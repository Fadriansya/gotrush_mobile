import 'package:flutter/material.dart';

enum AlertType { info, success, error, warning }

Color _backgroundColor(BuildContext context, AlertType type) {
  switch (type) {
    case AlertType.success:
      return Colors.green[700]!;
    case AlertType.error:
      return Colors.red[700]!;
    case AlertType.warning:
      return Colors.orange[800]!;
    case AlertType.info:
      return Theme.of(context).colorScheme.primary;
  }
}

IconData _iconFor(AlertType type) {
  switch (type) {
    case AlertType.success:
      return Icons.check_circle;
    case AlertType.error:
      return Icons.error;
    case AlertType.warning:
      return Icons.warning;
    case AlertType.info:
      return Icons.info;
  }
}

/// Shows a styled, floating SnackBar with an icon and message.
void showAppSnackBar(
  BuildContext context,
  String message, {
  AlertType type = AlertType.info,
  Duration? duration,
}) {
  final snack = buildAppSnackBar(
    context,
    message,
    type: type,
    duration: duration,
  );
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(snack);
}

/// Build a SnackBar widget so callers can capture a ScaffoldMessengerState and
/// show it later (avoids using BuildContext across async gaps).
SnackBar buildAppSnackBar(
  BuildContext context,
  String message, {
  AlertType type = AlertType.info,
  Duration? duration,
}) {
  final bg = _backgroundColor(context, type);
  final icon = _iconFor(type);
  // set sensible defaults per type
  final defDuration =
      duration ??
      (type == AlertType.info
          ? const Duration(seconds: 2)
          : type == AlertType.error
          ? const Duration(seconds: 4)
          : const Duration(seconds: 3));

  return SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: bg,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    duration: defDuration,
    content: Row(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: Colors.white),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

/// Build a SnackBar using only [ThemeData] so callers can construct the
/// SnackBar without holding a BuildContext across async gaps.
SnackBar buildAppSnackBarFromTheme(
  ThemeData theme,
  String message, {
  AlertType type = AlertType.info,
  Duration? duration,
}) {
  final bg = (type == AlertType.info)
      ? theme.colorScheme.primary
      : (type == AlertType.success)
      ? Colors.green[700]!
      : (type == AlertType.error)
      ? Colors.red[700]!
      : Colors.orange[800]!;

  final icon = _iconFor(type);

  final defDuration =
      duration ??
      (type == AlertType.info
          ? const Duration(seconds: 2)
          : type == AlertType.error
          ? const Duration(seconds: 4)
          : const Duration(seconds: 3));

  return SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: bg,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    duration: defDuration,
    content: Row(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: Colors.white),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

/// Shows a dialog with a small entrance animation. For [AlertType.info]
/// the dialog will auto-dismiss after a short duration (non-blocking).
Future<void> showAppDialog(
  BuildContext context, {
  String title = 'Perhatian',
  required String message,
  AlertType type = AlertType.info,
  bool barrierDismissible = true,
  Duration? autoDismissDuration,
}) async {
  final icon = _iconFor(type);
  final color = _backgroundColor(context, type);

  if (!context.mounted) return;

  // choose auto-dismiss for info-type dialogs unless explicitly disabled
  final shouldAutoDismiss =
      type == AlertType.info && autoDismissDuration != Duration.zero;
  final dismissAfter = autoDismissDuration ?? const Duration(seconds: 2);

  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'Alert',
    pageBuilder: (ctx, anim1, anim2) {
      // schedule auto-dismiss if applicable; capture NavigatorState to avoid
      // using the BuildContext across the async gap.
      if (shouldAutoDismiss) {
        final nav = Navigator.of(ctx);
        Future.delayed(dismissAfter, () {
          try {
            if (nav.canPop()) nav.pop();
          } catch (_) {
            // ignore pop errors
          }
        });
      }

      return SafeArea(
        child: Builder(
          builder: (innerCtx) {
            return Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(innerCtx).dialogTheme.backgroundColor ??
                        Theme.of(innerCtx).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: color,
                            child: Icon(icon, color: Colors.white, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(message),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            if (Navigator.of(innerCtx).canPop()) {
                              Navigator.of(innerCtx).pop();
                            }
                          },
                          child: const Text('OK'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    },
    transitionBuilder: (ctx, anim1, anim2, child) {
      final curved = Curves.easeOutBack.transform(anim1.value);
      return Transform.scale(
        scale: curved,
        child: Opacity(opacity: anim1.value, child: child),
      );
    },
    transitionDuration: const Duration(milliseconds: 350),
  );
}
