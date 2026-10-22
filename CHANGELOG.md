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
- **Silent for now** — Coucou's sounds are gone and sounds are off by default until PG supplies Giraffy's own. Files you put in `~/Library/Application Support/Giraffy/Sounds` still play.
- **Mac only** — the iPhone app, its widgets, the iPhone link and its relay, the App Store build, and the Windows, Linux and Android apps are not part of Giraffy.
