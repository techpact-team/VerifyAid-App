class QuestionnaireQuestion {
  const QuestionnaireQuestion({required this.id, required this.label});

  final String id;
  final String label;
}

const defaultQuestionnaireQuestions = [
  QuestionnaireQuestion(id: 'answer_1', label: 'Questionnaire answer 1'),
  QuestionnaireQuestion(id: 'answer_2', label: 'Questionnaire answer 2'),
  QuestionnaireQuestion(id: 'answer_3', label: 'Questionnaire answer 3'),
];
