import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SustainabilityPage extends StatefulWidget {
  const SustainabilityPage({super.key});

  @override
  State<SustainabilityPage> createState() => _SustainabilityPageState();
}

class _SustainabilityPageState extends State<SustainabilityPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Data variables
  Map<String, dynamic>? userFootprint;
  List<Map<String, dynamic>> sustainableBrands = [];
  List<Map<String, dynamic>> ecoProducts = [];
  List<Map<String, dynamic>> materials = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchAllData() async {
    setState(() => isLoading = true);

    try {
      await Future.wait([
        _fetchUserFootprint(),
        _fetchSustainableBrands(),
        _fetchEcoProducts(),
        _fetchMaterials(),
      ]);
    } catch (e) {
      print('Error fetching data: $e');
    }

    setState(() => isLoading = false);
  }

  Future<void> _fetchUserFootprint() async {
    final user = _auth.currentUser;
    if (user != null) {
      final doc =
          await _firestore.collection('user_footprints').doc(user.uid).get();

      if (doc.exists) {
        userFootprint = doc.data();
      } else {
        // Create initial footprint document
        userFootprint = {
          'totalFootprint': 0.0,
          'monthlyFootprint': {},
          'totalPurchases': 0,
          'goals': {'monthly_limit': 10.0, 'annual_target': 100.0},
        };
        await _firestore
            .collection('user_footprints')
            .doc(user.uid)
            .set(userFootprint!);
      }
    }
  }

  Future<void> _fetchSustainableBrands() async {
    final snapshot =
        await _firestore
            .collection('brands')
            .where('environmentalScore', isGreaterThan: 4.0)
            .orderBy('environmentalScore', descending: true)
            .limit(10)
            .get();

    sustainableBrands =
        snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  Future<void> _fetchEcoProducts() async {
    final snapshot =
        await _firestore
            .collection('products')
            .where('carbonFootprint', isLessThan: 3.0)
            .orderBy('carbonFootprint')
            .limit(10)
            .get();

    ecoProducts =
        snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  Future<void> _fetchMaterials() async {
    final snapshot =
        await _firestore
            .collection('materials')
            .orderBy('sustainability_score', descending: true)
            .get();

    materials =
        snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : CustomScrollView(
                slivers: [
                  _buildAppBar(),
                  SliverFillRemaining(
                    child: Column(
                      children: [
                        _buildTabBar(),
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildDashboardTab(),
                              _buildBrandsTab(),
                              _buildMaterialsTab(),
                              _buildImpactTab(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
    );
  }

  Widget _buildAppBar() {
    final currentFootprint = userFootprint?['totalFootprint'] ?? 0.0;
    final monthlyGoal = userFootprint?['goals']?['monthly_limit'] ?? 10.0;

    return SliverAppBar(
      expandedHeight: 200,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: const Color(0xFF4CAF50),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.eco, color: Colors.white, size: 30),
                      SizedBox(width: 10),
                      Text(
                        'Sustainability Hub',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 28,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Your Carbon Footprint: ${currentFootprint.toStringAsFixed(1)} kg CO₂',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 5),
                  LinearProgressIndicator(
                    value: (currentFootprint / monthlyGoal).clamp(0.0, 1.0),
                    backgroundColor: Colors.white.withOpacity(0.3),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: const Color(0xFF4CAF50),
        unselectedLabelColor: Colors.grey,
        indicatorColor: const Color(0xFF4CAF50),
        tabs: const [
          Tab(text: 'Dashboard'),
          Tab(text: 'Brands'),
          Tab(text: 'Materials'),
          Tab(text: 'Impact'),
        ],
      ),
    );
  }

  Widget _buildDashboardTab() {
    final totalFootprint = userFootprint?['totalFootprint'] ?? 0.0;
    final monthlyGoal = userFootprint?['goals']?['monthly_limit'] ?? 10.0;
    final progress = (totalFootprint / monthlyGoal * 100).clamp(0.0, 100.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress Card
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                gradient: const LinearGradient(
                  colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Monthly Progress',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${progress.toStringAsFixed(1)}% of goal',
                              style: const TextStyle(color: Colors.white70),
                            ),
                            const SizedBox(height: 5),
                            LinearProgressIndicator(
                              value: progress / 100,
                              backgroundColor: Colors.white.withOpacity(0.3),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Column(
                        children: [
                          Text(
                            '${totalFootprint.toStringAsFixed(1)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            'kg CO₂',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Quick Actions
          const Text(
            'Quick Actions',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  'Track Purchase',
                  Icons.add_shopping_cart,
                  const Color(0xFF2196F3),
                  () => _showTrackPurchaseDialog(),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _buildActionCard(
                  'Set Goals',
                  Icons.flag,
                  const Color(0xFFFF9800),
                  () => _showSetGoalsDialog(),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Eco-Friendly Recommendations
          const Text(
            'Recommended Eco Products',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),
          SizedBox(
            height: 180,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: ecoProducts.length,
              itemBuilder: (context, index) {
                final product = ecoProducts[index];
                return _buildProductCard(product);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top Sustainable Brands',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sustainableBrands.length,
            itemBuilder: (context, index) {
              final brand = sustainableBrands[index];
              return _buildBrandCard(brand);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sustainable Materials Guide',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: materials.length,
            itemBuilder: (context, index) {
              final material = materials[index];
              return _buildMaterialCard(material);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildImpactTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Environmental Impact',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),
          _buildImpactStats(),
          const SizedBox(height: 20),
          _buildAchievements(),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, size: 30, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    return Container(
      width: 150,
      margin: const EdgeInsets.only(right: 15),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 80,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                color: Colors.grey.shade200,
              ),
              child: const Center(
                child: Icon(Icons.eco, size: 40, color: Color(0xFF4CAF50)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['name'] ?? 'Product',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${product['carbonFootprint']} kg CO₂',
                    style: const TextStyle(color: Colors.green, fontSize: 10),
                  ),
                  Text(
                    '\$${product['price']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandCard(Map<String, dynamic> brand) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey.shade200,
              ),
              child: const Icon(
                Icons.business,
                size: 30,
                color: Color(0xFF4CAF50),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    brand['name'] ?? 'Brand',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _buildScoreChip(
                        'Env',
                        brand['environmentalScore'] ?? 0.0,
                      ),
                      const SizedBox(width: 8),
                      _buildScoreChip('Labor', brand['laborScore'] ?? 0.0),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (brand['certifications'] != null)
                    Wrap(
                      spacing: 4,
                      children:
                          (brand['certifications'] as List)
                              .take(2)
                              .map(
                                (cert) => Chip(
                                  label: Text(
                                    cert,
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                  backgroundColor: Colors.green.shade100,
                                ),
                              )
                              .toList(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialCard(Map<String, dynamic> material) {
    final score = material['sustainability_score'] ?? 0.0;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: _getScoreColor(score).withOpacity(0.2),
          ),
          child: Center(
            child: Text(
              score.toStringAsFixed(1),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _getScoreColor(score),
              ),
            ),
          ),
        ),
        title: Text(
          material['name'] ?? 'Material',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          material['environmental_impact'] ?? '',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (material['benefits'] != null) ...[
                  const Text(
                    'Benefits:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...(material['benefits'] as List).map(
                    (benefit) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            size: 16,
                            color: Color(0xFF4CAF50),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(benefit)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreChip(String label, double score) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getScoreColor(score).withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$label ${score.toStringAsFixed(1)}',
        style: TextStyle(
          fontSize: 12,
          color: _getScoreColor(score),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 4.0) return Colors.green;
    if (score >= 3.0) return Colors.orange;
    return Colors.red;
  }

  Widget _buildImpactStats() {
    final totalFootprint = userFootprint?['totalFootprint'] ?? 0.0;
    final totalPurchases = userFootprint?['totalPurchases'] ?? 0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total CO₂',
                '${totalFootprint.toStringAsFixed(1)} kg',
                Icons.cloud,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _buildStatCard(
                'Purchases',
                '$totalPurchases items',
                Icons.shopping_bag,
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Avg/Item',
                '${totalPurchases > 0 ? (totalFootprint / totalPurchases).toStringAsFixed(1) : "0"} kg',
                Icons.assessment,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _buildStatCard(
                'This Month',
                '${_getCurrentMonthFootprint().toStringAsFixed(1)} kg',
                Icons.calendar_today,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 30, color: const Color(0xFF4CAF50)),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(title, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievements() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Achievements',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 15),
        _buildAchievementCard(
          'Eco Warrior',
          'Complete 10 sustainable purchases',
          true,
        ),
        _buildAchievementCard(
          'Carbon Reducer',
          'Reduce monthly footprint by 20%',
          false,
        ),
        _buildAchievementCard(
          'Material Expert',
          'Learn about 5 sustainable materials',
          false,
        ),
      ],
    );
  }

  Widget _buildAchievementCard(
    String title,
    String description,
    bool achieved,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(
          achieved ? Icons.emoji_events : Icons.lock,
          color: achieved ? Colors.amber : Colors.grey,
          size: 30,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: achieved ? Colors.black : Colors.grey,
          ),
        ),
        subtitle: Text(
          description,
          style: TextStyle(color: achieved ? Colors.black87 : Colors.grey),
        ),
      ),
    );
  }

  double _getCurrentMonthFootprint() {
    final currentMonth = DateTime.now().toIso8601String().substring(0, 7);
    final monthlyData =
        userFootprint?['monthlyFootprint'] as Map<String, dynamic>?;
    return monthlyData?[currentMonth]?.toDouble() ?? 0.0;
  }

  void _showTrackPurchaseDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Track Purchase'),
            content: const Text(
              'This feature will help you log new purchases and calculate their carbon footprint.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Coming Soon'),
              ),
            ],
          ),
    );
  }

  void _showSetGoalsDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Set Sustainability Goals'),
            content: const Text(
              'Customize your monthly and annual carbon footprint targets.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Coming Soon'),
              ),
            ],
          ),
    );
  }
}
