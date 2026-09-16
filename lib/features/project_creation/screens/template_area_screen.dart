import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iconstruct/core/widgets/app_message.dart';
import 'package:iconstruct/features/auth/presentation/screens/cost_estimation.dart';
import 'package:iconstruct/features/project_creation/data/bom_quantity_estimator.dart';
import 'package:iconstruct/features/project_creation/data/renovation_scope.dart';
import 'package:iconstruct/features/project_creation/data/renovation_templates.dart';
import 'package:iconstruct/features/project_creation/data/site_details.dart';
import 'package:iconstruct/features/project_creation/widgets/glitched_flow_shell.dart';

/// After a template is chosen, collect what its quantities are sized from.
///
/// A room renovation asks for the room: its size, ceiling height, doors,
/// windows and how far up the walls the tiles go. Floor, wall and paint
/// quantities each come from their own measured surface. Roofing, electrical
/// and plumbing are not sized from a room and keep a single area.
class TemplateAreaScreen extends StatefulWidget {
  final RenovationTemplate template;
  final String projectName;
  final String? customProjectName;
  final String? projectNotes;

  const TemplateAreaScreen({
    super.key,
    required this.template,
    required this.projectName,
    this.customProjectName,
    this.projectNotes,
  });

  @override
  State<TemplateAreaScreen> createState() => _TemplateAreaScreenState();
}

double? _parseMetres(String text) {
  final value = double.tryParse(text.trim().replaceAll(',', '.'));
  return value != null && value.isFinite ? value : null;
}

/// Door and window sizes a builder can enter without measuring each one.
const List<String> _doorUses = ['bathroom', 'room', 'main door'];
const List<String> _windowUses = ['bathroom vent', 'small', 'standard', 'wide'];

/// How many openings of one size the room has. A preset size is fixed; a
/// custom size is typed in.
class _OpeningCount {
  final Opening? preset;
  final String use;
  final TextEditingController? widthController;
  final TextEditingController? heightController;
  int count;

  _OpeningCount.preset(Opening this.preset, this.use, this.count)
      : widthController = null,
        heightController = null;

  _OpeningCount.custom()
      : preset = null,
        use = '',
        count = 1,
        widthController = TextEditingController(),
        heightController = TextEditingController();

  static bool _sensible(double? metres) =>
      metres != null && metres >= 0.3 && metres <= 3.0;

  /// A custom size with a count but no usable width or height.
  bool get isIncomplete =>
      preset == null &&
      count > 0 &&
      !(_sensible(_parseMetres(widthController!.text)) &&
          _sensible(_parseMetres(heightController!.text)));

  Opening? get opening {
    if (count <= 0) return null;
    final size = preset;
    if (size != null) return size.copyWith(count: count);
    if (isIncomplete) return null;
    return Opening(
      widthM: _parseMetres(widthController!.text)!,
      heightM: _parseMetres(heightController!.text)!,
      count: count,
    );
  }

  void dispose() {
    widthController?.dispose();
    heightController?.dispose();
  }
}

