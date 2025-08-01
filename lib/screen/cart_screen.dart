import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'address_entry_page.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  _CartScreenState createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> with SingleTickerProviderStateMixin {
  final user = FirebaseAuth.instance.currentUser;
  final List<int> quantityOptions = List<int>.generate(10, (i) => i + 1);
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _updateQuantity(String docId, int quantity, {bool isPurchased = false}) {
    final collection = isPurchased ? 'purchased_items' : 'cart';
    FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection(collection)
        .doc(docId)
        .update({'quantity': quantity});
  }

  void _removeItem(String docId, {bool isPurchased = false}) {
    final collection = isPurchased ? 'purchased_items' : 'cart';
    final itemType = isPurchased ? 'purchased item' : 'cart item';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Remove Item'),
          ],
        ),
        content: Text(
          'Are you sure you want to remove this $itemType?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(user!.uid)
                  .collection(collection)
                  .doc(docId)
                  .delete();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white),
                      SizedBox(width: 8),
                      Text('Item removed successfully'),
                    ],
                  ),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            },
            child: Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showQuantityDialog(String docId, int currentQty, {bool isPurchased = false}) {
    TextEditingController controller = TextEditingController(
      text: currentQty.toString(),
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text('Enter Quantity'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'Enter custom quantity',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              int? customQty = int.tryParse(controller.text);
              if (customQty != null && customQty > 0) {
                _updateQuantity(docId, customQty, isPurchased: isPurchased);
              }
              Navigator.pop(context);
            },
            child: Text('OK', style: TextStyle(color: Colors.deepPurple)),
          ),
        ],
      ),
    );
  }

  void _moveToCart(Map<String, dynamic> item, String docId) {
    // Add to cart
    FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('cart')
        .add({
      ...item,
      'timestamp': FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.shopping_cart, color: Colors.white),
            SizedBox(width: 8),
            Text('Item added to cart'),
          ],
        ),
        backgroundColor: Colors.deepPurple,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: Text("My Cart", style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.deepPurple,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.deepPurple,
          indicatorWeight: 3,
          tabs: [
            Tab(
              icon: Icon(Icons.shopping_cart),
              text: "Cart",
            ),
            Tab(
              icon: Icon(Icons.refresh),
              text: "Buy Again",
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCartTab(),
          _buildBuyAgainTab(),
        ],
      ),
    );
  }

  Widget _buildCartTab() {
    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('cart')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(color: Colors.deepPurple),
          );
        }

        final cartItems = snapshot.data!.docs;

        if (cartItems.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.shopping_cart_outlined,
                  size: 80,
                  color: Colors.grey.shade400,
                ),
                SizedBox(height: 16),
                Text(
                  "Your cart is empty",
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  "Add some products to get started",
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }

        return _buildItemsList(cartItems, isCart: true);
      },
    );
  }

  Widget _buildBuyAgainTab() {
    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('purchased_items')
          .orderBy('purchaseDate', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(color: Colors.deepPurple),
          );
        }

        final purchasedItems = snapshot.data!.docs;

        if (purchasedItems.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.history,
                  size: 80,
                  color: Colors.grey.shade400,
                ),
                SizedBox(height: 16),
                Text(
                  "No previous purchases",
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  "Items you purchase will appear here",
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }

        return _buildItemsList(purchasedItems, isCart: false);
      },
    );
  }

  Widget _buildItemsList(List<QueryDocumentSnapshot> items, {required bool isCart}) {
    double total = 0.0;
    List<Map<String, dynamic>> itemsForOrder = [];

    if (isCart) {
      for (var doc in items) {
        final data = doc.data() as Map<String, dynamic>;
        int quantity = data.containsKey('quantity') ? data['quantity'] : 1;
        double price = double.tryParse(data['price'].toString()) ?? 0.0;
        total += price * quantity;
        itemsForOrder.add({
          'name': data['name'],
          'price': price,
          'quantity': quantity,
          'size': data['size'],
          'imageUrl': data['imageUrl'],
        });
      }
    }

    return Column(
      children: [
        if (isCart) ...[
          // Cart Items Count
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            margin: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              "${items.length} item${items.length > 1 ? 's' : ''} in your cart",
              style: TextStyle(
                color: Colors.deepPurple,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ] else ...[
          // Buy Again Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            margin: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.history, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  "Your previous purchases",
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],

        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final doc = items[index];
              final item = doc.data() as Map<String, dynamic>;
              final docId = doc.id;
              int quantity = item.containsKey('quantity') ? item['quantity'] : 1;

              return Container(
                margin: EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product Image
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.grey.shade100,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            item['imageUrl'],
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  color: Colors.deepPurple,
                                  strokeWidth: 2,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.image_not_supported,
                                color: Colors.grey,
                              );
                            },
                          ),
                        ),
                      ),
                      SizedBox(width: 16),

                      // Product Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['name'],
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 4),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                "Size: ${item['size']}",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            SizedBox(height: 12),

                            // Quantity Section
                            Row(
                              children: [
                                Text(
                                  "Qty: ",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: DropdownButton<int>(
                                    value: quantityOptions.contains(quantity) ? quantity : null,
                                    items: quantityOptions
                                        .map((qty) => DropdownMenuItem<int>(
                                              value: qty,
                                              child: Text(qty.toString()),
                                            ))
                                        .toList(),
                                    onChanged: (value) {
                                      if (value != null) {
                                        _updateQuantity(docId, value, isPurchased: !isCart);
                                      }
                                    },
                                    hint: Text(
                                      quantity.toString(),
                                      style: TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                    underline: SizedBox(),
                                    style: TextStyle(
                                      color: Colors.black87,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                if (!quantityOptions.contains(quantity))
                                  TextButton(
                                    onPressed: () => _showQuantityDialog(
                                      docId,
                                      quantity,
                                      isPurchased: !isCart,
                                    ),
                                    child: Text(
                                      'Edit',
                                      style: TextStyle(
                                        color: Colors.deepPurple,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),

                            // Purchase Date (only for buy again tab)
                            if (!isCart && item.containsKey('purchaseDate')) ...[
                              SizedBox(height: 8),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  "Purchased: ${_formatDate(item['purchaseDate'])}",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.blue.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Action Button and Price
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (isCart) ...[
                            // Remove button for cart items
                            GestureDetector(
                              onTap: () => _removeItem(docId),
                              child: Container(
                                padding: EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.close,
                                  color: Colors.red,
                                  size: 18,
                                ),
                              ),
                            ),
                          ] else ...[
                            // Add to cart button for purchased items
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GestureDetector(
                                  onTap: () => _moveToCart(item, docId),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.deepPurple,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.add_shopping_cart,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Add',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => _removeItem(docId, isPurchased: true),
                                  child: Container(
                                    padding: EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          SizedBox(height: 16),
                          Text(
                            '₹${(double.tryParse(item['price'].toString()) ?? 0.0 * quantity).toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple,
                              fontSize: 16,
                            ),
                          ),
                          if (quantity > 1) ...[
                            SizedBox(height: 4),
                            Text(
                              '₹${item['price']} each',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Bottom checkout section (only for cart tab)
        if (isCart && items.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Total Amount",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            Text(
                              "₹${total.toStringAsFixed(2)}",
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "${items.length} items",
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddressEntryPage(items: itemsForOrder),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      minimumSize: Size(double.infinity, 56),
                      elevation: 2,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_bag_outlined),
                        SizedBox(width: 8),
                        Text(
                          "Place Order",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    
    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is DateTime) {
      date = timestamp;
    } else {
      return 'Unknown';
    }
    
    return "${date.day}/${date.month}/${date.year}";
  }
}