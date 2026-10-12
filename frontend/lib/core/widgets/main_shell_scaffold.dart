import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'bottom_nav_bar.dart';

/// Wraps the 4 persistent bottom tabs (Home, History, Progress, Profile)
/// in a single persistent Scaffold with IndexedStack navigation so that
/// switching screens does NOT reload or destroy the page state.
class MainShellScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainShellScaffold({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: BottomNavBar(
        currentIndex: _branchToVisual(navigationShell.currentIndex),
        onTap: (index) {
          if (index == 2) {
            // Center mic slot triggers interview practice
            context.push('/interview');
            return;
          }
          final branchIndex = _visualToBranch(index);
          navigationShell.goBranch(
            branchIndex,
            initialLocation: branchIndex == navigationShell.currentIndex,
          );
        },
        onMicTap: () => context.push('/interview'),
      ),
    );
  }

  /// Maps branch index (0..3) to BottomNavBar visual index (0, 1, 3, 4 with 2 being center Mic).
  static int _branchToVisual(int branchIndex) {
    switch (branchIndex) {
      case 0:
        return 0; // Home
      case 1:
        return 1; // History
      case 2:
        return 3; // Progress
      case 3:
        return 4; // Profile
      default:
        return 0;
    }
  }

  /// Maps BottomNavBar visual index back to branch index.
  static int _visualToBranch(int visualIndex) {
    switch (visualIndex) {
      case 0:
        return 0; // Home
      case 1:
        return 1; // History
      case 3:
        return 2; // Progress
      case 4:
        return 3; // Profile
      default:
        return 0;
    }
  }
}
