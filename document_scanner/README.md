# Scanova — AI Document Scanner (Flutter)

A production-quality document scanning app in the spirit of Adobe Scan /
Microsoft Lens / CamScanner, with an original UI. Built with Flutter using
clean architecture so native scanning, OCR, and PDF pipelines can be
dropped in without restructuring the app.

This repository currently contains **Phases 1–6**: the full UI flow
(Phase 1), a real device camera with gallery import (Phase 2), real
pixel-level image processing — perspective correction, rotation, and
filters (Phase 3), real multi-page PDF generation, storage, and sharing
(Phase 4), real on-device OCR with SQLite-backed persistence (Phase 5),
and real Google/email auth with an outbound cloud sync queue (Phase 6)
— gated behind a Firebase project you provide (see section 8). AI
features (Phase 7) are still UI-complete but simulated — see the phase
sections below for exactly what's real versus mocked in each area.

---

## 1. Architecture

**Pattern:** feature-first Clean Architecture. Each feature owns its own
`domain` (entities, business rules), `data` (repositories — mock today,
real backends later, behind the same interface), and `presentation`
(screens, widgets, state) layers. Cross-cutting UI, error types, and
constants live in `core/`; reusable UI-only widgets live in `shared/`.

**State management:** `provider` (`ChangeNotifier`). Chosen over
Bloc/Riverpod for this phase because the state graph is small
(documents, in-progress scan session, settings) and `provider` keeps the
UI code readable; swapping to Riverpod later is a mechanical change since
business logic lives in provider classes, not widgets.

**Navigation:** `go_router`, declarative and deep-link-ready. Route
constants live in `core/router/app_router.dart` — no screen hard-codes a
path string.

**Why this shape scales:** the Scanner, OCR, Documents, and PDF features
are separated by responsibility, each with its own `data` layer behind
a small interface. That's why adding the `camera` plugin (Phase 2) only
touched `features/scanner/data` and the camera screen's internals —
crop/enhance/page-manager kept consuming the same `ScanSessionProvider`
API — and why adding real OCR (Phase 5, `google_mlkit_text_recognition`)
and real persistence (Phase 5, `sqflite`) only meant adding
`OcrService` and `DocumentsDatabase` behind the existing
`DocumentsProvider`/`OcrResultScreen` surface, with no screen rewrites.

## 2. Required packages

**In `pubspec.yaml` today:**
| Package | Purpose |
|---|---|
| `go_router` | Declarative navigation |
| `provider` | State management |
| `google_fonts` | Typography (Inter) |
| `intl` | Date formatting |
| `uuid` | Local IDs for scan pages |
| `camera` | Live preview, capture (Phase 2) |
| `image_picker` | Gallery import, page replace (Phase 2) |
| `permission_handler` | Camera permission request + friendly denial UI (Phase 2) |
| `image` | Pixel-level perspective warp, filters, brightness/contrast/sharpen (Phase 3) |
| `pdf` | Real multi-page PDF composition (Phase 4) |
| `path_provider` | Where captures, generated PDFs, and the SQLite file live on disk (Phases 4–5) |
| `share_plus` | Native share sheet for PDFs and extracted text (Phase 4–5) |
| `sqflite` | Local document library persistence (Phase 5) |
| `google_mlkit_text_recognition` | Real on-device OCR — Latin and Devanagari script models (Phase 5) |
| `firebase_core` | Firebase SDK bootstrap (Phase 6) |
| `firebase_auth` | Google + email/password sign-in (Phase 6) |
| `google_sign_in` | Google account picker used by Firebase Auth's Google provider (Phase 6) |
| `cloud_firestore` | Document metadata sync (Phase 6) |
| `firebase_storage` | Generated PDF upload (Phase 6) |

**Planned for later phases** (not added yet, so the app stays buildable
today — add each when its phase starts):
| Phase | Package(s) | Purpose |
|---|---|---|
| Apple Sign-In | `sign_in_with_apple` + Xcode capability/entitlement setup | Needs native iOS project config this repo doesn't have yet — see Phase 6 notes |
| Security | `flutter_secure_storage` | Sensitive metadata at rest |
| PDF encryption | TBD — needs SDK access to confirm the `pdf` package's current encryption API | Password-protected PDFs (currently captured in the UI but not enforced — see Phase 4 notes) |
| OCR for Tamil/Kannada | TBD — a cloud OCR fallback (e.g. Cloud Vision), gated behind Premium | ML Kit's on-device recognizer has no Tamil/Kannada script model — see Phase 5 notes |

