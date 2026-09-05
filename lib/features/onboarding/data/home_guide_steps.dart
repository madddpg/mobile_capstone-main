/// Targets on [MainHomeScreen] the first-login tour can spotlight.
enum HomeGuideTarget {
  welcome,
  startEstimate,
  postBidding,
  canvassTracking,
  shopChat,
}

class HomeGuideStep {
  final HomeGuideTarget target;
  final String title;
  final String body;
  final String nextLabel;

  const HomeGuideStep({
    required this.target,
    required this.title,
    required this.body,
    required this.nextLabel,
  });
}

/// Short, skippable tour shown after a builder's first login.
///
/// Copy stays in the planning / canvassing phase: estimate materials, request
/// quotations, compare bids. It does not describe on-site construction.
List<HomeGuideStep> homeGuideSteps({String? firstName}) {
  final trimmed = firstName?.trim() ?? '';
  final greet = trimmed.isNotEmpty && trimmed.toLowerCase() != 'user'
      ? 'Welcome, $trimmed.'
      : 'Welcome.';

  return [
    HomeGuideStep(
      target: HomeGuideTarget.welcome,
      title: greet,
      body:
          'iConstruct helps you plan materials and canvass hardware shops — before you buy. Here is the path.',
      nextLabel: "Let's go",
    ),
    const HomeGuideStep(
      target: HomeGuideTarget.startEstimate,
      title: 'Start an estimate',
      body:
          'Name your estimate, then select your renovation scope (Full Reno or Extension). Material quantities scale automatically per DPWH standards.',
      nextLabel: 'Next',
    ),
    const HomeGuideStep(
      target: HomeGuideTarget.postBidding,
      title: 'Ask shops for prices',
      body:
          'When the list looks right, request private quotations from hardware shops.',
      nextLabel: 'Next',
    ),
    const HomeGuideStep(
      target: HomeGuideTarget.canvassTracking,
      title: 'Compare and choose',
      body:
          'Watch offers come in, compare them side by side, and pick a supplier.',
      nextLabel: 'Next',
    ),
    const HomeGuideStep(
      target: HomeGuideTarget.shopChat,
      title: 'Then message the shop',
      body:
          'Selecting a quotation unlocks live chat. Use it to confirm materials, availability, and pickup. iConstruct does not collect phone numbers or process payment.',
      nextLabel: 'Got it',
    ),
  ];
}

/// First-time overlay on shop chat (after a quotation is accepted).
List<HomeGuideStep> chatGuideSteps() {
  return const [
    HomeGuideStep(
      target: HomeGuideTarget.shopChat,
      title: 'This is shop chat',
      body:
          'You and the hardware shop can message here after you select their quotation. Coordinate materials, quantities, and pickup — nothing is paid in the app.',
      nextLabel: 'Next',
    ),
    HomeGuideStep(
      target: HomeGuideTarget.shopChat,
      title: 'What to send',
      body:
          'Ask about quoted items, substitutes, and when you can pick up. Do not share passwords or arrange payment inside iConstruct.',
      nextLabel: 'Next',
    ),
    HomeGuideStep(
      target: HomeGuideTarget.shopChat,
      title: 'Find it later',
      body:
          'Open Shop messages from Profile, or Message shop on a posted estimate after a supplier is selected.',
      nextLabel: 'Got it',
    ),
  ];
}
