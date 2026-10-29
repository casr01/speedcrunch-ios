// Theme.swift — colours taken from SpeedCrunch's own schemes:
// Duskfox (its default, dark) and Dawnfox (its light sibling).
// Source: src/resources/color-schemes/{Duskfox,Dawnfox}.json upstream.

import SwiftUI
import UIKit

enum Theme {
    static let background = dynamic(dark: 0x232136, light: 0xFAF4ED)
    static let surface    = dynamic(dark: 0x2A273F, light: 0xF2E9E1)
    static let keyFill    = dynamic(dark: 0x393552, light: 0xE4DCD3)
    static let keyStrong  = dynamic(dark: 0x44415A, light: 0xD7CEC4)
    static let text       = dynamic(dark: 0xE0DEF4, light: 0x544F73)
    static let secondary  = dynamic(dark: 0x908CAA, light: 0x797593)
    static let result     = dynamic(dark: 0xA3BE8C, light: 0x618774)
    static let number     = dynamic(dark: 0xF6C177, light: 0xEA9D34)
    static let function   = dynamic(dark: 0x9CCFD8, light: 0x56949F)
    static let operatorColor = dynamic(dark: 0xEA9A97, light: 0xD7827E)
    static let variable   = dynamic(dark: 0x569FBA, light: 0x286983)
    static let comment    = dynamic(dark: 0xC4A7E7, light: 0x907AA9)
    static let error      = dynamic(dark: 0xEB6F92, light: 0xB4637A)

    static var uiBackground: UIColor { uiDynamic(dark: 0x232136, light: 0xFAF4ED) }
    static var uiText: UIColor { uiDynamic(dark: 0xE0DEF4, light: 0x544F73) }
    static var uiAccent: UIColor { uiDynamic(dark: 0xC4A7E7, light: 0x907AA9) }
    static var uiSurface: UIColor { uiDynamic(dark: 0x2A273F, light: 0xF2E9E1) }

    private static func dynamic(dark: UInt32, light: UInt32) -> Color {
        Color(uiDynamic(dark: dark, light: light))
    }

    private static func uiDynamic(dark: UInt32, light: UInt32) -> UIColor {
        UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        }
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}
