# Smart HRMS (WorkForce Command)

A Flutter-based Human Resource Management System (HRMS) for companies that need to manage employees, attendance, leaves, announcements, and salary/performance reporting — with a full admin console and a bulk employee-import workflow.

## Features

**Admin / HR**
- Dashboard with live stats (total staff, present, on leave, departments) and charts
- Employee management (add, edit, reset credentials, activate/deactivate)
- Bulk import of employees from Excel (`.xlsx`) / CSV with validation, preview, batching, and import history
- Leave request approval flow
- Company & announcement management
- Data export (CSV) and salary slip/report generation (PDF)

**Employee**
- Home screen, personal profile, attendance history, leave requests
- Reports (attendance, salary, leave) and same-company directory browsing

**Platform**
- Firebase Authentication, Cloud Firestore, Cloud Storage, and (planned) Remote Config
- Light / dark / system theme with persistence
- Responsive UI (desktop two-panel login, mobile bottom nav, adaptive layouts)
- Works on Android, iOS, Web, Windows, macOS, Linux

## Getting Started

Prerequisites: [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.x), [Firebase CLI](https://firebase.google.com/docs/cli).

```bash
flutter pub get
flutter run            # run on a connected device/emulator
flutter test           # run widget/unit tests
flutter analyze        # static analysis (0 issues expected)
```

### Firebase setup

The project is wired to Firebase project `elitestaff-51f88`. `lib/firebase_options.dart`, `android/app/google-services.json`, and `firebase.json` are already generated. To point it at a different Firebase project:

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=<your-firebase-project>
```

Deploy the security rules (already done for `elitestaff-51f88`):

```bash
firebase deploy --only firestore:rules
```

### Builds

```bash
flutter build apk --release   # Android APK -> build/app/outputs/flutter-apk/app-release.apk
flutter build web             # web -> build/web
flutter build windows         # Windows desktop (requires Visual Studio C++ workload)
```

### Seed data

`lib/seed_main.dart` (`flutter run -t lib/seed_main.dart`) seeds a demo company, admin, and employees via `lib/services/database_seeder.dart`.

## Project Structure

```
lib/
├── core/            theme, constants
├── data/            repositories, providers, services (import, salary)
├── models/          data models
├── screens/
│   ├── auth/        login, employee home/detail/report/leave screens
│   └── admin/       dashboard, employee management, import flow, requests
├── services/        database seeder
├── utility/         file parser (Excel/CSV), helpers
└── widgets/         shared/common widgets
```

## Repository

- Issue tracker: upstream codebase managed externally; feature phases covered in `PHASE3_IMPLEMENTATION_SUMMARY.md`, `PHASE4_IMPLEMENTATION_SUMMARY.md`, `PHASE4_FINAL_SUMMARY.md`.