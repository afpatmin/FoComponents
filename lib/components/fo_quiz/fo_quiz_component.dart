import 'dart:async';

import 'package:angular/angular.dart';
import 'package:intl/intl.dart';

import '../../models/fo_quiz_model.dart';
import 'fo_question_component.dart';

@Component(
  selector: 'fo-quiz',
  templateUrl: 'fo_quiz_component.html',
  styleUrls: ['fo_quiz_component.css'],
  directives: [FoQuestionComponent, NgFor],
  changeDetection: ChangeDetectionStrategy.OnPush,
)
class FoQuizComponent implements OnInit, OnDestroy {
  FoQuestionModel activeQuestion;
  int activeIndex;
  final ChangeDetectorRef _changeDetectorRef;

  final _doneController = StreamController<FoQuizDoneEvent>();

  @Input()
  FoQuizModel model;

  @Input()
  bool disabled = false;

  @Input()
  String buttonColor = '#888';

  @Input()
  @Deprecated(
      'This has been deprecated and will be removed in next major release')
  String buttonColorActive = '#aaa';

  final String quiz_previous = Intl.message('previous', name: 'quiz_previous');

  final String quiz_send = Intl.message('send', name: 'quiz_send');

  final String quiz_next = Intl.message('next', name: 'quiz_next');

  FoQuizComponent(this._changeDetectorRef);

  String get nextButtonLabel =>
      activeQuestion == model.questions.last ? quiz_send : quiz_next;

  @Output('done')
  Stream<FoQuizDoneEvent> get onDone => _doneController.stream;

  String get prevButtonLabel =>
      activeQuestion == null || activeQuestion == model.questions.first
          ? null
          : quiz_previous;
  @override
  void ngOnDestroy() {
    _doneController.close();
  }

  int maxPoints;

  @override
  void ngOnInit() {
    restart();
    maxPoints = _calcMaxPoints(model);
  }

  void onQuestionDone(FoQuestionModel question) {
    activeIndex = model.questions.indexOf(question);

    if (activeIndex == model.questions.length - 1) {
      _doneController.add(FoQuizDoneEvent(_calcScore(model), maxPoints));
    } else {
      activeIndex++;
      activeQuestion = model.questions[activeIndex];
    }
  }

  void restart() {
    activeQuestion = model.questions.first;
    activeIndex = 0;
    _changeDetectorRef.markForCheck();
  }

  void onQuestionPrev(FoQuestionModel question) {
    activeIndex = model.questions.indexOf(question);

    if (activeIndex > 0) {
      activeIndex--;
      activeQuestion = model.questions[activeIndex];
    }
  }

  int _calcMaxPoints(FoQuizModel quiz) {
    if (quiz == null) return 0;
    var maxPoints = 0;

    /// Add all options in multi-selects
    for (final question in quiz.questions.where((q) => q.multiSelect == true)) {
      for (final option in question.options) {
        if (option.score > 0) {
          maxPoints += option.score;
        }
        maxPoints += _calcMaxPoints(option.child);
      }
    }

    /// Add only highest score option in single-selects
    for (final question
        in quiz.questions.where((q) => q.multiSelect == false)) {
      final sortedOptions = List<FoOptionModel>.from(question.options)
        ..sort((o1, o2) => o2.score - o1.score);

      final highestScore = sortedOptions.first.score;
      if (highestScore > 0) {
        maxPoints += highestScore;
      }

      for (final option in question.options) {
        maxPoints += _calcMaxPoints(option.child);
      }
    }
    return maxPoints;
  }

  int _calcScore(FoQuizModel quiz) {
    if (quiz == null) return 0;
    var score = 0;
    for (final question in quiz.questions) {
      final selectedOptions =
          question.options.where((option) => option.selected);
      for (final option in selectedOptions) {
        score += option.score;
        score += _calcScore(option.child);
      }
    }
    return score;
  }
}

class FoQuizDoneEvent {
  final int score;

  final int maxPoints;
  FoQuizDoneEvent(this.score, this.maxPoints);
}
