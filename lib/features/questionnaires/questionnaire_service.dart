import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class QuestionnaireService {
  final supabase = Supabase.instance.client;

  Future<Map<String, dynamic>?> getActiveQuestionnaire({
    required String programId,
    required String tenantId,
  }) async {
    final result = await supabase
        .from('program_questionnaires')
        .select()
        .eq('program_id', programId)
        .eq('tenant_id', tenantId)
        .eq('status', 'published')
        .order('version', ascending: false)
        .limit(1)
        .maybeSingle();

    debugPrint('ACTIVE QUESTIONNAIRE: $result');

    return result;
  }

  Future<List<Map<String, dynamic>>> getQuestions({
    required String questionnaireId,
    String? programQuestionnaireId,
    required String tenantId,
  }) async {
    debugPrint(
      'FETCHING QUESTIONS FOR QUESTIONNAIRE ID: $questionnaireId '
      'PROGRAM QUESTIONNAIRE ID: $programQuestionnaireId',
    );

    final attempts = _buildQuestionQueryAttempts(
      questionnaireId: questionnaireId,
      programQuestionnaireId: programQuestionnaireId,
      tenantId: tenantId,
    );

    Object? lastRecoverableError;
    var hadEmptySuccessfulQuery = false;

    for (final attempt in attempts) {
      try {
        final rows = await _fetchQuestions(attempt);

        if (rows.isEmpty) {
          hadEmptySuccessfulQuery = true;
          debugPrint('NO QUESTIONS USING ${attempt.debugLabel}');
          continue;
        }

        final normalized = rows.map(_normalizeQuestion).toList()
          ..sort(_compareQuestions);

        debugPrint(
          'LOADED ${normalized.length} QUESTIONS USING ${attempt.debugLabel}',
        );

        return normalized;
      } on PostgrestException catch (error) {
        if (!_isRecoverableQuestionQueryError(error)) {
          rethrow;
        }

        lastRecoverableError = error;
        debugPrint(
          'QUESTION QUERY SKIPPED (${attempt.debugLabel}): ${error.message}',
        );
      }
    }

    if (hadEmptySuccessfulQuery) {
      return [];
    }

    if (lastRecoverableError != null) {
      throw lastRecoverableError;
    }

    return [];
  }

  List<_QuestionQueryAttempt> _buildQuestionQueryAttempts({
    required String questionnaireId,
    required String? programQuestionnaireId,
    required String tenantId,
  }) {
    final attempts = <_QuestionQueryAttempt>[];
    final seen = <String>{};

    void add(String column, String? value, {required bool includeTenant}) {
      if (value == null || value.trim().isEmpty) return;

      final key = '$column|$value|$includeTenant';
      if (seen.add(key)) {
        attempts.add(
          _QuestionQueryAttempt(
            column: column,
            value: value,
            tenantId: tenantId,
            includeTenant: includeTenant,
          ),
        );
      }
    }

    for (final includeTenant in [true, false]) {
      add(
        'program_questionnaire_id',
        programQuestionnaireId,
        includeTenant: includeTenant,
      );
      add('questionnaire_id', questionnaireId, includeTenant: includeTenant);
      add(
        'program_questionnaire_id',
        questionnaireId,
        includeTenant: includeTenant,
      );
      add(
        'questionnaire_id',
        programQuestionnaireId,
        includeTenant: includeTenant,
      );
    }

    return attempts;
  }

  Future<List<Map<String, dynamic>>> _fetchQuestions(
    _QuestionQueryAttempt attempt,
  ) async {
    var query = supabase
        .from('questionnaire_questions')
        .select()
        .eq(attempt.column, attempt.value);

    if (attempt.includeTenant) {
      query = query.eq('tenant_id', attempt.tenantId);
    }

    final response = await query;
    return List<Map<String, dynamic>>.from(response);
  }

  bool _isRecoverableQuestionQueryError(PostgrestException error) {
    final message = error.message.toLowerCase();

    return message.contains('column') ||
        message.contains('schema cache') ||
        message.contains('does not exist') ||
        message.contains('could not find');
  }

  Map<String, dynamic> _normalizeQuestion(Map<String, dynamic> question) {
    final normalized = Map<String, dynamic>.from(question);
    final id = _firstValue(question, const ['id', 'question_id']);
    final text = _firstValue(question, const [
      'question_text',
      'label',
      'title',
      'text',
      'prompt',
      'name',
    ]);
    final type = _firstValue(question, const [
      'question_type',
      'type',
      'field_type',
      'input_type',
      'answer_type',
    ]);
    final required = _firstValue(question, const [
      'required',
      'is_required',
      'mandatory',
    ]);

    normalized['id'] = id?.toString() ?? '';
    normalized['question_text'] = text?.toString() ?? 'Question';
    normalized['question_type'] = _normalizeQuestionType(type?.toString());
    normalized['required'] = _asBool(required);

    return normalized;
  }

  Object? _firstValue(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value;
      }
    }

    return null;
  }

  String _normalizeQuestionType(String? type) {
    final normalized = (type ?? 'text').toLowerCase().trim();

    if (normalized == 'integer' || normalized == 'decimal') {
      return 'number';
    }

    if (normalized == 'boolean' || normalized == 'bool') {
      return 'yes_no';
    }

    if (normalized == 'text' ||
        normalized == 'string' ||
        normalized == 'short_text') {
      return 'text';
    }

    return normalized;
  }

  bool _asBool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      return [
        'true',
        'yes',
        '1',
        'required',
      ].contains(value.toLowerCase().trim());
    }

    return false;
  }

  int _compareQuestions(
    Map<String, dynamic> first,
    Map<String, dynamic> second,
  ) {
    final firstOrder = _questionOrder(first);
    final secondOrder = _questionOrder(second);

    if (firstOrder != secondOrder) {
      return firstOrder.compareTo(secondOrder);
    }

    return (first['question_text'] ?? '').toString().compareTo(
      (second['question_text'] ?? '').toString(),
    );
  }

  int _questionOrder(Map<String, dynamic> question) {
    final value = _firstValue(question, const [
      'sort_order',
      'display_order',
      'order_index',
      'position',
      'sequence',
      'order',
    ]);

    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<void> saveQuestionnaireResponse({
    required String tenantId,
    required String questionnaireId,
    required String programId,
    required String beneficiaryId,
    required String submittedBy,
    required Map<String, dynamic> answers,
  }) async {
    final response = await supabase
        .from('questionnaire_responses')
        .insert({
          'tenant_id': tenantId,
          'questionnaire_id': questionnaireId,
          'program_id': programId,
          'beneficiary_id': beneficiaryId,
          'submitted_by': submittedBy,
          'status': 'submitted',
          'submitted_at': DateTime.now().toIso8601String(),
        })
        .select('id')
        .single();

    final responseId = response['id'];

    final answerRows = answers.entries.map((entry) {
      return {
        'tenant_id': tenantId,
        'response_id': responseId,
        'question_id': entry.key,
        'answer_text': entry.value?.toString(),
        'answer_json': {'value': entry.value},
      };
    }).toList();

    if (answerRows.isNotEmpty) {
      await supabase.from('questionnaire_answers').insert(answerRows);
    }
  }
}

class _QuestionQueryAttempt {
  const _QuestionQueryAttempt({
    required this.column,
    required this.value,
    required this.tenantId,
    required this.includeTenant,
  });

  final String column;
  final String value;
  final String tenantId;
  final bool includeTenant;

  String get debugLabel {
    final tenantLabel = includeTenant ? ' with tenant filter' : '';
    return '$column=$value$tenantLabel';
  }
}
