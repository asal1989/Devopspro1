import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_strings.dart';
import 'core/router/app_router.dart';
import 'core/services/firebase_bootstrap.dart';
import 'core/services/sync_coordinator.dart';
import 'core/theme/app_theme.dart';
import 'features/authentication/presentation/providers/auth_provider.dart';
import 'features/documents/presentation/providers/documents_provider.dart';
import 'features/documents/presentation/providers/sync_status_provider.dart';
import 'features/scanner/presentation/providers/scan_session_provider.dart';
import 'features/settings/presentation/providers/settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseBootstrap.initialize();
  runApp(const DocumentScannerApp());
}

class DocumentScannerApp extends StatelessWidget {
  const DocumentScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DocumentsProvider()),
        ChangeNotifierProvider(create: (_) => ScanSessionProvider()),
        ChangeNotifierProvider(create: (_) => SyncStatusProvider()),
      ],
      child: const _SyncWiring(child: _AppShell()),
    );
  }
}

/// Constructs [SyncCoordinator] once all the providers it wires
/// together exist, and exposes it back down the tree so Settings can
/// trigger a manual retry.
class _SyncWiring extends StatefulWidget {
  final Widget child;
  const _SyncWiring({required this.child});

  @override
  State<_SyncWiring> createState() => _SyncWiringState();
}

class _SyncWiringState extends State<_SyncWiring> {
  late final SyncCoordinator _coordinator;

  @override
  void initState() {
    super.initState();
    _coordinator = SyncCoordinator(
      auth: context.read<AuthProvider>(),
      settings: context.read<SettingsProvider>(),
      documents: context.read<DocumentsProvider>(),
      status: context.read<SyncStatusProvider>(),
    );
  }

  @override
  void dispose() {
    _coordinator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Provider<SyncCoordinator>.value(value: _coordinator, child: widget.child);
  }
}

class _AppShell extends StatelessWidget {
  const _AppShell();

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        return MaterialApp.router(
          title: AppStrings.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: settings.themeMode,
          routerConfig: appRouter,
        );
      },
    );
  }
}
