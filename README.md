# DraftFlow

**DraftFlow** is a modern, minimalist desktop notes and relational database application inspired by the elegance of Things 3 / Bear and the organizational power of Notion. Built with Flutter, Drift (SQLite), and optional multi-device Supabase synchronization.

---

## ✨ Features

- **Block-Based Rich Text Editor**: Clean, distraction-free writing experience with Markdown shortcuts, callout blocks, toggle lists, and multi-language syntax-highlighted code blocks.
- **Notion-Style Relational Databases**: Interactive database tables supporting multiple column types (Text, Number, Select, Multi-select, Status, Date, URL links), automatic summary rows, and center peek modals.
- **Command Palette & Fast Search**: Instantly navigate pages, trigger actions, and search text with fuzzy matching via `Cmd+K` (macOS) or `Ctrl+K` (Windows).
- **Quick Notes**: Convenient slide-out drawer for fast captures, colorful sticky notes, and checklists.
- **Modular Ecosystem**: Extensible module architecture, including a built-in Media Tracker module (TMDB / Kinopoisk integration).
- **Local-First & Offline-First**: All your data lives locally in a high-performance SQLite database.
- **End-to-End Cloud Sync (Optional)**: Seamless multi-device sync via Supabase with full conflict resolution and local backups.
- **Refined Desktop UX**: Designed to feel native on macOS and Windows with translucent materials, spring animations, and full keyboard navigation.

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.24+ recommended)
- **macOS**: Xcode and CocoaPods
- **Windows**: Visual Studio 2022 with **Desktop development with C++**

### Installation & Run

1. Clone the repository:
   ```bash
   git clone https://github.com/tonisaf/draftflow.git
   cd draftflow
   ```

2. Fetch dependencies:
   ```bash
   flutter pub get
   ```

3. Run locally:
   ```bash
   # On macOS
   flutter run -d macos

   # On Windows
   flutter run -d windows
   ```

---

## ☁️ Optional Cloud Synchronization

DraftFlow works 100% offline out-of-the-box. If you want cross-device cloud synchronization:

1. Create a free project on [Supabase](https://supabase.com).
2. Copy `config/supabase.example.json` to `config/supabase.json` and fill in your project URL and public anon key.
3. Apply the database schema from [`supabase/notes_schema.sql`](supabase/notes_schema.sql) in your Supabase SQL Editor.
4. Run the app with the configuration:
   ```bash
   flutter run -d macos --dart-define-from-file=config/supabase.json
   ```

---

## 🛠 Testing & Analysis

```bash
flutter analyze
flutter test
```

---

## 📄 License

This project is open-source. See the repository for details.
