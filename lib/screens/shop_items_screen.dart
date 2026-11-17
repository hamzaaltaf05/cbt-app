import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cbt_app/cubits/auth/auth_cubit.dart';
import 'package:cbt_app/cubits/honour_shop/honour_shop_cubit.dart';
import 'package:cbt_app/models/shop_item.dart';
import 'package:cbt_app/models/user_profile.dart';

/// The list of categories an item can belong to.
/// `category` is a free-text column in Supabase, so adding a value here
/// requires no database migration.
const List<String> kShopCategories = [
  'Beverages',
  'Crisps',
  'Biscuits',
  'Mints & Gums',
  'Other',
];

class ShopItemsScreen extends StatefulWidget {
  const ShopItemsScreen({super.key});

  @override
  State<ShopItemsScreen> createState() => _ShopItemsScreenState();
}

class _ShopItemsScreenState extends State<ShopItemsScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _canManageItems {
    final role = context.watch<AuthCubit>().role;
    return role == UserRole.admin || role == UserRole.shopManager;
  }

  bool get _isFiltering {
    final state = context.watch<HonourShopCubit>().state;
    return state.searchQuery.isNotEmpty || state.selectedCategory != 'All';
  }

  List<ShopItem> get _filteredItems =>
      context.watch<HonourShopCubit>().state.filteredItems;

  bool get _isLoading => context.watch<HonourShopCubit>().state.isLoading;

  String? get _error => context.watch<HonourShopCubit>().state.errorMessage;

  Future<void> _showAddItemDialog() async {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    String selectedCategory = kShopCategories.first;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add New Item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Item Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(
                  labelText: 'Price',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedCategory,
                items: kShopCategories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (value) =>
                    setDialogState(() => selectedCategory = value!),
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final priceStr = priceController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Name is required')),
                  );
                  return;
                }
                final price = double.tryParse(priceStr);
                if (price == null || price <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter a valid price')),
                  );
                  return;
                }
                final success = await context.read<HonourShopCubit>().addItem(
                  name: name,
                  price: price,
                  category: selectedCategory,
                );
                if (success && context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Item added!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditItemDialog(ShopItem item) async {
    final nameController = TextEditingController(text: item.name);
    final priceController = TextEditingController(
      text: item.price.toStringAsFixed(2),
    );
    String selectedCategory = kShopCategories.contains(item.category)
        ? item.category
        : kShopCategories.first;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Item Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(
                  labelText: 'Price',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedCategory,
                items: kShopCategories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (value) =>
                    setDialogState(() => selectedCategory = value!),
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final priceStr = priceController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Name is required')),
                  );
                  return;
                }
                final price = double.tryParse(priceStr);
                if (price == null || price <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter a valid price')),
                  );
                  return;
                }
                final success = await context.read<HonourShopCubit>().editItem(
                  id: item.id,
                  name: name,
                  price: price,
                  category: selectedCategory,
                );
                if (success && context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Item updated!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else if (!success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to update item')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(ShopItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Are you sure you want to delete "${item.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final success = await context.read<HonourShopCubit>().deleteItem(item.id);
      if (!success && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Failed to delete item')));
      }
    }
  }

  /// Soft "Available" / "Unavailable" chip shown on cards and in the sheet.
  Widget _availabilityChip(bool isAvailable) {
    final (bg, fg) = isAvailable
        ? (Colors.green.withValues(alpha: 0.14), Colors.green.shade700)
        : (Colors.red.withValues(alpha: 0.14), Colors.red.shade700);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAvailable ? Icons.check_circle : Icons.block,
            size: 11,
            color: fg,
          ),
          const SizedBox(width: 3),
          Text(
            isAvailable ? 'Available' : 'Unavailable',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  /// Bottom sheet shown when any user taps an item card.
  /// Offers the availability action for that item.
  void _showItemSheet(ShopItem item) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  _availabilityChip(item.isAvailable),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(
                item.isAvailable
                    ? Icons.remove_circle_outline
                    : Icons.add_circle_outline,
                color: item.isAvailable ? Colors.red : Colors.green,
              ),
              title: Text(
                item.isAvailable ? 'Mark as unavailable' : 'Mark as available',
              ),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                await _confirmSetAvailability(item, !item.isAvailable);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Confirmation dialog → RPC toggle → list refresh.
  Future<void> _confirmSetAvailability(
    ShopItem item,
    bool makeAvailable,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          makeAvailable ? 'Mark as available' : 'Mark as unavailable',
        ),
        content: Text(
          'Are you sure you want to mark "${item.name}" as '
          '${makeAvailable ? 'available' : 'unavailable'}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: makeAvailable ? Colors.green : Colors.red,
            ),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final success = await context.read<HonourShopCubit>().toggleAvailability(
      item,
      makeAvailable,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? (makeAvailable
                    ? 'Item marked as available'
                    : 'Item marked as unavailable')
                : 'Failed to update availability',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Widget _buildSearchBar() {
    final shopCubit = context.read<HonourShopCubit>();
    final selectedCategory = context.watch<HonourShopCubit>().state.selectedCategory;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: _searchController,
              onChanged: (text) => shopCubit.setSearchQuery(text),
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search by name',
                hintStyle: const TextStyle(fontSize: 12),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          shopCubit.setSearchQuery('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              value: selectedCategory,
              borderRadius: BorderRadius.circular(12),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 8,
                ),
              ),
              items: [
                'All',
                ...kShopCategories,
              ].map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (value) =>
                  shopCubit.setCategory(value ?? 'All'),
            ),
          ),
        ],
      ),
    );
  }

  /// Returns a soft (background, foreground) color pair for a shop category.
  /// Each category gets a distinct tinted chip so the list is easy to scan.
  (Color, Color) _categoryChipColors(String category) {
    switch (category) {
      case 'Beverages':
        return (Colors.blue.withValues(alpha: 0.16), Colors.blue.shade600);
      case 'Crisps':
        return (Colors.orange.withValues(alpha: 0.16), Colors.orange.shade700);
      case 'Biscuits':
        return (Colors.brown.withValues(alpha: 1), Colors.brown.shade100);
      case 'Mints & Gums':
        return (Colors.teal.withValues(alpha: 0.16), Colors.teal.shade600);
      default:
        return (Colors.grey.withValues(alpha: 0.18), Colors.grey.shade600);
    }
  }

  Widget _buildItemTile(ShopItem item) {
    final (chipBg, chipFg) = _categoryChipColors(item.category);
    final scheme = Theme.of(context).colorScheme;
    final card = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showItemSheet(item),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: chipBg,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  item.category,
                  style: TextStyle(
                    fontSize: 11,
                    color: chipFg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: item.isAvailable
                            ? scheme.onSurface
                            : scheme.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                    const SizedBox(height: 4),
                    _availabilityChip(item.isAvailable),
                  ],
                ),
              ),
              Text(
                'Rs ${item.price.round()}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: item.isAvailable
                      ? scheme.primary
                      : scheme.primary.withValues(alpha: 0.6),
                ),
              ),
              if (_canManageItems)
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  tooltip: 'Edit item',
                  onPressed: () => _showEditItemDialog(item),
                ),
            ],
          ),
        ),
      ),
    );

    if (!_canManageItems) return card;

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _confirmDelete(item),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: card,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Honour Shop'),
        actions: [
          if (_canManageItems)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _showAddItemDialog,
            ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => context.read<HonourShopCubit>().loadItems(),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _filteredItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isFiltering
                              ? Icons.search_off_outlined
                              : Icons.storefront_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isFiltering
                              ? 'No items match your search.'
                              : 'No items in the shop yet.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        if (!_isFiltering && _canManageItems) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Add items using the + button.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () => context.read<HonourShopCubit>().loadItems(),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: _filteredItems.map(_buildItemTile).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
