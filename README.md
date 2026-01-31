# ReceiptOnce

A Flutter app for scanning, organizing, and managing receipts. Capture receipts with your camera or gallery, extract text with on-device OCR, and keep everything in a local database with categories and search.

## Features

- **Scan receipts** — Use the camera or pick images from your gallery
- **OCR** — Extract text from receipt images with Google ML Kit (on-device, no cloud required)
- **Organize** — Store receipts with merchant, date, amount, category, and notes
- **Search** — Find receipts quickly from the home screen
- **Share** — Share receipt details when you need them
- **Local-first** — Data is stored in a local SQLite database on your device

## Tech stack

- [Flutter](https://flutter.dev/) — Cross-platform UI
- [Google ML Kit Text Recognition](https://developers.google.com/ml-kit/vision/text-recognition) — On-device OCR
- [sqflite](https://pub.dev/packages/sqflite) — Local SQLite database
- [camera](https://pub.dev/packages/camera) & [image_picker](https://pub.dev/packages/image_picker) — Capture and pick images
- [share_plus](https://pub.dev/packages/share_plus) — Sharing
- [in_app_purchase](https://pub.dev/packages/in_app_purchase) — In-app purchases (optional)

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (SDK ^3.10.3)
- For **Android**: Android Studio / SDK; camera and storage permissions
- For **iOS**: Xcode; camera and photo library usage descriptions in `Info.plist`
- For **macOS**: Xcode; camera entitlement if using camera on desktop

## Getting started

1. Install dependencies:
   ```bash
   flutter pub get
   ```

2. Run the app:
   ```bash
   flutter run
   ```

   Or open the project in your IDE and run from there.

## Project structure

```
lib/
├── main.dart           # App entry, navigation, and UI
└── data/
    ├── receipt.dart        # Receipt model
    └── receipt_database.dart   # SQLite access
```

## License

This project is not published to pub.dev (`publish_to: 'none'` in `pubspec.yaml`). Use and modify it as you like. If you reuse significant parts, attribution is appreciated.

---

*ReceiptOnce — capture and organize receipts in one place.*
