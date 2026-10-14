import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iconstruct/core/theme/app_theme.dart';
import 'package:iconstruct/core/widgets/app_message.dart';
import 'package:iconstruct/core/widgets/iconstruct_panel.dart';
import 'package:iconstruct/features/bidding/data/bidding_deadline_service.dart';
import 'package:iconstruct/features/bidding/data/bidding_schedule.dart';

/// Modal bottom sheet allowing a homeowner to extend or adjust the quotation deadline.
class ChangeDeadlineSheet extends StatefulWidget {
  final String postId;
  final String projectName;
  final BiddingSchedule schedule;

  const ChangeDeadlineSheet({
    super.key,
    required this.postId,
    required this.projectName,
    required this.schedule,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String postId,
    required String projectName,
    required BiddingSchedule schedule,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeDeadlineSheet(
        postId: postId,
        projectName: projectName,
        schedule: schedule,
      ),
    );
  }

  @override
  State<ChangeDeadlineSheet> createState() => _ChangeDeadlineSheetState();
}

class _ChangeDeadlineSheetState extends State<ChangeDeadlineSheet> {
  late DateTime _newDeadline;
  String _selectedReason = 'Need more quotations';
  final TextEditingController _noteController = TextEditingController();
  bool _busy = false;

  static const List<String> _reasonOptions = [
    'Need more quotations',
    'Scope clarification / material update',
    'Extension requested by supplier',
    'Project timeline adjusted',
    'Other reason',
  ];

