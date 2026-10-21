class ShopItem {
  final String id;
  final String name;
  final double price;
  final String category;
  final bool isAvailable;
  final String? imageUrl;

  ShopItem({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    this.isAvailable = true,
    this.imageUrl,
  });

  factory ShopItem.fromMap(Map<String, dynamic> map) {
    return ShopItem(
      id: map['id'] as String,
      name: map['name'] as String,
      price: (map['price'] as num).toDouble(),
      category: map['category'] as String,
      isAvailable: map['is_available'] as bool? ?? true,
      imageUrl: map['image_url'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': price,
      'category': category,
      'is_available': isAvailable,
      'image_url': imageUrl,
    };
  }
}