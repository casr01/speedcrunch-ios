// ContentView.swift — main calculator screen: history, live result, editor.

import SwiftUI
import UIKit

enum ActiveSheet: String, Identifiable {
    case functions, constants, definitions, settings, about
    var id: String { rawValue }
}

struct ContentView: View {
    @EnvironmentObject private var model: CalculatorModel
    @State private var sheet: ActiveSheet?
    @State private var confirmClear = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HistoryList()
                Divider().overlay(Theme.keyFill)
                PreviewLine(preview: model.preview)
                ExpressionField(model: model)
                    .frame(height: 46)
                    .padding(.horizontal, 14)
                    .padding(.top, 2)
                    .padding(.bottom, 4)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("SpeedCrunch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    Button { sheet = .functions } label: {
                        Image(systemName: "function")
                    }
                    .accessibilityLabel("Funciones")
                    Button { sheet = .constants } label: {
                        Image(systemName: "atom")
                    }
                    .accessibilityLabel("Constantes")
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Menu {
                        Button { sheet = .definitions } label: {
                            Label("Variables y funciones", systemImage: "x.squareroot")
                        }
                        Button { sheet = .settings } label: {
                            Label("Ajustes", systemImage: "gearshape")
                        }
                        Button { sheet = .about } label: {
                            Label("Acerca de", systemImage: "info.circle")
                        }
                        Divider()
                        Button(role: .destructive) { confirmClear = true } label: {
                            Label("Borrar historial", systemImage: "trash")
                        }
                        .disabled(model.history.isEmpty)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("Más opciones")
                }
            }
            .tint(Theme.comment)
            .confirmationDialog("¿Borrar todo el historial?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Borrar historial", role: .destructive) { model.clearHistory() }
            }
            .sheet(item: $sheet, onDismiss: { model.requestFocus() }) { kind in
                Group {
                    switch kind {
                    case .functions: FunctionsView()
                    case .constants: ConstantsView()
                    case .definitions: DefinitionsView()
                    case .settings: SettingsView()
                    case .about: AboutView()
                    }
                }
                .environmentObject(model)
            }
        }
    }
}

// MARK: - History

private struct HistoryList: View {
    @EnvironmentObject private var model: CalculatorModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if model.history.isEmpty {
                        EmptyHistoryHint()
                    }
                    ForEach(model.history) { item in
                        HistoryRow(item: item)
                            .id(item.id)
                    }
                    Color.clear.frame(height: 4).id(bottomID)
                }
            }
            .scrollDismissesKeyboard(.never)
            .onAppear { proxy.scrollTo(bottomID, anchor: .bottom) }
            .onChange(of: model.history.count) { _ in
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(bottomID, anchor: .bottom)
                }
            }
        }
    }

    private let bottomID = "history-bottom"
}

private struct HistoryRow: View {
    @EnvironmentObject private var model: CalculatorModel
    let item: HistoryItem

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(item.expression)
                .foregroundStyle(item.lines.isEmpty ? Theme.comment : Theme.text)
            ForEach(Array(item.lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .foregroundStyle(Theme.result)
                    .fontWeight(.medium)
            }
        }
        .font(.system(size: 17, design: .monospaced))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture { model.reuse(item) }
        .contextMenu {
            if let value = item.resultValue {
                Button {
                    UIPasteboard.general.string = value
                } label: {
                    Label("Copiar resultado", systemImage: "doc.on.doc")
                }
                Button {
                    model.insertResult(of: item)
                } label: {
                    Label("Insertar resultado", systemImage: "text.insert")
                }
            }
            Button {
                UIPasteboard.general.string = item.source
            } label: {
                Label("Copiar expresión", systemImage: "doc.on.clipboard")
            }
            Button {
                model.reuse(item)
            } label: {
                Label("Editar expresión", systemImage: "pencil")
            }
            Divider()
            Button(role: .destructive) {
                model.delete(item)
            } label: {
                Label("Eliminar", systemImage: "trash")
            }
        }
    }
}

private struct EmptyHistoryHint: View {
    private let examples = [
        "sqrt(2) * pi",
        "x = 5",
        "f(a; b) = a^2 + b",
        "10[metre] → [foot]",
        "0xFF + 1",
        "100!"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Escribe una expresión y presiona ⏎")
                .font(.headline)
                .foregroundStyle(Theme.text)
            Text("Algunas ideas:")
                .font(.subheadline)
                .foregroundStyle(Theme.secondary)
            ForEach(examples, id: \.self) { example in
                Text(example)
                    .font(.system(size: 16, design: .monospaced))
                    .foregroundStyle(Theme.function)
            }
            Text("Toca una línea del historial para reutilizarla. Mantén presionado para copiar.")
                .font(.footnote)
                .foregroundStyle(Theme.secondary)
                .padding(.top, 6)
        }
        .padding(20)
    }
}

// MARK: - Live result

private struct PreviewLine: View {
    let preview: Preview

    var body: some View {
        Group {
            switch preview {
            case .none:
                EmptyView()
            case .value(let lines):
                Text("= " + lines.joined(separator: "   "))
                    .foregroundStyle(Theme.secondary)
            case .error(let message):
                Text(message)
                    .foregroundStyle(Theme.error)
            }
        }
        .font(.system(size: 15, design: .monospaced))
        .lineLimit(2)
        .minimumScaleFactor(0.7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, preview == .none ? 0 : 8)
        .animation(nil, value: preview)
    }
}
