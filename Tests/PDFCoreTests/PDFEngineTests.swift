import Foundation
import AppKit
import PDFKit
import PDFCore

// Standalone checks also work with Command Line Tools, which do not ship XCTest.
private struct CheckFailure: Error, CustomStringConvertible {
    let description: String
}
private func XCTAssertEqual<T: Equatable>(_ lhs: T, _ rhs: T, _ message: String = "", file: StaticString = #filePath, line: UInt = #line) throws {
    guard lhs == rhs else { throw CheckFailure(description: "\(file):\(line) \(lhs) != \(rhs) \(message)") }
}
private func XCTAssertTrue(_ value: Bool) throws {
    guard value else { throw CheckFailure(description: "Se esperaba true") }
}
private func XCTAssertFalse(_ value: Bool) throws { try XCTAssertTrue(!value) }
private func XCTAssertNotNil<T>(_ value: T?) throws { try XCTAssertTrue(value != nil) }
private func XCTUnwrap<T>(_ value: T?) throws -> T {
    guard let value else { throw CheckFailure(description: "Valor inesperado: nil") }
    return value
}
private func XCTAssertThrowsError<T>(_ expression: @autoclosure () throws -> T, _ message: String = "") throws {
    do { _ = try expression() } catch { return }
    throw CheckFailure(description: "Se esperaba un error: \(message)")
}

