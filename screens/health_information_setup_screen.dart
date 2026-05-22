import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/db_helper.dart';
import '../widgets/animated_health_background.dart';
import 'registration_success_screen.dart';

class HealthInformationSetupScreen extends StatefulWidget {
  final int userId;

  const HealthInformationSetupScreen({super.key, required this.userId});

  @override
  State<HealthInformationSetupScreen> createState() =>
      _HealthInformationSetupScreenState();
}

class _HealthInformationSetupScreenState
    extends State<HealthInformationSetupScreen> {

  // Each item carries a display label and the structured medicationContext
  // value stored in the DB. This replaces the old free-text dropdown that
  // collapsed everything into two booleans and threw away the medication info.
  static const List<_ConditionOption> _conditionOptions = [
    _ConditionOption(
      label: 'No relevant conditions or medications',
      medicationContext: 'none',
      hasDiabetes: false,
      hasHypertension: false,
    ),
    _ConditionOption(
      label: 'Taking blood pressure (hypertension) medications',
      medicationContext: 'bp_meds',
      hasDiabetes: false,
      hasHypertension: true,
    ),
    _ConditionOption(
      label: 'Taking diabetes medications',
      medicationContext: 'diabetes_meds',
      hasDiabetes: true,
      hasHypertension: false,
    ),
    _ConditionOption(
      label: 'Taking both blood pressure & diabetes medications',
      medicationContext: 'both_meds',
      hasDiabetes: true,
      hasHypertension: true,
    ),
    _ConditionOption(
      label: 'Diagnosed with hypertension — not yet on medication',
      medicationContext: 'none',
      hasDiabetes: false,
      hasHypertension: true,
    ),
    _ConditionOption(
      label: 'Diagnosed with diabetes — not yet on medication',
      medicationContext: 'none',
      hasDiabetes: true,
      hasHypertension: false,
    ),
  ];

  _ConditionOption? _selectedOption;

  final TextEditingController _allergiesController = TextEditingController();
  final TextEditingController _existingDiseasesController =
      TextEditingController();
  final TextEditingController _medicationsController = TextEditingController();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }

  @override
  void dispose() {
    _allergiesController.dispose();
    _existingDiseasesController.dispose();
    _medicationsController.dispose();
    super.dispose();
  }

  Future<void> _saveAndNavigate() async {
    if (_allergiesController.text.trim().isEmpty) {
      _showSnack('Please enter your allergies (or type "None").');
      return;
    }
    if (_existingDiseasesController.text.trim().isEmpty) {
      _showSnack('Please enter existing diseases (or type "None").');
      return;
    }
    if (_medicationsController.text.trim().isEmpty) {
      _showSnack('Please enter current medications (or type "None").');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final option = _selectedOption;

      await DBHelper().insertHealthProfile(
        userId: widget.userId,
        hasDiabetes: option?.hasDiabetes ?? false,
        hasHypertension: option?.hasHypertension ?? false,
        // Stores the structured context so the health score engine can
        // apply the correct personalised thresholds.
        medicationContext: option?.medicationContext ?? 'none',
        allergies: _allergiesController.text.trim(),
        existingConditions: _existingDiseasesController.text.trim(),
        medications: _medicationsController.text.trim(),
      );

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => const SuccessScreen(),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      _showSnack('Could not save health information. Please try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: Stack(
        children: [
          const Positioned.fill(
              child: AnimatedHealthBackground(opacity: 0.48)),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bottomInset =
                    MediaQuery.of(context).viewInsets.bottom;
                final minContentHeight =
                    constraints.maxHeight - bottomInset - 48;
                final contentAlignment = bottomInset > 0
                    ? Alignment.topCenter
                    : const Alignment(0, 0.12);

                return SingleChildScrollView(
                  padding:
                      EdgeInsets.fromLTRB(32, 24, 32, 24 + bottomInset),
                  physics: bottomInset > 0
                      ? const AlwaysScrollableScrollPhysics()
                      : const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight:
                          minContentHeight > 0 ? minContentHeight : 0,
                    ),
                    child: Align(
                      alignment: contentAlignment,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 430),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Health Information',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 25,
                                fontWeight: FontWeight.w900,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'This helps personalise your health score',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 40),

                            // Condition / medication dropdown
                            _HealthDropdownField<_ConditionOption>(
                              label: 'Current Condition & Medications',
                              hint: 'Select your situation',
                              value: _selectedOption,
                              items: _conditionOptions,
                              itemLabel: (o) => o.label,
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => _selectedOption = value);
                              },
                            ),

                            const SizedBox(height: 26),
                            _HealthTextField(
                              label: 'Allergies',
                              hint: 'e.g. Penicillin, Peanuts — or type None',
                              controller: _allergiesController,
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 26),
                            _HealthTextField(
                              label: 'Existing Diseases',
                              hint: 'e.g. Kidney disease, Asthma — or None',
                              controller: _existingDiseasesController,
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 26),
                            _HealthTextField(
                              label: 'Current Medications',
                              hint: 'e.g. Metformin 500mg, Losartan 50mg',
                              controller: _medicationsController,
                              textInputAction: TextInputAction.done,
                            ),
                            const SizedBox(height: 48),

                            SizedBox(
                              width: double.infinity,
                              height: 45,
                              child: ElevatedButton(
                                onPressed:
                                    _isSaving ? null : _saveAndNavigate,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF24A593),
                                  disabledBackgroundColor:
                                      const Color(0xFF9FBDB8),
                                  foregroundColor: Colors.white,
                                  disabledForegroundColor: Colors.white,
                                  elevation: 6,
                                  shadowColor: const Color(0xFF156F65),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Text(
                                  _isSaving ? 'Saving...' : 'Next',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 28),
                            const _ProgressDots(),
                          ],
                        ),
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
}

