import 'package:flutter/material.dart';

class AdminCenteredLayout extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final Color? backgroundColor;

  const AdminCenteredLayout({
    super.key,
    required this.child,
    this.maxWidth = 800.0,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor,
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
