import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'product_detail_screen.dart';
import 'cart_screen.dart';
import 'my_orders_page.dart'; // Add this import

class ARShoppingScreen extends StatefulWidget {
  const ARShoppingScreen({super.key});

  @override
  _ARShoppingScreenState createState() => _ARShoppingScreenState();
}

class _ARShoppingScreenState extends State<ARShoppingScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List<Map<String, dynamic>> categories = [
    {'name': 'All', 'icon': Icons.grid_view},
    {'name': 'Favourites', 'icon': Icons.favorite},
    {'name': 'Tops', 'icon': Icons.checkroom},
    {'name': 'Bottoms', 'icon': Icons.accessibility},
    {'name': 'Dresses', 'icon': Icons.person_outline},
    {'name': 'Footwear', 'icon': Icons.directions_walk},
  ];
  String selectedCategory = 'All';
  String searchQuery = '';
  bool isGridView = true;
  final TextEditingController _searchController = TextEditingController();
  Set<String> favouriteItems = {};

  @override
  void initState() {
    super.initState();
    _loadFavourites();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFavourites() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('favourites')
                .get();

        setState(() {
          favouriteItems = doc.docs.map((doc) => doc.id).toSet();
        });
      } catch (e) {
        print('Error loading favourites: $e');
      }
    }
  }

  Future<void> _toggleFavourite(String productId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to add favourites')),
      );
      return;
    }

    try {
      final favouriteRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('favourites')
          .doc(productId);

      if (favouriteItems.contains(productId)) {
        await favouriteRef.delete();
        setState(() {
          favouriteItems.remove(productId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Removed from favourites')),
        );
      } else {
        await favouriteRef.set({'addedAt': FieldValue.serverTimestamp()});
        setState(() {
          favouriteItems.add(productId);
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Added to favourites')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.grey[50],
      // drawer: _buildNavigationDrawer(),
      body: CustomScrollView(
        slivers: [
          buildSliverAppBar(),
          SliverToBoxAdapter(child: buildSearchSection()),
          SliverToBoxAdapter(child: buildCategorySection()),
          SliverToBoxAdapter(child: buildViewToggle()),
          buildProductGrid(),
        ],
      ),
    );
  }

  // Remove the drawer property from Scaffold
  // Duplicate build method removed.

  // Update the SliverAppBar leading button
  Widget buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: Colors.deepPurple,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.menu, color: Colors.white),
        onPressed: () {
          // Show popup menu with My Orders option
          showMenu(
            context: context,
            position: const RelativeRect.fromLTRB(
              0,
              80,
              200,
              0,
            ), // Position near top-left
            items: [
              PopupMenuItem<String>(
                value: 'orders',
                child: Row(
                  children: const [
                    Icon(Icons.receipt_long, color: Colors.deepPurple),
                    SizedBox(width: 12),
                    Text('My Orders'),
                  ],
                ),
              ),
            ],
          ).then((value) {
            if (value == 'orders') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MyOrdersPage()),
              );
            }
          });
        },
      ),
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          'Shopping',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.deepPurple, Colors.deepPurple.shade300],
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CartScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget buildSearchSection() {
    return Container(
      padding: const EdgeInsets.all(20.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => searchQuery = value),
          decoration: InputDecoration(
            hintText: 'Search for amazing products...',
            hintStyle: TextStyle(color: Colors.grey[400]),
            prefixIcon: Icon(Icons.search, color: Colors.deepPurple[300]),
            suffixIcon:
                searchQuery.isNotEmpty
                    ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => searchQuery = '');
                      },
                    )
                    : Icon(Icons.tune, color: Colors.grey[400]),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget buildCategorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.0),
          child: Text(
            'Categories',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        Container(
          height: 120,
          margin: const EdgeInsets.symmetric(vertical: 10),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              final isSelected = selectedCategory == category['name'];
              return GestureDetector(
                onTap:
                    () => setState(() => selectedCategory = category['name']),
                child: Container(
                  width: 80,
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.deepPurple : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  isSelected
                                      ? Colors.deepPurple.withOpacity(0.3)
                                      : Colors.grey.withOpacity(0.1),
                              spreadRadius: isSelected ? 2 : 1,
                              blurRadius: isSelected ? 8 : 5,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(
                          category['icon'],
                          color: isSelected ? Colors.white : Colors.deepPurple,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Flexible(
                        child: Text(
                          category['name'],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w500,
                            color:
                                isSelected
                                    ? Colors.deepPurple
                                    : Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget buildViewToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              selectedCategory == 'Favourites'
                  ? 'Your Favourites'
                  : 'Featured Products',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 5,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.grid_view,
                    color: isGridView ? Colors.deepPurple : Colors.grey,
                  ),
                  onPressed: () => setState(() => isGridView = true),
                ),
                IconButton(
                  icon: Icon(
                    Icons.view_list,
                    color: !isGridView ? Colors.deepPurple : Colors.grey,
                  ),
                  onPressed: () => setState(() => isGridView = false),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildProductGrid() {
    if (selectedCategory == 'Favourites') {
      return buildFavouritesGrid();
    }

    return StreamBuilder(
      stream: FirebaseFirestore.instance.collection('products').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(50.0),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                ),
              ),
            ),
          );
        }

        final products =
            snapshot.data!.docs.where((doc) {
              final product = doc.data();
              final matchesCategory =
                  selectedCategory == 'All' ||
                  product['category'] == selectedCategory;
              final matchesSearch = (product['name'] as String)
                  .toLowerCase()
                  .contains(searchQuery.toLowerCase());
              return matchesCategory && matchesSearch;
            }).toList();

        if (products.isEmpty) {
          return SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(50.0),
                child: Column(
                  children: [
                    Icon(Icons.search_off, size: 80, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No products found',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isGridView ? 2 : 1,
              childAspectRatio: isGridView ? 0.65 : 2,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) =>
                  buildProductCard(products[index].data(), products[index].id),
              childCount: products.length,
            ),
          ),
        );
      },
    );
  }

  Widget buildFavouritesGrid() {
    if (favouriteItems.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(50.0),
            child: Column(
              children: [
                Icon(Icons.favorite_border, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No favourites yet',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add items to your favourites to see them here',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return StreamBuilder(
      stream:
          FirebaseFirestore.instance
              .collection('products')
              .where(FieldPath.documentId, whereIn: favouriteItems.toList())
              .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(50.0),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                ),
              ),
            ),
          );
        }

        final products =
            snapshot.data!.docs.where((doc) {
              final product = doc.data();
              return (product['name'] as String).toLowerCase().contains(
                searchQuery.toLowerCase(),
              );
            }).toList();

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isGridView ? 2 : 1,
              childAspectRatio: isGridView ? 0.65 : 2,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) =>
                  buildProductCard(products[index].data(), products[index].id),
              childCount: products.length,
            ),
          ),
        );
      },
    );
  }

  Widget buildProductCard(Map<String, dynamic> product, String productId) {
    final isFavourite = favouriteItems.contains(productId);

    return GestureDetector(
      onTap:
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProductDetailScreen(product: product),
            ),
          ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section with fixed height
            SizedBox(
              height: isGridView ? 120 : 80,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    child: CachedNetworkImage(
                      imageUrl: product['imageUrl'] ?? '',
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.contain,
                      placeholder:
                          (_, __) => Container(
                            color: Colors.grey[100],
                            child: const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.deepPurple,
                                ),
                              ),
                            ),
                          ),
                      errorWidget:
                          (_, __, ___) => Container(
                            color: Colors.grey[100],
                            child: const Icon(
                              Icons.image_not_supported,
                              color: Colors.grey,
                              size: 40,
                            ),
                          ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => _toggleFavourite(productId),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isFavourite ? Icons.favorite : Icons.favorite_border,
                          color: isFavourite ? Colors.red : Colors.grey,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Content section - Fixed to prevent overflow
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Product name with constrained height
                    Flexible(
                      child: Text(
                        product['name'] ?? 'Unknown Product',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Price
                    Text(
                      "₹${product['price']?.toString() ?? '0'}",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
