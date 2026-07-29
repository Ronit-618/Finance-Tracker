# Finance Tracker — Project Plan

A personal finance tracking app built around screenshot-based expense capture, with a Flutter frontend and ASP.NET Core backend.

---

## 1. Overview

The core idea: instead of manually opening the app to log every expense, a floating bubble widget lets the user capture a screenshot (e.g. of a payment confirmation) with one tap. The screenshot sits in a "pending" queue until the user fills in a short form describing it — at which point it becomes a proper ledger entry.

**Platform scope (Phase 1):** Android only. The floating bubble + auto-screenshot capture relies on Android's `SYSTEM_ALERT_WINDOW` and `MediaProjection` APIs, which have no equivalent on iOS. iOS support (via a share-sheet extension instead of auto-capture) can be considered later.

---

## 2. Tech Stack

| Layer | Choice |
|---|---|
| Mobile app | Flutter |
| Backend API | ASP.NET Core Web API |
| Database | SQL Server (LocalDB) |
| File/image storage | Local device storage (Phase 1) → cloud blob storage (Phase 2, for sync/backup) |
| Native Android integration | Kotlin plugin (foreground service, overlay window, MediaProjection) — Flutter alone can't do this |

---

## 3. Core Features

### 3.1 Floating Bubble & Screenshot Capture
- Persistent floating widget shown over other apps (`SYSTEM_ALERT_WINDOW` + foreground service).
- Tap → user confirms ("yes") → screen captured via `MediaProjection`.
- Screenshot saved to app-private storage, organized by date:
  `/Android/data/<package>/files/screenshots/YYYY-MM-DD/`
- Consider `flutter_overlay_window` (or similar) to avoid writing the overlay from scratch.

### 3.2 Pending Queue & Notification Counter
- Every captured screenshot increments a "pending" counter.
- Persistent notification shows count of un-described screenshots.
- Counter decrements when the user fills in the form and marks the entry as done (`IsCompleted = true`).

### 3.3 Entry Form
User-filled fields:
- **Amount**
- **Description**
- **Category** — single select: `Personal Payment`, `Bill Sharing`, `Loan`, `Income`
- **Type** — `Expense` / `Income`
- **Payment Type**

Auto-filled fields:
- **Date** — today's date (editable)
- **SN** — auto-incrementing serial number, assigned on submit

### 3.4 Tables & Filtering
- Daily view
- Monthly view
- Yearly view
- Custom view with filters (date range, category, type, payment type)
- Nepali (Bikram Sambat) calendar support for filtering by Nepali months (e.g. Baisakh, Shrawan), alongside standard English dates

---

## 4. Data Model

```
Entries
├── Id                (PK, int/guid)
├── SN                (auto-increment display number)
├── Date              (date)
├── Description       (string)
├── Category           (enum: PersonalPayment, BillSharing, Loan, Income)
├── Type              (enum: Expense, Income)
├── PaymentType        (string)
├── Amount            (decimal)
├── ScreenshotPath      (string, nullable)
├── IsCompleted        (bool — default false until form is filled)
└── CreatedAt          (datetime)
```

Notes:
- Daily/monthly/yearly/custom views are all just filtered/grouped queries against this single `Entries` table — no need for separate tables per time period.
- Store screenshots on disk (or blob storage later), keep only the path/URL in the DB row — don't store image blobs directly in the database.
- If screenshots need richer metadata later (e.g. multiple images per entry), split into a separate `Attachments` table with a foreign key to `Entries`.

---

## 5. Known Technical Challenges

