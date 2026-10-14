import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iconstruct/core/theme/app_theme.dart';
import 'package:iconstruct/features/bidding/data/bidding_schedule.dart';

/// Reusable live banner displaying current bidding status and remaining time countdown.
///
/// Refreshes automatically every 30 seconds to ensure the countdown stays accurate.
class BiddingStatusBanner extends StatefulWidget {
  final BiddingSchedule schedule;
  final bool isOwner;
  final VoidCallback? onChangeDeadline;

  const BiddingStatusBanner({
    super.key,
    required this.schedule,
    this.isOwner = false,
    this.onChangeDeadline,
  });

  @override
  State<BiddingStatusBanner> createState() => _BiddingStatusBannerState();
}

class _BiddingStatusBannerState extends State<BiddingStatusBanner> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Periodic refresh for live countdown
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final status = BiddingSchedule.resolveStatus(
      startsAt: widget.schedule.startsAt,
      endsAt: widget.schedule.endsAt,
      storedStatus: widget.schedule.status.name,
      now: now,
    );

    final (:bg, :border, :iconColor, :textColor, :icon) = switch (status) {
      BiddingStatus.open => (
        bg: const Color(0xFFECFDF5),
        border: const Color(0xFFA7F3D0),
        iconColor: const Color(0xFF059669),
        textColor: const Color(0xFF065F46),
        icon: Icons.timer_outlined,
      ),
      BiddingStatus.scheduled => (
        bg: const Color(0xFFEFF6FF),
        border: const Color(0xFFBFDBFE),
        iconColor: const Color(0xFF2563EB),
        textColor: const Color(0xFF1E40AF),
        icon: Icons.calendar_month_outlined,
      ),
      BiddingStatus.closed => (
        bg: const Color(0xFFF3F4F6),
        border: const Color(0xFFE5E7EB),
        iconColor: const Color(0xFF6B7280),
        textColor: const Color(0xFF374151),
        icon: Icons.lock_clock_outlined,
      ),
    };

    final title = switch (status) {
      BiddingStatus.open => 'Bidding Open · ${widget.schedule.remainingTimeLabel(now)}',
      BiddingStatus.scheduled => 'Bidding Scheduled',
      BiddingStatus.closed => 'Bidding Closed',
    };

    final subtitle = switch (status) {
      BiddingStatus.open => 'Quotation deadline: ${BiddingSchedule.formatDateTime(widget.schedule.endsAt)}',
      BiddingStatus.scheduled => 'Opens: ${BiddingSchedule.formatDateTime(widget.schedule.startsAt)}',
      BiddingStatus.closed => 'Closed on ${BiddingSchedule.formatDateTime(widget.schedule.endsAt)}. Quotations submitted before the deadline remain valid.',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ),
              if (widget.isOwner &&
                  status != BiddingStatus.closed &&
                  widget.onChangeDeadline != null) ...[
                TextButton(
                  onPressed: widget.onChangeDeadline,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    foregroundColor: textColor,
                  ),
                  child: Text(
                    'Change Deadline',
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 3),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Text(
              subtitle,
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                color: textColor.withValues(alpha: 0.85),
                height: 1.35,
              ),
            ),
          ),
          if (widget.schedule.isDeadlineChanged) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Text(
                'Deadline was adjusted (${widget.schedule.deadlineChangeCount} ${widget.schedule.deadlineChangeCount == 1 ? 'extension' : 'extensions'}).',
                style: GoogleFonts.poppins(
                  fontSize: 10.5,
                  fontStyle: FontStyle.italic,
                  color: textColor.withValues(alpha: 0.75),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
