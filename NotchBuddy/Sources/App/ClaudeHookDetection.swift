import Foundation

/// True when a parsed ~/.claude/settings.json routes Claude Code SessionStart events to Giraffy.
///
/// Kept free of file access so it can be tested on fixtures instead of the real settings file.
/// Matched on the command text: Giraffy's hook runs ~/Library/Application Support/Giraffy/nb-hook
/// (or ~/.claude/giraffy/nb-hook). Hooks written by an upstream Coucou install (NotchBuddy,
/// ~/.claude/coucou) are not Giraffy's and are never counted or touched.
func coucouHooksPresent(inSettings settings: [String: Any]) -> Bool {
    guard let hooks = settings["hooks"] as? [String: Any],
          let sessionStart = hooks["SessionStart"] as? [[String: Any]] else { return false }
    return sessionStart.contains { group in
        (group["hooks"] as? [[String: Any]])?.contains { hook in
            guard let command = hook["command"] as? String else { return false }
            return command.contains("Giraffy") || command.contains("giraffy")
        } ?? false
    }
}
