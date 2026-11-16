import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cbt_app/models/shop_item.dart';
import 'package:cbt_app/cubits/honour_shop/honour_shop_state.dart';

class HonourShopCubit extends Cubit<HonourShopState> {
  final SupabaseClient _client;

  HonourShopCubit(this._client) : super(const HonourShopState()) {
    loadItems();
  }

  Future<void> loadItems() async {
    emit(state.copyWith(isLoading: true, errorMessage: null));

    try {
      final rows = await _client
          .from('shop_items')
          .select()
          .order('created_at', ascending: false);

      final items = rows.map((row) => ShopItem.fromMap(row)).toList();
      emit(state.copyWith(items: items, isLoading: false));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load items: $e',
      ));
    }
  }

  void setCategory(String category) {
    emit(state.copyWith(selectedCategory: category));
  }

  void setSearchQuery(String query) {
    emit(state.copyWith(searchQuery: query));
  }

  /// Optimistic availability toggle (0ms perceived latency)
  Future<bool> toggleAvailability(ShopItem item, bool isAvailable) async {
    final previousItems = List<ShopItem>.from(state.items);

    // 1. Instant local update
    final updatedItems = state.items.map((i) {
      return i.id == item.id ? i.copyWith(isAvailable: isAvailable) : i;
    }).toList();

    emit(state.copyWith(items: updatedItems));

    // 2. Persist to Supabase RPC
    try {
      await _client.rpc(
        'set_shop_item_availability',
        params: {'p_id': item.id, 'p_is_available': isAvailable},
      );
      return true;
    } catch (e) {
      // Revert if network call fails
      emit(state.copyWith(
        items: previousItems,
        errorMessage: 'Failed to update availability: $e',
      ));
      return false;
    }
  }

  Future<bool> addItem({
    required String name,
    required double price,
    required String category,
    String? imageUrl,
  }) async {
    emit(state.copyWith(isLoading: true));
    try {
      final user = _client.auth.currentUser;
      final inserted = await _client.from('shop_items').insert({
        'name': name,
        'price': price,
        'category': category,
        'is_available': true,
        'image_url': imageUrl,
        'updated_by': user?.id,
      }).select().single();

      final newItem = ShopItem.fromMap(inserted);
      emit(state.copyWith(
        items: [newItem, ...state.items],
        isLoading: false,
      ));
      return true;
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to add item: $e',
      ));
      return false;
    }
  }

  Future<bool> editItem({
    required String id,
    required String name,
    required double price,
    required String category,
  }) async {
    final previousItems = List<ShopItem>.from(state.items);

    // Optimistic update
    final updated = state.items.map((i) {
      return i.id == id ? i.copyWith(name: name, price: price, category: category) : i;
    }).toList();
    emit(state.copyWith(items: updated));

    try {
      final user = _client.auth.currentUser;
      await _client.from('shop_items').update({
        'name': name,
        'price': price,
        'category': category,
        'updated_by': user?.id,
      }).eq('id', id);
      return true;
    } catch (e) {
      emit(state.copyWith(
        items: previousItems,
        errorMessage: 'Failed to update item: $e',
      ));
      return false;
    }
  }

  Future<bool> deleteItem(String id) async {
    final previousItems = List<ShopItem>.from(state.items);

    // Optimistic delete
    final updated = state.items.where((i) => i.id != id).toList();
    emit(state.copyWith(items: updated));

    try {
      await _client.from('shop_items').delete().eq('id', id);
      return true;
    } catch (e) {
      emit(state.copyWith(
        items: previousItems,
        errorMessage: 'Failed to delete item: $e',
      ));
      return false;
    }
  }
}
