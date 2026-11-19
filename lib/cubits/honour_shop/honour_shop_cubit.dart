import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cbt_app/models/shop_item.dart';
import 'package:cbt_app/cubits/honour_shop/honour_shop_state.dart';
import 'package:cbt_app/services/voting_repository.dart';

class HonourShopCubit extends Cubit<HonourShopState> {
  final SupabaseClient _client;
  final VotingRepository _votingRepository;

  HonourShopCubit(this._client, {VotingRepository? votingRepository})
      : _votingRepository = votingRepository ?? VotingRepository(client: _client),
        super(const HonourShopState()) {
    loadItems();
  }

  Future<void> loadItems() async {
    emit(state.copyWith(isLoading: true, errorMessage: null));

    try {
      final rows = await _client
          .from('shop_items')
          .select()
          .order('created_at', ascending: false);

      final userVotes = await _votingRepository.fetchUserVotes(
        targetType: 'shop_item',
      );

      final items = rows.map((row) {
        final id = row['id'] as String;
        final vote = userVotes[id] ?? 0;
        return ShopItem.fromMap(row, userVote: vote);
      }).toList();

      items.sort(_compareItems);
      emit(state.copyWith(items: items, isLoading: false));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load items: $e',
      ));
    }
  }

  /// Comparator: highest score first; ties broken by name A-Z.
  static int _compareItems(ShopItem a, ShopItem b) {
    final scoreCompare = b.score.compareTo(a.score);
    if (scoreCompare != 0) return scoreCompare;
    return a.name.compareTo(b.name);
  }

  void setCategory(String category) {
    emit(state.copyWith(selectedCategory: category));
  }

  void setSearchQuery(String query) {
    emit(state.copyWith(searchQuery: query));
  }

  /// Instant optimistic vote toggle on shop items
  Future<void> castVote(ShopItem item, int requestedVote) async {
    final previousItems = List<ShopItem>.from(state.items);
    final nextVote = item.userVote == requestedVote ? 0 : requestedVote;

    int newUp = item.upvotesCount;
    int newDown = item.downvotesCount;

    if (item.userVote == 1) newUp--;
    if (item.userVote == -1) newDown--;

    if (nextVote == 1) newUp++;
    if (nextVote == -1) newDown++;

    newUp = newUp < 0 ? 0 : newUp;
    newDown = newDown < 0 ? 0 : newDown;

    final updatedItem = item.copyWith(
      userVote: nextVote,
      upvotesCount: newUp,
      downvotesCount: newDown,
    );

    final updatedItems = state.items.map((i) {
      return i.id == item.id ? updatedItem : i;
    }).toList();
    updatedItems.sort(_compareItems);

    emit(state.copyWith(items: updatedItems));

    try {
      final res = await _votingRepository.castVote(
        targetType: 'shop_item',
        targetId: item.id,
        vote: nextVote,
      );

      if (res.isNotEmpty && res['upvotes'] != null && res['downvotes'] != null) {
        final confirmedItems = state.items.map((i) {
          if (i.id == item.id) {
            return i.copyWith(
              upvotesCount: (res['upvotes'] as num).toInt(),
              downvotesCount: (res['downvotes'] as num).toInt(),
              userVote: (res['user_vote'] as num).toInt(),
            );
          }
          return i;
        }).toList();
        confirmedItems.sort(_compareItems);
        emit(state.copyWith(items: confirmedItems));
      }
    } catch (e) {
      emit(state.copyWith(
        items: previousItems,
        errorMessage: 'Failed to update vote: $e',
      ));
    }
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
