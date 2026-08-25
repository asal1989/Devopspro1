import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../features/documents/presentation/screens/documents_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';

/// Hosts the bottom navigation tabs (Home, Documents, Scan, Settings).
/// The Scan tab is an action, not a persisted page: it pushes the
/// full-screen scanner flow instead of switching the tab body.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tabIndex = 0;

  static const _tabs = [HomeScreen(), DocumentsScreen(), SettingsScreen()];

  void _onNavTap(int index) {
    if (index == 2) {
      context.push(AppRoutes.scan);
      return;
    }
    setState(() => _tabIndex = index == 3 ? 2 : index);
  }

  @override
  Widget build(BuildContext context) {
    final border = Theme.of(context).extension<AppSemanticColors>()?.border;
    return Scaffold(
      body: IndexedStack(index: _tabIndex, children: _tabs),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _ScanFab(onTap: () => context.push(AppRoutes.scan)),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: border ?? Colors.transparent))),
        child: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          notchMargin: 8,
          padding: EdgeInsets.zero,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                _NavItem(icon: Icons.home_rounded, label: 'Home', selected: _tabIndex == 0, onTap: () => _onNavTap(0)),
                _NavItem(icon: Icons.description_rounded, label: 'Documents', selected: _tabIndex == 1, onTap: () => _onNavTap(1)),
                const Spacer(),
                _NavItem(icon: Icons.settings_rounded, label: 'Settings', selected: _tabIndex == 2, onTap: () => _onNavTap(3)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScanFab extends StatelessWidget {
  final VoidCallback onTap;
  const _ScanFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return FloatingActionButton(
      onPressed: onTap,
      backgroundColor: accent,
      shape: const CircleBorder(),
      elevation: 2,
      child: const Icon(Icons.document_scanner_rounded, color: Colors.white),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected ? theme.colorScheme.primary : theme.extension<AppSemanticColors>()?.textSecondary;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
