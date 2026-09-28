// Renders the app's screens at small-phone, common-phone, large-phone and
// tablet sizes, with the largest font setting the app allows, and fails on
// any overflow or unbounded layout.
//
// Text in iConstruct scales with the screen (see AppScale), so a row that fit
// at one fixed size can clip on another device. This is the check that catches
// it before a builder does.
//
// Screens that read Firebase while building run against Firebase's own test
// mocks, signed out and with no data. That checks their frame, navigation and
// empty states; the cards they fill from Firestore are covered through the
// widgets they are built from, further down.
//
// A fixed-size button clips its label silently, with no overflow error, so
// this test cannot see that case. Buttons use minimum sizes instead.
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:iconstruct/core/layout/app_scale.dart';
import 'package:iconstruct/features/auth/presentation/models/ranked_shop.dart';
import 'package:iconstruct/features/auth/presentation/models/shop_rating.dart';
import 'package:iconstruct/features/auth/presentation/services/shop_rating_service.dart';
import 'package:iconstruct/features/auth/presentation/widgets/otp_dialog.dart';
import 'package:iconstruct/features/auth/presentation/widgets/rate_shop_sheet.dart';
import 'package:iconstruct/features/auth/presentation/widgets/shop_storefront_sheet.dart';
import 'package:iconstruct/features/bidding/data/partial_acceptance.dart';
import 'package:iconstruct/features/bidding/widgets/accepted_lines_panel.dart';
import 'package:iconstruct/features/bidding/widgets/cancel_selection_sheet.dart';
import 'package:iconstruct/features/bidding/widgets/counter_offers_panel.dart';
import 'package:iconstruct/features/chat/data/chat_attachment_service.dart';
import 'package:iconstruct/features/chat/widgets/attachment_confirm_sheet.dart';
import 'package:iconstruct/features/chat/widgets/message_list.dart';
import 'package:iconstruct/features/project_creation/data/bom_export.dart';
import 'package:iconstruct/features/project_creation/widgets/bom_share_sheet.dart';
import 'package:iconstruct/features/project_creation/widgets/material_id_sheet.dart';
import 'package:iconstruct/core/state/user_state/user_provider.dart';
import 'package:iconstruct/features/auth/presentation/screens/main_home_screen.dart';
import 'package:iconstruct/features/auth/presentation/screens/material_estimator.dart';
import 'package:iconstruct/features/auth/presentation/screens/profile_screen.dart';
import 'package:iconstruct/features/auth/presentation/screens/saved_projects.dart';
import 'package:iconstruct/features/auth/presentation/screens/top_shops_screen.dart';
import 'package:iconstruct/features/bidding/screens/posted_project_details_screen.dart';
import 'package:iconstruct/features/bidding/screens/project_bids_screen.dart';
import 'package:iconstruct/features/bidding/screens/quotations_screen.dart';
import 'package:iconstruct/features/chat/screens/chat_inbox_screen.dart';
import 'package:iconstruct/features/chat/screens/chat_thread_screen.dart';
import 'package:iconstruct/features/notifications/screens/notifications_screen.dart';
import 'package:iconstruct/features/project_creation/screens/project_tracking_screen.dart';
import 'package:iconstruct/features/auth/presentation/screens/change_password_screen.dart';
import 'package:iconstruct/features/auth/presentation/screens/cost_estimation.dart';
import 'package:iconstruct/features/auth/presentation/screens/edit_profile_screen.dart';
import 'package:iconstruct/features/auth/presentation/screens/email_verification_screen.dart';
import 'package:iconstruct/features/auth/presentation/screens/forgot_password_otp_screen.dart';
import 'package:iconstruct/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:iconstruct/features/auth/presentation/screens/home_screen.dart';
import 'package:iconstruct/features/auth/presentation/screens/login_screen.dart';
import 'package:iconstruct/features/auth/presentation/screens/register_screen.dart';
import 'package:iconstruct/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:iconstruct/features/auth/presentation/screens/terms_conditions_screen.dart';
import 'package:iconstruct/features/bidding/data/post_load_outcome.dart';
import 'package:iconstruct/features/bidding/screens/bidding_hub_screen.dart';
import 'package:iconstruct/features/bidding/widgets/estimate_unavailable_view.dart';
import 'package:iconstruct/features/bidding/widgets/line_selection_sheet.dart';
import 'package:iconstruct/features/onboarding/presentation/screens/display_screen.dart';
import 'package:iconstruct/features/onboarding/presentation/screens/landing_screen.dart';
import 'package:iconstruct/features/onboarding/presentation/screens/main_display.dart';
import 'package:iconstruct/features/project_creation/data/ai_material_consultant_service.dart';
import 'package:iconstruct/features/project_creation/data/bom_quantity_estimator.dart';
import 'package:iconstruct/features/project_creation/data/renovation_coverage.dart';
import 'package:iconstruct/features/project_creation/data/renovation_scope.dart';
import 'package:iconstruct/features/project_creation/data/renovation_templates.dart';
import 'package:iconstruct/features/project_creation/data/site_details.dart';
import 'package:iconstruct/features/project_creation/screens/ai_consultation_screen.dart';
import 'package:iconstruct/features/project_creation/screens/ai_recommendations_screen.dart';
import 'package:iconstruct/features/project_creation/screens/create_project_screen.dart';
import 'package:iconstruct/features/project_creation/screens/select_planning_method_screen.dart';
import 'package:iconstruct/features/project_creation/screens/describe_project_screen.dart';
import 'package:iconstruct/features/project_creation/screens/select_renovation_type_screen.dart';
import 'package:iconstruct/features/project_creation/screens/select_work_items_screen.dart';
import 'package:iconstruct/features/project_creation/screens/template_area_screen.dart';

