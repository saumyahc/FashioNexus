class OrderItem {
  final String name;
  final String image;
  final String size;
  final int quantity;
  final double price;

  OrderItem({
    required this.name,
    required this.image,
    required this.size,
    required this.quantity,
    required this.price,
  });

  factory OrderItem.fromMap(Map<String, dynamic> data) {
    return OrderItem(
      name: data['name'],
      image: data['imageUrl'],
      size: data['size'],
      quantity: data['quantity'],
      price:
          (data['price'] is double)
              ? data['price']
              : double.tryParse(data['price']?.toString() ?? '0') ?? 0,
    );
  }
}
