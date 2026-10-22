# Giraffy — guide for AI coding agents

Giraffy is a native macOS app (`NotchBuddy/`), Purple Giraffe's fork of Coucou (MIT). Giraffy, a small animated purple giraffe living in the MacBook notch, shows AI coding agent sessions (Claude Code, Codex, Gemini CLI and more) and a few integrations, and lets the user approve, answer, chat and drop files from the notch. Mac only.

## Where things are
- `NotchBuddy/Sources/App/` — the Mac app's Swift code. `NotchBuddy/Sources/CoucouKit/` — shared models (the character's BotEngine, pills, diff, island types). Folder and type names that still say Coucou, Mochi or NotchBuddy are internal and can be renamed in a clean-up pass.
- `NotchBuddy/Sources/CoucouKit/PillCatalog.swift` — single source of truth for all declared pills (workspace tools, agents, AI providers, services). Every pill ID, color, category and subtitle lives here.
- `NotchBuddy/project.yml` — XcodeGen project (never edit the `.xcodeproj` by hand). One target, `NotchBuddy`, which builds `Giraffy.app`.
- `NotchBuddy/Resources/Localizable.xcstrings` — 14 languages. New strings: English first; other languages may fall back to English.
- `docs/SPEC.md`, `docs/INTEGRATIONS.md` — upstream behaviour notes (in French), still mostly accurate.
- `design/prototype/` — upstream prototype, private reference only: never ship it or copy its look.
- `scripts/test-*.sh`, `scripts/test-localization.py`, `tests/` — tests. CI (`.github/workflows/build.yml`, macOS) runs them and builds the app.

## Build
```
cd NotchBuddy && xcodegen && xcodebuild -scheme NotchBuddy -configuration Debug build
```
To run it day to day on the Mac (signed, permissions kept across builds): `GIRAFFY_TEAM_ID=<team> ./scripts/dev-install.sh`.

## Licence rules (non-negotiable)
- Never use the names "Coucou" or "Mochi" in anything a user sees, nor the Mochi character's look, Coucou's icons, its 28 sounds, or its media (`LICENSE-ASSETS.md`). Giraffy must not suggest it is Coucou or endorsed by its author.
- Keep `LICENSE` and both copyright lines, and the "Based on Coucou by Louis Raillé (MIT)" credit in Settings → About and the README.
- Never call upstream infrastructure: no Coucou GitHub releases, no Coucou relay. Support links use `TODO_PG_SUPPORT_URL` until PG supplies one.

## Rules
- Swift 6, SwiftUI + AppKit. No new third-party dependencies. The character is drawn in code (`Canvas` + `TimelineView`), no Rive/Lottie/images.
- Secrets live in the Keychain, never on disk or in git.
- No telemetry. Network calls only to services the user configured.
- Never block Claude Code: if the app doesn't answer, the hook exits immediately.
- Never overwrite `~/.claude/settings.json`: dated backup, merge, show the diff, write only after the user confirms. Only ever touch Giraffy's own hooks (commands containing `Giraffy` or `giraffy`), never Coucou's.
- Never send an email or approve a Claude Code or Codex permission without an explicit click.
- Performance: 0 % CPU when the island is hidden.
- Keep the bundle identifier `au.com.purplegiraffe.Giraffy` (Keychain items, preferences and permissions depend on it).
- Pill IDs are stable contract values (Keychain, UserDefaults, hook routing): once Giraffy ships, never rename an existing pill ID.
- Keep per-agent and per-service pill colours from `PillCatalog.swift`; only the app's own accent follows the PG theme.
- New views follow the existing app style.
- Every release adds its CHANGELOG.md section, a row in the README Versions table, and commits the regenerated Info.plist with the new version.
- Commit after each phase of work with a clear message, and run the test scripts that apply.
