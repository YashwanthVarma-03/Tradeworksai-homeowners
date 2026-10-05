import 'package:flutter/material.dart';

import '../theme.dart';

class AppTabNavigation {
  AppTabNavigation._();

  static final ValueNotifier<int?> requestedTab = ValueNotifier<int?>(null);

  static void request(int index) => requestedTab.value = index;
}

class MainBottomNavigation extends StatelessWidget {
  const MainBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _items = <(IconData, String)>[
    (Icons.home_outlined, 'Home'),
    (Icons.search, 'Search'),
    (Icons.calendar_today_outlined, 'Bookings'),
    (Icons.card_giftcard_outlined, 'Rewards'),
    (Icons.person_outline, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) => SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Container(
          height: 84,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(34),
            border: Border.all(color: AppTheme.cardBorder),
            boxShadow: AppTheme.floatShadow,
          ),
          child: Row(
            children: [
              for (var index = 0; index < _items.length; index++)
                Expanded(
                  child: _NavigationItem(
                    icon: _items[index].$1,
                    label: _items[index].$2,
                    selected: index == currentIndex,
                    onTap: () => onTap(index),
                  ),
                ),
            ],
          ),
        ),
      );
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            decoration: BoxDecoration(
              color: selected ? AppTheme.blueTint : Colors.transparent,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 25,
                  color: selected ? AppTheme.blue : AppTheme.body,
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      color: selected ? AppTheme.blue : AppTheme.body,
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
