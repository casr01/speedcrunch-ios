// ReferenceViews.swift — sheets listing built-in functions, constants and
// the user's own variables and functions. Tapping an entry inserts it.

import SwiftUI

struct FunctionsView: View {
    @EnvironmentObject private var model: CalculatorModel
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var functions: [BuiltinFunction] = []

    private var filtered: [BuiltinFunction] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return functions }
        return functions.filter {
            $0.identifier.lowercased().contains(q) || $0.name.lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { function in
                Button {
                    model.insert(function.identifier + "(")
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(function.identifier)(\(function.usage))")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(Theme.function)
                        Text(function.name)
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondary)
                    }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Buscar función")
            .navigationTitle("Funciones")
            .navigationBarTitleDisplayMode(.inline)
            .doneToolbar()
            .onAppear { if functions.isEmpty { functions = model.engine.builtinFunctions() } }
        }
    }
}

struct ConstantsView: View {
    @EnvironmentObject private var model: CalculatorModel
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var constants: [ConstantInfo] = []

    private struct ConstantGroup: Identifiable {
        let title: String
        let constants: [ConstantInfo]
        var id: String { title }
    }

    private var groups: [ConstantGroup] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let matching = q.isEmpty ? constants : constants.filter {
            $0.name.lowercased().contains(q) || $0.domain.lowercased().contains(q)
                || $0.subdomain.lowercased().contains(q)
        }
        var order: [String] = []
        var byGroup: [String: [ConstantInfo]] = [:]
        for constant in matching {
            let key = constant.subdomain.isEmpty ? constant.domain : "\(constant.domain) · \(constant.subdomain)"
            if byGroup[key] == nil { order.append(key) }
            byGroup[key, default: []].append(constant)
        }
        return order.map { ConstantGroup(title: $0, constants: byGroup[$0] ?? []) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(groups) { group in
                    Section(group.title) {
                        ForEach(group.constants) { constant in
                            Button {
                                model.insert(constant.value)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(constant.name)
                                        .foregroundStyle(Theme.text)
                                    Text(constant.unit.isEmpty ? constant.value : "\(constant.value)  \(constant.unit)")
                                        .font(.system(.subheadline, design: .monospaced))
                                        .foregroundStyle(Theme.number)
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Buscar constante")
            .navigationTitle("Constantes")
            .navigationBarTitleDisplayMode(.inline)
            .doneToolbar()
            .onAppear { if constants.isEmpty { constants = model.engine.constants() } }
        }
    }
}

struct DefinitionsView: View {
    @EnvironmentObject private var model: CalculatorModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let variables = model.variables()
        let functions = model.userFunctions()

        NavigationStack {
            List {
                Section {
                    if variables.isEmpty {
                        Text("Define una con  x = 5").foregroundStyle(Theme.secondary)
                    }
                    ForEach(variables) { variable in
                        Button {
                            model.insert(variable.name)
                            dismiss()
                        } label: {
                            HStack {
                                Text(variable.name)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(Theme.variable)
                                Spacer()
                                Text(variable.value)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(Theme.number)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                        .swipeActions {
                            if variable.name != "ans" {
                                Button(role: .destructive) {
                                    model.removeVariable(variable.name)
                                } label: {
                                    Label("Eliminar", systemImage: "trash")
                                }
                            }
                        }
                    }
                } header: {
                    Text("Variables")
                }

                Section {
                    if functions.isEmpty {
                        Text("Define una con  f(x) = x^2").foregroundStyle(Theme.secondary)
                    }
                    ForEach(functions) { function in
                        Button {
                            model.insert(function.name + "(")
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(function.signature)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(Theme.function)
                                Text("= " + function.body)
                                    .font(.system(.subheadline, design: .monospaced))
                                    .foregroundStyle(Theme.secondary)
                            }
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                model.removeUserFunction(function.name)
                            } label: {
                                Label("Eliminar", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Text("Funciones de usuario")
                } footer: {
                    Text("Desliza a la izquierda para eliminar.")
                }
            }
            .navigationTitle("Variables y funciones")
            .navigationBarTitleDisplayMode(.inline)
            .doneToolbar()
        }
    }
}

private struct DoneToolbar: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Listo") { dismiss() }
            }
        }
    }
}

extension View {
    /// Adds the "Listo" button that closes a sheet.
    func doneToolbar() -> some View { modifier(DoneToolbar()) }
}
