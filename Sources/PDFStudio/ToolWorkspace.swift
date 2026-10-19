import SwiftUI
import AppKit
import PDFKit
import UniformTypeIdentifiers
import PDFCore

struct PDFPreview: NSViewRepresentable {
    let url: URL
    let password: String
    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.backgroundColor = NSColor(white: 0.92, alpha: 1)
        return view
    }
    func updateNSView(_ view: PDFView, context: Context) {
        if view.document?.documentURL != url {
            view.document = PDFDocument(url: url)
        }
        if view.document?.isLocked == true { view.document?.unlock(withPassword: password) }
    }
}

private struct Job {
    let toolID: String
    let files: [URL]
    let expression: String
    let inputPassword: String
    let outputPassword: String
    let watermark: String
    let degrees: Int
    let quality: Double
    let startNumber: Int

    func run(to destination: URL) throws -> URL {
        if toolID == "merge" {
            try PDFEngine.save(PDFEngine.merge(files, password: inputPassword), to: destination)
            return destination
        }
        if toolID == "images" {
            try PDFEngine.save(PDFEngine.imagesToPDF(files), to: destination)
            return destination
        }
        guard let source = files.first else { throw PDFError.message("Selecciona un archivo.") }
        let document = try PDFEngine.open(source, password: inputPassword)
        if toolID == "jpg" {
            let folder = destination.appendingPathComponent("folio-imagenes-\(UUID().uuidString.prefix(8))", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
            do {
                let indices = try PDFEngine.pages(expression, count: document.pageCount)
                for (offset, index) in indices.enumerated() {
                    guard let page = document.page(at: index) else { throw PDFError.message("Página no disponible.") }
                    let data = try PDFEngine.jpeg(page, scale: 2, quality: 0.9)
                    try data.write(to: folder.appendingPathComponent(String(format: "pagina-%04d.jpg", offset + 1)), options: .atomic)
                }
            } catch {
                // Only remove the fresh, private output directory if this export failed.
                try? FileManager.default.removeItem(at: folder)
                throw error
            }
            return folder
        }
        if toolID == "text" {
            guard let text = document.string, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw PDFError.message("Este PDF no tiene texto seleccionable. Un documento escaneado necesita OCR, que aún no está disponible.")
            }
            try text.write(to: destination, atomically: true, encoding: .utf8)
            return destination
        }
        let output: PDFDocument
        switch toolID {
        case "split", "order": output = try PDFEngine.select(document, expression: expression)
        case "rotate": output = try PDFEngine.rotate(document, expression: expression, degrees: degrees)
        case "compress": output = try PDFEngine.compress(document, quality: quality)
        case "watermark": output = try PDFEngine.annotate(document, watermark: watermark)
        case "numbers": output = try PDFEngine.annotate(document, startNumber: startNumber)
        case "protect":
            try PDFEngine.save(document, to: destination, password: outputPassword)
            return destination
        case "unlock":
            guard document.allowsPrinting && document.allowsCopying else {
                throw PDFError.message("El documento mantiene restricciones de propietario. Introduce la contraseña de propietario para exportar una copia sin restricciones.")
            }
            output = try PDFEngine.select(document, expression: "")
        default: throw PDFError.message("Esta herramienta todavía no está disponible.")
        }
        try PDFEngine.save(output, to: destination)
        return destination
    }
}

