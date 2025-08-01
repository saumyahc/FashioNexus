import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'ar_shopping.dart';

class PaymentsPage extends StatefulWidget {
  final double totalAmount;
  final Map<String, dynamic>? orderDetails;

  const PaymentsPage({super.key, required this.totalAmount, this.orderDetails});

  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage>
    with TickerProviderStateMixin {
  bool isProcessing = false;
  late Razorpay _razorpay;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Replace with your actual Razorpay keys
  static const String razorpayKeyId = "rzp_test_99nQfXpiIYzt0w";
  static const String razorpayKeySecret = "95cY3WzHzXirWUiadjlWlOVE";

  @override
  void initState() {
    super.initState();
    _initializeRazorpay();
    _setupAnimations();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    _animationController.forward();
    _slideController.forward();
  }

  void _initializeRazorpay() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    setState(() => isProcessing = false);

    try {
      // Move cart items to purchased_items and clear cart
      await _moveCartToPurchasedItems(response.paymentId!);

      _showSuccessDialog(
        "Payment Successful! 🎉",
        "Payment ID: ${response.paymentId}\n\nYour order has been confirmed and will be delivered soon!",
      );
    } catch (e) {
      print("Error moving cart items: $e");
      _showErrorToast(
        "Payment successful but failed to update cart. Please contact support.",
      );
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    setState(() => isProcessing = false);
    _showErrorToast("Payment Failed: ${response.message}");
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    setState(() => isProcessing = false);
    _showSuccessToast("External Wallet: ${response.walletName}");
  }

  Future<void> _moveCartToPurchasedItems(String paymentId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not authenticated");

    final batch = _firestore.batch();
    final now = FieldValue.serverTimestamp();

    try {
      // Get all cart items
      final cartSnapshot =
          await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('cart')
              .get();

      if (cartSnapshot.docs.isEmpty) {
        throw Exception("No items in cart");
      }

      // Add each cart item to purchased_items
      for (final doc in cartSnapshot.docs) {
        final cartData = doc.data();
        final purchasedItemRef =
            _firestore
                .collection('users')
                .doc(user.uid)
                .collection('purchased_items')
                .doc(); // Auto-generate ID

        // Add purchase metadata
        final purchasedData = {
          ...cartData,
          'purchaseDate': now,
          'paymentId': paymentId,
          'paymentMethod': 'online',
          'orderStatus': 'confirmed',
          'originalCartId': doc.id,
        };

        batch.set(purchasedItemRef, purchasedData);

        // Delete from cart
        batch.delete(doc.reference);
      }

      // Create order summary document
      final orderRef =
          _firestore
              .collection('users')
              .doc(user.uid)
              .collection('orders')
              .doc();

      final orderData = {
        'orderId': orderRef.id,
        'paymentId': paymentId,
        'totalAmount': widget.totalAmount,
        'itemCount': cartSnapshot.docs.length,
        'orderDate': now,
        'paymentMethod': 'online',
        'status': 'confirmed',
        'items':
            cartSnapshot.docs.map((doc) {
              final data = doc.data();
              return {
                'name': data['name'],
                'price': data['price'],
                'quantity': data['quantity'] ?? 1,
                'size': data['size'],
                'imageUrl': data['imageUrl'],
              };
            }).toList(),
        'deliveryAddress': widget.orderDetails?['address'] ?? '',
        'phoneNumber': widget.orderDetails?['phone'] ?? '',
      };

      batch.set(orderRef, orderData);

      // Commit all changes
      await batch.commit();
      print(
        "Successfully moved ${cartSnapshot.docs.length} items from cart to purchased items",
      );
    } catch (e) {
      print("Error in batch operation: $e");
      rethrow;
    }
  }

  Future<void> _handleCODOrder() async {
    final user = _auth.currentUser;
    if (user == null) {
      _showErrorToast("User not authenticated");
      return;
    }

    try {
      setState(() => isProcessing = true);

      // Move cart items to purchased_items for COD
      await _moveCartToPurchasedItemsCOD();

      setState(() => isProcessing = false);

      final codTotal = widget.totalAmount + 10;
      _showSuccessDialog(
        "Order Placed Successfully! 🎉",
        "Your order will be delivered soon.\n\nAmount to pay on delivery: ₹${codTotal.toStringAsFixed(2)}\n\nThank you for choosing FashioNexus!",
      );
    } catch (e) {
      setState(() => isProcessing = false);
      print("Error handling COD order: $e");
      _showErrorToast("Failed to place order. Please try again.");
    }
  }

  Future<void> _moveCartToPurchasedItemsCOD() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not authenticated");

    final batch = _firestore.batch();
    final now = FieldValue.serverTimestamp();
    final codOrderId = "COD_${DateTime.now().millisecondsSinceEpoch}";

    try {
      // Get all cart items
      final cartSnapshot =
          await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('cart')
              .get();

      if (cartSnapshot.docs.isEmpty) {
        throw Exception("No items in cart");
      }

      // Add each cart item to purchased_items
      for (final doc in cartSnapshot.docs) {
        final cartData = doc.data();
        final purchasedItemRef =
            _firestore
                .collection('users')
                .doc(user.uid)
                .collection('purchased_items')
                .doc(); // Auto-generate ID

        // Add purchase metadata
        final purchasedData = {
          ...cartData,
          'purchaseDate': now,
          'paymentId': codOrderId,
          'paymentMethod': 'cod',
          'orderStatus': 'confirmed',
          'originalCartId': doc.id,
          'codAmount': widget.totalAmount + 10,
        };

        batch.set(purchasedItemRef, purchasedData);

        // Delete from cart
        batch.delete(doc.reference);
      }

      // Create order summary document
      final orderRef =
          _firestore
              .collection('users')
              .doc(user.uid)
              .collection('orders')
              .doc();

      final orderData = {
        'orderId': orderRef.id,
        'paymentId': codOrderId,
        'totalAmount': widget.totalAmount + 10, // Including COD fee
        'itemCount': cartSnapshot.docs.length,
        'orderDate': now,
        'paymentMethod': 'cod',
        'status': 'confirmed',
        'codFee': 10.0,
        'items':
            cartSnapshot.docs.map((doc) {
              final data = doc.data();
              return {
                'name': data['name'],
                'price': data['price'],
                'quantity': data['quantity'] ?? 1,
                'size': data['size'],
                'imageUrl': data['imageUrl'],
              };
            }).toList(),
        'deliveryAddress': widget.orderDetails?['address'] ?? '',
        'phoneNumber': widget.orderDetails?['phone'] ?? '',
      };

      batch.set(orderRef, orderData);

      // Commit all changes
      await batch.commit();
      print(
        "Successfully moved ${cartSnapshot.docs.length} items from cart to purchased items (COD)",
      );
    } catch (e) {
      print("Error in COD batch operation: $e");
      rethrow;
    }
  }

