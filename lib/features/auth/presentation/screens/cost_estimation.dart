import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iconstruct/core/widgets/iconstruct_panel.dart';
import 'package:iconstruct/core/widgets/offset_panel_shell.dart';

import 'package:iconstruct/features/auth/presentation/screens/material_estimator.dart';
import 'package:iconstruct/features/project_creation/data/bom_quantity_estimator.dart';
import 'package:iconstruct/features/project_creation/data/material_visual.dart';
import 'package:iconstruct/features/project_creation/data/renovation_scope.dart';
import 'package:iconstruct/features/project_creation/data/renovation_templates.dart';
import 'package:iconstruct/features/project_creation/widgets/material_id_sheet.dart';
import 'package:iconstruct/features/project_creation/widgets/material_swatch.dart';
import 'package:iconstruct/core/widgets/app_message.dart';

class CostEstimationScreen extends StatefulWidget {
  final String projectName;
  final String? customProjectName;
  final String? projectNotes;

  /// The nationally-derived BOM this screen reviews. Always supplied: the
  /// template path and the AI path both build one before navigating here.
  final RenovationTemplate? template;

  /// Area used to scale template quantities (sqm).
  final double? projectAreaSqm;

  /// Renovation scope chosen on the area/scope screen. Persisted downstream so a
  /// reopened Extension estimate is not mistaken for a Full Renovation.
  final RenovationScope scope;

  /// Budget preference collected during AI consultation (Low / Medium / High).
  final String? budgetPreference;

  const CostEstimationScreen({
    super.key,
    required this.projectName,
    this.customProjectName,
    this.projectNotes,
    this.template,
    this.projectAreaSqm,
    this.scope = RenovationScope.fullRenovation,
    this.budgetPreference,
  });

  @override
  State<CostEstimationScreen> createState() => _CostEstimationScreenState();
}

class _CostEstimationScreenState extends State<CostEstimationScreen> {
  final ScrollController _materialsScrollController = ScrollController();

  final List<AddedPlumbingSelection> _selectedProducts =
      <AddedPlumbingSelection>[];

  /// Parallel template line items (supports type swap / alternatives).
  List<RenovationTemplateItem> _templateItems = [];

  @override
  void initState() {
    super.initState();

    final template = widget.template;
    if (template != null) _seedFromTemplate(template);
  }

  void _seedFromTemplate(RenovationTemplate template) {
    _templateItems = template.items
        .map(BomQuantityEstimator.ensureSwappable)
        .toList();
    _rebuildSelectionsFromTemplateItems();
  }

  void _rebuildSelectionsFromTemplateItems() {
    for (final old in _selectedProducts) {
      old.qtyController.dispose();
    }
    _selectedProducts
      ..clear()
      ..addAll(_templateItems.map(_selectionForItem));
  }

  AddedPlumbingSelection _selectionForItem(RenovationTemplateItem item) {
    final sel = AddedPlumbingSelection(
      categoryTitle: item.category,
      kind: 'Tap / drop to change type',
      materialName: item.name,
      size: item.size,
      unit: item.unit,
      quantity: item.defaultQuantity,
    );
    sel.qtyController.text = _formatQty(item.defaultQuantity);
    return sel;
  }

