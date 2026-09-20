import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:iconstruct/features/auth/presentation/screens/cost_estimation.dart'
    show AddedTileSelection, AddedPlumbingSelection;
import 'package:iconstruct/core/firebase/firestore_error.dart';
import 'package:iconstruct/core/models/project_model.dart';
import 'package:iconstruct/core/navigation/planning_nav.dart';
import 'package:iconstruct/core/state/active_project_state.dart';
import 'package:iconstruct/core/widgets/iconstruct_panel.dart';
import 'package:iconstruct/core/widgets/offset_panel_shell.dart';
import 'package:iconstruct/features/bidding/screens/posted_project_details_screen.dart';
import 'package:iconstruct/features/bidding/data/project_post_payload.dart';
import 'package:iconstruct/features/project_creation/data/bom_export.dart';
import 'package:iconstruct/features/project_creation/data/excluded_work.dart';
import 'package:iconstruct/features/project_creation/data/material_visual.dart';
import 'package:iconstruct/features/project_creation/data/project_lifecycle.dart';
import 'package:iconstruct/features/project_creation/data/renovation_coverage.dart';
import 'package:iconstruct/features/project_creation/data/renovation_scope.dart';
import 'package:iconstruct/features/project_creation/widgets/bom_share_sheet.dart';
import 'package:iconstruct/features/project_creation/widgets/material_id_sheet.dart';
import 'package:iconstruct/features/project_creation/widgets/material_swatch.dart';
import 'package:iconstruct/core/widgets/app_message.dart';

class MaterialEstimatorScreen extends StatefulWidget {
  final String projectName;
  final List<AddedTileSelection> tiles;
  final List<AddedPlumbingSelection> plumbingMaterials;
  final ProjectModel? existingProject;
  final List<String>? aiGeneratedMaterials;
  final double? aiProjectArea;
  final String? aiBudget;
  final String? customProjectName;
  final String? projectNotes;

  /// Renovation scope chosen upstream. Persisted with the estimate so a reopened
  /// Extension is not silently treated as a Full Renovation.
  final RenovationScope scope;

  /// When true, estimate name, renovation type, area, and budget are read-only.
  final bool lockEstimateDetails;

  /// Room measurements the quantities were sized from. Saved with the estimate
  /// and the post, so the builder and the shops can see what was measured.
  final Map<String, dynamic>? siteDetails;

  /// Work the builder took out of the bill of materials on the review screen.
  /// Carried to the post so a shop quotes the list it was given and is told
  /// what was deliberately left off it.
  final List<ExcludedWork> excludedWork;

  /// How much of the space the job covers. Saved as its own field; it never
  /// goes into projectScope, which carries the renovation type and is read by
  /// the shop dashboard under that meaning.
  final RenovationCoverage coverage;

  const MaterialEstimatorScreen({
    super.key,
    required this.projectName,
    this.tiles = const [],
    this.plumbingMaterials = const [],
    this.existingProject,
    this.aiGeneratedMaterials,
    this.aiProjectArea,
    this.aiBudget,
    this.customProjectName,
    this.projectNotes,
    this.scope = RenovationScope.cosmetic,
    this.lockEstimateDetails = false,
    this.siteDetails,
    this.excludedWork = const [],
    this.coverage = RenovationCoverage.full,
  });

  @override
  State<MaterialEstimatorScreen> createState() =>
      _MaterialEstimatorScreenState();
}

class _MaterialEstimatorScreenState extends State<MaterialEstimatorScreen> {
  String? _selectedBudget;
  double _projectArea = 0.0;
  String _projectName = '';
  late String _projectType;
  final PageController _materialsPageController = PageController();

  late final TextEditingController _projectNameController;
  late final TextEditingController _projectTypeController;
  late final TextEditingController _projectAreaController;
  late final TextEditingController _remarksController;

  int _currentMaterialPage = 0;

  List<AddedTileSelection> _localTiles = [];
  List<AddedPlumbingSelection> _localPlumbing = [];
  List<String> _localMaterials = [];

  /// What the builder left out: the review screen's removals, plus anything
  /// removed here. Saved with the estimate and sent with the post.
  ///
  /// A reopened draft carries the exclusions it was saved with, so a decision
  /// made once does not have to be made again.
  late final List<ExcludedWork> _excludedWork = [
    ...widget.excludedWork,
    if (widget.excludedWork.isEmpty) ...?widget.existingProject?.excludedWork,
  ];

