// Enhanced ChatbotPage UI with sidebar, speech-to-text, Firestore integration, and improved chat management
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:mime/mime.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

const String apiKey = "AIzaSyAUdLXtAkOCRC-IIH_tELPqtm_4rPBQOyQ";

class ChatSession {
  final String id;
  final String title;
  final DateTime createdAt;
  final List<Map<String, dynamic>> messages;

  ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.messages,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'messages': messages,
    };
  }

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: json['id'],
      title: json['title'],
      createdAt: DateTime.parse(json['createdAt']),
      messages: List<Map<String, dynamic>>.from(json['messages']),
    );
  }
}

class ChatbotPage extends StatefulWidget {
  const ChatbotPage({super.key});

  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage>
    with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  GenerativeModel? _model;
  bool _isLoading = false;
  bool _isModelInitializing = true;

  // Speech to text
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _speechEnabled = false;

  // Chat sessions
  List<ChatSession> _chatSessions = [];
  String? _currentSessionId;
  bool _isLoadingHistory = false;

  // Animation controllers
  late AnimationController _micAnimationController;
  late Animation<double> _micPulseAnimation;

  @override
  void initState() {
    super.initState();
    _initializeModel();
    _initializeSpeech();
    _initializeAnimations();
    _initializeApp();
  }

  @override
  void dispose() {
    _micAnimationController.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    _micAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _micPulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _micAnimationController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initializeApp() async {
    setState(() {
      _isLoadingHistory = true;
    });

    try {
      await _initializeAuth();
      await _loadChatSessions();

      // Only start new chat if no existing sessions
      if (_chatSessions.isEmpty) {
        _startNewChat();
      }
    } catch (e) {
      print('Error initializing app: $e');
      _startNewChat(); // Fallback to new chat
    } finally {
      setState(() {
        _isLoadingHistory = false;
      });
    }
  }

  Future<void> _initializeModel() async {
    try {
      _model = GenerativeModel(
        model: 'gemini-1.5-flash-latest',
        apiKey: apiKey,
      );
    } catch (e) {
      _addMessage('model', 'Error initializing Gemini: ${e.toString()}');
    } finally {
      setState(() {
        _isModelInitializing = false;
      });
    }
  }

  Future<void> _initializeSpeech() async {
    _speech = stt.SpeechToText();

    // Request microphone permission
    var status = await Permission.microphone.request();
    if (status == PermissionStatus.granted) {
      _speechEnabled = await _speech.initialize(
        onError: (error) {
          setState(() {
            _isListening = false;
          });
          _micAnimationController.stop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Speech recognition error: ${error.errorMsg}'),
            ),
          );
        },
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            setState(() {
              _isListening = false;
            });
            _micAnimationController.stop();
          }
        },
      );
    }
  }

  Future<void> _initializeAuth() async {
    // Sign in anonymously if no user is signed in
    if (FirebaseAuth.instance.currentUser == null) {
      try {
        await FirebaseAuth.instance.signInAnonymously();
        print(
          'Signed in anonymously: ${FirebaseAuth.instance.currentUser?.uid}',
        );
      } catch (e) {
        print('Error signing in anonymously: $e');
        rethrow;
      }
    } else {
      print(
        'User already signed in: ${FirebaseAuth.instance.currentUser?.uid}',
      );
    }
  }

  Future<void> _loadChatSessions() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('No user found, cannot load chat sessions');
        return;
      }

      print('Loading chat sessions for user: ${user.uid}');

      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('chat_sessions')
              .orderBy('createdAt', descending: true)
              .get();

      print('Found ${querySnapshot.docs.length} chat sessions');

      setState(() {
        _chatSessions =
            querySnapshot.docs.map((doc) {
              final data = doc.data();
              print('Loading session: ${doc.id} - ${data['title']}');
              return ChatSession(
                id: doc.id,
                title: data['title'] ?? 'New Chat',
                createdAt:
                    data['createdAt'] != null
                        ? (data['createdAt'] as Timestamp).toDate()
                        : DateTime.now(),
                messages: List<Map<String, dynamic>>.from(
                  data['messages'] ?? [],
                ),
              );
            }).toList();
      });

      print('Loaded ${_chatSessions.length} chat sessions successfully');
    } catch (e) {
      print('Error loading chat sessions: $e');
    }
  }

  void _startNewChat() {
    setState(() {
      _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
      _messages.clear();
    });

    // Add welcome message
    _addMessage(
      'model',
      'Hello! I\'m your AI assistant. How can I help you today?',
    );
  }

  Future<void> _saveCurrentSession() async {
    if (_currentSessionId == null || _messages.isEmpty) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('No user found, cannot save session');
        return;
      }

      // Generate title from first user message or use default
      String title = 'New Chat';
      final firstUserMessage = _messages.firstWhere(
        (msg) => msg['role'] == 'user',
        orElse: () => {'content': ''},
      );
      if (firstUserMessage['content'] != null &&
          firstUserMessage['content'].isNotEmpty) {
        title = firstUserMessage['content'].toString();
        if (title.length > 30) {
          title = '${title.substring(0, 30)}...';
        }
      }

      // Prepare messages for Firestore (remove media bytes for storage efficiency)
      final messagesToSave =
          _messages.map((msg) {
            final msgCopy = Map<String, dynamic>.from(msg);
            if (msgCopy.containsKey('mediaBytes')) {
              msgCopy.remove('mediaBytes'); // Remove binary data
            }
            return msgCopy;
          }).toList();

      print('Saving session: $_currentSessionId with title: $title');

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('chat_sessions')
          .doc(_currentSessionId)
          .set({
            'title': title,
            'createdAt': FieldValue.serverTimestamp(),
            'messages': messagesToSave,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      // Update local sessions list
      final existingIndex = _chatSessions.indexWhere(
        (s) => s.id == _currentSessionId,
      );
      final session = ChatSession(
        id: _currentSessionId!,
        title: title,
        createdAt: DateTime.now(),
        messages: List.from(_messages),
      );

      setState(() {
        if (existingIndex >= 0) {
          _chatSessions[existingIndex] = session;
        } else {
          _chatSessions.insert(0, session);
        }
      });

      print('Session saved successfully');
    } catch (e) {
      print('Error saving chat session: $e');
    }
  }

  void _loadChatSession(ChatSession session) {
    setState(() {
      _currentSessionId = session.id;
      _messages.clear();
      _messages.addAll(session.messages);
    });
    Navigator.of(context).pop(); // Close drawer
  }

  void _addMessage(
    String role,
    dynamic content, {
    bool isLoadingMessage = false,
    Uint8List? mediaBytes,
    String? mimeType,
  }) {
    setState(() {
      _messages.add({
        'role': role,
        'content': content,
        'isLoading': isLoadingMessage,
        'mediaBytes': mediaBytes,
        'mimeType': mimeType,
        'timestamp': DateTime.now().toIso8601String(),
      });
    });

    // Auto-save session after each message
    if (!isLoadingMessage) {
      _saveCurrentSession();
    }
  }

  Future<void> _startListening() async {
    if (!_speechEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech recognition not available')),
      );
      return;
    }

    setState(() {
      _isListening = true;
    });
    _micAnimationController.repeat(reverse: true);

    await _speech.listen(
      onResult: (result) {
        setState(() {
          _controller.text = result.recognizedWords;
        });
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
    );
  }

  Future<void> _stopListening() async {
    setState(() {
      _isListening = false;
    });
    _micAnimationController.stop();
    await _speech.stop();
  }

  Future<void> _sendMessage(
    String message, {
    List<DataPart>? mediaParts,
  }) async {
    if (_isModelInitializing) {
      _addMessage('model', 'Gemini is still initializing. Please wait...');
      return;
    }
    if (_model == null) {
      _addMessage('model', 'Error: Gemini model is not initialized.');
      return;
    }
    if (message.trim().isEmpty && (mediaParts == null || mediaParts.isEmpty)) {
      return;
    }

    setState(() => _isLoading = true);

    String userDisplayContent = message;
    Uint8List? mediaBytes;
    String? mimeType;

    if (mediaParts != null && mediaParts.isNotEmpty) {
      final fileNames = mediaParts
          .map((p) => _getMediaDisplayName(p.mimeType))
          .join(", ");
      userDisplayContent = '$message $fileNames'.trim();
      mediaBytes = mediaParts.first.bytes;
      mimeType = mediaParts.first.mimeType;
    }

    _addMessage(
      'user',
      userDisplayContent,
      mediaBytes: mediaBytes,
      mimeType: mimeType,
    );
    _controller.clear();

    final List<Content> promptParts = [];
    if (message.isNotEmpty) {
      promptParts.add(Content.text(message));
    }
    if (mediaParts != null) {
      promptParts.addAll(mediaParts.map((part) => Content.multi([part])));
    }

    int loadingMessageIndex = _messages.length;
    _addMessage('model', 'Thinking...', isLoadingMessage: true);

    try {
      final response = await _model!.generateContent(promptParts);
      final reply = response.text ?? 'Sorry, I could not process that.';
      setState(() {
        _messages.removeAt(loadingMessageIndex);
        _addMessage('model', reply);
      });
    } catch (e) {
      setState(() {
        _messages.removeAt(loadingMessageIndex);
        _addMessage('model', 'Error: ${e.toString()}');
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _getMediaDisplayName(String? mimeType) {
    if (mimeType?.startsWith('image/') == true) return '[Image]';
    if (mimeType?.startsWith('video/') == true) return '[Video]';
    if (mimeType?.startsWith('audio/') == true) return '[Audio]';
    return '[Media]';
  }

  Future<void> _pickMedia() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'jpg',
        'jpeg',
        'png',
        'gif',
        'webp',
        'bmp',
        'mp4',
        'mov',
        'avi',
        'mkv',
        'mp3',
        'wav',
        'aac',
        'flac',
        'm4a',
      ],
    );

    if (result != null && result.files.isNotEmpty) {
      final pickedFile = result.files.single;
      if (pickedFile.path != null) {
        final filePath = pickedFile.path!;
        final fileBytes = await File(filePath).readAsBytes();
        String? mimeType = lookupMimeType(filePath);

        if (mimeType == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not determine file type.')),
          );
          return;
        }

        final mediaPart = DataPart(mimeType, fileBytes);
        String? accompanyingText = await _showAccompanyingTextDialog();
        if (accompanyingText != null) {
          _sendMessage(accompanyingText, mediaParts: [mediaPart]);
        }
      }
    }
  }

  Future<String?> _showAccompanyingTextDialog() async {
    final textController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Add a message'),
          content: TextField(
            controller: textController,
            decoration: const InputDecoration(
              hintText: "What would you like to know about this media?",
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed:
                  () => Navigator.of(context).pop(
                    textController.text.trim().isEmpty
                        ? "Analyze this media."
                        : textController.text,
                  ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
              child: const Text('Send'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> messageData) {
    bool isUser = messageData['role'] == 'user';
    String content = messageData['content'] as String;
    bool isLoadingMessage = messageData['isLoading'] ?? false;
    Uint8List? mediaBytes =
        messageData['mediaBytes'] != null
            ? Uint8List.fromList(List<int>.from(messageData['mediaBytes']))
            : null;
    String? mimeType = messageData['mimeType'];
    bool isImage = mimeType?.startsWith('image/') ?? false;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.deepPurple.shade100,
              child: Icon(Icons.smart_toy, size: 18, color: Colors.deepPurple),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? Colors.deepPurple : Colors.grey.shade100,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isLoadingMessage)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.deepPurple,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Thinking...',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      content,
                      style: TextStyle(
                        color: isUser ? Colors.white : Colors.black87,
                        fontSize: 16,
                        height: 1.4,
                      ),
                    ),
                  if (isImage && mediaBytes != null) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        mediaBytes,
                        height: 200,
                        width: 200,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.deepPurple,
              child: const Icon(Icons.person, size: 18, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _deleteChatSessionFromFirestore(ChatSession session) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('chat_sessions')
          .doc(session.id)
          .delete();
    } catch (e) {
      print('Error deleting chat session: $e');
    }
  }

  void _deleteChatSession(ChatSession session) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Chat'),
            content: const Text('Are you sure you want to delete this chat?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  // Delete from Firestore
                  await _deleteChatSessionFromFirestore(session);

                  // Update local state
                  setState(() {
                    _chatSessions.removeWhere((s) => s.id == session.id);
                  });

                  Navigator.of(context).pop();

                  // If current session is deleted, start new chat
                  if (session.id == _currentSessionId) {
                    _startNewChat();
                  }
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildSidebar() {
    return Drawer(
      child: Column(
        children: [
          // Fixed header with proper constraints
          // Replace the header Container in _buildSidebar() with this:
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.deepPurple, Colors.deepPurple.shade300],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize:
                      MainAxisSize.min, // This is key - let it size itself
                  children: [
                    const Text(
                      'Chat History',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_chatSessions.length} conversations',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // New Chat Button with proper padding
          Padding(
            padding: const EdgeInsets.all(12), // Reduced padding
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  _startNewChat();
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.add, size: 20),
                label: const Text('New Chat'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                  ), // Reduced padding
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),

          // Chat sessions list
          Expanded(
            child:
                _isLoadingHistory
                    ? const Center(child: CircularProgressIndicator())
                    : _chatSessions.isEmpty
                    ? const Center(
                      child: Text(
                        'No previous chats',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: _chatSessions.length,
                      itemBuilder: (context, index) {
                        final session = _chatSessions[index];
                        final isCurrentSession =
                            session.id == _currentSessionId;

                        return Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 1, // Reduced vertical margin
                          ),
                          decoration: BoxDecoration(
                            color:
                                isCurrentSession
                                    ? Colors.deepPurple.withOpacity(0.1)
                                    : null,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListTile(
                            dense: true, // Make tiles more compact
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 2, // Reduced vertical padding
                            ),
                            leading: CircleAvatar(
                              backgroundColor: Colors.deepPurple.shade100,
                              radius: 16, // Slightly smaller
                              child: Icon(
                                Icons.chat,
                                color: Colors.deepPurple,
                                size: 16, // Smaller icon
                              ),
                            ),
                            title: Text(
                              session.title,
                              style: TextStyle(
                                fontWeight:
                                    isCurrentSession
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                fontSize: 13, // Smaller font
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              _formatDate(session.createdAt),
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 10, // Smaller font
                              ),
                            ),
                            onTap: () => _loadChatSession(session),
                            trailing: SizedBox(
                              width: 28, // Smaller trailing area
                              child: IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 16, // Smaller icon
                                ),
                                onPressed: () => _deleteChatSession(session),
                                color: Colors.grey.shade600,
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.grey.shade50,
      drawer: _buildSidebar(),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.deepPurple,
        title: const Text(
          'AI Assistant',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _startNewChat,
            tooltip: 'New Chat',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child:
                _messages.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.smart_toy,
                              size: 48,
                              color: Colors.deepPurple,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'How can I help you today?',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Ask me anything, send an image, or use voice input',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.only(top: 16, bottom: 100),
                      itemCount: _messages.length,
                      itemBuilder:
                          (_, index) => _buildMessageBubble(_messages[index]),
                    ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // Media attachment button
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: IconButton(
                      onPressed: _pickMedia,
                      icon: const Icon(Icons.attach_file),
                      color: Colors.deepPurple,
                      tooltip: 'Attach media',
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Speech-to-text button
                  Container(
                    decoration: BoxDecoration(
                      color:
                          _isListening
                              ? Colors.red.shade100
                              : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: AnimatedBuilder(
                      animation: _micPulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _isListening ? _micPulseAnimation.value : 1.0,
                          child: IconButton(
                            onPressed:
                                _speechEnabled
                                    ? (_isListening
                                        ? _stopListening
                                        : _startListening)
                                    : null,
                            icon: Icon(
                              _isListening ? Icons.mic : Icons.mic_none,
                            ),
                            color:
                                _isListening ? Colors.red : Colors.deepPurple,
                            tooltip:
                                _isListening ? 'Stop listening' : 'Voice input',
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Text input field
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          hintText: 'Type your message...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (value) => _sendMessage(value),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Send button
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.deepPurple,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: IconButton(
                      onPressed:
                          _isLoading
                              ? null
                              : () => _sendMessage(_controller.text),
                      icon:
                          _isLoading
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                              : const Icon(Icons.send),
                      color: Colors.white,
                      tooltip: 'Send message',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
