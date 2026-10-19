import SwiftUI
import AppKit

@main
struct JePDFApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene {
        WindowGroup("JePDF") {
            ContentView()
                .frame(minWidth: 940, minHeight: 650)
                .preferredColorScheme(.light)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1240, height: 840)
        .commands { CommandGroup(replacing: .newItem) {} }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

struct ContentView: View {
    @State private var category: Category = .all
    @State private var search = ""
    @State private var selected: Tool?
    @State private var onlyAvailable = false
    private let ink = Color(red: 0.16, green: 0.19, blue: 0.24)
    private var filtered: [Tool] {
        Tool.catalog.filter {
            (category == .all || $0.category == category) &&
            (!onlyAvailable || $0.available) &&
            (search.isEmpty || ($0.name + " " + $0.description).localizedCaseInsensitiveContains(search))
        }
    }
    var body: some View {
        HStack(spacing: 0) {
            sidebar
            VStack(spacing: 0) {
                HStack {
                    Text("Tu espacio de trabajo").font(.system(size: 13)).foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "lock.shield").foregroundStyle(Color(red: 0.24, green: 0.55, blue: 0.43))
                    Text("Archivos en tu Mac").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                }.padding(.horizontal, 34).frame(height: 58)
                Divider().opacity(0.5)
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Menos pasos. Más posibilidades.")
                                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                                Text(category == .all ? "Todo para tus PDF." : category.rawValue)
                                    .font(.system(size: 34, weight: .bold, design: .rounded)).tracking(-1).foregroundStyle(ink)
                                Text("Herramientas sencillas. Documentos bajo tu control.")
                                    .font(.system(size: 14)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            ZStack {
                                RoundedRectangle(cornerRadius: 22).fill(Color(red: 0.99, green: 0.92, blue: 0.88)).frame(width: 92, height: 92).rotationEffect(.degrees(9))
                                Image(systemName: "doc.richtext").font(.system(size: 43, weight: .light)).foregroundStyle(Color(red: 0.90, green: 0.37, blue: 0.25)).rotationEffect(.degrees(-8))
                            }.accessibilityHidden(true).padding(.trailing, 12)
                        }.padding(.top, 12).padding(.bottom, 8)
                        HStack {
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                                TextField("Buscar una herramienta…", text: $search).textFieldStyle(.plain)
                                if !search.isEmpty { Button { search = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }.buttonStyle(.plain).accessibilityLabel("Borrar búsqueda") }
                            }.padding(12).frame(maxWidth: 350).background(.white, in: RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.black.opacity(0.08)))
                            Spacer()
                            Toggle("Solo disponibles", isOn: $onlyAvailable).toggleStyle(.switch).controlSize(.small).font(.system(size: 12))
                        }
                        HStack {
                            Text(category.rawValue).font(.system(size: 15, weight: .semibold)).foregroundStyle(ink)
                            Text("\(filtered.count)").font(.system(size: 11, weight: .medium)).padding(.horizontal, 7).padding(.vertical, 3).background(Color.black.opacity(0.05), in: Capsule())
                            Spacer()
                        }
                        if filtered.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "magnifyingglass").font(.largeTitle)
                                Text("No encontramos esa herramienta").font(.headline)
                                Text("Prueba otra palabra o cambia el filtro.").foregroundStyle(.secondary)
                            }.frame(maxWidth: .infinity).padding(50)
                        }
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 16)], spacing: 16) {
                            ForEach(filtered) { tool in
                                Button { selected = tool } label: { ToolCard(tool: tool) }.buttonStyle(.plain)
                            }
                        }
                        HStack(spacing: 7) {
                            Image(systemName: "checkmark.shield")
                            Text("Procesamiento local · Sin subir archivos · Sin cuenta")
                        }.font(.system(size: 12)).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.vertical, 10)
                    }.padding(34)
                }.background(Color(red: 0.965, green: 0.966, blue: 0.98))
            }
        }
        .sheet(item: $selected) { tool in ToolWorkspace(tool: tool) }
    }
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack(spacing: 10) {
                Image(systemName: "square.stack.3d.up.fill").font(.system(size: 24)).foregroundStyle(Color(red: 0.93, green: 0.38, blue: 0.28))
                JePDFWordmark()
            }.padding(.top, 30).padding(.bottom, 14)
            VStack(alignment: .leading, spacing: 6) {
                Text("HERRAMIENTAS").font(.system(size: 10, weight: .semibold)).tracking(1.4).foregroundStyle(.secondary).padding(.bottom, 10).padding(.leading, 12)
                ForEach(Category.allCases) { item in
                    Button { category = item } label: {
                        HStack(spacing: 11) {
                            Image(systemName: item.icon).font(.system(size: 15)).frame(width: 20)
                            Text(item == .all ? "Todas" : item.rawValue).font(.system(size: 13, weight: category == item ? .semibold : .regular))
                            Spacer()
                            if item == category { Circle().fill(Color(red: 0.91, green: 0.37, blue: 0.27)).frame(width: 5, height: 5) }
                        }.foregroundStyle(category == item ? Color(red: 0.80, green: 0.29, blue: 0.20) : ink.opacity(0.75))
                            .padding(.horizontal, 12).padding(.vertical, 12)
                            .background(category == item ? Color(red: 1, green: 0.94, blue: 0.91) : .clear, in: RoundedRectangle(cornerRadius: 9))
                    }.buttonStyle(.plain)
                }
            }
            Spacer()
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: "internaldrive").font(.system(size: 23)).foregroundStyle(Color(red: 0.29, green: 0.53, blue: 0.45))
                Text("Lo tuyo se queda contigo.").font(.system(size: 13, weight: .semibold))
                Text("Tus documentos se procesan directamente en este Mac.").font(.system(size: 12)).foregroundStyle(.secondary).lineSpacing(4)
            }.padding(16).background(Color(red: 0.95, green: 0.97, blue: 0.96), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 5) {
                Text("JePDF para Mac   ·   v0.1.2")
                Text("Copyright: je0azul5")
            }.font(.system(size: 10)).foregroundStyle(.secondary)
        }.padding(18).frame(width: 200).background(.white)
    }
}

