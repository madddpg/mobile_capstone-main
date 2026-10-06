import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iconstruct/core/navigation/progress_guard.dart';
import 'package:iconstruct/core/widgets/iconstruct_panel.dart';
import 'package:iconstruct/core/widgets/offset_panel_shell.dart';

import 'package:iconstruct/features/auth/presentation/screens/material_estimator.dart';
import 'package:iconstruct/features/project_creation/data/bom_quantity_estimator.dart';
import 'package:iconstruct/features/project_creation/data/bom_sections.dart';
import 'package:iconstruct/features/project_creation/data/excluded_work.dart';
import 'package:iconstruct/features/project_creation/data/functional_counts.dart';
import 'package:iconstruct/features/project_creation/data/material_visual.dart';
import 'package:iconstruct/features/project_creation/data/renovation_coverage.dart';
import 'package:iconstruct/features/project_creation/data/renovation_scope.dart';
import 'package:iconstruct/features/project_creation/data/renovation_templates.dart';
import 'package:iconstruct/features/project_creation/data/site_details.dart';
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

  /// How much of the space the job covers. Recorded with the estimate and the
  /// post; it never goes into projectScope, which carries the renovation type.
  final RenovationCoverage coverage;

  /// Every kind of work chosen, of which [scope] is the heaviest. Null from a
  /// caller that predates multi-select, which then means [scope] alone.
  final RenovationTypes? renovationTypes;

  RenovationTypes get types => renovationTypes ?? RenovationTypes.only(scope);

  /// Budget preference collected during AI consultation (Low / Medium / High).
  final String? budgetPreference;

  /// The measured room, when there is one. Quantities, swaps and formulas are
  /// all sized from it, and the list is grouped into floor, walls and the rest.
  final SiteTakeoff? takeoff;

  /// For a functional room, how many outlets, switches and lights the builder
  /// asked for. Wiring, conduit and device quantities are sized from this
  /// rather than from the room's floor area.
  final FunctionalCounts? counts;

  const CostEstimationScreen({
    super.key,
    required this.projectName,
    this.customProjectName,
    this.projectNotes,
    this.template,
    this.projectAreaSqm,
    this.scope = RenovationScope.cosmetic,
    this.coverage = RenovationCoverage.full,
    this.renovationTypes,
    this.budgetPreference,
    this.takeoff,
    this.counts,
  });

  @override
  State<CostEstimationScreen> createState() => _CostEstimationScreenState();
}

class _CostEstimationScreenState extends State<CostEstimationScreen> {
  final ScrollController _materialsScrollController = ScrollController();

  final List<AddedPlumbingSelection> _selectedProducts =
      <AddedPlumbingSelection>[];

  /// Parallel template line items. Each line keeps the type the template chose.
  List<RenovationTemplateItem> _templateItems = [];

  /// Lines the builder took out, newest first, kept whole so any of them can
  /// be put back exactly as it was. They travel with the estimate so the shop
  /// is told what is deliberately not being asked for.
  final List<RenovationTemplateItem> _excludedItems = [];

  /// Rows whose quantity the builder typed in. A recalculation that would
  /// replace one of these asks first; rows still on their computed quantity
  /// are simply re-sized.
  final Set<AddedPlumbingSelection> _typedQty = Set.identity();

  /// Type swaps and size changes made on this screen.
  int _swaps = 0;

  /// Whether the builder changed the list at all since it was built.
  bool _edited = false;

  /// Work of the job's kinds the builder left unticked, named as work: "Tile
  /// the walls" tells a shop more than a missing wall-tile line does. These
  /// cannot be put back here; the work is chosen on the checklist.
  late final List<ExcludedWork> _workLeftOut = () {
    final template = widget.template;
    if (template == null || !template.isFromWorkItems) {
      return const <ExcludedWork>[];
    }
    final catalogue =
        RenovationTemplatesCatalog.workCatalogueFor(template.renovationType);
    return [
      for (final item in catalogue.leftOut(template.workItemIds.toSet()))
        ExcludedWork(name: item.label, category: 'Work'),
    ];
  }();

  List<ExcludedWork> get _excludedWork => [
        ..._workLeftOut,
        for (final item in _excludedItems)
          ExcludedWork(
            name: item.name,
            category: item.category,
            unit: item.unit,
            size: item.size,
            quantity: item.defaultQuantity,
          ),
      ];

