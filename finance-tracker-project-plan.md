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
- ✅ **30. Dashboard visualizations (4 charts)** — Done on 2026-07-29.
  - Added `fl_chart` (`^0.70.2`) dependency to `pubspec.yaml`.
  - **Backend:** New `GET /api/Entry/by-category?type=0` endpoint in `EntriesController.cs`, backed by new `CategoryTotalResponse` DTO. Returns expense totals grouped by category, ordered descending.
  - **Frontend model:** `models/category_total.dart` — mirrors the backend DTO.
  - **ApiService:** Added `getCategoryTotals({int? type})` method.
  - **4 chart widgets** created under `widgets/`:
    1. `expense_category_chart.dart` — Pie/donut chart with legend, one slice per category with distinct colors and percentage labels.
    2. `income_vs_expense_chart.dart` — Grouped bar chart showing last 6 months of Income (green) vs Expense (red) bars side-by-side, with month labels and compact Y-axis formatting.
    3. `balance_trend_chart.dart` — Smooth line chart with shaded area, plotting cumulative running balance across all monthly periods.
    4. `top_spending_list.dart` — Ranked horizontal list of top 5 expense categories with proportional progress bars and Rs. amounts.
  - Each chart in its own Card with matching elevation/padding and empty-state fallback ("No data yet").
  - Dashboard loads all 4 sections alongside existing summary card and monthly trend; `RefreshIndicator` reloads all data.
  - Builds with 0 errors on both frontend (flutter analyze) and backend (dotnet build).
- ✅ **30b. Chart layout fixes + Savings chart + auto-refresh** — Done on 2026-07-29.
  - **Expense by Category (pie chart):** Fixed layout — pie chart now centered in a contained 160×160 box (no overflow), legend moved to bottom-right via `Align` + `Wrap` (no overlap with circle), amounts removed from labels (shows `CategoryName (XX.X%)` only).
  - **Balance Trend removed** — replaced with **Savings chart** (`widgets/savings_chart.dart`): bar chart showing savings (`Income - Expense`) per month for the last 6 months, positive bars green, negative bars red.
  - **Dynamic auto-refresh:** Added `RouteObserver` + `RouteAware` mixin to `DashboardScreen` — `didPopNext()` calls `_loadData()` whenever the user navigates back to Dashboard, so all cards/charts reflect the latest data after any add/edit/delete on other screens.
  - **Logo home button:** Tapping the `CircleAvatar` logo in the AppBar (Dashboard, Pending, Transactions screens) now calls `Navigator.pushNamedAndRemoveUntil` to `/dashboard`, acting as a home button that always returns to the root page.
- ✅ **31. Reports screen (Trial Balance + Monthly Transactions)** — Done on 2026-07-29.
  - **Backend:** New DTOs `TrialBalanceItem` / `TrialBalanceResponse` in `backend/Dtos/TrialBalanceResponse.cs`. New endpoint `GET /api/Entry/trial-balance?year=2026&month=7` in `EntriesController.cs` — filters Entries by year/month, groups by Category, sums Debit vs Credit amounts per category, returns items + totalDebit/totalCredit summary.
  - **Drawer:** Added `reports` to `DrawerDestination` enum (`drawer_provider.dart`). Added "Reports" `ListTile` with `Icons.description` in `app_drawer.dart` with the same navigation pattern (popUntil-dashboard-then-pushReplacement for top-level pages). Back-button from Reports returns to Dashboard.
  - **Routing:** Added `/reports` route in `main.dart` pointing to `ReportsScreen`.
  - **`ReportsScreen`** (`screens/reports_screen.dart`):
    - Month/Year picker via two `DropdownButton`s (Month dropdown shows full month names, Year dropdown covers a 5-year window), defaults to current month/year.
    - `TabBar` with two tabs: "Trial Balance" and "Transactions".
    - **Trial Balance tab:** Bordered `Table` widget with `Account Name | Debit | Credit` header row, each category as a row (blank cell if zero), thick 2px top border before the Totals row showing `TotalDebit` / `TotalCredit`. Title "Trial Balance" with subtitle "For the month of July 2026". Currency formatted as `Rs. X,XXX.00`. Shows "No data for this month" if empty.
    - **Transactions tab:** Reuses the same entry tile style as `EntryListScreen` (icon circle, description, date, category, signed colored amount). Double-tap opens `TransactionDetailScreen` via `Navigator.push`. Shows "No transactions this month" if empty.
  - **Frontend model + API:** Created `models/trial_balance_item.dart` with `TrialBalanceItem` and `TrialBalanceResponse` classes. Added `getTrialBalance(year, month)` to `ApiService`.
  - Builds with 0 errors (flutter analyze, dotnet build).
