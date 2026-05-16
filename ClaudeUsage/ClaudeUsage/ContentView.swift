import SwiftUI
import Core

struct ContentView: View {
    @State private var codexState: CodexState?

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "gauge.with.dots.needle.50percent")
                    .font(.title3)
                    .foregroundStyle(.tint)
                Text("Claude Usage")
                    .font(.headline)
                Spacer()
                Text("v\(version)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            if let state = codexState {
                CodexGaugeRow(label: "Codex 5h", window: state.primary)
                if let secondary = state.secondary {
                    CodexGaugeRow(label: "Codex Week", window: secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text("No Codex usage data yet.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text("Waiting for first scan or new session…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(width: 320, height: 170, alignment: .topLeading)
        .task {
            while !Task.isCancelled {
                codexState = try? await Database.shared.latestCodexState()
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }
}

private struct CodexGaugeRow: View {
    let label: String
    let window: RateLimitWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(label)
                    .font(.callout)
                Spacer()
                Text(String(format: "%.0f%%", window.usedPercent))
                    .font(.callout.bold())
                    .foregroundStyle(barColor)
                Text("·")
                    .foregroundStyle(.secondary)
                Text(resetCountdown)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            ProgressView(value: min(window.usedPercent / 100, 1.0))
                .progressViewStyle(.linear)
                .tint(barColor)
        }
    }

    private var barColor: Color {
        switch window.usedPercent {
        case ..<60: return .green
        case ..<85: return .orange
        default: return .red
        }
    }

    private var resetCountdown: String {
        let interval = window.resetsAt.timeIntervalSinceNow
        if interval <= 0 { return "due" }
        let totalMinutes = Int(interval / 60)
        let days = totalMinutes / (24 * 60)
        let hours = (totalMinutes / 60) % 24
        let minutes = totalMinutes % 60
        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}

#Preview {
    ContentView()
}