  int get _materialCount =>
      _localTiles.length + _localPlumbing.length + _localMaterials.length;

  /// Guards against concurrent save/post while an `await` is in flight.
  bool _busy = false;

  /// Set once a post succeeds this session so the same screen instance cannot
  /// re-post (creating a duplicate `projectPosts` doc) before it is disposed.
  bool _postedThisSession = false;

  late final String _projectScopeLabel = widget.existingProject?.projectScope ??
      widget.scope.label;

  /// A reopened estimate keeps the coverage it was saved with. An estimate
  /// saved before coverage existed reads as Full, which is what it described.
  late final RenovationCoverage _coverage =
      widget.existingProject?.coverage ?? widget.coverage;

  bool get _alreadyPosted =>
      _postedThisSession ||
      (widget.existingProject != null &&
          ProjectLifecycle.isPosted(
            widget.existingProject!.status,
            postId: widget.existingProject!.postId,
          ));

  /// A structured line (tile/plumbing) that would be sent to shops with a
  /// non-positive quantity — shows as a blank row on the quotation request.
  bool get _hasZeroQtyLine =>
      _localTiles.any((t) => !(t.quantity > 0)) ||
      _localPlumbing.any((p) => !(p.quantity > 0));

  bool get _detailsLocked => widget.lockEstimateDetails || _alreadyPosted;

  /// Whether the area came from a measured room rather than a typed figure.
  /// The BOM quantities were sized from it, so editing it here would leave
  /// the post disagreeing with the materials under it.
  bool get _areaIsMeasured =>
      widget.siteDetails != null ||
      (widget.existingProject?.hasSiteDetails ?? false);

  @override
  void initState() {
    super.initState();
    _localTiles = List.from(widget.tiles);
    _localPlumbing = List.from(widget.plumbingMaterials);

    if (widget.aiGeneratedMaterials != null) {
      _localMaterials.addAll(widget.aiGeneratedMaterials!);
    }

    if (widget.aiProjectArea != null && widget.aiProjectArea! > 0) {
      _projectArea = widget.aiProjectArea!;
    }

    if (widget.aiBudget != null) {
      final budgetLower = widget.aiBudget!.toLowerCase();
      if (budgetLower.contains('low')) {
        _selectedBudget = 'Low Budget';
      } else if (budgetLower.contains('high')) {
        _selectedBudget = 'High Budget';
      } else {
        _selectedBudget = 'Mid Budget';
      }
    }

    if (widget.existingProject != null) {
      _projectName = widget.existingProject!.projectName;
      _projectType = widget.existingProject!.projectType;
      _projectArea = widget.existingProject!.projectArea;

      final costLvl = widget.existingProject!.costLevel.toLowerCase();
      if (costLvl.contains('low')) {
        _selectedBudget = 'Low Budget';
      } else if (costLvl.contains('high')) {
        _selectedBudget = 'High Budget';
      } else {
        _selectedBudget = 'Mid Budget';
      }

      _localMaterials = List<String>.from(
        widget.existingProject!.materials
            .map((m) => m is Map ? (m['name'] ?? '').toString() : m.toString())
            .where((s) => s.isNotEmpty),
      );
    } else {
      _projectType = widget.projectName;
      if (widget.customProjectName != null &&
          widget.customProjectName!.trim().isNotEmpty) {
        _projectName = widget.customProjectName!.trim();
      }
    }

    _projectNameController = TextEditingController(text: _projectName);
    _projectTypeController = TextEditingController(text: _projectType);
    _projectAreaController = TextEditingController(
      text: _projectArea > 0 ? _projectArea.toString() : '',
    );
    _remarksController = TextEditingController(
      text: widget.projectNotes?.trim() ?? '',
    );
  }

