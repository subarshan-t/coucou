import SwiftUI

/// Approvals: every permission an agent asked for and what was decided (ApprovalAuditLog).
/// Filter by agent and decision, export to CSV. The log stays on this Mac.
struct HubApprovalsPage: View {
    @ObservedObject private var log = ApprovalAuditLog.shared
    @State private var agent: String? = nil
    @State private var decision: AuditDecision? = nil

    private var rows: [AuditEntry] { AuditLogic.filtered(log.entries, agent: agent, decision: decision) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HubHero(page: .approvals, title: String(localized: "audit.page.title"),
                    subtitle: String(localized: "audit.page.subtitle"), compact: true)
            settingsRow
            if log.enabled {
                filterRow
                if rows.isEmpty {
                    HubEmptyState(text: String(localized: "audit.empty"), state: .idle)
                } else {
                    list
                }
            } else {
                HubEmptyState(text: String(localized: "audit.disabled"))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 28)
        .padding(.top, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { log.load() }
    }

    private var settingsRow: some View {
        HStack(spacing: 16) {
            Toggle(String(localized: "audit.setting.enabled"), isOn: $log.enabled)
                .toggleStyle(.switch)
            Picker(String(localized: "audit.setting.retention"), selection: $log.retention) {
                Text(String(localized: "audit.retention.30")).tag(AuditRetention.days30)
                Text(String(localized: "audit.retention.90")).tag(AuditRetention.days90)
                Text(String(localized: "audit.retention.forever")).tag(AuditRetention.forever)
            }
            .pickerStyle(.menu)
            .fixedSize()
            .disabled(!log.enabled)
            Spacer()
        }
        .font(.system(size: 13))
        .foregroundColor(HubTheme.body)
    }

    private var filterRow: some View {
        HStack(spacing: 12) {
            Picker(String(localized: "audit.filter.agent"), selection: $agent) {
                Text(String(localized: "audit.filter.all")).tag(String?.none)
                ForEach(log.agents, id: \.self) { Text(verbatim: $0).tag(String?.some($0)) }
            }
            .pickerStyle(.menu)
            .fixedSize()
            Picker(String(localized: "audit.filter.decision"), selection: $decision) {
                Text(String(localized: "audit.filter.all")).tag(AuditDecision?.none)
                ForEach(AuditDecision.allCases, id: \.self) { d in
                    Text(Self.label(d)).tag(AuditDecision?.some(d))
                }
            }
            .pickerStyle(.menu)
            .fixedSize()
            Spacer()
            Text(String(format: String(localized: "audit.count %lld"), Int64(rows.count)))
                .font(.system(size: 12))
                .foregroundColor(HubTheme.secondary)
                .monospacedDigit()
            Button(String(localized: "audit.export")) { log.exportCSV(rows) }
                .disabled(rows.isEmpty)
        }
        .font(.system(size: 13))
    }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 6) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, e in
                    HubApprovalRow(entry: e)
                }
            }
            .padding(.bottom, 20)
        }
        .scrollIndicators(.automatic)
    }

    static func label(_ d: AuditDecision) -> String {
        switch d {
        case .allow:    return String(localized: "audit.decision.allow")
        case .deny:     return String(localized: "audit.decision.deny")
        case .always:   return String(localized: "audit.decision.always")
        case .terminal: return String(localized: "audit.decision.terminal")
        case .timeout:  return String(localized: "audit.decision.timeout")
        }
    }

    static func color(_ d: AuditDecision) -> Color {
        switch d {
        case .allow, .always: return HubTheme.green
        case .deny:           return HubTheme.red
        case .timeout:        return Color(hex: "#F5A524")
        case .terminal:       return HubTheme.secondary
        }
    }
}

private struct HubApprovalRow: View {
    let entry: AuditEntry

    nonisolated(unsafe) private static let time: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(verbatim: entry.agent).font(.system(size: 12.5, weight: .semibold))
                    Text(verbatim: "·").foregroundColor(HubTheme.muted)
                    Text(verbatim: entry.project).font(.system(size: 12.5)).foregroundColor(HubTheme.secondary)
                    Text(verbatim: "·").foregroundColor(HubTheme.muted)
                    Text(verbatim: entry.tool).font(.system(size: 12.5)).foregroundColor(HubTheme.secondary)
                }
                Text(verbatim: entry.target.isEmpty ? entry.tool : entry.target)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(HubTheme.body)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                Text(verbatim: Self.time.string(from: entry.timestamp)
                     + (entry.via == .notch ? " · " + String(localized: "audit.via.notch")
                        : entry.via == .shortcut ? " · " + String(localized: "audit.via.shortcut") : ""))
                    .font(.system(size: 11))
                    .foregroundColor(HubTheme.muted)
            }
            Spacer(minLength: 8)
            Text(HubApprovalsPage.label(entry.decision))
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundColor(HubApprovalsPage.color(entry.decision))
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Capsule().fill(HubApprovalsPage.color(entry.decision).opacity(0.14)))
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(HubTheme.card))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(HubTheme.line))
    }
}
