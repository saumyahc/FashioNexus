import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'order_summary_page.dart';
import 'order_item.dart';

class AddressEntryPage extends StatefulWidget {
  final List<Map<String, dynamic>> items;

  const AddressEntryPage({super.key, required this.items});

  @override
  State<AddressEntryPage> createState() => _AddressEntryPageState();
}

class _AddressEntryPageState extends State<AddressEntryPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController altPhoneController = TextEditingController();
  final TextEditingController houseController = TextEditingController();
  final TextEditingController areaController = TextEditingController();
  final TextEditingController landmarkController = TextEditingController();
  final TextEditingController pincodeController = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  final TextEditingController stateController = TextEditingController();
  final TextEditingController instructionsController = TextEditingController();

  String selectedAddressType = 'Home';
  List<String> addressTypes = ['Home', 'Work', 'Other'];

  bool isLoading = true;
  bool isFirstTimeUser = true;
  bool hasModifiedDetails = false;
  String? userId;

  @override
  void initState() {
    super.initState();
    _initializeUser();
  }

  Future<void> _initializeUser() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        userId = user.uid;
        await _loadUserAddress();
      }
    } catch (e) {
      print('Error initializing user: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadUserAddress() async {
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();

      if (doc.exists && doc.data()!.containsKey('address')) {
        final addressData = doc.data()!['address'] as Map<String, dynamic>;

        setState(() {
          isFirstTimeUser = false;
          nameController.text = addressData['name'] ?? '';
          phoneController.text = addressData['phone'] ?? '';
          altPhoneController.text = addressData['alternatePhone'] ?? '';
          houseController.text = addressData['houseNumber'] ?? '';
          areaController.text = addressData['area'] ?? '';
          landmarkController.text = addressData['landmark'] ?? '';
          pincodeController.text = addressData['pincode'] ?? '';
          cityController.text = addressData['city'] ?? '';
          stateController.text = addressData['state'] ?? '';
          instructionsController.text = addressData['instructions'] ?? '';
          selectedAddressType = addressData['addressType'] ?? 'Home';
        });
      }
    } catch (e) {
      print('Error loading user address: $e');
    }
  }

  Future<void> _saveUserAddress(Map<String, dynamic> addressDetails) async {
    if (userId == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'address': addressDetails,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error saving address: $e');
      // Show error message to user
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save address. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _onFieldChanged() {
    if (!isFirstTimeUser && !hasModifiedDetails) {
      setState(() {
        hasModifiedDetails = true;
      });
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    altPhoneController.dispose();
    houseController.dispose();
    areaController.dispose();
    landmarkController.dispose();
    pincodeController.dispose();
    cityController.dispose();
    stateController.dispose();
    instructionsController.dispose();
    super.dispose();
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 24),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
    Widget? suffixIcon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
        onChanged: (_) => _onFieldChanged(),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.blue, width: 2),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildAddressTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Address Type',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children:
              addressTypes.map((type) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        setState(() => selectedAddressType = type);
                        _onFieldChanged();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color:
                              selectedAddressType == type
                                  ? Colors.blue
                                  : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color:
                                selectedAddressType == type
                                    ? Colors.blue
                                    : Colors.grey.shade300,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              type == 'Home'
                                  ? Icons.home
                                  : type == 'Work'
                                  ? Icons.work
                                  : Icons.location_on,
                              color:
                                  selectedAddressType == type
                                      ? Colors.white
                                      : Colors.grey.shade600,
                              size: 20,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              type,
                              style: TextStyle(
                                color:
                                    selectedAddressType == type
                                        ? Colors.white
                                        : Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildReturningUserHeader() {
    if (isFirstTimeUser) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Your saved address details are pre-filled. You can edit any information if needed.',
              style: TextStyle(
                color: Colors.blue.shade700,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text(
            "Delivery Address",
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          isFirstTimeUser ? "Delivery Address" : "Confirm Address",
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey.shade200),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header for returning users
                    _buildReturningUserHeader(),

                    // Contact Information Section
                    _buildSectionTitle("Contact Information"),
                    _buildTextField(
                      controller: nameController,
                      label: "Full Name",
                      hint: "Enter your full name",
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                      suffixIcon: const Icon(Icons.person_outline),
                    ),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: _buildTextField(
                            controller: phoneController,
                            label: "Phone Number *",
                            hint: "Enter mobile number",
                            keyboardType: TextInputType.phone,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Phone number required';
                              }
                              if (value.length < 10) {
                                return 'Enter valid phone number';
                              }
                              return null;
                            },
                            suffixIcon: const Icon(Icons.phone_outlined),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: _buildTextField(
                            controller: altPhoneController,
                            label: "Alternate Phone",
                            hint: "Optional",
                            keyboardType: TextInputType.phone,
                            suffixIcon: const Icon(Icons.phone_outlined),
                          ),
                        ),
                      ],
                    ),

                    // Address Type Selection
                    _buildAddressTypeSelector(),

                    // Address Details Section
                    _buildSectionTitle("Address Details"),
                    _buildTextField(
                      controller: houseController,
                      label: "House/Flat/Office No. *",
                      hint: "Building name, floor, etc.",
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter house/flat number';
                        }
                        return null;
                      },
                      suffixIcon: const Icon(Icons.home_outlined),
                    ),
                    _buildTextField(
                      controller: areaController,
                      label: "Area/Locality *",
                      hint: "Sector, area, locality",
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter area/locality';
                        }
                        return null;
                      },
                      suffixIcon: const Icon(Icons.location_city_outlined),
                    ),
                    _buildTextField(
                      controller: landmarkController,
                      label: "Nearby Landmark",
                      hint: "E.g., near metro station, mall",
                      suffixIcon: const Icon(Icons.place_outlined),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: pincodeController,
                            label: "Pincode *",
                            hint: "6-digit pincode",
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Pincode required';
                              }
                              if (value.length != 6) {
                                return 'Enter valid pincode';
                              }
                              return null;
                            },
                            suffixIcon: const Icon(Icons.pin_drop_outlined),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: cityController,
                            label: "City *",
                            hint: "Your city",
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'City required';
                              }
                              return null;
                            },
                            suffixIcon: const Icon(Icons.location_city),
                          ),
                        ),
                      ],
                    ),
                    _buildTextField(
                      controller: stateController,
                      label: "State *",
                      hint: "Your state",
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter state';
                        }
                        return null;
                      },
                      suffixIcon: const Icon(Icons.map_outlined),
                    ),

                    // Delivery Instructions Section
                    _buildSectionTitle("Delivery Instructions"),
                    _buildTextField(
                      controller: instructionsController,
                      label: "Special Instructions",
                      hint: "Any specific delivery instructions (optional)",
                      maxLines: 3,
                      suffixIcon: const Icon(Icons.note_outlined),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // Bottom Button
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade200,
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        // Show loading indicator
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder:
                              (context) => const Center(
                                child: CircularProgressIndicator(),
                              ),
                        );

                        // Create address map with all details
                        final addressDetails = {
                          'name': nameController.text,
                          'phone': phoneController.text,
                          'alternatePhone': altPhoneController.text,
                          'houseNumber': houseController.text,
                          'area': areaController.text,
                          'landmark': landmarkController.text,
                          'pincode': pincodeController.text,
                          'city': cityController.text,
                          'state': stateController.text,
                          'addressType': selectedAddressType,
                          'instructions': instructionsController.text,
                          'fullAddress':
                              '${houseController.text}, ${areaController.text}, ${cityController.text}, ${stateController.text} - ${pincodeController.text}',
                        };

                        // Save address to Firebase (for first-time users or when details are modified)
                        if (isFirstTimeUser || hasModifiedDetails) {
                          await _saveUserAddress(addressDetails);
                        }

                        // Hide loading indicator
                        Navigator.of(context).pop();

                        // Convert each map to an OrderItem
                        final orderItems =
                            widget.items
                                .map((item) => OrderItem.fromMap(item))
                                .toList();

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => OrderSummaryPage(
                                  address: addressDetails['fullAddress']!,
                                  phone: phoneController.text,
                                  items: orderItems,
                                  addressDetails: addressDetails,
                                ),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      isFirstTimeUser
                          ? "Save Address & Continue"
                          : hasModifiedDetails
                          ? "Update & Continue"
                          : "Continue to Order Summary",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
