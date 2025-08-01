// trend_forecasting_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class TrendForecastingPage extends StatefulWidget {
  const TrendForecastingPage({super.key});

  @override
  _TrendForecastingPageState createState() => _TrendForecastingPageState();
}

class _TrendForecastingPageState extends State<TrendForecastingPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<QuerySnapshot>? _trendsStream;
  Stream<QuerySnapshot>? _personalizedTrendsStream;
  List<Map<String, dynamic>> _trendTimeline = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initializeStreams();
    _loadTrendTimeline();
  }

  void _initializeStreams() {
    // AI-Powered Trend Detection Stream
    _trendsStream =
        _firestore
            .collection('trends')
            .where('status', isEqualTo: 'active')
            .orderBy('trendScore', descending: true)
            .snapshots();

    // Personalized Trend Recommendations Stream
    if (_auth.currentUser != null) {
      _personalizedTrendsStream =
          _firestore
              .collection('users')
              .doc(_auth.currentUser!.uid)
              .collection('personalizedTrends')
              .orderBy('relevanceScore', descending: true)
              .snapshots();
    }
  }

  Future<void> _loadTrendTimeline() async {
    setState(() => _isLoading = true);

    try {
      QuerySnapshot timelineSnapshot =
          await _firestore.collection('trendTimeline').orderBy('phase').get();

      setState(() {
        _trendTimeline =
            timelineSnapshot.docs
                .map(
                  (doc) => {
                    'id': doc.id,
                    ...doc.data() as Map<String, dynamic>,
                  },
                )
                .toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading trend timeline: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _performVisualTrendSearch() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() => _isLoading = true);

      try {
        // Upload image to Firebase Storage and get URL
        String imageUrl = await _uploadImageToStorage(File(image.path));

        // Call your AI service for visual trend analysis
        Map<String, dynamic> trendAnalysis = await _analyzeImageForTrends(
          imageUrl,
        );

        // Store analysis results in Firestore
        await _firestore.collection('visualTrendSearches').add({
          'userId': _auth.currentUser?.uid,
          'imageUrl': imageUrl,
          'analysis': trendAnalysis,
          'timestamp': FieldValue.serverTimestamp(),
        });

        _showTrendAnalysisResults(trendAnalysis);
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error analyzing image: $e')));
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<String> _uploadImageToStorage(File imageFile) async {
    // Implement Firebase Storage upload logic
    // Return the download URL
    throw UnimplementedError('Implement Firebase Storage upload');
  }

  Future<Map<String, dynamic>> _analyzeImageForTrends(String imageUrl) async {
    // Implement AI service call for trend analysis
    // This would typically call your ML model or external API
    throw UnimplementedError('Implement AI trend analysis');
  }

  void _showTrendAnalysisResults(Map<String, dynamic> analysis) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => TrendAnalysisResultsSheet(analysis: analysis),
    );
  }

  Future<void> _saveTrendToUserPreferences(String trendId) async {
    if (_auth.currentUser != null) {
      await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('savedTrends')
          .doc(trendId)
          .set({'trendId': trendId, 'savedAt': FieldValue.serverTimestamp()});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Trend Forecasting'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'AI Trends'),
            Tab(text: 'For You'),
            Tab(text: 'Timeline'),
            Tab(text: 'Search'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAITrendsTab(),
          _buildPersonalizedTrendsTab(),
          _buildTrendTimelineTab(),
          _buildVisualSearchTab(),
        ],
      ),
    );
  }

  Widget _buildAITrendsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _trendsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No trends available'));
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var trendDoc = snapshot.data!.docs[index];
            var trend = trendDoc.data() as Map<String, dynamic>;

            return TrendCard(
              trend: trend,
              trendId: trendDoc.id,
              onSave: () => _saveTrendToUserPreferences(trendDoc.id),
            );
          },
        );
      },
    );
  }

  Widget _buildPersonalizedTrendsTab() {
    if (_auth.currentUser == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Sign in to see personalized trends'),
            ElevatedButton(
              onPressed: () {
                // Navigate to login page
              },
              child: Text('Sign In'),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _personalizedTrendsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No personalized trends available'));
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var trendDoc = snapshot.data!.docs[index];
            var trend = trendDoc.data() as Map<String, dynamic>;

            return PersonalizedTrendCard(
              trend: trend,
              trendId: trendDoc.id,
              relevanceScore: trend['relevanceScore']?.toDouble() ?? 0.0,
            );
          },
        );
      },
    );
  }

  Widget _buildTrendTimelineTab() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    return ListView.builder(
      itemCount: _trendTimeline.length,
      itemBuilder: (context, index) {
        var timelineItem = _trendTimeline[index];
        return TrendTimelineCard(
          timelineItem: timelineItem,
          isLast: index == _trendTimeline.length - 1,
        );
      },
    );
  }

  Widget _buildVisualSearchTab() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.camera_alt, size: 80, color: Colors.grey[400]),
          SizedBox(height: 24),
          Text(
            'Visual Trend Search',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          Text(
            'Upload a photo to find similar trending styles',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _performVisualTrendSearch,
            icon: Icon(Icons.upload),
            label: Text('Upload Photo'),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
          ),
          if (_isLoading) ...[
            SizedBox(height: 24),
            CircularProgressIndicator(),
            SizedBox(height: 8),
            Text('Analyzing image...'),
          ],
        ],
      ),
    );
  }
}