// Option model

class _ConditionOption {
  final String label;
  final String medicationContext; // 'none' | 'bp_meds' | 'diabetes_meds' | 'both_meds'
  final bool hasDiabetes;
  final bool hasHypertension;

  const _ConditionOption({
    required this.label,
    required this.medicationContext,
    required this.hasDiabetes,
    required this.hasHypertension,
  });
}

// Field widgets

class _HealthDropdownField<T> extends StatelessWidget {
  final String label;
  final T? value;
  final String hint;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T?> onChanged;

  const _HealthDropdownField({
    required this.label,
    required this.value,
    required this.hint,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _HealthFieldShell(
      label: label,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF777777)),
          borderRadius: BorderRadius.circular(14),
          hint: Text(
            hint,
            style: const TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: Color(0xFF8D8D8D),
            ),
          ),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Colors.black,
          ),
          items: items
              .map((item) => DropdownMenuItem<T>(
                    value: item,
                    child: Text(
                      itemLabel(item),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _HealthTextField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final TextInputAction? textInputAction;

  const _HealthTextField({
    required this.label,
    required this.hint,
    required this.controller,
    this.textInputAction,
  });

  @override
  Widget build(BuildContext context) {
    return _HealthFieldShell(
      label: label,
      child: TextField(
        controller: controller,
        textInputAction: textInputAction,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: Colors.black,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          isDense: true,
          hintText: hint,
          hintStyle: const TextStyle(
            fontSize: 13,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w400,
            color: Color(0xFF8D8D8D),
          ),
        ),
      ),
    );
  }
}

class _HealthFieldShell extends StatelessWidget {
  final String label;
  final Widget child;

  const _HealthFieldShell({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(height: 30, child: child),
        Container(height: 1, color: const Color(0xFF8A8A8A)),
      ],
    );
  }
}

class _ProgressDots extends StatelessWidget {
  const _ProgressDots();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        final isActive = index == 1;
        return Container(
          width: isActive ? 26 : 9,
          height: 9,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF24A593)
                : const Color(0xFFD7D7D7),
            borderRadius: BorderRadius.circular(20),
          ),
        );
      }),
    );
  }
}