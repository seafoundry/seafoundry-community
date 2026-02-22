// @tier: community
import 'package:flutter/material.dart';
import '../../components/dialog_scroll_view.dart';

class OrganismCreationStepScrollView extends StatelessWidget {
  const OrganismCreationStepScrollView({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    // Dialogs remove viewInsets; use the window insets so keyboard padding works.
    final viewInsets = views.isNotEmpty
        ? MediaQueryData.fromView(views.first).viewInsets
        : MediaQuery.of(context).viewInsets;

    return DialogScrollView(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + viewInsets.bottom),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: child,
    );
  }
}
