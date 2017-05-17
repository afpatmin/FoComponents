// Copyright (c) 2017, Muienog AB. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library data_table_component;

import 'dart:async' show Future, Stream, StreamController;
import 'dart:math';
import 'dart:collection' show LinkedHashMap;
import 'package:angular2/angular2.dart';
import 'package:angular_components/angular_components.dart';
import 'package:fo_components/pipes/range_pipe.dart';
import 'package:fo_components/data_table_model.dart';

@Component(
    selector: 'fo-data-table',
    styleUrls: const ['data_table_component.css'],
    templateUrl: 'data_table_component.html',
    directives: const [materialDirectives],
    changeDetection: ChangeDetectionStrategy.OnPush,
    pipes: const [UpperCasePipe, RangePipe])

class DataTableComponent implements OnDestroy
{
  DataTableComponent()
  {
    updateFilter();
  }

  void ngOnDestroy()
  {
    onCellClickController.close();
    onRowClickController.close();
    _onSortController.close();
  }

  void step(int steps)
  {
    if (!_disabled && (firstIndex + _numRows < _data.length || steps < 0)) _setIndices(firstIndex + (steps * _numRows));
  }

  void onSort(String column)
  {
    if (!_disabled)
    {
      sortColumn = column;
      sortOrder = (sortOrder == "ASC") ? "DESC" : "ASC";
      _sort();
    }
  }

  void updateFilter()
  {
    _filteredData.clear();
    if (searchPhrase.isEmpty) _filteredData = new List.from(_data);
    else
    {
      List<String> keywordList = searchPhrase.split(" ");

      _filteredData = _data.where((m) => _find(keywordList, m)).toList(growable: false);

    }
  }

  void _sort()
  {
    int sortFn(Map<String, String> a, Map<String, String> b, String column, String order)
    {
      try
      {
        // Number comparison
        num numA = num.parse(a[column]);
        num numB = num.parse(b[column]);
        return (order == "ASC") ? (numA - numB).toInt() : (numB - numA).toInt();
      }
      on FormatException
      {
        try
        {
          // Date comparison
          DateTime dateA = DateTime.parse(a[column]);
          DateTime dateB = DateTime.parse(b[column]);
          return (order == "ASC") ? (dateA.difference(dateB)).inMinutes : (dateB.difference(dateA)).inMinutes;
        }
        on FormatException
        {
          // Default String comparison
          return (order == "ASC") ? a[column].compareTo(b[column]) : b[column].compareTo(a[column]);
        }
      }
    }

    LinkedHashMap<String, DataTableModel> bufferMap = new LinkedHashMap();
    List<DataTableModel> values = _filteredData.toList(growable: false);

    values.sort((DataTableModel a, DataTableModel b) => sortFn(a.toTableRow(), b.toTableRow(), sortColumn, sortOrder));

    for (DataTableModel value in values)
    {
      bufferMap[_filteredData.firstWhere((key) => key.toTableRow()[key]) == value];
    }
    _filteredData = bufferMap.values;

    _onSortController.add({"column":sortColumn, "order":sortOrder});
  }

  @Input('models')
  void set models(List<DataTableModel> value)
  {
    _data = value;
    if (_columns == null || _columns.isEmpty && _data != null && _data.isNotEmpty) _columns = _data.first.toTableRow().keys.toList(growable: false);
    _setIndices(firstIndex);
    updateFilter();
  }

  @Input('rows')
  void set numRows(int value)
  {
    _numRows = value;
    _setIndices(0);
  }

  @Input('disabled')
  void set disabled(bool flag) { _disabled = flag; }

  bool _find(List<String> needles, DataTableModel model)
  {
    for (String needle in needles.where((v) => v.isNotEmpty && v != ""))
    {
      if (model.toTableRow().values.where((v) => v.toLowerCase().contains(needle.toLowerCase())).isNotEmpty) return true;
    }
    return false;
  }

  void _setIndices(int first_index)
  {
    firstIndex = max(0, first_index);
    lastIndex = firstIndex + _numRows;
  }

  bool get disabled => _disabled;
  int get numRows => _numRows;
  List<String> get columns => _columns;


  @Output('cellclick')
  Stream<String> get onCellClickOutput => onCellClickController.stream;

  @Output('rowclick')
  Stream<String> get onRowClickOutput => onRowClickController.stream;

  @Output('sort')
  Stream<Map<String, String>> get onSortOutput => _onSortController.stream;

  List<DataTableModel> _data = new List();
  List<DataTableModel> _filteredData = new List();
  List<DataTableModel> get filteredData => _filteredData;

  String sortColumn = "";
  String sortOrder = "DESC";
  String searchPhrase = "";

  @Input('no-results-message')
  String noResultsMessage = "No results found";

  @Input('large-hidden-columns')
  List<String> largeHiddenColumns = [];

  @Input('medium-hidden-columns')
  List<String> mediumHiddenColumns = [];

  @Input('small-hidden-columns')
  List<String> smallHiddenColumns = [];

  @Input('title')
  String title = "";

  int firstIndex = 0;
  int lastIndex = 1;
  int _numRows = 1;
  bool _disabled = false;

  List<String> _columns = [];

  final StreamController<String> onCellClickController = new StreamController();
  final StreamController<String> onRowClickController = new StreamController();
  final StreamController<Map<String, String>> _onSortController = new StreamController();
}