  @override
  void initState() {
    super.initState();
    // Default proposed deadline: 2 days after current deadline, 5:00 PM
    _newDeadline = DateTime(
      widget.schedule.endsAt.year,
      widget.schedule.endsAt.month,
      widget.schedule.endsAt.day + 2,
      17,
      0,
    );
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickNewDate() async {
    final now = DateTime.now();
    final initialDate = _newDeadline.isBefore(now)
        ? now.add(const Duration(days: 1))
        : _newDeadline;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
      helpText: 'SELECT NEW DEADLINE DATE',
    );

    if (pickedDate == null || !mounted) return;

    setState(() {
      _newDeadline = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        _newDeadline.hour,
        _newDeadline.minute,
      );
    });
  }

  Future<void> _pickNewTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _newDeadline.hour,
        minute: _newDeadline.minute,
      ),
      helpText: 'SELECT NEW CLOSING TIME',
    );

    if (pickedTime == null || !mounted) return;

    setState(() {
      _newDeadline = DateTime(
        _newDeadline.year,
        _newDeadline.month,
        _newDeadline.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _submitChange() async {
    final validationError = BiddingSchedule.validateDeadlineChange(
      currentEndsAt: widget.schedule.endsAt,
      newEndsAt: _newDeadline,
      startsAt: widget.schedule.startsAt,
    );

    if (validationError != null) {
      showAppMessage(
        context,
        SnackBar(content: Text(validationError)),
      );
      return;
    }

    setState(() => _busy = true);

    try {
      await BiddingDeadlineService.instance.changeDeadline(
        postId: widget.postId,
        newDeadline: _newDeadline,
        reason: _selectedReason,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );

      if (!mounted) return;
      Navigator.pop(context, true);
      showAppMessage(
        context,
        const SnackBar(
          content: Text(
            'Quotation deadline updated. Participating shops have been notified.',
          ),
        ),
        kind: AppMessageKind.success,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showAppMessage(
        context,
        SnackBar(
          content: Text(
            e.toString().replaceFirst(RegExp(r'^Exception: '), ''),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final validationError = BiddingSchedule.validateDeadlineChange(
      currentEndsAt: widget.schedule.endsAt,
      newEndsAt: _newDeadline,
      startsAt: widget.schedule.startsAt,
    );

    final isExtension = _newDeadline.isAfter(widget.schedule.endsAt);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: const BoxDecoration(
          color: IConstructPanel.navy,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 14),
              decoration: BoxDecoration(
                color: AppColors.cream.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(4),
              ),
            ),

            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
                children: [
                  // Title
                  Text(
                    'Change Quotation Deadline',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Extend or modify when hardware shops must submit their quotations.',
                    style: GoogleFonts.poppins(
                      color: AppColors.cream.withValues(alpha: 0.8),
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Current Deadline Info Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.cream.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.event_available_rounded,
                          color: AppColors.cream,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CURRENT DEADLINE',
                                style: GoogleFonts.poppins(
                                  color: AppColors.cream.withValues(alpha: 0.6),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                BiddingSchedule.formatDateTime(
                                  widget.schedule.endsAt,
                                ),
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // New Deadline Inputs
                  Text(
                    'NEW DEADLINE',
                    style: GoogleFonts.poppins(
                      color: AppColors.cream.withValues(alpha: 0.6),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      // Date Picker
                      Expanded(
                        flex: 6,
                        child: InkWell(
                          onTap: _pickNewDate,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: AppColors.cream.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppColors.cream.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today_outlined,
                                  size: 16,
                                  color: AppColors.cream,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    BiddingSchedule.formatDateCompact(
                                      _newDeadline,
                                    ),
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 18,
                                  color: AppColors.cream,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Time Picker
                      Expanded(
                        flex: 5,
                        child: InkWell(
                          onTap: _pickNewTime,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: AppColors.cream.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppColors.cream.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.access_time_rounded,
                                  size: 16,
                                  color: AppColors.cream,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    BiddingSchedule.formatTimeCompact(
                                      _newDeadline,
                                    ),
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 18,
                                  color: AppColors.cream,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Difference Pill
                  Row(
                    children: [
                      Icon(
                        isExtension
                            ? Icons.trending_up_rounded
                            : Icons.warning_amber_rounded,
                        size: 14,
                        color: isExtension ? AppColors.success : AppColors.warning,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isExtension
                            ? 'Extending by ${BiddingSchedule.formatDuration(_newDeadline.difference(widget.schedule.endsAt))}'
                            : 'Shortening by ${BiddingSchedule.formatDuration(widget.schedule.endsAt.difference(_newDeadline))}',
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: isExtension ? AppColors.success : AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Reason Dropdown
                  Text(
                    'REASON FOR CHANGE',
                    style: GoogleFonts.poppins(
                      color: AppColors.cream.withValues(alpha: 0.6),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.cream.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.cream.withValues(alpha: 0.35),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedReason,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF2C3E50),
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppColors.cream,
                        ),
                        items: _reasonOptions.map((reason) {
                          return DropdownMenuItem<String>(
                            value: reason,
                            child: Text(
                              reason,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedReason = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Note Field
                  TextField(
                    controller: _noteController,
                    minLines: 2,
                    maxLines: 3,
                    maxLength: 200,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Additional details for hardware shops (optional)',
                      hintStyle: GoogleFonts.poppins(
                        color: AppColors.cream.withValues(alpha: 0.4),
                        fontSize: 12.5,
                      ),
                      counterStyle: GoogleFonts.poppins(
                        color: AppColors.cream.withValues(alpha: 0.5),
                        fontSize: 10,
                      ),
                      filled: true,
                      fillColor: AppColors.cream.withValues(alpha: 0.08),
                      contentPadding: const EdgeInsets.all(12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: AppColors.cream.withValues(alpha: 0.35),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: AppColors.cream.withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                  ),

                  // Validation Error
                  if (validationError != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.redAccent.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 16,
                            color: Colors.redAccent,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              validationError,
                              style: GoogleFonts.poppins(
                                color: Colors.redAccent,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Prior Notice Policy Note
                  const SizedBox(height: 8),
                  Text(
                    'Policy: A 24-hour notice policy applies when shortening deadlines to protect participating shops. All participating hardware shops will receive immediate notification of this change.',
                    style: GoogleFonts.poppins(
                      color: AppColors.cream.withValues(alpha: 0.55),
                      fontSize: 10.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),

            // Action Buttons
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.cream,
                          side: BorderSide(
                            color: AppColors.cream.withValues(alpha: 0.45),
                          ),
                          minimumSize: const Size(0, 46),
                          shape: const StadiumBorder(),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: (_busy || validationError != null)
                            ? null
                            : _submitChange,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.cream,
                          foregroundColor: IConstructPanel.navy,
                          disabledBackgroundColor:
                              AppColors.cream.withValues(alpha: 0.35),
                          elevation: 0,
                          minimumSize: const Size(0, 46),
                          shape: const StadiumBorder(),
                        ),
                        child: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: IConstructPanel.navy,
                                ),
                              )
                            : Text(
                                'Update Deadline',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
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
    );
  }
}
