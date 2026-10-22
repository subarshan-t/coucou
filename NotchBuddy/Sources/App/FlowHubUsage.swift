import SwiftUI

/// Usage: what each coding-agent account used (UsageStore), and links for the apps whose usage
/// isn't kept on this Mac. Refreshes once a minute while the page is shown, never otherwise.
struct HubUsagePage: View {
    @ObservedObject private var store = UsageStore.shared

    private var claude: [UsageStore.AccountUsage] { store.accounts.filter { $0.account.kind == .claude } }
    private var codex: [UsageStore.AccountUsage] { store.accounts.filter { $0.account.kind == .codex } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HubHero(page: .usage, title: String(localized: "usage.page.title"),
                        subtitle: String(localized: "usage.page.subtitle"), compact: true)
                refreshRow
                if store.accounts.isEmpty && store.lastRefresh != nil {
                    HubEmptyState(text: String(localized: "usage.empty"), state: .idle)
                }
                if !claude.isEmpty {
                    section(String(localized: "usage.section.claude"))
                    ForEach(claude) { HubUsageCard(usage: $0) }
                }
                if !codex.isEmpty {
                    section(String(localized: "usage.section.codex"))
                    ForEach(codex) { HubUsageCard(usage: $0) }
                }
                section(String(localized: "usage.section.other"))
                otherApps
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .padding(.bottom, 28)
        }
        .onAppear { store.refresh() }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                if Task.isCancelled { break }
                store.refresh()
            }
        }
    }

    private var refreshRow: some View {
        HStack(spacing: 10) {
            if let t = store.lastRefresh {
                Text(String(format: String(localized: "usage.updated %@"), HubUsageFormat.relative(t)))
                    .font(.system(size: 12))
                    .foregroundColor(HubTheme.secondary)
            }
            if store.refreshing { ProgressView().controlSize(.small) }
            Spacer()
            Button(String(localized: "usage.refresh")) { store.refresh() }
                .disabled(store.refreshing)
        }
    }

    private func section(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .kerning(0.6)
            .foregroundColor(HubTheme.muted)
            .padding(.top, 4)
    }

    private var otherApps: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "usage.other.note"))
                .font(.system(size: 12))
                .foregroundColor(HubTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(HubUsageFormat.otherApps, id: \.name) { app in
                HStack {
                    Text(verbatim: app.name).font(.system(size: 13, weight: .medium))
                    Spacer()
                    Button(String(localized: "usage.open")) { NSWorkspace.shared.open(app.url) }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 10).fill(HubTheme.card))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(HubTheme.line))
            }
        }
    }
}

private struct HubUsageCard: View {
    let usage: UsageStore.AccountUsage

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: usage.account.label).font(.system(size: 14, weight: .semibold))
                Spacer()
                Text(verbatim: "~/" + usage.account.directory.lastPathComponent)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(HubTheme.muted)
            }
            if let l = usage.limits, l.fiveHour != nil || l.weekly != nil {
                HStack(spacing: 16) {
                    if let w = l.fiveHour { limit(String(localized: "usage.limit.5h"), w) }
                    if let w = l.weekly { limit(String(localized: "usage.limit.week"), w) }
                }
            } else {
                Text(usage.account.kind == .claude ? String(localized: "usage.limit.none")
                                                   : String(localized: "usage.limit.none.codex"))
                    .font(.system(size: 11.5))
                    .foregroundColor(HubTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(alignment: .bottom, spacing: 20) {
                stat(String(localized: "usage.today"), usage.today)
                stat(String(localized: "usage.week"), usage.week)
                Spacer()
                chart
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(HubTheme.card))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(HubTheme.line))
    }

    private func limit(_ title: String, _ w: UsageWindow) -> some View {
        let pct = w.resetsAt <= Date() ? 0 : w.usedPct
        let color = Color(hex: ClaudePlanGauge.color(for: pct))
        return VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title).font(.system(size: 11.5)).foregroundColor(HubTheme.secondary)
                Spacer()
                Text(verbatim: "\(Int(pct.rounded()))%").font(.system(size: 12, weight: .semibold)).monospacedDigit()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule().fill(color).frame(width: max(4, geo.size.width * pct / 100))
                }
            }
            .frame(height: 6)
            Text(String(format: String(localized: "usage.resets %@"), HubUsageFormat.relative(w.resetsAt)))
                .font(.system(size: 10.5))
                .foregroundColor(HubTheme.muted)
        }
        .frame(maxWidth: .infinity)
    }

    private func stat(_ title: String, _ t: TokenTotals) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 11)).foregroundColor(HubTheme.secondary)
            Text(verbatim: HubUsageFormat.tokens(t.total)).font(.system(size: 20, weight: .semibold)).monospacedDigit()
            Text(String(format: String(localized: "usage.breakdown %@ %@ %@"),
                        HubUsageFormat.tokens(t.input), HubUsageFormat.tokens(t.output),
                        HubUsageFormat.tokens(t.cacheRead + t.cacheWrite)))
                .font(.system(size: 10.5))
                .foregroundColor(HubTheme.muted)
        }
    }

    /// The last 7 days, today on the right.
    private var chart: some View {
        let peak = max(1, usage.days.map(\.total).max() ?? 1)
        return HStack(alignment: .bottom, spacing: 4) {
            ForEach(usage.days.indices, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(i == usage.days.count - 1 ? HubTheme.accent : HubTheme.accent.opacity(0.4))
                    .frame(width: 9, height: max(2, 38 * CGFloat(usage.days[i].total) / CGFloat(peak)))
            }
        }
        .frame(height: 38, alignment: .bottom)
    }
}

enum HubUsageFormat {
    /// 950 → "950", 12 400 → "12.4K", 3 100 000 → "3.1M".
    static func tokens(_ n: Int) -> String {
        switch n {
        case ..<1_000: return "\(n)"
        case ..<1_000_000: return String(format: "%.1fK", Double(n) / 1_000)
        case ..<1_000_000_000: return String(format: "%.1fM", Double(n) / 1_000_000)
        default: return String(format: "%.1fB", Double(n) / 1_000_000_000)
        }
    }

    static func relative(_ d: Date) -> String {
        RelativeDateTimeFormatter().localizedString(for: d, relativeTo: Date())
    }

    struct OtherApp: Sendable { let name: String; let url: URL }

    /// Apps that keep no usage on this Mac: the page links to them instead.
    static let otherApps: [OtherApp] = [
        OtherApp(name: "Claude (app)", url: URL(string: "https://claude.ai/settings/usage")!),
        OtherApp(name: "ChatGPT", url: URL(string: "https://chatgpt.com")!),
        OtherApp(name: "Grok", url: URL(string: "https://grok.com")!),
        OtherApp(name: "Kimi", url: URL(string: "https://www.kimi.com")!),
    ]
}
