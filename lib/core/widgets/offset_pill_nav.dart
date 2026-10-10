import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iconstruct/core/navigation/app_nav.dart';
import 'package:iconstruct/core/services/unread_notifications.dart';
import 'package:iconstruct/core/utils/hammer_nav.dart';
import 'package:iconstruct/core/widgets/iconstruct_panel.dart';
import 'package:iconstruct/features/auth/presentation/screens/saved_projects.dart';
import 'package:iconstruct/features/chat/data/chat_service.dart';
import 'package:iconstruct/features/chat/screens/chat_inbox_screen.dart';
/// Which pill-nav label is active.
///
/// The global bar has four destinations: [home], [bidding], [chat] and
/// [files]. [estimate] and [finalize] are steps inside the planning flow
/// rather than places you navigate to, so they highlight nothing. They are
/// kept so those screens can still declare where they sit.
enum OffsetNavTab { home, estimate, finalize, files, bidding, chat }

/// Unread conversation count for the chat tab.
///
/// Wrapped because the bar renders in widget tests and before Firebase is
/// initialised, where constructing the service throws and would take the whole
/// navigation bar down with it.
Stream<int> _chatUnreadStream() {
  try {
    return ChatService().watchUnreadCount();
  } catch (_) {
    return Stream<int>.value(0);
  }
}

/// Shared cream floating pill navigation used across planning screens.
class OffsetPillNav extends StatelessWidget {
  final OffsetNavTab activeTab;

  const OffsetPillNav({super.key, required this.activeTab});

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    // Only the active chip is Flexible, so it can shorten its label on a
    // narrow phone with large text instead of pushing the row past the edge
    // of the pill. With every slot Flexible the row was split four ways, and
    // "Home" was cut to "H…" with room to spare: an icon needs 40, not a
    // quarter of the pill.
    Widget slot(OffsetNavTab tab, Widget child) =>
        activeTab == tab ? Flexible(child: child) : child;

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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              slot(
                OffsetNavTab.home,
                activeTab == OffsetNavTab.home
                    ? const _ActiveNavChip(
                        icon: Icons.home_rounded,
                        label: 'Home',
                      )
                    : _NavIcon(
                        icon: Icons.home_rounded,
                        onTap: () => AppNav.openHomeTab(context),
                      ),
              ),
              const SizedBox(width: 10),
              slot(
                OffsetNavTab.bidding,
                activeTab == OffsetNavTab.bidding
                    ? const _ActiveNavChip(
                        imagePath: 'assets/images/hammer.png',
                        label: 'Bidding',
                      )
                    : _NavIcon(
                        imagePath: 'assets/images/hammer.png',
                        onTap: () => handleHammerTap(context),
                      ),
              ),
              const SizedBox(width: 10),
              slot(
                OffsetNavTab.chat,
                StreamBuilder<int>(
                  stream: _chatUnreadStream(),
                  builder: (context, chatSnap) {
                    final unreadChats = chatSnap.data ?? 0;

                    if (activeTab == OffsetNavTab.chat) {
                      return _ActiveNavChip(
                        icon: Icons.chat_bubble_rounded,
                        label: 'Chat',
                        badgeCount: unreadChats,
                      );
                    }
                    return _NavIcon(
                      icon: Icons.chat_bubble_rounded,
                      badgeCount: unreadChats,
                      onTap: () => AppNav.openTab(
                        context,
                        (_) => const ChatInboxScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              slot(
                OffsetNavTab.files,
                activeTab == OffsetNavTab.files
                    ? const _ActiveNavChip(
                        icon: Icons.folder_rounded,
                        label: 'Files',
                      )
                    : _NavIcon(
                        icon: Icons.folder_rounded,
                        onTap: () => AppNav.openTab(
                          context,
                          (_) => const SavedProjectsScreen(),
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
        mainAxisSize: MainAxisSize.min,
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
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: IConstructPanel.cream,
              ),
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