// Custom Widgets
class TrendCard extends StatelessWidget {
  final Map<String, dynamic> trend;
  final String trendId;
  final VoidCallback onSave;

  const TrendCard({super.key, 
    required this.trend,
    required this.trendId,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (trend['imageUrl'] != null)
            ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
              child: Image.network(
                trend['imageUrl'],
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        trend['name'] ?? 'Unnamed Trend',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      onPressed: onSave,
                      icon: Icon(Icons.bookmark_border),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  trend['description'] ?? '',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    _buildTrendChip(
                      'Score: ${trend['trendScore']?.toString() ?? '0'}',
                    ),
                    SizedBox(width: 8),
                    _buildTrendChip(trend['category'] ?? 'General'),
                    SizedBox(width: 8),
                    _buildTrendChip(trend['source'] ?? 'AI'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendChip(String label) {
    return Chip(
      label: Text(label, style: TextStyle(fontSize: 12)),
      backgroundColor: Colors.grey[200],
      visualDensity: VisualDensity.compact,
    );
  }
}

class PersonalizedTrendCard extends StatelessWidget {
  final Map<String, dynamic> trend;
  final String trendId;
  final double relevanceScore;

  const PersonalizedTrendCard({super.key, 
    required this.trend,
    required this.trendId,
    required this.relevanceScore,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(8),
      child: ListTile(
        leading:
            trend['imageUrl'] != null
                ? CircleAvatar(backgroundImage: NetworkImage(trend['imageUrl']))
                : CircleAvatar(child: Icon(Icons.trending_up)),
        title: Text(trend['name'] ?? 'Unnamed Trend'),
        subtitle: Text(trend['reason'] ?? 'Recommended for you'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${(relevanceScore * 100).toInt()}%'),
            Text('match', style: TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class TrendTimelineCard extends StatelessWidget {
  final Map<String, dynamic> timelineItem;
  final bool isLast;

  const TrendTimelineCard({super.key, required this.timelineItem, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _getPhaseColor(timelineItem['phase']),
              ),
            ),
            if (!isLast)
              Container(width: 2, height: 60, color: Colors.grey[300]),
          ],
        ),
        SizedBox(width: 16),
        Expanded(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    timelineItem['phase'] ?? '',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  SizedBox(height: 4),
                  Text(
                    timelineItem['description'] ?? '',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (timelineItem['adoptionRate'] != null) ...[
                    SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: timelineItem['adoptionRate'] / 100.0,
                      backgroundColor: Colors.grey[300],
                    ),
                    SizedBox(height: 4),
                    Text('${timelineItem['adoptionRate']}% adoption'),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _getPhaseColor(String? phase) {
    switch (phase?.toLowerCase()) {
      case 'emerging':
        return Colors.green;
      case 'growing':
        return Colors.orange;
      case 'mainstream':
        return Colors.blue;
      case 'declining':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

class TrendAnalysisResultsSheet extends StatelessWidget {
  final Map<String, dynamic> analysis;

  const TrendAnalysisResultsSheet({super.key, required this.analysis});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Trend Analysis Results',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close),
              ),
            ],
          ),
          Divider(),
          Expanded(
            child: ListView(
              children: [
                if (analysis['similarTrends'] != null)
                  _buildSimilarTrendsSection(analysis['similarTrends']),
                if (analysis['colors'] != null)
                  _buildColorsSection(analysis['colors']),
                if (analysis['patterns'] != null)
                  _buildPatternsSection(analysis['patterns']),
                if (analysis['style'] != null)
                  _buildStyleSection(analysis['style']),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimilarTrendsSection(List<dynamic> similarTrends) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Similar Trends',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        ...similarTrends
            .map(
              (trend) => ListTile(
                title: Text(trend['name'] ?? ''),
                subtitle: Text('${trend['confidence']}% confidence'),
                trailing: Icon(Icons.trending_up),
              ),
            )
            ,
        SizedBox(height: 16),
      ],
    );
  }

  Widget _buildColorsSection(List<dynamic> colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Detected Colors',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children:
              colors
                  .map(
                    (color) => Chip(
                      label: Text(color['name'] ?? ''),
                      backgroundColor: Color(
                        int.parse(color['hex'].replaceFirst('#', '0xFF')),
                      ),
                    ),
                  )
                  .toList(),
        ),
        SizedBox(height: 16),
      ],
    );
  }

  Widget _buildPatternsSection(List<dynamic> patterns) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Patterns',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        ...patterns
            .map((pattern) => Chip(label: Text(pattern['type'] ?? '')))
            ,
        SizedBox(height: 16),
      ],
    );
  }

  Widget _buildStyleSection(Map<String, dynamic> style) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Style Analysis',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        Text('Category: ${style['category'] ?? 'Unknown'}'),
        Text('Formality: ${style['formality'] ?? 'Unknown'}'),
        Text('Season: ${style['season'] ?? 'Unknown'}'),
      ],
    );
  }
}
