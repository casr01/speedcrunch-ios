// ExpressionField.swift — the expression editor.
//
// A UITextField wrapped for SwiftUI, because the calculator needs things
// SwiftUI's TextField can't do on iOS 16: inserting at the cursor, a custom
// keyboard (the keypad) and no autocorrect or "smart" punctuation, which
// would corrupt expressions.

import SwiftUI
import UIKit

struct ExpressionField: UIViewRepresentable {
    @ObservedObject var model: CalculatorModel

    func makeCoordinator() -> Coordinator {
        Coordinator(model: model)
    }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.delegate = context.coordinator
        field.font = .monospacedSystemFont(ofSize: 22, weight: .regular)
        field.adjustsFontSizeToFitWidth = true
        field.minimumFontSize = 14
        field.textColor = Theme.uiText
        field.tintColor = Theme.uiAccent
        field.attributedPlaceholder = NSAttributedString(
            string: "Expresión",
            attributes: [.foregroundColor: Theme.uiText.withAlphaComponent(0.35)])
        field.clearButtonMode = .whileEditing
        field.returnKeyType = .go
        field.keyboardType = .asciiCapable
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.spellCheckingType = .no
        field.smartQuotesType = .no
        field.smartDashesType = .no
        field.smartInsertDeleteType = .no
        if #available(iOS 17.0, *) {
            field.inlinePredictionType = .no
        }
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.addTarget(context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)

        context.coordinator.attach(field)
        context.coordinator.applyKeyboardMode(model.useKeypad, reload: false)
        DispatchQueue.main.async { field.becomeFirstResponder() }
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        let coordinator = context.coordinator
        if field.text != model.input {
            field.text = model.input
            let end = field.endOfDocument
            field.selectedTextRange = field.textRange(from: end, to: end)
        }
        coordinator.applyKeyboardMode(model.useKeypad, reload: true)
        if coordinator.lastFocusRequest != model.focusRequest {
            coordinator.lastFocusRequest = model.focusRequest
            DispatchQueue.main.async { field.becomeFirstResponder() }
        }
    }

    static func dismantleUIView(_ field: UITextField, coordinator: Coordinator) {
        coordinator.detach()
    }

    @MainActor
    final class Coordinator: NSObject, UITextFieldDelegate {
        private let model: CalculatorModel
        private weak var field: UITextField?
        private var keypadInput: ClickingInputView?
        private var symbolBar: ClickingInputView?
        private var keypadMode: Bool?
        var lastFocusRequest = 0

        init(model: CalculatorModel) {
            self.model = model
            self.lastFocusRequest = model.focusRequest
        }

        func attach(_ field: UITextField) {
            self.field = field
            model.insertHandler = { [weak self] text in self?.insert(text) }
        }

        func detach() {
            model.insertHandler = nil
        }

        // MARK: Keyboard mode

        func applyKeyboardMode(_ useKeypad: Bool, reload: Bool) {
            guard let field, keypadMode != useKeypad else { return }
            keypadMode = useKeypad
            if useKeypad {
                field.inputView = makeKeypad()
                field.inputAccessoryView = nil
            } else {
                field.inputView = nil
                field.inputAccessoryView = makeSymbolBar()
            }
            if reload, field.isFirstResponder {
                field.reloadInputViews()
            }
        }

        private func makeKeypad() -> UIView {
            if let keypadInput { return keypadInput }
            let model = self.model
            let view = ClickingInputView(height: KeypadView.height) {
                KeypadView(model: model) { [weak self] in self?.handle($0) }
            }
            keypadInput = view
            return view
        }

        private func makeSymbolBar() -> UIView {
            if let symbolBar { return symbolBar }
            let view = ClickingInputView(height: SymbolBarView.height) {
                SymbolBarView { [weak self] in self?.handle($0) }
            }
            symbolBar = view
            return view
        }

        // MARK: Actions

        func handle(_ action: KeyAction) {
            guard let field else { return }
            switch action {
            case .insert(let text):
                insert(text)
            case .backspace:
                field.deleteBackward()
                textChanged(field)
            case .clear:
                field.text = ""
                textChanged(field)
            case .submit:
                model.submit()
            case .cursorLeft:
                moveCursor(by: -1)
            case .cursorRight:
                moveCursor(by: 1)
            case .toggleKeyboard:
                model.useKeypad.toggle()
            case .toggleSecond:
                break
            }
        }

        func insert(_ text: String) {
            guard let field else {
                model.input += text
                return
            }
            if !field.isFirstResponder {
                field.becomeFirstResponder()
            }
            field.insertText(text)
            textChanged(field)
        }

        private func moveCursor(by offset: Int) {
            guard let field, let range = field.selectedTextRange else { return }
            let anchor = offset < 0 ? range.start : range.end
            if !range.isEmpty {
                field.selectedTextRange = field.textRange(from: anchor, to: anchor)
                return
            }
            if let position = field.position(from: anchor, offset: offset) {
                field.selectedTextRange = field.textRange(from: position, to: position)
            }
        }

        @objc func textChanged(_ field: UITextField) {
            let text = field.text ?? ""
            if model.input != text {
                model.input = text
            }
        }

        // MARK: UITextFieldDelegate

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            model.submit()
            return false
        }

        func textFieldShouldClear(_ textField: UITextField) -> Bool {
            model.clearInput()
            return true
        }
    }
}

/// Hosts a SwiftUI view as a keyboard (inputView / inputAccessoryView) and
/// enables the standard keyboard click sound for its buttons.
final class ClickingInputView: UIInputView, UIInputViewAudioFeedback {
    private var host: UIHostingController<AnyView>?

    var enableInputClicksWhenVisible: Bool { true }

    init<Content: View>(height: CGFloat, @ViewBuilder content: () -> Content) {
        super.init(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: height),
                   inputViewStyle: .default)
        // Paint the whole keyboard area, including the home-indicator strip below
        // the keys, so the system's grey keyboard background doesn't show through.
        backgroundColor = Theme.uiSurface
        allowsSelfSizing = true
        autoresizingMask = [.flexibleWidth]

        let host = UIHostingController(rootView: AnyView(content()))
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        if #available(iOS 16.4, *) {
            host.safeAreaRegions = []
        }
        addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: trailingAnchor),
            host.view.topAnchor.constraint(equalTo: topAnchor),
            host.view.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),
            host.view.heightAnchor.constraint(equalToConstant: height)
        ])
        self.host = host
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }
}
