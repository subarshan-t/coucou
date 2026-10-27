import AppKit
import UniformTypeIdentifiers
import Foundation

/// The app side of the approval audit log (ApprovalAudit.swift): records decisions from
/// HookServer, keeps the settings, and feeds the Approvals page. Local only.
@MainActor
final class ApprovalAuditLog: ObservableObject {
    static let shared = ApprovalAuditLog()

    /// On by default (brief): the log is the point.
    @Published var enabled: Bool = UserDefaults.standard.object(forKey: "auditEnabled") as? Bool ?? true {
        didSet { UserDefaults.standard.set(enabled, forKey: "auditEnabled") }
    }
    @Published var retention: AuditRetention =
        AuditRetention(rawValue: UserDefaults.standard.object(forKey: "auditRetentionDays") as? Int ?? 90) ?? .days90 {
        didSet {
            UserDefaults.standard.set(retention.rawValue, forKey: "auditRetentionDays")
            prune()
        }
    }
    @Published private(set) var entries: [AuditEntry] = []

    private let file = AuditFile(directory: AuditFile.defaultDirectory)
    private var loaded = false

    private init() {}

    /// One decision. `target` is the command or file; it is redacted before it is written.
    func record(pillId: String, project: String, tool: String, target: String,
                decision: AuditDecision, via: AuditVia) {
        guard enabled else { return }
        let entry = AuditEntry(timestamp: Date(),
                               agent: PillCatalog.definition(for: pillId)?.name ?? pillId,
                               project: project.isEmpty ? "—" : project,
                               tool: tool,
                               target: AuditRedactor.redact(target),
                               decision: decision, via: via)
        let file = self.file
        Task.detached(priority: .utility) {
            do { try file.append(entry) } catch { appendAppLog("nb.log", "[Audit] write failed: \(error)") }
        }
        if loaded { entries.insert(entry, at: 0) }
    }

    /// Reads the file (newest first). Called when the Approvals page opens.
    func load() {
        prune()
        entries = file.readAll().reversed()
        loaded = true
    }

    func prune() { file.prune(retention: retention) }

    var agents: [String] { Array(Set(entries.map(\.agent))).sorted() }

    /// Asks where to save, then writes the given entries as CSV.
    func exportCSV(_ rows: [AuditEntry]) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "giraffy-approvals.csv"
        panel.allowedContentTypes = [.commaSeparatedText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? AuditLogic.csv(rows).write(to: url, atomically: true, encoding: .utf8)
    }
}
