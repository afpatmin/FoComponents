// Copyright (c) 2017, Minoch AB. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:html' as dom;
import 'dart:math';
import 'package:angular/angular.dart';
import 'package:angular_components/angular_components.dart';
import 'package:fo_model/fo_model.dart';
import '../../pipes/fo_name_pipe.dart';
import '../../pipes/range_pipe.dart';
import '../../services/fo_messages_service.dart';
import '../fo_modal/fo_modal_component.dart';
import '../fo_select/fo_select_component.dart';

/// Callback function for evaluated columns
typedef Object EvaluateColumnFn(Object model);
typedef Future<Object> AsyncEvaluateColumnFn(Object model);

typedef String ErrorFn(Object model);

@Component(
    selector: 'fo-data-table',
    styleUrls: const ['fo_data_table_component.css'],
    templateUrl: 'fo_data_table_component.html',
    directives: const <dynamic>[
      coreDirectives,
      FoModalComponent,
      FoSelectComponent,
      materialDirectives,
      MaterialIconComponent
    ],
    pipes: const [NamePipe, RangePipe],
    changeDetection: ChangeDetectionStrategy.OnPush)
class FoDataTableComponent implements OnChanges, OnInit, OnDestroy {
  FoDataTableComponent(this.host, this._changeDetector, this.msg);

  @override
  void ngOnInit() {
    selectedRowOptionId = rowOptions
        .firstWhere((r) => r.id == rows, orElse: () => rowOptions.first)
        .id;
    firstIndex = 0;
    lastIndex = _selectedRowOption.id;
  }

  @override
  void ngOnChanges(Map<String, SimpleChange> changes) {
    _evaluatedColumnsBuffer.clear();
    allEvaluatedColumns = evaluatedColumns.keys.toList()
      ..addAll(asyncEvaluatedColumns.keys);

    _filteredKeys = new List.from(data.keys);

    if (changes.containsKey('rows') || changes.containsKey('data')) {
      data ??= {};

      selectedRowOptionId = rowOptions
          .firstWhere((r) => r.id == rows, orElse: () => rowOptions.first)
          .id;

      onSearch();
      setIndices(0);
    }
  }

  @override
  void ngOnDestroy() {
    onAddController.close();
    onDeleteController.close();
    onRowClickController.close();
    onSelectedRowsController.close();
    _onFilterController.close();
    _onSortController.close();
    _onBatchOperationController.close();
  }

  dynamic getCell(Object id, String column) =>
      (data == null || data[id] == null)
          ? null
          : (data[id] as FoModel).toJson()[column];

  bool isBool(Object value) => value is bool;

  void step(int steps) {
    setIndices(firstIndex + (steps * _selectedRowOption.id));
  }

  void onSearchKeyUp(dom.KeyboardEvent e) {
    if (!lazyFilter) {
      onSearch();
    } else if (e.keyCode == dom.KeyCode.ENTER ||
        e.keyCode == dom.KeyCode.MAC_ENTER) {
      onSearch();
    }
  }

  void onSearch() {
    if (internalFilter && searchPhrase != null && searchPhrase.isNotEmpty) {
      bool find(Object model, List<String> keywords) {
        bool allKeywords;
        final row = json.decode(json.encode(model));
        for (final keyword in keywords) {
          allKeywords = false;
          for (final col in columns.keys) {
            final data = row[col]?.toString();
            if (data != null &&
                data.toString().toLowerCase().contains(keyword)) {
              allKeywords = true;
              break;
            }
          }
          for (final col in allEvaluatedColumns) {
            final r = _evaluatedColumnsBuffer[row['id']];
            final data = (r?.containsKey(col) == true) ? r[col] : null;
            if (data != null &&
                data.toString().toLowerCase().contains(keyword)) {
              allKeywords = true;
              break;
            }
          }
          if (allKeywords == false) {
            return false;
          }
        }
        return true;
      }

      final keywords = searchPhrase.toLowerCase().split(' ');
      _filteredKeys = data.keys.where((key) => find(data[key], keywords));
    } else
      _filteredKeys = null;

    _onFilterController.add(searchPhrase);
    setIndices(0);
  }

