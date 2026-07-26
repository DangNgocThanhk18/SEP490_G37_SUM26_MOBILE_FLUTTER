import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The visual and semantic intent of an in-app notification.
enum InAppNotificationType { success, error, warning, information }

/// An optional action shown below an in-app notification's message.
class InAppNotificationAction {
  const InAppNotificationAction({
    required this.label,
    required this.onPressed,
    this.dismissOnPressed = true,
  });

  final String label;
  final FutureOr<void> Function() onPressed;
  final bool dismissOnPressed;
}

/// A handle that can dismiss a notification and report when it has closed.
class InAppNotificationHandle {
  InAppNotificationHandle._(this._onDismiss, this.closed);

  final VoidCallback _onDismiss;

  /// Completes after the exit animation has finished and the overlay is gone.
  final Future<void> closed;

  void dismiss() => _onDismiss();
}

/// Branded, cross-platform notices rendered in the application's root overlay.
///
/// A notice automatically closes after [duration]. Pass `null` to keep it open
/// until the user dismisses it. Automatic closing is disabled when the device's
/// accessible-navigation preference is enabled.
abstract final class InAppNotifications {
  static const Duration defaultDuration = Duration(seconds: 4);
  static const int _maxVisible = 4;
  static final Map<OverlayState, _NotificationOverlayController> _controllers =
      <OverlayState, _NotificationOverlayController>{};

  static InAppNotificationHandle show(
    BuildContext context, {
    required String message,
    InAppNotificationType type = InAppNotificationType.information,
    String? title,
    Duration? duration = defaultDuration,
    InAppNotificationAction? action,
    bool dismissible = true,
    String? dismissLabel,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      throw FlutterError(
        'InAppNotifications.show() requires an Overlay ancestor. '
        'Call it with a context below MaterialApp, CupertinoApp, or Navigator.',
      );
    }

    final controller = _controllers.putIfAbsent(
      overlay,
      () => _NotificationOverlayController(
        overlay: overlay,
        maxVisible: _maxVisible,
        onEmpty: () => _controllers.remove(overlay),
      ),
    );
    return controller.show(
      message: message,
      title: title,
      type: type,
      duration: duration,
      action: action,
      dismissible: dismissible,
      dismissLabel: dismissLabel,
    );
  }

  static InAppNotificationHandle success(
    BuildContext context, {
    required String message,
    String? title,
    Duration? duration = defaultDuration,
    InAppNotificationAction? action,
    bool dismissible = true,
  }) {
    return show(
      context,
      message: message,
      title: title,
      type: InAppNotificationType.success,
      duration: duration,
      action: action,
      dismissible: dismissible,
    );
  }

  static InAppNotificationHandle error(
    BuildContext context, {
    required String message,
    String? title,
    Duration? duration = defaultDuration,
    InAppNotificationAction? action,
    bool dismissible = true,
  }) {
    return show(
      context,
      message: message,
      title: title,
      type: InAppNotificationType.error,
      duration: duration,
      action: action,
      dismissible: dismissible,
    );
  }

  static InAppNotificationHandle warning(
    BuildContext context, {
    required String message,
    String? title,
    Duration? duration = defaultDuration,
    InAppNotificationAction? action,
    bool dismissible = true,
  }) {
    return show(
      context,
      message: message,
      title: title,
      type: InAppNotificationType.warning,
      duration: duration,
      action: action,
      dismissible: dismissible,
    );
  }

  static InAppNotificationHandle information(
    BuildContext context, {
    required String message,
    String? title,
    Duration? duration = defaultDuration,
    InAppNotificationAction? action,
    bool dismissible = true,
  }) {
    return show(
      context,
      message: message,
      title: title,
      type: InAppNotificationType.information,
      duration: duration,
      action: action,
      dismissible: dismissible,
    );
  }
}

