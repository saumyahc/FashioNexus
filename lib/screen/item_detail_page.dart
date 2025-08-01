import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ItemDetailPage extends StatelessWidget {
  final Map<String, dynamic> item;
  final String loggedInUserEmail;

  const ItemDetailPage({
    super.key,
    required this.item,
    required this.loggedInUserEmail,
  });

  // EmailJS Configuration
  static const String _serviceId =
      'service_4o92vui'; // Replace with your EmailJS service ID
  static const String _templateId =
      'template_3n4jmjk'; // Replace with your EmailJS template ID
  static const String _publicKey =
      'l8za9rjdyPpvjbNaG'; // Replace with your EmailJS public key

  @override
  Widget build(BuildContext context) {
    final String name = item['itemName'] ?? 'No Name';
    final String price =
        item['itemPrice']?.toString() ??
        item['pricePerDay']?.toString() ??
        'N/A';
    final String description = item['itemDescription'] ?? 'No Description';
    final String? imageUrl = item['imageUrl'];
    final bool isRental =
        item['type']?.toLowerCase() == 'rental' || item['pricePerDay'] != null;

    final String sellerName =
        isRental
            ? item['renterName'] ?? 'Unknown'
            : item['sellerName'] ?? 'Unknown';
    final String sellerEmail =
        isRental
            ? item['renterEmail'] ?? 'Not provided'
            : item['sellerEmail'] ?? 'Not provided';
    final String sellerPhone =
        isRental
            ? item['renterPhone'] ?? 'Not provided'
            : item['sellerPhone'] ?? 'Not provided';
    final String city =
        isRental ? item['renterCity'] ?? 'Unknown' : item['city'] ?? 'Unknown';
    final String state =
        isRental
            ? item['renterState'] ?? 'Unknown'
            : item['state'] ?? 'Unknown';

    final bool isOwner = loggedInUserEmail == sellerEmail;

    ImageProvider? imageProvider;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      imageProvider = NetworkImage(imageUrl);
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: Colors.purple,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  image:
                      imageProvider != null
                          ? DecorationImage(
                            image: imageProvider,
                            fit: BoxFit.cover,
                          )
                          : null,
                ),
                child:
                    imageProvider == null
                        ? const Center(
                          child: Icon(
                            Icons.image_not_supported,
                            size: 80,
                            color: Colors.grey,
                          ),
                        )
                        : Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.3),
                              ],
                            ),
                          ),
                        ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "₹$price${isRental ? '/day' : ''}",
                                style: const TextStyle(
                                  fontSize: 24,
                                  color: Colors.purple,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isRental)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'RENTAL',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.description,
                                  color: Colors.purple[600],
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  "Description",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              description,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.black54,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.person, color: Colors.purple[600]),
                                const SizedBox(width: 8),
                                const Text(
                                  "Seller Information",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(
                                  Icons.account_circle,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    sellerName,
                                    style: const TextStyle(fontSize: 16),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.phone, color: Colors.grey),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    sellerPhone,
                                    style: const TextStyle(fontSize: 16),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.email, color: Colors.grey),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    sellerEmail,
                                    style: const TextStyle(fontSize: 16),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_city,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    "$city, $state",
                                    style: const TextStyle(fontSize: 16),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (isOwner)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Check your email for requests from buyers',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black54,
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: Icon(
                            isRental ? Icons.schedule : Icons.shopping_cart,
                          ),
                          label: Text(isRental ? 'Rent Now' : 'Buy Now'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            elevation: 3,
                          ),
                          onPressed: () {
                            _showPurchaseDialog(
                              context,
                              name,
                              price,
                              isRental,
                              city,
                              sellerName,
                              sellerEmail,
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPurchaseDialog(
    BuildContext context,
    String itemName,
    String price,
    bool isRental,
    String userCity,
    String sellerName,
    String sellerEmail,
  ) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController emailController = TextEditingController();
    final TextEditingController phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                isRental ? Icons.schedule : Icons.shopping_bag,
                color: Colors.purple,
              ),
              const SizedBox(width: 8),
              Text(isRental ? 'Rent Item' : 'Purchase Item'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Only users from $userCity can purchase this item.',
                  style: const TextStyle(color: Colors.redAccent),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  keyboardType: TextInputType.name,
                  decoration: const InputDecoration(
                    labelText: 'Your Name',
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Your Contact Number',
                    prefixIcon: Icon(Icons.phone),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Your Email',
                    prefixIcon: Icon(Icons.email),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => _handlePurchaseRequest(
                context,
                nameController,
                emailController,
                phoneController,
                sellerEmail,
                sellerName,
                itemName,
                price,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handlePurchaseRequest(
    BuildContext context,
    TextEditingController nameController,
    TextEditingController emailController,
    TextEditingController phoneController,
    String sellerEmail,
    String sellerName,
    String itemName,
    String price,
  ) async {
    final String buyerName = nameController.text.trim();
    final String email = emailController.text.trim();
    final String phone = phoneController.text.trim();

    if (buyerName.isEmpty || email.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter your name, email, and contact number.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final bool isEmailValid = RegExp(
      r'^[\w-\.]+@([\w-]+\.)+[\w]{2,4}',
    ).hasMatch(email);
    final bool isPhoneValid = phone.length >= 10;

    if (!isEmailValid || !isPhoneValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter valid email and phone number.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Close the form dialog first
    Navigator.of(context).pop();

    // Show immediate success message
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Request sent successfully! $sellerName will get in touch with you soon.',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    }

    // Send email in background (fire and forget)
    _sendEmailNotification(
      sellerEmail: sellerEmail,
      sellerName: sellerName,
      itemName: itemName,
      itemPrice: price,
      buyerName: buyerName,
      buyerEmail: email,
      buyerPhone: phone,
    ).catchError((error) {
      print('Failed to send email in background: $error');
      // Optionally, you could show a subtle notification if the email fails
      // but the user has already seen the success message
    });
  }

  Future<void> _sendEmailNotification({
    required String sellerEmail,
    required String sellerName,
    required String itemName,
    required String itemPrice,
    required String buyerName,
    required String buyerEmail,
    required String buyerPhone,
  }) async {
    try {
      final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'origin': 'http://localhost',
        },
        body: json.encode({
          'service_id': _serviceId,
          'template_id': _templateId,
          'user_id': _publicKey,
          'template_params': {
            // Main recipient
            'to_email': sellerEmail,

            // Template variables matching your EmailJS template
            'seller_name': sellerName,
            'item_name': itemName,
            'item_price': itemPrice,
            'buyer_name': buyerName,
            'buyer_email': buyerEmail,
            'buyer_phone': buyerPhone,

            // Additional parameters for debugging
            'reply_to': buyerEmail,
            'from_name': 'FashionNexus',
          },
        }),
      );

      print('EmailJS Response Status: ${response.statusCode}');
      print('EmailJS Response Body: ${response.body}');

      if (response.statusCode == 200) {
        print('Email sent successfully to $sellerEmail');
      } else {
        throw Exception(
          'Failed to send email: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (error) {
      print('Failed to send email: $error');
      rethrow;
    }
  }
}