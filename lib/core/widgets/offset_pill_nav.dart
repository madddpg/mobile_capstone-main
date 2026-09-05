import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iconstruct/core/services/unread_notifications.dart';
import 'package:iconstruct/core/utils/hammer_nav.dart';
import 'package:iconstruct/core/widgets/iconstruct_panel.dart';
import 'package:iconstruct/features/auth/presentation/screens/home_screen.dart';
import 'package:iconstruct/features/auth/presentation/screens/main_home_screen.dart';
import 'package:iconstruct/features/auth/presentation/screens/saved_projects.dart';
/// Which pill-nav label is active.
enum OffsetNavTab { home, estimate, finalize, files, bidding }

/// Shared cream floating pill navigation used across planning screens.
class OffsetPillNav extends StatelessWidget {
  final OffsetNavTab activeTab;

  const OffsetPillNav({super.key, required this.activeTab});

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: IConstructPanel.pillBottomMargin + bottomPad,
        ),
        child: Container(
          height: IConstructPanel.pillHeight,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: IConstructPanel.cream,
            borderRadius: BorderRadius.circular(40),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: StreamBuilder<int>(
            stream: unreadNotificationCountStream(),
            builder: (context, snapshot) {
              final unread = snapshot.data ?? 0;

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (activeTab == OffsetNavTab.home)
                    const _ActiveNavChip(
                      icon: Icons.home_rounded,
                      label: 'Home',
                    )
                  else
                    _NavIcon(
                      icon: Icons.home_rounded,
                      onTap: () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MainHomeScreen(),
                          ),
                          (route) => false,
                        );
                      },
                    ),
                  const SizedBox(width: 10),
                  if (activeTab == OffsetNavTab.bidding)
                    _ActiveNavChip(
                      imagePath: 'assets/images/hammer.png',
                      label: 'Bidding',
                      badgeCount: unread,
                    )
                  else
                    _NavIcon(
                      imagePath: 'assets/images/hammer.png',
                      badgeCount: unread,
                      onTap: () => handleHammerTap(context),
                    ),
                  const SizedBox(width: 10),
                  if (activeTab == OffsetNavTab.files ||
                      activeTab == OffsetNavTab.bidding ||
                      activeTab == OffsetNavTab.home)
                    _NavIcon(
                      icon: Icons.calculate_rounded,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const HomeScreen(),
                          ),
                        );
                      },
                    )
                  else
                    _ActiveNavChip(
                      icon: activeTab == OffsetNavTab.finalize
                          ? Icons.fact_check_rounded
                          : Icons.calculate_rounded,
                      label: activeTab == OffsetNavTab.finalize
                          ? 'Finalize'
                          : 'Estimate',
                    ),
                  const SizedBox(width: 10),
                  if (activeTab == OffsetNavTab.files)
                    _ActiveNavChip(
                      icon: Icons.folder_rounded,
                      label: 'Files',
                      badgeCount: unread,
                    )
                  else
                    _NavIcon(
                      icon: Icons.folder_rounded,
                      badgeCount: unread,
                      onTap: () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SavedProjectsScreen(),
                          ),
                          (route) => false,
                        );
                      },
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ActiveNavChip extends StatelessWidget {
  final IconData? icon;
  final String? imagePath;
  final String label;
  final int badgeCount;

  const _ActiveNavChip({
    this.icon,
    this.imagePath,
    required this.label,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: IConstructPanel.darkBlue,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          if (imagePath != null)
            Image.asset(
              imagePath!,
              width: 18,
              height: 18,
              color: IConstructPanel.cream,
            )
          else
            Icon(icon, color: IConstructPanel.cream, size: 18),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: IConstructPanel.cream,
            ),
          ),
        ],
      ),
    );

    return UnreadBadge(count: badgeCount, offset: 0, child: chip);
  }
}

class _NavIcon extends StatelessWidget {
  final IconData? icon;
  final String? imagePath;
  final VoidCallback onTap;
  final int badgeCount;

  const _NavIcon({
    this.icon,
    this.imagePath,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final iconChild = SizedBox(
      width: 40,
      height: 40,
      child: Center(
        child: imagePath != null
            ? Image.asset(
                imagePath!,
                width: 22,
                height: 22,
                color: IConstructPanel.darkBlue,
              )
            : Icon(icon, color: IConstructPanel.darkBlue, size: 24),
      ),
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: UnreadBadge(count: badgeCount, child: iconChild),
    );
  }
}
