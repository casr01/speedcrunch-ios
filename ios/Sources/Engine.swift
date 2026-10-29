// Engine.swift — Swift wrapper over the C bridge (speedcrunch_bridge.h).
//
// All calls must happen on the main thread; the model guarantees that.

import Foundation

struct EvaluationResult: Decodable {
    let ok: Bool
    let kind: String?
    let expression: String?
    let lines: [String]?
    let error: String?
}

struct PreviewResult: Decodable {
    let ok: Bool
    let lines: [String]?
    let error: String?
}

struct HistoryItem: Decodable, Identifiable, Hashable {
    var id: Int = 0
    let source: String
    let expression: String
    let lines: [String]

    private enum CodingKeys: String, CodingKey { case source, expression, lines }

    /// "= 4" -> "4": the bare value, for copying or reusing.
    var resultValue: String? {
        guard let first = lines.first else { return nil }
        return first.hasPrefix("= ") ? String(first.dropFirst(2)) : first
    }
}

struct UserVariable: Decodable, Identifiable, Hashable {
    var id: String { name }
    let name: String
    let value: String
}

struct UserFunctionInfo: Decodable, Identifiable, Hashable {
    var id: String { name }
    let name: String
    let arguments: [String]
    let body: String

    var signature: String { "\(name)(\(arguments.joined(separator: ";")))" }
}

struct BuiltinFunction: Decodable, Identifiable, Hashable {
    var id: String { identifier }
    let identifier: String
    let name: String
    let usage: String
}

struct ConstantInfo: Decodable, Identifiable, Hashable {
    var id: String { domain + "/" + subdomain + "/" + name }
    let name: String
    let value: String
    let unit: String
    let domain: String
    let subdomain: String
}

struct EngineSettings: Codable, Equatable {
    var angleUnit: String = "r"
    var resultFormat: String = "g"
    var precision: Int = -1
    var complexNumbers: Bool = false
    var decimalSeparator: String = "."
    var digitGrouping: Bool = false
}

final class Engine {
    private let handle: OpaquePointer

    init(dataDirectory: URL?) {
        let created: OpaquePointer?
        if let dataDirectory {
            created = dataDirectory.path.withCString { sc_engine_create($0) }
        } else {
            created = sc_engine_create(nil)
        }
        guard let created else {
            fatalError("SpeedCrunch engine could not be created")
        }
        handle = created
    }

    deinit {
        sc_engine_destroy(handle)
    }

    // MARK: Calculation

    func evaluate(_ expression: String) -> EvaluationResult {
        decode(expression.withCString { sc_engine_evaluate(handle, $0) })
            ?? EvaluationResult(ok: false, kind: nil, expression: nil, lines: nil, error: "Error interno")
    }

    func preview(_ expression: String) -> PreviewResult {
        decode(expression.withCString { sc_engine_preview(handle, $0) })
            ?? PreviewResult(ok: false, lines: nil, error: nil)
    }

    // MARK: History

    func history() -> [HistoryItem] {
        let items: [HistoryItem] = decode(sc_engine_history(handle)) ?? []
        return items.enumerated().map { index, item in
            var copy = item
            copy.id = index
            return copy
        }
    }

    func clearHistory() { sc_engine_clear_history(handle) }

    func removeHistoryEntry(at index: Int) {
        sc_engine_remove_history_entry(handle, Int32(index))
    }

    // MARK: User definitions

    func variables() -> [UserVariable] { decode(sc_engine_variables(handle)) ?? [] }

    func removeVariable(_ name: String) {
        name.withCString { sc_engine_remove_variable(handle, $0) }
    }

    func userFunctions() -> [UserFunctionInfo] { decode(sc_engine_user_functions(handle)) ?? [] }

    func removeUserFunction(_ name: String) {
        name.withCString { sc_engine_remove_user_function(handle, $0) }
    }

    // MARK: Reference data

    func builtinFunctions() -> [BuiltinFunction] {
        let all: [BuiltinFunction] = decode(sc_engine_builtin_functions(handle)) ?? []
        var seen = Set<String>()
        return all.filter { seen.insert($0.identifier).inserted }
    }

    func constants() -> [ConstantInfo] { decode(sc_engine_constants(handle)) ?? [] }

    // MARK: Settings

    func settings() -> EngineSettings { decode(sc_engine_get_settings(handle)) ?? EngineSettings() }

    func apply(_ settings: EngineSettings) {
        guard let data = try? JSONEncoder().encode(settings),
              let json = String(data: data, encoding: .utf8) else { return }
        json.withCString { sc_engine_set_settings(handle, $0) }
    }

    func save() { sc_engine_save(handle) }

    // MARK: Helpers

    /// Takes ownership of a string returned by the bridge, frees it and decodes it.
    private func decode<T: Decodable>(_ pointer: UnsafeMutablePointer<CChar>?) -> T? {
        guard let pointer else { return nil }
        defer { sc_string_free(pointer) }
        let data = Data(bytes: pointer, count: strlen(pointer))
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
