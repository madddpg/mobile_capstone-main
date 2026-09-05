import 'package:flutter/material.dart';
import 'package:iconstruct/features/auth/presentation/models/ranked_shop.dart';
import 'package:iconstruct/features/auth/presentation/services/shop_ranking_service.dart';

class TopShopsScreen extends StatefulWidget {
  const TopShopsScreen({super.key});

  @override
  State<TopShopsScreen> createState() => _TopShopsScreenState();
}

class _TopShopsScreenState extends State<TopShopsScreen> {
  final ShopRankingService _rankingService = ShopRankingService();
  late Future<List<RankedShop>> _shopsFuture;

  @override
  void initState() {
    super.initState();
    _shopsFuture = _rankingService.fetchRankedShops();
  }

  @override
  Widget build(BuildContext context) {
    const cream = Color(0xFFEBE0CC);
    const darkBlue = Color(0xFF2C3E50);

    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        title: const Text(
          'Top Hardware Shops',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700,
            color: darkBlue,
          ),
        ),
        backgroundColor: cream,
        elevation: 0,
        iconTheme: const IconThemeData(color: darkBlue),
      ),
      body: FutureBuilder<List<RankedShop>>(
        future: _shopsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: darkBlue),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading shops.',
                style: TextStyle(color: darkBlue.withValues(alpha: 0.8)),
              ),
            );
          }

          final shops = snapshot.data;
          if (shops == null || shops.isEmpty) {
            return Center(
              child: Text(
                'No available shops.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  color: darkBlue.withValues(alpha: 0.8),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: shops.length,
            itemBuilder: (context, index) {
              final shop = shops[index];
              final isTop3 = index < 3 && shop.quotationCount > 0;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
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
                    // Rank Indicator
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isTop3 ? darkBlue : Colors.grey.shade200,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.bold,
                          color: isTop3 ? Colors.white : darkBlue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Shop details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shop.shopName,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: darkBlue,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${shop.address}, ${shop.barangay}, ${shop.city}',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: darkBlue.withValues(alpha: 0.7),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (shop.subscriptionPlan != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Plan: ${shop.subscriptionPlan}',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Quotation count
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${shop.quotationCount}',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: darkBlue,
                          ),
                        ),
                        Text(
                          'quotes',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            color: darkBlue.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