- ✅ **32. Bikram Sambat (BS) / Nepali calendar support** — Done on 2026-07-29.
  - **Package:** Added `BSDateConverter` v1.3.0 NuGet package. Inspected actual API via reflection — `DateConverter` static class with methods: `ConvertADToBS(string)` (AD→BS "YYYY-MM-DD"), `ConvertBSToAD(string)` (BS→AD "YYYY-MM-DD"), `ConvertToBSWithName(string)` ("13 Shrawan 2083"), `ConvertToADWithName(string)` ("31 July 2026"), `GetTodayDateAD()`, `GetTodayDateBS()`.
  - **`Services/NepaliDateService.cs`** — static helper wrapping `DateConverter`:
    - `AdToBs(DateTime)` → formatted BS string (e.g. "13 Shrawan 2083")
    - `AdToBsShort(DateTime)` → "YYYY-MM-DD" BS string
    - `BsToAd(int bsYear, int bsMonth, int bsDay)` → AD DateTime
    - `GetBsMonthAdRange(int bsYear, int bsMonth)` → (AD start, AD end) tuple for a BS month
  - **`EntryResponse` DTO** — added `string? BsDate` field, populated by `NepaliDateService.AdToBs(e.Date)` in `MapToResponse()`.
  - **`GET /api/Entry/trial-balance`** — now accepts optional `bsYear`/`bsMonth` query params alongside existing `year`/`month`. Converts BS month range to AD internally via `GetBsMonthAdRange()`, then reuses the same grouping logic.
  - **`GET /api/Entry`** — added optional `bsYear`/`bsMonth` params; computes AD `from`/`to` range before filtering.
  - AD-based params (`year`/`month`, `from`/`to`) continue working exactly as before — purely additive.
  - Verified conversion: AD 2026-07-29 → BS 2083-04-13 ("13 Shrawan 2083"). BS 2083-4 range → AD 2026-07-17 to 2026-08-16.
  - Builds with 0 errors (dotnet build + flutter analyze).
- ✅ **33. Settings screen + theme toggle + AD/BS date format toggle** — Done on 2026-07-29.
  - **Dependencies:** Added `shared_preferences ^2.3.0`, `nepali_date_picker ^6.0.2`.
  - **Providers** (`providers/settings_providers.dart`):
    - `DateFormatMode` enum (`ad`, `bs`), `DateFormatNotifier` (persists to `SharedPreferences` key `dateFormat`).
    - `ThemeModeNotifier` (persists to `SharedPreferences` key `themeMode`).
    - `dateFormatProvider` / `themeModeProvider` expose these as `StateNotifierProvider`s.
  - **`Entry` model:** Added `String? bsDate` field parsed from backend JSON.
  - **`DateDisplay` helper** (`widgets/date_display.dart`): `formatDate(WidgetRef, Entry)` returns BS formatted date (`entry.bsDate`) when mode is `bs`, or AD `DateFormat('MMM dd, yyyy')` otherwise. `DateDisplay` ConsumerWidget widget for drop-in replacement.
  - **`SettingsScreen`** (`screens/settings_screen.dart`): Drawer-linked top-level page with two `SwitchListTile`s: Date Format (AD/BS) and Theme (Light/Dark). Both toggle immediately via Riverpod state.
  - **`main.dart`**: `MyApp` changed to `ConsumerWidget` — reads `themeModeProvider` and sets `MaterialApp.themeMode`, `theme` (light), `darkTheme` (dark using same seed color). Added `/settings` route.
  - **Drawer:** Added `settings` to `DrawerDestination` enum, "Settings" ListTile with `Icons.settings` in `app_drawer.dart`, route-aware navigation.
  - **BS date picker:** Entry Form's date picker shows `showMaterialDatePicker` (Nepali calendar) when BS mode is active, converting via `_date.toNepaliDateTime()` / `picked.toDateTime()`.
  - **Date format applied app-wide** in:
    - `entry_list_screen.dart` — transaction tiles use `DateDisplay`
    - `reports_screen.dart` — transaction tiles use `DateDisplay`
    - `transaction_detail_screen.dart` — detail Date row reads `dateFormatProvider`
    - `entry_form_screen.dart` — date label shows BS formatted via `NepaliDateTime.format()`
  - Settings persist across app restarts via `SharedPreferences`.
  - Builds with 0 errors (flutter analyze).
