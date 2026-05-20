import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../widgets/chat_pulse_background.dart';
import '../widgets/typing_indicator.dart';
import '../services/ai_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<Map<String, dynamic>> _messages = [];
  List<Map<String, Object?>> _sessions = [];

  bool _isLoading = true;
  bool _isTyping = false;
  bool _isTitleSet = false; // tracks whether session title has been set yet

  int? _userId;
  int? _currentSessionId;
  String? _userName;

  @override
  void initState() {
    super.initState();
    _initNewSession();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Called on open and on "New Chat" — creates a fresh session, shows welcome.
  Future<void> _initNewSession() async {
    setState(() {
      _isLoading = true;
      _messages.clear();
      _isTitleSet = false;
    });

    final user = await DBHelper().getFirstUser();
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    _userId = user['user_id'] as int;
    _userName = user['full_name']?.toString() ?? 'there';

    // Create a fresh session in the database
    _currentSessionId = await DBHelper().createChatSession(_userId!);

    // Load sidebar session list
    await _loadSessions();

    // Build and show the welcome message (not saved to DB — it's UI only)
    final welcomeMsg = _buildWelcomeMessage(_userName!);
    setState(() {
      _messages.add({'message': welcomeMsg, 'sender': 'ai'});
      _isLoading = false;
    });

    _scrollToBottom();
  }

  // Loads a past session into the chat view.
  Future<void> _loadSession(int sessionId) async {
    if (_userId == null) return;
    setState(() {
      _isLoading = true;
      _messages.clear();
      _isTitleSet = true; // past sessions already have a title
    });

    _currentSessionId = sessionId;
    final history = await DBHelper().getChatHistory(_userId!, sessionId: sessionId);

    setState(() {
      _messages.addAll(history.map((m) => Map<String, dynamic>.from(m)));
      _isLoading = false;
    });
    _scrollToBottom();
  }

  Future<void> _loadSessions() async {
    if (_userId == null) return;
    final sessions = await DBHelper().getChatSessions(_userId!);
    setState(() => _sessions = sessions);
  }

  Future<void> _deleteSession(int sessionId) async {
    await DBHelper().deleteChatSession(sessionId);
    await _loadSessions();

    // If we just deleted the active session, start a new one
    if (sessionId == _currentSessionId) {
      await _initNewSession();
    }
  }

  String _buildWelcomeMessage(String name) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    return '$greeting, $name! 👋\n\n'
        "I'm VitalMate AI, your personal health companion. "
        'I can help you understand your health readings, answer questions about your wellbeing, '
        'and flag anything that looks unusual.\n\n'
        'How are you feeling today?';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _userId == null || _currentSessionId == null || _isTyping) return;

    // Connectivity check
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No internet connection. VitalMate AI needs to be online.'),
          ),
        );
      }
      return;
    }

    _messageController.clear();

    // Set session title from the first user message
    if (!_isTitleSet) {
      _isTitleSet = true;
      await DBHelper().updateSessionTitle(_currentSessionId!, text);
      await _loadSessions(); // refresh sidebar
    }

    // Save + show user message
    await DBHelper().insertMessage(
      _userId!,
      text,
      'user',
      sessionId: _currentSessionId!,
    );
    setState(() {
      _messages.add({'message': text, 'sender': 'user'});
      _isTyping = true;
    });
    _scrollToBottom();

    try {
      // Build history for AI — exclude the welcome message (sender: 'ai', not in DB)
      // and the message we just added (it's the current turn)
      final dbMessages = _messages
          .where((m) => m.containsKey('id')) // only DB-backed messages
          .toList();
      final historyForAI = dbMessages.length > 1
          ? dbMessages.sublist(0, dbMessages.length - 1)
          : <Map<String, dynamic>>[];

      final aiResponse = await AIService().getAIResponse(
        text,
        chatHistory: historyForAI,
      );

      await DBHelper().insertMessage(
        _userId!,
        aiResponse,
        'ai',
        sessionId: _currentSessionId!,
      );

      if (mounted) {
        setState(() {
          _messages.add({'message': aiResponse, 'sender': 'ai'});
          _isTyping = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add({
            'message': 'I had trouble reaching the server. Please try again.',
            'sender': 'ai',
          });
        });
        _scrollToBottom();
      }
    }
  }

  // Build

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildSidebar(),
      body: Stack(
        children: [
          const Positioned.fill(child: AnimatedMedicalBackground()),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: Color(0xFF24A593)),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          itemCount: _messages.length + (_isTyping ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (_isTyping && index == _messages.length) {
                              return _buildLoadingBubble();
                            }
                            final msg = _messages[index];
                            return _buildChatBubble(
                              msg['message'].toString(),
                              msg['sender'] == 'user',
                            );
                          },
                        ),
                ),
                _buildInputBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Sidebar

  Widget _buildSidebar() {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
              width: double.infinity,
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color.fromARGB(255, 255, 255, 255))),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFFE0F4F1),
                    radius: 18,
                    child: Icon(Icons.psychology_outlined, color: Color(0xFF24A593), size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'VitalMate AI',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Colors.black54),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),

            // New chat button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop(); // close drawer
                    _initNewSession();
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text(
                    'New chat',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF24A593),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),

            // Sessions label
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 10, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Previous chats',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.black38,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),

            // Session list
            Expanded(
              child: _sessions.isEmpty
                  ? const Center(
                      child: Text(
                        'No previous chats yet.',
                        style: TextStyle(fontSize: 13, color: Colors.black38),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      itemCount: _sessions.length,
                      itemBuilder: (context, index) {
                        final session = _sessions[index];
                        final sessionId = session['session_id'] as int;
                        final title = session['title']?.toString() ?? 'New chat';
                        final isActive = sessionId == _currentSessionId;

                        return Dismissible(
                          key: Key('session_$sessionId'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEBEB),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.delete_outline, color: Color(0xFFE53935), size: 20),
                          ),
                          onDismissed: (_) => _deleteSession(sessionId),
                          child: GestureDetector(
                            onTap: () {
                              Navigator.of(context).pop();
                              _loadSession(sessionId);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              margin: const EdgeInsets.symmetric(vertical: 3),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? const Color(0xFFE0F4F1)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: isActive
                                    ? Border.all(color: const Color(0xFF24A593).withValues(alpha: 0.3))
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.chat_bubble_outline,
                                    size: 16,
                                    color: isActive
                                        ? const Color(0xFF24A593)
                                        : Colors.black38,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isActive
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                        color: isActive
                                            ? const Color(0xFF1A7A6E)
                                            : Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Footer
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Swipe left on a chat to delete it.',
                style: TextStyle(fontSize: 11, color: Colors.black26),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Header

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu_rounded, color: Colors.black87),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            tooltip: 'Chat history',
          ),
          const Expanded(
            child: Text(
              'VitalMate AI',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black87),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_comment_outlined, color: Color(0xFF24A593)),
            onPressed: _initNewSession,
            tooltip: 'New chat',
          ),
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.black54),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Back',
          ),
        ],
      ),
    );
  }

  // Bubbles

  Widget _buildLoadingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20).copyWith(bottomLeft: Radius.zero),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5)],
        ),
        child: const TypingIndicator(),
      ),
    );
  }

  Widget _buildChatBubble(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF24A593) : Colors.white,
          borderRadius: BorderRadius.circular(20).copyWith(
            bottomRight: isUser ? Radius.zero : const Radius.circular(20),
            bottomLeft: isUser ? const Radius.circular(20) : Radius.zero,
          ),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5)],
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isUser ? Colors.white : Colors.black87,
            fontSize: 15,
            height: 1.45,
          ),
        ),
      ),
    );
  }

  // Input bar

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 15),
      decoration: const BoxDecoration(
        color: Colors.transparent,
        border: Border(top: BorderSide(color: Colors.transparent)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              onSubmitted: (_) => _sendMessage(),
              textInputAction: TextInputAction.send,
              decoration: InputDecoration(
                hintText: 'Ask about your health...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: const Color(0xFFF0F0F0),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: const Color(0xFF24A593),
            child: IconButton(
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}