/// Portrait phones from the smallest still in use to the largest, plus a
/// tablet. The app is locked to portrait, so landscape is not listed.
const _sizes = <String, Size>{
  'iPhone SE 1st gen 320x568': Size(320, 568),
  'small Android 360x640': Size(360, 640),
  'iPhone SE 375x667': Size(375, 667),
  'common Android 360x780': Size(360, 780),
  'iPhone 14 390x844': Size(390, 844),
  'Pixel 412x915': Size(412, 915),
  'iPhone Pro Max 430x932': Size(430, 932),
  'tablet 800x1280': Size(800, 1280),
};

/// Status bar or notch (top) and home indicator or gesture bar (bottom) on
/// each device, in logical pixels. They take height from every screen, and
/// a screen that ignores them puts its header under the notch.
const _safeAreas = <String, (double top, double bottom)>{
  'iPhone SE 1st gen 320x568': (20, 0),
  'small Android 360x640': (24, 0),
  'iPhone SE 375x667': (20, 0),
  'common Android 360x780': (24, 16),
  'iPhone 14 390x844': (47, 34),
  'Pixel 412x915': (32, 16),
  'iPhone Pro Max 430x932': (59, 34),
  'tablet 800x1280': (24, 16),
};

/// The largest phone font setting AppScale honours.
const double _userTextScale = AppScale.maxUserTextScale;

bool _isLayoutError(String message) =>
    message.contains('overflowed') ||
    message.contains('was not laid out') ||
    message.contains('unbounded') ||
    message.contains('infinite size') ||
    message.contains('BoxConstraints forces an infinite');

String _describe(FlutterErrorDetails details) {
  final full = details.toString();
  final first = details.exceptionAsString().split('\n').first.trim();
  final where = RegExp(r'file:///\S*?(lib/[^\s:]+):(\d+)').firstMatch(full);
  return where == null ? first : '$first  @ ${where.group(1)}:${where.group(2)}';
}