  static String _formatQty(double q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(1);

  /// Swap one line to an alternative type/size. Only this row is rebuilt — every
  /// other row keeps its (possibly hand-edited) quantity and controller — and
  /// the swapped row's quantity is recomputed for its new size instead of
  /// carrying the previous size's piece count.
  void _swapTemplateItem(int index, MaterialAlternative alternative) {
    if (index < 0 || index >= _templateItems.length) return;
    final current = _templateItems[index];
    final area = widget.projectAreaSqm ?? 1.0;

    var swapped = BomQuantityEstimator.ensureSwappable(
      current.copyWith(
        name: alternative.name,
        size: alternative.size ?? current.size,
      ),
    );
    final recomputed =
        BomQuantityEstimator.estimateQuantity(item: swapped, areaSqm: area);
    swapped = swapped.copyWith(defaultQuantity: recomputed);

    setState(() {
      _templateItems[index] = swapped;
      _selectedProducts[index].qtyController.dispose();
      _selectedProducts[index] = _selectionForItem(swapped);
    });
  }

  /// True only when there is at least one line and every line has a finite,
  /// strictly-positive quantity — a BOM with a `0` line would go to shops as a
  /// blank "—" row.
  bool get _allQuantitiesValid =>
      _selectedProducts.isNotEmpty &&
      _selectedProducts.every((s) => s.quantity.isFinite && s.quantity > 0);

  @override
  void dispose() {
    _materialsScrollController.dispose();
    for (final s in _selectedProducts) {
      s.qtyController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final templateName = widget.template?.name;
    final titleText = templateName != null && templateName.isNotEmpty
        ? templateName
        : (widget.projectName.contains('\n')
            ? widget.projectName
            : widget.projectName.replaceFirst(' ', '\n'));

    return OffsetPanelShell(
      activeNav: OffsetNavTab.estimate,
      panelColor: IConstructPanel.navy,
      header: OffsetPanelHeaders.avatarAndMenu(context),
      contentPadding:
          IConstructPanel.contentPaddingOf(context).copyWith(bottom: 20),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titleText,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          const Divider(color: Color(0xFFEDE4D4), thickness: 1),
          const SizedBox(height: 10),
          Text(
            widget.template?.id == 'ai_consultation_bom'
                ? 'Your AI material list — quantities scaled from area & scope.\nEdit a quantity or remove an item you don\'t need.'
                : 'Reference package — quantities scaled from area.\nEdit qty, remove items, or drag a type onto its matching material only.',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: const Color(0xFFE0D7C9),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFFEDE4D4), thickness: 1),
          const SizedBox(height: 12),
          Expanded(child: _buildTemplateBomBody(context)),
        ],
      ),
    );
  }

  Widget _buildTemplateBomBody(BuildContext context) {
    if (_templateItems.isEmpty || _selectedProducts.isEmpty) {
      return Align(
        alignment: Alignment.topLeft,
        child: Text(
          'All reference materials were removed.\nGo back and pick another template, or continue with AI.',
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: const Color(0xFFE0D7C9),
            height: 1.4,
          ),
        ),
      );
    }

    final areaLabel = widget.projectAreaSqm != null
        ? '${widget.projectAreaSqm!.toStringAsFixed(1)} sqm'
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (areaLabel != null) ...[
          Text(
            'Quantities auto-estimated for $areaLabel. Drag a type onto its own material only.',
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: const Color(0xFF8FB2D4),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
        ],
        Expanded(
          child: ListView.builder(
            controller: _materialsScrollController,
            itemCount: _templateItems.length,
            itemBuilder: (context, index) {
              final item = _templateItems[index];
              final selected = _selectedProducts[index];

              return Padding(
                key: ValueKey('bomrow_${selected.key}_$index'),
                padding: const EdgeInsets.only(bottom: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item.alternatives.isNotEmpty) ...[
                      Text(
                        'Available types',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFE0D7C9),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 36,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: item.alternatives.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(width: 8),
                          itemBuilder: (context, altIndex) {
                            final alt = item.alternatives[altIndex];
                            return Draggable<_SlotAlternative>(
                              data: _SlotAlternative(
                                slotIndex: index,
                                alternative: alt,
                              ),
                              feedback: Material(
                                color: Colors.transparent,
                                child: _AltChip(
                                  label: alt.name,
                                  dragging: true,
                                ),
                              ),
                              childWhenDragging: Opacity(
                                opacity: 0.35,
                                child: _AltChip(label: alt.name),
                              ),
                              child: GestureDetector(
                                onTap: () => _swapTemplateItem(index, alt),
                                child: _AltChip(
                                  label: alt.name,
                                  selected: alt.name == item.name,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    DragTarget<_SlotAlternative>(
                      onWillAcceptWithDetails: (details) =>
                          details.data.slotIndex == index &&
                          (item.isSwappable || item.alternatives.isNotEmpty),
                      onAcceptWithDetails: (details) {
                        _swapTemplateItem(index, details.data.alternative);
                      },
                      builder: (context, candidate, rejected) {
                        final hovering = candidate.isNotEmpty;
                        return Container(
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              bottomLeft: Radius.circular(16),
                            ),
                            border: hovering
                                ? Border.all(
                                    color: const Color(0xFF6EE7B7),
                                    width: 2,
                                  )
                                : rejected.isNotEmpty
                                    ? Border.all(
                                        color: const Color(0xFFFF8A80),
                                        width: 1.5,
                                      )
                                    : null,
                          ),
                          child: _AddedMaterialItem(
                            title: selected.materialName,
                            category: item.category,
                            subtitle: [
                              item.category,
                              if ((selected.size ?? item.size ?? '').trim().isNotEmpty)
                                (selected.size ?? item.size!).trim(),
                              selected.unit,
                            ].where((s) => s.isNotEmpty).join(' • '),
                            unit: selected.unit,
                            qtyController: selected.qtyController,
                            availableSizes: item.availableSizes,
                            selectedSize: selected.size ?? item.size,
                            formulaString: BomQuantityEstimator.getFormulaString(
                              item: item,
                              areaSqm: widget.projectAreaSqm ?? 1.0,
                              currentQty: selected.quantity,
                            ),
                            onSizeChanged: item.availableSizes.isEmpty
                                ? null
                                : (newSize) {
                                    if (newSize == null || newSize.isEmpty) return;
                                    final area = widget.projectAreaSqm ?? 1.0;
                                    final result = BomQuantityEstimator.recalculateForSize(
                                      item: item,
                                      newSize: newSize,
                                      areaSqm: area,
                                    );
                                    setState(() {
                                      selected.size = newSize;
                                      selected.quantity = result.newQty;
                                      selected.qtyController.text =
                                          result.newQty.toInt() == result.newQty
                                              ? result.newQty.toInt().toString()
                                              : result.newQty.toStringAsFixed(1);
                                      _templateItems[index] = item.copyWith(
                                        size: newSize,
                                        defaultQuantity: result.newQty,
                                      );

                                      // Also check and update linked items (e.g. tile grout)
                                      for (var i = 0; i < _templateItems.length; i++) {
                                        final linkedItem = _templateItems[i];
                                        final linkedSel = _selectedProducts[i];
                                        if (linkedItem.name.toLowerCase().contains('grout') ||
                                            linkedItem.name.toLowerCase().contains('adhesive')) {
                                          final linkedRes = BomQuantityEstimator.recalculateForSize(
                                            item: linkedItem,
                                            newSize: newSize,
                                            areaSqm: area,
                                          );
                                          linkedSel.quantity = linkedRes.newQty;
                                          linkedSel.qtyController.text =
                                              linkedRes.newQty.toInt() == linkedRes.newQty
                                                  ? linkedRes.newQty.toInt().toString()
                                                  : linkedRes.newQty.toStringAsFixed(1);
                                          _templateItems[i] = linkedItem.copyWith(
                                            defaultQuantity: linkedRes.newQty,
                                          );
                                        }
                                      }
                                    });
                                  },
                            onChanged: (val) {
                              final parsed = double.tryParse(val.trim());
                              final clean = (parsed != null &&
                                      parsed.isFinite &&
                                      parsed >= 0)
                                  ? parsed
                                  : 0.0;
                              setState(() {
                                selected.quantity = clean;
                                _templateItems[index] = item.copyWith(
                                  defaultQuantity: clean,
                                );
                              });
                            },
                            onRemove: () {
                              setState(() {
                                _templateItems.removeAt(index);
                                final removed =
                                    _selectedProducts.removeAt(index);
                                removed.qtyController.dispose();
                              });
                            },
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    const Divider(
                      color: Color(0xFFEDE4D4),
                      thickness: 1,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            onPressed: _allQuantitiesValid ? _goToEstimator : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEDE4D4),
              foregroundColor: const Color(0xFF1E3042),
              disabledBackgroundColor:
                  const Color(0xFFEDE4D4).withValues(alpha: 0.4),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              minimumSize: const Size(0, 40),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 6,
              shadowColor: Colors.black.withAlpha(100),
            ),
            child: Text(
              'Estimate Now',
              maxLines: 1,
              softWrap: false,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  void _goToEstimator() {
    if (_selectedProducts.isEmpty) {
      showAppMessage(context,
        const SnackBar(
          content: Text('Add or keep at least one material before estimating.'),
        ),
      );
      return;
    }
    if (!_allQuantitiesValid) {
      showAppMessage(
        context,
        const SnackBar(
          content: Text(
              'Every line needs a quantity greater than 0 before you can estimate.'),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MaterialEstimatorScreen(
          projectName: widget.projectName,
          customProjectName: widget.customProjectName,
          projectNotes: widget.projectNotes,
          tiles: const [],
          plumbingMaterials: _selectedProducts,
          aiProjectArea: widget.projectAreaSqm,
          aiBudget: widget.budgetPreference,
          scope: widget.scope,
          lockEstimateDetails: true,
        ),
      ),
    );
  }

}

class _SlotAlternative {
  final int slotIndex;
  final MaterialAlternative alternative;

  const _SlotAlternative({
    required this.slotIndex,
    required this.alternative,
  });
}

class _AltChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool dragging;

  const _AltChip({
    required this.label,
    this.selected = false,
    this.dragging = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: dragging || selected
            ? const Color(0xFFEDE4D4)
            : const Color(0xFFEDE4D4).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF648DB6).withValues(alpha: 0.7),
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: dragging || selected
              ? const Color(0xFF1E3042)
              : const Color(0xFFEDE4D4),
        ),
      ),
    );
  }
}

class _AddedMaterialItem extends StatefulWidget {
  final String title;
  final String subtitle;
  final TextEditingController qtyController;
  final String unit;
  final ValueChanged<String> onChanged;
  final VoidCallback onRemove;
  final List<String> availableSizes;
  final String? selectedSize;
  final ValueChanged<String?>? onSizeChanged;
  final String? formulaString;

  /// Category the item was classified under. Feeds the visual resolver so the
  /// swatch matches what the estimator actually costed.
  final String category;

  const _AddedMaterialItem({
    required this.title,
    required this.subtitle,
    required this.qtyController,
    required this.unit,
    required this.onChanged,
    required this.onRemove,
    this.availableSizes = const [],
    this.selectedSize,
    this.onSizeChanged,
    this.formulaString,
    this.category = '',
  });

  @override
  State<_AddedMaterialItem> createState() => _AddedMaterialItemState();
}

class _AddedMaterialItemState extends State<_AddedMaterialItem> {
  bool _showFormula = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3042),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFEDE4D4).withAlpha(80),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Visual identifier. Tapping it opens the full identification
              // card so the item can be matched against the shelf before it is
              // ordered.
              Semantics(
                button: true,
                label: 'Show what ${widget.title} looks like',
                child: Tooltip(
                  message: 'What does this look like?',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => showMaterialIdSheet(
                      context,
                      name: widget.title,
                      category: widget.category,
                      unit: widget.unit,
                      quantity:
                          double.tryParse(widget.qtyController.text.trim()) ?? 0,
                      size: widget.selectedSize,
                    ),
                    child: MaterialSwatch(
                      visual: MaterialVisual.forItem(
                        name: widget.title,
                        category: widget.category,
                        unit: widget.unit,
                      ),
                      size: widget.selectedSize,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.25,
                      ),
                    ),
                    if (widget.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: const Color(0xFFE0D7C9),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 8),

              Flexible(
                child: Container(
                  width: 120,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFEDE4D4).withAlpha(120),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: widget.qtyController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: widget.onChanged,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Qty',
                            hintStyle: TextStyle(
                              color: Colors.white38,
                              fontSize: 10,
                            ),
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          widget.unit,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: const Color(0xFFEDE4D4).withAlpha(180),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              IconButton(
                onPressed: widget.onRemove,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.only(left: 4),
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: const Icon(
                  Icons.close_rounded,
                  color: Color(0xFFEDE4D4),
                  size: 18,
                ),
              ),
            ],
          ),

          if (widget.availableSizes.isNotEmpty && widget.onSizeChanged != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Size / Spec:',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF8FB2D4),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C3E50),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFEDE4D4).withAlpha(60),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: widget.availableSizes.contains(widget.selectedSize)
                            ? widget.selectedSize
                            : widget.availableSizes.first,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF1E3042),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFEDE4D4),
                        ),
                        icon: const Icon(
                          Icons.arrow_drop_down,
                          color: Color(0xFFEDE4D4),
                          size: 18,
                        ),
                        items: widget.availableSizes.map((size) {
                          return DropdownMenuItem<String>(
                            value: size,
                            child: Text(
                              size,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: widget.onSizeChanged,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],

          if (widget.formulaString != null && widget.formulaString!.isNotEmpty) ...[
            const SizedBox(height: 6),
            InkWell(
              onTap: () => setState(() => _showFormula = !_showFormula),
              child: Row(
                children: [
                  Icon(
                    _showFormula ? Icons.info : Icons.info_outline,
                    size: 13,
                    color: const Color(0xFF8FB2D4),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _showFormula ? 'Hide Formula' : 'View Formula',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF8FB2D4),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
            if (_showFormula) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C3E50),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF8FB2D4).withAlpha(40),
                  ),
                ),
                child: Text(
                  widget.formulaString!,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: const Color(0xFFE0D7C9),
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class AddedTileSelection {
  final String tileTypeName;
  final String tileSizeGroup;
  final String tileSizeName;
  double quantity;
  final TextEditingController qtyController;

  AddedTileSelection({
    required this.tileTypeName,
    required this.tileSizeGroup,
    required this.tileSizeName,
    this.quantity = 0.0,
  }) : qtyController = TextEditingController(text: quantity.toString());

  String get key =>
      '${tileTypeName.trim()}|${tileSizeGroup.trim()}|${tileSizeName.trim()}';
}

class AddedPlumbingSelection {
  final String categoryTitle;
  final String kind;
  final String materialName;
  String? size;
  final String? length;
  final String? coverSize;
  final String unit;
  double quantity;
  final TextEditingController qtyController;

  AddedPlumbingSelection({
    required this.categoryTitle,
    required this.kind,
    required this.materialName,
    this.size,
    this.length,
    this.coverSize,
    this.unit = 'Qty.',
    this.quantity = 0.0,
  }) : qtyController = TextEditingController(text: quantity.toString());

  String get key =>
      '${categoryTitle.trim()}|${kind.trim()}|${materialName.trim()}|${(size ?? '').trim()}|${(length ?? '').trim()}|${(coverSize ?? '').trim()}';

  String get displayLabel {
    final parts = <String>[];

    final kindLabel = kind.trim();
    final s = (size ?? '').trim();
    final l = (length ?? '').trim();
    final c = (coverSize ?? '').trim();

    if (kindLabel.isNotEmpty) parts.add(kindLabel);
    if (s.isNotEmpty) parts.add(s);
    if (l.isNotEmpty) parts.add(l);
    if (c.isNotEmpty) parts.add(c);

    return parts.isEmpty
        ? materialName.trim()
        : '${materialName.trim()} • ${parts.join(' • ')}';
  }
}
