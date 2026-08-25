# Scanova — AI Document Scanner (Flutter)

A production-quality document scanning app in the spirit of Adobe Scan /
Microsoft Lens / CamScanner, with an original UI. Built with Flutter using
clean architecture so native scanning, OCR, and PDF pipelines can be
dropped in without restructuring the app.

This repository currently contains **Phase 1 — UI Prototype**: every
screen in the primary flow, wired together with realistic mock data and
in-memory state, so the whole app is navigable end to end before any
camera/OpenCV/OCR/PDF plugin is integrated.

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

**Why this shape scales:** the Scanner, OCR, and PDF features are already
separated by responsibility. When Phase 2 adds the `camera` plugin, only
`features/scanner/data` and the camera screen's internals change — the
crop/enhance/page-manager screens keep consuming the same
`ScanSessionProvider` API. Same for OCR (ML Kit) and PDF (`pdf`/`printing`
packages) in later phases.

## 2. Required packages

**In this phase (`pubspec.yaml`):**
| Package | Purpose |
|---|---|
| `go_router` | Declarative navigation |
| `provider` | State management |
| `google_fonts` | Typography (Inter) |
| `intl` | Date formatting |
| `uuid` | Local IDs for scan pages |

**Planned for later phases** (not added yet, so the app stays buildable
today — add each when its phase starts):
| Phase | Package(s) | Purpose |
|---|---|---|
| 2 — Camera | `camera`, `image_picker` | Live preview, capture, gallery import |
| 3 — Image processing | `opencv_dart` (or platform channel to OpenCV), `image` | Edge detection, perspective correction, filters |
| 4 — PDF | `pdf`, `printing`, `path_provider` | PDF generation, compression, preview |
| 5 — OCR | `google_mlkit_text_recognition` | On-device OCR (English, Hindi, Tamil, Kannada via script-specific recognizers) |
| 5 — Local storage | `sqflite`, `path_provider` | Offline document/OCR metadata store |
| 6 — Cloud | `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_storage` (or Supabase equivalents) | Auth, sync, cloud storage |
| 6 — Sharing | `share_plus` | Native share sheet |
| Security | `flutter_secure_storage` | Sensitive metadata at rest |

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
      domain/entities/            ScanPage, PageFilter
      presentation/providers/     ScanSessionProvider (in-progress scan state)
      presentation/screens/       Camera, Crop, Enhancement, Page Manager
      presentation/widgets/       DetectionFramePainter
    documents/
      domain/entities/            ScannedDocument, DocumentCategory
      data/                       MockDocumentsRepository
      presentation/providers/     DocumentsProvider (library state)
      presentation/screens/       Documents library (grid/list/search/sort)
      presentation/widgets/       DocumentGridItem
    pdf/
      domain/entities/            PdfOptions
      presentation/screens/       PdfCreateOptionsScreen, PdfPreviewScreen
    ocr/
      domain/entities/            OcrLanguage
      presentation/screens/       OcrResultScreen
    settings/
      presentation/providers/     SettingsProvider
      presentation/screens/       SettingsScreen
    authentication/
      presentation/screens/       SignInScreen (optional)

  shared/widgets/                 PrimaryButton, SectionHeader, AppShell (bottom nav)
  main.dart                       Provider wiring + MaterialApp.router
```

## 4. Database structure (target — Phase 5)

Local storage moves from in-memory `DocumentsProvider` to `sqflite`
behind the same repository interface:

```
documents
  id TEXT PRIMARY KEY
  name TEXT
  created_at INTEGER
  updated_at INTEGER
  folder_id TEXT NULL
  is_favorite INTEGER
  size_kb INTEGER
  category TEXT
  extracted_text TEXT NULL
  pdf_path TEXT
  synced_at INTEGER NULL        -- null until cloud-synced

pages
  id TEXT PRIMARY KEY
  document_id TEXT REFERENCES documents(id) ON DELETE CASCADE
  position INTEGER
  original_image_path TEXT
  processed_image_path TEXT
  rotation_degrees INTEGER
  filter TEXT
  brightness REAL
  contrast REAL
  sharpness REAL

folders
  id TEXT PRIMARY KEY
  name TEXT
  created_at INTEGER

sync_queue                       -- offline-first upload queue (Phase 6)
  id TEXT PRIMARY KEY
  document_id TEXT
  status TEXT                    -- pending | uploading | failed
  retry_count INTEGER
  last_error TEXT NULL
