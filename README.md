<div align="center">

<img src="NotchBuddy/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" width="96" alt="Giraffy icon">

# Giraffy

**Purple Giraffe's lookout for AI coding agents, living in your Mac's notch.**

</div>

Giraffy is a small animated giraffe in the MacBook notch. He keeps watch over your AI coding agent sessions (Claude Code, Codex, Gemini CLI and others) and pops his head up when one needs you. From the notch you can approve or deny permissions, answer an agent's questions, follow its steps and diffs, jump to its terminal, chat, and drop files.

Giraffy is a Purple Giraffe fork of [Coucou](https://github.com/Louis-CFM/coucou) by Louis Raillé, under the MIT License. It is not Coucou and is not made or endorsed by Coucou's author.

> **Status: in development (0.1.0).** Mac only, for internal use at Purple Giraffe. Placeholder icon, no sounds yet.

## What it does

- **Agent sessions in the notch.** Every running agent session with its live steps and diffs.
- **Approvals.** Allow, Deny or Always for a permission request, and answers to AskUserQuestion, with one click. Giraffy never approves anything without that click.
- **Jump to terminal.** Open the terminal tab where an agent is running.
- **Chat.** Ask Claude (or another provider you configure) from the notch.
- **File drop.** Drop a file onto the notch to hand it to an agent.
- **Weekly recap.** A summary of the week's coding sessions, kept on your Mac.
- **GitHub and Vercel**, and the Claude plan usage pill.

## Build

Requirements: macOS 15 or later, Xcode, [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
cd NotchBuddy && xcodegen && xcodebuild -scheme NotchBuddy -configuration Debug build
```

To run it day to day, signed and installed in /Applications:

```bash
GIRAFFY_TEAM_ID=<your Apple team ID> ./scripts/dev-install.sh
```

Never edit `NotchBuddy.xcodeproj` by hand: change `NotchBuddy/project.yml` and run `xcodegen`.

## Privacy

- Secrets (API keys, tokens) are stored in the macOS Keychain only.
- No telemetry. Giraffy only talks to the services you configure.
- Before changing `~/.claude/settings.json`, Giraffy makes a dated backup, shows you the change and waits for your confirmation.

## Versions

| Version | Date | Notes |
|---|---|---|
| 0.1.0 | in development | First Giraffy build: rename, new bundle ID, updater and iPhone link off. See [CHANGELOG.md](CHANGELOG.md). |

## Support

TODO_PG_SUPPORT_URL

## License

The code is under the [MIT License](LICENSE), © 2026 Louis Raillé for Coucou and © 2026 Purple Giraffe for the changes made for Giraffy.

The Coucou name, the Mochi character, Coucou's icon and sounds and its media belong to Louis Raillé and are not used in Giraffy (see [LICENSE-ASSETS.md](LICENSE-ASSETS.md)). Giraffy's name, character and artwork are Purple Giraffe's.

Based on Coucou by Louis Raillé (MIT).