## 3. Folder structure

```
lib/
  core/
    constants/     app_colors.dart, app_spacing.dart, app_strings.dart
    theme/         app_theme.dart (light/dark ThemeData + semantic color extension)
    errors/        app_exception.dart (typed, user-facing failures)
    router/        app_router.dart (go_router routes + path constants)
    services/       FirebaseBootstrap (safe init), SyncCoordinator (app-level auth/settings/documents wiring — the one place `core/` intentionally depends on features, as the composition root)
    utils/         (reserved for future formatters/helpers)

  features/
    home/presentation/            Dashboard: CTA, quick actions, recent docs
    scanner/
      domain/entities/            ScanPage (real imagePath + cropCorners), PageFilter
      data/                       ImageProcessor (perspective warp, filters, adjust — real, pure Dart)
      presentation/providers/     ScanSessionProvider (in-progress scan state; supports re-opening a saved document for editing)
      presentation/screens/       Camera (real `camera` plugin), Crop, Enhancement (real live-processed preview), Page Manager
      presentation/widgets/       DetectionFramePainter
    documents/
      domain/entities/            ScannedDocument (+ pdfPath, updatedAt/syncedAt), DocumentCategory
      data/                       MockDocumentsRepository (demo seed), database/DocumentsDatabase (real sqflite persistence + sync queue), sync/CloudSyncRepository + SyncService (real Firestore/Storage upload)
      presentation/providers/     DocumentsProvider (library state, persists + reports every mutation), SyncStatusProvider (read-only sync status for the UI)
      presentation/screens/       Documents library (grid/list/search/sort)
      presentation/widgets/       DocumentGridItem
    pdf/
      domain/entities/            PdfOptions
      data/                       PdfGenerator (real `pdf`-package generation, runs via `compute()`)
      presentation/screens/       PdfCreateOptionsScreen, PdfPreviewScreen (real Share via `share_plus`)
    ocr/
      domain/entities/            OcrLanguage
      data/                       OcrService (real Google ML Kit on-device recognition)
      presentation/screens/       OcrResultScreen
    settings/
      presentation/providers/     SettingsProvider
      presentation/screens/       SettingsScreen
    authentication/
      domain/entities/            AppUser
      data/                       AuthService (real Firebase Auth: Google + email/password)
      presentation/providers/     AuthProvider
      presentation/screens/       SignInScreen (optional)

  shared/widgets/                 PrimaryButton, SectionHeader, AppShell (bottom nav), PageThumbnail (real file or placeholder)
  main.dart                       Provider wiring + MaterialApp.router
```

## 4. Database structure (Phase 5 — `documents`/`pages` implemented)

[`DocumentsDatabase`](lib/features/documents/data/database/documents_database.dart)
implements the `documents` and `pages` tables below with `sqflite`,
behind the same small surface (`loadAll`/`upsert`/`delete`) so
`DocumentsProvider` never touches SQL directly. `folders` and
`sync_queue` are modeled here as the Phase 6 target — folders aren't a
real entity yet (`ScannedDocument.folder` is a free-text field with no
table behind it), and there is no cloud sync to queue for yet.

```
documents                        -- implemented
  id TEXT PRIMARY KEY
  name TEXT
  created_at INTEGER
  folder TEXT NULL                -- free-text for now; see folders below
  is_favorite INTEGER
  size_kb INTEGER
  category TEXT
  extracted_text TEXT NULL
  pdf_path TEXT NULL
  thumbnail_color INTEGER         -- ARGB int, Phase 1 placeholder color

pages                            -- implemented
  id TEXT PRIMARY KEY
  document_id TEXT REFERENCES documents(id) ON DELETE CASCADE
  position INTEGER
  original_image_path TEXT NULL
  original_color INTEGER          -- ARGB int placeholder, mirrors ScanPage.originalAssetColor
  crop_corners TEXT NULL          -- JSON-encoded [[x,y],[x,y],[x,y],[x,y]], normalized 0..1
  rotation_degrees INTEGER
  filter TEXT
  brightness REAL
  contrast REAL
  sharpness REAL

folders                          -- still a target — no table yet
  id TEXT PRIMARY KEY
  name TEXT
  created_at INTEGER

sync_queue                       -- implemented (Phase 6)
  document_id TEXT PRIMARY KEY REFERENCES documents(id)
  status TEXT                    -- pending | uploading | failed
  retry_count INTEGER
  last_error TEXT NULL
```

