<h1 align="center">Time Manager</h1>

<p align="center">
  <img src="fastlane/metadata/android/en-US/images/icon.png" alt="Time Manager icon" width="128">
</p>

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

## Screenshots

<p align="center">
  <img src="fastlane/metadata/android/en-US/images/phoneScreenshots/1_todo.png" alt="Daily to-do list" width="200">
  <img src="fastlane/metadata/android/en-US/images/phoneScreenshots/2_goals.png" alt="Goals with sub-goals" width="200">
  <img src="fastlane/metadata/android/en-US/images/phoneScreenshots/3_habits.png" alt="Weekly habit grid" width="200">
  <img src="fastlane/metadata/android/en-US/images/phoneScreenshots/4_timer.png" alt="Focus timer" width="200">
</p>

## Install

**Android (7.0 or newer):** download `time-manager.apk` from the
[latest release](https://github.com/Koc13/TimeManager/releases/latest) and
open it on your phone. Android asks you to allow installing apps from your
browser or file manager the first time.

On first start, pick (or create) the folder that should hold your data. To
sync it with other devices, choose a folder that Syncthing shares.

Release APKs are signed with this certificate (SHA-256):
`cd:af:6d:24:6b:9b:a3:c7:b3:95:2f:fa:51:30:78:df:42:12:25:60:86:ab:3b:5a:c3:27:ba:de:35:40:88:2c`.
An APK from another source (such as F-Droid, once available) is signed
differently, so switching between them means uninstalling first. Your data
folder is kept.

**Linux:** build from source (below) for now.

## Building

Needs Flutter 3.47 (stable).

```sh
flutter pub get
flutter test
flutter run -d linux          # or an Android device id
flutter build apk --release   # Android
flutter build linux --release # Linux bundle in build/linux/x64/release/bundle
```

## License

GPL-3.0-or-later (see `LICENSE`). Inter and Phosphor fonts are bundled under
their own licences in `assets/fonts/`.