struct ToolWorkspace: View {
    let tool: Tool
    @Environment(\.dismiss) private var dismiss
    @State private var files: [URL] = []
    @State private var previewURL: URL?
    @State private var expression = ""
    @State private var inputPassword = ""
    @State private var outputPassword = ""
    @State private var watermark = "CONFIDENCIAL"
    @State private var degrees = 90
    @State private var quality = 0.55
    @State private var startNumber = 1
    @State private var busy = false
    @State private var error: String?
    @State private var result: URL?
    @State private var dragTarget = false
    @State private var resultMessage = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: tool.icon).font(.system(size: 23)).foregroundStyle(tool.color)
                    .frame(width: 48, height: 48).background(tool.color.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 5) {
                    Text(tool.name).font(.system(size: 22, weight: .bold, design: .rounded))
                    Text(tool.description).font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark").font(.system(size: 14)).frame(width: 30, height: 30) }
                    .buttonStyle(.plain).accessibilityLabel("Cerrar herramienta").disabled(busy)
            }.padding(24)
            Divider()
            if !tool.available {
                VStack(spacing: 18) {
                    Image(systemName: "wrench.and.screwdriver").font(.system(size: 45, weight: .light)).foregroundStyle(tool.color)
                    Text("Estamos preparando esta herramienta").font(.title2.bold())
                    Text("Todavía no está disponible en esta versión.\nPuedes usar las herramientas marcadas como disponibles en el catálogo.")
                        .multilineTextAlignment(.center).foregroundStyle(.secondary)
                    Button("Volver a las herramientas") { dismiss() }.buttonStyle(.borderedProminent).tint(tool.color)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            HStack {
                                Text("1. Tus archivos").font(.headline)
                                Spacer()
                                if !files.isEmpty { Button(tool.multiple ? "Añadir" : "Cambiar") { chooseFiles() }.disabled(busy) }
                            }
                            if files.isEmpty { dropZone } else { fileList }
                            options
                            Label("El original se conserva. Elige dónde guardar la copia.", systemImage: "checkmark.shield")
                                .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }.padding(24)
                    }.frame(width: 355)
                    Divider()
                    ZStack {
                        Color(nsColor: NSColor(white: 0.94, alpha: 1))
                        if let url = previewURL {
                            if tool.acceptsImages {
                                if let image = NSImage(contentsOf: url) {
                                    Image(nsImage: image).resizable().scaledToFit().padding(28)
                                }
                            } else {
                                PDFPreview(url: url, password: inputPassword)
                            }
                        } else {
                            VStack(spacing: 13) {
                                Image(systemName: "doc.text.magnifyingglass").font(.system(size: 42, weight: .ultraLight))
                                Text("Vista previa del documento").font(.system(size: 13))
                            }.foregroundStyle(.secondary)
                        }
                    }.overlay(alignment: .topTrailing) {
                        if previewURL != nil {
                            Text("ORIGINAL").font(.system(size: 9, weight: .semibold)).tracking(1)
                                .padding(7).background(.regularMaterial, in: Capsule()).padding(12)
                        }
                    }
                }
                Divider()
                HStack(spacing: 14) {
                    if busy {
                        ProgressView().controlSize(.small)
                        Text("Procesando en tu Mac…").font(.system(size: 12)).foregroundStyle(.secondary)
                    } else if let result {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Archivo guardado").font(.system(size: 12, weight: .semibold))
                            if !resultMessage.isEmpty { Text(resultMessage).font(.system(size: 10)).foregroundStyle(.secondary) }
                        }
                        Button("Ver en Finder") { NSWorkspace.shared.activateFileViewerSelecting([result]) }.font(.system(size: 12))
                    } else {
                        Image(systemName: "internaldrive").foregroundStyle(.secondary)
                        Text("Tus archivos no salen de este equipo").font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Guardar \(tool.id == "jpg" ? "imágenes" : "copia")…") { export() }
                        .buttonStyle(.borderedProminent).tint(tool.color).controlSize(.large)
                        .disabled(files.isEmpty || busy || (tool.id == "protect" && outputPassword.isEmpty) || (tool.id == "watermark" && watermark.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                }.padding(20)
            }
        }.frame(width: 960, height: 690)
            .background(.white)
            .interactiveDismissDisabled(busy)
            .alert("No se pudo completar", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("Entendido", role: .cancel) { error = nil }
            } message: { Text(error ?? "") }
    }

    private var dropZone: some View {
        VStack(spacing: 13) {
            Image(systemName: "square.and.arrow.down").font(.system(size: 30, weight: .light)).foregroundStyle(tool.color)
            Text(tool.acceptsImages ? "Arrastra tus imágenes aquí" : "Arrastra \(tool.multiple ? "tus PDF" : "un PDF") aquí").font(.system(size: 13, weight: .medium))
            Text("o selecciona desde tu Mac").font(.system(size: 11)).foregroundStyle(.secondary)
            Button("Seleccionar archivos") { chooseFiles() }.buttonStyle(.borderedProminent).tint(tool.color)
        }.frame(maxWidth: .infinity).padding(.vertical, 30)
            .background(tool.color.opacity(dragTarget ? 0.10 : 0.035), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(tool.color.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
            .onDrop(of: [UTType.fileURL], isTargeted: $dragTarget) { providers in
                guard !busy else { return false }
                // Preserve the original drop ordering even when providers load asynchronously.
                Task { @MainActor in
                    var urls: [URL] = []
                    for provider in providers {
                        let url: URL? = await withCheckedContinuation { continuation in
                            _ = provider.loadObject(ofClass: URL.self) { value, _ in continuation.resume(returning: value) }
                        }
                        if let url { urls.append(url) }
                    }
                    addFiles(urls)
                }
                return true
            }
    }

    private var fileList: some View {
        VStack(spacing: 8) {
            ForEach(Array(files.enumerated()), id: \.element) { index, url in
                HStack(spacing: 8) {
                    Button { previewURL = url } label: {
                        HStack(spacing: 8) {
                            Image(systemName: tool.acceptsImages ? "photo" : "doc.fill").foregroundStyle(tool.color)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(url.lastPathComponent).font(.system(size: 12, weight: .medium)).lineLimit(1).truncationMode(.middle)
                                Text(fileSize(url)).font(.system(size: 10)).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                    }.buttonStyle(.plain)
                    if tool.multiple {
                        VStack(spacing: 4) {
                            Button { move(index, by: -1) } label: { Image(systemName: "chevron.up").font(.system(size: 9)) }.disabled(index == 0).accessibilityLabel("Mover antes")
                            Button { move(index, by: 1) } label: { Image(systemName: "chevron.down").font(.system(size: 9)) }.disabled(index == files.count - 1).accessibilityLabel("Mover después")
                        }.buttonStyle(.plain)
                    }
                    Button {
                        files.remove(at: index)
                        if previewURL == url { previewURL = files.first }
                        result = nil
                    } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }.buttonStyle(.plain).accessibilityLabel("Quitar \(url.lastPathComponent)")
                }.padding(10).background(Color.black.opacity(0.025), in: RoundedRectangle(cornerRadius: 8))
            }
        }.disabled(busy)
    }

    @ViewBuilder private var options: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("2. Opciones").font(.headline)
            if tool.usesPages {
                Text(tool.id == "order" ? "Orden de las páginas" : "Páginas").font(.system(size: 12, weight: .medium))
                TextField("Todas · Ejemplo: 1-3, 5, 8", text: $expression).textFieldStyle(.roundedBorder)
                Text(tool.id == "order" ? "Escribe el nuevo orden: 3, 1, 2. Omite páginas para eliminarlas o repítelas para duplicarlas. Los rangos pueden ir al revés: 5-1." : "Deja el campo vacío para incluir todas las páginas. La extracción crea un único PDF con las páginas elegidas.")
                    .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            if tool.id == "rotate" {
                Picker("Giro", selection: $degrees) {
                    Text("90° derecha").tag(90)
                    Text("180°").tag(180)
                    Text("90° izquierda").tag(270)
                }.pickerStyle(.menu)
            }
            if tool.id == "compress" {
                Text("Calidad de imagen: \(Int(quality * 100)) %").font(.system(size: 12))
                Slider(value: $quality, in: 0.15...0.9)
                Label("Convierte cada página en una imagen. Se pierde el texto seleccionable, los enlaces y los formularios. El tamaño final puede ser mayor que el original.", systemImage: "info.circle")
                    .font(.system(size: 11)).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
            }
            if tool.id == "watermark" {
                TextField("Texto de la marca", text: $watermark).textFieldStyle(.roundedBorder)
                Text("Texto gris semitransparente en el centro de cada página. Se añade como una anotación editable; no protege el contenido.").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            if tool.id == "numbers" {
                Stepper("Empezar en: \(startNumber)", value: $startNumber, in: 1...9999).font(.system(size: 12))
                Text("Numeración centrada en el margen inferior. Se añade como una anotación editable.").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            if tool.id == "protect" {
                SecureField("Contraseña para la nueva copia", text: $outputPassword).textFieldStyle(.roundedBorder)
                Text("Necesitarás esta contraseña para abrir la copia. Guárdala en un lugar seguro.").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            if tool.id == "jpg" {
                Text("Se creará una carpeta nueva con una imagen JPG por página, a 144 ppp (máximo 4096 px por lado).").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            if tool.id == "merge" || tool.id == "images" {
                Text("Usa las flechas de la lista para cambiar el orden de los archivos.").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            if tool.id == "text" {
                Text("Se extrae el texto seleccionable en formato TXT, sin conservar la maquetación. No incluye reconocimiento OCR.").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            if !tool.acceptsImages {
                Divider()
                Text(tool.id == "unlock" ? "Contraseña actual" : "¿El original tiene contraseña?").font(.system(size: 12, weight: .medium))
                SecureField("Contraseña del original", text: $inputPassword).textFieldStyle(.roundedBorder)
            }
        }.disabled(busy)
    }

    private func chooseFiles() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = tool.acceptsImages ? [.jpeg, .png, .tiff] : [.pdf]
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = tool.multiple
        panel.canChooseDirectories = false
        panel.prompt = "Seleccionar"
        panel.begin { response in
            if response == .OK { addFiles(panel.urls) }
        }
    }
    private func addFiles(_ urls: [URL]) {
        let allowed = tool.acceptsImages ? ["jpg", "jpeg", "png", "tif", "tiff"] : ["pdf"]
        let accepted = urls.filter { $0.isFileURL && allowed.contains($0.pathExtension.lowercased()) }
        guard !accepted.isEmpty else {
            error = tool.acceptsImages ? "Selecciona imágenes JPG, PNG o TIFF." : "Selecciona un archivo PDF."
            return
        }
        if tool.multiple {
            files += accepted.filter { !files.contains($0) }
        } else { files = [accepted[0]] }
        previewURL = files.first
        result = nil
    }
    private func move(_ index: Int, by offset: Int) {
        let next = index + offset
        guard files.indices.contains(next) else { return }
        files.swapAt(index, next)
        result = nil
    }
    private func fileSize(_ url: URL) -> String {
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }
    private func export() {
        if tool.id == "jpg" {
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.canCreateDirectories = true
            panel.prompt = "Guardar aquí"
            panel.message = "Elige dónde crear la carpeta de imágenes."
            panel.begin { response in
                guard response == .OK, let url = panel.url else { return }
                performExport(to: url)
            }
        } else {
            let panel = NSSavePanel()
            panel.allowedContentTypes = tool.id == "text" ? [.plainText] : [.pdf]
            let stem = files.first?.deletingPathExtension().lastPathComponent ?? "documento"
            panel.nameFieldStringValue = "\(stem)-\(tool.id).\(tool.id == "text" ? "txt" : "pdf")"
            panel.canCreateDirectories = true
            panel.prompt = "Guardar copia"
            panel.begin { response in
                guard response == .OK, let url = panel.url else { return }
                guard !files.contains(where: { $0.resolvingSymlinksInPath().standardizedFileURL == url.resolvingSymlinksInPath().standardizedFileURL }) else {
                    error = "Elige un nombre diferente para conservar el archivo original."
                    return
                }
                performExport(to: url)
            }
        }
    }
    private func performExport(to destination: URL) {
        let job = Job(toolID: tool.id, files: files, expression: expression, inputPassword: inputPassword,
                      outputPassword: outputPassword, watermark: watermark, degrees: degrees,
                      quality: quality, startNumber: startNumber)
        let originalSize = files.reduce(0) { $0 + ((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
        busy = true
        result = nil
        Task { @MainActor in
            do {
                let url = try await Task.detached(priority: .userInitiated) { try job.run(to: destination) }.value
                result = url
                if tool.id == "compress" {
                    resultMessage = "\(ByteCountFormatter.string(fromByteCount: Int64(originalSize), countStyle: .file)) → \(fileSize(url))"
                } else { resultMessage = url.lastPathComponent }
            } catch { self.error = error.localizedDescription }
            busy = false
        }
    }
}