final class PDFEngineTests {
    private var cleanup: [URL] = []
    deinit { for url in cleanup { try? FileManager.default.removeItem(at: url) } }
    func saveSample(to url: URL) throws { try PDFEngine.save(document(), to: url) }
    private func document(_ count: Int = 3) -> PDFDocument {
        let document = PDFDocument()
        for index in 0..<count {
            let page = PDFPage()
            page.setBounds(CGRect(x: 0, y: 0, width: 300 + index * 20, height: 400), for: .mediaBox)
            let text = PDFAnnotation(bounds: CGRect(x: 20, y: 100, width: 200, height: 40), forType: .freeText, withProperties: nil)
            text.contents = "Página \(index + 1)"
            page.addAnnotation(text)
            document.insert(page, at: index)
        }
        return document
    }
    private func tempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        cleanup.append(url)
        return url
    }
    func testPageRangesPreserveOrderAndDuplicates() throws {
        try XCTAssertEqual(PDFEngine.pages("3-1, 2, 2", count: 3), [2, 1, 0, 1, 1])
        try XCTAssertEqual(PDFEngine.pages(" ", count: 3), [0, 1, 2])
        for input in ["0", "4", "1-4", "1,", "a", "-1", "1-2-3"] {
            try XCTAssertThrowsError(PDFEngine.pages(input, count: 3), input)
        }
    }
    func testExtractAndRotateDoNotChangeOriginal() throws {
        let original = document()
        let selected = try PDFEngine.select(original, expression: "3,1,3")
        try XCTAssertEqual(selected.pageCount, 3)
        try XCTAssertEqual(selected.page(at: 0)?.bounds(for: .mediaBox).width, 340)
        try XCTAssertEqual(selected.page(at: 1)?.bounds(for: .mediaBox).width, 300)
        let rotated = try PDFEngine.rotate(original, expression: "2,2", degrees: 90)
        try XCTAssertEqual(rotated.page(at: 1)?.rotation, 90)
        try XCTAssertEqual(rotated.page(at: 0)?.rotation, 0)
        try XCTAssertEqual(original.page(at: 1)?.rotation, 0)
    }
    func testMergeAndSaveRoundTrip() throws {
        let folder = try tempDirectory()
        let first = folder.appendingPathComponent("first.pdf")
        let second = folder.appendingPathComponent("second.pdf")
        try PDFEngine.save(document(2), to: first)
        try PDFEngine.save(document(1), to: second)
        let merged = try PDFEngine.merge([first, second])
        try XCTAssertEqual(merged.pageCount, 3)
        let destination = folder.appendingPathComponent("merged.pdf")
        try PDFEngine.save(merged, to: destination)
        try XCTAssertEqual(try PDFEngine.open(destination).pageCount, 3)
        try XCTAssertEqual(try PDFEngine.open(first).pageCount, 2)
    }
    func testPasswordProtectionAndUnlockedCopy() throws {
        let folder = try tempDirectory()
        let protected = folder.appendingPathComponent("protected.pdf")
        try PDFEngine.save(document(1), to: protected, password: "test-password")
        try XCTAssertTrue(try XCTUnwrap(PDFDocument(url: protected)).isLocked)
        try XCTAssertThrowsError(try PDFEngine.open(protected, password: "wrong"))
        let unlocked = try PDFEngine.open(protected, password: "test-password")
        let copy = folder.appendingPathComponent("unlocked.pdf")
        try PDFEngine.save(PDFEngine.select(unlocked, expression: ""), to: copy)
        try XCTAssertFalse(try XCTUnwrap(PDFDocument(url: copy)).isLocked)
        try XCTAssertEqual(try PDFEngine.open(copy).pageCount, 1)
    }
    func testAnnotationsSurviveSaveWithoutChangingSource() throws {
        let original = document(2)
        let numbered = try PDFEngine.annotate(original, startNumber: 7)
        try XCTAssertEqual(numbered.page(at: 0)?.annotations.last?.contents, "7")
        try XCTAssertEqual(numbered.page(at: 1)?.annotations.last?.contents, "8")
        try XCTAssertEqual(original.page(at: 0)?.annotations.count, 1)
        let folder = try tempDirectory()
        let url = folder.appendingPathComponent("marked.pdf")
        try PDFEngine.save(PDFEngine.annotate(original, watermark: "BORRADOR"), to: url)
        try XCTAssertEqual(try PDFEngine.open(url).page(at: 1)?.annotations.last?.contents, "BORRADOR")
    }
    func testImageExportsAndCompressionPreservePageGeometry() throws {
        let original = document(2)
        original.page(at: 0)?.rotation = 90
        let data = try PDFEngine.jpeg(XCTUnwrap(original.page(at: 0)))
        try XCTAssertNotNil(NSImage(data: data))
        let compressed = try PDFEngine.compress(original, quality: 0.5)
        try XCTAssertEqual(compressed.pageCount, 2)
        try XCTAssertEqual(compressed.page(at: 0)?.bounds(for: .mediaBox).width, 300)
        try XCTAssertEqual(compressed.page(at: 0)?.bounds(for: .mediaBox).height, 400)
        try XCTAssertEqual(compressed.page(at: 0)?.rotation, 90)
        try XCTAssertEqual(compressed.page(at: 1)?.bounds(for: .mediaBox).width, 320)
        let folder = try tempDirectory()
        let imageURL = folder.appendingPathComponent("page.jpg")
        try data.write(to: imageURL)
        try XCTAssertEqual(try PDFEngine.imagesToPDF([imageURL, imageURL]).pageCount, 2)
    }

    private func edgeFixture(bounds: CGRect, rotation: Int, crop: Bool) throws -> PDFPage {
        let data = NSMutableData()
        var media = bounds
        let consumer = try XCTUnwrap(CGDataConsumer(data: data as CFMutableData))
        let context = try XCTUnwrap(CGContext(consumer: consumer, mediaBox: &media, nil))
        context.beginPDFPage(nil)
        context.setFillColor(NSColor.white.cgColor)
        context.fill(bounds)
        context.setStrokeColor(NSColor.black.cgColor)
        context.setLineWidth(4)
        context.stroke(bounds.insetBy(dx: 3, dy: 3))
        let markers: [(CGFloat, CGFloat, NSColor)] = [
            (bounds.minX + 7, bounds.minY + 7, .red),
            (bounds.maxX - 47, bounds.minY + 7, .green),
            (bounds.minX + 7, bounds.maxY - 47, .blue),
            (bounds.maxX - 47, bounds.maxY - 47, .black)
        ]
        for (x, y, color) in markers {
            context.setFillColor(color.cgColor)
            context.fill(CGRect(x: x, y: y, width: 40, height: 40))
        }
        context.setFillColor(NSColor.purple.cgColor)
        context.fill(CGRect(x: bounds.midX - 20, y: bounds.midY - 30, width: 40, height: 60))
        context.endPDFPage()
        context.closePDF()
        let page = try XCTUnwrap(PDFDocument(data: data as Data)?.page(at: 0))
        if crop { page.setBounds(bounds.insetBy(dx: 17, dy: 23), for: .cropBox) }
        page.rotation = rotation
        return page
    }

    private func pixels(_ page: PDFPage, box: CGPDFBox) throws -> [UInt8] {
        let width = 192, height = 256
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        try bytes.withUnsafeMutableBytes { buffer in
            let context = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            let rect = CGRect(x: 0, y: 0, width: width, height: height)
            context.setFillColor(NSColor.white.cgColor)
            context.fill(rect)
            let reference = try XCTUnwrap(page.pageRef)
            context.concatenate(reference.getDrawingTransform(box, rect: rect, rotate: 0, preserveAspectRatio: true))
            context.drawPDFPage(reference)
        }
        return bytes
    }

    func testCompressionKeepsEdgesAndPageBoxesAfterSaving() throws {
        var source = PDFDocument()
        for bounds in [CGRect(x: 0, y: 0, width: 320, height: 460),
                       CGRect(x: 41, y: -29, width: 460, height: 320)] {
            for rotation in [0, 90, 180, 270] {
                for crop in [false, true] {
                    source.insert(try edgeFixture(bounds: bounds, rotation: rotation, crop: crop), at: source.pageCount)
                }
            }
        }
        let folder = try tempDirectory()
        // Reopen to make PDFKit box/rotation edits visible through the CGPDFPage used by the pixel check.
        let sourceURL = folder.appendingPathComponent("source-edges.pdf")
        try PDFEngine.save(source, to: sourceURL)
        source = try PDFEngine.open(sourceURL)
        let url = folder.appendingPathComponent("compressed-edges.pdf")
        try PDFEngine.save(PDFEngine.compress(source, quality: 0.7), to: url)
        let reopened = try PDFEngine.open(url)
        try XCTAssertEqual(reopened.pageCount, source.pageCount)
        for index in 0..<source.pageCount {
            let original = try XCTUnwrap(source.page(at: index))
            let compressed = try XCTUnwrap(reopened.page(at: index))
            for box: CGPDFBox in [.mediaBox, .cropBox] {
                let expected = try pixels(original, box: box)
                let actual = try pixels(compressed, box: box)
                let error = zip(expected, actual).reduce(0.0) { $0 + Double(abs(Int($1.0) - Int($1.1))) } / Double(expected.count * 255)
                guard error < 0.015 else {
                    throw CheckFailure(description: "El contenido está recortado o desalineado en página \(index + 1), caja \(box.rawValue), diferencia \(error)")
                }
            }
            try XCTAssertEqual(compressed.bounds(for: .mediaBox), original.bounds(for: .mediaBox))
            try XCTAssertEqual(compressed.bounds(for: .cropBox), original.bounds(for: .cropBox))
            try XCTAssertEqual(compressed.rotation, original.rotation)
        }
    }
}