  void onSort(String column) {
    if (!disabled && column != null) {
      sortColumn = column;
      sortOrder = (sortOrder == 'ASC') ? 'DESC' : 'ASC';
      _onSortController.add({
        'column': sortColumn,
        'order': sortOrder,
        'internal': internalSort ||
            evaluatedColumns.containsKey(column) ||
            asyncEvaluatedColumns.containsKey(column)
      });

      searchPhrase = null;
      _filteredKeys = null;

      /// Evaluated columns are always sorted internally
      if (internalSort ||
          evaluatedColumns.containsKey(column) ||
          asyncEvaluatedColumns.containsKey(column)) {
        int sort(Object a, Object b) {
          final vA = a == null ? '-' : a.toString();
          final vB = b == null ? '-' : b.toString();
          try {
            // Number comparison
            final numA = num.parse(vA);
            final numB = num.parse(vB);
            return (sortOrder == 'ASC')
                ? (numA - numB).toInt()
                : (numB - numA).toInt();
          } on FormatException {
            try {
              // Date comparison
              final dateA = DateTime.parse(vA);
              final dateB = DateTime.parse(vB);
              return (sortOrder == 'ASC')
                  ? dateA.difference(dateB).inMilliseconds
                  : dateB.difference(dateA).inMilliseconds;
            } on FormatException {
              // Default String comparison
              final colA = a.toString().toLowerCase();
              final colB = b.toString().toLowerCase();

              return (sortOrder == 'ASC')
                  ? colA.compareTo(colB)
                  : colB.compareTo(colA);
            }
          }
        }

        final values = data.keys
            .where(filteredKeys.contains)
            .map((key) => data[key])
            .toList();

        if (values != null) {
          if (columns.keys.contains(sortColumn)) {
            values.sort((a, b) => sort(
                json.decode(json.encode(a))[sortColumn].toString(),
                json.decode(json.encode(b))[sortColumn].toString()));
          } else if (evaluatedColumns.containsKey(sortColumn)) {
            values.sort((a, b) => sort(evaluatedColumns[sortColumn](a),
                evaluatedColumns[sortColumn](b)));
          } else if (asyncEvaluatedColumns.containsKey(sortColumn)) {
            values.sort((a, b) => sort(asyncEvaluatedColumns[sortColumn](a),
                asyncEvaluatedColumns[sortColumn](b)));
          }

          _filteredKeys =
              values.map((model) => json.decode(json.encode(model))['id']);
        }
      }
    }
  }

  void onDownloadDataCSV() {
    if (data.isNotEmpty) {
      /// Generate CSV string (Property1;Property2;Property3;Property4;Property5\n)
      final sb = new StringBuffer();

      final colNames = new List.from(columns.keys)
        ..addAll(evaluatedColumns.keys);
      sb.writeln(colNames);

      for (final key in filteredKeys) {
        final model = data[key];
        if (model == null) continue;

        final row = json.decode(json.encode(model));

        final properties = columns.keys.map((col) => row[col]).toList()
          ..addAll(
              evaluatedColumns.keys.map((id) => evaluatedColumns[id](model)));

        /// Add "'"-character if ¨the cell has a leading '0'-character. This will stop Excel from skipping leading 0
        for (var property in properties) {
          try {
            var strProperty = property.toString();
            num.parse(strProperty);
            if (strProperty.startsWith('0')) {
              strProperty = '="$strProperty"';
            }
          } on FormatException {
            /* Not a number, continue */
          }
        }

        sb.writeln(properties.join(';'));
      }

      final csv = Uri.encodeComponent(sb.toString());

      /* UTF-8 BOM */
      new dom.AnchorElement(href: 'data:text/csv;charset=utf-8,\uFEFF$csv')
        ..setAttribute('download', 'data.csv')
        ..click();
    }
  }

  void setIndices(int inFirstIndex) {
    if (inFirstIndex <= -(_selectedRowOption.id as int) ||
        inFirstIndex >= data.length) return;

    firstIndex = max(0, inFirstIndex);
    if (searchPhrase != null && searchPhrase.isNotEmpty)
      firstIndex =
          max(0, min(firstIndex, filteredKeys.length - _selectedRowOption.id));
    lastIndex = firstIndex + _selectedRowOption.id;

    currentPage = (data.isEmpty)
        ? 0
        : (firstIndex.toDouble() / _selectedRowOption.id).ceil() + 1;
  }

  int get totalPages =>
      (filteredKeys.length.toDouble() / _selectedRowOption.id).ceil();

  bool get lazyFilter =>
      data == null || !internalFilter || data.length < liveSearchThreshold;

  final List<FoModel> rowOptions = [
    new FoModel()..id = 5,
    new FoModel()..id = 10,
    new FoModel()..id = 15,
    new FoModel()..id = 20,
    new FoModel()..id = 25,
    new FoModel()..id = 50,
    new FoModel()..id = 100,
    new FoModel()..id = 1000
  ];

  void onCheckedChange(Object id, bool state) {
    if (state)
      selectedRows.add(id);
    else
      selectedRows.remove(id);
    onSelectedRowsController.add(selectedRows);
  }

  void onBatchOperationTrigger(String event) {
    _onBatchOperationController
        .add(new BatchOperationEvent(event, new Set.from(selectedRows)));

    allChecked = false;
  }

  bool get allChecked => _allChecked;

  set allChecked(bool state) {
    _allChecked = state;
    if (_allChecked)
      selectedRows = filteredKeys
          .where((o) => errorFunction == null || errorFunction(data[o]) == null)
          .toSet();
    else
      selectedRows.clear();
  }

