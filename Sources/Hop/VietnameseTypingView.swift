import SwiftUI

/// Vietnamese typing module: one line. The chips ARE the switch — a method
/// turns typing on, "off" turns it off — the way the keyboard lock's lengths
/// start the lock.
struct VietnameseTypingView: View {
    @ObservedObject var typing: VietnameseTypingController
    let lang: AppLanguage

    var body: some View {
        HStack(spacing: 6) {
            ModuleMarkIcon(symbol: "character.cursor.ibeam",
                           color: typing.isBlocked ? Theme.accentOrange
                               : typing.isActive ? Theme.editing : Theme.textSecondary)
            Text(L10n.t(.vietnameseLabel, lang))
                .font(Theme.mono(11))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 6)
            HStack(spacing: 5) {
                ForEach(VietnameseTypingController.Mode.allCases, id: \.self) { chip($0) }
            }
        }
    }

    private func chip(_ mode: VietnameseTypingController.Mode) -> some View {
        let selected = typing.mode == mode
        return Button {
            typing.select(mode)
        } label: {
            Text(title(mode))
                .font(Theme.mono(11, weight: selected ? .semibold : .medium))
                .foregroundStyle(selected ? (typing.isBlocked && mode != .off ? Theme.accentOrange : Theme.editing)
                                          : Theme.textSecondary)
                .lineLimit(1)
                .padding(.horizontal, 3)
                .frame(minWidth: 18, minHeight: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverHighlight(3)
    }

    /// Telex and VNI are the names of the methods, whatever the language.
    private func title(_ mode: VietnameseTypingController.Mode) -> String {
        switch mode {
        case .off: return L10n.t(.vietnameseOff, lang)
        case .telex: return "Telex"
        case .vni: return "VNI"
        }
    }
}
