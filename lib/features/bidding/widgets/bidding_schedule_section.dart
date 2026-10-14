import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iconstruct/features/bidding/data/bidding_schedule.dart';

/// Reusable UI section for configuring the bidding schedule when reviewing and
/// posting a renovation project.
///
/// Designed to follow the iConstruct aesthetic and directly reflects the
/// visual specification with Opening Date, Quotation Deadline, Closing Time,
/// and live duration calculation.
class BiddingScheduleSection extends StatelessWidget {
  /// The currently selected bidding opening date & time.
  final DateTime openingDateTime;

  /// The currently selected quotation deadline date & time.
  final DateTime deadlineDateTime;

  /// Whether opening is configured to begin immediately on post.
  final bool openImmediately;

  /// Callback when the opening date & time changes.
  final ValueChanged<DateTime> onOpeningChanged;

  /// Callback when the deadline date & time changes.
  final ValueChanged<DateTime> onDeadlineChanged;

  /// Callback when the "Open Immediately" toggle changes.
  final ValueChanged<bool>? onOpenImmediatelyChanged;

  /// Whether inputs are editable or disabled (e.g. during submission).
  final bool enabled;

  /// Whether rendered on a dark background (like MaterialEstimator's Finalize card)
  /// or a light background (dialogs / sheets).
  final bool isDark;