struct JePDFWordmark: View {
    var body: some View {
        (
            Text("J").foregroundColor(Color(red: 0.18, green: 0.43, blue: 0.85)) +
            Text("e").foregroundColor(Color(red: 0.10, green: 0.58, blue: 0.47)) +
            Text("P").foregroundColor(Color(red: 0.86, green: 0.57, blue: 0.08)) +
            Text("D").foregroundColor(Color(red: 0.92, green: 0.32, blue: 0.27)) +
            Text("F").foregroundColor(Color(red: 0.58, green: 0.35, blue: 0.79))
        )
        .font(.system(size: 27, weight: .bold, design: .rounded))
        .tracking(-0.8)
        .accessibilityLabel("JePDF")
    }
}

struct ToolCard: View {
    let tool: Tool
    @State private var hovered = false
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: tool.icon).font(.system(size: 23, weight: .medium)).foregroundStyle(tool.color)
                    .frame(width: 48, height: 48).background(tool.color.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
                Spacer()
                if !tool.available {
                    Text("Próximamente").font(.system(size: 9, weight: .medium)).foregroundStyle(.secondary)
                        .padding(.horizontal, 7).padding(.vertical, 4).background(Color.black.opacity(0.04), in: Capsule())
                } else if hovered {
                    Image(systemName: "arrow.up.right").font(.system(size: 13)).foregroundStyle(tool.color)
                }
            }.padding(.bottom, 20)
            Text(tool.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(Color(red: 0.18, green: 0.20, blue: 0.25)).padding(.bottom, 8)
            Text(tool.description).font(.system(size: 12)).foregroundStyle(.secondary).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }.padding(22).frame(maxWidth: .infinity, alignment: .leading).frame(height: 200)
            .background(.white, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(hovered ? tool.color.opacity(0.5) : Color.black.opacity(0.075), lineWidth: 1))
            .shadow(color: .black.opacity(hovered ? 0.055 : 0.015), radius: hovered ? 12 : 3, y: 4)
            .onHover { hovered = $0 }
            .accessibilityElement(children: .combine)
    }
}
