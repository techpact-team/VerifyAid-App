import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

String fieldDisplayValue(Object? value, {String fallback = 'N/A'}) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) {
    return fallback;
  }
  return text;
}

class FieldBackButton extends StatelessWidget {
  const FieldBackButton({
    super.key,
    this.fallbackLocation = '/home',
    this.tooltip = 'Back',
  });

  final String fallbackLocation;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      icon: const Icon(Icons.arrow_back_rounded),
      onPressed: () {
        final navigator = Navigator.of(context);

        if (navigator.canPop()) {
          navigator.pop();
          return;
        }

        context.go(fallbackLocation);
      },
    );
  }
}

class FieldLogo extends StatelessWidget {
  const FieldLogo({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final markSize = compact ? 36.0 : 54.0;
    final titleSize = compact ? 24.0 : 30.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: markSize,
              width: markSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.shield_outlined,
                    color: AppColors.primaryDark,
                    size: markSize,
                  ),
                  Positioned(
                    top: compact ? 6 : 9,
                    child: Icon(
                      Icons.check,
                      color: AppColors.primary,
                      size: compact ? 12 : 18,
                    ),
                  ),
                  Positioned(
                    bottom: compact ? 5 : 8,
                    child: Icon(
                      Icons.groups_2,
                      color: AppColors.primary,
                      size: compact ? 12 : 18,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontFamily: 'Mulish',
                  fontSize: titleSize,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
                children: const [
                  TextSpan(
                    text: 'VERIFY',
                    style: TextStyle(color: AppColors.primaryDark),
                  ),
                  TextSpan(
                    text: 'AID',
                    style: TextStyle(color: AppColors.primary),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'FIELD OPERATIONS',
          style: TextStyle(
            color: AppColors.muted,
            fontSize: compact ? 9 : 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

class FieldSurface extends StatelessWidget {
  const FieldSurface({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.color = AppColors.surface,
    this.borderColor = AppColors.border,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color color;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x030A2D4E),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class FieldInfoRow extends StatelessWidget {
  const FieldInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    super.key,
    this.iconColor = AppColors.primary,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 36,
          width: 36,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                softWrap: true,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
  }
}

class FieldStatusPill extends StatelessWidget {
  const FieldStatusPill({
    required this.label,
    super.key,
    this.icon,
    this.color = AppColors.primary,
    this.backgroundColor,
  });

  final String label;
  final IconData? icon;
  final Color color;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 190),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor ?? color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 13),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FieldActionTile extends StatelessWidget {
  const FieldActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    super.key,
    this.color = AppColors.primary,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Color color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      softWrap: true,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 10), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

class FieldMetricTile extends StatelessWidget {
  const FieldMetricTile({
    required this.label,
    required this.value,
    required this.icon,
    super.key,
    this.color = AppColors.primary,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return FieldSurface(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: AppColors.text,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class FieldPhotoAvatar extends StatelessWidget {
  const FieldPhotoAvatar({super.key, this.file, this.label, this.size = 58});

  final File? file;
  final String? label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initials = (label ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part[0])
        .take(2)
        .join()
        .toUpperCase();

    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primarySoft,
        border: Border.all(color: AppColors.border),
        image: file == null
            ? null
            : DecorationImage(image: FileImage(file!), fit: BoxFit.cover),
      ),
      alignment: Alignment.center,
      child: file == null
          ? Text(
              initials.isEmpty ? 'VA' : initials,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
              ),
            )
          : null,
    );
  }
}

class FieldBottomNav extends StatelessWidget {
  const FieldBottomNav({
    required this.currentIndex,
    required this.onTap,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    const items = [
      _FieldBottomNavItem(Icons.home_rounded, 'Home'),
      _FieldBottomNavItem(Icons.groups_2_outlined, 'Beneficiaries'),
      _FieldBottomNavItem(Icons.inventory_2_outlined, 'Distributions'),
      _FieldBottomNavItem(Icons.sync_rounded, 'Sync'),
      _FieldBottomNavItem(Icons.more_horiz, 'More'),
    ];

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              for (var index = 0; index < items.length; index++)
                Expanded(
                  child: InkWell(
                    onTap: () => onTap(index),
                    child: _BottomNavButton(
                      item: items[index],
                      selected: index == currentIndex,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldBottomNavItem {
  const _FieldBottomNavItem(this.icon, this.label);

  final IconData icon;
  final String label;
}

class _BottomNavButton extends StatelessWidget {
  const _BottomNavButton({required this.item, required this.selected});

  final _FieldBottomNavItem item;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.muted;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(item.icon, color: color, size: 21),
        const SizedBox(height: 4),
        Text(
          item.label,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class FieldPhotoPreview extends StatelessWidget {
  const FieldPhotoPreview({required this.file, super.key, this.height = 180});

  final File file;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.file(
        file,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
      ),
    );
  }
}
