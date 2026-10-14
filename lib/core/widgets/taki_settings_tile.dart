import 'package:flutter/material.dart';

import '../theme/taki_colors.dart';
import '../theme/taki_icon_size.dart';
import '../theme/taki_spacing.dart';
import '../theme/taki_typography.dart';
import 'taki_interaction.dart';

/// One row of the Settings screen: a leading icon, a title, an optional
/// subtitle and an optional trailing widget (value, chevron, spinner).
///
/// - Without [onTap] the row is informational: it is not focusable and not
///   announced as a button.
/// - [destructive] paints the title with the error color (e.g. "Clear cache").
/// - The whole row is one semantics node: `title, subtitle`.
class TakiSettingsTile extends StatelessWidget {
  const TakiSettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.destructive = false,
  });

  /// Minimum row height; grows with the text scale.
  static const double minHeight = 64;

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final titleColor =
        destructive ? TakiColors.error : TakiColors.textPrimary;
    final subtitle = this.subtitle;

    Widget row(Set<WidgetState> states) {
      final content = ConstrainedBox(
        constraints: const BoxConstraints(minHeight: minHeight),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: TakiSpacing.pageGutter,
            vertical: TakiSpacing.sm,
          ),
          child: Row(
            children: [
              ExcludeSemantics(
                child: Icon(
                  icon,
                  size: TakiIconSize.md.value,
                  color: destructive
                      ? TakiColors.error
                      : TakiColors.iconSecondary,
                ),
              ),
              const SizedBox(width: TakiSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TakiTypography.body.copyWith(color: titleColor),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: TakiSpacing.xxs),
                      Text(
                        subtitle,
                        style: TakiTypography.trackSubtitle.copyWith(
                          color: TakiColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing case final trailing?) ...[
                const SizedBox(width: TakiSpacing.md),
                trailing,
              ],
            ],
          ),
        ),
      );

      return Stack(
        children: [
          if (states.contains(WidgetState.pressed))
            Positioned.fill(
              child: ColoredBox(color: TakiColors.pressedOverlay),
            ),
          TakiFocusRing(
            visible: states.contains(WidgetState.focused),
            shape: const RoundedRectangleBorder(),
            inset: true,
            child: content,
          ),
        ],
      );
    }

    final label = subtitle == null ? title : '$title, $subtitle';

    if (onTap == null) {
      return Semantics(
        container: true,
        label: label,
        child: ExcludeSemantics(child: row(const {})),
      );
    }

    return Semantics(
      container: true,
      button: true,
      label: label,
      // The inner TakiPressable semantics are excluded below so the row is a
      // single node; the tap action must live on this one.
      onTap: onTap,
      child: ExcludeSemantics(
        child: TakiPressable(
          onPressed: onTap,
          builder: (context, states) => row(states),
        ),
      ),
    );
  }
}
