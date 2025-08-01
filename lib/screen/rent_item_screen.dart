import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RentItemScreen extends StatefulWidget {
  const RentItemScreen({super.key});

  @override
  State<RentItemScreen> createState() => _RentItemScreenState();
}

class _RentItemScreenState extends State<RentItemScreen>
    with TickerProviderStateMixin {
  final TextEditingController _renterNameController = TextEditingController();
  final TextEditingController _renterPhoneController = TextEditingController();
  final TextEditingController _renterEmailController = TextEditingController();
  final TextEditingController _renterCityController = TextEditingController();
  final TextEditingController _renterStateController = TextEditingController();
  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _itemDescriptionController = TextEditingController();
  final TextEditingController _itemPriceController = TextEditingController();

  bool _isUploading = false;
  File? _selectedImage;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final ImagePicker _picker = ImagePicker();

  // TODO: Replace these with your Cloudinary account details
  final String cloudinaryUploadPreset = 'saumya chandwani';
  final String cloudinaryCloudName = 'dleiye4er';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _renterNameController.dispose();
    _renterPhoneController.dispose();
    _renterEmailController.dispose();
    _renterCityController.dispose();
    _renterStateController.dispose();
    _itemNameController.dispose();
    _itemDescriptionController.dispose();
    _itemPriceController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Select Image Source',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildImageSourceButton(
                        icon: Icons.camera_alt,
                        label: 'Camera',
                        onTap: () async {
                          Navigator.pop(context);
                          final picked = await _picker.pickImage(
                            source: ImageSource.camera,
                            imageQuality: 70,
                          );
                          if (picked != null) _setImage(File(picked.path));
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildImageSourceButton(
                        icon: Icons.photo_library,
                        label: 'Gallery',
                        onTap: () async {
                          Navigator.pop(context);
                          final picked = await _picker.pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 70,
                          );
                          if (picked != null) _setImage(File(picked.path));
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageSourceButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple.shade400, Colors.purple.shade300],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.deepPurple.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: Colors.white),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _setImage(File imageFile) {
    setState(() {
      _selectedImage = imageFile;
    });
  }

  Future<String> _uploadImageToCloudinary(File imageFile) async {
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudinaryCloudName/image/upload',
    );

    var request = http.MultipartRequest('POST', uri);
    request.fields['upload_preset'] = cloudinaryUploadPreset;
    request.files.add(
      await http.MultipartFile.fromPath('file', imageFile.path),
    );

    var response = await request.send();
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to upload image to Cloudinary');
    }

    var resStr = await response.stream.bytesToString();
    var jsonRes = json.decode(resStr);

    return jsonRes['secure_url'];
  }

  Future<void> _uploadItem() async {
    if (_isUploading) return;

    if (_renterNameController.text.isEmpty ||
        _renterPhoneController.text.isEmpty ||
        _renterEmailController.text.isEmpty ||
        _renterCityController.text.isEmpty ||
        _renterStateController.text.isEmpty ||
        _itemNameController.text.isEmpty ||
        _itemDescriptionController.text.isEmpty ||
        _itemPriceController.text.isEmpty ||
        _selectedImage == null) {
      _showSnackBar(
        "Please fill all fields and select an image",
        isError: true,
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not signed in");

      // Upload image to Cloudinary
      String imageUrl = await _uploadImageToCloudinary(_selectedImage!);

      final String itemId = const Uuid().v4();

      // FIXED: Save to 'items' collection instead of 'rental_items'
      // and use consistent field names that match RentAndSellPage
      await FirebaseFirestore.instance.collection("items").doc(itemId).set({
        "itemId": itemId,
        "sellerName": _renterNameController.text.trim(), // Changed from renterName
        "sellerPhone": _renterPhoneController.text.trim(), // Changed from renterPhone
        "sellerEmail": _renterEmailController.text.trim(), // Changed from renterEmail
        "city": _renterCityController.text.trim(), // Changed from renterCity
        "state": _renterStateController.text.trim(), // Changed from renterState
        "itemName": _itemNameController.text.trim(),
        "itemDescription": _itemDescriptionController.text.trim(),
        "itemPrice": _itemPriceController.text.trim(), // Changed from pricePerDay
        "imageUrl": imageUrl,
        "ownerId": user.uid,
        "type": "rent", // Added type field
        "createdAt": Timestamp.now(),
      });

      if (!mounted) return;
      _showSnackBar("Item listed for rent successfully!", isError: false);

      // Clear form after successful upload
      _clearForm();

      Navigator.pop(context);
    } catch (e) {
      debugPrint("Upload error: $e");
      _showSnackBar("Upload failed: ${e.toString()}", isError: true);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _clearForm() {
    _renterNameController.clear();
    _renterPhoneController.clear();
    _renterEmailController.clear();
    _renterCityController.clear();
    _renterStateController.clear();
    _itemNameController.clear();
    _itemDescriptionController.clear();
    _itemPriceController.clear();
    setState(() {
      _selectedImage = null;
    });
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red[600] : Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          prefixIcon: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
          filled: true,
          fillColor: Colors.white.withOpacity(0.1),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.white, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildImageUploadSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: _selectedImage == null
                    ? LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.1),
                          Colors.white.withOpacity(0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: _selectedImage == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.add_photo_alternate,
                            size: 48,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Tap to add item photo',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Camera or Gallery',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(_selectedImage!, fit: BoxFit.cover),
                          Positioned(
                            top: 12,
                            right: 12,
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedImage = null),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Tap to change',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.deepPurple.shade800,
              Colors.deepPurple.shade600,
              Colors.purple.shade400,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom App Bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    const Expanded(
                      child: Center(
                        child: Text(
                          'List Item for Rent',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 44), // Balance the back button
                  ],
                ),
              ),

              // Content
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildImageUploadSection(),

                        const Text(
                          'Renter Information',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),

                        _buildTextField(
                          controller: _renterNameController,
                          hint: 'Renter Name',
                          icon: Icons.person_outline,
                        ),

                        _buildTextField(
                          controller: _renterPhoneController,
                          hint: 'Phone Number',
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                        ),

                        _buildTextField(
                          controller: _renterEmailController,
                          hint: 'Email Address',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                        ),

                        _buildTextField(
                          controller: _renterCityController,
                          hint: 'City',
                          icon: Icons.location_city,
                        ),

                        _buildTextField(
                          controller: _renterStateController,
                          hint: 'State',
                          icon: Icons.map_outlined,
                        ),

                        const SizedBox(height: 24),

                        const Text(
                          'Item Details',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),

                        _buildTextField(
                          controller: _itemNameController,
                          hint: 'Item Name',
                          icon: Icons.inventory_2_outlined,
                        ),

                        _buildTextField(
                          controller: _itemDescriptionController,
                          hint: 'Item Description',
                          icon: Icons.description_outlined,
                          maxLines: 3,
                        ),

                        _buildTextField(
                          controller: _itemPriceController,
                          hint: 'Price per Day (₹)',
                          icon: Icons.currency_rupee,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Upload Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.deepPurple.shade800,
                              elevation: 8,
                              shadowColor: Colors.black.withOpacity(0.3),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: _isUploading ? null : _uploadItem,
                            child: _isUploading
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            Colors.deepPurple.shade800,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      const Text(
                                        'Listing...',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  )
                                : const Text(
                                    'List for Rent',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
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
        ),
      ),
    );
  }
}