/// Loads the app's bundled fonts under the names the screens ask for.
///
/// Without this every glyph renders in the test font, a solid square as wide
/// as the font size, which is far wider than Poppins and reports overflows
/// that never happen on a phone. google_fonts registers each weight as its own
/// family (`Poppins_700`), so each of those names is pointed at the bundled
/// file. Only Poppins Light is bundled, which runs a little narrower than the
/// bold weights, so the check is close to the device rather than exact.
Future<void> _loadAppFonts() async {
  Future<void> load(String family, String asset) async {
    final loader = FontLoader(family)..addFont(rootBundle.load(asset));
    await loader.load();
  }

  const poppins = 'assets/fonts/Poppins-Light.ttf';
  const inter = 'assets/fonts/Inter-VariableFont_opsz,wght.ttf';
  await load('Poppins', poppins);
  await load('Inter', inter);
  await load('Bungee-Regular', 'assets/fonts/Bungee-Regular.ttf');
  await load('Boldonse-Regular', 'assets/fonts/Boldonse-Regular.ttf');

  final variants = <String>[
    'regular',
    'italic',
    for (var weight = 100; weight <= 900; weight += 100) ...[
      '$weight',
      '${weight}italic',
    ],
  ];
  for (final variant in variants) {
    await load('Poppins_$variant', poppins);
    await load('Inter_$variant', inter);
  }
}

const _typesOnTimers = {'AIConsultationScreen'};

/// Height an on-screen keyboard takes on a phone, in logical pixels.
const double _keyboardHeight = 300;

/// Screens with a text field are checked again with the keyboard open on the
/// smallest phones. The keyboard takes half of a 568-point screen, which is
/// where a form that fits with the keyboard closed runs out of room.
const _keyboardSizes = <String, Size>{
  'iPhone SE 1st gen 320x568': Size(320, 568),
  'iPhone SE 375x667': Size(375, 667),
};

/// Answers at once with a fixed set of picks, so the recommendations screen
/// renders its list without calling the Cloud Function.
class _FakeAiService extends AiMaterialConsultantService {
  _FakeAiService(this.picks);

  final List<AiWorkPick> picks;

  @override
  Future<AiWorkRecommendResult> recommendWork({
    required String projectType,
    required String scope,
    required String description,
    required WorkCatalogue catalogue,
  }) async =>
      AiWorkRecommendResult(success: true, picks: picks);
}

/// Opens a sheet or dialog as soon as it is on screen, the way a tap would.
class _OpensOnStart extends StatefulWidget {
  const _OpensOnStart(this.open);

  final void Function(BuildContext context) open;

  @override
  State<_OpensOnStart> createState() => _OpensOnStartState();
}

class _OpensOnStartState extends State<_OpensOnStart> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.open(context));
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: SizedBox.expand());
}

/// The smallest valid PNG, standing in for a picked photo.
final _onePixelPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// A builder who bought from the shop on two estimates and has not rated it.
class _FakeRatingService implements ShopRatingService {
  @override
  Future<List<({String postId, String title})>> ratableProjects(
    String shopId,
  ) async =>
      const [
        (postId: 'post-1', title: 'Dela Cruz ground-floor bathroom, Calamba'),
        (postId: 'post-2', title: 'Kitchen Renovation (remaining lines)'),
      ];