  void _openRazorpayCheckout() {
    var options = {
      'key': razorpayKeyId,
      'amount': (widget.totalAmount * 100).toInt(),
      'name': 'FashioNexus',
      'description': 'Payment for your fashion order',
      'prefill': {
        'contact': widget.orderDetails?['phone'] ?? '9876543210',
        'email': 'customer@fashionexus.com',
      },
      'theme': {'color': '#FF6B35'},
      'notes': {
        'address': widget.orderDetails?['address'] ?? '',
        'items_count': widget.orderDetails?['items']?.length.toString() ?? '0',
      },
      // Enable all payment methods
      'method': {
        'netbanking': true,
        'card': true,
        'upi': true,
        'wallet': true,
        'emi': true,
      },
      'config': {
        'display': {
          'blocks': {
            'utib': {
              //Axis Bank
              'name': 'Pay using Axis Bank',
              'instruments': [
                {'method': 'card'},
                {'method': 'netbanking'},
              ],
            },
            'other': {
              'name': 'Other Payment modes',
              'instruments': [
                {'method': 'card'},
                {'method': 'netbanking'},
                {'method': 'upi'},
                {'method': 'wallet'},
              ],
            },
          },
          'hide': [],
          'preferences': {'show_default_blocks': true},
        },
      },
    };

    try {
      setState(() => isProcessing = true);
      _razorpay.open(options);
    } catch (e) {
      setState(() => isProcessing = false);
      _showErrorToast("Error: $e");
    }
  }

  void _handleCashOnDelivery() {
    final codTotal = widget.totalAmount + 10;
    _showCODConfirmationDialog(codTotal);
  }

