# StroyApp

Flutter MVP for construction inventory tracking.

## What is implemented

- Inventory dashboard with search and filters.
- KPI cards for total, available, checked out, and service-needed items.
- Check-out and return flows with condition update.
- Transfer flow between construction sites.
- Add item flow directly from the inventory screen.
- Edit and delete flows for inventory positions.
- Operations log with timestamps and operation type icons.
- Operation log filter by event type.
- Safe startup without `firebase_options.dart`:
  the app falls back to local mode if Firebase is not configured.

## Tech stack

- Flutter + Material 3
- Riverpod (state management)
- Firebase packages (optional runtime integration)

## Run locally

1. Install Flutter SDK.
2. Fetch dependencies:

```bash
flutter pub get
```

3. Run app:

```bash
flutter run
```

## Firebase note

If your project is not configured with Firebase yet, the app still starts in local mode.
When Firebase config is added later, startup will connect automatically.
