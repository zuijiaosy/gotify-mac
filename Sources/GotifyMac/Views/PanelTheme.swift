import SwiftUI

/// 面板与设置界面的共享视觉 token 与轻量交互控件样式。
/// 面板遵循不透明白底 + 浅色高对比度阅读设计（v0.3.1 决策）。
enum PanelTheme {
    // MARK: - Surface
    static let canvas = Color.white
    static let chromeBackground = Color(white: 0.982)
    static let subtleSurface = Color(white: 0.955)
    static let hairline = Color.black.opacity(0.08)
    static let rowHairline = Color.black.opacity(0.055)
    static let rowHover = Color.black.opacity(0.036)
    static let rowSelectedFill = Color.accentColor.opacity(0.11)
    static let rowSelectedBorder = Color.accentColor.opacity(0.22)

    // MARK: - Ink
    static let inkPrimary = Color(white: 0.10)
    static let inkReadTitle = Color(white: 0.22)
    static let inkSecondary = Color(white: 0.42)
    static let inkTertiary = Color(white: 0.54)

    // MARK: - Status
    static func statusColor(for state: AppModel.ConnectionState) -> Color {
        switch state {
        case .connected: Color(red: 0.13, green: 0.68, blue: 0.36)
        case .checking, .reconnecting: Color(red: 0.90, green: 0.52, blue: 0.08)
        case .failed: Color(red: 0.86, green: 0.22, blue: 0.22)
        case .unconfigured: Color(white: 0.56)
        }
    }
}

extension PriorityTier {
    /// 列表与详情徽章在纯白底上的精调语义色，兼顾辨识度与柔和克制
    var dotColor: Color {
        switch self {
        case .critical: Color(red: 0.88, green: 0.22, blue: 0.22)
        case .high: Color(red: 0.89, green: 0.49, blue: 0.06)
        case .normal: Color(red: 0.14, green: 0.49, blue: 0.92)
        case .low: Color(white: 0.58)
        }
    }

    var badgeForeground: Color {
        switch self {
        case .critical: Color(red: 0.74, green: 0.14, blue: 0.16)
        case .high: Color(red: 0.71, green: 0.37, blue: 0.02)
        case .normal: Color(red: 0.10, green: 0.39, blue: 0.78)
        case .low: Color(white: 0.42)
        }
    }

    var badgeBackground: Color {
        switch self {
        case .critical: Color(red: 0.88, green: 0.22, blue: 0.22).opacity(0.10)
        case .high: Color(red: 0.89, green: 0.49, blue: 0.06).opacity(0.11)
        case .normal: Color(red: 0.14, green: 0.49, blue: 0.92).opacity(0.10)
        case .low: Color(white: 0.55).opacity(0.11)
        }
    }

    var badgeBorder: Color {
        dotColor.opacity(0.24)
    }
}

/// 面板工具栏紧凑操作按钮（如「全部已读」）：克制的浅色描边胶囊，清晰区分可用/悬停/禁用态
struct PanelToolbarButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(isEnabled ? PanelTheme.inkPrimary : PanelTheme.inkTertiary)
            .padding(.horizontal, 9)
            .frame(height: 24)
            .background(
                backgroundColor(isPressed: configuration.isPressed),
                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(
                        isEnabled ? Color.black.opacity(isHovered ? 0.16 : 0.10) : Color.black.opacity(0.06),
                        lineWidth: 0.75
                    )
            )
            .opacity(isEnabled ? 1 : 0.65)
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .onHover { isHovered = $0 }
            .animation(.easeOut(duration: 0.12), value: isHovered)
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        guard isEnabled else { return Color(white: 0.965) }
        if isPressed { return Color.black.opacity(0.09) }
        if isHovered { return Color.black.opacity(0.045) }
        return Color.white
    }
}

/// 轻量无框操作按钮（如详情底部「返回」「复制内容」），带悬停底色反馈
struct PanelSubtleButtonStyle: ButtonStyle {
    var foreground: Color = PanelTheme.inkSecondary
    var hoverForeground: Color = PanelTheme.inkPrimary
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(isHovered && isEnabled ? hoverForeground : foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                backgroundColor(isPressed: configuration.isPressed),
                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
            )
            .opacity(isEnabled ? 1 : 0.45)
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .onHover { isHovered = $0 }
            .animation(.easeOut(duration: 0.12), value: isHovered)
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        guard isEnabled else { return .clear }
        if isPressed { return Color.black.opacity(0.09) }
        if isHovered { return Color.black.opacity(0.05) }
        return .clear
    }
}
