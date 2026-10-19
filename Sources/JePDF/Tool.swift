import SwiftUI

enum Category: String, CaseIterable, Identifiable {
    case all = "Todas las herramientas", organize = "Organizar", convert = "Convertir", edit = "Editar", security = "Seguridad"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .organize: return "square.3.layers.3d"
        case .convert: return "arrow.triangle.2.circlepath"
        case .edit: return "slider.horizontal.3"
        case .security: return "lock.shield"
        }
    }
}

struct Tool: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let category: Category
    let available: Bool
    var color: Color {
        switch category {
        case .organize: return Color(red: 0.95, green: 0.38, blue: 0.28)
        case .convert: return Color(red: 0.27, green: 0.48, blue: 0.77)
        case .edit: return Color(red: 0.65, green: 0.39, blue: 0.61)
        case .security: return Color(red: 0.25, green: 0.57, blue: 0.48)
        case .all: return .orange
        }
    }
    var acceptsImages: Bool { id == "images" }
    var multiple: Bool { id == "merge" || acceptsImages }
    var usesPages: Bool { ["split", "order", "rotate", "jpg"].contains(id) }

    static let catalog: [Tool] = [
        .init(id: "merge", name: "Unir PDF", description: "Varios documentos, un solo PDF. Ponlos en el orden que quieras.", icon: "arrow.triangle.merge", category: .organize, available: true),
        .init(id: "split", name: "Dividir PDF", description: "Extrae las páginas que necesitas y crea un nuevo documento.", icon: "arrow.up.left.and.arrow.down.right", category: .organize, available: true),
        .init(id: "compress", name: "Comprimir PDF", description: "Reduce el peso de tus documentos ajustando la calidad de imagen.", icon: "arrow.down.right.and.arrow.up.left", category: .edit, available: true),
        .init(id: "word", name: "PDF a Word", description: "Convierte documentos PDF en archivos de Word editables.", icon: "doc.text", category: .convert, available: false),
        .init(id: "ppt", name: "PDF a PowerPoint", description: "Transforma tus documentos en presentaciones de diapositivas.", icon: "rectangle.on.rectangle", category: .convert, available: false),
        .init(id: "excel", name: "PDF a Excel", description: "Extrae tablas de tus documentos a una hoja de cálculo.", icon: "tablecells", category: .convert, available: false),
        .init(id: "images", name: "Imagen a PDF", description: "Reúne imágenes JPG, PNG y TIFF en un documento PDF.", icon: "photo.on.rectangle.angled", category: .convert, available: true),
        .init(id: "jpg", name: "PDF a JPG", description: "Guarda cada página de tu PDF como una imagen de alta calidad.", icon: "photo", category: .convert, available: true),
        .init(id: "order", name: "Organizar PDF", description: "Reordena, duplica o elimina páginas para dejarlo a tu manera.", icon: "rectangle.3.group", category: .organize, available: true),
        .init(id: "watermark", name: "Marca de agua", description: "Añade una marca de texto sobre todas las páginas de tu PDF.", icon: "drop", category: .edit, available: true),
        .init(id: "rotate", name: "Rotar PDF", description: "Dale el giro correcto a todas las páginas o solo a algunas.", icon: "rotate.right", category: .organize, available: true),
        .init(id: "numbers", name: "Números de página", description: "Añade numeración a tus documentos de forma sencilla.", icon: "number.square", category: .edit, available: true),
        .init(id: "protect", name: "Proteger PDF", description: "Añade una contraseña para controlar el acceso a tu documento.", icon: "lock.shield", category: .security, available: true),
        .init(id: "unlock", name: "Desbloquear PDF", description: "Crea una copia sin contraseña usando la clave actual del PDF.", icon: "lock.open", category: .security, available: true),
        .init(id: "text", name: "PDF a texto", description: "Extrae el texto seleccionable y guárdalo en un archivo TXT.", icon: "text.alignleft", category: .convert, available: true),
        .init(id: "sign", name: "Firmar PDF", description: "Dibuja tu firma y colócala en tus documentos.", icon: "signature", category: .edit, available: false),
        .init(id: "editor", name: "Editar PDF", description: "Añade texto, formas y anotaciones a tus páginas.", icon: "square.and.pencil", category: .edit, available: false),
        .init(id: "ocr", name: "OCR PDF", description: "Reconoce el texto de documentos e imágenes escaneadas.", icon: "viewfinder", category: .convert, available: false)
    ]
}