/// A reusable custom modal route and panel surface.
///
/// Use [show] for forms or other bespoke content, [confirm] for confirmation
/// prompts, and [showLoading] for blocking progress. All variants are built with
/// [showGeneralDialog] and use the same transition and responsive route frame.
abstract final class InAppModal {
  static Future<T?> show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    bool barrierDismissible = true,
    String? barrierLabel,
    Color barrierColor = const Color(0xB307040D),
    Duration transitionDuration = const Duration(milliseconds: 240),
    bool useRootNavigator = true,
    RouteSettings? routeSettings,
  }) {
    final resolvedBarrierLabel =
        barrierLabel ??
        MaterialLocalizations.of(context).modalBarrierDismissLabel;
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: resolvedBarrierLabel,
      barrierColor: barrierColor,
      transitionDuration: transitionDuration,
      useRootNavigator: useRootNavigator,
      routeSettings: routeSettings,
      pageBuilder: (routeContext, _, _) {
        return PopScope(
          canPop: barrierDismissible,
          child: _InAppModalRouteFrame(child: builder(routeContext)),
        );
      },
      transitionBuilder: (routeContext, animation, _, child) {
        final disableAnimations =
            MediaQuery.maybeOf(routeContext)?.disableAnimations ?? false;
        if (disableAnimations) return child;

        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String? confirmLabel,
    String? cancelLabel,
    IconData? icon,
    bool destructive = false,
    bool barrierDismissible = true,
  }) async {
    final localizations = MaterialLocalizations.of(context);
    final result = await show<bool>(
      context,
      barrierDismissible: barrierDismissible,
      builder: (modalContext) {
        final theme = Theme.of(modalContext);
        final scheme = theme.colorScheme;
        final accent = destructive ? scheme.error : scheme.primary;
        return InAppModalPanel(
          title: title,
          icon:
              icon ??
              (destructive
                  ? Icons.warning_amber_rounded
                  : Icons.help_outline_rounded),
          iconColor: accent,
          content: Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          actions: <Widget>[
            OutlinedButton(
              onPressed: () => Navigator.of(modalContext).pop(false),
              child: Text(cancelLabel ?? localizations.cancelButtonLabel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(modalContext).pop(true),
              style: destructive
                  ? FilledButton.styleFrom(
                      backgroundColor: scheme.error,
                      foregroundColor: scheme.onError,
                    )
                  : null,
              child: Text(confirmLabel ?? localizations.okButtonLabel),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  /// Shows a blocking progress panel. Dismiss it with [dismiss] when work ends.
  static Future<void> showLoading(
    BuildContext context, {
    required String message,
    String? title,
    bool barrierDismissible = false,
  }) async {
    await show<void>(
      context,
      barrierDismissible: barrierDismissible,
      builder: (_) => InAppLoadingPanel(title: title, message: message),
    );
  }

  /// Closes the top-most root-navigator modal opened by this API.
  static void dismiss<T>(BuildContext context, [T? result]) {
    Navigator.of(context, rootNavigator: true).pop<T>(result);
  }
}

/// The branded surface used inside [InAppModal.show].
class InAppModalPanel extends StatelessWidget {
  const InAppModalPanel({
    super.key,
    required this.title,
    required this.content,
    this.icon,
    this.iconColor,
    this.actions = const <Widget>[],
    this.showCloseButton = false,
    this.onClose,
    this.maxWidth = 480,
    this.semanticLabel,
  });

  final String title;
  final Widget content;
  final IconData? icon;
  final Color? iconColor;
  final List<Widget> actions;
  final bool showCloseButton;
  final VoidCallback? onClose;
  final double maxWidth;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = context.cvColors;
    final accent = iconColor ?? scheme.primary;
    final closeTooltip = MaterialLocalizations.of(context).closeButtonTooltip;

    return Semantics(
      container: true,
      scopesRoute: true,
      namesRoute: true,
      label: semanticLabel ?? title,
      explicitChildNodes: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Material(
          color: tokens.surfaceRaised,
          elevation: 18,
          shadowColor: Colors.black.withValues(alpha: 0.28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: tokens.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: accent, width: 3)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (icon != null) ...<Widget>[
                        _TintedIcon(icon: icon!, color: accent, size: 42),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(title, style: theme.textTheme.titleLarge),
                        ),
                      ),
                      if (showCloseButton)
                        IconButton(
                          onPressed:
                              onClose ?? () => Navigator.of(context).maybePop(),
                          tooltip: closeTooltip,
                          icon: const Icon(Icons.close_rounded),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Flexible(child: SingleChildScrollView(child: content)),
                  if (actions.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 22),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 10,
                      runSpacing: 10,
                      children: actions,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A ready-made progress panel for operations such as authentication updates.
class InAppLoadingPanel extends StatelessWidget {
  const InAppLoadingPanel({super.key, required this.message, this.title});

  final String message;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InAppModalPanel(
      title: title ?? message,
      semanticLabel: title == null ? message : '$title. $message',
      content: title == null
          ? Center(
              child: SizedBox.square(
                dimension: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: scheme.primary,
                ),
              ),
            )
          : Row(
              children: <Widget>[
                SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _NotificationOverlayController {
  _NotificationOverlayController({
    required this.overlay,
    required this.maxVisible,
    required this.onEmpty,
  });

  final OverlayState overlay;
  final int maxVisible;
  final VoidCallback onEmpty;
  final List<_NotificationRecord> _records = <_NotificationRecord>[];
  OverlayEntry? _entry;

  InAppNotificationHandle show({
    required String message,
    required InAppNotificationType type,
    required Duration? duration,
    required bool dismissible,
    String? title,
    InAppNotificationAction? action,
    String? dismissLabel,
  }) {
    if (_records.length >= maxVisible) {
      _remove(_records.first);
    }

    late final _NotificationRecord record;
    record = _NotificationRecord(
      message: message,
      title: title,
      type: type,
      duration: duration,
      action: action,
      dismissible: dismissible,
      dismissLabel: dismissLabel,
      onRemove: () => _remove(record),
    );
    _records.add(record);
    if (_entry == null) {
      _entry = OverlayEntry(
        builder: (_) => _NotificationOverlayHost(
          records: List<_NotificationRecord>.unmodifiable(_records),
        ),
      );
      overlay.insert(_entry!);
    } else {
      _entry!.markNeedsBuild();
    }

    return InAppNotificationHandle._(record.dismiss, record.closed);
  }

  void _remove(_NotificationRecord record) {
    if (!_records.remove(record)) return;
    record.complete();
    if (_records.isNotEmpty) {
      _entry?.markNeedsBuild();
      return;
    }

    _entry?.remove();
    _entry?.dispose();
    _entry = null;
    onEmpty();
  }
}

class _NotificationRecord {
  _NotificationRecord({
    required this.message,
    required this.title,
    required this.type,
    required this.duration,
    required this.action,
    required this.dismissible,
    required this.dismissLabel,
    required this.onRemove,
  });

  final String message;
  final String? title;
  final InAppNotificationType type;
  final Duration? duration;
  final InAppNotificationAction? action;
  final bool dismissible;
  final String? dismissLabel;
  final VoidCallback onRemove;
  final GlobalKey<_InAppNotificationCardState> key =
      GlobalKey<_InAppNotificationCardState>();
  final Completer<void> _closed = Completer<void>();

  Future<void> get closed => _closed.future;

  void dismiss() {
    final state = key.currentState;
    if (state == null) {
      onRemove();
    } else {
      unawaited(state.dismiss());
    }
  }

  void complete() {
    if (!_closed.isCompleted) _closed.complete();
  }
}

class _NotificationOverlayHost extends StatelessWidget {
  const _NotificationOverlayHost({required this.records});

  final List<_NotificationRecord> records;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: false,
        child: SafeArea(
          bottom: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                media.size.width < 480 ? 12 : 24,
                12,
                media.size.width < 480 ? 12 : 24,
                0,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 560,
                  maxHeight: media.size.height * 0.78,
                ),
                child: SingleChildScrollView(
                  clipBehavior: Clip.none,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      for (final record in records)
                        Padding(
                          key: ValueKey<_NotificationRecord>(record),
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _InAppNotificationCard(
                            key: record.key,
                            record: record,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InAppNotificationCard extends StatefulWidget {
  const _InAppNotificationCard({super.key, required this.record});

  final _NotificationRecord record;

  @override
  State<_InAppNotificationCard> createState() => _InAppNotificationCardState();
}

class _InAppNotificationCardState extends State<_InAppNotificationCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  Timer? _timer;
  bool _started = false;
  bool _closing = false;
  bool _runningAction = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 190),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final media = MediaQuery.maybeOf(context);
    if (media?.disableAnimations ?? false) {
      _animationController.value = 1;
    } else {
      unawaited(_animationController.forward());
    }
    if (!(media?.accessibleNavigation ?? false) &&
        widget.record.duration != null) {
      _timer = Timer(widget.record.duration!, dismiss);
    }
  }

  Future<void> dismiss() async {
    if (_closing) return;
    _closing = true;
    _timer?.cancel();
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (!disableAnimations && mounted) {
      await _animationController.reverse();
    }
    widget.record.onRemove();
  }

  Future<void> _runAction() async {
    final action = widget.record.action;
    if (action == null || _runningAction) return;
    setState(() => _runningAction = true);
    try {
      await action.onPressed();
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'ComiVerse in-app notifications',
          context: ErrorDescription('while running a notification action'),
        ),
      );
    } finally {
      if (mounted) setState(() => _runningAction = false);
      if (action.dismissOnPressed) await dismiss();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = context.cvColors;
    final appearance = _NotificationAppearance.resolve(
      context,
      widget.record.type,
    );
    final dismissLabel =
        widget.record.dismissLabel ??
        MaterialLocalizations.of(context).closeButtonTooltip;
    final animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -0.18),
          end: Offset.zero,
        ).animate(animation),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.98, end: 1).animate(animation),
          child: Semantics(
            container: true,
            liveRegion: true,
            label: <String?>[
              widget.record.title,
              widget.record.message,
            ].whereType<String>().join('. '),
            child: Material(
              color: tokens.surfaceRaised,
              elevation: 12,
              shadowColor: Colors.black.withValues(alpha: 0.22),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: appearance.color.withValues(alpha: 0.4),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: appearance.color, width: 4),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _TintedIcon(
                        icon: appearance.icon,
                        color: appearance.color,
                        size: 38,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            if (widget.record.title != null) ...<Widget>[
                              Text(
                                widget.record.title!,
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 3),
                            ],
                            Text(
                              widget.record.message,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            if (widget.record.action != null) ...<Widget>[
                              const SizedBox(height: 5),
                              TextButton(
                                onPressed: _runningAction ? null : _runAction,
                                style: TextButton.styleFrom(
                                  foregroundColor: appearance.color,
                                  minimumSize: const Size(48, 42),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                ),
                                child: _runningAction
                                    ? SizedBox.square(
                                        dimension: 17,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: appearance.color,
                                        ),
                                      )
                                    : Text(widget.record.action!.label),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (widget.record.dismissible)
                        IconButton(
                          onPressed: dismiss,
                          tooltip: dismissLabel,
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.close_rounded, size: 20),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationAppearance {
  const _NotificationAppearance(this.color, this.icon);

  final Color color;
  final IconData icon;

  static _NotificationAppearance resolve(
    BuildContext context,
    InAppNotificationType type,
  ) {
    final tokens = context.cvColors;
    return switch (type) {
      InAppNotificationType.success => _NotificationAppearance(
        tokens.success,
        Icons.check_circle_rounded,
      ),
      InAppNotificationType.error => _NotificationAppearance(
        Theme.of(context).colorScheme.error,
        Icons.error_rounded,
      ),
      InAppNotificationType.warning => _NotificationAppearance(
        tokens.warning,
        Icons.warning_amber_rounded,
      ),
      InAppNotificationType.information => _NotificationAppearance(
        tokens.info,
        Icons.info_rounded,
      ),
    };
  }
}

class _TintedIcon extends StatelessWidget {
  const _TintedIcon({
    required this.icon,
    required this.color,
    required this.size,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: size * 0.58),
      ),
    );
  }
}

class _InAppModalRouteFrame extends StatelessWidget {
  const _InAppModalRouteFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: AnimatedPadding(
          duration: media.disableAnimations
              ? Duration.zero
              : const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.fromLTRB(
            media.size.width < 480 ? 16 : 32,
            24,
            media.size.width < 480 ? 16 : 32,
            24 + media.viewInsets.bottom,
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}
