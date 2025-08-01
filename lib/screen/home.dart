import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Feature screens
import 'smart_closet.dart';
import 'ai_stylist.dart';
import 'rent_&_sell.dart';
import 'ar_shopping.dart'; 
import 'profile_page.dart'; 

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool isLoadingShoppingData = true;
  String userName = 'User';

  // Smart Closet data - removed totalClothes
  int totalCategories = 0;
  bool isLoadingClosetData = true;

  // Bottom navigation
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    fetchUserName();
    fetchSmartClosetData();
    // Removed fetchARItems() call
    setState(() {
      isLoadingShoppingData =
          false; // Set shopping data as loaded since we removed the fetch
    });
  }

  // Fetch user's name from Firebase Auth or Firestore
  Future<void> fetchUserName() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Try to get display name first
        if (user.displayName != null && user.displayName!.isNotEmpty) {
          setState(() {
            userName = user.displayName!.split(' ')[0]; // Get first name only
          });
        } else {
          // If no display name, try to fetch from Firestore
          DocumentSnapshot userDoc =
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .get();

          if (userDoc.exists) {
            String name =
                userDoc.get('name') ?? userDoc.get('displayName') ?? 'User';
            setState(() {
              userName = name.split(' ')[0]; // Get first name only
            });
          }
        }
      }
    } catch (e) {
      // If anything fails, keep default 'User'
      setState(() {
        userName = 'User';
      });
    }
  }

  // Modified fetchSmartClosetData method - only count categories, removed clothes count
  Future<void> fetchSmartClosetData() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Get all clothes for the current user
        QuerySnapshot clothesSnapshot =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('clothes')
                .get();

        // Define your app's 5 categories (excluding 'All')
        final List<String> validCategories = [
          'Topwear',
          'Bottomwear',
          'Footwear',
          'Dress',
          'Accessories',
        ];

        // Get unique categories that exist in user's closet
        Set<String> uniqueCategories = {};
        for (var doc in clothesSnapshot.docs) {
          Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?;

          if (data != null) {
            String category = data['category']?.toString().trim() ?? '';

            // Only count valid categories that are not empty
            if (category.isNotEmpty && validCategories.contains(category)) {
              uniqueCategories.add(category);
            }
          }
        }

        setState(() {
          totalCategories = uniqueCategories.length;
          isLoadingClosetData = false;
        });

        // Debug print to check what's being fetched
        print(
          'Smart Closet Data - Categories found: ${uniqueCategories.toList()}',
        );
        print(
          'Smart Closet Data - Total Categories: ${uniqueCategories.length}',
        );
      } else {
        // User not logged in
        setState(() {
          totalCategories = 0;
          isLoadingClosetData = false;
        });
      }
    } catch (e) {
      print('Error fetching Smart Closet data: $e');
      setState(() {
        // Set default values if fetch fails
        totalCategories = 0;
        isLoadingClosetData = false;
      });
    }
  }

  // Alternative method if you want to refresh data when returning from Smart Closet
  Future<void> refreshSmartClosetData() async {
    setState(() {
      isLoadingClosetData = true;
    });
    await fetchSmartClosetData();
  }

  // Modified Smart Closet preview widget - fixed pixel overflow and constant categories
  Widget _buildSmartClosetPreview() {
    return SizedBox(
      height: 100,
      child:
          isLoadingClosetData
              ? Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
              : Row(
                children: [
                  Expanded(
                    flex: 3, // Give more space to the text content
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8, // Reduced padding
                            vertical: 4, // Reduced padding
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(
                              10,
                            ), // Reduced radius
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.category,
                                size: 16, // Reduced icon size
                                color: Colors.white,
                              ),
                              SizedBox(width: 4), // Reduced spacing
                              Flexible(
                                // Added Flexible to prevent overflow
                                child: Text(
                                  totalCategories == 0
                                      ? '5 Categories'
                                      : '$totalCategories/5 Categories',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12, // Reduced font size
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow:
                                      TextOverflow.ellipsis, // Handle overflow
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 6), // Reduced spacing
                        Flexible(
                          // Added Flexible to prevent overflow
                          child: Text(
                            'Organize your wardrobe\nacross 5 main categories',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 10, // Reduced font size
                              height: 1.2, // Reduced line height
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2, // Limit to 2 lines
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8), // Add spacing between text and icon
                  Container(
                    width: 70, // Slightly reduced width
                    height: 70, // Slightly reduced height
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12), // Reduced radius
                    ),
                    child: Icon(
                      totalCategories > 0
                          ? Icons.checkroom
                          : Icons.checkroom_outlined,
                      size: 35, // Reduced icon size
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
    );
  }

  // Removed fetchARItems method and camera permission request method

  // Handle bottom navigation
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        // Home - already here, do nothing
        break;
      case 1:
        // Social - navigate to social page (you can add this later)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Social feature coming soon!')),
        );
        break;
      case 2:
        // Profile - navigate to profile page
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) =>
                    ProfilePage(), // Replace with your actual profile page
          ),
        ).then((_) {
          // Reset selected index when returning from profile
          setState(() {
            _selectedIndex = 0;
          });
        });
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          // Custom App Bar
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: const Color(0xFF6C63FF),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF6C63FF), Color(0xFF9C27B0)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'Welcome, $userName! 👋',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 20,
                          ),
                        ),
                        SizedBox(height: 5),
                        Row(
                          children: [
                            Icon(Icons.style, color: Colors.white, size: 30),
                            SizedBox(width: 10),
                            Text(
                              'FashioNexus',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 28,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Welcome to your Smart Fashion Ecosystem \nDiscover. Style. Share.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                            fontWeight: FontWeight.w400,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Feature Cards
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 10),

                // Smart Closet Card
                FeatureFlashCard(
                  title: 'Smart Closet',
                  subtitle: 'Organize your wardrobe digitally',
                  icon: Icons.checkroom,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF5563C1), Color(0xFF6B4080)],
                  ),
                  preview: _buildSmartClosetPreview(),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SmartClosetScreen(),
                      ),
                    ).then((_) {
                      // Refresh smart closet data when returning
                      fetchSmartClosetData();
                    });
                  },
                ),

                const SizedBox(height: 20),

                // AI Stylist Card
                FeatureFlashCard(
                  title: 'AI Stylist',
                  subtitle: 'Get personalized fashion advice',
                  icon: Icons.face_retouching_natural,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD17AB5), Color(0xFFD14952)],
                  ),
                  preview: _buildAIStylistPreview(),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ChatbotPage()),
                    );
                  },
                ),

                const SizedBox(height: 20),

                // Shopping Card (formerly AR Shopping)
                FeatureFlashCard(
                  title: 'Shopping',
                  subtitle: 'Discover trending fashion items',
                  icon: Icons.shopping_bag,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF78C2B8), Color(0xFFE8A8BE)],
                  ),
                  preview: _buildShoppingPreview(),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) =>
                                ARShoppingScreen(), // You might want to rename this to ShoppingScreen
                      ),
                    );
                  },
                ),

                const SizedBox(height: 20),

                // Rent & Sell Card
                FeatureFlashCard(
                  title: 'Rent & Sell',
                  subtitle: 'Monetize your fashion collection',
                  icon: Icons.swap_horiz,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE6B88A), Color(0xFFDB8B7A)],
                  ),
                  preview: _buildRentSellPreview(),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RentAndSellPage(),
                      ),
                    );
                  },
                ),

                const SizedBox(
                  height: 100,
                ), // Bottom padding for navigation bar
              ]),
            ),
          ),
        ],
      ),

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          selectedItemColor: const Color(0xFF6C63FF),
          unselectedItemColor: Colors.grey,
          backgroundColor: Colors.white,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Social'),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_circle),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIStylistPreview() {
    return SizedBox(
      height: 100,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '💬 "What should I wear today?"',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'AI Assistant Ready',
                    style: TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(Icons.smart_toy, size: 40, color: Colors.white),
          ),
        ],
      ),
    );
  }

  // New Shopping preview widget (formerly AR Shopping)
  Widget _buildShoppingPreview() {
    return SizedBox(
      height: 100,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.trending_up, size: 14, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'Trending Now',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Discover the latest fashion\ntrends and collections',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              Icons.shopping_bag_outlined,
              size: 40,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRentSellPreview() {
    return SizedBox(
      height: 100,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Icon(Icons.attach_money, size: 16, color: Colors.white70),
                    Text(
                      'Earn from your closet',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
                SizedBox(height: 5),
                Text(
                  '📦 List • 🤝 Rent • 💰 Sell',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(Icons.currency_exchange, size: 40, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class FeatureFlashCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Gradient gradient;
  final Widget preview;
  final VoidCallback onTap;

  const FeatureFlashCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.preview,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: Card(
        elevation: 8,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(25),
          child: Container(
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(25),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(icon, size: 24, color: Colors.white),
                    ),
                    SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white70,
                      size: 16,
                    ),
                  ],
                ),
                SizedBox(height: 15),
                Expanded(child: preview),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
