import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'cart_screen.dart';
import 'address_entry_page.dart'; // Add this import

class ProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  String? selectedSize;
  final user = FirebaseAuth.instance.currentUser;

  bool isInCart = false;
  StreamSubscription<QuerySnapshot>? cartSubscription;

  @override
  void initState() {
    super.initState();
    _checkIfInCart();
  }

  @override
  void dispose() {
    cartSubscription?.cancel();
    super.dispose();
  }

  void _checkIfInCart() {
    if (user == null) return;

    cartSubscription?.cancel();

    cartSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('cart')
        .snapshots()
        .listen((snapshot) {
          bool found = false;
          for (var doc in snapshot.docs) {
            final data = doc.data();
            if (data['name'] == widget.product['name'] &&
                data['size'] == selectedSize) {
              found = true;
              break;
            }
          }
          if (found != isInCart) {
            setState(() {
              isInCart = found;
            });
          }
        });
  }

  // Helper method to safely convert price to double
  double _getPriceAsDouble() {
    final price = widget.product['price'];
    if (price is double) {
      return price;
    } else if (price is int) {
      return price.toDouble();
    } else if (price is String) {
      return double.tryParse(price) ?? 0.0;
    }
    return 0.0;
  }

  Future<void> addToCart() async {
    if (selectedSize == null) {
      _showSelectSizeDialog();
      return;
    }

    if (isInCart) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => CartScreen()));
      return;
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('cart')
        .add({
          'name': widget.product['name'],
          'price': widget.product['price'],
          'imageUrl': widget.product['imageUrl'],
          'size': selectedSize,
          'timestamp': FieldValue.serverTimestamp(),
        });

    setState(() {
      isInCart = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text('Item added to cart'),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> buyNow() async {
    if (selectedSize == null) {
      _showSelectSizeDialog();
      return;
    }

    // Create a single item for the buy now action
    final item = {
      'name': widget.product['name'],
      'price': widget.product['price'],
      'imageUrl': widget.product['imageUrl'],
      'size': selectedSize,
      'quantity': 1, // Default quantity for buy now
    };

    // Navigate directly to AddressEntryPage with this single item
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddressEntryPage(items: [item])),
    );
  }

  void _showSelectSizeDialog() {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange),
                SizedBox(width: 8),
                Text('Select Size'),
              ],
            ),
            content: Text('Please select a size before continuing.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK', style: TextStyle(color: Colors.deepPurple)),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFootwear = widget.product['category'] == 'Footwear';
    final sizes =
        isFootwear
            ? ['3', '4', '5', '6', '7', '8', '9']
            : ['XS', 'S', 'M', 'L', 'XL', 'XXL'];

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: Text(
          widget.product['name'],
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          Container(
            margin: EdgeInsets.only(right: 8),
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('users')
                      .doc(user!.uid)
                      .collection('cart')
                      .snapshots(),
              builder: (context, snapshot) {
                int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                return Stack(
                  children: [
                    IconButton(
                      icon: Icon(Icons.shopping_cart_outlined),
                      onPressed:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => CartScreen()),
                          ),
                    ),
                    if (count > 0)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            '$count',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Image Section
                  Container(
                    width: double.infinity,
                    height: 300,
                    color: Colors.white,
                    child: Hero(
                      tag: 'product-${widget.product['name']}',
                      child: ClipRRect(
                        borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(20),
                        ),
                        child: Image.network(
                          widget.product['imageUrl'],
                          width: double.infinity,
                          height: double.infinity,
                          fit:
                              BoxFit
                                  .contain, // Changed to contain to show full image
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                color: Colors.deepPurple,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey.shade200,
                              child: Icon(
                                Icons.image_not_supported,
                                size: 50,
                                color: Colors.grey,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                  // Product Info Section
                  Container(
                    margin: EdgeInsets.all(16),
                    padding: EdgeInsets.all(20),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.product['name'],
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 8),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "₹${widget.product['price']}",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple,
                            ),
                          ),
                        ),
                        SizedBox(height: 24),

                        // Size Selection
                        Text(
                          "Select Size ${isFootwear ? '(UK Size)' : ''}",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              sizes.map((size) {
                                final isSelected = size == selectedSize;
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      selectedSize = size;
                                      _checkIfInCart();
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: Duration(milliseconds: 200),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          isSelected
                                              ? Colors.deepPurple
                                              : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color:
                                            isSelected
                                                ? Colors.deepPurple
                                                : Colors.grey.shade300,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Text(
                                      size,
                                      style: TextStyle(
                                        color:
                                            isSelected
                                                ? Colors.white
                                                : Colors.black87,
                                        fontWeight:
                                            isSelected
                                                ? FontWeight.w600
                                                : FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                        ),
                        SizedBox(height: 24),

                        // Description Section
                        Text(
                          "Description",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          widget.product['description'] ??
                              'No description provided.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Action Buttons
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: buyNow,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: Text(
                        "Buy Now",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: addToCart,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isInCart ? Colors.green : Colors.white,
                        foregroundColor:
                            isInCart ? Colors.white : Colors.deepPurple,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isInCart ? Colors.green : Colors.deepPurple,
                            width: 1.5,
                          ),
                        ),
                        elevation: 1,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isInCart
                                ? Icons.shopping_cart
                                : Icons.add_shopping_cart,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            isInCart ? "Go to Cart" : "Add to Cart",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
