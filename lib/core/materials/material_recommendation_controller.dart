import 'package:flutter/foundation.dart';
import 'package:iconstruct/core/firebase/firestore_error.dart';
import 'models/material_category.dart';
import 'models/material_item.dart';
import 'services/firestore_materials_service.dart';

class MaterialRecommendationController extends ChangeNotifier {
  static const String filterAll = 'All';
  static const String filterFloor = 'Floor';
  static const String filterWall = 'Wall';

  MaterialRecommendationController({
    FirestoreMaterialsService? firestore,
    List<MaterialCategory>? initialCategories,
  }) : _firestore = firestore,
       _categories = initialCategories ?? const <MaterialCategory>[];

  final FirestoreMaterialsService? _firestore;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<MaterialCategory> _categories;
  List<MaterialCategory> get categories => _categories;

  String _selectedFilter = filterAll;
  String get selectedFilter => _selectedFilter;

  MaterialItem? selectedItem;

  final Map<String, MaterialItem?> selectedPerCategory =
      <String, MaterialItem?>{};

  void setSelectedFilter(String filter) {
    final next = filter.trim();
    if (next.isEmpty || next == _selectedFilter) return;
    _selectedFilter = next;
    notifyListeners();
  }

  String _cleanType(String? value) {
    return (value ?? '')
        .toLowerCase()
        .replaceAll('for ', '')
        .replaceAll('_', ' ')
        .trim();
  }

  bool _itemHasType(MaterialItem item, String type) {
    final target = type.toLowerCase().trim();
    final itemType = _cleanType(item.type);

    if (itemType.isEmpty) return false;
    if (itemType == 'both') return target == 'floor' || target == 'wall';

    return itemType.contains(target);
  }

  bool _itemMatchesSelectedFilter(MaterialItem item) {
    switch (_selectedFilter) {
      case filterFloor:
        return _itemHasType(item, 'floor');
      case filterWall:
        return _itemHasType(item, 'wall');
      case filterAll:
      default:
        return true;
    }
  }

  bool shouldShowCategory(MaterialCategory category) {
    if (_selectedFilter == filterAll) return true;
    return category.items.any(_itemMatchesSelectedFilter);
  }

  List<MaterialCategory> get filteredCategories {
    return List<MaterialCategory>.unmodifiable(
      _categories.where(shouldShowCategory),
    );
  }

  Future<void> loadForProject(String project) async {
    if (_firestore == null) {
      _errorMessage = 'Materials Firestore service is not configured.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _categories = await _firestore.fetchMaterialsForProject(project);
      selectedItem = null;
      selectedPerCategory.clear();
      _errorMessage = null;
    } catch (e) {
      _categories = const <MaterialCategory>[];
      _errorMessage = firestoreUserMessage(e, action: 'load material options');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectItem(MaterialItem item) {
    selectItemForCategory(item.category, item);
  }

  void selectItemForCategory(String category, MaterialItem item) {
    selectedItem = item;
    selectedPerCategory[category] = item;
    notifyListeners();
  }

  MaterialItem? getSelectedForCategory(String category) {
    return selectedPerCategory[category];
  }

  List<MaterialItem> getItemsByCategory(String category) {
    for (final cat in _categories) {
      if (cat.title == category) {
        return List<MaterialItem>.unmodifiable(
          cat.items.where(_itemMatchesSelectedFilter),
        );
      }
    }
    return const <MaterialItem>[];
  }

  void clearSelection({String? category}) {
    if (category == null) {
      selectedItem = null;
      selectedPerCategory.clear();
    } else {
      if (selectedItem?.category == category) selectedItem = null;
      selectedPerCategory.remove(category);
    }
    notifyListeners();
  }
}
