import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/db_helper.dart';

class AddMeasurementScreen extends StatefulWidget {
  const AddMeasurementScreen({super.key});

  @override
  State<AddMeasurementScreen> createState() => _AddMeasurementScreenState();
}

class _AddMeasurementScreenState extends State<AddMeasurementScreen>
    with SingleTickerProviderStateMixin {
  static const Color _teal = Color(0xFF24A593);
  static const Color _scaffoldBg = Color(0xFFF5F5F5);

  final DBHelper _db = DBHelper();

  late TabController _tabController;
  int _activeTab = 0;

  int _systolic = 120;
  int _diastolic = 80;
  int _pulse = 72;

  int _bloodSugar = 110;
  String _measurementType = 'Fasting';
  final List<String> _measurementTypes = ['Fasting', 'Post-meal', 'Random'];

  DateTime _selectedDateTime = DateTime.now();
  bool _isSaving = false;

  static const int _minSystolic = 60, _maxSystolic = 250;
  static const int _minDiastolic = 40, _maxDiastolic = 150;
  static const int _minPulse = 30, _maxPulse = 220;
  static const int _minSugar = 20, _maxSugar = 600;

  late final TextEditingController _systolicCtrl;
  late final TextEditingController _diastolicCtrl;
  late final TextEditingController _pulseCtrl;
  late final TextEditingController _sugarCtrl;

  late final FocusNode _systolicFocus;
  late final FocusNode _diastolicFocus;
  late final FocusNode _pulseFocus;
  late final FocusNode _sugarFocus;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() {
        if (!_tabController.indexIsChanging) {
          setState(() => _activeTab = _tabController.index);
        }
      });

    _systolicCtrl = TextEditingController(text: _systolic.toString());
    _diastolicCtrl = TextEditingController(text: _diastolic.toString());
    _pulseCtrl = TextEditingController(text: _pulse.toString());
    _sugarCtrl = TextEditingController(text: _bloodSugar.toString());

    _systolicFocus = FocusNode()
      ..addListener(
        () => _onFocusLost(
          _systolicFocus,
          _systolicCtrl,
          _minSystolic,
          _maxSystolic,
          (v) => setState(() => _systolic = v),
        ),
      );
    _diastolicFocus = FocusNode()
      ..addListener(
        () => _onFocusLost(
          _diastolicFocus,
          _diastolicCtrl,
          _minDiastolic,
          _maxDiastolic,
          (v) => setState(() => _diastolic = v),
        ),
      );
    _pulseFocus = FocusNode()
      ..addListener(
        () => _onFocusLost(
          _pulseFocus,
          _pulseCtrl,
          _minPulse,
          _maxPulse,
          (v) => setState(() => _pulse = v),
        ),
      );
    _sugarFocus = FocusNode()
      ..addListener(
        () => _onFocusLost(
          _sugarFocus,
          _sugarCtrl,
          _minSugar,
          _maxSugar,
          (v) => setState(() => _bloodSugar = v),
        ),
      );
  }

  void _onFocusLost(
    FocusNode node,
    TextEditingController ctrl,
    int min,
    int max,
    void Function(int) setter,
  ) {
    if (!node.hasFocus) {
      final parsed = int.tryParse(ctrl.text) ?? min;
      final clamped = parsed.clamp(min, max);
      setter(clamped);
      ctrl.text = clamped.toString();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _systolicCtrl.dispose();
    _diastolicCtrl.dispose();
    _pulseCtrl.dispose();
    _sugarCtrl.dispose();
    _systolicFocus.dispose();
    _diastolicFocus.dispose();
    _pulseFocus.dispose();
    _sugarFocus.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(
          ctx,
        ).copyWith(colorScheme: const ColorScheme.light(primary: _teal)),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
      builder: (ctx, child) => Theme(
        data: Theme.of(
          ctx,
        ).copyWith(colorScheme: const ColorScheme.light(primary: _teal)),
        child: child!,
      ),
    );
    if (time == null || !mounted) return;

    setState(() {
      _selectedDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  String _formattedDateTime() {
    final d = _selectedDateTime;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final h = d.hour > 12
        ? d.hour - 12
        : d.hour == 0
        ? 12
        : d.hour;
    final m = d.minute.toString().padLeft(2, '0');
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    return '${d.day} ${months[d.month - 1]} ${d.year}, $h.$m $ampm';
  }

  Future<void> _saveReading() async {
    FocusScope.of(context).unfocus();
    await Future.delayed(const Duration(milliseconds: 80));

    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final user = await _db.getFirstUser();
      if (user == null) {
        _showSnack('No user profile found. Please set up your profile first.');
        setState(() => _isSaving = false);
        return;
      }

      final userId = user['user_id'] as int;
      final measuredAt = _selectedDateTime.toIso8601String();

      if (_activeTab == 0) {
        await _db.insertMeasurement({
          'user_id': userId,
          'measurement_type': 'Blood Pressure',
          'value_1': _systolic.toDouble(),
          'value_2': _diastolic.toDouble(),
          'value_3': _pulse.toDouble(),
          'is_fasting': 0,
          'measured_at': measuredAt,
        });
      } else {
        await _db.insertMeasurement({
          'user_id': userId,
          'measurement_type': 'Blood Sugar',
          'value_1': _bloodSugar.toDouble(),
          'value_2': null,
          'value_3': null,
          'is_fasting': _measurementType == 'Fasting' ? 1 : 0,
          'measured_at': measuredAt,
        });
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('Save error: $e');
      _showSnack('Failed to save reading. Please try again.');
      setState(() => _isSaving = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFF333333)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _scaffoldBg,
      appBar: AppBar(
        toolbarHeight: 70,
        backgroundColor: _scaffoldBg,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Padding(
          padding: EdgeInsets.only(top: 25),
          child: Text(
            'Add New Reading',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Column(
          children: [
            _buildTabToggle(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [_buildBPTab(), _buildBSTab()],
              ),
            ),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildTabToggle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            _tabChip(label: 'Blood Pressure', index: 0),
            _tabChip(label: 'Blood Sugar', index: 1),
          ],
        ),
      ),
    );
  }

  Widget _tabChip({required String label, required int index}) {
    final selected = _activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          _tabController.animateTo(index);
          setState(() => _activeTab = index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: selected ? _teal : Colors.transparent,
            borderRadius: BorderRadius.circular(26),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : Colors.black54,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceImage(String assetPath) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: SizedBox(
        height: 150,
        width: double.infinity,
        child: FittedBox(fit: BoxFit.contain, child: Image.asset(assetPath)),
      ),
    );
  }

  Widget _buildBPTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Column(
        children: [
          _buildDeviceImage('assests/images/Blood pressure.png'),
          const SizedBox(height: 16),
          _buildStepperField(
            label: 'Systolic',
            unit: 'mmHg',
            value: _systolic,
            min: _minSystolic,
            max: _maxSystolic,
            controller: _systolicCtrl,
            focusNode: _systolicFocus,
            onChanged: (v) => setState(() => _systolic = v),
          ),
          _buildDivider(),
          _buildStepperField(
            label: 'Diastolic',
            unit: 'mmHg',
            value: _diastolic,
            min: _minDiastolic,
            max: _maxDiastolic,
            controller: _diastolicCtrl,
            focusNode: _diastolicFocus,
            onChanged: (v) => setState(() => _diastolic = v),
          ),
          _buildDivider(),
          _buildStepperField(
            label: 'Pulse',
            unit: 'bpm',
            value: _pulse,
            min: _minPulse,
            max: _maxPulse,
            controller: _pulseCtrl,
            focusNode: _pulseFocus,
            onChanged: (v) => setState(() => _pulse = v),
          ),
          _buildDivider(),
          _buildDateTimeField(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildBSTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Column(
        children: [
          _buildDeviceImage('assests/images/Blood sugar.png'),
          const SizedBox(height: 16),
          _buildStepperField(
            label: 'Blood Sugar',
            unit: 'mg/dL',
            value: _bloodSugar,
            min: _minSugar,
            max: _maxSugar,
            controller: _sugarCtrl,
            focusNode: _sugarFocus,
            onChanged: (v) => setState(() => _bloodSugar = v),
          ),
          _buildDivider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Measurement Type',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFE0E0E0)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _measurementType,
                      isExpanded: true,
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.black54,
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                      items: _measurementTypes
                          .map(
                            (t) => DropdownMenuItem(value: t, child: Text(t)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _measurementType = v!),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildDivider(),
          _buildDateTimeField(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildStepperField({
    required String label,
    required String unit,
    required int value,
    required int min,
    required int max,
    required TextEditingController controller,
    required FocusNode focusNode,
    required void Function(int) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                TextSpan(
                  text: '  ($unit)',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.black45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (text) {
                    final parsed = int.tryParse(text);
                    if (parsed != null) {
                      setState(() => onChanged(parsed));
                    }
                  },
                  onSubmitted: (text) {
                    final parsed = int.tryParse(text) ?? min;
                    final clamped = parsed.clamp(min, max);
                    onChanged(clamped);
                    controller.text = clamped.toString();
                  },
                ),
              ),
              _stepBtn(
                icon: Icons.remove,
                onTap: value > min
                    ? () {
                        final next = value - 1;
                        onChanged(next);
                        controller
                          ..text = next.toString()
                          ..selection = TextSelection.collapsed(
                            offset: next.toString().length,
                          );
                      }
                    : null,
              ),
              const SizedBox(width: 10),
              _stepBtn(
                icon: Icons.add,
                onTap: value < max
                    ? () {
                        final next = value + 1;
                        onChanged(next);
                        controller
                          ..text = next.toString()
                          ..selection = TextSelection.collapsed(
                            offset: next.toString().length,
                          );
                      }
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepBtn({required IconData icon, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: onTap != null ? Colors.black38 : Colors.black12,
            width: 1.5,
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: onTap != null ? Colors.black87 : Colors.black26,
        ),
      ),
    );
  }

  Widget _buildDateTimeField() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Date & Time',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _pickDateTime,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE0E0E0)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _formattedDateTime(),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 20,
                    color: Colors.black45,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() => const Divider(height: 1, color: Color(0xFFEEEEEE));

  Widget _buildSaveButton() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: SizedBox(
          width: 200,
          height: 45,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveReading,
            style: ElevatedButton.styleFrom(
              backgroundColor: _teal,
              disabledBackgroundColor: _teal.withValues(alpha: 0.5),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
