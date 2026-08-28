# Scanova — AI Document Scanner (Flutter)

A production-quality document scanning app in the spirit of Adobe Scan /
Microsoft Lens / CamScanner, with an original UI. Built with Flutter using
clean architecture so native scanning, OCR, and PDF pipelines can be
dropped in without restructuring the app.

This repository currently contains **Phases 1–5**: the full UI flow
(Phase 1), a real device camera with gallery import (Phase 2), real
pixel-level image processing — perspective correction, rotation, and
filters (Phase 3), real multi-page PDF generation, storage, and sharing
(Phase 4), and real on-device OCR with SQLite-backed persistence
(Phase 5). Cloud sync and AI features (Phases 6–7) are still
UI-complete but simulated — see the phase sections below for exactly
what's real versus mocked in each area.

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

**Planned for later phases** (not added yet, so the app stays buildable
today — add each when its phase starts):
| Phase | Package(s) | Purpose |
|---|---|---|
| 6 — Cloud | `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_storage` (or Supabase equivalents) | Auth, sync, cloud storage |
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
    utils/         (reserved for Phase 2+ formatters/helpers)

  features/
    home/presentation/            Dashboard: CTA, quick actions, recent docs
    scanner/
      domain/entities/            ScanPage (real imagePath + cropCorners), PageFilter
      data/                       ImageProcessor (perspective warp, filters, adjust — real, pure Dart)
      presentation/providers/     ScanSessionProvider (in-progress scan state; supports re-opening a saved document for editing)
      presentation/screens/       Camera (real `camera` plugin), Crop, Enhancement (real live-processed preview), Page Manager
      presentation/widgets/       DetectionFramePainter
    documents/
      domain/entities/            ScannedDocument (+ pdfPath), DocumentCategory
      data/                       MockDocumentsRepository (demo seed), database/DocumentsDatabase (real sqflite persistence)
      presentation/providers/     DocumentsProvider (library state, persists every mutation)
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

folders                          -- target, Phase 6
  id TEXT PRIMARY KEY
  name TEXT
  created_at INTEGER

sync_queue                       -- target, Phase 6 (offline-first upload queue)
  id TEXT PRIMARY KEY
  document_id TEXT
  status TEXT                    -- pending | uploading | failed
  retry_count INTEGER
  last_error TEXT NULL
```

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

---

## Phases 1–5 (this delivery)

### Files created/modified since Phase 1
New: `lib/features/scanner/data/image_processor.dart`,
`lib/features/pdf/data/pdf_generator.dart`,
`lib/features/ocr/data/ocr_service.dart`,
`lib/features/documents/data/database/documents_database.dart`,
`lib/shared/widgets/page_thumbnail.dart`. Modified: `ScannerCameraScreen`,
`CropScreen`, `EnhancementScreen`, `PageManagerScreen`,
`PdfCreateOptionsScreen`, `PdfPreviewScreen`, `OcrResultScreen`,
`ScanSessionProvider`, `DocumentsProvider`, `ScanPage`,
`ScannedDocument`, `pubspec.yaml`. See the folder structure and
sections 5–7 above for what each does.

### What's implemented
- Full navigation flow: Home → Scan → **real Camera** (live preview,
  flash, camera switch, gallery import, manual + timer-approximated
  auto capture) → Crop (draggable corners over the **real captured
  image**) → Enhance (**real, live-processed** filters + brightness/
  contrast/sharpness) → Page Manager (reorder/rotate/delete/replace,
  now with real thumbnails) → PDF Create Options → **real PDF
  generation** → PDF Preview (real thumbnails, real Share) → **real
  on-device OCR** (extract, edit, copy, share, save as .txt).
- Re-opening a saved document from PDF Preview ("Add page" / "Edit
  pages" / "Reorder") correctly updates that same document rather than
  creating a duplicate.
- The document library now **survives an app restart**: every add/
  rename/favorite/delete/duplicate/OCR-result goes through
  `DocumentsProvider` into `sqflite`, not just an in-memory list.
- Home dashboard, Documents library (grid/list, search, sort, favorites
  filter), Settings (scanner defaults, appearance incl. working dark
  mode, storage, account with optional sign-in, about).
- Friendly, non-crashing error states for camera permission denial,
  camera init failure, gallery import failure, PDF generation failure,
  and OCR recognition failure (`core/constants/app_strings.dart` copy
  from the spec).

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
- Cloud auth/sync and AI features (Phases 6–7) remain simulated;
  unchanged from the Phase 1 delivery. `SignInScreen` and
  `SettingsProvider.cloudSyncEnabled` are UI-complete but not connected
  to a backend.
- No database migrations exist yet — the schema in section 4 is
  version 1 with no upgrade path. Fine while the app is pre-release;
  add an `onUpgrade` callback in `DocumentsDatabase` before shipping a
  schema change.
- Folders and favorites-as-a-first-class-entity aren't real yet —
  `ScannedDocument.folder` is a free-text field with no `folders` table
  behind it (per section 4), and there's no UI to assign one yet.
- `android/` and `ios/` platform folders are not included in this
  commit — see Installation commands above for the one-time scaffold
  step and the manifest/plist permissions to add afterward.
- None of this has been run through `flutter analyze`/`flutter test`/a
  real device in this environment (no Flutter SDK installed here). The
  camera, image-processing, PDF, OCR, and SQLite code paths in
  particular need verification on a real device before shipping —
  review with those commands and the manual walkthrough above first.
  Two specific package details couldn't be verified without SDK/docs
  access and are worth double-checking first: the
  `TextRecognitionScript.devanagiri` enum spelling (`OcrService`) and
  the `pw.MemoryImage.width`/`.height` getters (`PdfGenerator`).

### Next phase
**Phase 6 — Cloud**: wire `SignInScreen` to real Google/Apple/email
auth (Firebase Auth or Supabase), and give `DocumentsProvider` a sync
layer — upload queue, retry, and conflict resolution — that activates
only once a user is signed in, keeping local-first behavior unchanged
for everyone else.
