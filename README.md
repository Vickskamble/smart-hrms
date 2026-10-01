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
- Firebase Authentication and Cloud Firestore
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

Firebase client config is **not committed to this repository**. This repo is public, so
`lib/firebase_options.dart` and `android/app/google-services.json` are gitignored and
must be generated locally before the app will build:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

`firebase.json` is committed and pre-wired to project `elitestaff-51f88`. To point the
app at a different project, run `flutterfire configure --project=<your-project>`.

Deploy the security rules:

```bash
firebase deploy --only firestore:rules
```

### Security rules

`firestore.rules` is the only thing standing between a signed-in employee and the rest of
the company's data. It is covered by an emulator test suite, and **the rules must be
re-verified whenever they change**:

```bash
cd rules
npm install
npm run rules:test      # 30 tests against the Firestore emulator
```

To check a candidate rules file without touching the deployed one:

```bash
RULES_PATH=../firestore.rules.candidate npm run rules:test
```

The suite covers self-role promotion, cross-company user moves, salary-slip visibility,
leave self-approval, attendance tampering on other people's records, and unauthenticated
access. Any test added here should be paired with the rule change it justifies.

### Builds

```bash
flutter build apk --release   # Android APK -> build/app/outputs/flutter-apk/app-release.apk
flutter build web             # web -> build/web
flutter build windows         # Windows desktop (requires Visual Studio C++ workload)
```

### Seed data

`lib/seed_main.dart` (`flutter run -t lib/seed_main.dart`) seeds a demo company, admin, and
employees via `lib/services/database_seeder.dart`. It writes demo records to the configured
Firebase project — do not point it at production.

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
rules/               Firestore emulator tests for firestore.rules
```

## Repository

- Issue tracker: upstream codebase managed externally; feature phases covered in `PHASE3_IMPLEMENTATION_SUMMARY.md`, `PHASE4_IMPLEMENTATION_SUMMARY.md`, `PHASE4_FINAL_SUMMARY.md`.