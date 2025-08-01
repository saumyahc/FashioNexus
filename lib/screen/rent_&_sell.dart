import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'rent_item_screen.dart';
import 'sell_item_screen.dart';
import 'item_detail_page.dart';

class RentAndSellPage extends StatefulWidget {
  const RentAndSellPage({super.key});

  @override
  State<RentAndSellPage> createState() => _RentAndSellPageState();
}

class _RentAndSellPageState extends State<RentAndSellPage>
    with TickerProviderStateMixin {
  final List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _debugMessage = '';
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fabAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fabAnimationController, curve: Curves.easeInOut),
    );
    _loadItems();
    _fabAnimationController.forward();
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _loadItems() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
        _debugMessage = 'User not authenticated';
      });
      return;
    }

    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('items').get();

      print('Total documents in items collection: ${snapshot.docs.length}');

      if (snapshot.docs.isEmpty) {
        setState(() {
          _isLoading = false;
          _debugMessage = 'No documents found in items collection';
        });
        return;
      }

      for (int i = 0; i < snapshot.docs.length && i < 3; i++) {
        print('Document $i: ${snapshot.docs[i].data()}');
      }

      FirebaseFirestore.instance
          .collection('items')
          .snapshots()
          .listen(
            (snapshot) {
              print('Snapshot received: ${snapshot.docs.length} documents');
              setState(() {
                _items.clear();
                for (var doc in snapshot.docs) {
                  var data = doc.data();
                  data['docId'] = doc.id;
                  _items.add(data);
                  print(
                    'Added item: ${data['itemName']} - Type: ${data['type']}',
                  );
                }
                _isLoading = false;
                _debugMessage = 'Loaded ${_items.length} items';
              });
            },
            onError: (error) {
              print('Firestore error: $error');
              setState(() {
                _isLoading = false;
                _debugMessage = 'Error: $error';
              });
              _showSnackBar('Error loading items: $error', isError: true);
            },
          );
    } catch (e) {
      print('Exception in _loadItems: $e');
      setState(() {
        _isLoading = false;
        _debugMessage = 'Exception: $e';
      });
    }
  }

  void _showAddItemDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'What would you like to do?',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Choose whether you want to rent out or sell your item',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RentItemScreen(),
                          ),
                        ).then((_) => _loadItems());
                      },
                      icon: const Icon(Icons.schedule, color: Colors.white),
                      label: const Text(
                        'Rent',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SellItemScreen(),
                          ),
                        ).then((_) => _loadItems());
                      },
                      icon: const Icon(Icons.sell, color: Colors.white),
                      label: const Text(
                        'Sell',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _openItemDetail(Map<String, dynamic> item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ItemDetailPage(
              item: item,
              loggedInUserEmail: FirebaseAuth.instance.currentUser?.email ?? '',
            ),
      ),
    );
  }

  Future<void> _deleteItem(Map<String, dynamic> item) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (item['ownerId'] != user.uid) {
      _showSnackBar('You can only delete your own items', isError: true);
      return;
    }

    final bool? shouldDelete = await _showDeleteConfirmation(
      item['itemName'] ?? 'this item',
    );
    if (shouldDelete != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('items')
          .doc(item['docId'])
          .delete();

      _showSnackBar('Item deleted successfully', isError: false);
    } catch (e) {
      _showSnackBar('Failed to delete item: $e', isError: true);
    }
  }

  Future<bool?> _showDeleteConfirmation(String itemName) {
    return showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Delete Item',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            content: Text('Are you sure you want to delete "$itemName"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
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

  // Enhanced search function for location-based filtering
  List<Map<String, dynamic>> get _filteredItems {
    if (_searchQuery.isEmpty) return _items;

    final query = _searchQuery.toLowerCase().trim();

    return _items.where((item) {
      final itemName = (item['itemName'] ?? '').toLowerCase();
      final sellerName = (item['sellerName'] ?? '').toLowerCase();
      final city = (item['city'] ?? '').toLowerCase();
      final state = (item['state'] ?? '').toLowerCase();
      final address = (item['address'] ?? '').toLowerCase();
      final description = (item['itemDescription'] ?? '').toLowerCase();

      // Enhanced location search - checks multiple location fields
      return itemName.contains(query) ||
          sellerName.contains(query) ||
          city.contains(query) ||
          state.contains(query) ||
          address.contains(query) ||
          description.contains(query) ||
          // Also check for partial matches and common variations
          _isLocationMatch(city, query) ||
          _isLocationMatch(state, query) ||
          _isLocationMatch(address, query);
    }).toList();
  }

  // Helper function for better location matching
  bool _isLocationMatch(String location, String query) {
    if (location.isEmpty || query.isEmpty) return false;

    // Check for exact match
    if (location == query) return true;

    // Check for partial match
    if (location.contains(query) || query.contains(location)) return true;

    // Check for common city variations (you can expand this)
    final locationVariations = {
      'vadodara': ['baroda', 'vadodra'],
      'baroda': ['vadodara', 'vadodra'],
      'mumbai': ['bombay'],
      'bombay': ['mumbai'],
      'bangalore': ['bengaluru'],
      'bengaluru': ['bangalore'],
      'delhi': ['new delhi'],
      'new delhi': ['delhi'],
      // Add more city variations as needed
    };

    if (locationVariations.containsKey(location)) {
      return locationVariations[location]!.contains(query);
    }

    if (locationVariations.containsKey(query)) {
      return locationVariations[query]!.contains(location);
    }

    return false;
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText:
              'Search by item name, seller, or location (e.g., Vadodara)...',
          hintStyle: TextStyle(color: Colors.grey[600]),
          prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
          suffixIcon:
              _searchQuery.isNotEmpty
                  ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                  : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item, int index) {
    final String? imageUrl = item['imageUrl'];
    final user = FirebaseAuth.instance.currentUser;
    final bool isOwner = user?.uid == item['ownerId'];
    final bool isForRent = item['type'] == 'rent';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: 6,
        shadowColor: Colors.deepPurple.withOpacity(0.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: () => _openItemDetail(item),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [Colors.white, Colors.grey.shade50],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // First Row: Image and Basic Info
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image Section
                      Hero(
                        tag: 'item-${item['itemId']}-$index',
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child:
                                imageUrl != null && imageUrl.isNotEmpty
                                    ? Image.network(
                                      imageUrl,
                                      fit: BoxFit.cover,
                                      loadingBuilder: (
                                        context,
                                        child,
                                        loadingProgress,
                                      ) {
                                        if (loadingProgress == null) {
                                          return child;
                                        }
                                        return Container(
                                          color: Colors.grey[200],
                                          child: const Center(
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        );
                                      },
                                      errorBuilder: (
                                        context,
                                        error,
                                        stackTrace,
                                      ) {
                                        return Container(
                                          color: Colors.grey[200],
                                          child: const Icon(
                                            Icons.broken_image,
                                            size: 40,
                                            color: Colors.grey,
                                          ),
                                        );
                                      },
                                    )
                                    : Container(
                                      color: Colors.grey[200],
                                      child: const Icon(
                                        Icons.image_not_supported,
                                        size: 40,
                                        color: Colors.grey,
                                      ),
                                    ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 16),

                      // Content Section - Using Expanded to prevent overflow
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title and Delete Button Row
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item['itemName'] ?? 'No name',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isOwner)
                                  GestureDetector(
                                    onTap: () => _deleteItem(item),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        size: 18,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            // Seller Info
                            Row(
                              children: [
                                Icon(
                                  Icons.person_outline,
                                  size: 16,
                                  color: Colors.deepPurple.shade400,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    item['sellerName'] ?? 'Unknown Seller',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.deepPurple.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 4),

                            // Location Info
                            if (item['city'] != null && item['city'].isNotEmpty)
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on_outlined,
                                    size: 16,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      item['city'],
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Description (if available)
                  if (item['itemDescription'] != null &&
                      item['itemDescription'].isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      item['itemDescription'],
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Bottom Row - Price and Tags
                  Row(
                    children: [
                      // Price
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.green.shade400,
                              Colors.green.shade600,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '₹${item['itemPrice'] ?? '0'}${isForRent ? '/day' : ''}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Type Tag
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isForRent
                                  ? Colors.orange.withOpacity(0.1)
                                  : Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isForRent ? 'For Rent' : 'For Sale',
                          style: TextStyle(
                            fontSize: 10,
                            color: isForRent ? Colors.orange : Colors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                      const Spacer(),

                      // Owner Tag
                      if (isOwner)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Your Item',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.purple,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _searchQuery.isNotEmpty
                    ? Icons.search_off
                    : Icons.inventory_2_outlined,
                size: 64,
                color: Colors.deepPurple.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No items found for "$_searchQuery"'
                  : 'No items available',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _debugMessage.isNotEmpty
                  ? _debugMessage
                  : _searchQuery.isNotEmpty
                  ? 'Try searching for different keywords or locations'
                  : 'Tap the + button to add your first item',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            if (_debugMessage.isNotEmpty) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _debugMessage = '';
                  });
                  _loadItems();
                },
                child: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _filteredItems;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple.shade50, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom App Bar
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Rent & Sell',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    if (_debugMessage.isNotEmpty)
                      IconButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder:
                                (context) => AlertDialog(
                                  title: const Text('Debug Info'),
                                  content: SingleChildScrollView(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('Items loaded: ${_items.length}'),
                                        Text(
                                          'Filtered items: ${filteredItems.length}',
                                        ),
                                        Text('Search query: "$_searchQuery"'),
                                        Text('Debug: $_debugMessage'),
                                        const SizedBox(height: 8),
                                        if (_items.isNotEmpty) ...[
                                          const Text('Sample item:'),
                                          Text(_items.first.toString()),
                                        ],
                                      ],
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('OK'),
                                    ),
                                  ],
                                ),
                          );
                        },
                        icon: const Icon(Icons.info_outline),
                      ),
                  ],
                ),
              ),

              // Search Bar
              _buildSearchBar(),

              // Content
              Expanded(
                child:
                    _isLoading
                        ? const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.deepPurple,
                            ),
                          ),
                        )
                        : filteredItems.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                          onRefresh: () async => _loadItems(),
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: filteredItems.length,
                            itemBuilder: (context, index) {
                              return _buildItemCard(
                                filteredItems[index],
                                index,
                              );
                            },
                          ),
                        ),
              ),
            ],
          ),
        ),
      ),

      // Floating Action Button
      floatingActionButton: ScaleTransition(
        scale: _fabAnimation,
        child: FloatingActionButton.extended(
          onPressed: () => _showAddItemDialog(context),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          elevation: 8,
          icon: const Icon(Icons.add),
          label: const Text(
            'Add Item',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
