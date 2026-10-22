# Changelog

Giraffy's history starts here. Earlier history belongs to Coucou, the project Giraffy is based on: see [github.com/Louis-CFM/coucou](https://github.com/Louis-CFM/coucou/blob/main/CHANGELOG.md).

## 0.1.0 — in development

First Giraffy build, forked from Coucou 0.5.2.

- **Giraffy** — new name everywhere you see it (menus, Settings, notifications, the chat assistant, 14 languages), new bundle ID `au.com.purplegiraffe.Giraffy`, and a placeholder purple giraffe icon. Giraffy keeps its own Keychain items, preferences, Application Support folder (`~/Library/Application Support/Giraffy`) and logs, so it never mixes with a Coucou install on the same Mac.
- **Claude Code hooks** — Giraffy's hooks run from Giraffy's own folder and Giraffy only ever touches its own hooks in `~/.claude/settings.json`, never Coucou's.
- **About** — Settings → General → About shows the version and the credit to Coucou.
- **Updates off** — the updater no longer checks the Coucou releases; it stays off until Giraffy has its own release feed.
- **PG purple** — Giraffy's own accent (the Flow window, the dictation pill, buttons) comes from one theme, `GiraffyTheme`; agent and service pill colours and the status colours are unchanged.
- **Giraffy himself** — a new character drawn in code: he rises on his neck, stretches tall with his ears up when an agent needs your OK, droops when something fails, sleeps low in the notch, and swallows the files you drop on him.
- **Sounds** — `scripts/dev-install.sh` copies Coucou's sounds into `~/Library/Application Support/Giraffy/Sounds` on your Mac (personal use only; they are not in the app or the repo), and sound is on by default. Your own files in that folder win.
- **Approvals log** — a new Approvals page in the Giraffy window lists every permission your agents asked for: when, which agent and project, the tool and command or file, and whether it was allowed, denied, always allowed, answered in the terminal or timed out. Filter by agent and decision, export to CSV. Stored only on your Mac (`~/Library/Application Support/Giraffy/Audit`, private to your account), with likely secrets in commands masked before they are written. On by default; keep entries 30 days, 90 days or forever.
- **Fewer integrations** — WhatsApp, crypto, portfolio, Apple Music, Spotify, Stripe, n8n, Resend, Notion, Cal.com, the voice wake word and the outfits are switched off and make no network calls.
- **Mac only** — the iPhone app, its widgets, the iPhone link and its relay, the App Store build, and the Windows, Linux and Android apps are not part of Giraffy.
