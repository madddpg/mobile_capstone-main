import 'package:flutter/material.dart';

import 'package:iconstruct/core/navigation/app_nav.dart';
import 'package:iconstruct/features/bidding/screens/bidding_hub_screen.dart';

/// Hammer tab: open the posted project display (canvassing), not a new plan.
Future<void> handleHammerTap(BuildContext context) {
  return AppNav.openTab(context, (_) => const BiddingHubScreen());
}
