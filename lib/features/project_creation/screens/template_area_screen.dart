import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iconstruct/core/navigation/progress_guard.dart';
import 'package:iconstruct/core/widgets/app_message.dart';
import 'package:iconstruct/features/auth/presentation/screens/cost_estimation.dart';
import 'package:iconstruct/features/project_creation/data/bom_quantity_estimator.dart';
import 'package:iconstruct/features/project_creation/data/description_hints.dart';
import 'package:iconstruct/features/project_creation/data/functional_counts.dart';
import 'package:iconstruct/features/project_creation/data/material_kind.dart';
import 'package:iconstruct/features/project_creation/data/ph_renovation_rates.dart';
import 'package:iconstruct/features/project_creation/data/renovation_coverage.dart';
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

  /// Chosen on the renovation type step, before the project was named.
  final RenovationScope scope;

  /// How much of the space the job covers. Its own dimension: a partial
  /// cosmetic job and a full one are the same kind of work over different
  /// amounts of room.
  final RenovationCoverage coverage;

  /// Every kind of work chosen, of which [scope] is the heaviest. Null from a
  /// caller that predates multi-select, which then means [scope] alone.
  final RenovationTypes? renovationTypes;

  RenovationTypes get types => renovationTypes ?? RenovationTypes.only(scope);

  /// Budget tier from the AI chat, when the list came from there.
  final String? budgetPreference;

  /// Finishes read out of what the builder wrote on the describe screen.
  /// They pre-set the switches below; the builder can still change any of them.
  final SiteHints hints;

  const TemplateAreaScreen({
    super.key,
    required this.template,
    required this.projectName,
    this.customProjectName,
    this.projectNotes,
    this.scope = RenovationScope.cosmetic,
    this.coverage = RenovationCoverage.full,
    this.renovationTypes,
    this.budgetPreference,
    this.hints = SiteHints.none,
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

  /// The whole space a partial job sits inside, and what the part is called.
  final _portionLabelController = TextEditingController();
  final _totalLengthController = TextEditingController();
  final _totalWidthController = TextEditingController();

  /// A partial job may still cover the whole space — "partial" is the
  /// builder's intent, and only they know whether it narrows to one part.
  bool _isPortion = false;

  /// An L-shaped or otherwise irregular room, measured wall by wall instead of
  /// squashed into the nearest rectangle.
  bool _isIrregular = false;
  final _floorAreaController = TextEditingController();
  final List<TextEditingController> _wallRuns = [
    for (var i = 0; i < 4; i++) TextEditingController(),
  ];

  late final RoomJob? _job = roomJobFor(widget.template.renovationType);
  late final List<_OpeningCount> _doors;
  late final List<_OpeningCount> _windows;
  WallTileHeight _wallTiles = WallTileHeight.none;
  bool _removeOldTiles = false;
  bool _paintCeiling = false;

  /// How many devices the wiring job installs. These, not the floor area,
  /// size the outlets, switches, lights, wire, conduit and utility boxes.
  late int _outlets;
  late int _switches;
  late int _lights;

  /// Whether finishes are measured: true when any chosen kind of work changes
  /// them. Purely functional work replaces pipes and wiring, so then only the
  /// room's size matters; doors, windows, tiles and paint are left as they are.
  bool get _finishes => widget.types.changesFinishes;

  /// Whether to ask for device counts: a job with functional work in it whose
  /// template actually carries wiring. Asked of the template itself rather than
  /// of the room, because a functional bathroom is plumbing only and a
  /// functional roof is drainage only — neither has a device to count.
  ///
  /// Asked alongside the finishes when the job is both — retiling a kitchen and
  /// rewiring it — rather than instead of them, which is what a single choice
  /// used to force.
  ///
  /// The steppers live in the room section, so a job with no room to measure
  /// cannot show them. Such a job keeps the template's own rates rather than
  /// taking counts the builder was never offered, which would read as zero
  /// devices and empty the wiring out of the list.
  late final bool _needsFunctionalCounts = widget.types.includesFunctional &&
      _job != null &&
      widget.template.items
          .any((i) => classifyMaterial(i) == MaterialKind.electrical);

  /// Whether the list carries a line of the given kind. A list built from
  /// ticked work is only asked about the work ticked: no wall-tile height
  /// when the walls are not being tiled, and nothing about the ceiling when
  /// nothing is being painted. A template is asked everything, as before,
  /// because measuring may add a finish it did not carry.
  bool _asks(bool Function(RenovationTemplateItem) test) =>
      !widget.template.isFromWorkItems || widget.template.items.any(test);

  late final bool _asksWallTiles =
      _asks((i) => classifyMaterial(i) == MaterialKind.wallTile);
  late final bool _asksFloor = _asks((i) =>
      classifyMaterial(i) == MaterialKind.floorTile || isFloorFinishGoods(i));
  late final bool _asksPaint =
      _asks((i) => kPaintKinds.contains(classifyMaterial(i)));

  /// Doors and windows change the tiled and painted wall and the new CHB, and
  /// doorways shorten the skirting.
  late final bool _asksOpenings = _asksWallTiles ||
      _asksPaint ||
      _asks((i) =>
          classifyMaterial(i) == MaterialKind.chbBlock ||
          i.name.toLowerCase().contains('skirting'));

  /// The counts as entered, or `null` when this job wires nothing and its
  /// quantities keep the template's own rates.
  FunctionalCounts? get _counts => _needsFunctionalCounts
      ? FunctionalCounts(
          outlets: _outlets,
          switches: _switches,
          lights: _lights,
        )
      : null;

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
    _wallTiles = widget.hints.wallTileHeight ??
        defaults?.wallTileHeight ??
        WallTileHeight.none;
    // Tiling the walls was ticked, so "no wall tiles" is not an answer here.
    if (widget.template.isFromWorkItems &&
        _asksWallTiles &&
        _wallTiles == WallTileHeight.none) {
      _wallTiles = WallTileHeight.wainscot;
    }
    _removeOldTiles =
        widget.hints.removeOldTiles ?? defaults?.removeOldTiles ?? false;
    _paintCeiling =
        widget.hints.paintCeiling ?? defaults?.paintCeiling ?? false;

    // A starting point for the steppers, not a rule — typical counts for a
    // room of this kind, which the builder then corrects.
    final devices = FunctionalCounts.defaultsFor(job);
    _outlets = devices.outlets;
    _switches = devices.switches;
    _lights = devices.lights;
    _openedWith = _entrySignature();
  }

  /// Everything the builder can enter here, as one string, so leaving can
  /// tell whether anything was typed or switched since the screen opened.
  late final String _openedWith;

  String _entrySignature() => [
    _areaController.text,
    _lengthController.text,
    _widthController.text,
    _heightController.text,
    _counterController.text,
    _portionLabelController.text,
    _totalLengthController.text,
    _totalWidthController.text,
    _floorAreaController.text,
    for (final run in _wallRuns) run.text,
    for (final row in [..._doors, ..._windows])
      '${row.count}:${row.widthController?.text}:${row.heightController?.text}',
    _isPortion,
    _isIrregular,
    _wallTiles.name,
    _removeOldTiles,
    _paintCeiling,
    _outlets,
    _switches,
    _lights,
  ].join('|');

  LeaveWarning? _backWarning() {
    if (_entrySignature() == _openedWith) {
      return const LeaveWarning.exitEstimate();
    }
    return const LeaveWarning(
      title: 'Discard your measurements?',
      message:
          'Going back clears the measurements and site details you '
          'entered on this screen. Quantities are sized from them, so you '
          'would need to enter them again.',
      keeps: 'Your selected work list is kept.',
      confirmLabel: 'Discard',
      cancelLabel: 'Keep editing',
    );
  }

  @override
  void dispose() {
    _areaController.dispose();
    _lengthController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _counterController.dispose();
    _portionLabelController.dispose();
    _totalLengthController.dispose();
    _totalWidthController.dispose();
    _floorAreaController.dispose();
    for (final run in _wallRuns) {
      run.dispose();
    }
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
      doors: _finishes && _asksOpenings ? openings(_doors) : const [],
      windows: _finishes && _asksOpenings && job.hasWalls
          ? openings(_windows)
          : const [],
      wallTileHeight: _finishes && job.offersWallTiles && _asksWallTiles
          ? _wallTiles
          : WallTileHeight.none,
      counterLengthM: _finishes && job == RoomJob.kitchen
          ? _parseMetres(_counterController.text) ?? 0
          : 0,
      removeOldTiles:
          _finishes && job.hasFloor && _asksFloor && _removeOldTiles,
      paintCeiling: _finishes && job.hasWalls && _asksPaint && _paintCeiling,
      partial: _partialArea,
      irregular: _irregularRoom,
      half: widget.coverage.isHalf,
    );
  }

  /// How far round the room the entered walls reach, so the builder can check
  /// it against what they paced out.
  double get _wallPerimeter => _wallRuns.fold(0.0, (sum, run) {
        final metres = _parseMetres(run.text) ?? 0;
        return sum + (metres > 0 ? metres : 0);
      });

  /// The room as walked wall by wall, when it is not a rectangle.
  IrregularRoom? get _irregularRoom {
    if (!_isIrregular) return null;
    return IrregularRoom(
      wallRunsM: [
        for (final run in _wallRuns)
          if (_parseMetres(run.text) != null && _parseMetres(run.text)! > 0)
            _parseMetres(run.text)!,
      ],
      floorSqm: _parseMetres(_floorAreaController.text) ?? 0,
    );
  }

  /// Whether this job is asked which part of the space it covers. Only a
  /// partial one has a part; a full job and a half job are measured whole.
  bool get _asksPortion => widget.coverage.hasPortion;

  /// The whole space, when the builder narrowed the job to a part of it.
  PartialArea? get _partialArea {
    if (!_asksPortion || !_isPortion) return null;
    return PartialArea(
      label: _portionLabelController.text.trim(),
      totalLengthM: _parseMetres(_totalLengthController.text) ?? 0,
      totalWidthM: _parseMetres(_totalWidthController.text) ?? 0,
    );
  }

  List<String> _problems(SiteDetails details) => [
        ...details.problems(),
        // A wiring job that installs nothing has no materials to quote.
        if (_needsFunctionalCounts && (_counts?.isEmpty ?? false))
          'Enter at least one outlet, switch or light for a wiring job.',
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
      // A job measured by area alone is halved the same way a room is.
      _openEstimate(widget.coverage.isHalf ? area / 2 : area, null);
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
    final counts = _counts;
    final scaled = BomQuantityEstimator.scaleTemplate(
      template: widget.template,
      areaSqm: area,
      scope: widget.scope,
      types: widget.types,
      takeoff: takeoff,
      counts: counts,
    );
    // An AI list holds exactly what the builder picked, so it gets no type
    // chips to swap one pick for another.
    final scaledItems =
        widget.template.id == BomQuantityEstimator.consultationTemplateId
            ? BomQuantityEstimator.fixedList(scaled)
            : scaled;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CostEstimationScreen(
          projectName: widget.projectName,
          customProjectName: widget.customProjectName,
          projectNotes: widget.projectNotes,
          template: widget.template.copyWithItems(scaledItems),
          projectAreaSqm: area,
          scope: widget.scope,
          coverage: widget.coverage,
          renovationTypes: widget.types,
          takeoff: takeoff,
          counts: counts,
          budgetPreference: widget.budgetPreference,
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
                      'Floor tiles are sized from length × width. Wall tiles and paint are sized from the walls, which are the room\'s perimeter × ceiling height, less its doors and windows. A roof is sized from the floor area under it.',
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
                  title: '3. Type of Renovation',
                  body:
                      '• Cosmetic: tiles, paint, fixtures and the cement layer under new tiles.\n• Structural: CHB walls, slab, rebar and forms. Footings, columns, beams and underpinning come from the engineer\'s plan.\n• Functional: wire, conduit and boxes are sized from the outlets, switches and lights you enter. Pipes and fittings are set counts for the fixtures.',
                  icon: Icons.tune_outlined,
                ),
                const SizedBox(height: 10),
                _buildGuideCard(
                  title: '4. Waste & rounding',
                  body:
                      'Tiles carry 8% cutting waste. Every quantity is rounded up, never down: to a whole bag, piece or length, or to 0.01 for sand, gravel and tie wire. Open View Formula on any line to check the working by hand.',
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
          ? 'Enter the total area in square meters.'
          : _finishes
              ? 'Enter the room size. Quantities use these measurements.'
              : _needsFunctionalCounts
                  ? 'Enter the room size and how many devices you need.'
                  : 'Enter the room size.',
      onBack: _backWarning,
      onExit: () => const LeaveWarning.exitEstimate(),
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
            _buildTypeRow(),
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

  Widget _buildTypeRow() {
    return Row(
        children: [
          // Expanded so the label gives way to the help link on a narrow
          // screen instead of pushing it past the panel edge.
          Expanded(
            child: _label(
                '${widget.types.label} renovation · '
                '${widget.template.items.length} '
                'material${widget.template.items.length == 1 ? '' : 's'}'),
          ),
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
      );
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
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        scrollPadding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
        decoration: InputDecoration(
          hintText: 'e.g. 18',
          hintStyle: GoogleFonts.poppins(
            color: GlitchedFlowShell.darkBlue.withValues(alpha: 0.4),
            fontSize: 16,
          ),
          suffixText: 'sqm',
          // Says which dimensions make the area, the same way the room
          // fields name theirs. Replaced by the error when there is one.
          helperText: 'Length × width, in meters. A 6 m × 3 m area is 18 sqm.',
          helperMaxLines: 2,
          helperStyle: GoogleFonts.poppins(
            fontSize: 11,
            color: const Color(0xFF8FB2D4),
            height: 1.3,
          ),
          errorMaxLines: 3,
          // The theme's dark red is hard to read on this navy panel.
          errorStyle: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: const Color(0xFFFFB4A8),
            height: 1.3,
          ),
          filled: true,
          fillColor: GlitchedFlowShell.cream,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: const BorderSide(
              color: GlitchedFlowShell.darkBlue,
              width: 1.4,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 18,
          ),
        ),
        validator: (value) {
          final parsed = double.tryParse(value?.trim() ?? '');
          // Each message names the unit and the dimensions, as the room-size
          // messages do ("Enter a room length between 0.5 and 30 m.").
          if (parsed == null || !parsed.isFinite || parsed <= 0) {
            return 'Enter a valid area greater than 0 sqm '
                '(length × width, in meters).';
          }
          if (parsed > 100000) {
            return 'That area looks too large — check the value. '
                'Enter 100,000 sqm or less.';
          }
          return null;
        },
      ),
      if (widget.coverage.isHalf) ...[
        const SizedBox(height: 8),
        _hint('Half: enter the whole area. The materials are sized for half '
            'of it.'),
      ],
    ];
  }

  List<Widget> _buildRoomSection(RoomJob job) {
    final details = _details!;
    final wallTileOptions = [
      if (!widget.template.isFromWorkItems) WallTileHeight.none,
      if (job == RoomJob.kitchen) WallTileHeight.backsplash,
      WallTileHeight.wainscot,
      WallTileHeight.full,
    ];

    return [
      if (_asksPortion) ...[
        _label('How much of the space?'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _choiceChip(
              label: 'The whole space',
              selected: !_isPortion,
              onTap: () => setState(() => _isPortion = false),
            ),
            _choiceChip(
              label: 'One part of it',
              selected: _isPortion,
              onTap: () => setState(() => _isPortion = true),
            ),
          ],
        ),
        if (_isPortion) ...[
          const SizedBox(height: 10),
          // The part is what gets measured below, because the part is what the
          // materials have to cover. The whole space is context for the shop
          // and a check that the part is not bigger than the room it is in.
          _hint(
            'Measure the part below. The whole space is asked for so the shop '
            'can see the context, and is never used to scale a quantity.',
          ),
          const SizedBox(height: 10),
          _portionLabelField(),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _metresField(
                    _totalLengthController, 'Whole length', 'e.g. 4.0'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metresField(
                    _totalWidthController, 'Whole width', 'e.g. 3.0'),
              ),
            ],
          ),
          if (_portionShare != null) ...[
            const SizedBox(height: 6),
            _hint(_portionShare!),
          ],
        ],
        const SizedBox(height: 18),
      ],
      if (widget.coverage.isHalf) ...[
        _hint('Half: measure the whole room. Every surface below is sized at '
            'half of it.'),
        const SizedBox(height: 10),
      ],
      _label(job.hasWalls
          ? (_isPortion && _asksPortion
              ? 'The part: length, width and ceiling height *'
              : 'Room size: length, width and ceiling height *')
          : (_isPortion && _asksPortion
              ? 'The part: length and width *'
              : 'Room size: length and width *')),
      const SizedBox(height: 4),
      // One room per estimate is still the rule. The shape of that room is no
      // longer forced into a rectangle: an L-shaped room is measured wall by
      // wall below.
      _hint(
        'One room per estimate. For another room, make a separate estimate.',
      ),
      if (_finishes && !widget.hints.isEmpty) ...[
        const SizedBox(height: 6),
        // Shown so the builder can see that the app read what they wrote, and
        // can correct it where a keyword guessed wrong.
        _hint('Set from your description: ${widget.hints.applied.join(' · ')}'),
      ],
      const SizedBox(height: 8),
      _switchRow(
        title: 'Not a simple rectangle',
        subtitle: 'An L-shaped room, or one with a recess or a bay',
        value: _isIrregular,
        onChanged: (v) => setState(() => _isIrregular = v),
      ),
      if (_isIrregular) ...[
        const SizedBox(height: 8),
        // A foreman measures such a room the way it is built: each wall in
        // turn, and the floor split into rectangles and added up.
        _hint(
          'Enter each wall in turn, walking the room. For the floor, split it '
          'into rectangles and add them up.',
        ),
        const SizedBox(height: 10),
        _metresField(_floorAreaController, 'Floor area (sq.m)', 'e.g. 14.5'),
        const SizedBox(height: 10),
        _label('Wall lengths'),
        const SizedBox(height: 6),
        for (var i = 0; i < _wallRuns.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: _metresField(
                      _wallRuns[i], 'Wall ${i + 1}', 'e.g. 3.0',
                      dense: true),
                ),
                if (_wallRuns.length > 3)
                  IconButton(
                    tooltip: 'Remove wall ${i + 1}',
                    onPressed: () => setState(() {
                      final removed = _wallRuns.removeAt(i);
                      WidgetsBinding.instance
                          .addPostFrameCallback((_) => removed.dispose());
                    }),
                    icon: const Icon(Icons.close_rounded, size: 16),
                    color: GlitchedFlowShell.cream,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
        _addSizeButton(
          'Add another wall',
          () => setState(() => _wallRuns.add(TextEditingController())),
        ),
        if (_wallPerimeter > 0) ...[
          const SizedBox(height: 4),
          _hint('${_wallRuns.length} walls, '
              '${_wallPerimeter.toStringAsFixed(2)} m around.'),
        ],
        if (job.hasWalls) ...[
          const SizedBox(height: 10),
          _metresField(_heightController, 'Ceiling height', 'e.g. 2.7'),
        ],
      ],
      if (!_isIrregular) _roomSizeFields(withHeight: job.hasWalls),
      if (_needsFunctionalCounts) ...[
        const SizedBox(height: 18),
        _label('Devices to install *'),
        const SizedBox(height: 4),
        // Said plainly, because this is the change: the room no longer decides
        // how much wire the job needs.
        _hint(
          'Wire, conduit and utility boxes are sized from these counts, not '
          'from the floor area. Set one to 0 to leave it out of the list.',
        ),
        const SizedBox(height: 10),
        _deviceRow('Convenience outlets', 'outlet', _outlets,
            (value) => setState(() => _outlets = value)),
        _deviceRow('Light switches', 'switch', _switches,
            (value) => setState(() => _switches = value)),
        _deviceRow('Ceiling lights', 'light', _lights,
            (value) => setState(() => _lights = value)),
      ],
      if (_finishes) ...[
      if (_asksOpenings) ...[
        const SizedBox(height: 18),
        _label(job.hasWalls ? 'Doors' : 'Doorways (skirting stops at these)'),
        const SizedBox(height: 6),
        ..._openingRows(_doors, 'door'),
        _addSizeButton(
          'Add another door size',
          () => setState(() => _doors.add(_OpeningCount.custom())),
        ),
      ],
      if (job.hasWalls && _asksOpenings) ...[
        const SizedBox(height: 12),
        _label('Windows'),
        const SizedBox(height: 6),
        ..._openingRows(_windows, 'window'),
        _addSizeButton(
          'Add another window size',
          () => setState(() => _windows.add(_OpeningCount.custom())),
        ),
      ],
      if (job.offersWallTiles && _asksWallTiles) ...[
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
      if (job.hasFloor && _asksFloor)
        _switchRow(
          title: 'Remove the old floor tiles',
          subtitle: 'Adds cement and sand to level the floor for the new tiles',
          value: _removeOldTiles,
          onChanged: (v) => setState(() => _removeOldTiles = v),
        ),
      if (job.hasWalls && _asksPaint)
        _switchRow(
          title: 'Paint the ceiling',
          subtitle: 'Adds the ceiling to the paint area',
          value: _paintCeiling,
          onChanged: (v) => setState(() => _paintCeiling = v),
        ),
      ],
      const SizedBox(height: 12),
      _buildMeasurementGuide(details),
      const SizedBox(height: 10),
      _buildTakeoffSummary(details),
    ];
  }

  /// What the builder typed, read back with the total area, so a wrong
  /// figure is seen before it sizes every material.
  Widget _buildMeasurementGuide(SiteDetails details) {
    final job = details.job;
    String m(double v) {
      final text = PhRenovationRates.numText(v);
      final dot = text.indexOf('.');
      if (dot < 0) return '$text.00';
      return text.length - dot - 1 < 2 ? '${text}0' : text;
    }

    final shape = details.irregular;
    final floor = details.measuredFloorSqm;
    final heightOk = !job.hasWalls || details.heightM > 0;
    final complete = floor > 0 && heightOk;

    final lines = <String>[];
    if (complete) {
      final size = shape != null
          ? '${shape.wallRunsM.length} walls, ${m(shape.perimeterM)} m around'
          : '${m(details.lengthM)} m long × ${m(details.widthM)} m wide';
      lines.add(job.hasWalls ? '$size, ${m(details.heightM)} m high' : size);
    }

    final bodyStyle = GoogleFonts.poppins(
      fontSize: 12,
      color: const Color(0xFFE0D7C9),
      height: 1.4,
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: GlitchedFlowShell.cream.withAlpha(24),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: GlitchedFlowShell.cream.withAlpha(90)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: Color(0xFF8FB2D4),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _label(
                  details.partial != null
                      ? 'The part you measured'
                      : 'Your measurements',
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (!complete)
            Text(
              shape != null
                  ? 'Enter the floor area and each wall to see the total.'
                  : job.hasWalls
                      ? 'Enter the length, width and height to see the total '
                          'area.'
                      : 'Enter the length and width to see the total area.',
              style: bodyStyle,
            )
          else ...[
            for (final line in lines) Text(line, style: bodyStyle),
            const SizedBox(height: 4),
            Text(
              shape != null
                  ? 'Total floor area: ${PhRenovationRates.areaText(floor)} sq.m'
                  : 'Total floor area: ${m(details.lengthM)} × '
                      '${m(details.widthM)} = '
                      '${PhRenovationRates.areaText(floor)} sq.m',
              style: bodyStyle.copyWith(
                fontWeight: FontWeight.w700,
                color: GlitchedFlowShell.cream,
              ),
            ),
            if (details.half)
              Text(
                'Half of the room is used: '
                '${PhRenovationRates.areaText(floor / 2)} sq.m',
                style: bodyStyle,
              ),
          ],
        ],
      ),
    );
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

  /// How much of the space the part comes to, as information only.
  ///
  /// Stated plainly as a share because a builder thinks in those terms, and
  /// stated as not-a-calculation because it is not one: every quantity below
  /// is sized from the part that was measured, never from a percentage of the
  /// whole.
  String? get _portionShare {
    final details = _details;
    final share = details?.portionOfSpace;
    if (share == null || share <= 0 || share > 1.0001) return null;
    return 'About ${(share * 100).round()}% of the space. Shown for context '
        'only — quantities come from the part you measured.';
  }

  Widget _portionLabelField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('What is this part called?'),
        const SizedBox(height: 6),
        TextField(
          controller: _portionLabelController,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
          scrollPadding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
          style: GoogleFonts.poppins(
            color: GlitchedFlowShell.darkBlue,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: 'shower area, accent wall',
            hintStyle: GoogleFonts.poppins(
              color: GlitchedFlowShell.darkBlue.withValues(alpha: 0.45),
              fontSize: 13,
            ),
            isDense: true,
            filled: true,
            fillColor: GlitchedFlowShell.cream,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }

  /// One wiring device and how many of it the room gets.
  Widget _deviceRow(
    String label,
    String noun,
    int count,
    ValueChanged<int> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: const Color(0xFFE0D7C9),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _CountStepper(count: count, noun: noun, onChanged: onChanged),
        ],
      ),
    );
  }

  /// A field name drawn on the dark panel, above the cream box. A floating
  /// label sat on that dark panel in dark type, so Length and Width disappeared.
  Widget _fieldLabel(String text, {bool dense = false}) {
    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.poppins(
        color: GlitchedFlowShell.cream,
        fontSize: dense ? 13 : 14,
        fontWeight: FontWeight.w700,
        height: 1.15,
      ),
    );
  }

  /// The narrowest a metres box can be and still show a value such as
  /// "12.35" next to its "m".
  static const double _minMetresFieldWidth = 110;

  /// Length and width, and the ceiling height when the job has walls. Three
  /// across left each box about 80 wide on a phone, too narrow for a value
  /// and its unit: "2.4" slid under the "m" and the hints were cut to "3.…".
  /// The height takes a row of its own whenever three do not fit.
  Widget _roomSizeFields({required bool withHeight}) {
    const gap = 10.0;
    Widget pair(Widget left, Widget right) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: gap),
            Expanded(child: right),
          ],
        );
    final length = _metresField(_lengthController, 'Length', 'e.g. 3.0');
    final width = _metresField(_widthController, 'Width', 'e.g. 2.5');
    if (!withHeight) return pair(length, width);
    final height = _metresField(_heightController, 'Height', 'e.g. 2.7');
    return LayoutBuilder(
      builder: (context, constraints) {
        final threeAcross =
            (constraints.maxWidth - 2 * gap) / 3 >= _minMetresFieldWidth;
        if (threeAcross) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: length),
              const SizedBox(width: gap),
              Expanded(child: width),
              const SizedBox(width: gap),
              Expanded(child: height),
            ],
          );
        }
        return Column(
          children: [
            pair(length, width),
            const SizedBox(height: 12),
            pair(height, const SizedBox.shrink()),
          ],
        );
      },
    );
  }

  Widget _metresField(
    TextEditingController controller,
    String label,
    String hint, {
    bool dense = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label, dense: dense),
        SizedBox(height: dense ? 4 : 6),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          onChanged: (_) => setState(() {}),
          scrollPadding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
          style: GoogleFonts.poppins(
            color: GlitchedFlowShell.darkBlue,
            fontSize: dense ? 15 : 18,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: hint.replaceFirst(RegExp(r'^e\.g\.\s*'), ''),
            hintStyle: GoogleFonts.poppins(
              color: GlitchedFlowShell.darkBlue.withValues(alpha: 0.45),
              fontSize: dense ? 13 : 15,
            ),
            suffixText: 'm',
            isDense: dense,
            filled: true,
            fillColor: GlitchedFlowShell.cream,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(dense ? 18 : 24),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(dense ? 18 : 24),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(dense ? 18 : 24),
              borderSide: const BorderSide(
                color: GlitchedFlowShell.darkBlue,
                width: 1.4,
              ),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: dense ? 12 : 16,
              vertical: dense ? 14 : 18,
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _openingRows(List<_OpeningCount> rows, String noun) {
    final labelStyle = GoogleFonts.poppins(
      fontSize: 12,
      color: const Color(0xFFE0D7C9),
    );
    Widget stepper(int i) => _CountStepper(
          count: rows[i].count,
          noun: noun,
          onChanged: (value) => setState(() => rows[i].count = value),
        );
    return [
      for (var i = 0; i < rows.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: rows[i].preset != null
              ? Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${rows[i].preset!.sizeLabel} · ${rows[i].use}',
                        style: labelStyle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    stepper(i),
                  ],
                )
              // A size of the builder's own. Its two boxes take the whole
              // row, with the count under them: squeezed beside the counter
              // they were too narrow to show "0.85" at all.
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Aligned on the boxes, not on the boxes and their labels,
                    // so "×" and the remove button sit on the boxes' middle.
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: _metresField(
                              rows[i].widthController!, 'Width', '0.80',
                              dense: true),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 0, 4, 15),
                          child: Text('×', style: labelStyle),
                        ),
                        Expanded(
                          child: _metresField(
                              rows[i].heightController!, 'Height', '2.10',
                              dense: true),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: IconButton(
                            tooltip: 'Remove this $noun size',
                            onPressed: () => setState(() {
                              final removed = rows.removeAt(i);
                              // Its fields are still on screen until this
                              // rebuild.
                              WidgetsBinding.instance.addPostFrameCallback(
                                  (_) => removed.dispose());
                            }),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                                minWidth: 36, minHeight: 36),
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: GlitchedFlowShell.cream,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text('How many of this size', style: labelStyle),
                        ),
                        const SizedBox(width: 8),
                        stepper(i),
                      ],
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
      if (t.wallTileSqm > 0) lines.add(t.wallTileBreakdownLine);
      // Only when the list paints: a job of floor tiles and waterproofing
      // listed a paint area that no line is sized from.
      if (_asksPaint && t.paintSqm > 0) lines.add(t.paintLine);
      if (job.hasSkirting && t.skirtingM > 0) lines.add(t.skirtingLine);
      if (t.waterproofingSqm > 0) lines.add(t.waterproofingLine);
      warnings = _finishes ? details.warnings() : const <String>[];
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
              Expanded(child: _label('Area breakdown')),
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

  /// "1 door", "2 doors", "3 switches": read aloud for the number, so it
  /// has to be proper English. A bare "s" said "1 doors" and "2 switchs".
  static String _countLabel(int count, String noun) {
    if (count == 1) return '1 $noun';
    final plural = RegExp(r'(s|x|z|ch|sh)$').hasMatch(noun)
        ? '${noun}es'
        : '${noun}s';
    return '$count $plural';
  }

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
              semanticsLabel: _countLabel(count, noun),
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
