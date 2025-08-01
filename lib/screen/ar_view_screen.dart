import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:math';

class ARViewScreen extends StatefulWidget {
  final String itemName;
  final String itemImage;
  final double itemPrice;
  final bool isRental;

  const ARViewScreen({
    super.key,
    required this.itemName,
    required this.itemImage,
    required this.itemPrice,
    required this.isRental,
  });

  @override
  State<ARViewScreen> createState() => _ARViewScreenState();
}

class _ARViewScreenState extends State<ARViewScreen>
    with TickerProviderStateMixin {
  CameraController? _controller;
  bool _isCameraInitialized = false;
  bool _isItemPlaced = false;
  Offset _itemPosition = Offset(0.5, 0.6); // Center position
  double _itemScale = 1.0;

  // Animation controllers for 3D effect
  late AnimationController _rotationController;
  late AnimationController _floatingController;
  late Animation<double> _rotationAnimation;
  late Animation<double> _floatingAnimation;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    // Rotation animation for 3D effect
    _rotationController = AnimationController(
      duration: Duration(seconds: 8),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(begin: 0, end: 2 * pi).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.linear),
    );

    // Floating animation
    _floatingController = AnimationController(
      duration: Duration(seconds: 3),
      vsync: this,
    );
    _floatingAnimation = Tween<double>(begin: -10, end: 10).animate(
      CurvedAnimation(parent: _floatingController, curve: Curves.easeInOut),
    );

    // Start animations
    _rotationController.repeat();
    _floatingController.repeat(reverse: true);
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        return;
      }

      _controller = CameraController(
        cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
      // Show error dialog
      if (mounted) {
        _showErrorDialog(
          'Camera Error',
          'Unable to access camera. Please check permissions.',
        );
      }
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop(); // Go back to product detail
                },
                child: Text('OK'),
              ),
            ],
          ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    _rotationController.dispose();
    _floatingController.dispose();
    super.dispose();
  }

  void _placeItem() {
    setState(() {
      _isItemPlaced = true;
    });
  }

  void _resetPlacement() {
    setState(() {
      _isItemPlaced = false;
      _itemPosition = Offset(0.5, 0.6);
      _itemScale = 1.0;
    });
  }

  void _onScaleUpdate(ScaleUpdateDetails details, Size screenSize) {
    setState(() {
      // Handle scaling
      _itemScale = (_itemScale * details.scale).clamp(0.5, 3.0);

      // Handle panning (moving) - using focalPointDelta for movement
      if (details.focalPointDelta != Offset.zero) {
        _itemPosition = Offset(
          (_itemPosition.dx * screenSize.width + details.focalPointDelta.dx) /
              screenSize.width,
          (_itemPosition.dy * screenSize.height + details.focalPointDelta.dy) /
              screenSize.height,
        );

        // Keep item within bounds
        _itemPosition = Offset(
          _itemPosition.dx.clamp(0.1, 0.9),
          _itemPosition.dy.clamp(0.2, 0.8),
        );
      }
    });
  }

  Widget _build3DModel() {
    return AnimatedBuilder(
      animation: Listenable.merge([_rotationAnimation, _floatingAnimation]),
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _floatingAnimation.value),
          child: Transform.scale(
            scale: _itemScale,
            child: Transform(
              alignment: Alignment.center,
              transform:
                  Matrix4.identity()
                    ..setEntry(3, 2, 0.001) // Perspective
                    ..rotateY(_rotationAnimation.value)
                    ..rotateX(0.2), // Slight tilt for 3D effect
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      // Main product image
                      Image.network(
                        widget.itemImage,
                        width: 150,
                        height: 150,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 150,
                            height: 150,
                            color: Colors.grey.shade300,
                            child: Icon(
                              Icons.image_not_supported,
                              size: 50,
                              color: Colors.grey,
                            ),
                          );
                        },
                      ),
                      // Glossy overlay for 3D effect
                      Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withOpacity(0.3),
                              Colors.transparent,
                              Colors.black.withOpacity(0.1),
                            ],
                            stops: [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    if (!_isCameraInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: Text('AR View'),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.deepPurple),
              SizedBox(height: 20),
              Text(
                'Initializing AR Camera...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('AR View - ${widget.itemName}'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          if (_isItemPlaced)
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: _resetPlacement,
              tooltip: 'Reset Position',
            ),
        ],
      ),
      body: Stack(
        children: [
          // Camera Preview
          Positioned.fill(child: CameraPreview(_controller!)),

          // AR Grid Overlay (to help with placement)
          if (!_isItemPlaced)
            Positioned.fill(child: CustomPaint(painter: ARGridPainter())),

          // 3D Item Overlay
          if (_isItemPlaced)
            Positioned(
              left: _itemPosition.dx * screenSize.width - 75,
              top: _itemPosition.dy * screenSize.height - 75,
              child: GestureDetector(
                onScaleUpdate: (details) => _onScaleUpdate(details, screenSize),
                child: _build3DModel(),
              ),
            ),

          // Instructions Overlay
          if (!_isItemPlaced)
            Positioned(
              bottom: 100,
              left: 20,
              right: 20,
              child: Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.deepPurple, width: 2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.camera_alt, color: Colors.white, size: 40),
                    SizedBox(height: 12),
                    Text(
                      'Point your camera at a flat surface',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Move around to find the perfect spot to place your ${widget.itemName}',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

          // Place Item Button
          if (!_isItemPlaced)
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: Center(
                child: ElevatedButton(
                  onPressed: _placeItem,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.view_in_ar, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'Place Item',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Item Info Card
          if (_isItemPlaced)
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.itemName,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '₹${widget.itemPrice.toInt()}',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.touch_app,
                          color: Colors.deepPurple,
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Drag to move • Pinch to resize',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Control Buttons (when item is placed)
          if (_isItemPlaced)
            Positioned(
              bottom: 30,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: _resetPlacement,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    icon: Icon(Icons.refresh, size: 20),
                    label: Text('Reset'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      // Add to cart or rental functionality
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            widget.isRental
                                ? '${widget.itemName} added to rental cart!'
                                : '${widget.itemName} added to cart!',
                          ),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    icon: Icon(
                      widget.isRental
                          ? Icons.event_available
                          : Icons.shopping_cart,
                      size: 20,
                    ),
                    label: Text(widget.isRental ? 'Rent Now' : 'Add to Cart'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// Custom painter for AR grid overlay
class ARGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.white.withOpacity(0.3)
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke;

    const gridSize = 50.0;

    // Draw vertical lines
    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Draw horizontal lines
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Draw center crosshair
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final crosshairSize = 30.0;

    final crosshairPaint =
        Paint()
          ..color = Colors.deepPurple.withOpacity(0.8)
          ..strokeWidth = 3.0
          ..style = PaintingStyle.stroke;

    // Horizontal line
    canvas.drawLine(
      Offset(centerX - crosshairSize, centerY),
      Offset(centerX + crosshairSize, centerY),
      crosshairPaint,
    );

    // Vertical line
    canvas.drawLine(
      Offset(centerX, centerY - crosshairSize),
      Offset(centerX, centerY + crosshairSize),
      crosshairPaint,
    );

    // Center circle
    canvas.drawCircle(
      Offset(centerX, centerY),
      5.0,
      Paint()
        ..color = Colors.deepPurple
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
