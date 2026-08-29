import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/ai/presentation/screens/ask_question_screen.dart';
import '../../features/ai/presentation/screens/document_summary_screen.dart';
import '../../features/ai/presentation/screens/extraction_screen.dart';
import '../../features/authentication/presentation/screens/sign_in_screen.dart';
import '../../features/documents/domain/entities/document.dart';
import '../../features/ocr/presentation/screens/ocr_result_screen.dart';
import '../../features/pdf/presentation/screens/pdf_create_options_screen.dart';
import '../../features/pdf/presentation/screens/pdf_preview_screen.dart';
import '../../features/scanner/presentation/screens/crop_screen.dart';
import '../../features/scanner/presentation/screens/enhancement_screen.dart';
import '../../features/scanner/presentation/screens/page_manager_screen.dart';
import '../../features/scanner/presentation/screens/scanner_camera_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../shared/widgets/app_shell.dart';

/// Route path constants so screens never hard-code string literals.
class AppRoutes {
  AppRoutes._();

  static const home = '/';
  static const settings = '/settings';
  static const scan = '/scan';
  static const crop = '/scan/crop';
  static const enhance = '/scan/enhance';
  static const pages = '/scan/pages';
  static const pdfOptions = '/scan/pdf-options';
  static const pdfPreview = '/scan/pdf-preview';
  static const ocr = '/ocr';
  static const signIn = '/sign-in';
  static const aiSummary = '/ai/summary';
  static const aiAsk = '/ai/ask';
  static const aiExtract = '/ai/extract';
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.home,
  routes: [
    GoRoute(
      path: AppRoutes.home,
      builder: (context, state) => const AppShell(),
    ),
    GoRoute(
      path: AppRoutes.settings,
      builder: (context, state) => const Scaffold(body: SafeArea(child: SettingsScreen())),
    ),
    GoRoute(
      path: AppRoutes.scan,
      builder: (context, state) => const ScannerCameraScreen(),
    ),
    GoRoute(
      path: AppRoutes.crop,
      builder: (context, state) => const CropScreen(),
    ),
    GoRoute(
      path: AppRoutes.enhance,
      builder: (context, state) => const EnhancementScreen(),
    ),
    GoRoute(
      path: AppRoutes.pages,
      builder: (context, state) => const PageManagerScreen(),
    ),
    GoRoute(
      path: AppRoutes.pdfOptions,
      builder: (context, state) => const PdfCreateOptionsScreen(),
    ),
    GoRoute(
      path: AppRoutes.pdfPreview,
      builder: (context, state) {
        final document = state.extra as ScannedDocument?;
        return PdfPreviewScreen(document: document);
      },
    ),
    GoRoute(
      path: AppRoutes.ocr,
      builder: (context, state) {
        final document = state.extra as ScannedDocument?;
        return OcrResultScreen(document: document);
      },
    ),
    GoRoute(
      path: AppRoutes.signIn,
      builder: (context, state) => const SignInScreen(),
    ),
    GoRoute(
      path: AppRoutes.aiSummary,
      builder: (context, state) => DocumentSummaryScreen(document: state.extra as ScannedDocument),
    ),
    GoRoute(
      path: AppRoutes.aiAsk,
      builder: (context, state) => AskQuestionScreen(document: state.extra as ScannedDocument),
    ),
    GoRoute(
      path: AppRoutes.aiExtract,
      builder: (context, state) => ExtractionScreen(document: state.extra as ScannedDocument),
    ),
  ],
);
