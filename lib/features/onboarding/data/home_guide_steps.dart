/// Targets on [MainHomeScreen] the first-login tour can spotlight.
///
/// [welcome] and [shopChat] resolve to no anchor, so steps using them are
/// shown without a spotlight. That is what lets the tour talk about things
/// that are not on the home screen without the home screen having to know.
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
/// Copy stays in the planning and canvassing phase: estimate materials,
/// request quotations, compare offers. It does not describe on-site
/// construction, and it does not promise anything the app cannot do.
///
/// Kept to five steps deliberately. Each capability that a builder would
/// otherwise never find is folded into the step where they would first meet
/// it, rather than given a step of its own, because a longer tour is a tour
/// people tap through.
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
          'iConstruct helps you plan materials and canvass hardware shops '
          'around CALABARZON — before you spend anything. Here is the path.',
      nextLabel: "Let's go",
    ),
    const HomeGuideStep(
      target: HomeGuideTarget.startEstimate,
      title: 'Start an estimate',
      body:
          'Name your project, then pick your scope: Full Renovation or '
          'Extension. Quantities scale from your floor area using Philippine '
          'construction standards. Tap any material to see what it looks like '
          'and exactly what to ask for at the counter.',
      nextLabel: 'Next',
    ),
    const HomeGuideStep(
      target: HomeGuideTarget.postBidding,
      title: 'Ask shops for prices',
      body:
          'When the list looks right, post it. Hardware shops quote you '
          'privately — each one sees your materials, never another shop\'s '
          'prices.',
      nextLabel: 'Next',
    ),
    const HomeGuideStep(
      target: HomeGuideTarget.canvassTracking,
      title: 'Compare and choose',
      body:
          'Offers arrive here to compare side by side. Take a whole quotation, '
          'or untick the lines you would rather buy elsewhere. Shop ratings '
          'come only from builders who actually bought from them.',
      nextLabel: 'Next',
    ),
    const HomeGuideStep(
      target: HomeGuideTarget.shopChat,
      title: 'Then message the shop',
      body:
          'Choosing a quotation opens a chat with that shop, and you can reach '
          'it any time from the Chat tab. Confirm materials, stock and pickup '
          'there. iConstruct never collects phone numbers and never handles '
          'payment.',
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
          'You and the hardware shop can message here once you have chosen '
          'their quotation. Sort out materials, quantities and pickup — '
          'nothing is paid inside the app.',
      nextLabel: 'Next',
    ),
    HomeGuideStep(
      target: HomeGuideTarget.shopChat,
      title: 'What to send',
      body:
          'Ask about quoted items, substitutes, and when you can collect. You '
          'can attach a photo of the wall or the delivery, or send a document. '
          'Never share passwords or arrange payment in here.',
      nextLabel: 'Next',
    ),
    HomeGuideStep(
      target: HomeGuideTarget.shopChat,
      title: 'Find it later',
      body:
          'Open the Chat tab in the bar at the bottom of the screen. Unread '
          'replies show a count on it, so you will know when a shop has '
          'answered.',
      nextLabel: 'Got it',
    ),
  ];
}
