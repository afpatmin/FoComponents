import 'dart:async';
import 'dart:html' as dom;

import 'package:angular/angular.dart';

import '../fo_button/fo_button_component.dart';
import '../fo_button/fo_button_event.dart';
import '../fo_dropdown_list/fo_dropdown_list_component.dart';
import '../fo_dropdown_list/fo_dropdown_option.dart';
import '../fo_icon/fo_icon_component.dart';
import '../fo_label/fo_label_component.dart';

@Component(
    selector: 'fo-dropdown-select',
    templateUrl: 'fo_dropdown_select_component.html',
    styleUrls: ['fo_dropdown_select_component.css'],
    directives: [
      coreDirectives,
      FoButtonComponent,
      FoDropdownListComponent,
      FoIconComponent,
      FoLabelComponent,
    ],
    changeDetection: ChangeDetectionStrategy.OnPush)
class FoDropdownSelectComponent implements AfterChanges, OnDestroy {
  @Input()
  String label;

  @Input()
  String actionButtonLabel;

  @Input()
  bool disabled = false;

  @Input()
  String placeholder = '-';

  @Input()
  bool allowNullSelection = false;

  @Input()
  bool showDropdownCategoryLabels = true;

  /// Max height of the dropdown, in pixels
  @Input()
  int dropdownMaxHeight;

  /// Make sure options doesn't extend beyond the viewport
  @Input()
  bool constrainToViewPort = true;

  @Input()
  bool materialIcons = true;

  Map<String, List<FoDropdownOptionRenderable>> _options;

  bool _optionsChanged;
  Object _selectedId;

  final ChangeDetectorRef _changeDetectorRef;

  final StreamController<Object> _selectedIdController =
      StreamController<Object>();

  final StreamController<FoButtonEvent> _actionButtonController =
      StreamController<FoButtonEvent>();
  final dom.Element _host;

  bool dropdownVisible = false;

  FoDropdownOptionRenderable selectedOption;
  @Input()
  bool showSearch = false;
  @ViewChild('selector')
  dom.Element selectorElement;

  FoDropdownSelectComponent(this._host, this._changeDetectorRef);

  @Output('actionButtonTrigger')
  Stream<FoButtonEvent> get actionButtonTrigger =>
      _actionButtonController.stream;

  int get dropdownWidth =>
      selectorElement.getBoundingClientRect().width.round();

  Map<String, List<FoDropdownOptionRenderable>> get options => _options;

  @Input()
  set options(Map<String, List<FoDropdownOptionRenderable>> value) {
    _options = value;
    _optionsChanged = true;
  }

  Object get selectedId => _selectedId;

  @Input('selectedId')
  set selectedId(Object id) {
    selectedOption = null;
    _selectedId = id;

    if (options != null) {
      for (final category in options.keys) {
        if (options[category] != null) {
          selectedOption = options[category]
              .firstWhere((e) => e?.renderId == id, orElse: () => null);

          if (selectedOption != null) {
            return;
          }
        }
      }
    }
  }

  @Output('selectedIdChange')
  Stream<Object> get selectedIdChange => _selectedIdController.stream;

  String get noFocusShadow =>
      _host.attributes.containsKey('noFocusShadow') ? '1' : null;

  String get square => _host.attributes.containsKey('square') ? '1' : null;

  @override
  void ngAfterChanges() {
    if (_optionsChanged == true) {
      // Update selected option
      for (final category in options.keys) {
        selectedOption = options[category].firstWhere(
            (option) => option?.renderId == _selectedId,
            orElse: () => null);
        if (selectedOption != null) {
          return;
        }
      }
    }
  }

  @override
  void ngOnDestroy() {
    _actionButtonController.close();
    _selectedIdController.close();
  }

  void onActionButtonTrigger(FoButtonEvent event) {
    _actionButtonController.add(event);
    dropdownVisible = false;
  }

  void onClick(dom.Event e) {
    if (disabled != true &&
        options?.values
                ?.where((option) => option?.isNotEmpty == true)
                ?.isNotEmpty ==
            true) {
      Future.delayed(Duration(milliseconds: 100)).then((_) {
        dropdownVisible = !dropdownVisible;
        _changeDetectorRef.markForCheck();
      });
    }
    e
      ..preventDefault()
      ..stopPropagation();
  }

  int get dropdownTopOffset => square == null ? null : -1;

  void onSelect(FoDropdownOptionRenderable event) {
    dropdownVisible = false;
    selectedOption = event;
    _selectedId = event.renderId;
    _selectedIdController.add(event.renderId);
  }
}
