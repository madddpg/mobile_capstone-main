import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iconstruct/core/theme/app_theme.dart';
import 'package:iconstruct/core/widgets/iconstruct_panel.dart';
import 'package:iconstruct/features/bidding/data/supplier_cancellation.dart';

/// Asks why a supplier selection is being cancelled.
///
/// A reason is required rather than optional: the shop is told this happened,
/// and "cancelled, no reason given" is how a shop stops trusting the app. The
/// sheet also says plainly what cancelling does, because it puts the other
/// shops' quotations back and cannot be done twice.
Future<CancelSelectionChoice?> showCancelSelectionSheet(
  BuildContext context, {
  required String shopName,
  required int otherQuotations,
}) {
  return showModalBottomSheet<CancelSelectionChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CancelSelectionSheet(
      shopName: shopName,
      otherQuotations: otherQuotations,
    ),
  );
}

class _CancelSelectionSheet extends StatefulWidget {
  final String shopName;
  final int otherQuotations;

  const _CancelSelectionSheet({
    required this.shopName,
    required this.otherQuotations,
  });

  @override
  State<_CancelSelectionSheet> createState() => _CancelSelectionSheetState();
}

class _CancelSelectionSheetState extends State<_CancelSelectionSheet> {
  CancelReason? _reason;
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final others = widget.otherQuotations;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: IConstructPanel.navy,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
                children: [
                  Text(
                    'Cancel ${widget.shopName}?',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    others == 0
                        ? 'The shop is told you cancelled, and your estimate goes '
                            'back to waiting for quotations. You can only do this once.'
                        : 'The shop is told you cancelled. Your estimate reopens '
                            'and the other $others quotation${others == 1 ? '' : 's'} '
                            'can be chosen again. You can only do this once.',
                    style: GoogleFonts.poppins(
                      color: AppColors.cream.withValues(alpha: 0.82),
                      fontSize: 12.5,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'WHY',
                    style: GoogleFonts.poppins(
                      color: AppColors.cream.withValues(alpha: 0.55),
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final reason in CancelReason.values)
                    _ReasonRow(
                      reason: reason,
                      selected: _reason == reason,
                      onTap: () => setState(() => _reason = reason),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _noteController,
                    minLines: 2,
                    maxLines: 4,
                    maxLength: 500,
                    textCapitalization: TextCapitalization.sentences,
                    style: GoogleFonts.poppins(
                      color: AppColors.navy,
                      fontSize: 13,
                      height: 1.4,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Anything to add? The shop sees this. (optional)',
                      hintMaxLines: 2,
                      hintStyle: GoogleFonts.poppins(
                        color: AppColors.navy.withValues(alpha: 0.45),
                        fontSize: 12.5,
                      ),
                      counterStyle: GoogleFonts.poppins(
                        color: AppColors.cream.withValues(alpha: 0.6),
                        fontSize: 10,
                      ),
                      filled: true,
                      fillColor: AppColors.cream,
                      contentPadding: const EdgeInsets.all(12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.cream,
                          side: BorderSide(
                            color: AppColors.cream.withValues(alpha: 0.45),
                          ),
                          minimumSize: const Size(0, 46),
                          shape: const StadiumBorder(),
                        ),
                        child: Text(
                          'Keep them',
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
                        onPressed: _reason == null
                            ? null
                            : () => Navigator.pop(
                                  context,
                                  CancelSelectionChoice(
                                    reason: _reason!,
                                    note: _noteController.text,
                                  ),
                                ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.danger,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              AppColors.danger.withValues(alpha: 0.35),
                          elevation: 0,
                          minimumSize: const Size(0, 46),
                          shape: const StadiumBorder(),
                        ),
                        child: Text(
                          'Cancel selection',
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

class _ReasonRow extends StatelessWidget {
  final CancelReason reason;
  final bool selected;
  final VoidCallback onTap;

  const _ReasonRow({
    required this.reason,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              // Drawn rather than a Radio: the Material one now wants a
              // RadioGroup ancestor, and this row is the group.
              Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  size: 20,
                  color: selected
                      ? AppColors.cream
                      : AppColors.cream.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  reason.label,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
