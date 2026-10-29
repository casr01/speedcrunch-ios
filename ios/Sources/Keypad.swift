// Keypad.swift — on-screen scientific keypad, used as the text field's
// keyboard (inputView), plus the slim symbol bar shown above the system keyboard.

import SwiftUI
import UIKit

enum KeyAction: Equatable {
    case insert(String)
    case backspace
    case clear
    case submit
    case cursorLeft
    case cursorRight
    case toggleSecond
    case toggleKeyboard
}

enum KeyStyle {
    case digit, operation, function, utility, primary
}

struct KeyDefinition {
    let label: String
    let action: KeyAction
    let style: KeyStyle
    var systemImage: String? = nil

    static func digit(_ d: String) -> KeyDefinition { .init(label: d, action: .insert(d), style: .digit) }
    static func op(_ label: String, _ text: String) -> KeyDefinition { .init(label: label, action: .insert(text), style: .operation) }
    static func fn(_ label: String, _ text: String) -> KeyDefinition { .init(label: label, action: .insert(text), style: .function) }
}

struct KeypadView: View {
    @ObservedObject var model: CalculatorModel
    let onAction: (KeyAction) -> Void
    @State private var second = false

    static let height: CGFloat = 300

    private var decimal: String { model.settings.decimalSeparator }

    private var rows: [[KeyDefinition]] {
        let s = second
        let backspace = KeyDefinition(label: "", action: .backspace, style: .utility, systemImage: "delete.left")
        let left = KeyDefinition(label: "", action: .cursorLeft, style: .utility, systemImage: "chevron.left")
        let right = KeyDefinition(label: "", action: .cursorRight, style: .utility, systemImage: "chevron.right")
        let keyboard = KeyDefinition(label: "", action: .toggleKeyboard, style: .utility, systemImage: "keyboard")
        let clear = KeyDefinition(label: "AC", action: .clear, style: .utility)
        let enter = KeyDefinition(label: "", action: .submit, style: .primary, systemImage: "return")
        let secondKey = KeyDefinition(label: "2nd", action: .toggleSecond, style: s ? .primary : .utility)

        let functions: [KeyDefinition] = s
            ? [secondKey, KeyDefinition.fn("asin", "arcsin("), KeyDefinition.fn("acos", "arccos("),
               KeyDefinition.fn("atan", "arctan("), KeyDefinition.fn("eˣ", "exp("), KeyDefinition.fn("∛", "cbrt(")]
            : [secondKey, KeyDefinition.fn("sin", "sin("), KeyDefinition.fn("cos", "cos("),
               KeyDefinition.fn("tan", "tan("), KeyDefinition.fn("ln", "ln("), KeyDefinition.fn("√", "sqrt(")]

        let symbols: [KeyDefinition] = s
            ? [KeyDefinition.op("[", "["), KeyDefinition.op("]", "]"), KeyDefinition.op("x²", "^2"),
               KeyDefinition.op("%", "%"), KeyDefinition.fn("e", "e"), backspace]
            : [KeyDefinition.op("(", "("), KeyDefinition.op(")", ")"), KeyDefinition.op("^", "^"),
               KeyDefinition.op("!", "!"), KeyDefinition.fn("π", "π"), backspace]

        let row7: [KeyDefinition] = [
            KeyDefinition.digit("7"), KeyDefinition.digit("8"), KeyDefinition.digit("9"),
            KeyDefinition.op("÷", "/"), s ? KeyDefinition.fn("i", "i") : KeyDefinition.fn("ans", "ans"), left
        ]
        let row4: [KeyDefinition] = [
            KeyDefinition.digit("4"), KeyDefinition.digit("5"), KeyDefinition.digit("6"),
            KeyDefinition.op("×", "*"), s ? KeyDefinition.fn("y", "y") : KeyDefinition.fn("x", "x"), right
        ]
        let row1: [KeyDefinition] = [
            KeyDefinition.digit("1"), KeyDefinition.digit("2"), KeyDefinition.digit("3"),
            KeyDefinition.op("−", "-"), s ? KeyDefinition.op("→", "→") : KeyDefinition.op("=", "="), keyboard
        ]
        let row0: [KeyDefinition] = [
            KeyDefinition.digit("0"), KeyDefinition.digit(decimal), KeyDefinition.op(";", ";"),
            KeyDefinition.op("+", "+"), clear, enter
        ]
        return [functions, symbols, row7, row4, row1, row0]
    }

