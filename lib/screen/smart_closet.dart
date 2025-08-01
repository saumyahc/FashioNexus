import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image/image.dart' as img;

class SmartClosetScreen extends StatefulWidget {
  const SmartClosetScreen({super.key});

  @override
  _SmartClosetScreenState createState() => _SmartClosetScreenState();
}

class _SmartClosetScreenState extends State<SmartClosetScreen> {
  File? _selectedImage;
  List<Map<String, dynamic>> _closetItems = [];
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  bool _isUploading = false;
  String _selectedFilter = 'All';

  final List<String> _categories = [
    'All',
    'Topwear',
    'Bottomwear',
    'Footwear',
    'Dress',
    'Accessories',
  ];

  @override
  void initState() {
    super.initState();
    _initializeCloset();
  }

  // Initialize closet - fix existing documents first, then load items
  Future<void> _initializeCloset() async {
    await _fixExistingDocuments();
    await _loadClosetItems();
  }

  // Improved Load closet items from Firebase with better null handling
  Future<void> _loadClosetItems() async {
    setState(() => _isLoading = true);
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        QuerySnapshot snapshot =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('closet_items')
                .orderBy('timestamp', descending: true)
                .get();

        setState(() {
          _closetItems =
              snapshot.docs.map((doc) {
                Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

                return {
                  'id': doc.id,
                  'imageBase64': data['imageBase64'] ?? '',
                  'category': data['category'] ?? 'Unknown',
                  'timestamp': data['timestamp'],
                  'color': data['color'] ?? 'Unknown',
                  'season': data['season'] ?? 'All Season',
                  'subCategory': data['subCategory'] ?? '',
                  'confidence': data['confidence'] ?? 0.0,
                };
              }).toList();
        });
      }
    } catch (e) {
      print('Error loading closet items: $e');
      _showErrorDialog('Failed to load closet items. Please try again.');
    }
    setState(() => _isLoading = false);
  }

  // Enhanced method to fix existing documents
  Future<void> _fixExistingDocuments() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        QuerySnapshot snapshot =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('closet_items')
                .get();

        WriteBatch batch = FirebaseFirestore.instance.batch();
        bool needsUpdate = false;

        for (QueryDocumentSnapshot doc in snapshot.docs) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

          Map<String, dynamic> updates = {};

          if (!data.containsKey('subCategory')) {
            updates['subCategory'] = '';
            needsUpdate = true;
          }
          if (!data.containsKey('color')) {
            updates['color'] = 'Unknown';
            needsUpdate = true;
          }
          if (!data.containsKey('season')) {
            updates['season'] = 'All Season';
            needsUpdate = true;
          }
          if (!data.containsKey('confidence')) {
            updates['confidence'] = 0.0;
            needsUpdate = true;
          }

          if (updates.isNotEmpty) {
            batch.update(doc.reference, updates);
          }
        }

        if (needsUpdate) {
          await batch.commit();
          print('Fixed existing documents');
        }
      }
    } catch (e) {
      print('Error fixing documents: $e');
    }
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Add New Item',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildImageSourceButton(
                      icon: Icons.camera_alt,
                      label: 'Camera',
                      onTap: () => _selectImage(ImageSource.camera),
                    ),
                    _buildImageSourceButton(
                      icon: Icons.photo_library,
                      label: 'Gallery',
                      onTap: () => _selectImage(ImageSource.gallery),
                    ),
                  ],
                ),
              ],
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
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF6C63FF).withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 40, color: const Color(0xFF6C63FF)),
            const SizedBox(height: 10),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Future<void> _selectImage(ImageSource source) async {
    Navigator.pop(context);
    final pickedFile = await _picker.pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 70,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
        _isUploading = true;
      });
      await _processAndUploadImage(_selectedImage!);
    }
  }

  // Convert image to base64 string with proper pixel handling
  Future<String> _imageToBase64(File imageFile) async {
    try {
      List<int> imageBytes = await imageFile.readAsBytes();

      img.Image? image = img.decodeImage(Uint8List.fromList(imageBytes));
      if (image != null) {
        // Resize if too large, maintaining aspect ratio
        if (image.width > 600 || image.height > 600) {
          if (image.width > image.height) {
            image = img.copyResize(image, width: 400);
          } else {
            image = img.copyResize(image, height: 400);
          }
        }

        List<int> compressedBytes = img.encodeJpg(image, quality: 60);
        String base64String = base64Encode(compressedBytes);

        // Further compress if still too large
        if (base64String.length > 800000) {
          if (image.width > image.height) {
            image = img.copyResize(image, width: 300);
          } else {
            image = img.copyResize(image, height: 300);
          }
          compressedBytes = img.encodeJpg(image, quality: 40);
          base64String = base64Encode(compressedBytes);
        }

        return base64String;
      }

      return base64Encode(imageBytes);
    } catch (e) {
      throw Exception('Failed to process image: $e');
    }
  }

  // Enhanced processAndUploadImage method with better error handling
  Future<void> _processAndUploadImage(File imageFile) async {
    try {
      final detection = await _detectClothingDetails(imageFile);
      String imageBase64 = await _imageToBase64(imageFile);

      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      Map<String, dynamic> itemData = {
        'imageBase64': imageBase64,
        'category': detection['category'] ?? 'Unknown',
        'subCategory': detection['subCategory'] ?? '',
        'color': detection['color'] ?? 'Unknown',
        'season': detection['season'] ?? 'All Season',
        'confidence': detection['confidence'] ?? 0.0,
        'timestamp': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('closet_items')
          .add(itemData);

      _showSuccessDialog(detection['category'] ?? 'Unknown');
      await _loadClosetItems();
    } catch (e) {
      print('Error processing image: $e');
      _showErrorDialog('Failed to add item. Please try again.');
    }

    setState(() {
      _isUploading = false;
      _selectedImage = null;
    });
  }

  // ENHANCED DETECTION WITH MULTIPLE ML MODELS AND IMPROVED LOGIC
  Future<Map<String, dynamic>> _detectClothingDetails(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);

      // Use multiple ML models for better accuracy
      final results = await Future.wait([
        _performImageLabeling(inputImage),
        _performObjectDetection(inputImage),
        _performTextRecognition(inputImage), // For brand/text analysis
      ]);

      final labels = results[0] as List<ImageLabel>;
      final objects = results[1] as List<DetectedObject>;
      final recognizedText = results[2] as RecognizedText;

      // Enhanced detection with weighted scoring
      final detection = _analyzeWithAdvancedLogic(
        labels,
        objects,
        recognizedText,
      );

      return detection;
    } catch (e) {
      print('Error detecting clothing details: $e');
      return {
        'category': 'Unknown',
        'subCategory': '',
        'color': 'Unknown',
        'season': 'All Season',
        'confidence': 0.0,
      };
    }
  }

  // Enhanced image labeling with better confidence handling
  Future<List<ImageLabel>> _performImageLabeling(InputImage inputImage) async {
    final labeler = ImageLabeler(
      options: ImageLabelerOptions(
        confidenceThreshold: 0.1,
      ), // Lower threshold for more labels
    );
    return await labeler.processImage(inputImage);
  }

  // Add object detection for better shape/structure analysis
  Future<List<DetectedObject>> _performObjectDetection(
    InputImage inputImage,
  ) async {
    try {
      final objectDetector = ObjectDetector(
        options: ObjectDetectorOptions(
          mode: DetectionMode.single,
          classifyObjects: true,
          multipleObjects: false,
        ),
      );
      return await objectDetector.processImage(inputImage);
    } catch (e) {
      print('Object detection error: $e');
      return [];
    }
  }

  // Add text recognition for brand/label detection
  Future<RecognizedText> _performTextRecognition(InputImage inputImage) async {
    try {
      final textRecognizer = TextRecognizer();
      return await textRecognizer.processImage(inputImage);
    } catch (e) {
      print('Text recognition error: $e');
      return RecognizedText(text: '', blocks: []);
    }
  }

  // ADVANCED ANALYSIS WITH WEIGHTED SCORING SYSTEM
  Map<String, dynamic> _analyzeWithAdvancedLogic(
    List<ImageLabel> labels,
    List<DetectedObject> objects,
    RecognizedText recognizedText,
  ) {
    // Create weighted label map
    Map<String, double> labelWeights = {};
    for (var label in labels) {
      labelWeights[label.label.toLowerCase()] = label.confidence;
    }

    // Analyze detected text for additional context
    final textContext = _analyzeRecognizedText(recognizedText);

    // Enhanced category detection with scoring
    final categoryResults = _detectCategoryWithScoring(
      labelWeights,
      objects,
      textContext,
    );

    String bestCategory = categoryResults['category'];
    double confidence = categoryResults['confidence'];

    // Detect other attributes based on the determined category
    String subCategory = _detectEnhancedSubCategory(
      labelWeights,
      bestCategory,
      textContext,
    );
    String color = _detectEnhancedColor(labelWeights, objects);
    String season = _detectEnhancedSeason(labelWeights, bestCategory);

    print('Final detection - Category: $bestCategory, Confidence: $confidence');
    print('Detected labels: ${labelWeights.keys.toList()}');

    return {
      'category': bestCategory,
      'subCategory': subCategory,
      'color': color,
      'season': season,
      'confidence': confidence,
    };
  }

  // Analyze recognized text for additional context
  Map<String, dynamic> _analyzeRecognizedText(RecognizedText recognizedText) {
    List<String> textElements = [];
    for (var block in recognizedText.blocks) {
      for (var line in block.lines) {
        textElements.add(line.text.toLowerCase());
      }
    }

    return {
      'hasSize': textElements.any(
        (text) => RegExp(r'\b(xs|s|m|l|xl|xxl|\d+)\b').hasMatch(text),
      ),
      'hasBrand': textElements.any(
        (text) => [
          'nike',
          'adidas',
          'zara',
          'h&m',
          'uniqlo',
        ].any((brand) => text.contains(brand)),
      ),
      'textElements': textElements,
    };
  }

  // ENHANCED CATEGORY DETECTION WITH WEIGHTED SCORING
  Map<String, dynamic> _detectCategoryWithScoring(
    Map<String, double> labelWeights,
    List<DetectedObject> objects,
    Map<String, dynamic> textContext,
  ) {
    Map<String, double> categoryScores = {
      'Topwear': 0.0,
      'Bottomwear': 0.0,
      'Footwear': 0.0,
      'Dress': 0.0,
      'Accessories': 0.0,
    };

    // Enhanced keyword matching with confidence weighting
    final categoryKeywords = {
      'Dress': [
        {
          'keywords': ['dress', 'gown', 'frock', 'robe'],
          'weight': 3.0,
        },
        {
          'keywords': [
            'sundress',
            'maxi',
            'mini',
            'cocktail',
            'evening',
            'wedding',
          ],
          'weight': 2.5,
        },
        {
          'keywords': [
            'formal',
            'party',
            'casual',
            'shift',
            'wrap',
            'bodycon',
            'a-line',
          ],
          'weight': 2.0,
        },
        {
          'keywords': ['fit and flare', 'midi', 'slip dress'],
          'weight': 2.0,
        },
      ],
      'Footwear': [
        {
          'keywords': ['shoe', 'shoes', 'footwear'],
          'weight': 3.0,
        },
        {
          'keywords': ['sneaker', 'boot', 'sandal', 'slipper', 'heel'],
          'weight': 2.8,
        },
        {
          'keywords': [
            'loafer',
            'trainer',
            'flip-flop',
            'oxford',
            'ankle boot',
          ],
          'weight': 2.5,
        },
        {
          'keywords': ['running shoe', 'dress shoe', 'high heel', 'flat'],
          'weight': 2.3,
        },
      ],
      'Bottomwear': [
        {
          'keywords': ['jeans', 'pants', 'trousers', 'shorts'],
          'weight': 3.0,
        },
        {
          'keywords': ['skirt', 'leggings', 'tights', 'chinos'],
          'weight': 2.8,
        },
        {
          'keywords': ['khakis', 'slacks', 'joggers', 'sweatpants'],
          'weight': 2.5,
        },
        {
          'keywords': ['track pants', 'capris', 'culottes', 'palazzo'],
          'weight': 2.3,
        },
        {
          'keywords': ['denim'],
          'weight': 2.0,
        }, // Only if not jacket
      ],
      'Topwear': [
        {
          'keywords': ['shirt', 't-shirt', 'tshirt', 'blouse', 'top'],
          'weight': 3.0,
        },
        {
          'keywords': ['sweater', 'hoodie', 'sweatshirt', 'cardigan'],
          'weight': 2.8,
        },
        {
          'keywords': ['jacket', 'coat', 'blazer', 'vest'],
          'weight': 2.8,
        },
        {
          'keywords': ['polo', 'jersey', 'tunic', 'henley'],
          'weight': 2.5,
        },
        {
          'keywords': ['flannel', 'pullover', 'jumper', 'knitwear'],
          'weight': 2.3,
        },
        {
          'keywords': ['tank', 'camisole', 'crop top'],
          'weight': 2.0,
        },
      ],
      'Accessories': [
        {
          'keywords': ['watch', 'bracelet', 'necklace', 'ring', 'earring'],
          'weight': 3.0,
        },
        {
          'keywords': ['hat', 'cap', 'bag', 'purse', 'backpack'],
          'weight': 2.8,
        },
        {
          'keywords': ['belt', 'scarf', 'gloves', 'tie', 'bow tie'],
          'weight': 2.5,
        },
        {
          'keywords': ['sunglasses', 'eyeglasses', 'wallet'],
          'weight': 2.3,
        },
      ],
    };

    // Score each category based on detected labels
    for (String category in categoryKeywords.keys) {
      for (var keywordGroup in categoryKeywords[category]!) {
        List<String> keywords = keywordGroup['keywords'] as List<String>;
        double weight = keywordGroup['weight'] as double;

        for (String keyword in keywords) {
          for (String label in labelWeights.keys) {
            if (label.contains(keyword)) {
              double score = labelWeights[label]! * weight;
              categoryScores[category] = categoryScores[category]! + score;
            }
          }
        }
      }
    }

    // Special handling for denim (could be jacket or pants)
    if (labelWeights.keys.any((label) => label.contains('denim'))) {
      bool hasJacketIndicators = labelWeights.keys.any(
        (label) => [
          'jacket',
          'coat',
          'blazer',
          'outerwear',
          'sleeve',
        ].any((indicator) => label.contains(indicator)),
      );

      if (hasJacketIndicators) {
        categoryScores['Topwear'] = categoryScores['Topwear']! + 2.0;
      } else {
        categoryScores['Bottomwear'] = categoryScores['Bottomwear']! + 2.0;
      }
    }

    // Boost scores based on object detection
    for (var obj in objects) {
      for (var objLabel in obj.labels) {
        String labelText = objLabel.text.toLowerCase();
        if (labelText.contains('clothing') || labelText.contains('apparel')) {
          // Generic clothing detected, slight boost to top categories
          String topCategory =
              categoryScores.entries
                  .reduce((a, b) => a.value > b.value ? a : b)
                  .key;
          categoryScores[topCategory] = categoryScores[topCategory]! + 0.5;
        }
      }
    }

    // Find the category with highest score
    String bestCategory = 'Unknown';
    double maxScore = 0.0;

    categoryScores.forEach((category, score) {
      if (score > maxScore) {
        maxScore = score;
        bestCategory = category;
      }
    });

    // If no category has significant score, try fallback detection
    if (maxScore < 1.0) {
      bestCategory = _fallbackCategoryDetection(labelWeights);
      maxScore = 0.5; // Lower confidence for fallback
    }

    // Normalize confidence to 0-1 range
    double confidence = min(maxScore / 5.0, 1.0);

    return {'category': bestCategory, 'confidence': confidence};
  }

  // Fallback detection for edge cases
  String _fallbackCategoryDetection(Map<String, double> labelWeights) {
    final labels = labelWeights.keys.toList();

    // Generic clothing terms
    if (labels.any(
      (l) => [
        'clothing',
        'apparel',
        'garment',
        'textile',
        'fabric',
      ].any((term) => l.contains(term)),
    )) {
      // Try to infer from shape or other indicators
      if (labels.any(
        (l) => ['long', 'sleeve', 'collar'].any((term) => l.contains(term)),
      )) {
        return 'Topwear';
      }
      if (labels.any(
        (l) => ['leg', 'waist', 'hip'].any((term) => l.contains(term)),
      )) {
        return 'Bottomwear';
      }
      return 'Topwear'; // Default fallback
    }

    return 'Unknown';
  }

  // Enhanced subcategory detection
  String _detectEnhancedSubCategory(
    Map<String, double> labelWeights,
    String category,
    Map<String, dynamic> textContext,
  ) {
    if (category == 'Accessories') {
      final subCategories = {
        'Watch': ['watch', 'wrist watch', 'wristwatch', 'timepiece'],
        'Jewelry': [
          'bracelet',
          'bangle',
          'wristband',
          'necklace',
          'chain',
          'pendant',
          'choker',
          'ring',
          'earring',
          'stud',
        ],
        'Headwear': ['hat', 'cap', 'beanie', 'helmet'],
        'Bag': ['bag', 'purse', 'handbag', 'backpack', 'tote', 'clutch'],
        'Belt': ['belt', 'waist belt'],
        'Eyewear': ['sunglasses', 'eyeglasses', 'glasses'],
        'Scarf': ['scarf', 'neck scarf', 'muffler'],
      };

      for (String subCat in subCategories.keys) {
        if (labelWeights.keys.any(
          (label) =>
              subCategories[subCat]!.any((keyword) => label.contains(keyword)),
        )) {
          return subCat;
        }
      }
    }

    if (category == 'Footwear') {
      final footwearTypes = {
        'Sneakers': ['sneaker', 'trainer', 'running shoe', 'athletic shoe'],
        'Boots': ['boot', 'ankle boot', 'knee boot', 'combat boot'],
        'Heels': ['heel', 'high heel', 'stiletto', 'pump'],
        'Sandals': ['sandal', 'flip-flop', 'slide'],
        'Flats': ['flat', 'ballet flat', 'loafer', 'slip-on'],
        'Dress Shoes': ['dress shoe', 'oxford', 'brogue'],
      };

      for (String type in footwearTypes.keys) {
        if (labelWeights.keys.any(
          (label) =>
              footwearTypes[type]!.any((keyword) => label.contains(keyword)),
        )) {
          return type;
        }
      }
    }

    return '';
  }

  // Enhanced color detection with better color mapping
  String _detectEnhancedColor(
    Map<String, double> labelWeights,
    List<DetectedObject> objects,
  ) {
    final colorMappings = {
      'Black': ['black', 'ebony', 'charcoal', 'jet', 'onyx', 'coal'],
      'White': ['white', 'ivory', 'cream', 'off-white', 'pearl', 'snow'],
      'Red': [
        'red',
        'crimson',
        'scarlet',
        'burgundy',
        'maroon',
        'cherry',
        'rose',
      ],
      'Blue': [
        'blue',
        'navy',
        'royal blue',
        'sky blue',
        'teal',
        'turquoise',
        'cobalt',
      ],
      'Green': ['green', 'olive', 'forest', 'mint', 'lime', 'emerald', 'sage'],
      'Yellow': ['yellow', 'gold', 'amber', 'mustard', 'lemon', 'canary'],
      'Pink': ['pink', 'rose', 'blush', 'magenta', 'fuchsia', 'coral'],
      'Purple': ['purple', 'violet', 'lavender', 'plum', 'indigo', 'mauve'],
      'Orange': ['orange', 'coral', 'peach', 'tangerine', 'rust', 'copper'],
      'Brown': [
        'brown',
        'tan',
        'beige',
        'khaki',
        'camel',
        'chocolate',
        'coffee',
      ],
      'Gray': ['gray', 'grey', 'silver', 'slate', 'charcoal', 'ash'],
    };

    // Score colors based on confidence
    Map<String, double> colorScores = {};

    for (String baseColor in colorMappings.keys) {
      double score = 0.0;
      for (String colorVariant in colorMappings[baseColor]!) {
        for (String label in labelWeights.keys) {
          if (label.contains(colorVariant)) {
            score += labelWeights[label]!;
          }
        }
      }
      if (score > 0) {
        colorScores[baseColor] = score;
      }
    }

    if (colorScores.isNotEmpty) {
      String bestColor =
          colorScores.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      return bestColor;
    }

    return 'Unknown';
  }

  // Enhanced season detection
  String _detectEnhancedSeason(
    Map<String, double> labelWeights,
    String category,
  ) {
    double winterScore = 0.0;
    double summerScore = 0.0;
    double allSeasonScore = 0.0;

    final seasonKeywords = {
      'winter': [
        'sweater',
        'hoodie',
        'coat',
        'jacket',
        'puffer',
        'boot',
        'scarf',
        'gloves',
        'wool',
        'fleece',
        'parka',
        'cardigan',
        'long sleeve',
        'thermal',
        'heavy',
      ],
      'summer': [
        'tank',
        'shorts',
        'sandal',
        't-shirt',
        'tee',
        'sundress',
        'flip-flop',
        'sleeveless',
        'short sleeve',
        'crop',
        'bikini',
        'light',
        'breathable',
      ],
      'all_season': [
        'jeans',
        'pants',
        'shirt',
        'blouse',
        'dress',
        'sneaker',
        'shoe',
      ],
    };

    for (String label in labelWeights.keys) {
      double confidence = labelWeights[label]!;

      for (String winterItem in seasonKeywords['winter']!) {
        if (label.contains(winterItem)) {
          winterScore += confidence;
        }
      }

      for (String summerItem in seasonKeywords['summer']!) {
        if (label.contains(summerItem)) {
          summerScore += confidence;
        }
      }

      for (String allSeasonItem in seasonKeywords['all_season']!) {
        if (label.contains(allSeasonItem)) {
          allSeasonScore += confidence * 0.5; // Lower weight for all-season
        }
      }
    }

    if (winterScore > summerScore && winterScore > allSeasonScore) {
      return 'Winter';
    } else if (summerScore > winterScore && summerScore > allSeasonScore) {
      return 'Summer';
    }

    return 'All Season';
  }

  void _deleteItem(String itemId) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('closet_items')
            .doc(itemId)
            .delete();

        await _loadClosetItems();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Item deleted successfully')),
          );
        }
      }
    } catch (e) {
      print('Error deleting item: $e');
      _showErrorDialog('Failed to delete item. Please try again.');
    }
  }

  void _showOutfitSuggestions() {
    final topwears =
        _closetItems.where((item) => item['category'] == 'Topwear').toList();
    final bottomwears =
        _closetItems.where((item) => item['category'] == 'Bottomwear').toList();
    final footwears =
        _closetItems.where((item) => item['category'] == 'Footwear').toList();
    final dresses =
        _closetItems.where((item) => item['category'] == 'Dress').toList();
    final accessories =
        _closetItems
            .where((item) => item['category'] == 'Accessories')
            .toList();

    final random = Random();

    bool useDress = dresses.isNotEmpty && random.nextBool();

    if (useDress) {
      if (footwears.isEmpty) {
        _showErrorDialog(
          "Add at least one Footwear to get dress outfit suggestions.",
        );
        return;
      }

      final randomDress = dresses[random.nextInt(dresses.length)];
      final randomFoot = footwears[random.nextInt(footwears.length)];
      final randomAccessory =
          accessories.isNotEmpty
              ? accessories[random.nextInt(accessories.length)]
              : null;

      _showOutfitDialog([
        {'item': randomDress, 'label': 'Dress'},
        {'item': randomFoot, 'label': 'Footwear'},
        if (randomAccessory != null)
          {'item': randomAccessory, 'label': 'Accessory'},
      ]);
    } else {
      if (topwears.isEmpty || bottomwears.isEmpty || footwears.isEmpty) {
        _showErrorDialog(
          "Add at least one item from each category (Topwear, Bottomwear, Footwear) to get outfit suggestions.",
        );
        return;
      }

      final randomTop = topwears[random.nextInt(topwears.length)];
      final randomBottom = bottomwears[random.nextInt(bottomwears.length)];
      final randomFoot = footwears[random.nextInt(footwears.length)];
      final randomAccessory =
          accessories.isNotEmpty
              ? accessories[random.nextInt(accessories.length)]
              : null;

      _showOutfitDialog([
        {'item': randomTop, 'label': 'Topwear'},
        {'item': randomBottom, 'label': 'Bottomwear'},
        {'item': randomFoot, 'label': 'Footwear'},
        if (randomAccessory != null)
          {'item': randomAccessory, 'label': 'Accessory'},
      ]);
    }
  }

  void _showOutfitDialog(List<Map<String, dynamic>> outfitItems) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome, color: Color(0xFF6C63FF)),
                      SizedBox(width: 10),
                      Text(
                        'Outfit Suggestion',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ...outfitItems.map((outfitItem) {
                    final item = outfitItem['item'];
                    final label = outfitItem['label'];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 15),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              base64Decode(item['imageBase64']),
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  label,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF6C63FF),
                                  ),
                                ),
                                Text(
                                  '${item['color']} ${item['subCategory'].isNotEmpty ? item['subCategory'] : item['category']}',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _showOutfitSuggestions();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C63FF),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('New Suggestion'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _showSuccessDialog(String category) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 10),
                Text('Success!'),
              ],
            ),
            content: Text('$category item added to your closet successfully!'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  void _showErrorDialog(String message) {
    if (mounted) {
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              title: const Row(
                children: [
                  Icon(Icons.error, color: Colors.red),
                  SizedBox(width: 10),
                  Text('Error'),
                ],
              ),
              content: Text(message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredItems {
    if (_selectedFilter == 'All') {
      return _closetItems;
    }
    return _closetItems
        .where((item) => item['category'] == _selectedFilter)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Smart Closet',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            onPressed: _showOutfitSuggestions,
            tooltip: 'Get Outfit Suggestions',
          ),
        ],
      ),
      body: Column(
        children: [
          // Enhanced Filter Bar
          Container(
            height: 60,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 10,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _selectedFilter == category;
                return Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                  child: FilterChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedFilter = category;
                      });
                    },
                    selectedColor: const Color(0xFF6C63FF).withOpacity(0.2),
                    checkmarkColor: const Color(0xFF6C63FF),
                    labelStyle: TextStyle(
                      color:
                          isSelected
                              ? const Color(0xFF6C63FF)
                              : Colors.grey[600],
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    side: BorderSide(
                      color:
                          isSelected
                              ? const Color(0xFF6C63FF)
                              : Colors.grey.shade300,
                    ),
                  ),
                );
              },
            ),
          ),

          // Loading or Upload State
          if (_isLoading || _isUploading)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF6C63FF),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _isUploading
                          ? 'Processing image...'
                          : 'Loading closet...',
                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    ),
                  ],
                ),
              ),
            )
          else if (_filteredItems.isEmpty)
            // Empty State
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.checkroom, size: 80, color: Colors.grey[400]),
                    const SizedBox(height: 20),
                    Text(
                      _selectedFilter == 'All'
                          ? 'Your closet is empty'
                          : 'No $_selectedFilter items found',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Add some items to get started!',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            )
          else
            // Items Grid
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.8,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: _filteredItems.length,
                itemBuilder: (context, index) {
                  final item = _filteredItems[index];
                  return _buildClosetItemCard(item);
                },
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickImage,
        backgroundColor: const Color(0xFF6C63FF),
        child: const Icon(Icons.add_a_photo, color: Colors.white),
      ),
    );
  }

  Widget _buildClosetItemCard(Map<String, dynamic> item) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          children: [
            // Image
            Positioned.fill(
              child: Image.memory(
                base64Decode(item['imageBase64']),
                fit: BoxFit.cover,
              ),
            ),

            // Gradient Overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                  ),
                ),
              ),
            ),

            // Content
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item['category'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Delete Button with Cross Icon
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => _deleteItem(item['id']),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
