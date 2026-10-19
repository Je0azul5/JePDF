import AppKit
import PDFKit

public enum PDFError: LocalizedError {
    case message(String)
    public var errorDescription: String? {
        switch self { case .message(let text): return text }
    }
}

public enum PDFEngine {
    public static func open(_ url: URL, password: String = "") throws -> PDFDocument {
        guard let document = PDFDocument(url: url) else {
            throw PDFError.message("No se pudo abrir \(url.lastPathComponent). Comprueba que sea un PDF válido.")
        }
        if document.isLocked && !document.unlock(withPassword: password) {
            throw PDFError.message("\(url.lastPathComponent) requiere una contraseña válida.")
        }
        guard document.pageCount > 0 else { throw PDFError.message("El PDF no contiene páginas.") }
        return document
    }

    public static func pages(_ expression: String, count: Int) throws -> [Int] {
        if expression.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return Array(0..<count) }
        var result: [Int] = []
        for component in expression.split(separator: ",", omittingEmptySubsequences: false) {
            let bounds = component.trimmingCharacters(in: .whitespaces).split(separator: "-", omittingEmptySubsequences: false)
            guard (1...2).contains(bounds.count),
                  let first = Int(bounds[0].trimmingCharacters(in: .whitespaces)), (1...count).contains(first) else {
                throw PDFError.message("Usa páginas entre 1 y \(count), por ejemplo: 1-3, 5, 8.")
            }
            if bounds.count == 2 {
                guard let last = Int(bounds[1].trimmingCharacters(in: .whitespaces)), (1...count).contains(last) else {
                    throw PDFError.message("El rango debe contener páginas entre 1 y \(count).")
                }
                let step = first <= last ? 1 : -1
                result += stride(from: first, through: last, by: step).map { $0 - 1 }
            } else { result.append(first - 1) }
        }
        guard !result.isEmpty else { throw PDFError.message("Selecciona al menos una página.") }
        return result
    }

    public static func select(_ document: PDFDocument, expression: String) throws -> PDFDocument {
        let output = PDFDocument()
        for index in try pages(expression, count: document.pageCount) {
            guard let page = document.page(at: index)?.copy() as? PDFPage else {
                throw PDFError.message("No se pudo copiar la página \(index + 1).")
            }
            output.insert(page, at: output.pageCount)
        }
        return output
    }

    public static func merge(_ urls: [URL], password: String = "") throws -> PDFDocument {
        let output = PDFDocument()
        guard !urls.isEmpty else { throw PDFError.message("Añade al menos un PDF.") }
        for url in urls {
            let document = try open(url, password: password)
            for index in 0..<document.pageCount {
                guard let page = document.page(at: index)?.copy() as? PDFPage else {
                    throw PDFError.message("No se pudo copiar una página de \(url.lastPathComponent).")
                }
                output.insert(page, at: output.pageCount)
            }
        }
        return output
    }

    public static func rotate(_ document: PDFDocument, expression: String, degrees: Int) throws -> PDFDocument {
        let output = try select(document, expression: "")
        for index in Set(try pages(expression, count: output.pageCount)) {
            if let page = output.page(at: index) { page.rotation = ((page.rotation + degrees) % 360 + 360) % 360 }
        }
        return output
    }

    public static func imagesToPDF(_ urls: [URL]) throws -> PDFDocument {
        let output = PDFDocument()
        for url in urls {
            guard let image = NSImage(contentsOf: url), let page = PDFPage(image: image) else {
                throw PDFError.message("No se pudo abrir la imagen \(url.lastPathComponent).")
            }
            output.insert(page, at: output.pageCount)
        }
        guard output.pageCount > 0 else { throw PDFError.message("Añade al menos una imagen.") }
        return output
    }

    public static func jpeg(_ page: PDFPage, scale: CGFloat = 1.5, quality: CGFloat = 0.75) throws -> Data {
        let bounds = page.bounds(for: .mediaBox)
        // Limit raster size to keep memory usage bounded for oversized pages.
        let maxSide: CGFloat = 4096
        let effectiveScale = min(scale, maxSide / max(bounds.width, bounds.height, 1))
        let size = NSSize(width: max(1, bounds.width * effectiveScale), height: max(1, bounds.height * effectiveScale))
        let thumbnail = page.thumbnail(of: size, for: .mediaBox)
        guard let tiff = thumbnail.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
              let data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: quality]) else {
            throw PDFError.message("No se pudo convertir la página a imagen.")
        }
        return data
    }

    public static func compress(_ document: PDFDocument, quality: CGFloat) throws -> PDFDocument {
        let output = PDFDocument()
        for index in 0..<document.pageCount {
            guard let original = document.page(at: index) else { throw PDFError.message("Página no disponible.") }
            // Rasterize in unrotated page space, then retain the original PDF geometry.
            // Resizing PDFPage(image:) only changes its clipping box, not its image content.
            guard let sourceData = original.dataRepresentation,
                  let rasterDocument = PDFDocument(data: sourceData),
                  let rasterSource = rasterDocument.page(at: 0) else {
                throw PDFError.message("No se pudo comprimir la página \(index + 1).")
            }
            rasterSource.rotation = 0
            let data = try withExtendedLifetime(rasterDocument) {
                try jpeg(rasterSource, scale: 1.25, quality: quality)
            }
            let pageData = NSMutableData()
            var bounds = original.bounds(for: .mediaBox)
            guard let provider = CGDataProvider(data: data as CFData),
                  let image = CGImage(jpegDataProviderSource: provider, decode: nil,
                                      shouldInterpolate: true, intent: .defaultIntent),
                  let consumer = CGDataConsumer(data: pageData as CFMutableData),
                  let context = CGContext(consumer: consumer, mediaBox: &bounds, nil) else {
                throw PDFError.message("No se pudo comprimir la página \(index + 1).")
            }
            context.beginPDFPage(nil)
            context.draw(image, in: bounds)
            context.endPDFPage()
            context.closePDF()
            guard let page = PDFDocument(data: pageData as Data)?.page(at: 0) else {
                throw PDFError.message("No se pudo crear la página comprimida \(index + 1).")
            }
            for box: PDFDisplayBox in [.cropBox, .bleedBox, .trimBox, .artBox] {
                page.setBounds(original.bounds(for: box), for: box)
            }
            page.rotation = original.rotation
            output.insert(page, at: output.pageCount)
        }
        return output
    }

    public static func annotate(_ document: PDFDocument, watermark: String? = nil, startNumber: Int? = nil) throws -> PDFDocument {
        let output = try select(document, expression: "")
        for index in 0..<output.pageCount {
            guard let page = output.page(at: index) else { continue }
            let bounds = page.bounds(for: .cropBox)
            let isWatermark = watermark != nil
            let text = watermark ?? "\((startNumber ?? 1) + index)"
            let width = max(40, bounds.width - 48)
            let annotation = PDFAnnotation(bounds: CGRect(x: bounds.minX + 24,
                y: isWatermark ? bounds.midY - 32 : bounds.minY + 16,
                width: width, height: isWatermark ? 64 : 24), forType: .freeText, withProperties: nil)
            annotation.contents = text
            annotation.font = .systemFont(ofSize: isWatermark ? 36 : 12, weight: isWatermark ? .bold : .regular)
            annotation.fontColor = isWatermark ? NSColor.gray.withAlphaComponent(0.4) : .darkGray
            annotation.color = .clear
            annotation.alignment = .center
            annotation.shouldPrint = true
            page.addAnnotation(annotation)
        }
        return output
    }

    public static func save(_ document: PDFDocument, to url: URL, password: String? = nil) throws {
        var options: [PDFDocumentWriteOption: Any] = [:]
        if let password {
            guard !password.isEmpty else { throw PDFError.message("Escribe una contraseña para proteger el PDF.") }
            options[.userPasswordOption] = password
            options[.ownerPasswordOption] = password
        }
        guard let data = document.dataRepresentation(options: options) else {
            throw PDFError.message("No se pudo generar el PDF.")
        }
        try data.write(to: url, options: .atomic)
    }
}
