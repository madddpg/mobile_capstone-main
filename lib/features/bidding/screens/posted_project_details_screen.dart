import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconstruct/core/widgets/iconstruct_panel.dart';
import 'package:iconstruct/core/widgets/offset_pill_nav.dart';
import 'package:iconstruct/core/navigation/planning_nav.dart';
import 'package:iconstruct/features/chat/data/chat_service.dart';
import 'package:iconstruct/features/chat/screens/chat_inbox_screen.dart';
import 'package:iconstruct/features/chat/screens/chat_thread_screen.dart';
import 'quotations_screen.dart';

class PostedProjectDetailsScreen extends StatelessWidget {
  final String postId;

  const PostedProjectDetailsScreen({super.key, required this.postId});

  // Official Theme Colors
  static const Color creamBg = Color(0xFFEDE4D4);
  static const Color navyCard = Color(0xFF2C3E50);
  static const Color textLight = Color(0xFFE0D7C9);
  static const Color blueGradientTop = Color(0xFF2C3E50);
  static const Color blueGradientBottom = Color(0xFF648DB6);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: blueGradientBottom,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('projectPosts')
            .doc(postId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [blueGradientTop, blueGradientBottom],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: const Center(
                child: CircularProgressIndicator(color: creamBg),
              ),
            );
          }

          if (!snapshot.data!.exists) {
            return const Center(child: Text("Project not found."));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final String projectName = data['projectName'] ?? 'Untitled Project';
          final String projectType = data['projectType'] ?? 'N/A';
          final num totalArea = data['totalAreaSqm'] ?? 0;
          final String budget = data['budget'] ?? 'N/A';
          final int quoteCount = data['quotationCount'] ?? 0;
          final selectedShopId = (data['selectedShopId'] ?? '').toString();
          final selectedShopName = (data['selectedShopName'] ?? '').toString();
          final selectedQuotationId =
              (data['selectedQuotationId'] ?? '').toString();
          final hasSelectedShop = selectedShopId.isNotEmpty;

          return Stack(
            children: [
              // --- BACKGROUND GRADIENT ---
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [blueGradientTop, blueGradientBottom],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),

              // --- TOP CREAM SHAPE (With curved left side matching your design) ---
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: MediaQuery.of(context).size.height * 0.45,
                child: Container(
                  decoration: const BoxDecoration(
                    color: creamBg,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(60),
                    ),
                  ),
                ),
              ),

              // --- CONTENT LAYER ---
              SafeArea(
                child: Stack(
                  children: [
                    // --- BACK BUTTON ---
                    Positioned(
                      top: 10,
                      left: 20,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: navyCard,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),

                    // --- MAIN FLOATING CARD PANEL ---
                    Positioned(
                      top: 90,
                      right: 0,
                      // Shares the offset-panel gutter so this screen stays in
                      // step with the shell-based screens.
                      left: IConstructPanel.leftInsetOf(context),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(28, 36, 24, 30),
                        decoration: const BoxDecoration(
                          color: navyCard,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(55),
                            bottomLeft: Radius.circular(55),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 15,
                              offset: Offset(-5, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              projectName,
                              style: GoogleFonts.poppins(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Divider(color: Colors.white30, thickness: 1),
                            const SizedBox(height: 20),

                            Text(
                              "Project Details",
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: creamBg,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 8),

                            _buildDetailText("Project Type: $projectType"),
                            const SizedBox(height: 4),
                            _buildDetailText(
                              "Project Area: ${totalArea.toStringAsFixed(2)}",
                            ),
                            const SizedBox(height: 4),
                            _buildDetailText("Budget: $budget"),
                            const SizedBox(height: 28),

                            const Divider(color: Colors.white30, thickness: 1),
                            const SizedBox(height: 20),

                            // Quotations Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Quotations Received",
                                  style: GoogleFonts.poppins(
                                    color: textLight,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                Text(
                                  quoteCount == 0
                                      ? "0 bids"
                                      : (quoteCount == 1
                                            ? "1 bids"
                                            : "$quoteCount bids"), // Match Mockup exactly ("1 bids")
                                  style: GoogleFonts.poppins(
                                    color: creamBg,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 36),

                            // Bottom Right Button
                            Align(
                              alignment: Alignment.centerRight,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: creamBg,
                                  foregroundColor: navyCard,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 10,
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => QuotationsScreen(
                                        postId: postId,
                                        projectName: projectName,
                                      ),
                                    ),
                                  );
                                },
                                child: Text(
                                  "View Quotations",
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            if (hasSelectedShop) ...[
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: creamBg,
                                    foregroundColor: navyCard,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 10,
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ChatThreadScreen(
                                          conversationId:
                                              ChatService.conversationId(
                                            postId,
                                            selectedShopId,
                                          ),
                                          shopName: selectedShopName.isEmpty
                                              ? null
                                              : selectedShopName,
                                          postId: postId,
                                          shopId: selectedShopId,
                                          quotationId:
                                              selectedQuotationId.isEmpty
                                              ? selectedShopId
                                              : selectedQuotationId,
                                          projectTitle: projectName,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    'Message shop',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const ChatInboxScreen(),
                                    ),
                                  );
                                },
                                child: Text(
                                  'Shop messages',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: creamBg,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () =>
                                    PlanningNav.startNewEstimate(context),
                                child: Text(
                                  'Start a new estimate',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: creamBg,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const OffsetPillNav(activeTab: OffsetNavTab.bidding),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDetailText(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        color: textLight,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
    );
  }
}