  @override
  void dispose() {
    _projectNameController.dispose();
    _projectTypeController.dispose();
    _projectAreaController.dispose();
    _remarksController.dispose();
    _materialsPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OffsetPanelShell(
      extent: OffsetPanelExtent.scrollBody,
      wrapPanel: false,
      activeNav: OffsetNavTab.finalize,
      header: OffsetPanelHeaders.backAndAvatar(context),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildContentCard(context),
          const SizedBox(height: 20),
          _buildFinalizeCard(context),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildContentCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: IConstructPanel.contentPaddingOf(context),
      decoration: BoxDecoration(
        color: IConstructPanel.darkBlue,
        borderRadius: IConstructPanel.offsetRadiusOf(context),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 15,
            offset: Offset(-5, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _alreadyPosted
                ? 'Review Bill of\nMaterials'
                : 'Review Bill of\nMaterials',
            style: GoogleFonts.poppins(
              fontSize: 26,
              height: 1.15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _alreadyPosted
                ? 'This estimate is posted for quotations. The material list is locked so shops quote the same BOM.'
                : 'Finalize your material plan before requesting supplier quotations.',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: const Color(0xFFE0D7C9),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          const Divider(color: Color(0xFFEDE4D4), thickness: 1),
          const SizedBox(height: 14),
          _buildProcedureSteps(),
          const SizedBox(height: 18),
          const Divider(color: Color(0xFFEDE4D4), thickness: 1),
          const SizedBox(height: 16),
          Text(
            'Estimate Details',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          _buildInputLabel('Estimate Name:'),
          _buildTextField(
            'e.g., Modern Kitchen Materials',
            controller: _projectNameController,
            readOnly: _detailsLocked,
            onChanged: _detailsLocked
                ? null
                : (val) {
                    setState(() {
                      _projectName = val;
                    });
                  },
          ),
          const SizedBox(height: 14),
          _buildInputLabel('Renovation Type:'),
          _buildTextField(
            'e.g., Kitchen Renovation',
            controller: _projectTypeController,
            readOnly: _detailsLocked,
            onChanged: _detailsLocked
                ? null
                : (val) {
                    setState(() {
                      _projectType = val;
                    });
                  },
          ),
          const SizedBox(height: 14),
          // A measured room already set this area, and the BOM quantities were
          // sized from it. Letting it be edited here would leave the number on
          // the post disagreeing with the quantities under it.
          _buildInputLabel(
            _areaIsMeasured
                ? 'Project Area (sqm) — measured from the room:'
                : _detailsLocked
                    ? 'Project Area (sqm):'
                    : 'Project Area (sqm) — optional:',
          ),
          _buildTextField(
            '0.00',
            controller: _projectAreaController,
            readOnly: _detailsLocked || _areaIsMeasured,
            onChanged: _detailsLocked || _areaIsMeasured
                ? null
                : (val) {
                    setState(() {
                      _projectArea = double.tryParse(val) ?? 0.0;
                    });
                  },
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 14),
          _buildInputLabel(
            _alreadyPosted ||
                    (widget.lockEstimateDetails &&
                        (widget.aiBudget?.trim().isNotEmpty ?? false))
                ? 'Budget Preference:'
                : 'Budget Preference — optional:',
          ),
          _buildDropdownField(
            readOnly: _alreadyPosted ||
                (widget.lockEstimateDetails &&
                    (widget.aiBudget?.trim().isNotEmpty ?? false)),
          ),
          const SizedBox(height: 14),
          _buildInputLabel(
            _alreadyPosted
                ? 'Remarks for suppliers:'
                : 'Remarks for suppliers — optional:',
          ),
          _buildTextField(
            'Brand preferences or scope remarks',
            controller: _remarksController,
            maxLines: 3,
            readOnly: _alreadyPosted,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              // Expanded so the heading gives way to the item count on a
              // narrow phone instead of pushing it out of the panel.
              Expanded(
                child: Text(
                  'Bill of Materials',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$_materialCount items',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF8FB2D4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _alreadyPosted
                ? 'This list is locked. Shops are quoting these materials.'
                : 'Confirm materials and quantities. Prices come from supplier quotations.',
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: const Color(0xFFE0D7C9),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          if (_materialCount == 0)
            Text(
              'No materials in this plan yet. Go back and load a template or AI BOM.',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xFFE0D7C9),
              ),
            )
          else
            _buildSelectedMaterialsSlider(),
        ],
      ),
    );
  }

  Widget _buildProcedureSteps() {
    const steps = [
      ('1', 'Review details'),
      ('2', 'Confirm BOM'),
      ('3', 'Save or request quotes'),
    ];

    return Row(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 1.5,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                color: const Color(0xFFEDE4D4).withValues(alpha: 0.35),
              ),
            ),
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE4D4).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFEDE4D4)),
                ),
                child: Text(
                  steps[i].$1,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFEDE4D4),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: 72,
                child: Text(
                  steps[i].$2,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: const Color(0xFFE0D7C9),
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildFinalizeCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 24, 18, 22),
      decoration: BoxDecoration(
        color: IConstructPanel.darkBlue,
        borderRadius: IConstructPanel.offsetRadiusOf(context),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 15,
            offset: Offset(-5, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Finalize &\nCanvass',
            style: GoogleFonts.poppins(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFFEDE4D4), thickness: 1),
          const SizedBox(height: 14),
          _buildSummaryRow('Materials in BOM:', '$_materialCount items'),
          const SizedBox(height: 8),
          _buildSummaryRow(
            'Renovation type:',
            _projectTypeController.text.trim().isEmpty
                ? '—'
                : _projectTypeController.text.trim(),
          ),
          const SizedBox(height: 8),
          _buildSummaryRow(
            'Area:',
            _projectArea > 0
                ? '${_projectArea.toStringAsFixed(2)} sq.m'
                : 'Not set',
          ),
          const SizedBox(height: 8),
          _buildSummaryRow(
            'Budget preference:',
            _selectedBudget ?? 'Not set',
          ),
          const SizedBox(height: 14),
          const Divider(color: Color(0xFFEDE4D4), thickness: 1),
          const SizedBox(height: 14),
          Text(
            'Pricing comes from hardware shop quotations after you request bids. This screen finalizes your material list only.',
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: const Color(0xFFE0D7C9),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          if (_alreadyPosted) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final postId = widget.existingProject?.postId;
                  if (postId == null || postId.isEmpty) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PostedProjectDetailsScreen(
                        postId: postId,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEDE4D4),
                  foregroundColor: const Color(0xFF2C3E50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  'View Quotations',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => PlanningNav.startNewEstimate(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEDE4D4),
                  side: const BorderSide(color: Color(0xFFEDE4D4)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  'Start New Estimate',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ] else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_materialCount == 0 || _busy)
                    ? null
                    : _postProjectForBidding,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEDE4D4),
                  foregroundColor: const Color(0xFF2C3E50),
                  disabledBackgroundColor:
                      const Color(0xFFEDE4D4).withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  _busy ? 'Working…' : 'Request Supplier Quotations',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _materialCount == 0 ? null : _shareMaterialList,
              icon: const Icon(Icons.ios_share_rounded, size: 18),
              label: Text(
                'Share / Print Material List',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFEDE4D4),
                side: const BorderSide(color: Color(0xFFEDE4D4)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (!_alreadyPosted)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed:
                    (_materialCount == 0 || _busy) ? null : _saveProject,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFEDE4D4),
                side: const BorderSide(color: Color(0xFFEDE4D4)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                'Save Draft',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedMaterialsSlider() {
    final List<Widget> allMaterials = [
      for (final material in _localMaterials)
        _buildStringMaterialCard(material),
      for (final tile in _localTiles) _buildTileCard(tile),
      for (final plumbing in _localPlumbing) _buildPlumbingCard(plumbing),
    ];

    final int itemsPerPage = 4;
    final int pageCount = (allMaterials.length / itemsPerPage).ceil();

    return Column(
      children: [
        SizedBox(
          height:
              480, // Adjust height to fit up to 4 items per page comfortably
          child: PageView.builder(
            controller: _materialsPageController,
            onPageChanged: (index) {
              setState(() {
                _currentMaterialPage = index;
              });
            },
            itemCount: pageCount,
            itemBuilder: (context, pageIndex) {
              final startIndex = pageIndex * itemsPerPage;
              final endIndex = (startIndex + itemsPerPage < allMaterials.length)
                  ? startIndex + itemsPerPage
                  : allMaterials.length;
              final items = allMaterials.sublist(startIndex, endIndex);

              return Column(
                children: items
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: item,
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ),
        if (pageCount > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              pageCount,
              (index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentMaterialPage == index
                      ? const Color(0xFFEDE4D4)
                      : const Color(0xFFEDE4D4).withAlpha(100),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: const Color(0xFFE0D7C9),
            ),
          ),
        ),
        Expanded(
          flex: 6,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _saveProject() async {
    if (_busy) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        showAppMessage(context,
          const SnackBar(content: Text('Please log in to save projects')),
        );
      }
      return;
    }

    if (_alreadyPosted) {
      if (mounted) {
        showAppMessage(
          context,
          const SnackBar(
            content: Text(
              'This estimate is already posted. The material list cannot be changed.',
            ),
          ),
        );
      }
      return;
    }

    if (_projectName.trim().isEmpty) {
      if (mounted) {
        showAppMessage(context, 
          const SnackBar(content: Text('Please enter an Estimate Name')),
        );
      }
      return;
    }

    setState(() => _busy = true);
    try {
      await user.getIdToken(true);
      final materialsList = _buildMaterialMaps();

      // Convert selectedBudget strings to expected costLevel logic
      String costLevel = 'medium';
      if (_selectedBudget != null) {
        if (_selectedBudget!.toLowerCase().contains('low')) {
          costLevel = 'low';
        } else if (_selectedBudget!.toLowerCase().contains('high')) {
          costLevel = 'high';
        }
      }

      final Map<String, dynamic> projectData = {
        'projectName': _projectName,
        'projectType': _projectType,
        'costLevel': costLevel,
        'projectScope': _projectScopeLabel,
        // Its own field. projectScope means the renovation type, both here and
        // on the shop dashboard, and must keep meaning that.
        'coverage': _coverage.name,
        'materials': materialsList,
        'materialsCount': materialsList.length,
        'totalAreaSqm': _projectArea,
        if (widget.siteDetails != null) 'siteDetails': widget.siteDetails,
        if (_excludedWork.isNotEmpty)
          'excludedWork': ExcludedWork.listToMaps(_excludedWork),
        'status': widget.existingProject?.status ?? ProjectLifecycle.draft,
        'updatedAt': FieldValue.serverTimestamp(),
        if (widget.existingProject == null)
          'createdAt': FieldValue.serverTimestamp(),
        if (_remarksController.text.trim().isNotEmpty)
          'projectNotes': _remarksController.text.trim(),
      };

      final savedRef = widget.existingProject != null
          ? FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('saved_projects')
              .doc(widget.existingProject!.id)
          : FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('saved_projects')
              .doc();

      await savedRef.set(projectData, SetOptions(merge: true));

      if (mounted) {
        showAppMessage(
          context,
          const SnackBar(
            content: Text('Draft saved. You can request quotations anytime.'),
          ),
          kind: AppMessageKind.success,
        );
        // By using `push` instead of `pushReplacement`, the current screen
        // stays in the navigation stack, preserving values. When the user taps
        // "Back" on SavedProjectsScreen, they will perfectly return here.
        await PlanningNav.openSavedProjects(context);
      }
    } catch (e) {
      if (mounted) {
        showAppMessage(context,
          SnackBar(
            content: Text(firestoreUserMessage(e, action: 'save this draft')),
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Material rows shared by saving, posting, and the shareable canvass sheet.
  List<Map<String, dynamic>> _buildMaterialMaps() {
    return [
      ..._localMaterials.map(
        (name) => {
          'name': name,
          'quantity': 0,
          'unit': '',
          'size': null,
          'category': 'Material',
        },
      ),
      ..._localTiles.map(
        (t) => {
          'name': t.tileTypeName,
          'quantity': t.quantity,
          'unit': 'Qty.',
          'size': t.tileSizeName,
          'category': 'Tiles',
        },
      ),
      ..._localPlumbing.map(
        (p) => {
          'name': p.materialName,
          'quantity': p.quantity,
          'unit': p.unit,
          'size': p.size,
          'category': p.categoryTitle,
        },
      ),
    ];
  }

  Future<void> _shareMaterialList() async {
    await showBomShareSheet(
      context,
      BomExportData.fromMaterials(
        estimateName: _projectName.trim().isEmpty
            ? _projectType
            : _projectName.trim(),
        renovationType: _projectType,
        areaSqm: _projectArea,
        budgetPreference: _selectedBudget,
        notes: _remarksController.text.trim().isEmpty
            ? null
            : _remarksController.text.trim(),
        materials: _buildMaterialMaps(),
        excluded: _excludedWork,
      ),
    );
  }

  Future<void> _postProjectForBidding() async {
    if (_busy) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        showAppMessage(context,
          const SnackBar(content: Text('Please log in to post projects')),
        );
      }
      return;
    }

    if (_alreadyPosted) {
      if (mounted) {
        showAppMessage(context, 
          const SnackBar(
            content: Text(
              'This estimate is already posted. Start a new plan to canvass another project.',
            ),
          ),
        );
      }
      return;
    }

    if (_projectName.trim().isEmpty) {
      if (mounted) {
        showAppMessage(context, 
          const SnackBar(content: Text('Please enter an Estimate Name')),
        );
      }
      return;
    }

    final materialsList = _buildMaterialMaps();

    if (materialsList.isEmpty) {
      if (mounted) {
        showAppMessage(context,
          const SnackBar(
            content: Text('Cannot post a project without materials'),
          ),
        );
      }
      return;
    }

    if (_hasZeroQtyLine) {
      if (mounted) {
        showAppMessage(context,
          const SnackBar(
            content: Text(
              'Set a quantity greater than 0 on every material before requesting quotations.',
            ),
          ),
        );
      }
      return;
    }

    setState(() => _busy = true);
    try {
      // Fresh ID token before security-rule checks on the batch write.
      await user.getIdToken(true);

      String costLevel = 'medium';
      if (_selectedBudget != null) {
        if (_selectedBudget!.toLowerCase().contains('low')) {
          costLevel = 'low';
        } else if (_selectedBudget!.toLowerCase().contains('high')) {
          costLevel = 'high';
        }
      }

      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      final String uid = user.uid;
      DocumentReference savedProjectRef;
      if (widget.existingProject != null) {
        savedProjectRef = firestore
            .collection('users')
            .doc(uid)
            .collection('saved_projects')
            .doc(widget.existingProject!.id);
      } else {
        savedProjectRef = firestore
            .collection('users')
            .doc(uid)
            .collection('saved_projects')
            .doc();
      }

      final DocumentReference newPostRef = firestore
          .collection('projectPosts')
          .doc();

      // The shop side reads the builder's name off the post: a quotation is a
      // reply to a person, not to a uid.
      final profile = await firestore.collection('users').doc(uid).get();
      final profileData = profile.data() ?? const <String, dynamic>{};
      final ownerName = ownerDisplayName(
        firstName: profileData['firstName']?.toString(),
        lastName: profileData['lastName']?.toString(),
        email: user.email,
      );

      final Map<String, dynamic> projectPostData = {
        ...projectPostFields(
          postId: newPostRef.id,
          userId: uid,
          projectId: savedProjectRef.id,
          projectName: _projectName,
          projectType: _projectType,
          projectScope: _projectScopeLabel,
          coverage: _coverage.name,
          ownerName: ownerName,
          materials: materialsList,
          totalAreaSqm: _projectArea,
          budget: costLevel,
          siteDetails: widget.siteDetails,
          remarks: _remarksController.text,
          excludedWork: ExcludedWork.listToMaps(_excludedWork),
        ),
        'status': 'open',
        'quotationCount': 0,
        'postedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final Map<String, dynamic> savedProjectData = {
        'projectName': _projectName,
        'projectType': _projectType,
        'costLevel': costLevel,
        'projectScope': _projectScopeLabel,
        // Its own field. projectScope means the renovation type, both here and
        // on the shop dashboard, and must keep meaning that.
        'coverage': _coverage.name,
        'materials': materialsList,
        'materialsCount': materialsList.length,
        'totalAreaSqm': _projectArea,
        if (widget.siteDetails != null) 'siteDetails': widget.siteDetails,
        if (_excludedWork.isNotEmpty)
          'excludedWork': ExcludedWork.listToMaps(_excludedWork),
        'status': ProjectLifecycle.waitingForQuotations,
        'postId': newPostRef.id,
        'postedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        if (widget.existingProject == null)
          'createdAt': FieldValue.serverTimestamp(),
        if (_remarksController.text.trim().isNotEmpty)
          'projectNotes': _remarksController.text.trim(),
      };

      // Merge-safe write so a missing draft doc cannot fail the whole batch.
      batch.set(savedProjectRef, savedProjectData, SetOptions(merge: true));
      batch.set(newPostRef, projectPostData);

      await batch.commit();
      _postedThisSession = true;

      ActiveProjectState.instance.clear();

      if (mounted) {
        showAppMessage(
          context,
          const SnackBar(
            content: Text(
              'BOM sent to hardware shops. Waiting for supplier quotations.',
            ),
          ),
          kind: AppMessageKind.success,
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                PostedProjectDetailsScreen(postId: newPostRef.id),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showAppMessage(context,
          SnackBar(
            content: Text(
              firestoreUserMessage(e, action: 'request supplier quotations'),
            ),
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 13,
          color: const Color(0xFFE0D7C9),
        ),
      ),
    );
  }

  Widget _buildTextField(
    String hintText, {
    TextEditingController? controller,
    ValueChanged<String>? onChanged,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool readOnly = false,
  }) {
    return Container(
      constraints: BoxConstraints(minHeight: maxLines > 1 ? 88 : 48),
      decoration: BoxDecoration(
        color: readOnly
            ? const Color(0xFFEDE4D4).withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFEDE4D4).withValues(alpha: readOnly ? 0.45 : 1),
          width: 1,
        ),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        readOnly: readOnly,
        enableInteractiveSelection: !readOnly,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: GoogleFonts.poppins(
          color: Colors.white.withValues(alpha: readOnly ? 0.85 : 1),
          fontSize: 14,
        ),
        decoration: InputDecoration(
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: maxLines > 1 ? 12 : 0,
          ),
          border: InputBorder.none,
          hintText: hintText,
          hintStyle: GoogleFonts.poppins(
            color: const Color(0xFFEDE4D4).withAlpha(153),
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownField({bool readOnly = false}) {
    return Container(
      // Minimum height, not fixed: the value grows with the text scale.
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: readOnly
            ? const Color(0xFFEDE4D4).withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFEDE4D4).withValues(alpha: readOnly ? 0.45 : 1),
          width: 1,
        ),
      ),
      child: readOnly
          ? Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _selectedBudget ?? 'Not set',
                style: GoogleFonts.poppins(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 14,
                ),
              ),
            )
          : DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedBudget,
                isExpanded: true,
                dropdownColor: const Color(0xFF2C3E50),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.white,
                ),
                hint: Text(
                  'Select budget range',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFFEDE4D4).withAlpha(153),
                    fontSize: 14,
                  ),
                ),
                items: ['Low Budget', 'Mid Budget', 'High Budget'].map((
                  String value,
                ) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      value,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _selectedBudget = newValue;
                  });
                },
              ),
            ),
    );
  }

  Widget _buildStringMaterialCard(String material) {
    return SelectedMaterialCard(
      name: material,
      category: 'Material',
      quantity: 0,
      projectArea: _projectArea,
      onRemove: _alreadyPosted
          ? null
          : () {
              setState(() {
                _localMaterials.remove(material);
                _excludedWork.insert(0, ExcludedWork(name: material));
              });
            },
    );
  }

  Widget _buildTileCard(AddedTileSelection tile) {
    return SelectedMaterialCard(
      name: tile.tileTypeName,
      category: 'Tiles',
      kind: tile.tileSizeGroup,
      size: tile.tileSizeName,
      quantity: tile.quantity,
      projectArea: _projectArea,
      onRemove: _alreadyPosted
          ? null
          : () {
              setState(() {
                _localTiles.remove(tile);
                _excludedWork.insert(
                  0,
                  ExcludedWork(
                    name: tile.tileTypeName,
                    category: 'Tiles',
                    size: tile.tileSizeName,
                    quantity: tile.quantity,
                    unit: 'pcs',
                  ),
                );
              });
            },
    );
  }

  Widget _buildPlumbingCard(AddedPlumbingSelection plumbing) {
    return SelectedMaterialCard(
      name: plumbing.materialName,
      category: plumbing.categoryTitle,
      kind: plumbing.kind,
      size: plumbing.size,
      length: plumbing.length,
      quantity: plumbing.quantity,
      projectArea: _projectArea,
      onRemove: _alreadyPosted
          ? null
          : () {
              setState(() {
                _localPlumbing.remove(plumbing);
                _excludedWork.insert(
                  0,
                  ExcludedWork(
                    name: plumbing.materialName,
                    category: plumbing.categoryTitle,
                    size: plumbing.size,
                    unit: plumbing.unit,
                    quantity: plumbing.quantity,
                  ),
                );
              });
            },
    );
  }

}