  const BiddingScheduleSection({
    super.key,
    required this.openingDateTime,
    required this.deadlineDateTime,
    required this.onOpeningChanged,
    required this.onDeadlineChanged,
    this.openImmediately = true,
    this.onOpenImmediatelyChanged,
    this.enabled = true,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = isDark ? Colors.white : const Color(0xFF2C3E50);
    final subtitleColor = isDark
        ? const Color(0xFFEDE4D4).withValues(alpha: 0.8)
        : const Color(0xFF5A6E7E);
    final labelColor = isDark ? const Color(0xFFE0D7C9) : const Color(0xFF2C3E50);

    final validationError = BiddingSchedule.validateSchedule(
      startsAt: openingDateTime,
      endsAt: deadlineDateTime,
    );

    final duration = deadlineDateTime.difference(openingDateTime);
    final formattedDuration = BiddingSchedule.formatDuration(duration);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Title
        Text(
          'Bidding Schedule',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: titleColor,
          ),
        ),
        const SizedBox(height: 4),

        // Description
        Text(
          'Set how long hardware shops have to submit their quotations.',
          style: GoogleFonts.poppins(
            fontSize: 12.5,
            color: subtitleColor,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 16),

        // Field 1: Opening date
        _buildFieldLabel('Opening date', labelColor),
        _buildPickerCard(
          context: context,
          icon: Icons.calendar_today_outlined,
          valueText: openImmediately
              ? 'Today (Immediately)'
              : BiddingSchedule.formatDateCompact(openingDateTime),
          trailing: openImmediately ? 'Immediate' : null,
          onTap: enabled
              ? () => _pickOpeningDate(context)
              : null,
        ),
        const SizedBox(height: 12),

        // Field 2: Quotation deadline
        _buildFieldLabel('Quotation deadline', labelColor),
        _buildPickerCard(
          context: context,
          icon: Icons.calendar_today_outlined,
          valueText: BiddingSchedule.formatDateCompact(deadlineDateTime),
          onTap: enabled ? () => _pickDeadlineDate(context) : null,
        ),
        const SizedBox(height: 12),

        // Field 3: Closing time
        _buildFieldLabel('Closing time', labelColor),
        _buildPickerCard(
          context: context,
          icon: Icons.access_time_rounded,
          valueText: BiddingSchedule.formatTimeCompact(deadlineDateTime),
          onTap: enabled ? () => _pickClosingTime(context) : null,
        ),
        const SizedBox(height: 14),

        // Schedule summary card / dynamic duration
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFFEDE4D4).withValues(alpha: 0.08)
                : const Color(0xFF2C3E50).withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: validationError != null
                  ? Colors.redAccent.withValues(alpha: 0.8)
                  : (isDark
                      ? const Color(0xFFEDE4D4).withValues(alpha: 0.25)
                      : const Color(0xFF2C3E50).withValues(alpha: 0.15)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    validationError != null
                        ? Icons.error_outline_rounded
                        : Icons.schedule_rounded,
                    size: 16,
                    color: validationError != null
                        ? Colors.redAccent
                        : (isDark ? const Color(0xFFEDE4D4) : const Color(0xFF2C3E50)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bidding opens: ${BiddingSchedule.formatDateTime(openingDateTime)}',
                          style: GoogleFonts.poppins(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: isDark ? const Color(0xFFEDE4D4) : const Color(0xFF2C3E50),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Quotation deadline: ${BiddingSchedule.formatDateTime(deadlineDateTime)}',
                          style: GoogleFonts.poppins(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: isDark ? const Color(0xFFEDE4D4) : const Color(0xFF2C3E50),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Duration: $formattedDuration',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: validationError != null
                                ? Colors.redAccent
                                : (isDark ? Colors.white : const Color(0xFF1E3042)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (validationError != null) ...[
                const SizedBox(height: 8),
                Text(
                  validationError,
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFieldLabel(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }

  Widget _buildPickerCard({
    required BuildContext context,
    required IconData icon,
    required String valueText,
    String? trailing,
    VoidCallback? onTap,
  }) {
    final borderColor = isDark
        ? const Color(0xFFEDE4D4).withValues(alpha: onTap == null ? 0.35 : 0.8)
        : const Color(0xFF2C3E50).withValues(alpha: onTap == null ? 0.2 : 0.4);

    final textColor = isDark
        ? Colors.white.withValues(alpha: onTap == null ? 0.6 : 1.0)
        : const Color(0xFF2C3E50).withValues(alpha: onTap == null ? 0.6 : 1.0);

    final iconColor = isDark
        ? const Color(0xFFEDE4D4).withValues(alpha: 0.85)
        : const Color(0xFF2C3E50).withValues(alpha: 0.75);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFFEDE4D4).withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                valueText,
                style: GoogleFonts.poppins(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
            ),
            if (trailing != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFFEDE4D4).withValues(alpha: 0.15)
                      : const Color(0xFF2C3E50).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  trailing,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 20,
              color: iconColor,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickOpeningDate(BuildContext context) async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: openingDateTime.isBefore(now) ? now : openingDateTime,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
      helpText: 'SELECT BIDDING OPENING DATE',
      builder: (context, child) => _datePickerTheme(context, child),
    );

    if (pickedDate == null) return;

    final isToday = pickedDate.year == now.year &&
        pickedDate.month == now.month &&
        pickedDate.day == now.day;

    DateTime newOpening;
    if (isToday) {
      newOpening = DateTime(
        now.year,
        now.month,
        now.day,
        now.hour,
        now.minute,
      );
      onOpenImmediatelyChanged?.call(true);
    } else {
      newOpening = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        9, // Default to 9:00 AM on future start dates
        0,
      );
      onOpenImmediatelyChanged?.call(false);
    }

    onOpeningChanged(newOpening);

    // If deadline is before or too close to new opening, adjust deadline forward
    if (deadlineDateTime.isBefore(newOpening.add(const Duration(hours: 24)))) {
      final adjustedDeadline = DateTime(
        newOpening.year,
        newOpening.month,
        newOpening.day + 3,
        17, // 5:00 PM
        0,
      );
      onDeadlineChanged(adjustedDeadline);
    }
  }

  Future<void> _pickDeadlineDate(BuildContext context) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: deadlineDateTime.isBefore(openingDateTime)
          ? openingDateTime.add(const Duration(days: 3))
          : deadlineDateTime,
      firstDate: openingDateTime,
      lastDate: openingDateTime.add(const Duration(days: 60)),
      helpText: 'SELECT QUOTATION DEADLINE',
      builder: (context, child) => _datePickerTheme(context, child),
    );

    if (pickedDate == null) return;

    final newDeadline = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      deadlineDateTime.hour,
      deadlineDateTime.minute,
    );

    onDeadlineChanged(newDeadline);
  }

  Future<void> _pickClosingTime(BuildContext context) async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: deadlineDateTime.hour,
        minute: deadlineDateTime.minute,
      ),
      helpText: 'SELECT CLOSING TIME',
      builder: (context, child) => _datePickerTheme(context, child),
    );

    if (pickedTime == null) return;

    final newDeadline = DateTime(
      deadlineDateTime.year,
      deadlineDateTime.month,
      deadlineDateTime.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    onDeadlineChanged(newDeadline);
  }

  Widget _datePickerTheme(BuildContext context, Widget? child) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF2C3E50),
          onPrimary: Color(0xFFEDE4D4),
          surface: Color(0xFFEDE4D4),
          onSurface: Color(0xFF2C3E50),
        ),
      ),
      child: child ?? const SizedBox.shrink(),
    );
  }
}
