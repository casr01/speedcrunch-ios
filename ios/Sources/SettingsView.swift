// SettingsView.swift — the subset of SpeedCrunch's settings that matter on a phone.

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: CalculatorModel

    private struct Option: Identifiable {
        let code: String
        let title: String
        var id: String { code }
    }

    private let angleUnits = [
        Option(code: "r", title: "Radianes"), Option(code: "d", title: "Grados"),
        Option(code: "g", title: "Gradianes"), Option(code: "t", title: "Vueltas")
    ]

    private let formats = [
        Option(code: "g", title: "General"), Option(code: "f", title: "Fijo"),
        Option(code: "e", title: "Científico"), Option(code: "n", title: "Ingeniería"),
        Option(code: "r", title: "Racional"), Option(code: "s", title: "Sexagesimal"),
        Option(code: "h", title: "Hexadecimal"), Option(code: "o", title: "Octal"),
        Option(code: "b", title: "Binario")
    ]

    private let precisions = [-1, 0, 2, 4, 6, 8, 10, 15, 20, 30, 50]

    var body: some View {
        NavigationStack {
            Form {
                Section("Cálculo") {
                    Picker("Unidad de ángulo", selection: $model.settings.angleUnit) {
                        ForEach(angleUnits) { Text($0.title).tag($0.code) }
                    }
                    Toggle("Números complejos", isOn: $model.settings.complexNumbers)
                }

                Section {
                    Picker("Formato", selection: $model.settings.resultFormat) {
                        ForEach(formats) { Text($0.title).tag($0.code) }
                    }
                    Picker("Decimales", selection: $model.settings.precision) {
                        ForEach(precisions, id: \.self) { value in
                            Text(value < 0 ? "Automático" : "\(value)").tag(value)
                        }
                    }
                } header: {
                    Text("Resultado")
                } footer: {
                    Text("Automático usa la máxima precisión útil (hasta 50 dígitos).")
                }

                Section {
                    Picker("Separador decimal", selection: $model.settings.decimalSeparator) {
                        Text("Punto  (1.5)").tag(".")
                        Text("Coma  (1,5)").tag(",")
                    }
                    Toggle("Agrupar miles", isOn: $model.settings.digitGrouping)
                } header: {
                    Text("Números")
                } footer: {
                    Text(model.settings.decimalSeparator == ","
                         ? "Con coma decimal, los argumentos de funciones se separan con punto y coma:  max(1,5; 2)."
                         : "Los argumentos de funciones se separan con punto y coma:  max(1; 2).")
                }

                Section("Teclado") {
                    Toggle("Usar teclado de calculadora", isOn: $model.useKeypad)
                }
            }
            .navigationTitle("Ajustes")
            .navigationBarTitleDisplayMode(.inline)
            .doneToolbar()
        }
    }
}

struct AboutView: View {
    private let upstream = URL(string: "https://github.com/heldercorreia/speedcrunch")!

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SpeedCrunch para iOS")
                            .font(.title3.bold())
                        Text("Port personal de SpeedCrunch. El motor de cálculo es el original, sin cambios en su lógica; la interfaz es nueva, en SwiftUI.")
                            .foregroundStyle(Theme.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("Licencia") {
                    Text("SpeedCrunch es software libre bajo la GNU General Public License, versión 2 o posterior. Este port se distribuye bajo la misma licencia y sin garantía de ningún tipo.")
                        .font(.footnote)
                    Link("Código fuente original", destination: upstream)
                }

                Section("Versión") {
                    LabeledContent("App", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—")
                    LabeledContent("Motor (commit)", value: Bundle.main.object(forInfoDictionaryKey: "SCUpstreamCommit") as? String ?? "—")
                }
            }
            .navigationTitle("Acerca de")
            .navigationBarTitleDisplayMode(.inline)
            .doneToolbar()
        }
    }
}