| Challenge | Detail |
|---|---|
| MediaProjection permission | Re-prompted every time the app process restarts — by OS design, can't be made fully persistent. Needs a one-time explainer for the user. |
| Foreground service type declaration | Android 14+ requires declaring `mediaProjection` as the foreground service type in the manifest, or the service gets killed. |
| Notification permission | Android 13+ requires a separate runtime `POST_NOTIFICATIONS` permission, or the pending-counter notification silently fails to show. |
| OEM battery optimization | Xiaomi, Oppo, and similar OEMs aggressively kill background services. Consider prompting users to disable battery optimization for the app during onboarding. |
| Nepali calendar conversion | No standard built-in library on the .NET side; will likely need a ported BS↔AD conversion table. Flutter side can use packages like `nepali_utils`. |
| iOS (future) | No floating overlays or arbitrary screen capture allowed. Would need a share-sheet extension where the user manually shares a screenshot into the app, rather than auto-capture. |

---

## 6. Suggested Build Order

1. ✅ **Backend foundation** — ASP.NET Core API + database schema (`Entries` table). Verify CRUD via Postman.
2. ✅ **Flutter app core** — manual entry form + entry list/table, wired to the API (no screenshot automation yet).
3. ✅ **Table views & filters** — daily/monthly/yearly/custom filter queries against the same table; validates the schema design.
4. ✅ **Flutter app core** — manual entry form + entry list/table, wired to the API. Done on 2026-07-22.
5. **Manual screenshot attach** — let users pick an existing screenshot from their gallery and attach it to a form entry. Delivers most of the value before automation is built.
6. **Floating bubble + auto-capture** — the most complex and Android-fragile piece; build once the rest of the app is stable.
7. **Nepali calendar filtering** — isolated enough to add at any point once the core date filtering works.

---

## Progress

- ✅ **1. Backend foundation** — Done on 2026-07-20.
  - Created `backend/` folder with ASP.NET Core Web API project (`FinanceTracker.Api`).
  - Added EF Core with `Microsoft.EntityFrameworkCore.SqlServer` provider.
  - Created `Entry` model with all fields per the data model.
  - Created `AppDbContext` with proper configuration and indexes.
  - Created and applied initial migration (`InitialCreate`) — SQL Server LocalDB database `FinanceTracker` is live.
  - Connection string in `appsettings.json` configured for `(localdb)\MSSQLLocalDB` with Integrated Security.
  - Builds and runs successfully with 0 errors.
- ✅ **2. Entry CRUD API** — Done on 2026-07-20.
  - Created `Controllers/EntryController.cs` with full CRUD at `api/Entry`.
  - Created DTOs (`CreateEntryRequest`, `UpdateEntryRequest`, `EntryResponse`).
  - Auto-assigns `SN` (incrementing), `CreatedAt` (UTC), and `IsCompleted` (false) on creation.
  - Builds with 0 errors.
- ✅ **3. PaymentType enum + auto-logic** — Done on 2026-07-20.
  - `PaymentType` is now an enum (`Debit`, `Credit`) stored as string in DB.
  - Logic: `Expense` → `Debit`, `Income` → `Credit` (auto-set server-side, not from client).
  - Removed `PaymentType` from Create/Update DTOs.
  - Migration `MakePaymentTypeEnum` applied to LocalDB.
- ✅ **4. IsCompleted simplified (int: 0 / 1)** — Done on 2026-07-20.
  - `IsCompleted` is now `int` (0 = saved after form fill, 1 = edited).
  - POST sets `IsCompleted = 0`, PUT sets `IsCompleted = 1`.
  - Removed `EntryStatuses` lookup table and FK (reverted).
  - Migration `RevertToIsCompleted` applied.
- ✅ **5. Bill table (auto-synced from Entries)** — Done on 2026-07-20.
  - `Bills` table with `EntryId` FK (one-to-one with Entries).
  - POST Entry → auto-creates Bill with Credit/Debit mapped from `PaymentType`.
  - PUT Entry → auto-updates linked Bill.
  - DELETE Entry → auto-deletes linked Bill.
  - `api/Bill` is read-only (GET) — balance is running total `SUM(Credit - Debit)`.
  - Each Bill has `Total = Credit - Debit` (per row: +Amount for Credit, -Amount for Debit).
  - Migrations `AddBillTable`, `LinkBillToEntry`, `AddTotalToBill` applied.