  void _navigateToARShopping() {
    // Navigate to AR Shopping page
    // Replace 'ARShoppingScreen()' with your actual AR shopping page class
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder:
            (context) =>
                const ARShoppingScreen(), // Replace with your AR shopping page
      ),
    );

    // Alternative: If you want to clear the entire navigation stack and go to AR shopping
    // Navigator.of(context).pushNamedAndRemoveUntil(
    //   '/ar_shopping', // Replace with your route name
    //   (route) => false,
    // );
  }

  @override
  void dispose() {
    _razorpay.clear();
    _animationController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          "Secure Payment",
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2D3748),
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.grey.shade200,
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Column(
            children: [
              _buildEnhancedAmountCard(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      _buildPaymentOptions(),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedAmountCard() {
    final orderDetails = widget.orderDetails;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667eea).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Total Amount",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "₹${widget.totalAmount.toStringAsFixed(2)}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -1,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.security,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (orderDetails != null) ...[
                  _buildOrderSummaryRow(
                    "Items",
                    "${orderDetails['items']?.length ?? 0}",
                  ),
                  _buildOrderSummaryRow(
                    "Items Total",
                    "₹${orderDetails['itemsTotal']?.toStringAsFixed(2) ?? '0.00'}",
                  ),
                  if ((orderDetails['deliveryCharge'] ?? 0) > 0)
                    _buildOrderSummaryRow(
                      "Delivery",
                      "₹${orderDetails['deliveryCharge']?.toStringAsFixed(2) ?? '0.00'}",
                    )
                  else
                    _buildOrderSummaryRow(
                      "Delivery",
                      "FREE",
                      isHighlight: true,
                    ),
                  if ((orderDetails['discount'] ?? 0) > 0)
                    _buildOrderSummaryRow(
                      "Discount",
                      "-₹${orderDetails['discount']?.toStringAsFixed(2) ?? '0.00'}",
                      isDiscount: true,
                    ),
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_user, color: Colors.white, size: 16),
                      SizedBox(width: 8),
                      Text(
                        "256-bit SSL Encrypted",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummaryRow(
    String label,
    String value, {
    bool isDiscount = false,
    bool isHighlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          Text(
            value,
            style: TextStyle(
              color:
                  isDiscount
                      ? const Color(0xFF48BB78)
                      : isHighlight
                      ? const Color(0xFF48BB78)
                      : Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            "Choose Payment Method",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2D3748),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Online Payment (Razorpay)
        _buildPaymentOptionCard(
          title: "Pay Online",
          subtitle: "UPI • Cards • Net Banking • Wallets",
          icon: Icons.payment,
          iconColor: const Color(0xFF4299E1),
          onTap: _openRazorpayCheckout,
          features: [
            "All UPI apps supported",
            "Credit & Debit Cards",
            "Net Banking (All major banks)",
            "Digital Wallets",
            "EMI Options available",
          ],
        ),

        const SizedBox(height: 16),

        // Cash on Delivery
        _buildPaymentOptionCard(
          title: "Cash on Delivery",
          subtitle: "Pay when you receive your order",
          icon: Icons.local_shipping,
          iconColor: const Color(0xFFD69E2E),
          onTap: _handleCashOnDelivery,
          features: [
            "Pay in cash upon delivery",
            "Additional ₹10 handling fee",
            "Total: ₹${(widget.totalAmount + 10).toStringAsFixed(2)}",
          ],
          isWarning: true,
        ),
      ],
    );
  }

  Widget _buildPaymentOptionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
    required List<String> features,
    bool isWarning = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isProcessing ? null : onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            iconColor.withOpacity(0.1),
                            iconColor.withOpacity(0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(icon, color: iconColor, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF2D3748),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isProcessing)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.grey.shade400,
                        size: 20,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (isWarning)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3CD),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFD4A574)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: const Color(0xFFD69E2E),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Additional ₹10 handling fee for COD orders",
                            style: TextStyle(
                              fontSize: 12,
                              color: const Color(0xFFD69E2E),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children:
                          features
                              .map(
                                (feature) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 2,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        color: iconColor,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          feature,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade700,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCODConfirmationDialog(double codTotal) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: Colors.white,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD69E2E).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.local_shipping,
                    color: Color(0xFFD69E2E),
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Confirm Cash on Delivery",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  "You will pay ₹${codTotal.toStringAsFixed(2)} in cash when your order is delivered.\n\nThis includes ₹10 handling fee for COD service.",
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF4A5568),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          "Cancel",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4A5568),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _handleCODOrder(); // Handle COD order processing
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD69E2E),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                        ),
                        child: const Text(
                          "Confirm Order",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: Colors.white,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF4A5568),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop(); // Close dialog
                          _navigateToARShopping(); // Navigate to AR shopping
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                        ),
                        child: const Text(
                          "Continue Shopping",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSuccessToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.green,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  void _showErrorToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.red,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }
}
