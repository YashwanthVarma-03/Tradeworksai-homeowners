import 'package:flutter/material.dart';
import '../theme.dart';

void dismissAppKeyboard() => FocusManager.instance.primaryFocus?.unfocus();

class KeyboardNavigationObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      dismissAppKeyboard();
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      dismissAppKeyboard();
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      dismissAppKeyboard();
}

/// One keyboard policy for every route, including third-party chat fields.
class AppKeyboard extends StatelessWidget {
  const AppKeyboard({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: FocusManager.instance,
        builder: (context, _) {
          final media = MediaQuery.of(context);
          final focusContext = FocusManager.instance.primaryFocus?.context;
          final editable = focusContext?.widget is EditableText
              ? focusContext!.widget as EditableText
              : focusContext?.findAncestorWidgetOfExactType<EditableText>();
          final type = editable?.keyboardType;
          final numeric = type?.index == TextInputType.number.index ||
              type == TextInputType.phone;
          final showDone = media.viewInsets.bottom > 0 && numeric;
          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: dismissAppKeyboard,
            child: NotificationListener<ScrollStartNotification>(
              onNotification: (notification) {
                if (notification.dragDetails != null) dismissAppKeyboard();
                return false;
              },
              child: Stack(children: [
                Positioned.fill(
                    child: MediaQuery(
                  data: showDone
                      ? media.copyWith(
                          viewInsets: media.viewInsets
                              .copyWith(bottom: media.viewInsets.bottom + 44))
                      : media,
                  child: child,
                )),
                if (showDone)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: media.viewInsets.bottom,
                    child: Material(
                      color: AppTheme.white,
                      child: Container(
                        height: 44,
                        decoration: const BoxDecoration(
                            border: Border(
                                top: BorderSide(color: AppTheme.border))),
                        alignment: Alignment.centerRight,
                        child: TextButton(
                            onPressed: dismissAppKeyboard,
                            child: const Text('Done',
                                style: TextStyle(color: AppTheme.blue))),
                      ),
                    ),
                  ),
              ]),
            ),
          );
        },
      );
}
