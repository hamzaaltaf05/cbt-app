import 'package:cbt_app/models/shop_item.dart';

class HonourShopState {
  final List<ShopItem> items;
  final String selectedCategory;
  final String searchQuery;
  final bool isLoading;
  final String? errorMessage;

  const HonourShopState({
    this.items = const [],
    this.selectedCategory = 'All',
    this.searchQuery = '',
    this.isLoading = false,
    this.errorMessage,
  });

  List<ShopItem> get filteredItems {
    final list = items.where((item) {
      final matchesCategory = selectedCategory == 'All' ||
          item.category.trim().toLowerCase() ==
              selectedCategory.trim().toLowerCase();
      final matchesSearch = searchQuery.trim().isEmpty ||
          item.name.toLowerCase().contains(searchQuery.trim().toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    list.sort((a, b) {
      final scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) return scoreCompare;
      return a.name.compareTo(b.name);
    });

    return list;
  }

  HonourShopState copyWith({
    List<ShopItem>? items,
    String? selectedCategory,
    String? searchQuery,
    bool? isLoading,
    String? errorMessage,
  }) {
    return HonourShopState(
      items: items ?? this.items,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}