```

`ScannedDocument.pages` keeps `originalAssetColor` only as a Phase 1
stand-in for `original_image_path` / `processed_image_path` — no real
image ever needs to be destroyed to add real files later.

## 5. Scanner implementation strategy (Phase 2–3)

1. Replace the simulated preview in `ScannerCameraScreen` with the
   `camera` plugin's `CameraController` + `CameraPreview`.
2. Run a lightweight edge-detection pass on each preview frame
   (downscaled) via OpenCV (contour detection + `approxPolyDP` to find
   the largest 4-point polygon), throttled to a few times per second to
   protect frame rate.
3. Feed the detected quadrilateral into the same `DetectionFramePainter`
   overlay already built — only the data source changes, not the widget.
4. On stable detection (confidence above threshold across N consecutive
   frames), trigger auto-capture; otherwise keep showing
   "Position the document inside the frame" / "Move closer".
5. On capture, run perspective-correction (`getPerspectiveTransform` +
   `warpPerspective`) in an isolate to keep the UI thread free, then hand
   the corrected image to the existing `CropScreen` for manual
   adjustment — `CropScreen`'s corner-handle model already matches this
   data shape (4 normalized points).
6. Filters (`Enhancement` screen) become real image ops (grayscale,
   adaptive threshold for B&W, unsharp mask for sharpness) run on a
   background isolate with a debounced live preview.

## 6. OCR implementation strategy (Phase 5)

- Use `google_mlkit_text_recognition` for on-device OCR — works fully
  offline, satisfying the "no internet required" requirement.
- English, Hindi, and other Latin/Devanagari-adjacent scripts use the
  default Latin recognizer; Tamil and Kannada need ML Kit's
  script-specific recognizer options where supported, or a fallback
  cloud OCR call (e.g. Google Cloud Vision) gated behind "Premium" for
  scripts the on-device model doesn't cover well — this is why
  `OcrLanguage` is already modeled as an explicit enum rather than a
  free-text field.
- OCR runs in a background isolate per page; results are cached on the
  `ScannedDocument.extractedText` field (already present) so re-opening
  a document doesn't re-run recognition.
- Failures never crash the app: wrap recognition in
  `core/errors/app_exception.dart`'s `OcrException` and show
  `AppStrings.ocrFailure` ("We couldn't recognize the text. Try a
  clearer scan.").

## 7. PDF implementation strategy (Phase 4)

- Use the `pdf` package to compose pages (one image per page, sized to
  the chosen `PdfPageFormat`) and `printing` for the native share/print
  sheet and an in-app preview (`PdfPreview` widget) that replaces the
  current mock preview in `PdfPreviewScreen`.
- Generation runs in an isolate (`compute`) for documents with many
  pages so the UI never freezes — this matters at the 50–100 page scale
  the spec calls out for testing.
- Compression re-encodes page images at a quality tied to `PdfQuality`
  (`PdfCreateOptionsScreen` already models `high/medium/low`) before
  embedding them.
- Password protection uses the `pdf` package's encryption support,
  applied only when `PdfOptions.passwordProtected` is set.
- Every generated PDF is written to a temp path first, then moved into
  permanent storage only on success, and temp files are deleted
  afterward (see `core/errors` — failures raise `PdfGenerationException`
  and the temp file is cleaned up either way).

---

## Phase 1 — UI Prototype (this delivery)

### Files created
Everything under `lib/`, `test/app_smoke_test.dart`, `pubspec.yaml`,
`analysis_options.yaml`, `.gitignore`, this `README.md`. See the folder
structure above for the full list — there is no `main.dart` logic
outside provider wiring, and no screen exceeds ~250 lines.

### What's implemented
- Full navigation flow: Home → Scan → Camera (simulated detection) →
  Crop (draggable corners) → Enhance (filters + brightness/contrast/
  sharpness) → Page Manager (reorder/rotate/delete/replace) → PDF
  Create Options → PDF Preview → OCR result screen.
- Home dashboard, Documents library (grid/list, search, sort, favorites
  filter), Settings (scanner defaults, appearance incl. working dark
  mode, storage, account with optional sign-in, about).
- Error copy from the spec (`core/constants/app_strings.dart`) ready to
  wire to real camera/OCR/storage failures.
- Realistic mock data (`MockDocumentsRepository`) so every screen has
  something to show immediately.

### Installation commands

```bash
cd document_scanner
flutter pub get
flutter run
```

If `android/` and `ios/` platform folders are not present (this
prototype was authored without a local Flutter SDK to scaffold them),
generate them once with:

```bash
flutter create . --platforms=android,ios --org com.scanova.app
```

This preserves the existing `lib/`, `pubspec.yaml`, and `test/` — it
only adds the native project shells.

### Testing instructions

```bash
flutter analyze        # static analysis
flutter test            # runs test/app_smoke_test.dart
flutter run             # manual walkthrough of the flow described above
```

Manual walkthrough checklist:
1. Home → tap **Scan Document** → camera screen shows the detection
   frame turn green and auto-navigates to Crop.
2. Drag a corner handle on the Crop screen, tap **Apply**.
3. Pick a filter and adjust a slider on Enhance, tap **Add More Pages**.
4. In Page Manager, tap **Add Page** to capture another, then drag to
   reorder, rotate, or delete a page, then **Done**.
5. Set a document name on PDF Create Options, tap **Create PDF**.
6. On PDF Preview, tap **Extract Text** to see the OCR screen, then
   **Save Document** to return home and see the new card in Recent
   Documents.
7. Toggle Dark Mode in Settings and confirm every screen re-themes.

### Known limitations (by design — later phases)
- Camera, edge detection, perspective correction, real OCR, and real
  PDF generation are all simulated with mock data/timers — see sections
  5–7 above for the concrete plan to replace each.
- No persistence: closing the app loses documents (`DocumentsProvider`
  is in-memory). SQLite lands in the phase that adds real image files.
- No cloud auth/sync backend is wired up; `SignInScreen` and
  `SettingsProvider.cloudSyncEnabled` are UI-complete but not connected
  to Firebase/Supabase yet.
- Share/Copy/Save-as-TXT on the OCR screen show confirmation snackbars
  instead of invoking a real share sheet — `share_plus` isn't added
  until sharing is implemented for real (Phase 6 table above).
- `android/` and `ios/` platform folders are not included in this
  commit (see Installation commands above to generate them) since they
  were authored without a local Flutter SDK available to scaffold and
  verify them.
- This code has not been run through `flutter analyze`/`flutter test`
  in this environment (no Flutter SDK installed here); review with
  those commands before shipping.

### Next phase
**Phase 2 — Camera**: integrate the `camera` plugin, replace the
simulated preview and detection loop in `ScannerCameraScreen`, and wire
real image capture into `ScanSessionProvider`.
