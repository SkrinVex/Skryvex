import 'package:flutter/material.dart';

/// Ширина, при которой включается десктопный layout
const kDesktopBreakpoint = 600.0;

bool isDesktop(BuildContext context) =>
    MediaQuery.of(context).size.width >= kDesktopBreakpoint;

/// Оборачивает контент формы в центрированную карточку на десктопе
Widget adaptiveFormBody({
  required BuildContext context,
  required Widget child,
  double maxWidth = 480,
}) {
  if (!isDesktop(context)) return child;
  return Center(
    child: SingleChildScrollView(
      child: Container(
        width: maxWidth,
        margin: const EdgeInsets.symmetric(vertical: 40),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(20),
        ),
        child: child,
      ),
    ),
  );
}