`documents` also gained `updated_at` and `synced_at` columns in schema
version 2 (`DocumentsDatabase._createV2Additions`, with a real
`onUpgrade` path — the "no migrations yet" gap flagged after Phase 5 is
now the actual example of how migrations work here). `sync_queue` uses
`document_id` as its primary key rather than a separate `id`, since a
document only ever needs one pending upload at a time — a new local
change just replaces the existing queue row instead of stacking up
duplicate jobs.

Every `DocumentsProvider` mutation updates the in-memory list first
(so the UI never waits on disk I/O) and persists to SQLite in the
background afterward; a failed write is swallowed rather than
propagated, so a storage hiccup never corrupts the in-memory state or
crashes the app. On first launch (empty database), the library shows
the mock sample documents as demo content without writing them to
disk — they only become persisted rows once the user actually
interacts with one (favorite, rename, etc.), so a fresh install never
leaves stale demo rows behind once real documents exist.

`ScanPage` now carries a real `originalImagePath` (set by the camera or
gallery import) alongside `originalAssetColor`, which remains only as a
placeholder for pages that have no file (Phase 1 mock documents, or a
platform without camera access). `processed_image_path` above is not
materialized as a field — [`ImageProcessor`](lib/features/scanner/data/image_processor.dart)
always re-derives the processed bytes from the original plus the stored
crop/filter/adjustment settings on demand (crop screen preview, PDF
generation), so the original file is never overwritten and nothing gets
out of sync with a stale cached copy.

## 5. Scanner implementation strategy (Phase 2–3 — implemented)

**Camera (Phase 2), done in `ScannerCameraScreen`:**
1. `permission_handler` requests camera access up front; a denial shows
   the friendly `AppStrings.cameraPermissionDenied` state with a retry
   and an "Open Settings" deep link, never a crash.
2. `availableCameras()` + `CameraController` (`camera` plugin) drive a
   real live `CameraPreview`. Flash cycles off → auto → always via
   `controller.setFlashMode`; camera switch disposes and re-opens the
   controller on the other `CameraDescription`.
3. Manual capture calls `controller.takePicture()` and stores the real
   file path on a new `ScanPage`. Gallery import uses `image_picker`'s
   `pickMultiImage` so several pages can be imported in one action.
4. **What's still simulated:** true frame-by-frame document-edge
   detection. A stabilization timer approximates "document detected"
   over the real live feed, and auto-capture fires off that timer
   rather than real contour confidence. Real detection needs a native
   OpenCV binding (e.g. `opencv_dart`) analyzing preview frames — out
   of safe scope without a Flutter SDK available to verify the binding
   compiles. The manual capture + interactive `CropScreen` path (which
   the spec explicitly requires as the fallback when detection
   confidence is low) is fully real and is the reliable path today.

**Image processing (Phase 3), done in
[`ImageProcessor`](lib/features/scanner/data/image_processor.dart) —
pure Dart via the `image` package, no OpenCV dependency:**
1. `perspectiveCrop` warps the quadrilateral defined by the Crop
   screen's four draggable corners into an upright rectangle using a
   hand-written bilinear-interpolation warp (chosen over relying on an
   unverified higher-level package API) — this corrects perspective,
   skew, and uneven positioning in one pass, exactly matching what the
   corner-handle UI already collects.
2. `copyRotate` applies the stored rotation; `applyFilter` implements
   grayscale, black & white (thresholded), high-contrast, and "document"
   presets; `adjust` maps the brightness/contrast/sharpness sliders
   (sharpening via a hand-rolled 3×3 unsharp kernel).
3. Every call goes through `processPageInIsolate` / `compute()` so nothing
   runs on the UI thread — used by both the Enhancement screen's
   debounced live preview and final PDF generation.
4. The Enhancement screen previews the *real* processed image
   (`Image.memory`) instead of a flat color swatch, downscaled to a
   `maxWorkingDimension` of 2200px for responsiveness on mid-range
   phones.

## 6. OCR implementation strategy (Phase 5 — implemented)

- [`OcrService`](lib/features/ocr/data/ocr_service.dart) wraps
  `google_mlkit_text_recognition` for real on-device OCR — works fully
  offline, satisfying the "no internet required" requirement.