class _TemplateAreaScreenState extends State<TemplateAreaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _areaController = TextEditingController();
  final _lengthController = TextEditingController();
  final _widthController = TextEditingController();
  final _counterController = TextEditingController();
  late final TextEditingController _heightController;

  late final RoomJob? _job = roomJobFor(widget.template.renovationType);
  late final List<_OpeningCount> _doors;
  late final List<_OpeningCount> _windows;
  WallTileHeight _wallTiles = WallTileHeight.none;
  bool _removeOldTiles = false;
  bool _paintCeiling = false;
  RenovationScope _selectedScope = RenovationScope.fullRenovation;

  @override
  void initState() {
    super.initState();
    final job = _job;
    final defaults = job == null ? null : SiteDetails.defaultsFor(job);

    int countOf(List<Opening>? openings, Opening size) => (openings ?? const [])
        .where((o) => o.sameSize(size))
        .fold(0, (sum, o) => sum + o.count);

    _heightController = TextEditingController(
      text: defaults?.heightM.toStringAsFixed(1) ?? '',
    );
    _doors = [
      for (var i = 0; i < kDoorSizes.length; i++)
        _OpeningCount.preset(
            kDoorSizes[i], _doorUses[i], countOf(defaults?.doors, kDoorSizes[i])),
    ];
    _windows = [
      for (var i = 0; i < kWindowSizes.length; i++)
        _OpeningCount.preset(kWindowSizes[i], _windowUses[i],
            countOf(defaults?.windows, kWindowSizes[i])),
    ];
    _wallTiles = defaults?.wallTileHeight ?? WallTileHeight.none;
    _removeOldTiles = defaults?.removeOldTiles ?? false;
    _paintCeiling = defaults?.paintCeiling ?? false;
  }

  @override
  void dispose() {
    _areaController.dispose();
    _lengthController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _counterController.dispose();
    for (final row in [..._doors, ..._windows]) {
      row.dispose();
    }
    super.dispose();
  }

  /// The room as currently entered, or `null` for work sized from an area.
  SiteDetails? get _details {
    final job = _job;
    if (job == null) return null;
    List<Opening> openings(List<_OpeningCount> rows) =>
        rows.map((r) => r.opening).whereType<Opening>().toList();

    return SiteDetails(
      job: job,
      lengthM: _parseMetres(_lengthController.text) ?? 0,
      widthM: _parseMetres(_widthController.text) ?? 0,
      heightM: job.hasWalls
          ? _parseMetres(_heightController.text) ?? 0
          : job.typicalHeightM,
      doors: openings(_doors),
      windows: job.hasWalls ? openings(_windows) : const [],
      wallTileHeight: job.offersWallTiles ? _wallTiles : WallTileHeight.none,
      counterLengthM: job == RoomJob.kitchen
          ? _parseMetres(_counterController.text) ?? 0
          : 0,
      removeOldTiles: job.hasFloor && _removeOldTiles,
      paintCeiling: job.hasWalls && _paintCeiling,
    );
  }

  List<String> _problems(SiteDetails details) => [
        ...details.problems(),
        if ([..._doors, ..._windows].any((row) => row.isIncomplete))
          'Enter the width and height of each custom door or window size, '
              'between 0.30 and 3.00 m.',
      ];

  void _continue() {
    FocusScope.of(context).unfocus();
    final details = _details;
    if (details == null) {
      if (!_formKey.currentState!.validate()) return;
      final area = double.tryParse(_areaController.text.trim());
      if (area == null || !area.isFinite || area <= 0) return;
      _openEstimate(area, null);
      return;
    }

    final problems = _problems(details);
    if (problems.isNotEmpty) {
      showAppMessage(context, SnackBar(content: Text(problems.first)));
      return;
    }
    final takeoff = SiteTakeoff.from(details);
    _openEstimate(takeoff.floorSqm, takeoff);
  }

  void _openEstimate(double area, SiteTakeoff? takeoff) {
    final scaledItems = BomQuantityEstimator.scaleTemplate(
      template: widget.template,
      areaSqm: area,
      scope: _selectedScope,
      takeoff: takeoff,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CostEstimationScreen(
          projectName: widget.projectName,
          customProjectName: widget.customProjectName,
          projectNotes: widget.projectNotes,
          template: widget.template.copyWithItems(scaledItems),
          projectAreaSqm: area,
          scope: _selectedScope,
          takeoff: takeoff,
        ),
      ),
    );
  }

  void _showHowEstimationWorksDialog() {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E3042),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(Icons.calculate_outlined, color: Color(0xFFEDE4D4)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'How Estimation Works',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildGuideCard(
                  title: '1. Measure the room',
                  body:
                      'Floor tiles are sized from length × width. Wall tiles and paint are sized from the walls, which are the room\'s perimeter × ceiling height, less its doors and windows. Roofing, electrical and plumbing use a single area.',
                  icon: Icons.straighten_rounded,
                ),
                const SizedBox(height: 10),
                _buildGuideCard(
                  title: '2. DPWH National Standards',
                  body:
                      'Material specifications follow DPWH Blue Book Vol. III; quantity rates follow Max Fajardo\'s construction tables.',
                  icon: Icons.verified_outlined,
                ),
                const SizedBox(height: 10),
                _buildGuideCard(
                  title: '3. Renovation Scope',
                  body:
                      '• Full Renovation: Redo finishes (tiles, paint, fixtures & screed cement/sand).\n• Extension: Adds slab concrete, CHB walls, rebar & formwork. Footings, columns, beams and roof come from the structural plan.',
                  icon: Icons.tune_outlined,
                ),
                const SizedBox(height: 10),
                _buildGuideCard(
                  title: '4. Sizes & waste',
                  body:
                      'Change a material\'s size in the BOM review and its piece count, grout and adhesive update. Tiles carry 8% cutting waste; spacers, tape and roller sets are added where the job needs them.',
                  icon: Icons.aspect_ratio_outlined,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Got it',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFEDE4D4),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGuideCard({
    required String title,
    required String body,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2C3E50),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEDE4D4).withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF8FB2D4)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFEDE4D4),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: const Color(0xFFE0D7C9),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final job = _job;
    return GlitchedFlowShell(
      title: job == null ? 'Project\nArea & Scope' : 'Site\nDetails',
      subtitle: widget.template.name,
      instruction: job == null
          ? 'Select scope & total area (sqm). Quantities auto-estimate per Philippine DPWH national standards.'
          : 'Measure the room first. Floor, wall and paint quantities are each sized from what you enter here.',
      trailingAction: GlitchedPillButton(
        label: 'Estimate Qty',
        width: 168,
        onPressed: _continue,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.only(right: 4, bottom: 24),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            ..._buildScopeSection(),
            const SizedBox(height: 18),
            if (job == null) ..._buildAreaSection() else ..._buildRoomSection(job),
            const SizedBox(height: 18),
            _buildStandardsNote(),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: GlitchedFlowShell.cream,
      ),
    );
  }

  List<Widget> _buildScopeSection() {
    return [
      Row(
        children: [
          // Expanded so the label gives way to the help link on a narrow
          // screen instead of pushing it past the panel edge.
          Expanded(child: _label('Renovation Scope *')),
          const SizedBox(width: 8),
          InkWell(
            onTap: _showHowEstimationWorksDialog,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.help_outline_rounded,
                  size: 14,
                  color: Color(0xFF8FB2D4),
                ),
                const SizedBox(width: 4),
                Text(
                  'How it works',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF8FB2D4),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFF1E3042),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: GlitchedFlowShell.cream.withAlpha(60)),
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildScopeOption(
                scope: RenovationScope.fullRenovation,
                title: 'Full Renovation',
                subtitle: 'Finishes & Screed',
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _buildScopeOption(
                scope: RenovationScope.extension,
                title: 'Extension',
                subtitle: 'Structure + Finishes',
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 6),
      Text(
        _selectedScope.description,
        style: GoogleFonts.poppins(
          fontSize: 11,
          color: const Color(0xFF8FB2D4),
        ),
      ),
    ];
  }

  List<Widget> _buildAreaSection() {
    return [
      _label('Total area (square meters) *'),
      const SizedBox(height: 8),
      TextFormField(
        controller: _areaController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: GoogleFonts.poppins(
          color: GlitchedFlowShell.darkBlue,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        scrollPadding: const EdgeInsets.only(bottom: 140),
        decoration: InputDecoration(
          hintText: 'e.g. 18',
          hintStyle: GoogleFonts.poppins(
            color: GlitchedFlowShell.darkBlue.withValues(alpha: 0.4),
          ),
          suffixText: 'sqm',
          filled: true,
          fillColor: GlitchedFlowShell.cream,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        validator: (value) {
          final parsed = double.tryParse(value?.trim() ?? '');
          if (parsed == null || !parsed.isFinite || parsed <= 0) {
            return 'Enter a valid area greater than 0';
          }
          if (parsed > 100000) {
            return 'That area looks too large — check the value';
          }
          return null;
        },
      ),
    ];
  }

  List<Widget> _buildRoomSection(RoomJob job) {
    final details = _details!;
    final wallTileOptions = [
      WallTileHeight.none,
      if (job == RoomJob.kitchen) WallTileHeight.backsplash,
      WallTileHeight.wainscot,
      WallTileHeight.full,
    ];

    return [
      _label(job.hasWalls
          ? 'Room size: length, width and ceiling height *'
          : 'Room size: length and width *'),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: _metresField(_lengthController, 'Length', 'e.g. 3.0'),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _metresField(_widthController, 'Width', 'e.g. 2.5'),
          ),
          if (job.hasWalls) ...[
            const SizedBox(width: 8),
            Expanded(
              child: _metresField(_heightController, 'Height', 'e.g. 2.7'),
            ),
          ],
        ],
      ),
      const SizedBox(height: 18),
      _label(job.hasWalls ? 'Doors' : 'Doorways (skirting stops at these)'),
      const SizedBox(height: 6),
      ..._openingRows(_doors, 'door'),
      _addSizeButton(
        'Add another door size',
        () => setState(() => _doors.add(_OpeningCount.custom())),
      ),
      if (job.hasWalls) ...[
        const SizedBox(height: 12),
        _label('Windows'),
        const SizedBox(height: 6),
        ..._openingRows(_windows, 'window'),
        _addSizeButton(
          'Add another window size',
          () => setState(() => _windows.add(_OpeningCount.custom())),
        ),
      ],
      if (job.offersWallTiles) ...[
        const SizedBox(height: 12),
        _label('Wall tiles'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in wallTileOptions)
              _choiceChip(
                label: option.label,
                selected: _wallTiles == option,
                onTap: () => setState(() => _wallTiles = option),
              ),
          ],
        ),
      ],
      if (job == RoomJob.kitchen) ...[
        const SizedBox(height: 16),
        _label('Counter length'),
        const SizedBox(height: 8),
        _metresField(_counterController, 'Counter', 'e.g. 2.4'),
        const SizedBox(height: 4),
        _hint('Sizes the backsplash and the countertop.'),
      ],
      const SizedBox(height: 12),
      if (job.hasFloor)
        _switchRow(
          title: 'Remove the old floor tiles',
          subtitle: 'Adds cement and sand for a new screed',
          value: _removeOldTiles,
          onChanged: (v) => setState(() => _removeOldTiles = v),
        ),
      if (job.hasWalls)
        _switchRow(
          title: 'Paint the ceiling',
          subtitle: 'Adds the ceiling to the paint area',
          value: _paintCeiling,
          onChanged: (v) => setState(() => _paintCeiling = v),
        ),
      const SizedBox(height: 12),
      _buildTakeoffSummary(details),
    ];
  }

  Widget _hint(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 11,
        color: const Color(0xFF8FB2D4),
        height: 1.3,
      ),
    );
  }

  Widget _metresField(
    TextEditingController controller,
    String label,
    String hint, {
    bool dense = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      onChanged: (_) => setState(() {}),
      scrollPadding: const EdgeInsets.only(bottom: 160),
      style: GoogleFonts.poppins(
        color: GlitchedFlowShell.darkBlue,
        fontSize: dense ? 13 : 15,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(
          color: GlitchedFlowShell.darkBlue.withValues(alpha: 0.7),
          fontSize: 12,
        ),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        hintText: hint,
        hintStyle: GoogleFonts.poppins(
          color: GlitchedFlowShell.darkBlue.withValues(alpha: 0.35),
          fontSize: dense ? 12 : 13,
        ),
        suffixText: 'm',
        isDense: true,
        filled: true,
        fillColor: GlitchedFlowShell.cream,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: dense ? 8 : 12,
        ),
      ),
    );
  }

  List<Widget> _openingRows(List<_OpeningCount> rows, String noun) {
    final labelStyle = GoogleFonts.poppins(
      fontSize: 12,
      color: const Color(0xFFE0D7C9),
    );
    return [
      for (var i = 0; i < rows.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Expanded(
                child: rows[i].preset != null
                    ? Text(
                        '${rows[i].preset!.sizeLabel} · ${rows[i].use}',
                        style: labelStyle,
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: _metresField(
                                rows[i].widthController!, 'Width', '0.80',
                                dense: true),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text('×', style: labelStyle),
                          ),
                          Expanded(
                            child: _metresField(
                                rows[i].heightController!, 'Height', '2.10',
                                dense: true),
                          ),
                        ],
                      ),
              ),
              const SizedBox(width: 8),
              _CountStepper(
                count: rows[i].count,
                noun: noun,
                onChanged: (value) => setState(() => rows[i].count = value),
              ),
              if (rows[i].preset == null)
                IconButton(
                  tooltip: 'Remove this $noun size',
                  onPressed: () => setState(() {
                    final removed = rows.removeAt(i);
                    // Its fields are still on screen until this rebuild.
                    WidgetsBinding.instance
                        .addPostFrameCallback((_) => removed.dispose());
                  }),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: GlitchedFlowShell.cream,
                  ),
                ),
            ],
          ),
        ),
    ];
  }

  Widget _addSizeButton(String label, VoidCallback onPressed) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF8FB2D4),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          visualDensity: VisualDensity.compact,
        ),
        icon: const Icon(Icons.add_rounded, size: 16),
        label: Text(
          label,
          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _choiceChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? GlitchedFlowShell.cream : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: GlitchedFlowShell.cream.withAlpha(120)),
          ),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: selected
                  ? GlitchedFlowShell.darkBlue
                  : GlitchedFlowShell.cream,
            ),
          ),
        ),
      ),
    );
  }

  Widget _switchRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: GlitchedFlowShell.cream,
                    ),
                  ),
                  _hint(subtitle),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeTrackColor: GlitchedFlowShell.cream,
              activeThumbColor: GlitchedFlowShell.darkBlue,
            ),
          ],
        ),
      ),
    );
  }

  /// The measured surfaces, updated as the builder types, so a wrong figure
  /// is caught here rather than in forty wall tiles too many.
  Widget _buildTakeoffSummary(SiteDetails details) {
    final problems = _problems(details);
    final lines = <String>[];
    var warnings = const <String>[];
    if (problems.isEmpty) {
      final t = SiteTakeoff.from(details);
      final job = details.job;
      if (job.hasFloor) lines.add(t.floorLine);
      if (job.hasWalls) lines.add(t.wallLine);
      if (t.wallTileSqm > 0) lines.add(t.wallTileLine);
      if (t.paintSqm > 0) lines.add(t.paintLine);
      if (job.hasSkirting && t.skirtingM > 0) lines.add(t.skirtingLine);
      if (t.waterproofingSqm > 0) lines.add(t.waterproofingLine);
      warnings = details.warnings();
    }

    final bodyStyle = GoogleFonts.poppins(
      fontSize: 11,
      color: const Color(0xFFE0D7C9),
      height: 1.35,
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3042),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: GlitchedFlowShell.cream.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.straighten_rounded,
                size: 18,
                color: Color(0xFF8FB2D4),
              ),
              const SizedBox(width: 8),
              Expanded(child: _label('Takeoff')),
            ],
          ),
          const SizedBox(height: 6),
          if (problems.isNotEmpty)
            Text(problems.first, style: bodyStyle)
          else
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(line, style: bodyStyle),
              ),
          for (final warning in warnings)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                warning,
                style: bodyStyle.copyWith(color: const Color(0xFFFFC98A)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStandardsNote() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: GlitchedFlowShell.cream.withAlpha(20),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: GlitchedFlowShell.cream.withAlpha(40)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_user_outlined,
              size: 20, color: Color(0xFF8FB2D4)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'DPWH & NSCP National Standards\nQuantities include a waste allowance for cutting and breakage.',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: const Color(0xFFE0D7C9),
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScopeOption({
    required RenovationScope scope,
    required String title,
    required String subtitle,
  }) {
    final selected = _selectedScope == scope;
    return GestureDetector(
      onTap: () => setState(() => _selectedScope = scope),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? GlitchedFlowShell.cream : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected
                    ? GlitchedFlowShell.darkBlue
                    : GlitchedFlowShell.cream,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 9,
                color: selected
                    ? GlitchedFlowShell.darkBlue.withAlpha(180)
                    : const Color(0xFF8FB2D4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A − n + counter for doors or windows of one size.
class _CountStepper extends StatelessWidget {
  final int count;
  final String noun;
  final ValueChanged<int> onChanged;

  const _CountStepper({
    required this.count,
    required this.noun,
    required this.onChanged,
  });

  static const int _max = 20;

  @override
  Widget build(BuildContext context) {
    Widget step(IconData icon, String tooltip, VoidCallback? onPressed) {
      return IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        color: GlitchedFlowShell.cream,
        disabledColor: GlitchedFlowShell.cream.withAlpha(70),
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GlitchedFlowShell.cream.withAlpha(90)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          step(Icons.remove_rounded, 'One less $noun',
              count > 0 ? () => onChanged(count - 1) : null),
          SizedBox(
            width: 24,
            child: Text(
              '$count',
              textAlign: TextAlign.center,
              semanticsLabel: '$count ${noun}s',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: GlitchedFlowShell.cream,
              ),
            ),
          ),
          step(Icons.add_rounded, 'One more $noun',
              count < _max ? () => onChanged(count + 1) : null),
        ],
      ),
    );
  }
}
