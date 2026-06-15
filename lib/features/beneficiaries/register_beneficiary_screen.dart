import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/biometric_service.dart';
import '../auth/current_profile_service.dart';
import '../programs/program_service.dart';
import '../questionnaires/questionnaire_service.dart';
import 'beneficiary_draft.dart';
import 'beneficiary_service.dart';
import 'fingerprint_enrollment_screen.dart';

class RegisterBeneficiaryScreen extends StatefulWidget {
  const RegisterBeneficiaryScreen({super.key});

  @override
  State<RegisterBeneficiaryScreen> createState() =>
      _RegisterBeneficiaryScreenState();
}

class _RegisterBeneficiaryScreenState extends State<RegisterBeneficiaryScreen> {
  static const Color _formAccentColor = Color(0xFF673AB7);
  static const Color _formBackgroundColor = Color(0xFFF6F6F8);
  static const Color _formBorderColor = Color(0xFFE0E0E0);

  final profileService = CurrentProfileService();
  final programService = ProgramService();
  final beneficiaryService = BeneficiaryService();
  final questionnaireService = QuestionnaireService();
  final imagePicker = ImagePicker();
  final BiometricService _biometricService = BiometricService();

  final fullNameController = TextEditingController();
  final nationalIdController = TextEditingController();
  final phoneController = TextEditingController();
  final householdSizeController = TextEditingController();
  final addressController = TextEditingController();
  final notesController = TextEditingController();

  Map<String, dynamic>? profile;
  List<Map<String, dynamic>> programs = [];

  String? selectedProgramId;
  String? selectedGender;
  DateTime? selectedDateOfBirth;

  Map<String, dynamic>? questionnaire;
  List<Map<String, dynamic>> questions = [];
  final Map<String, dynamic> questionnaireAnswers = {};

  File? selectedPhoto;
  String? _beneficiaryId;
  String? _uploadedPhotoUrl;

  bool loading = true;
  bool _savingDraft = false;
  bool loadingQuestions = false;
  String? error;

  String? get _tenantId => profile?['tenant_id']?.toString();

  String? get _locationId => profile?['location_id']?.toString();

  String? get formattedDateOfBirth {
    if (selectedDateOfBirth == null) return null;

    final year = selectedDateOfBirth!.year.toString().padLeft(4, '0');
    final month = selectedDateOfBirth!.month.toString().padLeft(2, '0');
    final day = selectedDateOfBirth!.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  @override
  void initState() {
    super.initState();
    loadInitialData();
  }

  @override
  void dispose() {
    fullNameController.dispose();
    nationalIdController.dispose();
    phoneController.dispose();
    householdSizeController.dispose();
    addressController.dispose();
    notesController.dispose();
    super.dispose();
  }

  Future<void> pickPhoto() async {
    final pickedFile = await imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      maxWidth: 900,
    );

    if (pickedFile == null) return;

    setState(() {
      selectedPhoto = File(pickedFile.path);
      _uploadedPhotoUrl = null;
    });
  }

  Future<void> pickDateOfBirth() async {
    final now = DateTime.now();

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
    );

    if (pickedDate == null) return;