- English uses ML Kit's Latin script recognizer; Hindi uses the
  Devanagari recognizer. **Tamil and Kannada are not among ML Kit's
  on-device script models**, so they currently fall back to the Latin
  recognizer — usable for mixed-script/numeric content but not a real
  Tamil/Kannada model. `OcrResultScreen` says so directly under the
  language picker rather than silently under-delivering. A cloud OCR
  fallback (e.g. Google Cloud Vision), gated behind Premium, is the
  planned fix — see the packages table in section 2.
- `OcrResultScreen` runs recognition across every real page image
  (`recognizeDocument`) and joins the results into one transcript; for
  documents with no real captured image (Phase 1 demo docs), it shows
  explanatory placeholder copy instead of failing. Results are cached
  via `DocumentsProvider.setExtractedText`, which persists to SQLite, so
  re-opening a document doesn't need to re-run recognition.
- Recognition calls go through ML Kit's own platform channel, which is
  already async and off the UI thread on the native side — no manual
  isolate wrapping needed (and `compute()` isn't a good fit here since a
  spawned isolate can't use platform channels without extra setup).
- Failures never crash the app: `OcrService.recognizePage` wraps ML Kit
  exceptions in `core/errors/app_exception.dart`'s `OcrException`, and
  `OcrResultScreen` catches it and shows `AppStrings.ocrFailure`
  ("We couldn't recognize the text. Try a clearer scan.") instead of a
  blank or broken screen.

## 7. PDF implementation strategy (Phase 4 — implemented)

- [`PdfGenerator`](lib/features/pdf/data/pdf_generator.dart) uses the
  `pdf` package's `pw.Document`/`pw.Page`/`pw.Image` to compose one page
  per `ScanPage`, each run through the exact same `ImageProcessor` used
  by the live Enhancement preview (crop, rotation, filter, brightness/
  contrast/sharpness) so the PDF matches what the user saw.
- Page size follows `PdfOptions.format`: A4/Letter use the `pdf`
  package's standard `PdfPageFormat.a4`/`.letter`; "Original size"
  derives a page format from the processed image's own pixel dimensions
  (assuming a 150dpi capture) so the PDF page matches the source
  document's proportions instead of stretching into a fixed size.
- **Compression/quality**: `PdfQuality` (high/medium/low) maps to a JPEG
  quality (90/75/50), and the "Compress PDF" toggle subtracts a further
  20 points — real re-encoding, not a cosmetic setting.
- Generation runs via `compute()` (`generatePdfInIsolate`) so the UI
  thread stays free for documents with many pages — the target scale is
  the 50–100 page range called out in the performance requirements.
- The finished PDF is written directly to the app's documents directory
  (`path_provider`'s `getApplicationDocumentsDirectory`) and the path is
  stored on `ScannedDocument.pdfPath`. Sharing (`PdfPreviewScreen`'s
  Share/Download actions) uses `share_plus`'s `Share.shareXFiles` on
  that real file through the native OS share sheet.
- When "Save Original Image" is off in Settings, each page's original
  capture is deleted right after the PDF is written (the PDF itself
  always keeps the processed image, so nothing is lost) — implementing
  the security requirement to not leave temporary image files around.
- **Not yet implemented — password protection.** The Create PDF screen
  captures a password and stores it as document metadata, but does not
  encrypt the file. This needed either verifying the exact encryption
  API surface of the pinned `pdf` package version or a lower-level PDF
  security library, neither of which could be confirmed without a
  Flutter SDK/docs access in this environment — guessing at the API
  risked a build that silently doesn't compile. The UI says so directly
  under the Password Protection toggle rather than implying it works.
- **Re-editing a saved document.** "Add page" / "Edit pages" / "Reorder"
  on `PdfPreviewScreen` call `ScanSessionProvider.loadForEditing`, which
  reloads that document's pages into the active scan session and tags
  the session with the document's id; finishing the flow through
  `PdfCreateOptionsScreen` then regenerates the PDF and calls
  `DocumentsProvider.updateDocument` on the same id instead of creating
  a duplicate document.

## 8. Cloud sync & auth strategy (Phase 6 — implemented, gated on your Firebase project)

**This phase needs a real Firebase project you provide** — Google/email
sign-in and sync literally cannot work without one, so
[`lib/firebase_options.dart`](lib/firebase_options.dart) ships as an
intentional placeholder that throws a clear error instead of silently
using fake credentials. See **Installation commands** below for the
`flutterfire configure` step. Everything else in the app (scanning,
editing, OCR, PDF, local library) works exactly the same whether or not
this is ever configured — [`FirebaseBootstrap`](lib/core/services/firebase_bootstrap.dart)
catches the init failure at startup and the app runs in local-only mode.

- **Auth**: [`AuthService`](lib/features/authentication/data/auth_service.dart)
  wraps `firebase_auth` + `google_sign_in` for real Google and
  email/password sign-in and sign-up, mapped to a plain `AppUser` so no
  screen touches the Firebase SDK directly. `AuthProvider` exposes
  sign-in state as a `ChangeNotifier` via `authStateChanges`.
  **Apple Sign-In is not implemented** — it needs an Xcode capability
  and entitlements file added to the `ios/` project, which doesn't
  exist in this repo yet (see Installation commands) and can't be
  scaffolded headlessly; `SignInScreen`'s Apple button says so instead
  of pretending to work.
- **Sync direction — outbound only.** [`CloudSyncRepository`](lib/features/documents/data/sync/cloud_sync_repository.dart)
  uploads a document's metadata to Firestore
  (`users/{uid}/documents/{id}`) and its generated PDF to Storage
  (`users/{uid}/documents/{id}.pdf`). It does **not** pull remote
  changes back down or merge them — so two devices signed into the same
  account will each upload their own local documents, but won't yet see
  each other's. A real two-way sync (download + last-write-wins using
  the new `updatedAt` field, or a proper CRDT/merge strategy) is future
  work; this phase delivers the "back up what's local" half honestly
  rather than a half-working merge that silently loses data.
- **Offline queue + retry**: [`SyncService`](lib/features/documents/data/sync/sync_service.dart)
  drains the `sync_queue` table — every document with local changes
  newer than its last successful sync gets enqueued, uploaded, and
  dequeued on success; a failed upload (offline, permission error,
  whatever) stays queued with an incremented retry count and the error
  message, surfaced in Settings' new **Sync Status** row with a
  **Retry** button.
- **When it runs**: [`SyncCoordinator`](lib/core/services/sync_coordinator.dart)
  (instantiated once in `main.dart`) is the only place that decides
  *when* to sync — on sign-in, on toggling Cloud Sync on, and after
  every local document change — by listening to `AuthProvider` and
  `SettingsProvider` and hooking `DocumentsProvider.onDocumentChanged`/
  `onDocumentDeleted`. Cloud sync only ever fires when
  `AuthProvider.isSignedIn && SettingsProvider.cloudSyncEnabled` are
  both true; `DocumentsProvider` itself has zero compile-time knowledge
  of auth or Firebase, so local-only usage is provably unaffected.
- **Conflict resolution**: within this outbound-only scope, "conflict"
  reduces to "is my local copy newer than what I last uploaded" —
  `ScannedDocument.isSynced` compares `updatedAt` against `syncedAt` and
  that's the whole policy. Real cross-device conflict resolution needs
  the download half described above first.

---

## Phases 1–6 (this delivery)

### Files created/modified since Phase 5
New: `lib/firebase_options.dart` (placeholder — see Installation
commands), `lib/core/services/firebase_bootstrap.dart`,
`lib/core/services/sync_coordinator.dart`,
`lib/features/authentication/domain/entities/app_user.dart`,
`lib/features/authentication/data/auth_service.dart`,
`lib/features/authentication/presentation/providers/auth_provider.dart`,
`lib/features/documents/data/sync/cloud_sync_repository.dart`,
`lib/features/documents/data/sync/sync_service.dart`,
`lib/features/documents/presentation/providers/sync_status_provider.dart`.
Modified: `SignInScreen`, `SettingsScreen`, `SettingsProvider`,
`DocumentsProvider`, `DocumentsDatabase` (v2 schema + sync queue),
`ScannedDocument` (+ `updatedAt`/`syncedAt`), `main.dart`,
`pubspec.yaml`. See the folder structure and section 8 above for what
each does.

### What's implemented
- Full navigation flow unchanged from Phase 5, plus: Settings → **Sign
  In** (real Google or email/password auth) → Cloud Sync toggle → a
  live **Sync Status** row (syncing / pending count / failed count with
  Retry) that appears once signed in and synced on.
- Every local document change (scan, edit, rename, favorite, OCR
  result, delete) automatically queues and attempts a real upload to
  Firestore + Storage whenever the user is signed in and Cloud Sync is
  on — with zero effect on anyone who isn't (see section 8's "When it
  runs").
- The document library still **survives an app restart** exactly as in
  Phase 5; sync layers on top of that without changing local behavior.
- Friendly, non-crashing error states extend to sign-in/sign-up
  (wrong password, email in use, offline, etc. — see `AuthService`'s
  `_friendlyMessage`) and to sync failures (tracked per-document in the
  queue, never surfaced as a crash or a lost document).

### Installation commands

```bash
cd document_scanner
flutter pub get
flutter run
```

`android/` and `ios/` platform folders are not present (this project
was authored without a local Flutter SDK to scaffold and verify them).
Generate them once with:

```bash
flutter create . --platforms=android,ios --org com.scanova.app
```

**To enable Sign In and Cloud Sync**, you need a real Firebase project
(everything else in the app works without this):

1. Create a project at https://console.firebase.google.com.
2. Enable **Authentication** → Sign-in method → Google and Email/Password.
3. Enable **Firestore Database** and **Storage** (test mode is fine to
   start; tighten the security rules — scoped to `users/{uid}/**` per
   the paths in section 8 — before shipping).
4. From the project root: `dart pub global activate flutterfire_cli`,
   then `flutterfire configure` — pick the project you just created,
   the platforms you scaffolded above, and it overwrites
   `lib/firebase_options.dart` with real values (and drops
   `google-services.json`/`GoogleService-Info.plist` into
   `android/app/`/`ios/Runner/` for you).
5. For Android's Google Sign-In specifically, add your debug (and
   later release) SHA-1 fingerprint to the Firebase project's Android
   app settings, or Google sign-in will fail with a
   `DEVELOPER_ERROR`/`ApiException: 10` even with valid config —
   `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android`
   gets you the debug fingerprint.