  @override
  void initState() {
    super.initState();

    final template = widget.template;
    if (template != null) _seedFromTemplate(template);
  }

  void _seedFromTemplate(RenovationTemplate template) {
    // Keep the type the template already chose. Available-type chips are not
    // attached to this list.
    final items = [
      for (final item in template.items)
        item.copyWith(isSwappable: false, alternatives: const []),
    ];
    // A measured room's list reads the way the job is walked: floor, walls,
    // tile setting, then what goes in the room.
    _templateItems = widget.takeoff == null ? items : sortBySection(items);
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
      kind: '',
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

  /// Lines whose typed quantity would be replaced if row [index] became
  /// [replacement], each saying what was typed and what it becomes.
  List<String> _typedLinesReplacedBy(
    int index,
    RenovationTemplateItem replacement,
  ) {
    var next = List.of(_templateItems)..[index] = replacement;
    if (BomQuantityEstimator.affectsTileSetting(replacement)) {
      next = BomQuantityEstimator.requantifyTileSetting(
        next,
        widget.projectAreaSqm ?? 1.0,
        takeoff: widget.takeoff,
      );
    }
    final lines = <String>[];
    for (var i = 0; i < next.length && i < _selectedProducts.length; i++) {
      final selection = _selectedProducts[i];
      if (!_typedQty.contains(selection)) continue;
      if (i != index && identical(next[i], _templateItems[i])) continue;
      final item = next[i];
      if (item.defaultQuantity == selection.quantity &&
          item.unit == selection.unit) {
        continue;
      }
      final typed = _formatQty(selection.quantity);
      final becomes = '${_formatQty(item.defaultQuantity)} ${item.unit}';
      lines.add(
        item.name == selection.materialName
            ? '${selection.materialName}: your $typed becomes $becomes'
            : '${selection.materialName} (you typed $typed) becomes $becomes '
                  'of ${item.name}',
      );
    }
    return lines;
  }

  /// Asks before a type or size change re-sizes quantities the builder typed.
  /// True when nothing typed is affected or the builder agreed.
  Future<bool> _confirmRecalculation({
    required String change,
    required int index,
    required RenovationTemplateItem replacement,
  }) {
    final lines = _typedLinesReplacedBy(index, replacement);
    if (lines.isEmpty) return Future.value(true);
    return confirmLeaveWarning(
      context,
      LeaveWarning(
        title: 'Recalculate quantities you typed?',
        message:
            '$change re-sizes ${lines.length == 1 ? 'this line' : 'these lines'} '
            'from your measurements, replacing the quantity you entered by '
            'hand:\n\n${lines.map((l) => '• $l').join('\n')}',
        keeps:
            'Every other line keeps its quantity. You can type a new '
            'quantity again afterwards.',
        confirmLabel: 'Recalculate',
        cancelLabel: 'Keep my quantities',
      ),
    );
  }

  /// What going back to the measurements would undo, or null when the list
  /// is still exactly as it was built.
  LeaveWarning? _backWarning() {
    if (!_edited) return const LeaveWarning.exitEstimate();
    String count(int n, String one, String many) => '$n ${n == 1 ? one : many}';
    final parts = [
      if (_typedQty.isNotEmpty)
        count(_typedQty.length, 'quantity you typed', 'quantities you typed'),
      if (_swaps > 0)
        count(_swaps, 'size change', 'size changes'),
      if (_excludedItems.isNotEmpty)
        count(_excludedItems.length, 'removed item', 'removed items'),
    ];
    final what = parts.isEmpty
        ? 'the changes you made to this list'
        : parts.length == 1
        ? parts.single
        : '${parts.sublist(0, parts.length - 1).join(', ')} and ${parts.last}';
    return LeaveWarning(
      title: 'Undo your material list edits?',
      message:
          'Going back to the measurements undoes $what. When you '
          'continue again, the list is rebuilt from the measurements, so a '
          'new area or room size re-scales every quantity.',
      keeps: 'Your measurements are kept, so you can adjust them and continue.',
      confirmLabel: 'Go back',
      cancelLabel: 'Keep my edits',
    );
  }

  /// Re-sizes the adhesive and grout lines after the tiles they serve change,
  /// so a new tile face or a removed wall-tile line shows up in both at once.
  /// Call inside setState.
  void _resyncTileSetting() {
    final settled = BomQuantityEstimator.requantifyTileSetting(
      _templateItems,
      widget.projectAreaSqm ?? 1.0,
      takeoff: widget.takeoff,
    );
    for (var i = 0; i < settled.length; i++) {
      final next = settled[i];
      if (identical(next, _templateItems[i])) continue;
      _templateItems[i] = next;

      final selection = _selectedProducts[i];
      _typedQty.remove(selection);
      if (next.unit != selection.unit) {
        selection.qtyController.dispose();
        _selectedProducts[i] = _selectionForItem(next);
      } else {
        selection.quantity = next.defaultQuantity;
        selection.qtyController.text = _formatQty(next.defaultQuantity);
      }
    }
  }

  /// The lines the builder took out, with a way to put each one back.
  ///
  /// Shown under the list rather than hidden behind a link: a shop is going to
  /// be told about these, so the builder should be able to see exactly what
  /// they are saying no to before they post.
  Widget _buildExcludedPanel() {
    final excluded = _excludedWork;
    if (excluded.isEmpty) return const SizedBox.shrink();
    final firstMaterial = _workLeftOut.length;

    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFEDE4D4).withValues(alpha: 0.45)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Not included (${excluded.length})',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFEDE4D4),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Sent with your request so shops quote the list above and '
              'nothing else.',
              style: GoogleFonts.poppins(
                fontSize: 10.5,
                color: const Color(0xFFE0D7C9).withValues(alpha: 0.75),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < excluded.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        excluded[i].label,
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          color: const Color(0xFFE0D7C9),
                          height: 1.35,
                        ),
                      ),
                    ),
                    if (i >= firstMaterial) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => _restoreExcluded(i - firstMaterial),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFEDE4D4),
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          minimumSize: const Size(0, 36),
                        ),
                        child: Text(
                          'Put back',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Puts an excluded line back, at the end of the list so every other row
  /// keeps the quantity the builder may have typed into it.
  void _restoreExcluded(int index) {
    if (index < 0 || index >= _excludedItems.length) return;
    setState(() {
      _edited = true;
      final item = _excludedItems.removeAt(index);
      _templateItems.add(item);
      _selectedProducts.add(_selectionForItem(item));
      if (BomQuantityEstimator.affectsTileSetting(item)) {
        _resyncTileSetting();
      }
    });
  }

  /// Whether row [index] opens a new section. Only a measured room's list is
  /// grouped; any other list keeps its template's order.
  bool _startsSection(int index) {
    if (widget.takeoff == null) return false;
    if (index == 0) return true;
    return bomSectionOf(_templateItems[index - 1]) !=
        bomSectionOf(_templateItems[index]);
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

    return ProgressGuard(
      onBack: _backWarning,
      onExit: () => const LeaveWarning.exitEstimate(),
      child: OffsetPanelShell(
        activeNav: OffsetNavTab.estimate,
        panelColor: IConstructPanel.navy,
        header: OffsetPanelHeaders.backAndAvatar(context),
        contentPadding: IConstructPanel.contentPaddingOf(context)
            .copyWith(bottom: 20),
        body: _buildTemplateBomBody(context, titleText),
      ),
    );
  }

  /// Title, instructions and notes shown above the material rows.
  Widget _buildBomHeader(BuildContext context, String titleText) {
    final hasRows = _templateItems.isNotEmpty && _selectedProducts.isNotEmpty;
    final areaLabel = widget.projectAreaSqm != null
        ? '${widget.projectAreaSqm!.toStringAsFixed(1)} sqm'
        : null;

    return Column(
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
        if (hasRows && widget.takeoff != null) ...[
          Text(
            'Measured room: ${widget.takeoff!.summary}. Every quantity is sized '
            'from these measurements; open View Formula on a line to see how.',
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: const Color(0xFF8FB2D4),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
        ] else if (hasRows && areaLabel != null) ...[
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
        // An AI BOM holds only what the builder picked, so the package this
        // note describes was never added to it.
        if (hasRows &&
            widget.types.includesStructural &&
            widget.template?.id != 'ai_consultation_bom') ...[
          Text(
            BomQuantityEstimator.structuralNoteFor(widget.takeoff),
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: const Color(0xFFFFC98A),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildTemplateBomBody(BuildContext context, String titleText) {
    // The header scrolls with the rows. Pinned above them, it filled the panel
    // on a small phone with large text and left the materials no room at all.
    final header = _buildBomHeader(context, titleText);

    if (_templateItems.isEmpty || _selectedProducts.isEmpty) {
      return ListView(
        children: [
          header,
          Text(
            'All reference materials were removed.\nGo back and pick another template, or continue with AI.',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: const Color(0xFFE0D7C9),
              height: 1.4,
            ),
          ),
          // Without this the builder who removed everything has nothing to put
          // back, and the only way out is to start the estimate again.
          _buildExcludedPanel(),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ListView.builder(
            controller: _materialsScrollController,
            itemCount: _templateItems.length + 2,
            itemBuilder: (context, listIndex) {
              if (listIndex == 0) return header;
              if (listIndex == _templateItems.length + 1) {
                return _buildExcludedPanel();
              }
              final index = listIndex - 1;
              final item = _templateItems[index];
              final selected = _selectedProducts[index];

              return Padding(
                key: ValueKey('bomrow_${selected.key}_$index'),
                padding: const EdgeInsets.only(bottom: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_startsSection(index))
                      _SectionLabel(bomSectionOf(item).label),
                    _AddedMaterialItem(
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
                              bom: _templateItems,
                              takeoff: widget.takeoff,
                              counts: widget.counts,
                            ),
                            onSizeChanged: item.availableSizes.isEmpty
                                ? null
                                : (newSize) async {
                                    if (newSize == null || newSize.isEmpty) return;
                                    final result = BomQuantityEstimator.recalculateForSize(
                                      item: item,
                                      newSize: newSize,
                                      areaSqm: widget.projectAreaSqm ?? 1.0,
                                      takeoff: widget.takeoff,
                                      counts: widget.counts,
                                    );
                                    final proceed = await _confirmRecalculation(
                                      change: 'Changing the size to $newSize',
                                      index: index,
                                      replacement: item.copyWith(
                                        size: newSize,
                                        defaultQuantity: result.newQty,
                                      ),
                                    );
                                    if (!proceed || !mounted) return;
                                    if (index >= _selectedProducts.length ||
                                        !identical(
                                          _selectedProducts[index],
                                          selected,
                                        )) {
                                      return;
                                    }
                                    setState(() {
                                      _edited = true;
                                      _swaps++;
                                      _typedQty.remove(selected);
                                      selected.size = newSize;
                                      selected.quantity = result.newQty;
                                      selected.qtyController.text =
                                          _formatQty(result.newQty);
                                      _templateItems[index] = item.copyWith(
                                        size: newSize,
                                        defaultQuantity: result.newQty,
                                      );
                                      if (BomQuantityEstimator.affectsTileSetting(item)) {
                                        _resyncTileSetting();
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
                                _edited = true;
                                _typedQty.add(selected);
                                selected.quantity = clean;
                                _templateItems[index] = item.copyWith(
                                  defaultQuantity: clean,
                                );
                              });
                            },
                            onRemove: () {
                              setState(() {
                                _edited = true;
                                final dropped = _templateItems.removeAt(index);
                                final removed =
                                    _selectedProducts.removeAt(index);
                                // Keep the quantity the builder is looking at,
                                // not the template's, so the excluded line says
                                // what it would actually have cost them.
                                _excludedItems.insert(
                                  0,
                                  dropped.copyWith(
                                    defaultQuantity: removed.quantity,
                                  ),
                                );
                                _typedQty.remove(removed);
                                removed.qtyController.dispose();
                                if (BomQuantityEstimator.affectsTileSetting(item)) {
                                  _resyncTileSetting();
                                }
                              });
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
          siteDetails: _siteDetailsMap(),
          excludedWork: _excludedWork,
          coverage: widget.coverage,
          renovationTypes: widget.types,
        ),
      ),
    );
  }

  /// What gets saved with the estimate and the post: the measured room, plus
  /// the device counts for a functional room, so reopening a draft or reading
  /// the post shows what the quantities were actually sized from.
  Map<String, dynamic>? _siteDetailsMap() {
    final details = widget.takeoff?.details.toMap();
    final counts = widget.counts;
    if (details == null && counts == null) return null;
    return {
      ...?details,
      if (counts != null && !counts.isEmpty) 'functionalCounts': counts.toMap(),
    };
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 10),
        child: Text(
          label.toUpperCase(),
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: const Color(0xFFFFC98A),
          ),
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
                          scrollPadding: const EdgeInsets.fromLTRB(
                            20,
                            24,
                            20,
                            96,
                          ),
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
