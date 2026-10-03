import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iconstruct/core/theme/app_theme.dart';
import 'package:iconstruct/core/widgets/iconstruct_panel.dart';
import 'package:iconstruct/features/chat/data/chat_attachment_service.dart';

/// Shows a picked photo or document and asks before it goes to the shop.
///
/// Picking used to send at once, so a wrong tap in the gallery reached the
/// shop with no way back: messages cannot be edited or deleted once sent. The
/// sheet shows the photo itself, or the document's name and size, with the
/// caption that goes with it. What was already typed in the message box is
/// the starting caption.
///
/// Returns the caption to send, which may be empty, or null when the builder
/// backs out.
Future<String?> showAttachmentConfirmSheet(
  BuildContext context, {
  required PickedAttachment attachment,
  required String shopName,
  String caption = '',
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AttachmentConfirmSheet(
      attachment: attachment,
      shopName: shopName,
      caption: caption,
    ),
  );
}

class _AttachmentConfirmSheet extends StatefulWidget {
  final PickedAttachment attachment;
  final String shopName;
  final String caption;

  const _AttachmentConfirmSheet({
    required this.attachment,
    required this.shopName,
    required this.caption,
  });

  @override
  State<_AttachmentConfirmSheet> createState() =>
      _AttachmentConfirmSheetState();
}

class _AttachmentConfirmSheetState extends State<_AttachmentConfirmSheet> {
  late final _captionController = TextEditingController(text: widget.caption);

  bool get _isImage => widget.attachment.kind == AttachmentKind.image;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shop = widget.shopName.trim().isEmpty
        ? 'the shop'
        : widget.shopName.trim();

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
                    _isImage ? 'Send this photo?' : 'Send this document?',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'It goes to $shop and cannot be deleted once sent.',
                    style: GoogleFonts.poppins(
                      color: AppColors.cream.withValues(alpha: 0.82),
                      fontSize: 12.5,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _isImage ? _photoPreview(context) : _documentRow(),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _captionController,
                    scrollPadding: const EdgeInsets.fromLTRB(20, 24, 20, 96),
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    style: GoogleFonts.poppins(
                      color: AppColors.textDark,
                      fontSize: 13.5,
                      height: 1.4,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Add a caption (optional)',
                      hintStyle: GoogleFonts.poppins(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                      filled: true,
                      fillColor: AppColors.cream,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
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
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            Navigator.pop(context, _captionController.text),
                        icon: const Icon(Icons.send_rounded, size: 18),
                        label: Text(
                          'Send',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.cream,
                          foregroundColor: AppColors.navySoft,
                          elevation: 0,
                          minimumSize: const Size(0, 46),
                          shape: const StadiumBorder(),
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

  /// The photo as it will arrive, already downscaled at pick time.
  ///
  /// Capped in height so a tall portrait shot leaves the caption and the
  /// buttons on screen.
  Widget _photoPreview(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final decodeWidth = (screen.width * MediaQuery.devicePixelRatioOf(context))
        .round()
        .clamp(1, ChatAttachmentService.maxImageEdge.toInt());

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: screen.height * 0.4),
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.25),
          child: Image.memory(
            widget.attachment.bytes,
            fit: BoxFit.contain,
            width: double.infinity,
            cacheWidth: decodeWidth,
            gaplessPlayback: true,
            errorBuilder: (context, _, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
              child: Text(
                'No preview for ${widget.attachment.name}',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: AppColors.cream.withValues(alpha: 0.8),
                  fontSize: 12.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _documentRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cream.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.insert_drive_file_rounded,
            color: AppColors.cream,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.attachment.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  ChatAttachmentService.readableSize(
                    widget.attachment.sizeBytes,
                  ),
                  style: GoogleFonts.poppins(
                    color: AppColors.cream.withValues(alpha: 0.7),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
