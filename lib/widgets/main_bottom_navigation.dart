import 'package:flutter/material.dart';

import '../theme.dart';
import '../ui/tw.dart';
import '../services/homeowner_service.dart';
import '../services/stream_service.dart';
import 'app_keyboard.dart';

class AppTabNavigation {
  AppTabNavigation._();

  static final ValueNotifier<int?> requestedTab = ValueNotifier<int?>(null);

  static void request(int index) => requestedTab.value = index;
}

/// v3.3 §4 bottom tab bar: a floating white pill, 64 high, radius 32,
/// 12 in from each side and 12 above the bottom inset, `floatShadow`, no
/// border. Five equal items; the selected one sits in a 52-high blue-tint
/// pill with a filled blue icon and blue label. Centred, max 560, on Wide.
class MainBottomNavigation extends StatelessWidget {
  const MainBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const double height = 64;

  static const _items = <(IconData, IconData, String)>[
    (Icons.home_outlined, Icons.home_rounded, 'Home'),
    (Icons.grid_view_outlined, Icons.grid_view_rounded, 'Browse'),
    (Icons.calendar_today_outlined, Icons.calendar_today_rounded, 'Bookings'),
    (Icons.mail_outline_rounded, Icons.mail_rounded, 'Inbox'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + bottomInset),
      child: Align(
        alignment: Alignment.bottomCenter,
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: TwLayout.maxContent),
          child: Container(
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: AppTheme.white,
              borderRadius: BorderRadius.circular(height / 2),
              boxShadow: AppTheme.floatShadow,
            ),
            child: Row(
              children: [
                for (var index = 0; index < _items.length; index++)
                  Expanded(
                    child: _NavigationItem(
                      icon: _items[index].$1,
                      selectedIcon: _items[index].$2,
                      label: _items[index].$3,
                      selected: index == currentIndex,
                      onTap: () {
                        dismissAppKeyboard();
                        onTap(index);
                      },
                      inbox: index == 3,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.inbox = false,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool inbox;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        child: Center(
          child: SizedBox(
            height: 52,
            width: double.infinity,
            child: Material(
              color: selected ? AppTheme.blueTint : Colors.transparent,
              borderRadius: BorderRadius.circular(26),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (inbox)
                        InboxUnreadIcon(selected: selected)
                      else
                        Icon(selected ? selectedIcon : icon,
                            size: 22,
                            color: selected ? AppTheme.blue : AppTheme.body),
                      const SizedBox(height: 2),
                      // The label shrinks rather than clipping at 1.3× text.
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          label,
                          maxLines: 1,
                          style: TwType.tab(selected: selected),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class InboxUnreadIcon extends StatelessWidget {
  const InboxUnreadIcon({super.key, this.selected = false});
  final bool selected;
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
        listenable: StreamService.instance,
        builder: (context, _) {
          final chat = StreamService.instance.client?.state;
          return StreamBuilder<int>(
            stream: chat?.totalUnreadCountStream,
            initialData: chat?.totalUnreadCount ?? 0,
            builder: (context, snapshot) => ValueListenableBuilder<int>(
              valueListenable:
                  HomeownerService.instance.notificationUnreadCount,
              builder: (context, activity, _) {
                final count = (snapshot.data ?? 0) + activity;
                return Semantics(
                    label: '$count unread',
                    child: Stack(clipBehavior: Clip.none, children: [
                      Icon(
                          selected
                              ? Icons.mail_rounded
                              : Icons.mail_outline_rounded,
                          size: 22,
                          color: selected ? AppTheme.blue : AppTheme.body),
                      if (count > 0)
                        Positioned(
                            top: -8,
                            right: -12,
                            child: Container(
                              constraints: const BoxConstraints(
                                  minWidth: 20, minHeight: 20),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                  color: AppTheme.blue,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: Colors.white, width: 2)),
                              child: Text(count > 99 ? '99+' : '$count',
                                  style: TwType.caption(color: Colors.white)
                                      .copyWith(fontSize: 10),
                                  textAlign: TextAlign.center),
                            )),
                    ]));
              },
            ),
          );
        });
  }
}
