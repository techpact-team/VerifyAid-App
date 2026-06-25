import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/field_app_widgets.dart';
import '../../services/biometric_service.dart';
import '../auth/current_profile_service.dart';
import '../biometrics/face_quality_result.dart';
import '../biometrics/face_scan_service.dart';
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
  static const Color _formAccentColor = AppColors.primary;
  static const Color _formBackgroundColor = AppColors.canvas;
  static const Color _formBorderColor = AppColors.border;
  static const bool _faceScanRequired = false;

  final profileService = CurrentProfileService();
  final programService = ProgramService();
  final beneficiaryService = BeneficiaryService();
  final questionnaireService = QuestionnaireService();
  final imagePicker = ImagePicker();
  final faceScanService = FaceScanService();
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

  Map<String, dynamic>? selectedQuestionnaire;
  List<Map<String, dynamic>> questionnaireQuestions = [];
  final Map<String, dynamic> questionnaireAnswers = {};

  File? selectedPhoto;
  File? selectedFacePhoto;
  FaceQualityResult? faceQualityResult;
  String? _beneficiaryId;
  String? _uploadedPhotoUrl;
  String? _uploadedFacePhotoUrl;

  bool loading = true;
  bool _savingDraft = false;
  bool _scanningFace = false;
  bool _questionnaireExpanded = false;
  bool questionnaireLoading = false;
  String? questionnaireError;
  int _registrationFormVersion = 0;
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

    final storedPhoto = await _copyImageToAppStorage(
      pickedFile,
      folderName: 'beneficiary_photos',
      filePrefix: 'beneficiary',
    );

    if (!mounted) return;

    setState(() {
      selectedPhoto = storedPhoto;
      _uploadedPhotoUrl = null;
    });
  }

  Future<void> scanFace() async {
    if (_scanningFace) return;

    setState(() {
      _scanningFace = true;
      faceQualityResult = null;
    });

    try {
      final result = await faceScanService.captureAndValidateFace();

      if (result == null) {
        return;
      }

      if (!mounted) return;

      setState(() {
        faceQualityResult = result.quality;
        selectedFacePhoto = result.isSuccess
            ? File(result.localImagePath!)
            : null;
        _uploadedFacePhotoUrl = null;
      });

      if (!result.isSuccess) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result.quality.message)));
      }
    } catch (e) {
      if (!mounted) return;

      debugPrint('Face scan failed: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Face scan failed. Check logs.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _scanningFace = false;
        });
      }
    }
  }

  Future<File> _copyImageToAppStorage(
    XFile pickedFile, {
    required String folderName,
    required String filePrefix,
  }) async {
    final directory = await getApplicationDocumentsDirectory();
    final targetDirectory = Directory(p.join(directory.path, folderName));

    if (!targetDirectory.existsSync()) {
      await targetDirectory.create(recursive: true);
    }

    final extension = p.extension(pickedFile.path).isEmpty
        ? '.jpg'
        : p.extension(pickedFile.path);
    final targetPath = p.join(
      targetDirectory.path,
      '${filePrefix}_${DateTime.now().millisecondsSinceEpoch}$extension',
    );

    return File(pickedFile.path).copy(targetPath);
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

    if (!mounted) return;

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

      final tenantId = currentProfile['tenant_id']?.toString().trim();
      final locationId = currentProfile['location_id']?.toString().trim();

      if (tenantId == null ||
          tenantId.isEmpty ||
          locationId == null ||
          locationId.isEmpty) {
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

      if (assignedPrograms.isEmpty) {
        if (!mounted) return;
        setState(() {
          error =
              'No programs are assigned to your profile location. Ask an administrator to update your location or assign a program to it.';
          loading = false;
        });
        return;
      }

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
    setState(() {
      questionnaireLoading = true;
      questionnaireError = null;
      selectedQuestionnaire = null;
      questionnaireQuestions = [];
    });

    try {
      final profile = await profileService.getCurrentProfile();

      final tenantId = profile?['tenant_id']?.toString();

      if (tenantId == null || tenantId.isEmpty) {
        throw Exception('Tenant ID missing. Cannot load questionnaire.');
      }

      final questionnaire = await questionnaireService
          .getQuestionnaireForProgram(programId: programId, tenantId: tenantId);

      if (!mounted) {
        return;
      }

      if (questionnaire == null) {
        setState(() {
          selectedQuestionnaire = null;
          questionnaireQuestions = [];
          questionnaireError =
              'No questionnaire available. Login online once to cache it for offline use.';
        });
        return;
      }

      final rawQuestions = questionnaire['questions'];

      final loadedQuestions = rawQuestions is List
          ? rawQuestions
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
          : <Map<String, dynamic>>[];

      setState(() {
        selectedQuestionnaire = questionnaire;
        questionnaireQuestions = loadedQuestions;
        questionnaireError = null;
        _questionnaireExpanded = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        questionnaireError = 'Failed to load questionnaire: $e';
        selectedQuestionnaire = null;
        questionnaireQuestions = [];
      });
    } finally {
      if (mounted) {
        setState(() {
          questionnaireLoading = false;
        });
      }
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
      key: ValueKey('text-$questionId-$_registrationFormVersion'),
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
      key: ValueKey('radio-$questionId-$_registrationFormVersion'),
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
      key: ValueKey('dropdown-$questionId-$_registrationFormVersion'),
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
                    selectedQuestionnaire!['title'] ?? 'Questionnaire',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF202124),
                    ),
                  ),
                  if (selectedQuestionnaire!['description'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        selectedQuestionnaire!['description'].toString(),
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

    if (_faceScanRequired && selectedFacePhoto == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Scan beneficiary face')));
      return false;
    }

    return true;
  }

  Future<BeneficiarySaveResult> _saveBeneficiaryDraft() async {
    if (_beneficiaryId != null) {
      return BeneficiarySaveResult.synced(remoteId: _beneficiaryId!);
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

    final result = await beneficiaryService.saveBeneficiary(
      draft: draft,
      photoLocalPath: selectedPhoto?.path,
      facePhotoLocalPath: (selectedFacePhoto ?? selectedPhoto)?.path,
    );

    if (result.remoteId != null) {
      _beneficiaryId = result.remoteId;
    }

    return result;
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

  Future<String?> _uploadFacePhoto({required String beneficiaryId}) async {
    final facePhoto = selectedFacePhoto ?? selectedPhoto;
    if (facePhoto == null) {
      return null;
    }

    final facePhotoPath = await beneficiaryService.uploadBeneficiaryFacePhoto(
      photoFile: facePhoto,
      tenantId: _tenantId!,
      beneficiaryId: beneficiaryId,
    );

    _uploadedFacePhotoUrl = facePhotoPath;
    return facePhotoPath;
  }

  Future<void> _saveQuestionnaireResponses({
    required String beneficiaryId,
  }) async {
    if (selectedQuestionnaire == null || selectedProgramId == null) {
      return;
    }

    final user = Supabase.instance.client.auth.currentUser!;

    try {
      await questionnaireService.saveQuestionnaireResponse(
        tenantId: _tenantId!,
        questionnaireId: selectedQuestionnaire!['id'],
        programId: selectedProgramId!,
        beneficiaryId: beneficiaryId,
        submittedBy: user.id,
        answers: questionnaireAnswers,
      );
    } on PostgrestException {
      rethrow;
    } catch (error) {
      if (!_isLikelyNetworkError(error)) {
        rethrow;
      }

      await _saveQuestionnaireResponsesLocally(
        localBeneficiaryId: beneficiaryId,
        remoteBeneficiaryId: beneficiaryId,
      );
    }
  }

  Future<void> _saveQuestionnaireResponsesLocally({
    required String localBeneficiaryId,
    String? remoteBeneficiaryId,
  }) async {
    if (selectedQuestionnaire == null || selectedProgramId == null) {
      return;
    }

    final user = Supabase.instance.client.auth.currentUser!;

    await questionnaireService.saveQuestionnaireResponseLocally(
      localBeneficiaryId: localBeneficiaryId,
      remoteBeneficiaryId: remoteBeneficiaryId,
      tenantId: _tenantId!,
      questionnaireId: selectedQuestionnaire!['id'],
      programId: selectedProgramId!,
      submittedBy: user.id,
      answers: questionnaireAnswers,
    );
  }

  bool _isLikelyNetworkError(Object error) {
    final message = error.toString().toLowerCase();

    return message.contains('socket') ||
        message.contains('network') ||
        message.contains('connection') ||
        message.contains('timeout') ||
        message.contains('offline') ||
        message.contains('failed host lookup') ||
        message.contains('internet');
  }

  void _resetRegistrationFormForNextBeneficiary() {
    fullNameController.clear();
    nationalIdController.clear();
    phoneController.clear();
    householdSizeController.clear();
    addressController.clear();
    notesController.clear();

    setState(() {
      selectedGender = null;
      selectedDateOfBirth = null;
      questionnaireAnswers.clear();
      selectedPhoto = null;
      selectedFacePhoto = null;
      faceQualityResult = null;
      _beneficiaryId = null;
      _uploadedPhotoUrl = null;
      _uploadedFacePhotoUrl = null;
      _registrationFormVersion += 1;
      selectedQuestionnaire = null;
      questionnaireQuestions = [];
      questionnaireError = null;
      _questionnaireExpanded = false;
    });
  }

  Future<void> _saveDetailsAndMoveToFingerprint() async {
    if (!_validateBeneficiaryForm()) {
      return;
    }

    try {
      setState(() {
        _savingDraft = true;
      });

      final saveResult = await _saveBeneficiaryDraft();

      if (saveResult.savedLocally) {
        await _saveQuestionnaireResponsesLocally(
          localBeneficiaryId: saveResult.localId!,
        );

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved locally. Sync when the device is online.'),
          ),
        );

        context.go('/home');
        return;
      }

      final beneficiaryId = saveResult.remoteId!;

      await _saveQuestionnaireResponses(beneficiaryId: beneficiaryId);

      _uploadedPhotoUrl ??= await _uploadBeneficiaryPhoto(
        beneficiaryId: beneficiaryId,
      );

      _uploadedFacePhotoUrl ??= await _uploadFacePhoto(
        beneficiaryId: beneficiaryId,
      );

      if (_uploadedFacePhotoUrl != null) {
        await _biometricService.enrollFacePhoto(
          beneficiaryId: beneficiaryId,
          tenantId: _tenantId!,
          photoUrl: _uploadedFacePhotoUrl!,
        );
      }

      if (!mounted) return;

      setState(() {
        _savingDraft = false;
      });

      final completed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => FingerprintEnrollmentScreen(
            beneficiaryId: beneficiaryId,
            tenantId: _tenantId!,
          ),
        ),
      );

      if (!mounted) return;

      if (completed == true) {
        _resetRegistrationFormForNextBeneficiary();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Beneficiary registration completed. Form ready for next beneficiary.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      debugPrint('Failed to save beneficiary details: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save details. Check logs.')),
      );
    } finally {
      if (mounted && _savingDraft) {
        setState(() {
          _savingDraft = false;
        });
      }
    }
  }

  Widget _buildBeneficiaryExtraFields() {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: 8),
        leading: const Icon(Icons.tune, color: AppColors.primary),
        title: const Text(
          'Additional Details',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
        ),
        subtitle: const Text(
          'Gender, birth date, household, address, notes',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        children: [
          DropdownButtonFormField<String>(
            initialValue: selectedGender,
            decoration: const InputDecoration(
              labelText: 'Gender',
              prefixIcon: Icon(Icons.wc_outlined),
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
          const SizedBox(height: 12),
          InkWell(
            onTap: pickDateOfBirth,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Date of Birth',
                prefixIcon: Icon(Icons.calendar_today_outlined),
              ),
              child: Text(formattedDateOfBirth ?? 'Select date'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: householdSizeController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Household Size',
              prefixIcon: Icon(Icons.groups_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: addressController,
            decoration: const InputDecoration(
              labelText: 'Address',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Notes',
              prefixIcon: Icon(Icons.notes_outlined),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaceVerificationSection() {
    final quality = faceQualityResult;
    final statusColor = quality == null
        ? AppColors.muted
        : quality.isAccepted
        ? AppColors.primary
        : AppColors.amber;

    return FieldSurface(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.verified_user_outlined, color: statusColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Face Verification',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  quality == null
                      ? 'Not scanned'
                      : quality.isAccepted
                      ? 'Verified'
                      : quality.message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (quality != null && quality.isAccepted)
            const FieldStatusPill(label: 'Verified', icon: Icons.check_circle)
          else
            TextButton.icon(
              onPressed: _scanningFace ? null : scanFace,
              icon: _scanningFace
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.center_focus_strong, size: 18),
              label: Text(_scanningFace ? 'Scanning' : 'Scan'),
            ),
        ],
      ),
    );
  }

  Widget _buildPhotoCaptureSection() {
    return FieldSurface(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          FieldPhotoAvatar(
            file: selectedPhoto,
            label: fullNameController.text,
            size: 64,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Capture Photo',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 3),
                Text(
                  'Required for field identity checks',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: pickPhoto,
            icon: const Icon(Icons.camera_alt_outlined, size: 18),
            label: Text(selectedPhoto == null ? 'Capture' : 'Retake'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionnaireStatusTile() {
    final hasQuestionnaire = selectedQuestionnaire != null;
    final count = questionnaireQuestions.length;

    if (questionnaireLoading) {
      return const FieldSurface(
        padding: EdgeInsets.all(14),
        child: Row(
          children: [
            SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Expanded(child: Text('Loading questionnaire...')),
          ],
        ),
      );
    }

    if (questionnaireError != null) {
      return FieldSurface(
        color: AppColors.amberSoft,
        borderColor: AppColors.amber.withValues(alpha: 0.28),
        padding: const EdgeInsets.all(12),
        child: Text(
          questionnaireError!,
          style: const TextStyle(
            color: AppColors.amber,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    if (selectedProgramId == null) {
      return const SizedBox.shrink();
    }

    return FieldSurface(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _questionnaireExpanded,
          onExpansionChanged: (expanded) {
            setState(() {
              _questionnaireExpanded = expanded;
            });
          },
          leading: const Icon(
            Icons.assignment_outlined,
            color: AppColors.primary,
          ),
          title: const Text(
            'Questionnaire',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
          ),
          subtitle: Text(
            hasQuestionnaire
                ? '$count questions'
                : 'No published questionnaire',
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          trailing: hasQuestionnaire
              ? const Icon(Icons.check_circle_outline, color: AppColors.primary)
              : const Icon(Icons.info_outline, color: AppColors.amber),
          children: hasQuestionnaire
              ? [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildQuestionnaireHeader(),
                        const SizedBox(height: 12),
                        ...questionnaireQuestions.map(buildQuestionField),
                      ],
                    ),
                  ),
                ]
              : const [],
        ),
      ),
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
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              FieldSurface(
                color: AppColors.dangerSoft,
                borderColor: AppColors.danger.withValues(alpha: 0.24),
                child: Text(
                  'Failed to load registration data:\n\n$error',
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _formBackgroundColor,
      appBar: AppBar(
        title: const Text('Register Beneficiary'),
        actions: [
          IconButton(
            onPressed: _savingDraft ? null : _saveDetailsAndMoveToFingerprint,
            icon: const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FieldSurface(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedProgramId,
                      decoration: const InputDecoration(
                        labelText: 'Program',
                        prefixIcon: Icon(Icons.work_outline),
                      ),
                      items: programs.map((program) {
                        return DropdownMenuItem<String>(
                          value: program['id'],
                          child: Text(
                            program['name'] ?? 'Unnamed Program',
                            overflow: TextOverflow.ellipsis,
                          ),
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
                    const SizedBox(height: 12),
                    TextField(
                      controller: fullNameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name *',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nationalIdController,
                      decoration: const InputDecoration(
                        labelText: 'National ID *',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildBeneficiaryExtraFields(),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _buildPhotoCaptureSection(),
              if (selectedProgramId != null ||
                  questionnaireLoading ||
                  selectedQuestionnaire != null ||
                  questionnaireError != null) ...[
                const SizedBox(height: 10),
                _buildQuestionnaireStatusTile(),
              ],
              const SizedBox(height: 10),
              _buildFaceVerificationSection(),
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _savingDraft ? null : _saveDetailsAndMoveToFingerprint,
              icon: _savingDraft
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save),
              label: Text(_savingDraft ? 'Saving...' : 'Save Beneficiary'),
            ),
          ),
        ),
      ),
    );
  }
}