  @override
  Future<ShopRatingDraft?> myRating(String shopId) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _longShop = RankedShop(
  uid: 'shop-1',
  shopName: 'Santo Niño Construction Supply and Hardware',
  address: 'Km. 52 National Highway corner J.P. Rizal Street',
  barangay: 'Barangay Real',
  city: 'Calamba City',
  subscriptionPlan: 'business',
  quotationCount: 128,
  suppliedCategories: const [
    'Cement & Aggregates',
    'Tiles & Adhesives',
    'Plumbing Fixtures',
    'Electrical Wiring',
    'Paint & Finishes',
  ],
  description:
      'Family-run hardware serving Laguna since 1987. Same-day delivery '
      'within Calamba for orders placed before noon.',
  businessHours: 'Mon to Sat, 7:00 AM to 6:00 PM',
  coverageCities: const ['Calamba', 'Los Baños', 'Cabuyao', 'Santa Rosa'],
  storefrontAbout: 'Bulk discounts on 50 bags of cement and up.',
  phone: '0917 123 4567',
  rating: const ShopRating(average: 4.6, count: 37),
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Tests have no network, and the fonts are loaded from the bundle below.
    GoogleFonts.config.allowRuntimeFetching = false;
    await _loadAppFonts();
    // Screens that read Firebase build against its test mocks: signed out,
    // no data.
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  final bathroom =
      RenovationTemplatesCatalog.forProject(
          'Bathroom Renovation', RenovationScope.structural);
  final extensionBom = bathroom.copyWithItems(
    BomQuantityEstimator.scaleTemplate(
      template: bathroom,
      areaSqm: 20,
      scope: RenovationScope.structural,
    ),
  );
  final measuredTakeoff = SiteTakeoff.from(
    const SiteDetails(
      job: RoomJob.wetRoom,
      lengthM: 2.0,
      widthM: 1.5,
      heightM: 2.4,
      doors: [Opening(widthM: 0.70, heightM: 2.10)],
      windows: [Opening(widthM: 0.60, heightM: 0.60)],
      wallTileHeight: WallTileHeight.wainscot,
      removeOldTiles: true,
      paintCeiling: true,
    ),
  );
  final measuredBom = bathroom.copyWithItems(
    BomQuantityEstimator.scaleTemplate(
      template: bathroom,
      areaSqm: measuredTakeoff.floorSqm,
      takeoff: measuredTakeoff,
    ),
  );
  List<AddedPlumbingSelection> estimateLines() => [
        for (final item in extensionBom.items)
          AddedPlumbingSelection(
            categoryTitle: item.category,
            kind: 'Tap / drop to change type',
            materialName: item.name,
            size: item.size,
            unit: item.unit,
            quantity: item.defaultQuantity,
          ),
      ];
  final kitchen =
      RenovationTemplatesCatalog.forProject(
          'Kitchen Renovation', RenovationScope.cosmetic);

  final screens = <String, Widget Function()>{
    'DisplayScreen': () => const DisplayScreen(),
    'LandingScreen': () => const LandingScreen(),
    'MainDisplayScreen': () => const MainDisplayScreen(),
    'TermsConditionsScreen': () => const TermsConditionsScreen(),
    'ChangePasswordScreen': () => const ChangePasswordScreen(),
    'EditProfileScreen': () => const EditProfileScreen(
          firstName: 'Juan Miguel',
          lastName: 'Dela Cruz',
        ),
    'HomeScreen': () => const HomeScreen(),
    'CreateProjectScreen': () =>
        const CreateProjectScreen(renovationType: 'Bathroom Renovation'),
    'SelectPlanningMethodScreen': () =>
        const SelectPlanningMethodScreen(projectName: 'Bathroom Renovation'),
    'SelectRenovationTypeScreen': () => const SelectRenovationTypeScreen(
          renovationType: 'Interior Painting',
        ),
    // Structural is ticked by default here, so the disclaimer renders.
    'SelectRenovationTypeScreen (structural ticked)': () =>
        const SelectRenovationTypeScreen(renovationType: 'Roof Repair'),
    'DescribeProjectScreen (AI)': () => const DescribeProjectScreen(
          projectName: 'Bathroom Renovation',
          scope: RenovationScope.functional,
          method: PlanningMethod.ai,
        ),
    'TemplateAreaScreen (functional)': () => TemplateAreaScreen(
          template: RenovationTemplatesCatalog.forProject(
              'Kitchen Renovation', RenovationScope.functional),
          projectName: 'Kitchen Renovation',
          scope: RenovationScope.functional,
        ),
    'TemplateAreaScreen': () => TemplateAreaScreen(
          template: bathroom,
          projectName: 'Bathroom Renovation',
        ),
    'CostEstimationScreen': () => CostEstimationScreen(
          projectName: 'Bathroom Renovation',
          template: extensionBom,
          projectAreaSqm: 20,
          scope: RenovationScope.structural,
        ),
    'TemplateAreaScreen (kitchen site details)': () => TemplateAreaScreen(
          template: kitchen,
          projectName: 'Kitchen Renovation',
        ),
    'TemplateAreaScreen (partial)': () => TemplateAreaScreen(
          template: kitchen,
          projectName: 'Kitchen Renovation',
          coverage: RenovationCoverage.partial,
        ),
    'TemplateAreaScreen (roof area)': () => TemplateAreaScreen(
          template:
              RenovationTemplatesCatalog.forProject(
              'Roof Repair', RenovationScope.cosmetic),
          projectName: 'Roof Repair',
        ),
    'CostEstimationScreen (measured room)': () => CostEstimationScreen(
          projectName: 'Bathroom Renovation',
          template: measuredBom,
          projectAreaSqm: measuredTakeoff.floorSqm,
          takeoff: measuredTakeoff,
        ),
    // Structural work ticked from the start, so the disclaimer renders too.
    'SelectWorkItemsScreen': () => SelectWorkItemsScreen(
          catalogue: RenovationTemplatesCatalog.workCatalogueFor(
              'Bathroom Renovation'),
          projectName: 'Bathroom Renovation',
          types: RenovationTypes([
            RenovationScope.cosmetic,
            RenovationScope.structural,
            RenovationScope.functional,
          ]),
        ),
    'TemplateAreaScreen (work items)': () => TemplateAreaScreen(
          template: RenovationTemplatesCatalog.workCatalogueFor(
                  'Bathroom Renovation')
              .templateFor({'retile_floor', 'replace_toilet'}),
          projectName: 'Bathroom Renovation',
        ),
    // A room with the most kinds of work ticked at once, including wiring.
    'SelectWorkItemsScreen (kitchen)': () => SelectWorkItemsScreen(
          catalogue: RenovationTemplatesCatalog.workCatalogueFor(
              'Kitchen Renovation'),
          projectName: 'Kitchen Renovation',
          types: RenovationTypes([
            RenovationScope.cosmetic,
            RenovationScope.functional,
          ]),
        ),
    'TemplateAreaScreen (kitchen work items)': () => TemplateAreaScreen(
          template: RenovationTemplatesCatalog.workCatalogueFor(
                  'Kitchen Renovation')
              .templateFor({'tile_backsplash', 'rewire'}),
          projectName: 'Kitchen Renovation',
          scope: RenovationScope.functional,
          renovationTypes: RenovationTypes([
            RenovationScope.cosmetic,
            RenovationScope.functional,
          ]),
        ),
    // Long names on both the shop and a substitute, with a note, so the
    // badge and the price have to share one line on a small phone.
    'SelectShopSheet (substitute)': () => const Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: SelectShopSheet(
              shopName: 'Santo Niño Construction Supply and Hardware',
              quotedTotal: 0,
              items: [
                {
                  'productName': 'Interior Latex Paint (4 L)',
                  'qty': 4,
                  'unit': 'gal',
                  'price': 10,
                  'subtotal': 40,
                },
                {
                  'productName': 'Mega Bond Premium Tile Adhesive Extra',
                  'requestedName': 'Tile Adhesive (25 kg)',
                  'status': 'substituted',
                  'lineNote': 'Out of stock this week; same coverage.',
                  'qty': 20,
                  'unit': 'bags',
                  'price': 343,
                  'subtotal': 6860,
                },
              ],
            ),
          ),
        ),
    'LoginScreen': () => const LoginScreen(),
    'RegisterScreen': () => const RegisterScreen(),
    'ForgotPasswordScreen': () => const ForgotPasswordScreen(),
    'ForgotPasswordOtpScreen': () => const ForgotPasswordOtpScreen(
          email: 'juan.miguel.delacruz.builder@example.com',
        ),
    'ResetPasswordScreen': () => const ResetPasswordScreen(
          email: 'juan.miguel.delacruz.builder@example.com',
          verificationToken: 'token',
        ),
    'EmailVerificationScreen': () => const EmailVerificationScreen(
          email: 'juan.miguel.delacruz.builder@example.com',
          uid: 'uid-1',
        ),
    'AIConsultationScreen': () => AIConsultationScreen(
          projectName: 'Bathroom Renovation',
          renovationTypes: RenovationTypes([
            RenovationScope.cosmetic,
            RenovationScope.structural,
          ]),
        ),
    'AiRecommendationsScreen': () => AiRecommendationsScreen(
          projectName: 'Kitchen Renovation',
          scope: RenovationScope.functional,
          renovationTypes: RenovationTypes([
            RenovationScope.cosmetic,
            RenovationScope.functional,
          ]),
          description:
              'Retile the backsplash and rewire the outlets near the sink.',
          service: _FakeAiService(const [
            AiWorkPick(
              id: 'tile_backsplash',
              reason: 'The backsplash behind the sink is cracked and stained',
            ),
            AiWorkPick(id: 'rewire', reason: 'Outlets near the sink spark'),
          ]),
        ),
    'BiddingHubScreen': () => const BiddingHubScreen(),
    'MainHomeScreen': () => const MainHomeScreen(),
    'ProfileScreen': () => const ProfileScreen(),
    'TopShopsScreen': () => const TopShopsScreen(),
    'SavedProjectsScreen': () => const SavedProjectsScreen(),
    'ProjectTrackingScreen': () => const ProjectTrackingScreen(),
    'NotificationsScreen': () => const NotificationsScreen(),
    'ChatInboxScreen': () => const ChatInboxScreen(),
    'ChatThreadScreen': () => const ChatThreadScreen(
          conversationId: 'post-1_shop-1',
          shopName: 'Santo Niño Construction Supply and Hardware',
          projectTitle: 'Bathroom Renovation (remaining lines)',
        ),
    'PostedProjectDetailsScreen': () =>
        const PostedProjectDetailsScreen(postId: 'post-1'),
    'QuotationsScreen': () => const QuotationsScreen(
          postId: 'post-1',
          projectName: 'Bathroom Renovation (remaining lines)',
        ),
    'ProjectBidsScreen': () => const ProjectBidsScreen(
          postId: 'post-1',
          projectName: 'Bathroom Renovation (remaining lines)',
        ),
    // Sheets and dialogs, opened over a blank screen with long real names.
    'CancelSelectionSheet': () => _OpensOnStart(
          (context) => showCancelSelectionSheet(
            context,
            shopName: 'Santo Niño Construction Supply and Hardware',
            otherQuotations: 3,
          ),
        ),
    'ShopStorefrontSheet': () =>
        _OpensOnStart((context) => showShopStorefrontSheet(context, _longShop)),
    'RateShopSheet': () => _OpensOnStart(
          (context) => showRateShopSheet(
            context,
            _longShop,
            ratingService: _FakeRatingService(),
          ),
        ),
    'AttachmentConfirmSheet (photo)': () => _OpensOnStart(
          (context) => showAttachmentConfirmSheet(
            context,
            attachment: PickedAttachment(
              bytes: _onePixelPng,
              name: 'scaled_IMG_20260928_101512.jpg',
              kind: AttachmentKind.image,
              sizeBytes: _onePixelPng.length,
            ),
            shopName: 'Santo Niño Construction Supply and Hardware',
            caption: 'This is the wall behind the sink, the tiles here are '
                'the ones that need replacing.',
          ),
        ),
    'AttachmentConfirmSheet (document)': () => _OpensOnStart(
          (context) => showAttachmentConfirmSheet(
            context,
            attachment: PickedAttachment(
              bytes: Uint8List(0),
              name: 'Dela-Cruz-bathroom-floor-plan-final-revision.pdf',
              kind: AttachmentKind.file,
              sizeBytes: 2411520,
            ),
            shopName: 'Santo Niño Construction Supply and Hardware',
          ),
        ),
    'BomShareSheet': () => _OpensOnStart(
          (context) => showBomShareSheet(
            context,
            BomExportData(
              estimateName: 'Dela Cruz ground-floor bathroom, Calamba',
              renovationType: 'Bathroom Renovation',
              areaSqm: 20,
              budgetPreference: 'Mid-range',
              materials: [
                for (final item in extensionBom.items)
                  BomExportItem(
                    name: item.name,
                    category: item.category,
                    quantity: item.defaultQuantity,
                    unit: item.unit,
                    size: item.size,
                  ),
              ],
            ),
          ),
        ),
    'MaterialIdSheet': () => _OpensOnStart(
          (context) => showMaterialIdSheet(
            context,
            name: 'Ceramic Wall Tiles, Matte Finish (Anti-slip)',
            category: 'Tiles & Adhesives',
            unit: 'pcs',
            quantity: 184,
            size: '30 x 60 cm',
          ),
        ),
    'OtpDialog': () => _OpensOnStart(
          (context) => showDialog<void>(
            context: context,
            builder: (_) => const OtpDialog(
              email: 'juan.miguel.delacruz.builder@example.com',
              uid: 'uid-1',
            ),
          ),
        ),
    // What a builder sees under the shop they took part of an offer from.
    'AcceptedLinesPanel': () => Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: AcceptedLinesPanel(
              summary: readAcceptance({
                'status': 'partially_accepted',
                'acceptedTotal': 8940,
                'items': [
                  {
                    'productName': 'Portland Cement (40 kg)',
                    'qty': 12,
                    'unit': 'bags',
                    'price': 260,
                    'subtotal': 3120,
                    'accepted': true,
                  },
                  {
                    'productName': 'Mega Bond Premium Tile Adhesive Extra',
                    'requestedName': 'Tile Adhesive (25 kg)',
                    'status': 'substituted',
                    'qty': 20,
                    'unit': 'bags',
                    'price': 291,
                    'subtotal': 5820,
                    'accepted': true,
                  },
                  {
                    'productName': 'Ceramic Wall Tiles, Matte (30 x 60 cm)',
                    'qty': 184,
                    'unit': 'pcs',
                    'price': 48,
                    'subtotal': 8832,
                    'accepted': false,
                  },
                ],
              }),
              quotedTotal: 17772,
              postId: 'post-1',
              quotationId: 'q-1',
              shopName: 'Santo Niño Construction Supply and Hardware',
            ),
          ),
        ),
    // One offer waiting, one taken and one turned down in the last round.
    'CounterOffersPanel': () => const Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: CounterOffersPanel(
              postId: 'post-1',
              quotationId: 'q-1',
              shopName: 'Santo Niño Construction Supply and Hardware',
              quotationData: {
                'status': 'partially_accepted',
                'items': [
                  {
                    'productName': 'Ceramic Wall Tiles, Matte (30 x 60 cm)',
                    'qty': 184,
                    'unit': 'pcs',
                    'price': 48,
                    'subtotal': 8832,
                    'accepted': false,
                    'declineReason': 'overpriced',
                    'negotiation': {
                      'shopOfferedPrice': 42.5,
                      'status': 'pending',
                      'round': 1,
                    },
                  },
                  {
                    'productName': 'Portland Cement (40 kg)',
                    'qty': 12,
                    'unit': 'bags',
                    'price': 245,
                    'subtotal': 2940,
                    'accepted': true,
                    'declineReason': 'overpriced',
                    'negotiation': {
                      'shopOfferedPrice': 245,
                      'status': 'accepted',
                      'round': 1,
                    },
                  },
                  {
                    'productName': 'Mega Bond Premium Tile Adhesive Extra',
                    'qty': 20,
                    'unit': 'bags',
                    'price': 343,
                    'subtotal': 6860,
                    'accepted': false,
                    'declineReason': 'overpriced',
                    'negotiation': {
                      'shopOfferedPrice': 330,
                      'status': 'declined',
                      'round': 2,
                    },
                  },
                ],
              },
            ),
          ),
        ),
    // A thread with long messages, a file, and a system note.
    'MessengerMessageList': () => Scaffold(
          body: MessengerMessageList(
            docs: const [
              {
                'senderRole': 'system',
                'senderId': 'system',
                'text': 'Quotation accepted for "Bathroom Renovation". You '
                    'can now message each other.',
              },
              {
                'senderRole': 'builder',
                'senderId': 'builder-1',
                'text': 'Hi! Can you deliver the 12 bags of Portland cement '
                    'and the tile adhesive to Barangay Real on Saturday '
                    'morning, before 9? The street is narrow, so a small '
                    'truck would be best.',
              },
              {
                'senderRole': 'shop',
                'senderId': 'shop-1',
                'text': 'Yes po, Saturday 8 AM works. We only have Mega Bond '
                    'in stock for the adhesive, same coverage per bag.',
              },
              {
                'senderRole': 'builder',
                'senderId': 'builder-1',
                'text': '',
                'attachment': {
                  'url': 'https://example.com/site-floor-plan.pdf',
                  'name': 'Dela-Cruz-bathroom-floor-plan-final-revision.pdf',
                  'kind': 'file',
                  'sizeBytes': 2411520,
                },
              },
            ],
            uid: 'builder-1',
            shopName: 'Santo Niño Construction Supply and Hardware',
            conversation: const {'readAt': {}},
            controller: ScrollController(),
          ),
        ),
    'MaterialEstimatorScreen': () => MaterialEstimatorScreen(
          projectName: 'Bathroom Renovation',
          customProjectName: 'Dela Cruz ground-floor bathroom, Calamba',
          plumbingMaterials: estimateLines(),
          aiProjectArea: 20,
          scope: RenovationScope.structural,
          lockEstimateDetails: true,
        ),
    'EstimateUnavailableView': () => Scaffold(
          body: EstimateUnavailableView(
            outcome: PostLoadOutcome.unavailable,
            postId: 'post-1',
            onRetry: () {},
            showBackButton: true,
          ),
        ),
  };

  const withTextFields = {
    'ChangePasswordScreen',
    'EditProfileScreen',
    'CreateProjectScreen',
    'DescribeProjectScreen (AI)',
    'TemplateAreaScreen',
    'TemplateAreaScreen (kitchen site details)',
    'LoginScreen',
    'RegisterScreen',
    'ForgotPasswordScreen',
    'ForgotPasswordOtpScreen',
    'ResetPasswordScreen',
    'EmailVerificationScreen',
    'AIConsultationScreen',
    'ChatThreadScreen',
    'MaterialEstimatorScreen',
    'CancelSelectionSheet',
    'AttachmentConfirmSheet (photo)',
    'AttachmentConfirmSheet (document)',
    'RateShopSheet',
    'OtpDialog',
  };

  for (final screen in screens.entries) {
    group(screen.key, () {
      for (final size in _sizes.entries) {
        testWidgets('fits on ${size.key}', (tester) async {
          await _expectFits(tester, screen.key, screen.value, size);
        });
      }
      if (withTextFields.contains(screen.key)) {
        for (final size in _keyboardSizes.entries) {
          testWidgets('fits on ${size.key} with the keyboard open',
              (tester) async {
            await _expectFits(tester, screen.key, screen.value, size,
                keyboard: _keyboardHeight);
          });
        }
      }
    });
  }
}