    var body: some View {
        VStack(spacing: 6) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 6) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, key in
                        KeyButton(key: key) { handle(key.action) }
                    }
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.surface)
    }

    private func handle(_ action: KeyAction) {
        if action == .toggleSecond {
            second.toggle()
            return
        }
        onAction(action)
        // "2nd" applies to a single key press, like on a hardware calculator.
        if case .insert = action, second {
            second = false
        }
    }
}

struct KeyButton: View {
    let key: KeyDefinition
    let action: () -> Void

    var body: some View {
        Button {
            UIDevice.current.playInputClick()
            action()
        } label: {
            Group {
                if let image = key.systemImage {
                    Image(systemName: image)
                        .font(.system(size: 18, weight: .medium))
                } else {
                    Text(key.label)
                        .font(.system(size: key.label.count > 3 ? 15 : 19,
                                      weight: key.style == .digit ? .regular : .medium,
                                      design: .rounded))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(KeyPressStyle())
        .accessibilityLabel(accessibilityText)
    }

    private var foreground: Color {
        switch key.style {
        case .digit: return Theme.text
        case .operation: return Theme.operatorColor
        case .function: return Theme.function
        case .utility: return Theme.secondary
        case .primary: return Theme.background
        }
    }

    private var background: Color {
        switch key.style {
        case .digit: return Theme.keyStrong
        case .primary: return Theme.comment
        default: return Theme.keyFill
        }
    }

    private var accessibilityText: String {
        switch key.action {
        case .backspace: return "Borrar"
        case .cursorLeft: return "Mover cursor a la izquierda"
        case .cursorRight: return "Mover cursor a la derecha"
        case .toggleKeyboard: return "Cambiar a teclado de texto"
        case .submit: return "Calcular"
        case .clear: return "Borrar todo"
        default: return key.label
        }
    }
}

private struct KeyPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}

/// Bar shown above the system keyboard with the symbols that are awkward to
/// reach there, and a button to go back to the calculator keypad.
struct SymbolBarView: View {
    let onAction: (KeyAction) -> Void

    static let height: CGFloat = 46

    private let symbols: [(String, String)] = [
        ("(", "("), (")", ")"), ("^", "^"), (";", ";"), ("=", "="), ("→", "→"),
        ("[", "["), ("]", "]"), ("π", "π"), ("ans", "ans"), ("√", "sqrt("), ("!", "!"),
        ("?", "? ")
    ]

    var body: some View {
        HStack(spacing: 0) {
            Button {
                onAction(.toggleKeyboard)
            } label: {
                Image(systemName: "square.grid.3x3.fill")
                    .font(.system(size: 18))
                    .frame(width: 48, height: Self.height)
            }
            .accessibilityLabel("Cambiar a teclado de calculadora")

            Divider().frame(height: 24)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(symbols.enumerated()), id: \.offset) { _, symbol in
                        let (label, text) = symbol
                        Button {
                            UIDevice.current.playInputClick()
                            onAction(.insert(text))
                        } label: {
                            Text(label)
                                .font(.system(size: 17, weight: .medium, design: .rounded))
                                .frame(minWidth: 36, minHeight: 34)
                                .padding(.horizontal, 4)
                                .background(Theme.keyFill, in: RoundedRectangle(cornerRadius: 7))
                        }
                    }
                }
                .padding(.horizontal, 8)
            }
        }
        .foregroundStyle(Theme.text)
        .frame(height: Self.height)
        .background(Theme.surface)
    }
}
