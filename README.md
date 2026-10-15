# Time Manager

To-do lists, goals, habits and a focus timer for Android and Linux. Everything
is stored as Markdown files with YAML frontmatter in a folder you choose, so
Syncthing can sync it between devices and Obsidian can read it. There is no
account and no server.

- Daily, weekly and monthly to-do lists, with a review of unfinished tasks
- Recurring tasks, deadlines and reminders
- Measurable goals with sub-goals and derived progress
- Habits on a weekly heat-map grid
- A Pomodoro timer that logs time to goals and habits
- A journal and review notes for each day, week and month

Licensed under GPL-3.0-or-later (see `LICENSE`). Inter and Phosphor fonts are
bundled under their own licences in `assets/fonts/`.

## Building

Needs Flutter 3.47 (stable).

```sh
flutter pub get
flutter test
flutter run -d linux          # or an Android device id
flutter build apk --release   # Android
flutter build linux --release # Linux bundle in build/linux/x64/release/bundle
```