- ✅ **6. Edit immutability + CreatedAt update** — Done on 2026-07-22.
  - Removed `Date` from `UpdateEntryRequest` — users cannot change Id, SN, or Date on edit.
  - `CreatedAt` now updates to `DateTime.UtcNow` on every edit (Entry + linked Bill).
  - Bill's `SN` and `Date` no longer overwritten on edit — they stay as originally set.
  - Builds with 0 errors.
- ✅ **7. Transaction table (Income/Expense split)** — Done on 2026-07-22.
  - Created `Transaction` model with only `BillId` (PK + FK), `Income`, and `Expense` columns.
  - Positive `Bill.Total` → `Income`, negative `Bill.Total` → `Expense` (absolute value).
  - One-to-one with Bills table via `BillId` FK/PK — no extra fields (no Id, SN, Date, Description, Total, CreatedAt).
  - Auto-synced on Entry POST (create), PUT (update), DELETE (cascade).
  - Created `api/Transaction` read-only GET endpoints.
  - Migration `AddTransactionTable` applied to LocalDB.
  - Builds with 0 errors.
- ✅ **8. Table views & filters** — Done on 2026-07-22.
  - `GET /api/Entry` now accepts optional query params: `from`, `to`, `category`, `type`, `paymentType`.
  - `GET /api/Entry/summary` — returns `TotalEntries`, `TotalIncome`, `TotalExpense`, `Balance` with same filters.
  - `GET /api/Entry/grouped?period=day|month|year` — groups entries by period with income/expense/balance per group.
  - All filter params work across the same reusable `FilterQuery` method.
  - Builds with 0 errors.
- ✅ **9. Flutter frontend core** — Done on 2026-07-22.
  - Created Flutter project in `frontend/` with `http` and `intl` packages.
  - Created models: `Entry`, `EntrySummary`, `EntryGroup` with JSON serialization.
  - Created `ApiService` covering all backend endpoints (entries, summary, grouped, CRUD).
  - Entry list screen with filter chips (Income/Expense), summary card, and pull-to-refresh.
  - Entry form screen (create) with type/category/date/amount fields.
  - Grouped view screen (day/month/year toggle) accessible from app bar.
  - Android `AndroidManifest.xml` configured with cleartext HTTP (`10.0.2.2:5044`).
  - APK builds with 0 analysis issues.
- ✅ **10. CORS + Kestrel + Firewall** — Done on 2026-07-27.
  - Added CORS (`AllowAnyOrigin/Method/Header`) to `Program.cs`.
  - Kestrel binds to `0.0.0.0:5044` via `UseUrls` + `launchSettings.json` so Android emulator can reach the API.
  - **Required**: Windows Firewall must allow inbound TCP on port 5044. Run as Admin:
    ```powershell
    New-NetFirewallRule -DisplayName "FinanceTracker API 5044" -Direction Inbound -LocalPort 5044 -Protocol TCP -Action Allow
    ```
- ✅ **11. Navigation shell with Drawer** — Done on 2026-07-27.
  - `HomeShell` with `Drawer` navigation (Dashboard / Pending / Transactions).
  - Pending badge driven from `PendingStore.length`.
- ✅ **12. Dashboard screen** — Done on 2026-07-27.
  - Summary cards via `GET /api/Entry/summary` (Income/Expense/Balance).
  - Monthly trend strip via `GET /api/Entry/grouped?period=month` (last 6 months).
- ✅ **13. Pending screen** — Done on 2026-07-27.
  - `PendingStore` singleton (in-memory list) with add/remove.
  - Tap pending item → opens Entry Form; on save → removed from pending store.
  - Dummy "Add test capture" button for manual testing.
- ✅ **14. Table screen** — Done on 2026-07-27.
  - Full entry list with Type/Category filter chips and dropdown.
  - Group-by toggle (None / Day / Month / Year) via in-memory grouping.
  - Edit/Delete via popup menu on each entry tile.
