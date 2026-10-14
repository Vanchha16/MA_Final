import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/user.dart';

/// Round profile photo, or the user's initials on brand blue when there is no
/// photo. Optional white ring and camera badge (Figma: Avatar).
class UserAvatar extends StatelessWidget {
  final User? user;
  final double size;
  final bool ring;
  final bool cameraBadge;
  final bool busy;

  const UserAvatar({super.key, this.user, this.size = 64, this.ring = false, this.cameraBadge = false, this.busy = false});

  static String initials(String? name) {
    final parts = (name ?? '').trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final url = user?.avatarUrl;
    final fallback = Center(
      child: Text(
        initials(user?.fullName),
        style: TextStyle(color: Colors.white, fontSize: size * 0.36, fontWeight: FontWeight.bold),
      ),
    );
    final badge = size * 0.34;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: AppTheme.primaryDark,
              shape: BoxShape.circle,
              border: ring ? Border.all(color: Colors.white, width: 3) : null,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 14, offset: const Offset(0, 6))],
            ),
            child: ClipOval(
              child: url == null
                  ? fallback
                  : CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => fallback,
                      errorWidget: (_, _, _) => fallback,
                    ),
            ),
          ),
          if (busy)
            Positioned.fill(
              child: DecoratedBox(
                decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                child: Center(
                  child: SizedBox.square(
                    dimension: size * 0.3,
                    child: const CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  ),
                ),
              ),
            ),
          if (cameraBadge)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: badge,
                height: badge,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.16), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Icon(Icons.photo_camera_rounded, size: badge * 0.55, color: AppTheme.primaryDark),
              ),
            ),
        ],
      ),
    );
  }
}
