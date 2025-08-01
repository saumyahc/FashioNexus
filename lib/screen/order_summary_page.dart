import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'payments_page.dart';
import 'order_item.dart';

class OrderSummaryPage extends StatefulWidget {
  final String address;
  final String phone;
  final List<OrderItem> items;
  final Map<String, String>? addressDetails;

  const OrderSummaryPage({
    super.key,
    required this.address,
    required this.phone,
    required this.items,
    this.addressDetails,
  });

  @override
  State<OrderSummaryPage> createState() => _OrderSummaryPageState();
}

class _OrderSummaryPageState extends State<OrderSummaryPage> {
  String userName = "";
  double discount = 0.0;
  double platformFee = 5.0;
  double gstAmount = 0.0;

  @override
  void initState() {
    super.initState();
    fetchUserName();
    calculateCharges();
  }

  void fetchUserName() {
    final user = FirebaseAuth.instance.currentUser;
    setState(() {
      userName = widget.addressDetails?['name'] ?? user?.displayName ?? "User";
    });
  }

  void calculateCharges() {
    double itemsTotal = widget.items.fold(
      0,
      (sum, item) => sum + (item.price * item.quantity),
    );

    // Calculate 5% discount for orders above ₹999
    if (itemsTotal >= 999) {
      discount = itemsTotal * 0.05;
    }

    // Calculate GST (18% on platform fee only)
    gstAmount = platformFee * 0.18;
  }

  double get itemsTotal {
    return widget.items.fold(
      0,
      (sum, item) => sum + (item.price * item.quantity),
    );
  }

  double get finalAmount {
    return itemsTotal + platformFee + gstAmount - discount;
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildDeliveryAddressCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.location_on,
                    color: Colors.green.shade600,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Deliver to",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        userName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                  ),
                  child: const Text(
                    "Change",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.address,
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Phone: ${widget.phone}",
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                  if (widget.addressDetails?['addressType'] != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        widget.addressDetails!['addressType']!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItemCard(OrderItem item) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                item.image,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder:
                    (context, error, stackTrace) => Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.image_not_supported,
                        color: Colors.grey.shade400,
                      ),
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Size: ${item.size}",
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        "₹${item.price.toStringAsFixed(0)}",
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        " x ${item.quantity}",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              "₹${(item.price * item.quantity).toStringAsFixed(0)}",
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBillDetailsCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Bill Details",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            _buildBillRow("Items Total", "₹${itemsTotal.toStringAsFixed(2)}"),
            _buildBillRow("Platform Fee", "₹${platformFee.toStringAsFixed(2)}"),
            _buildBillRow("GST", "₹${gstAmount.toStringAsFixed(2)}"),
            if (discount > 0)
              _buildBillRow(
                "Discount",
                "-₹${discount.toStringAsFixed(2)}",
                isDiscount: true,
              ),
            const Divider(height: 24),
            _buildBillRow(
              "Total Amount",
              "₹${finalAmount.toStringAsFixed(2)}",
              isTotal: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBillRow(
    String label,
    String amount, {
    String? originalPrice,
    bool isDiscount = false,
    bool isTotal = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.w400,
              color: isTotal ? Colors.black : Colors.grey.shade700,
            ),
          ),
          Row(
            children: [
              if (originalPrice != null) ...[
                Text(
                  originalPrice,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Text(
                amount,
                style: TextStyle(
                  fontSize: isTotal ? 16 : 14,
                  fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
                  color:
                      isDiscount
                          ? Colors.green.shade600
                          : isTotal
                          ? Colors.black
                          : Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          "Order Summary",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey.shade200),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  _buildDeliveryAddressCard(),

                  _buildSectionTitle("Order Items (${widget.items.length})"),
                  ...widget.items.map((item) => _buildOrderItemCard(item)),

                  const SizedBox(height: 16),
                  _buildBillDetailsCard(),

                  const SizedBox(height: 100), // Space for bottom button
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade300,
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Total Amount",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        "₹${finalAmount.toStringAsFixed(2)}",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    "${widget.items.length} item${widget.items.length > 1 ? 's' : ''}",
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => PaymentsPage(
                              totalAmount: finalAmount,
                              orderDetails: {
                                'items': widget.items,
                                'address': widget.address,
                                'phone': widget.phone,
                                'itemsTotal': itemsTotal,
                                'platformFee': platformFee,
                                'gstAmount': gstAmount,
                                'discount': discount,
                                'finalAmount': finalAmount,
                              },
                            ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade600,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Proceed to Payment",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
