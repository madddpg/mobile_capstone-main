import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Padding Flutter's own caret reveal should leave around a focused field.
///
/// Kept modest when the screen's main button is pinned *outside* the scroll
/// view: a large bottom pad would shove the field away from that button.
const EdgeInsets kFieldScrollPadding = EdgeInsets.fromLTRB(20, 24, 20, 28);

/// Scrolls a focused text field into the nearest scrollable.
///
/// The subtree does not change when the keyboard opens, so the field keeps
/// focus. The field is only moved when it would sit past the end of the
/// viewport — just above a button pinned under this scroll view — and stays
/// put when it is already on screen.
class RevealFocusedField extends StatefulWidget {
  final Widget child;

  const RevealFocusedField({super.key, required this.child});

  @override
  State<RevealFocusedField> createState() => _RevealFocusedFieldState();
}

class _RevealFocusedFieldState extends State<RevealFocusedField>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FocusManager.instance.addListener(_scheduleReveal);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_scheduleReveal);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() => _scheduleReveal();

  void _scheduleReveal() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
  }

  void _reveal() {
    if (!mounted) return;
    final focus = FocusManager.instance.primaryFocus;
    final ctx = focus?.context;
    if (ctx == null || !ctx.mounted) return;
    if (ctx.findAncestorStateOfType<_RevealFocusedFieldState>() != this) {
      return;
    }
    final isField =
        ctx.widget is EditableText ||
        ctx.findAncestorWidgetOfExactType<EditableText>() != null;
    if (!isField) return;

    Scrollable.ensureVisible(
      ctx,
      alignment: 1.0,
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Scrollable form fields with the screen's main [action] pinned to the
/// bottom of the scaffold body.
///
/// [Scaffold.resizeToAvoidBottomInset] shrinks this column when the keyboard
/// opens, so [action] rises with the keyboard instead of sliding under it
/// or away from the field. [alignFieldsAboveAction] keeps a short form
/// sitting just above that button when there is spare room.
class KeyboardForm extends StatelessWidget {
  final Widget child;
  final Widget? action;
  final bool alignFieldsAboveAction;
  final EdgeInsetsGeometry padding;

  const KeyboardForm({
    super.key,
    required this.child,
    this.action,
    this.alignFieldsAboveAction = false,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: RevealFocusedField(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final pad = padding.resolve(Directionality.of(context));
                final minHeight = math.max(
                  0.0,
                  constraints.maxHeight - pad.vertical,
                );
                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: padding,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: minHeight),
                    child: Column(
                      mainAxisAlignment: alignFieldsAboveAction
                          ? MainAxisAlignment.end
                          : MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [child],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        if (action != null) ...[const SizedBox(height: 12), action!],
      ],
    );
  }
}
