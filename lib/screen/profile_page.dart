import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _bioController = TextEditingController();

  String? _selectedGender;
  DateTime? _selectedDate;
  String? _profileImageBase64;
  File? _imageFile;
  bool _isLoading = false;
  bool _isEditing = false;
  bool _isDarkMode = false;
  String _selectedLanguage = 'English';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Language options
  final Map<String, String> _languages = {
    'English': 'en',
    'Spanish': 'es',
    'French': 'fr',
    'German': 'de',
    'Italian': 'it',
    'Portuguese': 'pt',
    'Hindi': 'hi',
    'Gujarati': 'gu',
  };

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadUserPreferences();
  }

  Future<void> _loadUserPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
      _selectedLanguage = prefs.getString('selectedLanguage') ?? 'English';
    });
  }

  Future<void> _saveUserPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _isDarkMode);
    await prefs.setString('selectedLanguage', _selectedLanguage);
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    try {
      User? user = _auth.currentUser;
      if (user != null) {
        DocumentSnapshot doc =
            await _firestore.collection('users').doc(user.uid).get();

        if (doc.exists) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

          _nameController.text = data['name'] ?? '';
          _emailController.text = data['email'] ?? user.email ?? '';
          _phoneController.text = data['phone'] ?? '';
          _addressController.text = data['address'] ?? '';
          _cityController.text = data['city'] ?? '';
          _postalCodeController.text = data['postalCode'] ?? '';
          _bioController.text = data['bio'] ?? '';
          _selectedGender = data['gender'];
          _profileImageBase64 = data['profileImageBase64'];

          if (data['dateOfBirth'] != null) {
            _selectedDate = (data['dateOfBirth'] as Timestamp).toDate();
          }
        }
      }
    } catch (e) {
      _showSnackBar('Error loading profile: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _saveUserData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      User? user = _auth.currentUser;
      if (user != null) {
        String? imageBase64 = _profileImageBase64;

        // Convert image to base64 if new image is selected
        if (_imageFile != null) {
          imageBase64 = await _convertImageToBase64(_imageFile!);
        }

        Map<String, dynamic> userData = {
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
          'address': _addressController.text.trim(),
          'city': _cityController.text.trim(),
          'postalCode': _postalCodeController.text.trim(),
          'bio': _bioController.text.trim(),
          'gender': _selectedGender,
          'dateOfBirth':
              _selectedDate != null ? Timestamp.fromDate(_selectedDate!) : null,
          'profileImageBase64': imageBase64,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        await _firestore
            .collection('users')
            .doc(user.uid)
            .set(userData, SetOptions(merge: true));

        _showSnackBar('Profile updated successfully!');
        setState(() => _isEditing = false);
      }
    } catch (e) {
      _showSnackBar('Error saving profile: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<String?> _convertImageToBase64(File imageFile) async {
    try {
      Uint8List imageBytes = await imageFile.readAsBytes();

      // Increased size limit to ~5MB for better quality images
      if (imageBytes.length > 5000000) {
        _showSnackBar(
          'Image too large. Please select an image smaller than 5MB.',
        );
        return null;
      }

      String base64String = base64Encode(imageBytes);
      return base64String;
    } catch (e) {
      _showSnackBar('Error processing image: $e');
      return null;
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();

    // Show options for camera or gallery
    showModalBottomSheet(
      context: context,
      backgroundColor: _isDarkMode ? Colors.grey[800] : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Container(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Select Image Source',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildImageSourceOption(
                      icon: Icons.camera_alt,
                      label: 'Camera',
                      onTap: () async {
                        Navigator.pop(context);
                        final XFile? image = await picker.pickImage(
                          source: ImageSource.camera,
                          maxWidth: 1024,
                          maxHeight: 1024,
                          imageQuality: 85,
                        );
                        if (image != null) {
                          setState(() {
                            _imageFile = File(image.path);
                          });
                        }
                      },
                    ),
                    _buildImageSourceOption(
                      icon: Icons.photo_library,
                      label: 'Gallery',
                      onTap: () async {
                        Navigator.pop(context);
                        final XFile? image = await picker.pickImage(
                          source: ImageSource.gallery,
                          maxWidth: 1024,
                          maxHeight: 1024,
                          imageQuality: 85,
                        );
                        if (image != null) {
                          setState(() {
                            _imageFile = File(image.path);
                          });
                        }
                      },
                    ),
                  ],
                ),
                SizedBox(height: 20),
              ],
            ),
          ),
    );
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.pink.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          children: [
            Icon(icon, size: 40, color: Colors.pink),
            SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          _selectedDate ?? DateTime.now().subtract(Duration(days: 365 * 20)),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.pink,
              onPrimary: Colors.white,
              surface: _isDarkMode ? Colors.grey[800]! : Colors.white,
              onSurface: _isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.pink,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        color: _isDarkMode ? Colors.grey[900] : Colors.white,
        child: Column(
          children: [
            Container(
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.pink, Colors.pink.shade300],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white,
                      child: _buildProfileImage(80),
                    ),
                    SizedBox(height: 10),
                    Text(
                      _nameController.text.isEmpty
                          ? 'Your Name'
                          : _nameController.text,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _emailController.text.isEmpty
                          ? 'your.email@example.com'
                          : _emailController.text,
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildDrawerItem(
                    icon: Icons.person,
                    title: 'Profile',
                    onTap: () => Navigator.pop(context),
                    isSelected: true,
                  ),
                  _buildDrawerItem(
                    icon: Icons.settings,
                    title: 'Settings',
                    onTap: () {
                      Navigator.pop(context);
                      _showSettingsDialog();
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.notifications,
                    title: 'Notifications',
                    onTap: () {
                      Navigator.pop(context);
                      _showSnackBar('Notifications feature coming soon!');
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.privacy_tip,
                    title: 'Privacy',
                    onTap: () {
                      Navigator.pop(context);
                      _showSnackBar('Privacy settings coming soon!');
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.help,
                    title: 'Help & Support',
                    onTap: () {
                      Navigator.pop(context);
                      _showSnackBar('Help & Support coming soon!');
                    },
                  ),
                  Divider(
                    color: _isDarkMode ? Colors.grey[700] : Colors.grey[300],
                  ),
                  _buildDrawerItem(
                    icon: Icons.logout,
                    title: 'Logout',
                    onTap: () => _showLogoutDialog(),
                    isDestructive: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isSelected = false,
    bool isDestructive = false,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isSelected ? Colors.pink.withOpacity(0.1) : Colors.transparent,
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color:
              isDestructive
                  ? Colors.red
                  : (isSelected
                      ? Colors.pink
                      : (_isDarkMode ? Colors.grey[300] : Colors.grey[600])),
        ),
        title: Text(
          title,
          style: TextStyle(
            color:
                isDestructive
                    ? Colors.red
                    : (isSelected
                        ? Colors.pink
                        : (_isDarkMode ? Colors.white : Colors.grey[800])),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: _isDarkMode ? Colors.grey[800] : Colors.white,
            title: Text(
              'Settings',
              style: TextStyle(
                color: _isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(
                    _isDarkMode ? Icons.dark_mode : Icons.light_mode,
                    color: Colors.pink,
                  ),
                  title: Text(
                    'Dark Mode',
                    style: TextStyle(
                      color: _isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  trailing: Switch(
                    value: _isDarkMode,
                    onChanged: (value) {
                      setState(() {
                        _isDarkMode = value;
                      });
                      _saveUserPreferences();
                      Navigator.pop(context);
                      _showSnackBar('Theme updated successfully!');
                    },
                    activeColor: Colors.pink,
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.language, color: Colors.pink),
                  title: Text(
                    'Language',
                    style: TextStyle(
                      color: _isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  subtitle: Text(
                    _selectedLanguage,
                    style: TextStyle(
                      color: _isDarkMode ? Colors.grey[300] : Colors.grey[600],
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showLanguageDialog();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.delete, color: Colors.red),
                  title: Text(
                    'Delete Account',
                    style: TextStyle(
                      color: _isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showDeleteAccountDialog();
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close', style: TextStyle(color: Colors.pink)),
              ),
            ],
          ),
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: _isDarkMode ? Colors.grey[800] : Colors.white,
            title: Text(
              'Select Language',
              style: TextStyle(
                color: _isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _languages.length,
                itemBuilder: (context, index) {
                  String language = _languages.keys.elementAt(index);
                  return ListTile(
                    title: Text(
                      language,
                      style: TextStyle(
                        color: _isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    leading: Radio<String>(
                      value: language,
                      groupValue: _selectedLanguage,
                      onChanged: (value) {
                        setState(() {
                          _selectedLanguage = value!;
                        });
                        _saveUserPreferences();
                        Navigator.pop(context);
                        _showSnackBar('Language updated to $value');
                      },
                      activeColor: Colors.pink,
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: TextStyle(color: Colors.pink)),
              ),
            ],
          ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: _isDarkMode ? Colors.grey[800] : Colors.white,
            title: Text(
              'Logout',
              style: TextStyle(
                color: _isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            content: Text(
              'Are you sure you want to logout?',
              style: TextStyle(
                color: _isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              TextButton(
                onPressed: () async {
                  await _auth.signOut();
                  Navigator.pop(context);
                  _showSnackBar('Logged out successfully');
                },
                child: Text('Logout', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: _isDarkMode ? Colors.grey[800] : Colors.white,
            title: Text(
              'Delete Account',
              style: TextStyle(
                color: _isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            content: Text(
              'Are you sure you want to delete your account? This action cannot be undone.',
              style: TextStyle(
                color: _isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showSnackBar('Account deletion feature coming soon!');
                },
                child: Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
  }

  Widget _buildProfileImage(double size) {
    if (_imageFile != null) {
      return ClipOval(
        child: Image.file(
          _imageFile!,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    } else if (_profileImageBase64 != null) {
      try {
        Uint8List imageBytes = base64Decode(_profileImageBase64!);
        return ClipOval(
          child: Image.memory(
            imageBytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        );
      } catch (e) {
        return Icon(
          Icons.person,
          size: size * 0.6,
          color: _isDarkMode ? Colors.grey[300] : Colors.grey[400],
        );
      }
    } else {
      return Icon(
        Icons.person,
        size: size * 0.6,
        color: _isDarkMode ? Colors.grey[300] : Colors.grey[400],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkMode ? Colors.grey[900] : Colors.grey[50],
      drawer: _buildDrawer(),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _isDarkMode ? Colors.grey[850] : Colors.white,
        leading: Builder(
          builder:
              (context) => IconButton(
                icon: Icon(Icons.menu, color: Colors.pink),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
        ),
        title: Text(
          'Profile',
          style: TextStyle(
            color: _isDarkMode ? Colors.white : Colors.black87,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          if (!_isEditing)
            IconButton(
              icon: Icon(Icons.edit, color: Colors.pink),
              onPressed: () => setState(() => _isEditing = true),
            ),
        ],
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator(color: Colors.pink))
              : SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildProfileHeader(),
                      SizedBox(height: 30),
                      _buildInfoSection(),
                      SizedBox(height: 30),
                      if (_isEditing) _buildActionButtons(),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _isDarkMode ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDarkMode ? 0.3 : 0.05),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.pink, width: 3),
                ),
                child: _buildProfileImage(120),
              ),
              if (_isEditing)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.pink,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 15),
          Text(
            _nameController.text.isEmpty ? 'Your Name' : _nameController.text,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          SizedBox(height: 5),
          Text(
            _emailController.text.isEmpty
                ? 'your.email@example.com'
                : _emailController.text,
            style: TextStyle(
              fontSize: 16,
              color: _isDarkMode ? Colors.grey[300] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _isDarkMode ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDarkMode ? 0.3 : 0.05),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Personal Information',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          SizedBox(height: 20),
          _buildTextField('Full Name', _nameController, Icons.person),
          SizedBox(height: 15),
          _buildTextField('Email', _emailController, Icons.email),
          SizedBox(height: 15),
          _buildTextField('Phone', _phoneController, Icons.phone),
          SizedBox(height: 15),
          _buildGenderField(),
          SizedBox(height: 15),
          _buildDateField(),
          SizedBox(height: 15),
          _buildTextField(
            'Address',
            _addressController,
            Icons.location_on,
            maxLines: 2,
          ),
          SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  'City',
                  _cityController,
                  Icons.location_city,
                ),
              ),
              SizedBox(width: 15),
              Expanded(
                child: _buildTextField(
                  'Postal Code',
                  _postalCodeController,
                  Icons.local_post_office,
                ),
              ),
            ],
          ),
          SizedBox(height: 15),
          _buildTextField('Bio', _bioController, Icons.info, maxLines: 3),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      enabled: _isEditing,
      maxLines: maxLines,
      style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: _isDarkMode ? Colors.grey[300] : Colors.grey[600],
        ),
        prefixIcon: Icon(icon, color: Colors.pink),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: _isDarkMode ? Colors.grey[600]! : Colors.grey[300]!,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: _isDarkMode ? Colors.grey[600]! : Colors.grey[300]!,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.pink, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: _isDarkMode ? Colors.grey[700]! : Colors.grey[200]!,
          ),
        ),
        filled: true,
        fillColor:
            _isEditing
                ? (_isDarkMode ? Colors.grey[700] : Colors.white)
                : (_isDarkMode ? Colors.grey[750] : Colors.grey[50]),
      ),
      validator: (value) {
        if (label == 'Full Name' && (value == null || value.isEmpty)) {
          return 'Please enter your name';
        }
        if (label == 'Email' &&
            (value == null || value.isEmpty || !value.contains('@'))) {
          return 'Please enter a valid email';
        }
        return null;
      },
    );
  }

  Widget _buildGenderField() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color:
              _isEditing
                  ? (_isDarkMode ? Colors.grey[600]! : Colors.grey[300]!)
                  : (_isDarkMode ? Colors.grey[700]! : Colors.grey[200]!),
        ),
        borderRadius: BorderRadius.circular(12),
        color:
            _isEditing
                ? (_isDarkMode ? Colors.grey[700] : Colors.white)
                : (_isDarkMode ? Colors.grey[750] : Colors.grey[50]),
      ),
      child: ListTile(
        leading: Icon(Icons.wc, color: Colors.pink),
        title: Text(
          'Gender',
          style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black87),
        ),
        subtitle: Text(
          _selectedGender ?? 'Select Gender',
          style: TextStyle(
            color: _isDarkMode ? Colors.grey[300] : Colors.grey[600],
          ),
        ),
        trailing:
            _isEditing
                ? Icon(
                  Icons.arrow_drop_down,
                  color: _isDarkMode ? Colors.white : Colors.black87,
                )
                : null,
        onTap: _isEditing ? () => _showGenderDialog() : null,
      ),
    );
  }

  Widget _buildDateField() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color:
              _isEditing
                  ? (_isDarkMode ? Colors.grey[600]! : Colors.grey[300]!)
                  : (_isDarkMode ? Colors.grey[700]! : Colors.grey[200]!),
        ),
        borderRadius: BorderRadius.circular(12),
        color:
            _isEditing
                ? (_isDarkMode ? Colors.grey[700] : Colors.white)
                : (_isDarkMode ? Colors.grey[750] : Colors.grey[50]),
      ),
      child: ListTile(
        leading: Icon(Icons.calendar_today, color: Colors.pink),
        title: Text(
          'Date of Birth',
          style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black87),
        ),
        subtitle: Text(
          _selectedDate != null
              ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
              : 'Select Date of Birth',
          style: TextStyle(
            color: _isDarkMode ? Colors.grey[300] : Colors.grey[600],
          ),
        ),
        trailing:
            _isEditing
                ? Icon(
                  Icons.arrow_drop_down,
                  color: _isDarkMode ? Colors.white : Colors.black87,
                )
                : null,
        onTap: _isEditing ? _selectDate : null,
      ),
    );
  }

  void _showGenderDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: _isDarkMode ? Colors.grey[800] : Colors.white,
            title: Text(
              'Select Gender',
              style: TextStyle(
                color: _isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(
                    'Male',
                    style: TextStyle(
                      color: _isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  leading: Radio<String>(
                    value: 'Male',
                    groupValue: _selectedGender,
                    onChanged: (value) {
                      setState(() => _selectedGender = value);
                      Navigator.pop(context);
                    },
                    activeColor: Colors.pink,
                  ),
                ),
                ListTile(
                  title: Text(
                    'Female',
                    style: TextStyle(
                      color: _isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  leading: Radio<String>(
                    value: 'Female',
                    groupValue: _selectedGender,
                    onChanged: (value) {
                      setState(() => _selectedGender = value);
                      Navigator.pop(context);
                    },
                    activeColor: Colors.pink,
                  ),
                ),
                ListTile(
                  title: Text(
                    'Other',
                    style: TextStyle(
                      color: _isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  leading: Radio<String>(
                    value: 'Other',
                    groupValue: _selectedGender,
                    onChanged: (value) {
                      setState(() => _selectedGender = value);
                      Navigator.pop(context);
                    },
                    activeColor: Colors.pink,
                  ),
                ),
                ListTile(
                  title: Text(
                    'Prefer not to say',
                    style: TextStyle(
                      color: _isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  leading: Radio<String>(
                    value: 'Prefer not to say',
                    groupValue: _selectedGender,
                    onChanged: (value) {
                      setState(() => _selectedGender = value);
                      Navigator.pop(context);
                    },
                    activeColor: Colors.pink,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: TextStyle(color: Colors.pink)),
              ),
            ],
          ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              setState(() => _isEditing = false);
              _loadUserData(); // Reset to original data
            },
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _isDarkMode ? Colors.grey[700] : Colors.grey[300],
              foregroundColor: _isDarkMode ? Colors.white : Colors.black87,
              padding: EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('Cancel', style: TextStyle(fontSize: 16)),
          ),
        ),
        SizedBox(width: 15),
        Expanded(
          child: ElevatedButton(
            onPressed: _saveUserData,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.pink,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('Save Changes', style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    _bioController.dispose();
    super.dispose();
  }
}
