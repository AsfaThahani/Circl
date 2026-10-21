import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Color getAuraColor(String? level) {
  final normalized = (level ?? '').toString().trim().toLowerCase();
  switch (normalized) {
    case 'diamond':
      return const Color(0xFFC0C0C0);
    case 'gold':
      return const Color(0xFFFFD700);
    case 'silver':
      return const Color(0xFF94A3B8);
    case 'bronze':
      return const Color(0xFFCD7F32);
    default:
      return const Color(0xFFCD7F32);
  }
}

String resolveAvatarUrl(dynamic value, {String fallback = ''}) {
  final raw = value?.toString().trim() ?? '';
  if (raw.isEmpty) return fallback;
  if (raw.startsWith('http')) return raw;

  try {
    return Supabase.instance.client.storage.from('avatars').getPublicUrl(raw);
  } catch (_) {
    return raw;
  }
}

class AuraAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final Color? auraColor;
  final Color? backgroundColor;
  final Widget? fallbackChild;
  final double borderWidth;
  final double glowOpacity;
  final double gapWidth;

  const AuraAvatar({
    super.key,
    this.imageUrl,
    this.radius = 18,
    this.auraColor,
    this.backgroundColor,
    this.fallbackChild,
    this.borderWidth = 1.0,
    this.glowOpacity = 0.2,
    this.gapWidth = 3.0,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedColor = auraColor ?? const Color(0xFFCD7F32);
    final avatarSize = radius * 2;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final themeBgColor = backgroundColor ?? 
        (isDark ? const Color(0xFF1E293B) : Colors.grey.shade200);

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: avatarSize + 18,
          height: avatarSize + 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: resolvedColor.withValues(alpha: glowOpacity),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                resolvedColor.withValues(alpha: 0.65),
                resolvedColor,
                resolvedColor.withValues(alpha: 0.85),
              ],
            ),
            border: Border.all(
              color: resolvedColor.withValues(alpha: 0.95),
              width: borderWidth,
            ),
          ),
          child: Container(
            padding: EdgeInsets.all(gapWidth),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: themeBgColor,
            ),
            child: CircleAvatar(
              radius: radius,
              backgroundColor: themeBgColor,
              backgroundImage: (imageUrl != null && imageUrl!.isNotEmpty)
                  ? NetworkImage(imageUrl!)
                  : null,
              child: (imageUrl == null || imageUrl!.isEmpty)
                  ? fallbackChild
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}
