import 'package:flutter/material.dart';

import 'package:iconstruct/features/bidding/screens/bidding_hub_screen.dart';

/// Hammer tab: open the posted project display (canvassing), not a new plan.
void handleHammerTap(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => const BiddingHubScreen()),
  );
}