Future<void> _expectFits(
  WidgetTester tester,
  String name,
  Widget Function() build,
  MapEntry<String, Size> size, {
  double keyboard = 0,
}) async {
  tester.view.physicalSize = size.value * 3;
  tester.view.devicePixelRatio = 3;
  final (top, bottom) = _safeAreas[size.key]!;
  tester.view.padding = FakeViewPadding(top: top * 3, bottom: bottom * 3);
  tester.view.viewPadding = FakeViewPadding(top: top * 3, bottom: bottom * 3);
  if (keyboard > 0) {
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard * 3);
  }
  tester.platformDispatcher.textScaleFactorTestValue = _userTextScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  final layout = <String>{};
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    final message = _describe(details);
    if (_isLayoutError(message)) {
      layout.add(message);
    } else {
      previous?.call(details);
    }
  };

  try {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => UserProvider(),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          builder: (context, child) =>
              ResponsiveFrame(child: child ?? const SizedBox.shrink()),
          home: build(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    // The AI chat types its opening messages on timers. Other screens are not
    // given this long: the splash screen moves on to sign-in by then.
    if (_typesOnTimers.contains(name)) {
      await tester.pump(const Duration(seconds: 3));
    }

    // Let animations and delayed navigation finish before disposal.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 30));
  } finally {
    FlutterError.onError = previous;
  }

  final where = keyboard > 0 ? '${size.key}, keyboard open' : size.key;
  for (final message in layout) {
    // ignore: avoid_print
    print('LAYOUT $name [$where]: $message');
  }
  expect(layout, isEmpty, reason: '$name does not fit on $where');
}