@main
struct PDFCoreChecks {
    static func main() throws {
        let tests = PDFEngineTests()
        if CommandLine.arguments.count == 3 && CommandLine.arguments[1] == "--sample" {
            try tests.saveSample(to: URL(fileURLWithPath: CommandLine.arguments[2]))
            return
        }
        let checks: [(String, () throws -> Void)] = [
            ("Rangos y entradas inválidas", tests.testPageRangesPreserveOrderAndDuplicates),
            ("Extracción, orden y rotación", tests.testExtractAndRotateDoNotChangeOriginal),
            ("Unión y guardado", tests.testMergeAndSaveRoundTrip),
            ("Protección y copia sin contraseña", tests.testPasswordProtectionAndUnlockedCopy),
            ("Anotaciones y conservación del original", tests.testAnnotationsSurviveSaveWithoutChangingSource),
            ("Imágenes, compresión y geometría", tests.testImageExportsAndCompressionPreservePageGeometry),
            ("Compresión sin recortar bordes, márgenes ni páginas giradas", tests.testCompressionKeepsEdgesAndPageBoxesAfterSaving)
        ]
        for (name, check) in checks {
            try check()
            print("PASS: \(name)")
        }
        print("\(checks.count)/\(checks.count) comprobaciones superadas")
    }
}
