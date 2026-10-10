import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import 'package:iconstruct/core/navigation/planning_nav.dart';
import 'package:iconstruct/core/state/onboarding_preferences.dart';
import 'package:iconstruct/core/state/user_state/user_provider.dart';
import 'package:iconstruct/features/auth/presentation/screens/saved_projects.dart';
import 'package:iconstruct/features/auth/presentation/screens/profile_screen.dart';
import 'package:iconstruct/features/auth/presentation/screens/top_shops_screen.dart';
import 'package:iconstruct/features/auth/presentation/widgets/shop_storefront_sheet.dart';
import 'package:iconstruct/features/auth/presentation/widgets/shop_rating_stars.dart';
import 'package:iconstruct/features/auth/presentation/screens/home_screen.dart';
import 'package:iconstruct/features/auth/presentation/models/ranked_shop.dart';
import 'package:iconstruct/features/auth/presentation/services/shop_ranking_service.dart';
import 'package:iconstruct/core/widgets/app_skeleton.dart';
import 'package:iconstruct/core/widgets/offset_pill_nav.dart';
import 'package:iconstruct/core/widgets/user_avatar.dart';
import 'package:iconstruct/features/onboarding/data/home_guide_steps.dart';
import 'package:iconstruct/features/onboarding/presentation/widgets/home_guide_overlay.dart';
import 'package:iconstruct/features/project_creation/screens/project_tracking_screen.dart';

class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({
    super.key,
    this.forceHomeGuide = false,
    this.loadShops,
  });

  /// Replay the first-login tour even if it was already finished.
  final bool forceHomeGuide;

  /// Where the hardware shops come from. Tests pass their own; the app reads
  /// them from Firestore.
  final Future<List<RankedShop>> Function()? loadShops;

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  static const Color _cream = Color(0xFFEBE0CC);
  static const Color _darkBlue = Color(0xFF2C3E50);
  static const Color _midBlue = Color(0xFF648DB6);

  final GlobalKey _startEstimateKey = GlobalKey();
  final GlobalKey _postBiddingKey = GlobalKey();
  final GlobalKey _canvassKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

  bool _guideVisible = false;
  int _guideStep = 0;
  Rect? _guideHighlight;
  List<HomeGuideStep> _guideSteps = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStartGuide());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _maybeStartGuide() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (!widget.forceHomeGuide &&
        await OnboardingPreferences.hasSeenHomeGuide(uid)) {
      return;
    }
    if (!mounted) return;
    final firstName = context.read<UserProvider>().currentUser?.firstName;
    setState(() {
      _guideSteps = homeGuideSteps(firstName: firstName);
      _guideVisible = true;
      _guideStep = 0;
    });
    await _syncGuideHighlight();
  }

  Future<void> _syncGuideHighlight() async {
    if (!_guideVisible || _guideSteps.isEmpty) return;
    final target = _guideSteps[_guideStep].target;
    final key = switch (target) {
      HomeGuideTarget.welcome => null,
      HomeGuideTarget.startEstimate => _startEstimateKey,
      HomeGuideTarget.postBidding => _postBiddingKey,
      HomeGuideTarget.canvassTracking => _canvassKey,
      HomeGuideTarget.shopChat => null,
    };
    if (key?.currentContext != null) {
      await Scrollable.ensureVisible(
        key!.currentContext!,
        alignment: 0.28,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    }
    if (!mounted) return;
    setState(() => _guideHighlight = _rectFor(key));
  }

  Rect? _rectFor(GlobalKey? key) {
    final ctx = key?.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _finishGuide() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    await OnboardingPreferences.markHomeGuideSeen(uid);
    if (!mounted) return;
    setState(() {
      _guideVisible = false;
      _guideHighlight = null;
    });
  }

  Future<void> _nextGuideStep() async {
    if (_guideStep >= _guideSteps.length - 1) {
      await _finishGuide();
      return;
    }
    setState(() => _guideStep += 1);
    await _syncGuideHighlight();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_darkBlue, _midBlue],
                  stops: [0.3, 1.0],
                ),
              ),
            ),
          ),

          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 380,
              decoration: BoxDecoration(
                color: _cream,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(50),
                  bottomRight: Radius.circular(50),
                ),
              ),
            ),
          ),

          Positioned.fill(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.only(bottom: 120),
              child: Column(
                children: [
                  SafeArea(
                    bottom: false,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 15,
                          ),
                          child: Row(
                            children: [
                              UserAvatar(
                                size: 38,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const ProfileScreen(),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 10,
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: const [
                                Text(
                                  'Welcome to iConstruct!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 27,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF2C3E50),
                                    letterSpacing: -0.5,
                                    height: 1.2,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Where builders connect to smarter solutions.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13,
                                    fontStyle: FontStyle.italic,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF2C3E50),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),

                  _MainCard(
                    backgroundColor: _darkBlue,
                    cream: _cream,
                    startEstimateKey: _startEstimateKey,
                    postBiddingKey: _postBiddingKey,
                    canvassKey: _canvassKey,
                    onSeeLocations: () {},
                    onContinueLastEstimate: () {
                      PlanningNav.continueLastEstimate(context);
                    },
                    onStartNewRenovation: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HomeScreen(),
                        ),
                      );
                    },
                    onSavedProjects: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SavedProjectsScreen(
                            focus: SavedProjectsFocus.all,
                          ),
                        ),
                      );
                    },
                    onPostProject: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SavedProjectsScreen(
                            focus: SavedProjectsFocus.readyToPost,
                          ),
                        ),
                      );
                    },
                    onViewQuotations: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ProjectTrackingScreen(),
                        ),
                      );
                    },
                    onTopShops: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TopShopsScreen(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 28),
                  _HardwareShopsCard(loadShops: widget.loadShops),
                  const SizedBox(height: 24),
                  const _HomeFootnote(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          const OffsetPillNav(activeTab: OffsetNavTab.home),

          if (_guideVisible && _guideSteps.isNotEmpty)
            Positioned.fill(
              child: HomeGuideOverlay(
                steps: _guideSteps,
                stepIndex: _guideStep,
                highlight: _guideHighlight,
                onNext: _nextGuideStep,
                onSkip: _finishGuide,
              ),
            ),
        ],
      ),
    );
  }
}

