import 'package:flutter/material.dart';

import '../theme.dart';

/// Shared tab intent used when a nested flow needs to return to the app shell.
class AppTabNavigation {
  AppTabNavigation._();

  static final ValueNotifier<int?> requestedTab = ValueNotifier<int?>(null);

  static void request(int index) {
    requestedTab.value = index;
  }
}

/// The one bottom navigation treatment used across homeowner surfaces.
class MainBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const MainBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: AppTheme.orange500,
        unselectedItemColor: AppTheme.gray,
        selectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home, size: 25),
            activeIcon: Icon(Icons.home, size: 25),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search, size: 25),
            activeIcon: Icon(Icons.search, size: 25),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month, size: 25),
            activeIcon: Icon(Icons.calendar_month, size: 25),
            label: 'Bookings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.redeem, size: 25),
            activeIcon: Icon(Icons.redeem, size: 25),
            label: 'Rewards',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person, size: 25),
            activeIcon: Icon(Icons.person, size: 25),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
