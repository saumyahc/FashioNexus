import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MyOrdersPage extends StatefulWidget {
  const MyOrdersPage({super.key});

  @override
  State<MyOrdersPage> createState() => _MyOrdersPageState();
}

class _MyOrdersPageState extends State<MyOrdersPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'My Orders',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.deepPurple,
        elevation: 0,
      ),
      body: _buildOrdersList(),
    );
  }

  Widget _buildOrdersList() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Please login to view your orders'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('orders')
              .orderBy('orderDate', descending: true)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.shopping_bag_outlined,
            title: 'No Orders Yet',
            message: 'Start shopping to see your orders here!',
          );
        }

        final orders = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final orderDoc = orders[index];
            final orderData = orderDoc.data() as Map<String, dynamic>;
            return _buildOrderCard(orderData, orderDoc.id);
          },
        );
      },
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> orderData, String orderId) {
    final status = orderData['status'] ?? 'Pending';
    final orderDate =
        (orderData['orderDate'] as Timestamp?)?.toDate() ?? DateTime.now();
    final items = orderData['items'] as List<dynamic>? ?? [];
    final totalAmount = orderData['totalAmount']?.toDouble() ?? 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showOrderDetails(orderData, orderId),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order #${orderId.substring(0, 8).toUpperCase()}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  _buildStatusChip(status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                DateFormat('MMM dd, yyyy • hh:mm a').format(orderDate),
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              const SizedBox(height: 12),
              _buildOrderItems(items),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total: ₹${totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.deepPurple,
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color chipColor;
    Color textColor;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'delivered':
        chipColor = Colors.green.shade100;
        textColor = Colors.green.shade700;
        icon = Icons.check_circle;
        break;
      case 'pending':
        chipColor = Colors.orange.shade100;
        textColor = Colors.orange.shade700;
        icon = Icons.access_time;
        break;
      case 'cancelled':
        chipColor = Colors.red.shade100;
        textColor = Colors.red.shade700;
        icon = Icons.cancel;
        break;
      default:
        chipColor = Colors.grey.shade100;
        textColor = Colors.grey.shade700;
        icon = Icons.info;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItems(List<dynamic> items) {
    if (items.isEmpty) return const SizedBox();

    return Column(
      children: [
        ...items.take(2).map((item) => _buildOrderItem(item)),
        if (items.length > 2)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '+${items.length - 2} more items',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildOrderItem(dynamic item) {
    final itemData = item as Map<String, dynamic>;
    final name = itemData['name'] ?? 'Unknown Item';
    final quantity = itemData['quantity'] ?? 1;
    final price = double.tryParse(itemData['price']?.toString() ?? '0') ?? 0.0;
    final imageUrl = itemData['imageUrl'] ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 50,
              height: 50,
              child:
                  imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder:
                            (context, url) => Container(
                              color: Colors.grey[200],
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                        errorWidget:
                            (context, url, error) => Container(
                              color: Colors.grey[200],
                              child: const Icon(Icons.image_not_supported),
                            ),
                      )
                      : Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.image),
                      ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Qty: $quantity × ₹${price.toStringAsFixed(2)}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showOrderDetails(Map<String, dynamic> orderData, String orderId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.7,
            maxChildSize: 0.9,
            minChildSize: 0.5,
            builder:
                (context, scrollController) => Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          controller: scrollController,
                          padding: const EdgeInsets.all(20),
                          child: _buildOrderDetailsContent(orderData, orderId),
                        ),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  Widget _buildOrderDetailsContent(
    Map<String, dynamic> orderData,
    String orderId,
  ) {
    final status = orderData['status'] ?? 'Pending';
    final orderDate =
        (orderData['orderDate'] as Timestamp?)?.toDate() ?? DateTime.now();
    final items = orderData['items'] as List<dynamic>? ?? [];
    final totalAmount = orderData['totalAmount']?.toDouble() ?? 0.0;
    // Fixed the type casting issue here
    final deliveryAddress =
        orderData['deliveryAddress'] is Map<String, dynamic>
            ? orderData['deliveryAddress'] as Map<String, dynamic>
            : <String, dynamic>{};
    final paymentMethod = orderData['paymentMethod'] ?? 'Unknown';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Order Details',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            _buildStatusChip(status),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Order #${orderId.substring(0, 8).toUpperCase()}',
          style: TextStyle(color: Colors.grey[600], fontSize: 16),
        ),
        Text(
          DateFormat('MMM dd, yyyy • hh:mm a').format(orderDate),
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
        const SizedBox(height: 24),

        // Items Section
        const Text(
          'Items',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...items.map((item) => _buildDetailedOrderItem(item)),

        const SizedBox(height: 24),

        // Delivery Address Section
        if (deliveryAddress.isNotEmpty) ...[
          const Text(
            'Delivery Address',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (deliveryAddress['name'] != null)
                  Text(
                    deliveryAddress['name'].toString(),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                if (deliveryAddress['phone'] != null)
                  Text(deliveryAddress['phone'].toString()),
                if (deliveryAddress['address'] != null)
                  Text(deliveryAddress['address'].toString()),
                if (deliveryAddress['city'] != null)
                  Text(
                    '${deliveryAddress['city']} - ${deliveryAddress['pincode'] ?? ''}',
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Payment Information
        const Text(
          'Payment Information',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Payment Method'),
                  Text(
                    paymentMethod,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Amount',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '₹${totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedOrderItem(dynamic item) {
    final itemData = item as Map<String, dynamic>;
    final name = itemData['name'] ?? 'Unknown Item';
    final quantity = itemData['quantity'] ?? 1;
    final price = double.tryParse(itemData['price']?.toString() ?? '0') ?? 0.0;
    final imageUrl = itemData['imageUrl'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 60,
              height: 60,
              child:
                  imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder:
                            (context, url) => Container(
                              color: Colors.grey[200],
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                        errorWidget:
                            (context, url, error) => Container(
                              color: Colors.grey[200],
                              child: const Icon(Icons.image_not_supported),
                            ),
                      )
                      : Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.image),
                      ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Quantity: $quantity',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  '₹${price.toStringAsFixed(2)} each',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '₹${(price * quantity).toStringAsFixed(2)}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.deepPurple,
            ),
          ),
        ],
      ),
    );
  }
}
