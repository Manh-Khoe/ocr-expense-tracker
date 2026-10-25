# Mini-Project 3: OCR Expense Tracker 📊🧾

An intelligent personal expense tracking application built with Flutter. It leverages **Google ML Kit Text Recognition** to extract transaction details (merchant name, total amount in VND, and transaction date) directly from printed receipt photos, manages offline records using an embedded **SQLite** database, and provides intuitive data visualizations powered by a custom **CustomPainter** pie chart.

---

## 🌟 Key Features

- 📸 **Receipt Camera Capture & OCR Recognition:** 
  - Directly capture physical paper receipts using the camera or import bill photos from the device gallery.
  - On-device optical character recognition using **Google ML Kit (Latin script)**.
  - Smart heuristics and RegEx parsing to extract store names, VND currency formats, and transaction dates.

- ✍️ **Dual Input Modes (OCR & Manual):**
  - **Review Screen:** Verify and adjust OCR-extracted fields before saving.
  - **Manual Entry:** Add expenses manually with custom notes, category tags, and optional receipt attachments.
  - **Full-Screen Bill Viewer:** Zoom and inspect captured receipt images anytime.

- 🗄️ **Local SQLite Database:**
  - Fast, fully offline storage using `sqflite`.
  - Schema includes `id`, `merchant`, `total_amount`, `date`, `category`, `image_path`, and `note`.
  - Full CRUD operations with automatic database version migration support.

- 📅 **Transaction Management & Monthly Grouping:**
  - Group transactions automatically by Month/Year with subtotal calculations.
  - Interactive swipe-to-delete (`Dismissible`) with safety confirmation dialogs.
  - Tap any transaction to inspect details or edit records.

- 🎨 **Dynamic CustomPainter Charts:**
  - Custom-built interactive Donut / Pie Chart using Flutter's native `CustomPainter` and `canvas.drawArc` (no bulky third-party chart libraries).
  - Time filtering by Month/Year via a top dropdown menu with immediate UI state redraw.
  - Detailed breakdown table showing expenditure percentages and totals per category.

---

## 🛠️ Tech Stack & Architecture

- **Framework:** [Flutter](https://flutter.dev/) (Channel stable, Dart 3.x)
- **OCR Engine:** `google_mlkit_text_recognition`
- **Camera & Image Selection:** `image_picker`
- **Database:** `sqflite` & `path`
- **Formatting & Localization:** `intl`
- **Rendering:** Native Flutter `CustomPainter` (PieChartPainter)

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (version `>= 3.13.2`)
- Android SDK (API Level 24+ minimum required for Google ML Kit)
- Java Development Kit (JDK 17 or JDK 21)

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/Manh-Khoe/ocr-expense-tracker.git
   cd ocr-expense-tracker
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the application:**
   - Connect an Android device with USB Debugging enabled, or launch an Android emulator.
   - Run:
     ```bash
     flutter run
     ```

---

## 📦 Building Release APK

To generate a standalone release APK for Android installation:

```bash
flutter build apk --release
```

The compiled APK will be located at:
```text
build/app/outputs/flutter-apk/app-release.apk
```

> **Note on ProGuard / R8:**  
> The Android release configuration includes dedicated rules in `android/app/proguard-rules.pro` to preserve Google ML Kit runtime classes when code minification is active.

---

## 🧪 Testing

Run automated tests to verify OCR regex heuristics and parsing logic:

```bash
flutter test
```

To run static analysis:

```bash
flutter analyze
```

---

## 👤 Author

- **Strong Duong (Duong Manh Khoe)**
- GitHub: [@Manh-Khoe](https://github.com/Manh-Khoe)
- Email: `duongmanhkhoe27102005@gmail.com`
