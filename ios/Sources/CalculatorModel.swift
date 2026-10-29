// CalculatorModel.swift — app state shared by every screen.

import SwiftUI
import UIKit

enum Preview: Equatable {
    case none
    case value([String])
    case error(String)
}

@MainActor
final class CalculatorModel: ObservableObject {
    @Published var input: String = "" {
        didSet {
            if input != oldValue { refreshPreview() }
        }
    }
    @Published private(set) var preview: Preview = .none
    @Published private(set) var history: [HistoryItem] = []
    @Published private(set) var lastError: String?
    @Published var settings: EngineSettings {
        didSet {
            if settings != oldValue { applySettings() }
        }
    }
    @Published var useKeypad: Bool {
        didSet { UserDefaults.standard.set(useKeypad, forKey: Self.keypadKey) }
    }
    /// Bumped to ask the expression field to take focus again (e.g. after a sheet closes).
    @Published private(set) var focusRequest = 0

    /// Set by the expression field so text can be inserted at the cursor.
    var insertHandler: ((String) -> Void)?

    let engine: Engine
    private static let keypadKey = "useKeypad"

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let dataDirectory = support?.appendingPathComponent("SpeedCrunch", isDirectory: true)
        let engine = Engine(dataDirectory: dataDirectory)
        self.engine = engine
        self.settings = engine.settings()
        self.useKeypad = UserDefaults.standard.object(forKey: Self.keypadKey) as? Bool ?? true
        self.history = engine.history()
    }

    // MARK: Editing

    func insert(_ text: String) {
        if let insertHandler {
            insertHandler(text)
        } else {
            input += text
        }
    }

    func clearInput() {
        input = ""
        lastError = nil
    }

    func requestFocus() {
        focusRequest += 1
    }

    // MARK: Evaluation

    func submit() {
        let expression = input.trimmingCharacters(in: .whitespaces)
        guard !expression.isEmpty else { return }

        let result = engine.evaluate(expression)
        if result.ok {
            lastError = nil
            history = engine.history()
            input = ""
            preview = .none
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } else if let error = result.error, !error.isEmpty {
            lastError = error
            preview = .error(error)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private func refreshPreview() {
        lastError = nil
        let expression = input.trimmingCharacters(in: .whitespaces)
        guard !expression.isEmpty else {
            preview = .none
            return
        }
        let result = engine.preview(expression)
        if result.ok, let lines = result.lines, !lines.isEmpty {
            preview = .value(lines)
        } else if let error = result.error, !error.isEmpty {
            preview = .error(error)
        } else {
            preview = .none
        }
    }

    // MARK: History

    func reuse(_ item: HistoryItem) {
        input = item.source
        requestFocus()
    }

    func insertResult(of item: HistoryItem) {
        guard let value = item.resultValue else { return }
        insert(value)
    }

    func delete(_ item: HistoryItem) {
        engine.removeHistoryEntry(at: item.id)
        history = engine.history()
    }

    func clearHistory() {
        engine.clearHistory()
        history = engine.history()
    }

    // MARK: User definitions

    func variables() -> [UserVariable] { engine.variables() }
    func userFunctions() -> [UserFunctionInfo] { engine.userFunctions() }

    func removeVariable(_ name: String) {
        engine.removeVariable(name)
        objectWillChange.send()
    }

    func removeUserFunction(_ name: String) {
        engine.removeUserFunction(name)
        objectWillChange.send()
    }

    // MARK: Settings & lifecycle

    private func applySettings() {
        engine.apply(settings)
        let stored = engine.settings()
        if stored != settings {
            settings = stored
        }
        refreshPreview()
    }

    func save() {
        engine.save()
    }
}
