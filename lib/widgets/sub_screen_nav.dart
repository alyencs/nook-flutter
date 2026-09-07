import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../screens/add/add_method_screen.dart';
import 'nook_bottom_nav.dart';

/// The tab bar as it appears on a pushed sub-screen.
///
/// P2-P6 are all drawn with the tab bar, so tapping a tab from one of them has
/// to return to the shell and select that tab rather than doing nothing. The
/// selected tab lives in [AppScope], so this sets it and pops back.
class SubScreenNav extends StatelessWidget {
  const SubScreenNav({super.key, this.currentIndex = NookTabs.profile});

  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return NookBottomNav(
      currentIndex: currentIndex,
      onSelect: (index) {
        if (index == NookTabs.add) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddMethodScreen()),
          );
          return;
        }
        AppScope.of(context).tab.value = index;
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
    );
  }
}
