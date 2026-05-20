import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:my_vitalmate/screens/measurement_screen.dart';
import 'package:my_vitalmate/screens/reminder_screen.dart';
import '../database/db_helper.dart';
import '../services/ai_service.dart';
import 'chat_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DBHelper _db = DBHelper();
  final AIService _ai = AIService();

  bool _isLoading = true;

  String _userName = 'User';
  String? _profileImageUrl;

  String _bpValue = '--/--';
  String _bpStatus = 'No Data';

  String _bsValue = '--';
  String _bsStatus = 'No Data';

  double _healthScore = 0;
  String _aiInsight = '';

  bool _bpExpanded = false;
  bool _bsExpanded = false;

  static const Color _teal = Color(0xFF24A593);
  static const Color _tealDark = Color(0xFF156F65);
  static const Color _scaffoldBg = Color(0xFFF4F9F8);

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final user = await _db.getFirstUser();
      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final userId = user['user_id'] as int;

      final results = await Future.wait([
        _db.getLatestMeasurement(userId, 'Blood Pressure'),
        _db.getLatestMeasurement(userId, 'Blood Sugar'),
        _db.calculateHealthScore(userId),
      ]);

      final bp = results[0] as Map<String, Object?>?;
      final bs = results[1] as Map<String, Object?>?;
      final score = results[2] as double;

      String bpValue = '--/--';
      String bpStatus = 'No Data';
      String bsValue = '--';
      String bsStatus = 'No Data';

      if (bp != null) {
        final systolic = (bp['value_1'] as num?)?.toInt() ?? 0;
        final diastolic = (bp['value_2'] as num?)?.toInt() ?? 0;
        bpValue = '$systolic/$diastolic';
        bpStatus = _getBPStatus(systolic, diastolic);
      }

      if (bs != null) {
        final sugar = (bs['value_1'] as num?)?.toInt() ?? 0;
        bsValue = sugar.toString();
        bsStatus = _getSugarStatus(sugar);
      }

      final insight = await _generateAIInsight(bpValue, bsValue);

      if (!mounted) return;
      setState(() {
        _userName = (user['full_name']?.toString() ?? 'User').split(' ').first;
        _profileImageUrl = user['profile_image_url']?.toString();
        _healthScore = score;
        _bpValue = bpValue;
        _bpStatus = bpStatus;
        _bsValue = bsValue;
        _bsStatus = bsStatus;
        _aiInsight = insight;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Dashboard load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<String> _generateAIInsight(String bp, String bs) async {
    final hasData = bp != '--/--' || bs != '--';
    final prompt = hasData
        ? '''
Give a very short health insight for a mobile dashboard.

Blood Pressure: $bp mmHg
Blood Sugar: $bs mg/dL

Rules:
- Maximum 20 words
- Friendly and encouraging tone
- No markdown, no bullet points
- Plain text only
'''
        : '''
The user has not logged any health readings yet today.
Write a warm 1-sentence welcome encouraging them to log their first reading.
Maximum 20 words. Plain text only.
''';

    return await _ai.getAIResponse(prompt);
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning,';
    if (hour < 17) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  String _getGreetingEmoji() {
    final hour = DateTime.now().hour;
    if (hour < 12) return '☀️';
    if (hour < 17) return '🌤️';
    return '🌙';
  }

  String _getBPStatus(int systolic, int diastolic) {
    if (systolic < 120 && diastolic < 80) return 'Normal';
    if (systolic < 130 && diastolic < 85) return 'Elevated';
    return 'High';
  }

  String _getSugarStatus(int sugar) {
    if (sugar < 140) return 'Normal';
    if (sugar < 200) return 'Elevated';
    return 'High';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Normal':
        return Colors.green;
      case 'Elevated':
        return Colors.orange;
      case 'High':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getScoreMessage() {
    if (_healthScore >= 85) return 'Great job!';
    if (_healthScore >= 70) return 'Keep it up!';
    if (_healthScore > 0) return "Let's improve together";
    return 'Add readings to get your score';
  }

  Color _getScoreColor() {
    if (_healthScore >= 70) return Colors.green;
    if (_healthScore >= 50) return Colors.orange;
    if (_healthScore > 0) return Colors.red;
    return Colors.grey;
  }

  void _navigateToReminders() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RemindersScreen()),
    );
  }

  void _navigateToChat() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ChatScreen()));
  }

  void _navigateToHistory() {
    // Navigator.of(context).push(
    //   MaterialPageRoute(builder: (_) => const HistoryScreen()),
    // );
  }

  void _navigateToProfile() {
    // Navigator.of(context).push(
    //   MaterialPageRoute(builder: (_) => const ProfileScreen()),
    // );
  }

  Future<void> _navigateToAddReading() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddMeasurementScreen()),
    );
    if (result == true) _loadDashboardData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _scaffoldBg,
      extendBody: true,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _teal))
          : SafeArea(
              bottom: false,
              child: RefreshIndicator(
                color: _teal,
                onRefresh: _loadDashboardData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 16),
                      _buildHealthScoreCard(),
                      const SizedBox(height: 16),
                      const Text(
                        "Today's Overview",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricCard(
                              title: 'Blood Pressure',
                              value: _bpValue,
                              unit: 'mm/Hg',
                              status: _bpStatus,
                              isExpanded: _bpExpanded,
                              onTap: () =>
                                  setState(() => _bpExpanded = !_bpExpanded),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMetricCard(
                              title: 'Blood Sugar',
                              value: _bsValue,
                              unit: 'mg/dL',
                              status: _bsStatus,
                              isExpanded: _bsExpanded,
                              onTap: () =>
                                  setState(() => _bsExpanded = !_bsExpanded),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildAIInsightCard(),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
      floatingActionButton: _buildFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      'Hello, $_userName ${_getGreetingEmoji()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                _getGreeting(),
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: _navigateToReminders,
          icon: const Icon(
            Icons.notifications_outlined,
            size: 27,
            color: Colors.black87,
          ),
          tooltip: 'Reminders',
        ),
        const SizedBox(width: 7),
        GestureDetector(
          onTap: _navigateToProfile,
          child: _buildProfileAvatar(),
        ),
      ],
    );
  }

  Widget _buildProfileAvatar() {
    if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      final url = _profileImageUrl!;

      if (url.startsWith('data:image') && url.contains('base64,')) {
        try {
          final base64Part = url.split('base64,').last;
          final bytes = base64Decode(base64Part);
          return CircleAvatar(radius: 20, backgroundImage: MemoryImage(bytes));
        } catch (_) {}
      }

      return CircleAvatar(radius: 20, backgroundImage: NetworkImage(url));
    }

    return const CircleAvatar(
      radius: 20,
      backgroundColor: Color(0xFFD6EDE9),
      child: Icon(Icons.person, color: _tealDark, size: 22),
    );
  }

  Widget _buildHealthScoreCard() {
    return Container(
      width: double.infinity,
      height: 160,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _teal.withValues(alpha: 0.09),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Health Score',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _healthScore > 0 ? _healthScore.toInt().toString() : '—',
                      style: const TextStyle(
                        fontSize: 42,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    ),
                    if (_healthScore > 0)
                      const Padding(
                        padding: EdgeInsets.only(left: 5, bottom: 5),
                        child: Text(
                          '/100',
                          style: TextStyle(
                            fontSize: 17,
                            color: Colors.black38,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _getScoreMessage(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _getScoreColor(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String unit,
    required String status,
    required bool isExpanded,
    required VoidCallback onTap,
  }) {
    final bool hasData = value != '--/--' && value != '--';
    final Color statusColor = _getStatusColor(status);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isExpanded ? _teal : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: _teal.withValues(alpha: 0.07),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  color: hasData ? Colors.black : Colors.black26,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              unit,
              style: const TextStyle(color: Colors.black45, fontSize: 11),
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 200),
              firstChild: const SizedBox(height: 10),
              secondChild: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  const Divider(height: 1, color: Color(0xFFE0F2EF)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        status,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Today, ${_formattedDate()}',
                    style: const TextStyle(fontSize: 10, color: Colors.black38),
                  ),
                ],
              ),
              crossFadeState: isExpanded && hasData
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AnimatedRotation(
                  duration: const Duration(milliseconds: 200),
                  turns: isExpanded ? 0.5 : 0,
                  child: const Icon(
                    Icons.keyboard_arrow_down,
                    color: _teal,
                    size: 20,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formattedDate() {
    final now = DateTime.now();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[now.month - 1]} ${now.day}';
  }

  Widget _buildAIInsightCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _teal.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Insight',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 5),
                if (_aiInsight.isEmpty)
                  Row(
                    children: List.generate(
                      3,
                      (i) =>
                          _PulsingDot(delay: Duration(milliseconds: i * 200)),
                    ),
                  )
                else
                  Text(
                    _aiInsight,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                      height: 1.6,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    setState(() => _aiInsight = '');
                    final insight = await _generateAIInsight(
                      _bpValue,
                      _bsValue,
                    );
                    if (mounted) setState(() => _aiInsight = insight);
                  },
                  child: const Text(
                    '↻ Refresh insight',
                    style: TextStyle(
                      fontSize: 11,
                      color: _teal,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            height: 75,
            width: 75,
            decoration: const BoxDecoration(
              color: Color.fromARGB(255, 255, 255, 255),
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: Image.asset(
                'assests/images/AI bot.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAB() {
    return GestureDetector(
      onTap: _navigateToAddReading,
      child: Container(
        height: 58,
        width: 58,
        decoration: BoxDecoration(
          color: _teal,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _teal.withValues(alpha: 0.4),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
    );
  }

  Widget _buildBottomNav() {
    return BottomAppBar(
      elevation: 8,
      color: Colors.white,
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      child: SizedBox(
        height: 64,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(
              icon: Icons.home_outlined,
              selectedIcon: Icons.home,
              label: 'Home',
              selected: true,
              onTap: () {},
            ),
            _navItem(
              icon: Icons.history_outlined,
              selectedIcon: Icons.history,
              label: 'History',
              onTap: _navigateToHistory,
            ),
            const SizedBox(width: 48),
            _navItem(
              icon: Icons.support_agent_outlined,
              selectedIcon: Icons.support_agent,
              label: 'VitalMate AI',
              onTap: _navigateToChat,
            ),
            _navItem(
              icon: Icons.person_outline,
              selectedIcon: Icons.person,
              label: 'Profile',
              onTap: _navigateToProfile,
            ),
          ],
        ),
      ),
    );
  }

  Widget _navItem({
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required VoidCallback onTap,
    bool selected = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? selectedIcon : icon,
              size: 24,
              color: selected ? Colors.black : Colors.black45,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? Colors.black : Colors.black45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Duration delay;
  const _PulsingDot({required this.delay});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
    _anim = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FadeTransition(
        opacity: _anim,
        child: Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Color(0xFF24A593),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}