Until those steps are done, `FirebaseBootstrap` catches the init
failure and the app runs normally in local-only mode — Sign In shows a
"Cloud sign-in is not set up yet" message instead of crashing.

This preserves the existing `lib/`, `pubspec.yaml`, and `test/` — it
only adds the native project shells. **After scaffolding**, add the
permissions Phase 2's camera/gallery features need (not yet present
since the native folders don't exist in this commit):

- **Android** (`android/app/src/main/AndroidManifest.xml`, inside
  `<manifest>`, before `<application>`):
  ```xml
  <uses-permission android:name="android.permission.CAMERA" />
  <uses-feature android:name="android.hardware.camera" android:required="false" />
  ```
  Also set `minSdkVersion` to at least 21 in
  `android/app/build.gradle` (the `camera` plugin requires it).
- **iOS** (`ios/Runner/Info.plist`, inside the top-level `<dict>`):
  ```xml
  <key>NSCameraUsageDescription</key>
  <string>Scanova needs camera access to scan documents.</string>
  <key>NSPhotoLibraryUsageDescription</key>
  <string>Scanova needs photo library access to import documents.</string>
  ```

### Testing instructions

```bash
flutter analyze        # static analysis
flutter test            # runs test/app_smoke_test.dart
flutter run             # manual walkthrough on a real device/emulator with a camera
```