- ✅ **15. Entry Form enhancements** — Done on 2026-07-27.
  - Edit mode: pre-fills fields when existing `Entry` is passed; Date locked on edit.
  - Category filtered by Type: hides "Income" category when Type = Expense (and vice versa).
  - Pending capture attachment indicator when opened from Pending screen.
- ✅ **16. Bug fix: model type mismatch (enum int vs String)** — Done on 2026-07-27.
  - `Entry.category`, `Entry.type`, `Entry.paymentType` changed from `String` to `int` to match backend enum serialization.
  - Updated `EntryFormScreen`, `EntryListScreen`, `TableScreen` to use int comparisons (0=Expense, 1=Income; 0=PersonalPayment, 1=BillSharing, 2=Loan, 3=Income).
  - Updated `ApiService` filter params from `String?` to `int?` with `.toString()` serialization.
  - Added debug logging in `createEntry` to print HTTP status + response body on failure.
- ✅ **17. Menu rename + FAB removal** — Done on 2026-07-27.
  - "Table" menu label renamed to "Transactions" in drawer and app bar.
  - FloatingActionButton removed from Transactions screen.
- ✅ **18. Expandable transaction tiles + screenshot viewer** — Done on 2026-07-27.
  - Each transaction tile is now expandable (tap to expand/collapse, multiple tiles independent).
  - Expanded content shows full details: Description, Category, Type, PaymentType, Amount, Date, CreatedAt, SN.
  - Attached screenshot rendered via `Image.file()` at 220px height with error handling; "No screenshot attached" placeholder when null.
  - Full-screen `InteractiveViewer` route for pinch-zooming the screenshot, dismissible via back button.
- ✅ **19. Public screenshot storage + permission handling** — Done on 2026-07-27.
  - Created `ScreenshotService` with `checkAndRequestPermission()` (explainer dialog + `MANAGE_EXTERNAL_STORAGE`) and `saveScreenshotToPublicFolder()` (copies to `/storage/emulated/0/FinanceTracker/Transaction/Screenshot/`).
  - Pending screen now uses `ScreenshotService` instead of app-private `path_provider` storage.
  - Entry Form (edit mode) displays existing screenshot via `Image.file()` with error fallback.
- ✅ **20. Physical device API connectivity fix** — Done on 2026-07-28.
  - `ApiService` base URL changed from `http://127.0.0.1:5044` to `http://192.168.15.106:5044` in `main.dart` — `127.0.0.1` points to the device itself on a physical phone, not the host PC.
  - Documented the rule: emulator → `10.0.2.2`, physical device → PC's LAN IP, both must be on same network with Kestrel bound to `0.0.0.0:5044` and Windows Firewall port 5044 open.
- ✅ **21. Pending capture image preview + screenshot copy on save** — Done on 2026-07-28.
  - Entry Form now renders `Image.file()` preview for pending captures (with error fallback) plus "Captured <timestamp>" label, replacing the old plain-text placeholder.
  - On save from a pending capture, `ScreenshotService.saveScreenshotToPublicFolder()` copies the file to `/storage/emulated/0/FinanceTracker/Transaction/Screenshot/` and the returned path is included in `POST /api/Entry` body as `screenshotPath`.
  - Copy failure shows a `SnackBar` error and aborts the save.
  - Edit-mode screenshot display remains unchanged.
- ✅ **22. Transaction detail page + double-tap navigation** — Done on 2026-07-28.
  - Created `TransactionDetailScreen` showing all entry fields (Description, Amount with Rs./color, Category, Type, PaymentType, Date, CreatedAt) read-only, plus screenshot with error fallback and full-screen viewer. SN hidden per user request.
  - AppBar has Edit and Delete buttons; Edit navigates to `EntryFormScreen` in edit mode, Delete shows confirmation dialog.
  - After Edit save or Delete confirm, pops back to Transactions list and refreshes.
  - Removed three-dot PopupMenuButton from transaction tiles; replaced single-tap with double-tap via `GestureDetector.onDoubleTap` on each tile.
