// Copyright (c) 2017, Patrick Minogue. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'package:angular/angular.dart';
import 'package:angular_components/angular_components.dart';
import '../fo_modal_component/fo_modal_component.dart';
import '../../pipes/phrase_pipe.dart';

@Component(
    selector: 'fo-select',
    styleUrls: const ['fo_select_component.scss.css'],
    templateUrl: 'fo_select_component.html',
    directives: const [CORE_DIRECTIVES, materialDirectives, FoModalComponent],
    pipes: const [PhrasePipe],
    changeDetection: ChangeDetectionStrategy.OnPush,
    visibility: Visibility.none
)
class FoSelectComponent implements OnChanges, OnDestroy
{
  FoSelectComponent()
  {
    _selectionChangeListener = selectionModel.selectionChanges.listen(_onSelectionChanges);
  }

  void ngOnChanges(Map<String, SimpleChange> changes)
  {
    if (changes.containsKey("selectedId"))
    {
      selectedModel = (selectedId == null) ? null : options.optionsList.firstWhere((m) => m['id'] == selectedId, orElse: () => null);
    }
  }

  void ngOnDestroy()
  {
    _onVisibleChangeController.close();
    _onSelectedIdChangeController.close();
    onActionButtonTriggerController.close();
    _selectionChangeListener.cancel();
  }

  void setVisible(bool flag)
  {
    if (!disabled) visible = flag;
  }

  void _onSelectionChanges(List<SelectionChangeRecord<Map>> e)
  {
    if (e.isEmpty) return;
    if (e.first.added.isNotEmpty)
    {
      selectedModel = e.first.added.first;
      selectedId = selectedModel['id'];
    }
    _onSelectedIdChangeController.add(selectedModel == null ? null : selectedModel['id']);
  }

  void clearSelection()
  {
    selectionModel.clear();
    selectedModel = null;
    selectedId = null;
    _onSelectedIdChangeController.add(null);
  }

  SelectionModel<Map> selectionModel = new SelectionModel.withList(allowMulti: false);
  StreamSubscription<List<SelectionChangeRecord<Map>>> _selectionChangeListener;
  final StreamController<bool> _onVisibleChangeController = new StreamController();
  final StreamController<String> _onSelectedIdChangeController = new StreamController();
  final StreamController<Map> onActionButtonTriggerController = new StreamController();

  bool tooltipModalVisible = false;

  @Input('actionButtonIcon')
  String actionButtonIcon = "add";

  @Input('allowNullSelection')
  bool allowNullSelection = false;

  @Input('nullSelectionButtonText')
  String nullSelectionButtonText = "-";

  @Input('label')
  String label = "";

  @Input('disabled')
  bool disabled = false;

  @Input('fullWidth')
  bool fullWidth = false;

  @Input('options')
  StringSelectionOptions<Map> options = new StringSelectionOptions<Map>([]);

  @Input('selectedId')
  String selectedId;

  //@Input('selectedModel')
  Map selectedModel;

  @Input('showActionButton')
  bool showActionButton = false;

  @Input('showSearch')
  bool showSearch = false;

  @Input('tooltip')
  String tooltip;

  @Input('visible')
  bool visible = false;

  @Output('selectedIdChange')
  Stream<String> get onSelectedIdChangeOutput => _onSelectedIdChangeController.stream;

  @Output('actionButtonTrigger')
  Stream<Map> get onActionButtonTriggerOutput => onActionButtonTriggerController.stream;

  @Output('visibleChange')
  Stream<bool> get onVisibleChangeOutput => _onVisibleChangeController.stream;
}