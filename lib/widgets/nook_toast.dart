import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/nook_colors.dart';
import '../theme/nook_spacing.dart';
import '../theme/nook_typography.dart';

/// Confirmations, at the top of the screen.
///
/// The top inset, not the bottom, because the bottom is where the primary
/// button and the tab bar are — a message there covers the controls you were
/// just using. `IgnorePointer`, so a tap goes through to whatever is beneath.
///
/// App-level rather than screen-level, so a message raised while a route is
/// popping survives the pop.
class NookToast {
  NookToast._();

  static OverlayEntry? _entry;

  /// How long a message stays. Long enough to read a sentence, short enough
  /// that it is gone before you need the space back.
  static const duration = Duration(seconds: 3);

  /// Shows [message] over the whole app.
  ///
  /// Takes an [OverlayState] rather than a `BuildContext` on purpose: the
  /// caller resolves it before any `await` or `pop`, so a confirmation shown
  /// after the screen that triggered it has gone still lands.
  static void show(
    OverlayState overlay,
    String message, {
    IconData icon = Icons.check_rounded,
    bool isError = false,
  }) {
    dismiss();

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _ToastHost(
        message: message,
        icon: isError ? Icons.error_outline_rounded : icon,
        isError: isError,
        // The countdown belongs to the widget, not to this class: a static
        // timer outlives the tree it was started for.
        onElapsed: () {
          if (_entry == entry) dismiss();
        },
      ),
    );
    _entry = entry;
    overlay.insert(entry);
  }

  /// Convenience for the common case, where the screen is still mounted.
  static void of(
    BuildContext context,
    String message, {
    IconData icon = Icons.check_rounded,
    bool isError = false,
  }) => show(
    Overlay.of(context, rootOverlay: true),
    message,
    icon: icon,
    isError: isError,
  );

  static void dismiss() {
    _entry?.remove();
    _entry = null;
  }
}

/// The bar itself: it slides down from the top edge and fades as it goes.
class _ToastHost extends StatefulWidget {
  const _ToastHost({
    required this.message,
    required this.icon,
    required this.isError,
    required this.onElapsed,
  });

  final String message;
  final IconData icon;
  final bool isError;
  final VoidCallback onElapsed;

  @override
  State<_ToastHost> createState() => _ToastHostState();
}

class _ToastHostState extends State<_ToastHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  )..forward();

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(NookToast.duration, () {
      if (mounted) widget.onElapsed();
    });
  }

  @override
  void dispose() {
    // Cancelled here, so tearing the tree down takes the countdown with it.
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    return Positioned(
      top: MediaQuery.of(context).padding.top + NookSpacing.tight,
      left: NookSpacing.screenEdge,
      right: NookSpacing.screenEdge,
      // Nothing here takes a tap: the controls underneath keep working while
      // the message is up.
      child: IgnorePointer(
        child: FadeTransition(
          opacity: curve,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.35),
              end: Offset.zero,
            ).animate(curve),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: NookSpacing.section,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: NookColors.textPrimary,
                  borderRadius: BorderRadius.circular(NookRadius.button),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x332E2E2E),
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.icon,
                      size: 17,
                      color: widget.isError
                          ? NookColors.error
                          : NookColors.primary,
                    ),
                    const SizedBox(width: NookSpacing.tight),
                    Flexible(
                      child: Text(
                        widget.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: NookType.bodyStrong.copyWith(
                          color: NookColors.surface,
                        ),
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
}
