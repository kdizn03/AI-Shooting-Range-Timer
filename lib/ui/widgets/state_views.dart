import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Shown when a list or chart has no data yet.
class EmptyState extends StatelessWidget {
  /// Creates an [EmptyState].
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpace.xl,
          vertical: compact ? AppSpace.xl : AppSpace.xxxl,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: compact ? 40 : 52,
                height: compact ? 40 : 52,
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: AppRadius.mdAll,
                  border: Border.all(color: AppColors.border),
                ),
                child: Icon(icon,
                    size: compact ? 20 : 24, color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpace.lg),
              Text(title, style: AppType.heading, textAlign: TextAlign.center),
              if (message != null) ...[
                const SizedBox(height: AppSpace.xs),
                Text(message!,
                    style: AppType.bodySecondary, textAlign: TextAlign.center),
              ],
              if (action != null) ...[
                const SizedBox(height: AppSpace.lg),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Neutral loading placeholder.
class LoadingState extends StatelessWidget {
  /// Creates a [LoadingState].
  const LoadingState({super.key, this.label = 'Loading…'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(height: AppSpace.md),
            Text(label, style: AppType.bodySecondary),
          ],
        ),
      ),
    );
  }
}

/// Error placeholder with a plain-language message and optional retry.
class ErrorState extends StatelessWidget {
  /// Creates an [ErrorState].
  const ErrorState({
    super.key,
    required this.title,
    this.message,
    this.onRetry,
  });

  final String title;
  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.error_outline,
      title: title,
      message: message,
      action: onRetry == null
          ? null
          : OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Try again'),
            ),
    );
  }
}

/// Inline banner for warnings/errors inside a page.
class InlineNotice extends StatelessWidget {
  /// Creates an [InlineNotice].
  const InlineNotice({
    super.key,
    required this.message,
    this.icon = Icons.info_outline,
    this.color = AppColors.info,
    this.action,
  });

  final String message;
  final IconData icon;
  final Color color;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.md, vertical: AppSpace.sm + 2),
        decoration: BoxDecoration(
          color: AppColors.tint(color, 0.10),
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: AppColors.tint(color, 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Text(message,
                  style: AppType.body.copyWith(color: AppColors.textPrimary)),
            ),
            if (action != null) ...[
              const SizedBox(width: AppSpace.sm),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