class SelectedMaterialCard extends StatelessWidget {
  final String name;
  final String category;
  final String? kind;
  final String? size;
  final String? length;
  final double quantity;
  final double projectArea;
  final VoidCallback? onRemove;

  const SelectedMaterialCard({
    super.key,
    required this.name,
    required this.category,
    this.kind,
    this.size,
    this.length,
    required this.quantity,
    this.projectArea = 0.0,
    this.onRemove,
  });

  double autoComputeQuantity() {
    if (projectArea <= 0) return 0;

    final cat = category.toLowerCase();
    if (cat == 'tiles' || cat == 'flooring' || cat == 'floor surface') {
      double tileWidth = 0.6;
      double tileHeight = 0.6;
      if (size != null && size!.trim().isNotEmpty) {
        final match = RegExp(r'(\d+)\s*[×xX]\s*(\d+)').firstMatch(size!);
        if (match != null) {
          tileWidth = (double.tryParse(match.group(1)!) ?? 600) / 1000;
          tileHeight = (double.tryParse(match.group(2)!) ?? 600) / 1000;
        }
      }
      double tileArea = tileWidth * tileHeight;
      if (tileArea == 0) return 0;
      double tilesNeeded = projectArea / tileArea;
      return (tilesNeeded * 1.10).ceilToDouble(); // 10% allowance
    } else if (cat.contains('plumb') ||
        cat.contains('pipes') ||
        cat.contains('wiring')) {
      return projectArea * 1.5;
    } else if (cat.contains('fixtures')) {
      return 1;
    }
    return 0;
  }