- ✅ **23. Bug fix: ScreenshotPath lost on edit** — Done on 2026-07-28.
  - **Root cause (two-sided bug):** Frontend never included existing `screenshotPath` in the update PUT body; backend unconditionally overwrote the DB column with whatever the request sent (including `null`).
  - Frontend fix: `EntryFormScreen._save()` now includes `widget.entry!.screenshotPath` in the update payload when editing an entry that has one.
  - Backend fix: `EntriesController.cs` PUT handler now uses `if (request.ScreenshotPath is not null)` guard so ScreenshotPath is only overwritten when the request explicitly provides a value, preserving the existing DB value otherwise.
- ✅ **24. Success toasts + post-save redirect** — Done on 2026-07-28.
  - Created `utils/snackbar_helper.dart` with shared `showSuccessSnackBar()` helper (2s duration).
  - Extracted `PendingStore`/`PendingCapture` from `pending_screen.dart` to `models/pending_store.dart` to avoid circular import.
  - **New Entry from Pending:** Shows "Added new entry" toast, removes from PendingStore, then redirects to Dashboard via `Navigator.pushAndRemoveUntil`.
  - **Update Entry:** Shows "Updated successfully" toast, then pops back to Transactions list (unchanged navigation).
  - **Delete Entry:** Shows "Deleted successfully" toast, then pops back to Transactions list (unchanged navigation).
- ✅ **25. Drawer navigation with named routes + proper back behavior** — Done on 2026-07-28.
  - Added `flutter_riverpod` dependency.
  - Created `providers/drawer_provider.dart` with `DrawerDestination` enum and `currentDrawerDestinationProvider`.
  - Created `widgets/app_drawer.dart` — shared `ConsumerWidget` drawer with route-smart navigation:
    - Same route → close drawer, no navigation.
    - From `/dashboard` → `pushNamed` (stack: [Dashboard, Target]).
    - From `/pending` or `/transactions` → `pushReplacementNamed` (replaces top-level page).
    - From sub-page (TransactionDetailScreen/EntryFormScreen) → `popUntil('/dashboard')` then `pushNamed`.
  - Replaced single-shell `home_shell.dart` with three named routes (`/dashboard`, `/pending`, `/transactions`) in `main.dart` via `initialRoute` + `routes`.
  - `DashboardScreen`, `PendingScreen`, `EntryListScreen` each have their own `Scaffold` + `AppBar` + `AppDrawer`.
  - Removed `home_shell.dart` (no longer used).
  - Removed `onPendingCountChanged` callback chain — `AppDrawer` reads `PendingStore().length` directly (singleton).
  - Back button scenarios:
    1. On Dashboard → back exits app (root route).
    2. Pending/Transactions → back returns to Dashboard.
    3. Switching Pending↔Transactions → stack stays [Dashboard, Current].
     4. TransactionDetailScreen → back returns to Transactions.
   - No `PopScope`/`WillPopScope` added or needed.
   - **Bug fix (post-build):** Removed extraneous `Navigator.pop(context)` from drawer `onTap` handlers after `_navigateTo` — route changes (pushNamed/pushReplacementNamed) close the drawer naturally; calling `pop` afterward could pop a route instead. Also changed sub-page case from `pushReplacementNamed` to `pushNamed` to keep Dashboard on the stack.
    - **Bug fix (post-build):** Wrapped `ref.read(currentDrawerDestinationProvider.notifier).state = ...` in `initState` of all three screens in `addPostFrameCallback` — writing to a provider during widget tree building causes "Tried to modify a provider while the widget tree was building" error.