Manual walkthrough checklist:
1. Home → tap **Scan Document** → grant camera permission → live
   preview appears, the corner frame turns green after ~1.4s, and
   (with Auto Capture on) it captures automatically; toggle Auto
   Capture off to use the shutter button instead.
2. Try flash cycling (off/auto/always) and the camera-switch button.
3. Try **gallery import** (multi-select works) as an alternative to the
   camera.
4. On Crop, drag a corner handle over the real captured image, tap
   **Apply** — the warp uses exactly those four points.
5. On Enhance, pick a filter and drag a slider — the preview updates
   with the real processed image after a short debounce (isolate
   processing, watch for the small spinner).
6. In Page Manager, **Add Page**, reorder by dragging, rotate, and try
   **Replace page** from the row's menu.
7. On PDF Create Options, name the document, pick a format/quality, tap
   **Create PDF** — watch the button show a spinner while `compute()`
   builds the file in the background.
8. On PDF Preview, confirm real page thumbnails, tap **Share** to
   confirm the native share sheet opens with the generated PDF, then
   **Save Document**.
9. From Documents (or Home's Recent Documents), open that document
   again and tap **Add page** — confirm it updates the same card
   instead of creating a second one.
10. On PDF Preview, tap **Extract Text** — confirm real recognized text
    appears (not placeholder copy) for a document with a real scanned
    page, and that switching the language chip re-runs recognition. Try
    **Copy**, **Share**, and **Save TXT**.
11. **Force-quit and relaunch the app** — confirm any document you
    created is still in Documents/Recent Documents (this is the real
    persistence test; Phase 1's mock demo docs reappear too until you've
    interacted with real ones).
12. Toggle Dark Mode in Settings and confirm every screen re-themes.
13. Toggle **Save Original Image** off in Settings, create another PDF,
    and confirm the original capture files are cleaned up afterward
    (the PDF itself is unaffected).
14. **With a real Firebase project configured** (see Installation
    commands): Settings → Sign In → Google or email/password. Confirm
    the Account row shows your name/email, then toggle **Cloud Sync**
    on and watch the new **Sync Status** row go "Syncing…" → "Up to
    date". Create a new document and confirm it starts syncing
    automatically. Check the Firebase console (Firestore + Storage) for
    the uploaded metadata/PDF.
15. Turn off WiFi/data, create or edit a document with Cloud Sync on —
    confirm the app doesn't hang or crash, and Sync Status shows a
    failed count with a **Retry** button; reconnect and tap Retry to
    confirm it clears.
16. Sign out — confirm Cloud Sync turns off and the Account row reverts
    to "Not signed in", while every local document stays exactly as it
    was (signing out never deletes local data).

Performance note: the 1/10/50/100-page load testing called out in the
spec has not been run here (no device/SDK available in this
environment) — `ImageProcessor`'s per-page pixel loops and the
isolate-based PDF assembly are designed for that scale, but should be
profiled on a real mid-range device before shipping.

### Known limitations
- **True document-edge detection is still simulated** — see section 5
  above. Everything downstream of a capture (crop, perspective
  correction, filters, PDF, OCR) is real.
- **PDF password protection is captured but not enforced** — see
  section 7 above for exactly why and what's needed to finish it.
- **Tamil and Kannada OCR fall back to the Latin recognizer** — ML Kit
  has no on-device model for either script; see section 6 above.
- **Cloud sync is outbound-only (local → cloud), and needs your own
  Firebase project** — see section 8 above for both the "why" and the
  setup steps. Nothing else in the app depends on it.
- **Apple Sign-In is not implemented** — needs Xcode entitlements this
  repo can't scaffold headlessly; see section 8.
- AI features (Phase 7) remain simulated; unchanged from the Phase 1
  delivery.
- Database migrations now have exactly one real example
  (`DocumentsDatabase` v1→v2, adding `updated_at`/`synced_at` and
  `sync_queue`) — the pattern exists, but it's only been exercised
  going from v1, not tested against a v2 database that already has
  real rows in it from actual use.
- Folders and favorites-as-a-first-class-entity aren't real yet —
  `ScannedDocument.folder` is a free-text field with no `folders` table
  behind it (per section 4), and there's no UI to assign one yet.
- `android/` and `ios/` platform folders are not included in this
  commit — see Installation commands above for the one-time scaffold
  step, the manifest/plist permissions, and the Firebase setup to add
  afterward.
- None of this has been run through `flutter analyze`/`flutter test`/a
  real device in this environment (no Flutter SDK installed here). The
  camera, image-processing, PDF, OCR, SQLite, auth, and sync code paths
  in particular need verification on a real device before shipping —
  review with those commands and the manual walkthrough above first.
  Package details that couldn't be verified without SDK/docs access and
  are worth double-checking first: the
  `TextRecognitionScript.devanagiri` enum spelling (`OcrService`), the
  `pw.MemoryImage.width`/`.height` getters (`PdfGenerator`), and the
  `google_sign_in: ^6.2.1` interactive `signIn()` API surface used in
  `AuthService` (a major-version redesign of that package's API exists
  upstream; pin/verify before upgrading).

### Next phase
**Phase 7 — AI features**: document summarization, "ask a question
about this document," smart classification, and structured extraction
(invoice/receipt fields, names/dates/amounts) — most naturally layered
on top of the real OCR text `OcrService` already produces, calling out
to an LLM API behind a `Premium`-gated interface per the monetization
plan. Natural-language document search over the (still local-only)
library rounds it out.
