import 'dart:async';
import 'dart:html' as html;

import 'package:angular/angular.dart';
import 'package:angular_components/angular_components.dart';
import 'package:angular_components/focus/focus.dart';
import 'package:angular_components/material_datepicker/module.dart';
import 'package:angular_forms/angular_forms.dart';
import 'package:fo_components/components/fo_icon/fo_icon_component.dart';
import 'package:intl/intl.dart';

import '../../pipes/capitalize_pipe.dart';
import '../fo_button/fo_button_component.dart';
import '../fo_button/fo_button_event.dart';
import '../fo_dropdown_list/fo_dropdown_list_component.dart';
import '../fo_dropdown_list/fo_dropdown_option.dart';
import '../fo_label/fo_label_component.dart';
import 'fo_error_output_component.dart';

@Component(
    selector: 'fo-text-input',
    templateUrl: 'fo_text_input_component.html',
    styleUrls: ['fo_text_input_component.css'],
    directives: [
      AutoFocusDirective,
      FoButtonComponent,
      FoDropdownListComponent,
      FoErrorOutputComponent,
      FoLabelComponent,
      formDirectives,
      FoIconComponent,
      NgClass,
      NgIf
    ],
    pipes: [CapitalizePipe],
    providers: [datepickerBindings],
    changeDetection: ChangeDetectionStrategy.OnPush)
