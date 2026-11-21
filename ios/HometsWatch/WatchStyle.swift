import SwiftUI

/// iPhone 앱(HometsStyle)의 다크 팔레트와 폰트를 워치에 맞게 옮긴 디자인 토큰.
enum WatchStyle {
    static let ink = Color(hex: 0xEAF3F5)
    static let text2 = Color(hex: 0xA8BCC6)
    static let text3 = Color(hex: 0x8298A5)
    static let blue = Color(hex: 0x89A3F0)
    static let mint = Color(hex: 0x7FD1B0)
    static let mintFill = Color(hex: 0x1B3936)
    static let lavender = Color(hex: 0xB9B5F0)
    static let background = Color(hex: 0x101820)
    static let surface = Color(hex: 0x182430)
    static let surfaceRaised = Color(hex: 0x1E2B38)
    static let border = Color(hex: 0x304653)
    static let selected = Color(hex: 0x2C3454)
    static let buttonGradient = LinearGradient(colors: [Color(hex: 0x617CCB), Color(hex: 0x4E67B0)], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let ringGradient = LinearGradient(colors: [Color(hex: 0x89A3F0), Color(hex: 0xB9B5F0)], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let screenBackground = LinearGradient(colors: [Color(hex: 0x131E2A), Color(hex: 0x0B1118)], startPoint: .top, endPoint: .bottom)

    static func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        switch weight {
        case .black, .heavy, .bold: .custom("Barlow-ExtraBold", size: size)
        case .semibold, .medium: .custom("Barlow-SemiBold", size: size)
        default: .custom("Barlow-Regular", size: size)
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255)
    }
}

/// 주 버튼: 그라데이션 캡슐
struct WatchPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(WatchStyle.font(16, .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(WatchStyle.buttonGradient, in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 0.5))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// 보조 버튼: 윤곽선 캡슐
struct WatchGhostButtonStyle: ButtonStyle {
    var tint: Color = WatchStyle.blue
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(WatchStyle.font(14, .semibold))
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, minHeight: 32)
            .background(WatchStyle.surface, in: Capsule())
            .overlay(Capsule().stroke(WatchStyle.border, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
