import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iconstruct/features/project_creation/screens/create_project_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  /// Same order as the original diamond map, plus extra house rooms below.
  static const List<String> _items = [
    'Bathroom\nRenovation',
    'Kitchen\nRenovation',
    'Floor\nRenovation',
    'Roof\nRepair',
    'Interior\nPainting',
    'Living Room\nRenovation',
    'Bedroom\nRenovation',
    'Laundry\nRenovation',
    'Dining Room\nRenovation',
    'Wall\nFinishing',
  ];

  final Set<String> _selected = {};
  final ScrollController _scrollController = ScrollController();
  late final AnimationController _hintPulse;
  late final AnimationController _enter;
  bool _showScrollHint = true;

  @override
  void initState() {
    super.initState();
    _hintPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final next = _scrollController.offset < 28;
    if (next != _showScrollHint) {
      setState(() => _showScrollHint = next);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _hintPulse.dispose();
    _enter.dispose();
    super.dispose();
  }

  void _toggle(String item) {
    setState(() {
      if (_selected.contains(item)) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..add(item);
      }
    });
  }

  void _submit() {
    if (_selected.isEmpty) return;

    final selected = _selected.first.replaceAll('\n', ' ');

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateProjectScreen(renovationType: selected),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _selected.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF2C3E50),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            // Soft multi-stop blend — no hard band mid-screen.
            stops: [0.0, 0.32, 0.58, 0.82, 1.0],
            colors: [
              Color(0xFF2C3E50),
              Color(0xFF31475C),
              Color(0xFF3E5F7E),
              Color(0xFF527AA0),
              Color(0xFF648DB6),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 72),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 28),
                    child: Text(
                      'Current project\nplans?',
                      style: TextStyle(
                        fontFamily: 'Bungee-Regular',
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFEDE4D4),
                        height: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Text(
                      'Tap a home area, then continue.',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFFEDE4D4).withValues(alpha: 0.72),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Stack(
                      children: [
                        SingleChildScrollView(
                          controller: _scrollController,
                          physics: const BouncingScrollPhysics(),
                          // Room for the blended Continue zone at the bottom.
                          padding: const EdgeInsets.only(bottom: 110),
                          child: _DiamondGrid(
                            items: _items,
                            selected: _selected,
                            onToggle: _toggle,
                            enter: _enter,
                          ),
                        ),
                        if (_showScrollHint)
                          Positioned(
                            left: 0,
                            right: 100,
                            bottom: 78,
                            child: FadeTransition(
                              opacity: Tween<double>(begin: 0.55, end: 1)
                                  .animate(
                                    CurvedAnimation(
                                      parent: _hintPulse,
                                      curve: Curves.easeInOut,
                                    ),
                                  ),
                              child: SlideTransition(
                                position:
                                    Tween<Offset>(
                                      begin: Offset.zero,
                                      end: const Offset(0, 0.16),
                                    ).animate(
                                      CurvedAnimation(
                                        parent: _hintPulse,
                                        curve: Curves.easeInOut,
                                      ),
                                    ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: const Color(
                                        0xFFEDE4D4,
                                      ).withValues(alpha: 0.95),
                                      size: 26,
                                    ),
                                    Text(
                                      'More rooms below',
                                      style: GoogleFonts.poppins(
                                        color: const Color(0xFFEDE4D4),
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              // Soft veil that ties the diamond field into the Continue button.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 150,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.35, 0.7, 1.0],
                        colors: [
                          const Color(0xFF527AA0).withValues(alpha: 0),
                          const Color(0xFF5A84AD).withValues(alpha: 0.35),
                          const Color(0xFF648DB6).withValues(alpha: 0.72),
                          const Color(0xFF648DB6).withValues(alpha: 0.92),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -50,
                bottom: 20,
                child: _buildSubmitButton(enabled: canSubmit),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton({required bool enabled}) {
    return SizedBox(
      width: 190,
      child: ElevatedButton(
        onPressed: enabled ? _submit : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFEDE4D4),
          foregroundColor: const Color(0xFF2B3A47),
          disabledBackgroundColor: const Color(
            0xFFEDE4D4,
          ).withValues(alpha: 0.45),
          disabledForegroundColor: const Color(
            0xFF2B3A47,
          ).withValues(alpha: 0.45),
          minimumSize: const Size(170, 46),
          shape: const StadiumBorder(),
          elevation: enabled ? 8 : 0,
          shadowColor: Colors.black.withAlpha(102),
        ),
        child: const Text(
          'Continue',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}

class _DiamondGrid extends StatelessWidget {
  final List<String> items;
  final Set<String> selected;
  final void Function(String) onToggle;
  final AnimationController enter;

  // Absolute (left, top, width, height) from the original design.
  // First 7 match the original file exactly; last 3 continue the same rhythm.
  static const _layout = [
    (261.91, 38.0, 126.0, 126.0), // Bathroom Renovation
    (10.94, 90.86, 126.0, 126.0), // Kitchen Renovation
    (150.24, 152.71, 126.0, 126.0), // Floor Renovation
    (70.00, 300.86, 126.0, 126.0), // Roof Repair
    (248.15, 240.14, 126.0, 126.0), // Interior Painting
    (220.67, 390.07, 126.0, 126.0), // Living Room Renovation
    (20.94, 450.36, 126.0, 126.0), // Bedroom Renovation
    (
      150.24,
      530.0,
      126.0,
      126.0,
    ), // Laundry Renovation (between Bedroom & Dining)
    (248.15, 620.0, 126.0, 126.0), // Dining Room Renovation
    (20.94, 650.0, 126.0, 126.0), // Wall Finishing (left)
  ];

  const _DiamondGrid({
    required this.items,
    required this.selected,
    required this.onToggle,
    required this.enter,
  });

  @override
  Widget build(BuildContext context) {
    final last = _layout[_layout.length - 1];
    final stackHeight = last.$2 + last.$4 + 40;
    final count = items.length;

    return SizedBox(
      height: stackHeight,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: List.generate(count, (i) {
          final (baseX, y, w, h) = _layout[i];
          // Original shift rules: Kitchen + Bedroom + Wall stay on left anchors;
          // Painting + Dining get the far-right edge offset.
          const double shiftX = 18.0;
          final double x;
          if (i == 1 || i == 6 || i == 9) {
            x = baseX;
          } else if (i == 4 || i == 8) {
            x = baseX + shiftX + 26.0;
          } else {
            x = baseX + shiftX;
          }

          final start = i / (count + 3);
          final end = (i + 2.4) / (count + 3);
          final animation = CurvedAnimation(
            parent: enter,
            curve: Interval(
              start.clamp(0.0, 1.0),
              end.clamp(0.0, 1.0),
              curve: Curves.easeOutCubic,
            ),
          );

          return Positioned(
            left: x,
            top: y,
            width: w,
            height: h,
            child: FadeTransition(
              opacity: animation,
              child: _DiamondButton(
                label: items[i],
                isSelected: selected.contains(items[i]),
                onTap: () => onToggle(items[i]),
                width: w,
                height: h,
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _DiamondButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final double width;
  final double height;

  const _DiamondButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    const double scale = 1.25;
    final double baseSquare = min(width, height) / sqrt2;
    final double squareSize = baseSquare * scale;
    final double outerSquareSize = squareSize + 18;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: isSelected ? 1.06 : 1.0,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        child: SizedBox(
          width: width,
          height: height,
          child: Center(
            child: Transform.rotate(
              angle: pi / 4,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: outerSquareSize,
                    height: outerSquareSize,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF000000), Color(0xE6EDE4D4)],
                        stops: [0.0, 0.78],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isSelected ? 0.55 : 1,
                          ),
                          blurRadius: isSelected ? 18 : 14,
                          offset: const Offset(4, 8),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: squareSize,
                    height: squareSize,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: isSelected
                          ? const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF5B85C4), Color(0xFF3A62A0)],
                            )
                          : const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFFEDE4D4), Color(0xFF707070)],
                              stops: [0.35, 1.0],
                            ),
                    ),
                    child: Transform.rotate(
                      angle: -pi / 4,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade900,
                              height: 1.4,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  offset: const Offset(1.2, 1.4),
                                  blurRadius: 3,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
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
