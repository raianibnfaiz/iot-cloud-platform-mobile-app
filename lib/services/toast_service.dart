import 'package:flutter/material.dart';
import '../widgets/toast.dart';

enum ToastType { success, error, info, warning }

class ToastService {
  static final ToastService _instance = ToastService._internal();
  static const Duration _defaultDuration = Duration(seconds: 3);
  static const Duration _showDelay = Duration(milliseconds: 300);

  factory ToastService() {
    return _instance;
  }

  ToastService._internal();

  static OverlayEntry? _currentToast;

  void showToast(
    BuildContext context, {
    required String message,
    ToastType type = ToastType.info,
    Duration duration = _defaultDuration,
    VoidCallback? onDismiss,
    bool immediate = false,
  }) {
    // Remove existing toast if any
    _currentToast?.remove();
    _currentToast = null;

    final overlay = Overlay.of(context);
    _currentToast = OverlayEntry(
      builder:
          (context) => Toast(
            message: message,
            type: type,
            onDismiss: () {
              _currentToast?.remove();
              _currentToast = null;
              onDismiss?.call();
            },
          ),
    );

    // Show toast after navigation completes
    if (immediate) {
      overlay.insert(_currentToast!);
    } else {
      Future.delayed(_showDelay, () {
        if (_currentToast != null) {
          overlay.insert(_currentToast!);
        }
      });
    }

    // Auto dismiss after duration
    Future.delayed(duration + (immediate ? Duration.zero : _showDelay), () {
      if (_currentToast != null) {
        _currentToast?.remove();
        _currentToast = null;
        onDismiss?.call();
      }
    });
  }

  static void success(
    BuildContext context, {
    required String message,
    Duration? duration,
    VoidCallback? onDismiss,
    bool immediate = false,
  }) {
    ToastService().showToast(
      context,
      message: message,
      type: ToastType.success,
      duration: duration ?? _defaultDuration,
      onDismiss: onDismiss,
      immediate: immediate,
    );
  }

  static void error(
    BuildContext context, {
    required String message,
    Duration? duration,
    VoidCallback? onDismiss,
    bool immediate = false,
  }) {
    ToastService().showToast(
      context,
      message: message,
      type: ToastType.error,
      duration: duration ?? _defaultDuration,
      onDismiss: onDismiss,
      immediate: immediate,
    );
  }

  static void info(
    BuildContext context, {
    required String message,
    Duration? duration,
    VoidCallback? onDismiss,
    bool immediate = false,
  }) {
    ToastService().showToast(
      context,
      message: message,
      type: ToastType.info,
      duration: duration ?? _defaultDuration,
      onDismiss: onDismiss,
      immediate: immediate,
    );
  }

  static void warning(
    BuildContext context, {
    required String message,
    Duration? duration,
    VoidCallback? onDismiss,
    bool immediate = false,
  }) {
    ToastService().showToast(
      context,
      message: message,
      type: ToastType.warning,
      duration: duration ?? _defaultDuration,
      onDismiss: onDismiss,
      immediate: immediate,
    );
  }
}