class FoTextInputComponent
    implements ControlValueAccessor<String>, AfterViewInit, OnDestroy {
  final ChangeDetectorRef _changeDetectorRef;
  @Input()
  String actionButtonLabel;

  @Input()
  String actionButtonIcon;

  @Input()
  bool autoFocus = false;

  @Input()
  String label;

  @Input()
  String leadingIcon;

  @Input()
  String leadingText;

  @Input()
  bool clearIcon;

  @Input()
  String placeholder;

  /// Set to false if you want all options appear regardless of what the user types
  @Input()
  bool filterOptions = true;

  @Input()
  Map<String, List<FoDropdownOptionRenderable>> options;

  @Input()
  bool showDropdownCategoryLabels = true;

  @Input()
  bool showDropdownOnFocus = false;

  /// Max height of options dropdown, in pixels
  @Input()
  int dropdownMaxHeight;

  @Input()
  bool disabled = false;

  /// Make sure options dropdown doesn't extend beyond the viewport
  @Input()
  bool constrainToViewPort = true;

  @Input()
  String type = 'text';

  @Input()
  bool hideErrorsOnBlur = true;

  @Input()
  bool materialIcons = true;

  String value;

  ChangeFunction<String> _onChange;

  NgControl control;
  final StreamController<html.Event> _clearButtonController =
      StreamController<html.Event>();
  final StreamController<FoButtonEvent> actionButtonController =
      StreamController<FoButtonEvent>();
  final StreamController<html.Event> changeController =
      StreamController<html.Event>();
  final StreamController<SelectionChangeEvent> _selectionChangeController =
      StreamController<SelectionChangeEvent>();
  final StreamController<html.FocusEvent> _focusController =
      StreamController<html.FocusEvent>();
  final StreamController<String> _blurController = StreamController<String>();
  StreamSubscription _windowResizeSub;
  bool _dropdownVisible = false;
  html.Element host;
  html.InputElement inputElement;
  bool hasFocus = false;
  int dropdownWidth;

  FoTextInputComponent(
      @Self() @Optional() this.control, this.host, this._changeDetectorRef) {
    if (control != null) control.valueAccessor = this;

    _windowResizeSub = html.window.onResize.listen(
        (_) => dropdownWidth = host.getBoundingClientRect().width.toInt() - 2);
  }

  /// Action button triggered
  @Output('actionButtonTrigger')
  Stream<FoButtonEvent> get actionButtonTrigger =>
      actionButtonController.stream;

  /// Component lost focus
  @Output('blur')
  Stream<String> get blur => _blurController.stream;

  /// Clear icon is clicked
  @Output('clear')
  Stream<html.Event> get clear => _clearButtonController.stream;

  bool get dropdownVisible =>
      options != null &&
      (_dropdownVisible && (value?.isEmpty == false || filterOptions != true) ||
          (hasFocus == true && showDropdownOnFocus == true));

  set dropdownVisible(bool value) {
    dropdownWidth = host.getBoundingClientRect().width.toInt() - 2;
    _dropdownVisible = value;
  }

  String get errorMessage {
    final errors = control?.errors;
    if (errors == null) {
      return null;
    } else if (errors.containsKey('required')) {
      return Intl.message('this field is required', name: 'error_required');
    } else if (errors.containsKey('error')) {
      return errors['error'];
    } else if (errors.containsKey('minlength')) {
      return Intl.message(
          'enter at least ${errors['minlength']['requiredLength']} characters',
          args: [errors['minlength']['requiredLength']],
          name: 'error_min_length');
    } else if (errors.containsKey('maxlength')) {
      return Intl.message(
          'enter max ${errors['maxlength']['requiredLength']} characters',
          args: [errors['maxlength']['requiredLength']],
          name: 'error_max_length');
    } else if (errors.containsKey('pattern')) {
      return Intl.message(
          'invalid pattern, required: ${errors['pattern']['requiredPattern']}',
          args: [errors['pattern']['requiredPattern']],
          name: 'error_invalid_pattern');
    } else {
      return errors.toString();
    }
  }

  String get filterValue => filterOptions == true ? value : null;

  @Output('focus')
  Stream<html.FocusEvent> get focus => _focusController.stream;

  String get noFocusShadow =>
      host.attributes.containsKey('noFocusShadow') ? '1' : null;

  @Output('selectionChange')
  Stream<SelectionChangeEvent> get selectionChange =>
      _selectionChangeController.stream;

  int get selectionEnd => inputElement?.selectionEnd;

  int get selectionStart => inputElement?.selectionStart;

  String get square => host.attributes.containsKey('square') ? '1' : null;

  String get autocomplete => host.attributes['autocomplete'];

  @override
  void ngAfterViewInit() {
    inputElement = host.querySelector('input');
  }

  @override
  void ngOnDestroy() {
    actionButtonController?.close();
    changeController.close();
    _selectionChangeController.close();
    _focusController.close();
    _blurController.close();
    _clearButtonController.close();
    _windowResizeSub.cancel();
  }

  void onBlur(html.Event event) {
    /// Delay has focus a little bit so that the dropdown list has time to detect click before being removed
    Future.delayed(Duration(milliseconds: 100)).then((_) {
      hasFocus = false;
    });
    _blurController.add(value);
  }

  int get dropdownTopOffset => square == null ? null : -1;

  void onClear(html.Event event) {
    // Prevent the input from gaining focus
    event.preventDefault();
    value = '';
    _dropdownVisible = false;
    if (_onChange != null) {
      _onChange(value);
    }
    _clearButtonController.add(event);
  }

  @override
  void onDisabledChanged(bool isDisabled) {
    disabled = isDisabled;
  }

  void onFilterSelect(FoDropdownOptionRenderable event) {
    _selectionChangeController
        .add(SelectionChangeEvent(value, event.renderLabel, event.renderId));
    value = event.renderLabel;
    _dropdownVisible = false;
    if (_onChange != null) {
      _onChange(value);
    }
  }

  void onFocus(html.FocusEvent event) {
    event.preventDefault();
    hasFocus = true;
    _focusController.add(event);
  }

  void onKeyUp(html.Event event) {
    if (event is html.KeyboardEvent &&
        (actionButtonLabel != null && event?.keyCode == html.KeyCode.ENTER ||
            event?.keyCode == html.KeyCode.MAC_ENTER &&
                value?.isEmpty == false)) {
      event.stopPropagation();
      actionButtonController.add(FoButtonEvent());
    }
  }

  void onValueChange(String event) {
    value = event;
    if (_onChange != null) {
      _onChange(value);
    }

    _dropdownVisible = options != null && value?.isEmpty == false;
  }

  @override
  void registerOnChange(ChangeFunction<String> f) {
    _onChange = f;
  }

  @override
  void registerOnTouched(TouchFunction f) {}

  @override
  void writeValue(String obj) {
    value = obj;
    _changeDetectorRef.markForCheck();
  }
}

class SelectionChangeEvent {
  final String labelBefore;
  final String labelAfter;
  final String value;

  SelectionChangeEvent(this.labelBefore, this.labelAfter, this.value);
}
