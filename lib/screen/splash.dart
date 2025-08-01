import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Import the LoginScreen
import 'login.dart'; // Update the path to the correct location of LoginPage

void main() {
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FashioNexus',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.purple, fontFamily: 'Montserrat'),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.65, curve: Curves.easeInOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOutBack),
      ),
    );

    _animationController.forward();

    // Navigate to login screen after delay
    Timer(const Duration(milliseconds: 3500), () {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (context) => LoginPage()));
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF6A1B9A), // Deep Purple
              Color(0xFF9C27B0), // Purple
              Color(0xFFAB47BC), // Light Purple
            ],
          ),
        ),
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Stack(
              children: [
                // Background animated patterns
                Positioned.fill(
                  child: Opacity(
                    opacity: _fadeAnimation.value * 0.15,
                    child: CustomPaint(
                      painter: GridPainter(
                        animationValue: _animationController.value,
                      ),
                    ),
                  ),
                ),

                // Main content
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo
                      Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Opacity(
                          opacity: _fadeAnimation.value,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                Icons.style,
                                size: 60,
                                color: Color(0xFF6A1B9A),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),

                      // App name
                      Opacity(
                        opacity: _fadeAnimation.value,
                        child: const Text(
                          'FashioNexus',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Tagline
                      Opacity(
                        opacity: _fadeAnimation.value,
                        child: const Text(
                          'AI-Powered Smart Fashion Ecosystem',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),

                      const SizedBox(height: 50),

                      // Loading indicator
                      Opacity(
                        opacity: _fadeAnimation.value,
                        child: Column(
                          children: [
                            SizedBox(
                              width: 40,
                              height: 40,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            ),
                            const SizedBox(height: 20),
                            FadeTransition(
                              opacity: Tween<double>(
                                begin: 0.0,
                                end: 1.0,
                              ).animate(
                                CurvedAnimation(
                                  parent: _animationController,
                                  curve: const Interval(
                                    0.6,
                                    1.0,
                                    curve: Curves.easeIn,
                                  ),
                                ),
                              ),
                              child: const Text(
                                'Preparing your fashion experience...',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Tech icons floating in background
                Positioned(
                  right: 40,
                  top: 100,
                  child: _buildTechIcon(
                    Icons.auto_awesome,
                    _animationController.value,
                  ),
                ),
                Positioned(
                  left: 30,
                  top: 200,
                  child: _buildTechIcon(
                    Icons.camera_alt,
                    _animationController.value,
                  ),
                ),
                Positioned(
                  right: 60,
                  bottom: 180,
                  child: _buildTechIcon(
                    Icons.shopping_bag,
                    _animationController.value,
                  ),
                ),
                Positioned(
                  left: 50,
                  bottom: 120,
                  child: _buildTechIcon(
                    Icons.analytics,
                    _animationController.value,
                  ),
                ),
                Positioned(
                  right: 100,
                  top: 300,
                  child: _buildTechIcon(
                    Icons.recycling,
                    _animationController.value,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTechIcon(IconData icon, double animationValue) {
    final double opacity =
        Tween<double>(begin: 0.0, end: 0.5)
            .animate(
              CurvedAnimation(
                parent: _animationController,
                curve: const Interval(0.3, 0.8, curve: Curves.easeOut),
              ),
            )
            .value;

    final double scale =
        Tween<double>(begin: 0.0, end: 1.0)
            .animate(
              CurvedAnimation(
                parent: _animationController,
                curve: const Interval(0.3, 0.8, curve: Curves.elasticOut),
              ),
            )
            .value;

    return Transform.scale(
      scale: scale,
      child: Opacity(
        opacity: opacity,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

// Custom painter to create a grid pattern in the background
class GridPainter extends CustomPainter {
  final double animationValue;

  GridPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.white
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke;

    final gridSize = 40.0;
    final offset = animationValue * 20.0;

    // Draw horizontal lines
    for (double y = -offset; y <= size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Draw vertical lines
    for (double x = -offset; x <= size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
