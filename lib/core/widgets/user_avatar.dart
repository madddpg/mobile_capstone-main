import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:iconstruct/core/widgets/app_image.dart';
import '../state/user_state/user_provider.dart';

class UserAvatar extends StatelessWidget {
  final double size;
  final VoidCallback? onTap;
  final bool hasBorder;

  const UserAvatar({
    super.key,
    this.size = 36.0,
    this.onTap,
    this.hasBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    const Color darkBlue = Color(0xFF2C3E50);
    const Color creamBg = Color(0xFFEDE4D4);

    return GestureDetector(
      onTap: onTap,
      child: Consumer<UserProvider>(
        builder: (context, userProvider, child) {
          final profileUrl = userProvider.currentUser?.profileImageUrl;

          Widget content;
          if (profileUrl != null && profileUrl.isNotEmpty) {
            content = AppImage.network(
              context,
              profileUrl,
              width: size,
              height: size,
              fit: BoxFit.cover,
              placeholder: Center(
                child: SizedBox(
                  width: size * 0.45,
                  height: size * 0.45,
                  child: const CircularProgressIndicator(
                    color: creamBg,
                    strokeWidth: 2,
                  ),
                ),
              ),
              error: Icon(
                Icons.person_rounded,
                color: creamBg,
                size: size * 0.6,
              ),
            );
          } else {
            content = Icon(
              Icons.person_rounded,
              color: creamBg,
              size: size * 0.6,
            );
          }

          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: darkBlue,
              border: hasBorder ? Border.all(color: creamBg, width: 2) : null,
              boxShadow: [
                if (hasBorder)
                  BoxShadow(
                    color: Colors.black.withAlpha(26),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: content,
          );
        },
      ),
    );
  }
}