- ✅ **26. Branding: logo in drawer header + launcher icon** — Done on 2026-07-28.
  - Replaced `Icons.account_balance_wallet` with `Image.asset('assets/images/logo.png')` in `app_drawer.dart` header.
  - Added `flutter_launcher_icons` dev dependency and config block in `pubspec.yaml` (`android: true`, `image_path: assets/images/logo.png`).
  - Registered `assets/images/` under `flutter: assets:` in `pubspec.yaml`.
  - Ran `dart run flutter_launcher_icons` — regenerated all 5 mipmap `ic_launcher.png` files from the logo asset.
  - Rebuilt APK with `flutter clean && flutter pub get && flutter run` — app installed and running on device with new launcher icon.
- ✅ **27. Card styling: bold date header for grouped day view** — Done on 2026-07-28.
  - Dashboard screen: made date headers bold in the monthly trend strip for better readability.
  - Transactions screen (day grouping): same bold date-header styling applied.
  - **Bug fix: date header comparisons** — Fixed `aDate == bDate` comparison where string instances could differ even for the same date string; now compares by value (identical strings) to ensure grouping headers collapse correctly.
- ✅ **28. Branding v2: switch to logoST.png + circular display** — Done on 2026-07-28.
  - Added `assets/images/logoST.png` alongside existing `logo.png`.
  - Swapped all 4 Dart references from `logo.png` to `logoST.png`:
    - `lib/widgets/app_drawer.dart` (drawer header, 64×64)
    - `lib/screens/dashboard_screen.dart` (AppBar right action, 44×44)
    - `lib/screens/pending_screen.dart` (AppBar right action, 44×44)
    - `lib/screens/entry_list_screen.dart` (AppBar right action, 44×44)
  - Fixed circular clipping: changed `child: Image.asset(...)` to `backgroundImage: AssetImage(...)` inside `CircleAvatar` at all 4 locations — `CircleAvatar` with `backgroundImage` guarantees a perfect circular clip via its internal `ClipOval`, unlike `child` which could leak square corners depending on `backgroundColor`.
  - Drawer: `CircleAvatar(radius: 32, backgroundImage: AssetImage('assets/images/logoST.png'))`.
  - AppBar (all 3 screens): `CircleAvatar(radius: 22, backgroundImage: AssetImage('assets/images/logoST.png'))`.
  - No `pubspec.yaml` changes needed — `assets/images/` glob already covers `logoST.png`.
- ✅ **29. Bug fix: "Screenshot unavailable" on TransactionDetailScreen (permission on read)** — Done on 2026-07-28.
  - **Root cause:** `MANAGE_EXTERNAL_STORAGE` permission was requested only on screenshot **save**, but never on **read**. `Image.file()` in `TransactionDetailScreen._buildScreenshot` and `FullScreenImage` failed silently on Android 11+, and the generic `errorBuilder` placeholder gave no way to diagnose or fix.
  - **Fix:** Both widgets now check `Permission.manageExternalStorage.isGranted` before attempting `Image.file()`. If not granted, they show a tappable prompt ("Tap to grant file access to view screenshot") that requests the permission and rebuilds on grant via `StatefulBuilder.setInnerState`.
  - Added `debugPrint` inside `errorBuilder` on both widgets for future diagnostics.
  - JSON mapping confirmed correct: backend `ScreenshotPath` (PascalCase) → ASP.NET Core camelCase serialization → `screenshotPath` → frontend `json['screenshotPath'] as String?` — no mismatch.
  - File path round-trip confirmed correct: full `/storage/emulated/0/FinanceTracker/Transaction/Screenshot/...` path is stored, returned, and passed to `Image.file()`.

## 8. Frontend Flow (Flutter — Dart)

### Navigation Shell
```
Named routes (root Navigator)
 ├── /dashboard   (DashboardScreen)   — initial route
 ├── /pending     (PendingScreen)
 └── /transactions (EntryListScreen)
```