  double getFinalQuantity() {
    if (quantity > 0) {
      return quantity;
    } else {
      return autoComputeQuantity();
    }
  }

  String getUnit(String category) {
    if (category.toLowerCase().contains('plumb')) return 'meters';
    switch (category.toLowerCase()) {
      case 'tiles':
      case 'flooring':
      case 'floor surface':
        return 'pcs';
      case 'plumbing':
      case 'pipes':
      case 'wiring':
        return 'meters';
      case 'fixtures':
        return 'pcs';
      case 'paint':
        return 'liters';
      default:
        return 'pcs';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDE4D4), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Last visual check before the BOM is posted for quotations.
              Semantics(
                button: true,
                label: 'Show what $name looks like',
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => showMaterialIdSheet(
                    context,
                    name: name,
                    category: category,
                    unit: getUnit(category),
                    quantity: getFinalQuantity(),
                    size: size,
                  ),
                  child: MaterialSwatch(
                    visual: MaterialVisual.forItem(
                      name: name,
                      category: category,
                      unit: getUnit(category),
                    ),
                    size: size,
                    dimension: 40,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              if (onRemove != null)
                GestureDetector(
                  onTap: onRemove,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      size: 20,
                      color: Colors.redAccent.withAlpha(200),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            kind != null && kind!.isNotEmpty ? '$category • $kind' : category,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              color: Color(0xCCE0D7C9),
            ),
          ),
          const SizedBox(height: 12),

          if (size != null && size!.isNotEmpty) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Size: $size',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: Color(0xFFE0D7C9),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],

          if (length != null && length!.isNotEmpty) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Length: $length',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: Color(0xFFE0D7C9),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],

          Builder(
            builder: (context) {
              final finalQty = getFinalQuantity();

              if (finalQty > 0) {
                final qtyStr = finalQty.toStringAsFixed(
                  finalQty.truncateToDouble() == finalQty ? 0 : 2,
                );

                final isEstimated = quantity <= 0 && projectArea > 0;
                final estStr = isEstimated ? ' (estimated)' : '';

                return Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Quantity: $qtyStr',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFEDE4D4),
                        ),
                      ),
                    ),
                    Text(
                      '${getUnit(category)}$estStr',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: Color(0xCCEDE4D4),
                      ),
                    ),
                  ],
                );
              } else {
                return Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Quantity: Not set',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFEDE4D4),
                        ),
                      ),
                    ),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
