import SwiftUI

struct TimerMinimalNotchView: View {
    let source: TimerSource

    init(source: TimerSource) {
        self.source = source
    }

    init(timerViewModel: TimerViewModel) {
        self.source = .system(timerViewModel)
    }

    var body: some View {
        Group {
            switch source {
            case .system(let vm):
                TimerMinimalNotchViewInternal(source: source, viewModel: vm)
                
            case .local(let vm):
                TimerMinimalNotchViewInternal(source: source, viewModel: vm)
            }
        }
    }
}

private struct TimerMinimalNotchViewInternal<VM: ObservableObject>: View {
    let source: TimerSource
    
    @Environment(\.notchScale) private var scale
    @Environment(\.isDynamicIsland) private var isDynamicIsland
    @ObservedObject var viewModel: VM

    /// A Label strip is shown only on the physical notch: on Dynamic Island a title would be
    /// truncated to three letters, so the minimal pill stays compact there (spec #13).
    private var showsLabel: Bool {
        !isDynamicIsland && source.label != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TimerCompactIndicatorView(source: source)

                Spacer()

                TimerCountdownText(source: source)
            }
            .padding(.vertical, 10)
            .padding(.leading, isDynamicIsland ? 4.scaled(by: scale) : 14.scaled(by: scale))
            .padding(.trailing, isDynamicIsland ? 6.scaled(by: scale) : 14.scaled(by: scale))

            if showsLabel, let label = source.label {
                // Centred across the full width, under the encoche — the only free zone.
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)
            }
        }
    }
}