### Key Design Decision: Pending is local-only, not backend state
A captured screenshot is **not** an `Entry` until the form is filled in — the backend's `Entry` model requires Amount/Description/Category/Type, which a raw screenshot doesn't have. So:
- **Pending** = a local, on-device queue (e.g. via Hive or a local JSON store) of `{screenshotPath, capturedAt}` items — nothing is sent to the backend yet.
- Only on form submit does the item become a real `Entry` row (cascading to `Bill` and `Transaction` per existing backend logic).
- Badge count = local pending-store length; increments on capture, decrements (item removed entirely, not just marked done) on successful save.

### 1. Dashboard (root)
- Summary cards from `GET /api/Entry/summary` (TotalIncome, TotalExpense, Balance).
- Optional trend/highlight strip from `GET /api/Entry/grouped?period=month`.
- Reflects only saved backend data — never shows unsynced pending captures.

### 2. Pending
- List of local capture items: thumbnail + capture time, newest first.
- Tapping an item opens the Entry Form, pre-loaded with that screenshot attached.
- On successful save: remove from local pending store (it's now a persisted Entry, not "pending").

### 3. Entry Form
| Field | Behavior |
|---|---|
| Type (Expense / Income) — top tab/segmented control | Required |
| Category | Dropdown: `Personal Payment`, `Bill Sharing`, `Loan`, `Income` — **should be filtered based on selected Type** to avoid contradictory combos (e.g. hide "Income" category when Type = Expense) — open decision, see below |
| Description | Text field |
| Amount | Numeric field |
| Date | Defaults to today; editable only at creation — backend blocks Date changes on edit (`UpdateEntryRequest` has no Date field), so lock this field once the entry exists |
| PaymentType | Not shown — backend auto-derives Debit/Credit from Type |
| SN | Not shon — backend auto-increments |
| Save Entry button | Triggers create/update call |

### 4. Save Entry → Backend Cascade
Single `POST /api/Entry` call triggers the existing backend cascade — no separate frontend calls needed for Bill/Transaction (both are auto-synced, read-only mirrors):
```
POST /api/Entry { description, amount, category, type, date, screenshotPath }
   → Entry created (SN + CreatedAt auto-set, IsCompleted = 0, PaymentType auto-derived)
   → Bill auto-created (EntryId FK, Total = ±Amount based on Credit/Debit)
   → Transaction auto-created (BillId FK, Income or Expense filled from Bill.Total sign)
```

### 5. Transactions
- Backed by `GET /api/Entry` with `from/to/category/type/paymentType` filters, plus day/month/year toggle via `GET /api/Entry/grouped`.
- Shows only real backend truth — pending captures never appear here.

### Suggested Local State
- `PendingCaptureStore` (Hive or local JSON) holding `{path, capturedAt}` — separate from the existing `ApiService`.
- Dashboard, Pending, Transactions as separate top-level routes off the drawer; Pending badge driven from `PendingCaptureStore.length`.

---

## 9. Open Questions / Decisions to Make

- [ ] Local-only screenshot storage vs. cloud-synced storage (affects backup, cross-device access, and hosting cost)
- [ ] Auth strategy for the API (single-user local app vs. multi-user with login)
- [ ] Whether Nepali date support is needed for MVP or can wait
- [ ] iOS support timeline, if any, and what the capture flow looks like there
- [x] Whether Category's "Income" option should be filtered out when Type = Expense (and vice versa) to avoid contradictory Type/Category combinations in the Entry Form — **Resolved: implemented in Entry Form. When Type = Expense, only PersonalPayment/BillSharing/Loan shown; when Type = Income, only Income category shown.**
- [ ] Screenshot storage currently uses `MANAGE_EXTERNAL_STORAGE` ("All files access") to write to a public folder (`/storage/emulated/0/FinanceTracker/Transaction/Screenshot/`). This is acceptable for a personal/sideloaded app but is **not** Play Store–friendly — Google typically rejects this permission for this use case in favor of the MediaStore API or Storage Access Framework (SAF). Revisit this before any Play Store release.