class _MainCard extends StatelessWidget {
  final Color backgroundColor;
  final Color cream;
  final Key? startEstimateKey;
  final Key? postBiddingKey;
  final Key? canvassKey;
  final VoidCallback onSeeLocations;
  final VoidCallback onContinueLastEstimate;
  final VoidCallback onStartNewRenovation;
  final VoidCallback onSavedProjects;
  final VoidCallback onPostProject;
  final VoidCallback onViewQuotations;
  final VoidCallback onTopShops;

  const _MainCard({
    required this.backgroundColor,
    required this.cream,
    this.startEstimateKey,
    this.postBiddingKey,
    this.canvassKey,
    required this.onSeeLocations,
    required this.onContinueLastEstimate,
    required this.onStartNewRenovation,
    required this.onSavedProjects,
    required this.onPostProject,
    required this.onViewQuotations,
    required this.onTopShops,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // 330 on any phone wide enough for it; shrinks to fit on narrow screens
      // (e.g. 320 dp) instead of overflowing. Identical layout at >= 362 dp.
      width: (MediaQuery.sizeOf(context).width - 32).clamp(0.0, 330.0),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 28, 18, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What would you like to do?',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                    color: cream,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Start a new estimate, pick up the last one, or follow the '
                  'quotations shops send you.',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12.5,
                    height: 1.4,
                    color: cream.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _ActionTile(
            icon: Icons.play_circle_outline_rounded,
            title: 'Continue Last Estimate',
            subtitle: 'Pick up where you left off on your latest estimate.',
            onTap: onContinueLastEstimate,
          ),
          const SizedBox(height: 12),
          _ActionTile(
            icon: Icons.home_repair_service_outlined,
            title: 'Start New Estimate',
            subtitle:
                'Choose a room and the work to be done, then get a list of '
                'materials and quantities.',
            onTap: onStartNewRenovation,
            key: startEstimateKey,
          ),
          const SizedBox(height: 12),
          _ActionTile(
            icon: Icons.folder_open_outlined,
            title: 'My Projects',
            subtitle: 'Every estimate you have saved, in one place.',
            onTap: onSavedProjects,
          ),
          const SizedBox(height: 12),
          _ActionTile(
            icon: Icons.campaign_outlined,
            title: 'Post for Bidding',
            subtitle:
                'Send a finished material list to hardware shops and ask '
                'them for quotations.',
            onTap: onPostProject,
            key: postBiddingKey,
          ),
          const SizedBox(height: 12),
          _ActionTile(
            icon: Icons.timeline_outlined,
            title: 'Canvass Tracking',
            subtitle:
                'Follow incoming bids and compare quotations until you pick '
                'a shop.',
            onTap: onViewQuotations,
            key: canvassKey,
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const cream = Color(0xFFEBE0CC);

    return Semantics(
      button: true,
      label: title,
      hint: 'Opens $title',
      child: Material(
        color: cream.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          splashColor: cream.withValues(alpha: 0.22),
          highlightColor: cream.withValues(alpha: 0.12),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cream.withValues(alpha: 0.32)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 8, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: cream.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: cream, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                            color: cream,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12.5,
                            height: 1.4,
                            fontWeight: FontWeight.w400,
                            color: cream.withValues(alpha: 0.78),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: cream.withValues(alpha: 0.9),
                    size: 28,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// What the numbers on the home screen are and are not.
class _HomeFootnote extends StatelessWidget {
  const _HomeFootnote();

  @override
  Widget build(BuildContext context) {
    const cream = Color(0xFFEBE0CC);

    return SizedBox(
      width: (MediaQuery.sizeOf(context).width - 32).clamp(0.0, 330.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.verified_user_outlined,
            size: 18,
            color: cream.withValues(alpha: 0.85),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'iConstruct works out material quantities only. Every price you '
              'see comes from a quotation a hardware shop sends you, and '
              'payment is arranged directly with the shop.',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11.5,
                height: 1.45,
                color: cream.withValues(alpha: 0.85),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// First letter of a shop's name for the card medallion.
String _shopInitial(String name) {
  final trimmed = name.trim();
  return trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase();
}

/// The hardware shops on the home screen, three to a page so the screen
/// stays short to scroll.
///
/// It used to share the card with "How iConstruct Works" behind two tabs.
/// That section was taken off the home screen; the first-login tour, which
/// can be replayed from Profile, still walks through the steps.
class _HardwareShopsCard extends StatefulWidget {
  const _HardwareShopsCard({this.loadShops});

  final Future<List<RankedShop>> Function()? loadShops;

  @override
  State<_HardwareShopsCard> createState() => _HardwareShopsCardState();
}

class _HardwareShopsCardState extends State<_HardwareShopsCard> {
  static const Color _darkBlue = Color(0xFF2C3E50);
  static const Color _cream = Color(0xFFEBE0CC);

  /// Shops shown on one page.
  static const int shopsPerPage = 3;

  late final Future<List<RankedShop>> _shopsFuture =
      widget.loadShops?.call() ?? ShopRankingService().fetchRankedShops();

  int _page = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      // Same rule as _MainCard: 330 where it fits, shrinks on narrow phones.
      width: (MediaQuery.sizeOf(context).width - 32).clamp(0.0, 330.0),
      decoration: BoxDecoration(
        color: _darkBlue,
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
      // A last page with fewer shops is shorter; the card eases to it.
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.topCenter,
        child: _buildShops(context),
      ),
    );
  }

  Widget _buildShops(BuildContext context) {
    final noteStyle = TextStyle(
      fontFamily: 'Poppins',
      fontSize: 12,
      height: 1.4,
      color: _cream.withValues(alpha: 0.75),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Headed like "What would you like to do?" on the card above.
        const Text(
          'Hardware Shops',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 19,
            fontWeight: FontWeight.w700,
            height: 1.25,
            color: _cream,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Shops with the best ratings from builders come first. Tap a shop '
          'to see its storefront.',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12.5,
            height: 1.4,
            color: _cream.withValues(alpha: 0.75),
          ),
        ),
        const SizedBox(height: 18),
        FutureBuilder<List<RankedShop>>(
          future: _shopsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AppSkeletonCardList(
                count: shopsPerPage,
                scrollable: false,
                cardColor: Colors.white,
                cardRadius: 18,
                cardPadding: EdgeInsets.all(14),
                cardMargin: EdgeInsets.only(bottom: 12),
                padding: EdgeInsets.zero,
                leadingCircle: true,
                leadingSize: 34,
                textLines: 2,
              );
            }

            if (snapshot.hasError) {
              return Text('The shops could not be loaded.', style: noteStyle);
            }

            final shops = snapshot.data ?? const <RankedShop>[];
            if (shops.isEmpty) {
              return Text('No hardware shops are listed yet.',
                  style: noteStyle);
            }

            final pages = (shops.length + shopsPerPage - 1) ~/ shopsPerPage;
            final page = _page.clamp(0, pages - 1);
            final first = page * shopsPerPage;
            final last = (first + shopsPerPage).clamp(0, shops.length);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = first; i < last; i++)
                  _ShopRow(shop: shops[i], rank: i),
                if (pages > 1)
                  _pager(
                    page: page,
                    pages: pages,
                    first: first,
                    last: last,
                    total: shops.length,
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TopShopsScreen(),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: _cream,
                      minimumSize: const Size(48, 40),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'View all shops',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _pager({
    required int page,
    required int pages,
    required int first,
    required int last,
    required int total,
  }) {
    Widget arrow(IconData icon, String tooltip, VoidCallback? onPressed) {
      return IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon),
        color: _cream,
        disabledColor: _cream.withValues(alpha: 0.3),
        style: IconButton.styleFrom(
          side: BorderSide(
            color: _cream.withValues(alpha: onPressed == null ? 0.2 : 0.6),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          arrow(
            Icons.chevron_left_rounded,
            'Previous page',
            page > 0 ? () => setState(() => _page = page - 1) : null,
          ),
          Expanded(
            child: Text(
              'Page ${page + 1} of $pages\n'
              'Shops ${first + 1}–$last of $total',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11.5,
                height: 1.4,
                color: _cream.withValues(alpha: 0.85),
              ),
            ),
          ),
          arrow(
            Icons.chevron_right_rounded,
            'Next page',
            page < pages - 1 ? () => setState(() => _page = page + 1) : null,
          ),
        ],
      ),
    );
  }
}

/// One hardware shop on the home card. [rank] is its place in the whole
/// ranking, so the top three keep their mark on every page.
class _ShopRow extends StatelessWidget {
  final RankedShop shop;
  final int rank;

  const _ShopRow({required this.shop, required this.rank});

  @override
  Widget build(BuildContext context) {
    const darkBlue = Color(0xFF2C3E50);
    final isTop3 = rank < 3;

    return GestureDetector(
      onTap: () => showShopStorefrontSheet(context, shop),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isTop3 ? darkBlue : Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: Text(
                _shopInitial(shop.shopName),
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.bold,
                  color: isTop3 ? Colors.white : darkBlue,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shop.shopName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: darkBlue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${shop.address}, ${shop.barangay}, ${shop.city}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: darkBlue.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 5),
                  ShopRatingStars(
                    rating: shop.rating,
                    size: 13,
                    color: Colors.amber.shade700,
                    emptyColor: darkBlue.withValues(alpha: 0.25),
                    textColor: darkBlue,
                  ),
                  if (shop.subscriptionPlan != null &&
                      shop.subscriptionPlan!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Plan: ${shop.subscriptionPlan}',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${shop.quotationCount}',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: darkBlue.withValues(alpha: 0.75),
                  ),
                ),
                Text(
                  shop.quotationCount == 1 ? 'quote' : 'quotes',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    color: darkBlue.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: darkBlue.withValues(alpha: 0.5),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
