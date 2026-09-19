import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../widgets/nook_bottom_nav.dart';
import 'add/add_method_screen.dart';
import 'home/home_screen.dart';
import 'profile/profile_screen.dart';
import 'trips/trips_screen.dart';

/// The four tabs. Add is an action rather than a tab: it opens the save flow
/// and returns you to whichever tab you were on, which is how the mockup's
/// flow reads.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  bool _homeSearching = false;

  ValueNotifier<int> get _tabs => AppScope.of(context).tab;
  int get _tab => _tabs.value;

  void _onSelect(int index) {
    if (index == NookTabs.add) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AddMethodScreen()),
      );
      return;
    }
    setState(() {
      // Tapping Home leaves search, which is how you get back out of it: the
      // search frames are drawn with the tab bar and no back button.
      if (index == NookTabs.home && _tab == NookTabs.home) {
        _homeSearching = false;
      }
      _tabs.value = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _tabs,
      builder: (context, tab, _) => IndexedStack(
        index: switch (tab) { NookTabs.home => 0, NookTabs.trips => 1, _ => 2 },
        children: [
          HomeScreen(
            nav: _nav,
            searching: _homeSearching,
            onStartSearch: () => setState(() => _homeSearching = true),
          ),
          TripsScreen(nav: _nav),
          ProfileScreen(nav: _nav),
        ],
      ),
    );
  }

  Widget get _nav => NookBottomNav(currentIndex: _tab, onSelect: _onSelect);
}