  String get filterLabel => lazyFilter ? msg.filter_enter() : msg.filter();

  Iterable<Object> get filteredKeys =>
      _filteredKeys == null ? data.keys : _filteredKeys;

  int get selectedRowOptionId => _selectedRowOption?.id;

  set selectedRowOptionId(int value) {
    _selectedRowOption = rowOptions.firstWhere((row) => row.id == value,
        orElse: () => rowOptions.first);
  }

  FoModel _selectedRowOption;
  Object deleteBufferId;
  int firstIndex = 0;
  int lastIndex = 1;
  int currentPage = 1;
  String searchPhrase = '';
  Iterable<Object> _filteredKeys;
  bool infoModalOpen = false;
  bool _allChecked;

  final dom.Element host;
  final int liveSearchThreshold = 500;
  final StreamController<String> onAddController = new StreamController();
  final StreamController<Set<Object>> onSelectedRowsController =
      new StreamController();
  final StreamController<Object> onDeleteController = new StreamController();
  final StreamController<String> _onFilterController = new StreamController();
  final StreamController<Object> onRowClickController = new StreamController();
  final StreamController<Map<String, dynamic>> _onSortController =
      new StreamController();
  final StreamController<BatchOperationEvent> _onBatchOperationController =
      new StreamController();

  final ChangeDetectorRef _changeDetector;

  Iterable<String> allEvaluatedColumns = [];
  final Map<Object, Map<String, Object>> _evaluatedColumnsBuffer = {};

  Object getEvaluatedColumn(Object row, String col) {
    if (_evaluatedColumnsBuffer[row] == null) {
      _evaluatedColumnsBuffer[row] = {};
    }

    if (!_evaluatedColumnsBuffer[row].containsKey(col)) {
      if (evaluatedColumns.containsKey(col)) {
        _evaluatedColumnsBuffer[row][col] = evaluatedColumns[col](data[row]);
        //_changeDetector.markForCheck();
      } else {
        _evaluatedColumnsBuffer[row][col] = null;
        asyncEvaluatedColumns[col](data[row]).then((v) {
          if (_evaluatedColumnsBuffer?.containsKey(row) == true &&
              _evaluatedColumnsBuffer[row] != null) {
            _evaluatedColumnsBuffer[row][col] = v;
            //_changeDetector.markForCheck();
          }
        });
      }
    }
    return _evaluatedColumnsBuffer[row][col];
  }

  final FoMessagesService msg;

  @Input()
  bool internalSort = true;

  @Input()
  bool internalFilter = true;

  @Input('large-hidden-col')
  Iterable<Object> largeHiddenCol = [];

  @Input('small-hidden-col')
  Iterable<Object> smallHiddenCol = [];

  @Input('medium-hidden-col')
  Iterable<Object> mediumHiddenCol = [];

  @Input()
  String sortColumn = '';

  @Input()
  String sortOrder = 'DESC';

  @Input()
  Map<Object, Object> data = {};

  @Input()
  Map<String, String> columns = {};

  @Input()
  Map<String, EvaluateColumnFn> evaluatedColumns = {};

  @Input()
  Map<String, AsyncEvaluateColumnFn> asyncEvaluatedColumns = {};

  @Input()
  ErrorFn errorFunction; // = ((model) => null);

  @Input()
  bool showAddButton = false;

  @Input()
  bool showCheckboxes = false;

  @Input()
  List<FoModel> batchOperations;

  @Input()
  bool showDeleteButtons = false;

  @Input()
  bool showDownloadButton = true;

  @Input()
  String label = '';

  @Input()
  String description;

  @Input()
  Set<Object> selectedRows = new Set();

  @Input()
  int rows = 10;

  @Input()
  bool disabled = false;

  @Output('add')
  Stream<String> get onAddOutput => onAddController.stream;

  @Output('delete')
  Stream<Object> get onDeleteOutput => onDeleteController.stream;

  @Output('filter')
  Stream<String> get onFilterOutput => _onFilterController.stream;

  @Output('rowclick')
  Stream<Object> get onRowClickOutput => onRowClickController.stream;

  @Output('selectedRowsChange')
  Stream<Set<Object>> get selectedRowsChange => onSelectedRowsController.stream;

  @Output('sort')
  Stream<Map<String, dynamic>> get onSortOutput => _onSortController.stream;

  @Output('batchOperation')
  Stream<BatchOperationEvent> get onBatchOperationOutput =>
      _onBatchOperationController.stream;
}

/// Batch Operation Event, spawned as output whenever the user performs a batch action on the table
class BatchOperationEvent {
  /// Default constructor
  BatchOperationEvent(this.operation, this.selectedIds);

  /// The operation name
  final String operation;

  /// Selected ids whenever the user invoked batch operation
  final Set<Object> selectedIds;
}