    setState(() {
      selectedDateOfBirth = pickedDate;
    });
  }

  Future<void> loadInitialData() async {
    try {
      final currentProfile = await profileService.getCurrentProfile();

      if (currentProfile == null) {
        if (!mounted) return;
        setState(() {
          error = 'No profile found for this logged-in user.';
          loading = false;
        });
        return;
      }

      final tenantId = currentProfile['tenant_id'] as String?;
      final locationId = currentProfile['location_id'] as String?;

      if (tenantId == null || locationId == null) {
        if (!mounted) return;
        setState(() {
          error = 'Profile is missing tenant_id or location_id.';
          loading = false;
        });
        return;
      }

      final assignedPrograms = await programService.getAssignedPrograms(
        tenantId: tenantId,
        locationId: locationId,
      );

      if (!mounted) return;

      setState(() {
        profile = currentProfile;
        programs = assignedPrograms;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  Future<void> loadQuestionnaireForProgram(String programId) async {
    if (profile == null) return;

    setState(() {
      loadingQuestions = true;
      questionnaire = null;
      questions = [];
      questionnaireAnswers.clear();
    });

    try {
      final activeQuestionnaire = await questionnaireService
          .getActiveQuestionnaire(
            programId: programId,
            tenantId: profile!['tenant_id'],
          );

      if (activeQuestionnaire == null) {
        if (!mounted) return;
        setState(() {
          loadingQuestions = false;
        });
        return;
      }

      final loadedQuestions = await questionnaireService.getQuestions(
        questionnaireId: activeQuestionnaire['id'],
        tenantId: profile!['tenant_id'],
      );

      if (!mounted) return;

      setState(() {
        questionnaire = activeQuestionnaire;
        questions = loadedQuestions;
        loadingQuestions = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loadingQuestions = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load questionnaire: $e')),
      );
    }
  }

  Widget buildQuestionField(Map<String, dynamic> question) {
    final questionId = question['id']?.toString() ?? '';
    final questionText = question['question_text']?.toString() ?? 'Question';
    final questionType = question['question_type']?.toString() ?? 'text';
    final required = question['required'] == true;
    final normalizedType = questionType.toLowerCase();
    final options = _questionOptions(question);

    Widget answerField;

    if (['number', 'integer', 'decimal'].contains(normalizedType)) {
      answerField = _buildTextAnswerField(
        questionId: questionId,
        questionType: questionType,
        keyboardType: TextInputType.number,
      );
    } else if (['yes_no', 'boolean', 'bool'].contains(normalizedType)) {
      answerField = _buildRadioAnswerField(
        questionId: questionId,
        options: const ['Yes', 'No'],
      );
    } else if (normalizedType == 'date') {
      answerField = _buildTextAnswerField(
        questionId: questionId,
        questionType: questionType,
        hintText: 'YYYY-MM-DD',
        keyboardType: TextInputType.datetime,
      );
    } else if (options.isNotEmpty) {
      answerField = normalizedType == 'dropdown'
          ? _buildDropdownAnswerField(questionId: questionId, options: options)
          : _buildRadioAnswerField(questionId: questionId, options: options);
    } else {
      answerField = _buildTextAnswerField(
        questionId: questionId,
        questionType: questionType,
      );
    }

    return _buildGoogleFormQuestionCard(
      questionText: questionText,
      required: required,
      answerField: answerField,
    );
  }

  Widget _buildGoogleFormQuestionCard({
    required String questionText,
    required bool required,
    required Widget answerField,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _formBorderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: const TextStyle(
                color: Color(0xFF202124),
                fontSize: 16,
                height: 1.35,
              ),
              children: [
                TextSpan(text: questionText),
                if (required)
                  const TextSpan(
                    text: ' *',
                    style: TextStyle(color: Color(0xFFD93025)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          answerField,
        ],
      ),
    );
  }

  Widget _buildTextAnswerField({
    required String questionId,
    required String questionType,
    String hintText = 'Your answer',
    TextInputType? keyboardType,
  }) {
    return TextField(
      keyboardType: keyboardType ?? _keyboardTypeForQuestion(questionType),
      maxLines: _maxLinesForQuestion(questionType),
      decoration: _googleFormInputDecoration(hintText),
      onChanged: (value) {
        questionnaireAnswers[questionId] = value;
      },
    );
  }

  Widget _buildRadioAnswerField({
    required String questionId,
    required List<String> options,
  }) {
    final groupValue = questionnaireAnswers[questionId]?.toString();

    return RadioGroup<String>(
      groupValue: groupValue,
      onChanged: (value) {
        setState(() {
          questionnaireAnswers[questionId] = value;
        });
      },
      child: Column(
        children: options.map((option) {
          return RadioListTile<String>(
            value: option,
            title: Text(
              option,
              style: const TextStyle(fontSize: 15, color: Color(0xFF202124)),
            ),
            activeColor: _formAccentColor,
            contentPadding: EdgeInsets.zero,
            dense: true,
            visualDensity: VisualDensity.compact,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDropdownAnswerField({
    required String questionId,
    required List<String> options,
  }) {
    final selectedAnswer = questionnaireAnswers[questionId]?.toString();

    return DropdownButtonFormField<String>(
      initialValue: options.contains(selectedAnswer) ? selectedAnswer : null,
      isExpanded: true,
      decoration: _googleFormInputDecoration('Choose'),
      items: options.map((option) {
        return DropdownMenuItem<String>(value: option, child: Text(option));
      }).toList(),
      onChanged: (value) {
        setState(() {
          questionnaireAnswers[questionId] = value;
        });
      },
    );
  }

  InputDecoration _googleFormInputDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFF70757A)),
      isDense: true,
      contentPadding: const EdgeInsets.only(top: 8, bottom: 8),
      border: const UnderlineInputBorder(),
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Color(0xFFBDBDBD)),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: _formAccentColor, width: 2),
      ),
    );
  }

  Widget _buildQuestionnaireHeader() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _formBorderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 8, color: _formAccentColor),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    questionnaire!['title'] ?? 'Questionnaire',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF202124),
                    ),
                  ),
                  if (questionnaire!['description'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        questionnaire!['description'].toString(),
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.35,
                          color: Color(0xFF3C4043),
                        ),
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

  List<String> _questionOptions(Map<String, dynamic> question) {
    final rawOptions =
        question['options'] ??
        question['choices'] ??
        question['answer_options'] ??
        question['possible_answers'] ??
        question['metadata'];

    final options = _normalizeOptionValues(rawOptions);
    return options.toSet().toList();
  }

  List<String> _normalizeOptionValues(Object? rawOptions) {
    if (rawOptions == null) {
      return [];
    }

    if (rawOptions is List) {
      return rawOptions
          .map(_optionLabel)
          .where((option) => option.isNotEmpty)
          .toList();
    }

    if (rawOptions is Map) {
      for (final key in const ['options', 'choices', 'items', 'values']) {
        if (rawOptions[key] != null) {
          return _normalizeOptionValues(rawOptions[key]);
        }
      }

      return rawOptions.values
          .map(_optionLabel)
          .where((option) => option.isNotEmpty)
          .toList();
    }

    if (rawOptions is String) {
      final value = rawOptions.trim();

      if (value.isEmpty) {
        return [];
      }

      try {
        return _normalizeOptionValues(jsonDecode(value));
      } on FormatException {
        return value
            .split(RegExp(r'[\n,;]'))
            .map((option) => option.trim())
            .where((option) => option.isNotEmpty)
            .toList();
      }
    }

    return [];
  }

  String _optionLabel(Object? option) {
    if (option == null) {
      return '';
    }

    if (option is Map) {
      for (final key in const ['label', 'text', 'value', 'name', 'title']) {
        final value = option[key];

        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString().trim();
        }
      }

      return '';
    }

    return option.toString().trim();
  }

  TextInputType _keyboardTypeForQuestion(String questionType) {
    switch (questionType.toLowerCase()) {
      case 'number':
      case 'integer':
      case 'decimal':
        return TextInputType.number;
      case 'phone':
        return TextInputType.phone;
      case 'email':
        return TextInputType.emailAddress;
      case 'text':
      case 'textarea':
      case 'short_text':
      case 'long_text':
      default:
        return TextInputType.text;
    }
  }

  int _maxLinesForQuestion(String questionType) {
    switch (questionType.toLowerCase()) {
      case 'textarea':
      case 'long_text':
        return 4;
      default:
        return 1;
    }
  }

  bool _validateBeneficiaryForm() {
    if (selectedProgramId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select a program')));
      return false;
    }

    if (fullNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter full name')));
      return false;
    }

    if (_tenantId == null || _locationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile is missing tenant or location')),
      );
      return false;
    }

    if (selectedPhoto == null && _uploadedPhotoUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Capture beneficiary photo')),
      );
      return false;
    }

    return true;
  }

  Future<String> _createBeneficiaryIfNeeded() async {
    if (_beneficiaryId != null) {
      return _beneficiaryId!;
    }

    final user = Supabase.instance.client.auth.currentUser!;

    final draft = BeneficiaryDraft(
      fullName: fullNameController.text.trim(),
      nationalId: nationalIdController.text.trim(),
      phone: phoneController.text.trim(),
      programId: selectedProgramId!,
      tenantId: _tenantId!,
      locationId: _locationId!,
      createdBy: user.id,
      registeredBy: user.id,
      gender: selectedGender,
      dateOfBirth: formattedDateOfBirth,
      householdSize: int.tryParse(householdSizeController.text.trim()),
      address: addressController.text.trim().isEmpty
          ? null
          : addressController.text.trim(),
      notes: notesController.text.trim().isEmpty
          ? null
          : notesController.text.trim(),
    );

    final beneficiaryId = await beneficiaryService.registerBeneficiary(draft);

    if (beneficiaryId == null) {
      throw Exception(
        'Beneficiary was saved offline and cannot enroll biometrics yet',
      );
    }

    _beneficiaryId = beneficiaryId;
    return beneficiaryId;
  }

  Future<String?> _uploadBeneficiaryPhoto({
    required String beneficiaryId,
  }) async {
    if (selectedPhoto == null) {
      return null;
    }

    final photoPath = await beneficiaryService.uploadBeneficiaryPhoto(
      photoFile: selectedPhoto!,
      tenantId: _tenantId!,
      beneficiaryId: beneficiaryId,
    );

    await beneficiaryService.saveBeneficiaryPhotoPath(
      beneficiaryId: beneficiaryId,
      photoPath: photoPath,
    );

    _uploadedPhotoUrl = photoPath;
    return photoPath;
  }

  Future<void> _saveQuestionnaireResponses({
    required String beneficiaryId,
  }) async {
    if (questionnaire == null || selectedProgramId == null) {
      return;
    }

    final user = Supabase.instance.client.auth.currentUser!;

    await questionnaireService.saveQuestionnaireResponse(
      tenantId: _tenantId!,
      questionnaireId: questionnaire!['id'],
      programId: selectedProgramId!,
      beneficiaryId: beneficiaryId,
      submittedBy: user.id,
      answers: questionnaireAnswers,
    );
  }

  Future<void> _saveDetailsAndMoveToFingerprint() async {
    if (!_validateBeneficiaryForm()) {
      return;
    }

    try {
      setState(() {
        _savingDraft = true;
      });

      final beneficiaryId = await _createBeneficiaryIfNeeded();

      await _saveQuestionnaireResponses(beneficiaryId: beneficiaryId);

      _uploadedPhotoUrl ??= await _uploadBeneficiaryPhoto(
        beneficiaryId: beneficiaryId,
      );

      if (_uploadedPhotoUrl != null) {
        await _biometricService.enrollFacePhoto(
          beneficiaryId: beneficiaryId,
          tenantId: _tenantId!,
          photoUrl: _uploadedPhotoUrl!,
        );
      }

      if (!mounted) return;

      setState(() {
        _savingDraft = false;
      });

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FingerprintEnrollmentScreen(
            beneficiaryId: beneficiaryId,
            tenantId: _tenantId!,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save details: $e')));
    } finally {
      if (mounted && _savingDraft) {
        setState(() {
          _savingDraft = false;
        });
      }
    }
  }

  Widget _buildBeneficiaryExtraFields() {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          initialValue: selectedGender,
          decoration: const InputDecoration(
            labelText: 'Gender',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'Male', child: Text('Male')),
            DropdownMenuItem(value: 'Female', child: Text('Female')),
            DropdownMenuItem(value: 'Other', child: Text('Other')),
          ],
          onChanged: (value) {
            setState(() {
              selectedGender = value;
            });
          },
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: pickDateOfBirth,
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Date of Birth',
              border: OutlineInputBorder(),
            ),
            child: Text(formattedDateOfBirth ?? 'Select date'),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: householdSizeController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Household Size',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: addressController,
          decoration: const InputDecoration(
            labelText: 'Address',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: notesController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Notes',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Register Beneficiary')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Failed to load registration data:\n\n$error',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _formBackgroundColor,
      appBar: AppBar(title: const Text('Register Beneficiary')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedProgramId,
                decoration: const InputDecoration(
                  labelText: 'Program',
                  border: OutlineInputBorder(),
                ),
                items: programs.map((program) {
                  return DropdownMenuItem<String>(
                    value: program['id'],
                    child: Text(program['name'] ?? 'Unnamed Program'),
                  );
                }).toList(),
                onChanged: (value) async {
                  setState(() {
                    selectedProgramId = value;
                  });

                  if (value != null) {
                    await loadQuestionnaireForProgram(value);
                  }
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: fullNameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nationalIdController,
                decoration: const InputDecoration(
                  labelText: 'National ID',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              _buildBeneficiaryExtraFields(),
              const SizedBox(height: 24),
              if (loadingQuestions)
                const Center(child: CircularProgressIndicator()),
              if (!loadingQuestions && questionnaire != null) ...[
                _buildQuestionnaireHeader(),
                const SizedBox(height: 12),
                ...questions.map(buildQuestionField),
              ],
              if (!loadingQuestions &&
                  selectedProgramId != null &&
                  questionnaire == null)
                const Text(
                  'No published questionnaire found for this program.',
                  style: TextStyle(color: Colors.orange),
                ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: pickPhoto,
                icon: const Icon(Icons.camera_alt),
                label: Text(
                  selectedPhoto == null
                      ? 'Capture Beneficiary Photo'
                      : 'Retake Photo',
                ),
              ),
              if (selectedPhoto != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    selectedPhoto!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: _savingDraft ? null : _saveDetailsAndMoveToFingerprint,
            icon: const Icon(Icons.save),
            label: Text(
              _savingDraft
                  ? 'Saving...'
                  : 'Save Details & Continue to Fingerprint',
            ),
          ),
        ),
      ),
    );
  }
}
