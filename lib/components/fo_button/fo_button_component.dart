import 'dart:async';
import 'package:angular/angular.dart';
import 'package:fo_components/components/fo_icon/fo_icon_component.dart';
import 'fo_button_event.dart';

@Component(
    selector: 'fo-button',
    templateUrl: 'fo_button_component.html',
    styleUrls: ['fo_button_component.css'],
    directives: [FoIconComponent, NgClass, NgIf],
    changeDetection: ChangeDetectionStrategy.OnPush)
class FoButtonComponent implements OnDestroy {
  @Input()
  String label;

  @Input()

  /// Button icon, don't use when the button has a label (use leading-/trailingIcon for that)
  String icon;

  @Input()

  /// Only use when the button also has a label
  String leadingIcon;

  @Input()

  /// Only use when the button also has a label
  String trailingIcon;

  /// Set text/icon color dynamically, overrides any color set by mixins and attributes
  @Input()
  String themeColor;

  /// Set background color dynamically, overrides any color set by mixins and attributes.
  @Input()
  String themeBackgroundColor;

  @Input()
  bool disabled = false;

  @Input()
  bool materialIcon = true;

  @Output('trigger')
  Stream<FoButtonEvent> get trigger => _triggerController.stream;

  void onClick() {
    if (disabled != true) {
      _triggerController.add(FoButtonEvent());
    }
  }

  final StreamController _triggerController = StreamController<FoButtonEvent>();

  FoButtonComponent();

  @override
  void ngOnDestroy() {
    _triggerController.close();
  }
}