- ✅ **34. Bug fix: transaction tile subtitle overflow with BS dates** — Done on 2026-07-29.
  - **Root cause:** The subtitle `Row` (`DateDisplay` + `  •  CategoryName`) had no `Expanded`/`Flexible` wrapping — both child `Text` widgets took their intrinsic width. BS mode dates (e.g. "13 Shrawan 2083") are longer than AD dates ("Jul 28, 2026"), overflowing into the fixed-width `trailing` amount column.
  - **Fix:** Wrapped text children in `Expanded` → inner `Row` with `Flexible` around each child, with `maxLines: 1` and `TextOverflow.ellipsis`. Also added `maxLines`/`overflow` params to `DateDisplay` widget.
  - **Files changed:** `widgets/date_display.dart`, `screens/entry_list_screen.dart`, `screens/reports_screen.dart`.
  - **Other screens verified safe:** `TransactionDetailScreen` uses `_detailRow` with `Expanded` for value; Dashboard/Pending don't render entry dates in constrained Rows.
  - Builds with 0 errors (flutter analyze).
- ✅ **35. Bug fix: Reports month/year selector respects BS mode** — Done on 2026-07-31.
  - **Root cause (two bugs):** (1) `_year`/`_month` in `ReportsScreen` were AD values reused for both modes, so in BS mode the dropdowns showed an AD year (not in the BS-year items list — Flutter `DropdownButton` asserts) against BS month names, i.e. a mismatched/stale period. (2) `_isBs` read `dateFormatProvider` with `ref.read` only — the screen never rebuilt and never refetched when the app-wide AD/BS toggle changed while Reports was open.
  - **Fix:** The screen now keeps the selected period in **both** calendars — `_adYear/_adMonth` and `_bsYear/_bsMonth` — kept in sync on every pick via `nepali_utils` conversion (`DateTime(...).toNepaliDateTime()` ↔ `NepaliDateTime(...).toDateTime()`), so switching modes never resets to today; the selector shows the equivalent period in the other calendar.
  - **AD mode:** unchanged two-dropdown picker (month names + a year dropdown). The AD year dropdown is now derived from the BS picker range (`NepaliDateTime(bsMin,1,1).toDateTime().year` … `NepaliDateTime(bsMax,12,30).toDateTime().year`) so the converted equivalent AD year is always a valid dropdown item.
  - **BS mode:** replaced the dropdowns with a tappable "BS Month: <Month> <Year>" field that opens `showMaterialDatePicker` (the exact Nepali calendar widget the Entry Form's date field uses) — no new picker was built. `initialDate` is clamped into the picker's range to guard the boundary case where an AD pick maps to a BS month just outside it. Selected `year`/`month` drive the data fetch directly.
  - **Mode-change handling:** `build` now does `ref.watch(dateFormatProvider)` (selector + subtitle rebuild on toggle) and `initState` registers `ref.listen(dateFormatProvider, ...)` which calls `_loadData()` so both tabs refetch with the active mode's params.
  - **Data-fetch params confirmed:** BS mode sends `bsYear`/`bsMonth` to both `getTrialBalance()` and `getEntries()` (backend `GET /api/Entry` and `trial-balance` both compute the AD range from `bsYear/bsMonth`); AD mode sends `year`/`month` to trial-balance and AD `from`/`to` to `GET /api/Entry`. The selector's picked value is exactly what is sent — no stale values.
  - **Files changed:** `screens/reports_screen.dart`.
  - Builds with 0 errors (flutter analyze); conversion sanity tests pass (AD↔BS round-trip, dropdown bounds, picker clamp).
- ✅ **36. Bug fix: Trial Balance table + Dashboard charts readable in dark mode** — Done on 2026-07-31.
  - **Trial Balance table (primary target):** replaced all hardcoded light-mode colors with theme tokens —
    - Cell/header text: `Theme.of(context).colorScheme.onSurface` (was `Colors.black`).
    - Header row background: `colorScheme.surfaceContainerHighest` (subtle shade distinct from body rows; was `Colors.grey.shade100`).
    - Regular row borders: `colorScheme.outline`, with alpha dropped to 0.6 in dark mode so the grid doesn't look harsh (was `Colors.grey.shade400`/black).
    - Totals row thick divider: kept 2px `BorderSide(color: colorScheme.onSurface)` — full-opacity `onSurface` gives higher contrast than the regular dividers, so the totals row stays visually distinct in both light and dark mode.
    - Empty state + subtitle text: `colorScheme.onSurfaceVariant` (was `Colors.grey.shade600`).
  - **Reports Transactions tab:** income/expense icon + amount colors are now brightness-aware — `Colors.green`/`Colors.red` in light mode, `Colors.green.shade400`/`Colors.red.shade400` in dark mode so they stay legible against a dark card (same green/red scheme used app-wide, no new colors).
  - **Dashboard charts (checked while in the area):** summary label `Colors.grey` → `colorScheme.onSurfaceVariant`; Monthly Trend track `Colors.red.shade100` → `colorScheme.errorContainer` (keeps the red expense tint, dark-friendly); `IncomeVsExpenseChart` and `SavingsChart` axis labels now use `colorScheme.onSurfaceVariant` and gridlines use `colorScheme.outlineVariant` (alpha 0.5) instead of fl_chart's light-grey defaults; `TopSpendingList` progress track `Colors.grey.shade200` → `colorScheme.surfaceContainerHighest`.
  - **Also fixed:** `transaction_detail_screen.dart` screenshot-placeholder used deprecated `colorScheme.surfaceVariant` → `surfaceContainerHighest` (resolves deprecation info).
  - **Files changed:** `screens/reports_screen.dart`, `screens/dashboard_screen.dart`, `screens/transaction_detail_screen.dart`, `widgets/income_vs_expense_chart.dart`, `widgets/savings_chart.dart`, `widgets/top_spending_list.dart`.
  - Builds with 0 errors, 0 warnings (flutter analyze).

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

---

## 10. Deploy Backend to Render + Neon (Step-by-Step Plan)

**Instructions for the agent:** Work through these steps in order, one at a time. Before starting each step, tell the user exactly what you are about to do and why. After completing each step, show the user what changed (files touched, commands run, output) and **wait for explicit confirmation before moving to the next step.** Do not skip ahead or batch multiple steps together, even if the fix seems obvious.

**Rollback rule (applies to every step):** Before making any change, note what the previous working state was (e.g., "last known good": SQL Server LocalDB provider, current commit hash, current file contents). If a step fails, produces unexpected output, or the user says it's wrong, **immediately revert that step's changes back to the last known good state** (`git checkout`/`git revert` for code, undo the specific config/env var change on Render or Neon's dashboard) before reporting back. Do not attempt a fix-forward patch on top of a broken step unless the user explicitly asks for one. Confirm with the user that the revert is complete and the app is back to its last working state, then wait for their instruction on how to proceed — do not automatically retry the step.

Context: ASP.NET Core Web API backend (currently using SQL Server LocalDB) + Flutter frontend. Deploying backend web service to **Render** (free tier) and the database to **Neon** (free tier Postgres with no expiry date — this must remain running permanently, not a 30-day trial). Single user only — no multi-user auth needed, just a simple API key gate. CI/CD via GitHub Actions already exists (main branch → Render deploy).

**Why Neon instead of Render Postgres:** Render's own free Postgres database expires 30 days after creation and is deleted after a 14-day grace period unless upgraded to paid. Since this app needs to run indefinitely with real data, the database must live on a provider with a genuinely permanent free tier. Neon fits that — Render still hosts the API/web service, only the database connection string points to Neon.

---

**STATUS: Steps 1-3 are already complete** (EF Core provider swapped from SQL Server to PostgreSQL, and the initial Postgres migration has been generated). Do not redo them. Before resuming at Step 4, first do a quick sanity check: confirm the current build still compiles clean, confirm the Step 2/3 commit is the current rollback point going forward, and confirm no real (non-placeholder) connection string or credentials were accidentally committed during steps 1-3. Report the sanity check result to the user, then proceed to Step 4.

### Step 1 — Audit current data layer *(completed)*
- Find every place `UseSqlServer` is referenced (likely `Program.cs`/`Startup.cs` and `DbContext` configuration).
- List all existing EF Core migrations.
- Note the current commit hash as the rollback point for this whole migration effort.
- Report findings to the user before touching anything.
- **Ask the user:** "Confirmed — here's what I found using SQL Server, and I've noted commit `<hash>` as our rollback point. Should I proceed with swapping to PostgreSQL?"
- **Result:** Found `UseSqlServer` in `Program.cs:9`, `Microsoft.EntityFrameworkCore.SqlServer` v10.0.10 in `.csproj`, connection string in `appsettings.json`. 8 SQL Server migrations in `Migrations/`. User approved proceed.

### Step 2 — Swap EF Core provider to PostgreSQL *(completed)*
- Remove `Microsoft.EntityFrameworkCore.SqlServer` NuGet package.
- Add `Npgsql.EntityFrameworkCore.PostgreSQL` NuGet package.
- Change `UseSqlServer(...)` to `UseNpgsql(...)` in the DbContext configuration.
- Use a placeholder connection string for now — no real credentials yet.
- Build the project to confirm it compiles.
- **If the build fails:** revert the package changes and code edit back to the Step 1 commit hash, report the exact build error, and stop.
- **Ask the user:** "Provider swapped and build succeeds. Do you want me to regenerate migrations now, or review the diff first?"
- **Result:** Swapped `.csproj` package to `Npgsql.EntityFrameworkCore.PostgreSQL` v10.0.3 (latest stable; 10.0.10 doesn't exist for Npgsql). Changed `UseNpgsql(...)` in `Program.cs`. Updated `appsettings.json` connection string to `Host=localhost;Database=FinanceTracker;Username=postgres;Password=placeholder`. `dotnet restore` succeeded.

### Step 3 — Regenerate migrations for Postgres *(completed)*
- Confirm with the user: fresh migration history vs. keeping old SQL-Server migrations for reference.
- Run `dotnet ef migrations add InitialPostgresMigration`.
- Do **not** apply it to any live database yet.
- **If migration generation errors out:** delete the partially-generated migration files and revert to the state after Step 2, report the error, and stop.
- **Ask the user:** "Migration generated. Should I test this locally against a local Postgres instance before we touch Neon?"
- **Result:** Deleted entire `Migrations/` folder (old SQL Server migrations cannot coexist — they reference `SqlServerModelBuilderExtensions` which no longer exists). Ran `dotnet ef migrations add InitialPostgresMigration` — generated 3 files: `.cs`, `.Designer.cs`, `AppDbContextModelSnapshot.cs`. `dotnet build` succeeded with 0 errors, 0 warnings.

### Step 4 — Create Neon DB + .env + apply migration (⚠️ Manual — user must do this)
- Guide the user through creating a **free Neon project** at neon.tech (this requires the user to click through Neon's UI — the agent cannot do this itself).
- Confirm with the user that this is Neon (not Render's built-in Postgres) — this is the piece that must not expire.
- Have the user paste the Neon connection string, to be stored only as a `.env` file, never hardcoded in source.
- Update app configuration to read from the environment variable at runtime.
- Run `dotnet ef database update` against Neon to apply the migration.
- **Ask the user:** "Schema applied and verified on Neon. Ready to move on to the API key security step?"

**4a. Manual — Create Neon project:**
1. Go to [neon.tech](https://neon.tech) → sign up / log in (GitHub sign-in is easiest).
2. Click **Create Project**.
3. **Project name:** `finance-tracker` (or anything you like).
4. **Database name:** `financetracker` (or leave default).
5. **Region:** closest to you (e.g. US East for Americas, Singapore for Asia).
6. **Plan:** leave on **Free** (0.5 GB storage, no expiry — this is permanent).
7. Click **Create Project**.
8. Once created, Neon shows a **Connection Details** modal. Select **Pooled connection** → **URL** format.
9. Copy the full connection string — it looks like:
   `postgresql://neondb_owner:ABC123@ep-xxxxx.us-east-2.aws.neon.tech/financetracker?sslmode=require`
10. **Reset the password** first (Neon dashboard → Users → reset password) so you have a known password, then copy the updated pooled connection string.
11. Paste the connection string here (the agent will write it into `.env`).
12. **Important:** Neon's connection string requires `sslmode=require` — make sure it's included.

**4b. Agent — Create `.env` file and update config:**
- Add a `.env` file in `backend/` root with:
  ```
  DATABASE_URL="<paste the pooled connection string here>"
  ```
- Confirm `.env` is in `.gitignore` and has never been committed to git history.
- Update `Program.cs` / `AppDbContext` to read the connection string from `Environment.GetEnvironmentVariable("DATABASE_URL")` (or `IConfiguration` with `DotNetEnv` / manual env loading), falling back to the placeholder in `appsettings.json` for local dev.
- Update `appsettings.json` to keep the placeholder as fallback (so local dev still works without `.env`).
- **Result:** `.env` created at `backend/.env` with a placeholder `DATABASE_URL` (gitignored, never committed — confirmed via `git ls-files`). Added `DotNetEnv` v3.2.0 NuGet package. Updated `Program.cs` to call `DotNetEnv.Env.TraversePath().Load()` then read `Environment.GetEnvironmentVariable("DATABASE_URL")` with fallback to `appsettings.json` `DefaultConnection` placeholder. `dotnet restore` + `dotnet build` succeeded (0 errors, 0 warnings). `.env.*` was already in `.gitignore` (lines 44-45). No `DATABASE_URL`/`neon`/`sslmode` strings exist in git history.

**4c. Agent — Apply migration to Neon:**
- Run `dotnet ef database update` using the Neon connection string.
- Verify tables (Entries, Bills, Transactions) were created correctly by querying Neon directly or checking migration output.
- **If the migration fails partway:** run `dotnet ef database update 0` to roll the Neon database back to empty, delete the bad migration if it was malformed, and report the exact error before proceeding.
- **Result:** Migration `20260831113324_InitialPostgresMigration` applied successfully to Neon. Created `Entries`, `Bills`, `Transactions` tables (with FKs, indexes, `numeric(18,2)` amounts, `timestamp with time zone` dates) plus `__EFMigrationsHistory`. Verified directly by querying Neon's `pg_tables` — all 4 tables present.
- **Bug + fix (connection string format):** Npgsql's `NpgsqlConnectionStringBuilder` does **not** accept Neon's URI-style connection string (`postgresql://...`). It expects a key-value form (`Host=...;Database=...;Username=...;Password=...`). The first `dotnet ef database update` failed with `Couldn't set postgresql://... (Parameter ...)`. **Fix:** added `ConnectionStringHelper.cs` which detects a `postgres://`/`postgresql://` URI, parses it into an `NpgsqlConnectionStringBuilder` (Host/Port/Database/Username/Password + `SslMode=Require`), and returns a valid key-value connection string. `Program.cs` now calls `ConnectionStringHelper.Normalize(...)` on the resolved `DATABASE_URL`. `TrustServerCertificate` was skipped (obsolete in Npgsql 10). Build clean (0 errors, 0 warnings) after fix.

### Step 5 — Add API key middleware ✅ DONE (local smoke test passed on 2026-09-01)
- Create a middleware class checking for an `X-Api-Key` header on every request.
- Compare against a value read from `IConfiguration`, sourced from an environment variable — never hardcoded.
- Return `401 Unauthorized` if missing or incorrect.
- Register the middleware after routing, before controllers.
- Exclude a lightweight health-check endpoint if one exists, so Render's health checks still pass.
- **If this breaks existing endpoints or the health check:** remove the middleware registration (revert this file only) and report which endpoint broke, before retrying.
- **Ask the user:** "Middleware added. Want me to generate a random API key now, or do you already have one?"

**Status:**
- ✅ Committed Step 4 as rollback checkpoint `2f296cd` (Postgres swap + Neon migration + ConnectionStringHelper). `.env` was NOT committed (gitignored).
- ✅ Created `backend/Middleware/ApiKeyMiddleware.cs` — checks `X-Api-Key` header against `configuration["ApiKey"]` (from env var), returns `401` if missing/incorrect; bypasses auth for `/health` path.
- ✅ Added `/health` endpoint (`GET /health` → `{ status: "ok" }`) in `Program.cs` for Render health checks (excluded from API-key middleware).
- ✅ Registered `app.UseMiddleware<ApiKeyMiddleware>()` in `Program.cs` after `UseHttpsRedirection`, before `MapControllers()`.
- ✅ Added `using FinanceTracker.Api.Middleware;` to `Program.cs`.
- ✅ Build succeeds (0 errors, 0 warnings).
- ✅ **Local smoke test completed** on 2026-09-01 against Neon (real `.env` DATABASE_URL → startup migration check "database already up to date"):
  - `/health` (no key) → **200** ✅
  - `/api/Entry` (no key) → **401** ✅
  - `/api/Entry` with `X-Api-Key: smoke-test-key-opencode-2026` → **200** ✅
  - App was tested on port **5044** instead of 5099 — `builder.WebHost.UseUrls("http://0.0.0.0:5044")` in `Program.cs` hard-sets the URL and overrides `ASPNETCORE_URLS`/launchSettings, so 5099 never binds. Port number is irrelevant to the middleware behavior; 5044 is the production-matching port.
  - Background `dotnet run` process killed and verified no listener remains on 5044.
- ✅ Committed Step 5 as rollback checkpoint `a596c37` (ApiKeyMiddleware + `/health` endpoint + `UseMiddleware<ApiKeyMiddleware>()` registration in `Program.cs`). Working tree clean. Rollback point going forward: **`a596c37`**.
- **Next up:** Step 6 (disable Swagger in production). The real API key value gets set on Render in Step 7 (env var `ApiKey`), not locally — the throwaway key above only proves the middleware works.

### Step 6 — Disable Swagger in production ✅ DONE (2026-09-06)
- **Finding:** Swagger/OpenAPI was **never wired into this project** — `Program.cs` has no `AddOpenApi()`/`MapOpenApi()`/`UseSwagger()` calls (verified across git history back to the beta commit `db01af3`, and grepping the repo for `Swagger`/`OpenAPI`/`AddEndpointsApiExplorer` returns nothing). The ASP.NET Core template's Swagger block appears to have been removed long before the deployment work began.
- **Result:** There is no API explorer served now or in production — nothing to disable, and no Swagger endpoint can ever be reached after deploy. Step 6's intent (no API explorer on production) is already satisfied; no code change required.
- **Next up:** Step 7 (set environment variables on Render — manual dashboard action).

### Step 7 — Set environment variables on Render
- List exactly which env vars need to be set on Render's dashboard: **Neon** connection string, API key value, `ASPNETCORE_ENVIRONMENT=Production`.
- Have the user confirm each one is set (agent cannot set these directly).
- **Ask the user:** "Please confirm these env vars are set on Render, then I'll proceed to trigger a deploy."

### Step 8 — Deploy and smoke test
- Push changes to a branch (or main, per the user's existing workflow) to trigger the GitHub Actions pipeline.
- Once deployed, `curl` the Render URL's health/root endpoint — first without the API key (expect 401), then with it (expect success).
- **If the deploy fails or the smoke test fails:** revert the branch/commit that triggered the deploy back to the last known good commit (the one before Step 2, or the most recent successfully-deployed one), redeploy that, confirm the old version is back up and serving traffic, then report the failure before touching anything further.
- **Ask the user:** "Deploy succeeded and the API key check is working. Ready to move to the Flutter side?"

### Step 9 — Point Flutter app at the Render URL
- Update the Flutter app's base API URL (currently localhost/laptop IP) to the Render `.onrender.com` URL.
- Add the `X-Api-Key` header to the app's HTTP client, reading the key from a config file **not** committed to source control.
- **If the app fails to reach the new URL or auth fails:** revert the base URL and header change back to pointing at the laptop backend, confirm the app works again locally, then report the exact error.
- **Ask the user:** "Flutter app updated to point at Render with the API key attached. Want me to run a full end-to-end test now?"

### Step 10 — End-to-end verification
- Open the app on phone/emulator → create a test entry → confirm it appears in Neon → confirm Dashboard/Table views load from the live Render backend.
- Report pass/fail on each check.
- **If any check fails:** identify which layer failed (Flutter → Render, or Render → Neon) and revert only that layer's most recent change, not the whole stack, then report before retrying.
- **Ask the user:** "All checks passed — anything you'd like me to double-check, or are we done here?"

### Step 11 — Set up a recurring backup (permanence safeguard)
- Add a scheduled GitHub Action (e.g. weekly) that runs `pg_dump` against the Neon connection string and saves the dump as a build artifact or emails it, so the user is never solely dependent on Neon's uptime.
- Confirm the action runs successfully at least once manually before relying on the schedule.
- **Ask the user:** "Backup job is set up and tested. Anything else before we call this done?"

---

**Reminders for the agent throughout:**
- Never commit secrets (API keys, connection strings) to source control — always use environment variables / dashboard secret management.
- Neon is the database, permanently — do not substitute Render's built-in free Postgres at any point, since that one expires after 30 days.
- If a step requires manual action on Render's or Neon's dashboard, say so clearly — you cannot click through their UI.
- On any failure: revert first, report second, wait for the user's go-ahead before retrying — never fix-forward silently.