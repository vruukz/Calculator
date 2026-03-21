# Calculator

A scientific calculator built with Flutter, designed to run on **Windows**, **Linux**, and **Android** from a single codebase.

---

## Features

- **Standard mode** — basic arithmetic (+, −, ×, ÷)
- **Scientific mode** — sin, cos, tan (+ inverses), ln, log, √, x², x³, xʸ, 1/x, n!, π, e, abs
- **DEG / RAD** toggle for trigonometric functions
- **INV** toggle for inverse trig functions
- **History panel** — slides in from the right, tap any entry to reuse the result
- **Keyboard support** — full numpad and keyboard input
- **Responsive display** — right-aligned, auto-scales for long numbers

---

## Screenshots

<img width="1251" height="701" alt="image" src="https://github.com/user-attachments/assets/13aa60e7-4c25-4c4c-80cc-6dd23159105f" />


---

## Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.0+)
- For Windows builds: Visual Studio with **Desktop development with C++** workload
- For Android builds: Android Studio + SDK

### Run

```bash
# Clone the repo
git clone https://github.com/vruukz/calculator.git
cd calculator

# Install dependencies
flutter pub get

# Add platform support if needed
flutter create --platforms=windows .   # for Windows
flutter create --platforms=linux .     # for Linux
flutter create --platforms=android .   # for Android

# Run
flutter run -d windows   # or linux, or android
```

### Build

```bash
# Windows executable
flutter build windows
# Output: build\windows\x64\runner\Release\calculator.exe

# Linux binary
flutter build linux
# Output: build/linux/x64/release/bundle/calculator

# Android APK
flutter build apk
# Output: build/app/outputs/flutter-apk/app-release.apk
```

---

## Built With

- [Flutter](https://flutter.dev) — UI framework
- [Dart](https://dart.dev) — Language
- `dart:math` — Scientific functions

---

## Author

**Andrei Cărpinișan** — [carpinisan-tech.org](https://carpinisan-tech.org) · [GitHub](https://github.com/vruukz)
