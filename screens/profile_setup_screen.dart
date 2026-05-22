import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import '../database/db_helper.dart';
import '../widgets/animated_health_background.dart';
import 'health_information_setup_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();

  Uint8List? _profileImageBytes;
  String? _selectedGender;
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
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _showProfileImageOptions() async {
    final action = await showModalBottomSheet<ImageSource?>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Gallery'),
                  onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: const Text('Camera'),
                  onTap: () => Navigator.pop(ctx, ImageSource.camera),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (action == null || !mounted) return;

    final pickedFile = await _imagePicker.pickImage(
      source: action,
      imageQuality: 85,
    );

    if (pickedFile == null || !mounted) return;

    final cropped = await ImageCropper().cropImage(
      sourcePath: pickedFile.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Image',
          toolbarColor: const Color(0xFF22B8A7),
          toolbarWidgetColor: Colors.white,
          lockAspectRatio: false,
        ),
        IOSUiSettings(title: 'Crop Image'),
      ],
    );

    if (cropped == null || !mounted) return;

    final bytes = await File(cropped.path).readAsBytes();
    setState(() {
      _profileImageBytes = bytes;
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select gender')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final String? profileImageDataUri;
      if (_profileImageBytes != null) {
        final base64Str = base64Encode(_profileImageBytes!);
        // Store as a data URI so we can render it later without file storage.
        profileImageDataUri = 'data:image/jpeg;base64,$base64Str';
      } else {
        profileImageDataUri = null;
      }

      final userId = await DBHelper().insertUserProfile(
        fullName: _nameController.text.trim(),
        age: int.tryParse(_ageController.text.trim()),
        gender: _selectedGender,
        heightCm: double.tryParse(_heightController.text.trim()),
        weightKg: double.tryParse(_weightController.text.trim()),
        profileImageUrl: profileImageDataUri,
      );

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => HealthInformationSetupScreen(userId: userId),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save profile. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardOpen = bottomInset > 0;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFFF7F7F7),
      body: Stack(
        children: [
          const Positioned.fill(
            child: AnimatedHealthBackground(opacity: 0.48),
          ),
          SafeArea(
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Center(
                child: SingleChildScrollView(
                  physics: isKeyboardOpen
                      ? const BouncingScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 26,
                      vertical: 12,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 430),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 6),

                            const Text(
                              'Create Your Profile',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Colors.black,
                              ),
                            ),

                            const SizedBox(height: 4),

                            const Text(
                              "Let's get to know you better",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                                height: 1.4,
                              ),
                            ),

                            const SizedBox(height: 16),

                            _ProfileAvatar(
                              imageBytes: _profileImageBytes,
                              onTap: _showProfileImageOptions,
                            ),

                            const SizedBox(height: 16),

                            _ModernField(
                              icon: Icons.person_outline,
                              label: 'NAME',
                              hintText: 'Enter your full name',
                              controller: _nameController,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Enter your name';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 12),

                            _ModernField(
                              icon: Icons.cake_outlined,
                              label: 'AGE',
                              hintText: 'Enter your age',
                              controller: _ageController,
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Enter age';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 12),

                            _DropdownField(
                              icon: Icons.transgender,
                              label: 'GENDER',
                              value: _selectedGender,
                              onChanged: (value) {
                                setState(() => _selectedGender = value);
                              },
                            ),

                            const SizedBox(height: 12),

                            _ModernField(
                              icon: Icons.height,
                              label: 'HEIGHT',
                              hintText: '160 cm',
                              controller: _heightController,
                              keyboardType: TextInputType.number,
                            ),

                            const SizedBox(height: 12),

                            _ModernField(
                              icon: Icons.monitor_weight_outlined,
                              label: 'WEIGHT',
                              hintText: '50 kg',
                              controller: _weightController,
                              keyboardType: TextInputType.number,
                            ),

                            const SizedBox(height: 24),

                            // Button — matches Get Started exactly
                            SizedBox(
                              width: double.infinity,
                              height: 45,
                              child: ElevatedButton(
                                onPressed: _isSaving ? null : _saveProfile,
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

                            const SizedBox(height: 14),

                            const _ProgressDots(),

                            const SizedBox(height: 10),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _ModernField extends StatelessWidget {
  final IconData icon;
  final String label;
  final String hintText;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _ModernField({
    required this.icon,
    required this.label,
    required this.hintText,
    required this.controller,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 14, right: 12),
          child: Icon(icon, size: 24, color: Colors.black87),
        ),
        Expanded(
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            validator: validator,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
            decoration: InputDecoration(
              labelText: label,
              hintText: hintText,
              floatingLabelBehavior: FloatingLabelBehavior.never,
              labelStyle: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.black54,
                letterSpacing: 1.5,
              ),
              hintStyle: const TextStyle(
                fontSize: 14,
                color: Colors.black38,
                fontStyle: FontStyle.italic,
              ),
              filled: true,
              fillColor: const Color(0xFFEFEFEF),
              contentPadding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Color(0xFF22B8A7),
                  width: 1.5,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.red),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DropdownField extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;

  const _DropdownField({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 14, right: 12),
          child: Icon(icon, size: 24, color: Colors.black87),
        ),
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: value,
            onChanged: onChanged,
            decoration: InputDecoration(
              labelText: label,
              floatingLabelBehavior: FloatingLabelBehavior.never,
              labelStyle: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.black54,
                letterSpacing: 1.5,
              ),
              filled: true,
              fillColor: const Color(0xFFEFEFEF),
              contentPadding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Color(0xFF22B8A7),
                  width: 1.5,
                ),
              ),
            ),
            hint: const Text(
              'Select gender',
              style: TextStyle(
                fontSize: 14,
                color: Colors.black38,
                fontStyle: FontStyle.italic,
              ),
            ),
            items: const [
              DropdownMenuItem(value: 'Male', child: Text('Male')),
              DropdownMenuItem(value: 'Female', child: Text('Female')),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final Uint8List? imageBytes;
  final VoidCallback onTap;

  const _ProfileAvatar({required this.imageBytes, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFE8E8E8),
              border: Border.all(
                color: const Color(0xFF22B8A7).withValues(alpha: 0.35),
                width: 2,
              ),
            ),
            child: ClipOval(
              child: imageBytes == null
                  ? const Icon(Icons.person, size: 44, color: Colors.black38)
                  : Image.memory(imageBytes!, fit: BoxFit.cover),
            ),
          ),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF22B8A7),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 8,
                ),
              ],
            ),
            child: const Icon(Icons.camera_alt, color: Colors.white, size: 17),
          ),
        ],
      ),
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
        final isActive = index == 0;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 26 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: isActive
                ? const Color(0xFF22B8A7)
                : const Color(0xFFD7D7D7),
          ),
        );
      }),
    );
  }
}