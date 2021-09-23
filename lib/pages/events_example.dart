// Copyright 2019 Aleksander Woźniak
// SPDX-License-Identifier: Apache-2.0

import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import "package:collection/collection.dart";
import 'package:intl/intl.dart';

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:http/http.dart' as http;

import '../utils.dart';

class TableEventsExample extends StatefulWidget {
  @override
  _TableEventsExampleState createState() => _TableEventsExampleState();
}

class _TableEventsExampleState extends State<TableEventsExample> {
  late final ValueNotifier<List<Event>> _selectedEvents;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  RangeSelectionMode _rangeSelectionMode = RangeSelectionMode
      .toggledOff; // Can be toggled on/off by longpressing a date
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  Map<String, List<Event>> _eventsByDates = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _selectedEvents = ValueNotifier(_getEventsForDay(_selectedDay!));

    _getEventsForMonth();
  }

  Future<void> _getEventsForMonth() async {
    // ppservice.qima.com
    // localhost:8000
    final response = await http
        .get(
        Uri.parse('http://ppservice.qima.com/psi-service/search/order-products/list?param=%7B%22pageNo%22:1,%22pageSize%22:100,%22isShowAll%22:false,%22criterias%22:%7B%22INSPECTION_DATE%22:%5B%222021-09-01%20-%202021-09-30%22%5D,%22STATUS%22:%5B%2240%22%5D,%22HAS_FULL_ACCESS%22:%5B%22true%22%5D,%22DEPARTMENT_ID%22:%5B%2213%22%5D,%22ROLES%22:%5B%22airp_monitor%22,%22data%20exporter%22,%22admin%22,%22accounting%22,%22inspector%22,%22protocol%20leader%22,%22sales%22,%22super%20reader%22,%22proqc%20supervisor%22,%22general%20reader%22,%22wordipadmin%22,%22coordination%20team%22,%22sample%20team%22,%22operation%20manager%22,%22report%20team%22,%22helpdeskadmin%22,%22protocol%20team%22,%22report%20manager%22,%22ka%20team%22,%22super%20editor%22%5D,%22ORDER-SCOPE%22:%5B%22PENDING%22%5D,%22SHOW_TEST_ORDER%22:%5B%22N%22%5D,%22USER_ID%22:%5B%22B5B66AB88BCA2FC948258611001584A9%22%5D%7D,%22orderItems%22:%5B%22businessUnit%22%5D,%22desc%22:true%7D')
    );

    if (response.statusCode == 200) {
      // If the server did return a 200 OK response,
      // then parse the JSON.
      Map<String, dynamic> results = jsonDecode(response.body);
      List<dynamic> orders = results['pageItems'];

      // return Album.fromJson(jsonDecode(response.body));

      List<Event> events = List.from(orders.map((item) => new Event(item['orderNumber'], item['inspectionDate'])));

      _eventsByDates = groupBy(events, (e) => e.inspectionDate);

      setState(() {
        _selectedDay = _focusedDay;
      });
      _selectedEvents.value = _getEventsForDay(_focusedDay);
    } else {
      // If the server did not return a 200 OK response,
      // then throw an exception.
      throw Exception('Failed to load album');
    }
  }

  @override
  void dispose() {
    _selectedEvents.dispose();
    super.dispose();
  }

  List<Event> _getEventsForDay(DateTime day) {
    // Implementation example
    return _eventsByDates[DateFormat('dd-MMM-yyyy').format(day)] ?? [];
  }

  List<Event> _getEventsForRange(DateTime start, DateTime end) {
    // Implementation example
    final days = daysInRange(start, end);

    return [
      for (final d in days) ..._getEventsForDay(d),
    ];
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
        _rangeStart = null; // Important to clean those
        _rangeEnd = null;
        _rangeSelectionMode = RangeSelectionMode.toggledOff;
      });

      _selectedEvents.value = _getEventsForDay(selectedDay);
    }
  }

  void _onRangeSelected(DateTime? start, DateTime? end, DateTime focusedDay) {
    setState(() {
      _selectedDay = null;
      _focusedDay = focusedDay;
      _rangeStart = start;
      _rangeEnd = end;
      _rangeSelectionMode = RangeSelectionMode.toggledOn;
    });

    // `start` or `end` could be null
    if (start != null && end != null) {
      _selectedEvents.value = _getEventsForRange(start, end);
    } else if (start != null) {
      _selectedEvents.value = _getEventsForDay(start);
    } else if (end != null) {
      _selectedEvents.value = _getEventsForDay(end);
    }
  }

  @override
  Widget build(BuildContext context) {
    // return FutureBuilder(
    //   future: _getEventsForMonth(),
    //   builder: (BuildContext context, AsyncSnapshot snapshot) {
        return Scaffold(
          appBar: AppBar(
            title: Text('QIMA Inspection Calendar'),
          ),
          body: Column(
            children: [
              TableCalendar<Event>(
                firstDay: kFirstDay,
                lastDay: kLastDay,
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                rangeStartDay: _rangeStart,
                rangeEndDay: _rangeEnd,
                calendarFormat: _calendarFormat,
                rangeSelectionMode: _rangeSelectionMode,
                eventLoader: _getEventsForDay,
                startingDayOfWeek: StartingDayOfWeek.monday,
                calendarStyle: CalendarStyle(
                  // Use `CalendarStyle` to customize the UI
                  outsideDaysVisible: false,
                  markerDecoration: const BoxDecoration(
                    color: Color(0xFFFF8A80),
                    shape: BoxShape.circle,
                  ),
                  todayDecoration: const BoxDecoration(
                    color: Color(0xFFFF8A80),
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                  )
                ),
                onDaySelected: _onDaySelected,
                onRangeSelected: _onRangeSelected,
                onFormatChanged: (format) {
                  if (_calendarFormat != format) {
                    setState(() {
                      _calendarFormat = format;
                    });
                  }
                },
                onPageChanged: (focusedDay) {
                  _focusedDay = focusedDay;
                },
              ),
              const SizedBox(height: 8.0),
              Expanded(
                child: ValueListenableBuilder<List<Event>>(
                  valueListenable: _selectedEvents,
                  builder: (context, value, _) {
                    return ListView.builder(
                      itemCount: value.length,
                      itemBuilder: (context, index) {
                        return Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12.0,
                            vertical: 4.0,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.redAccent),
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          child: ListTile(
                            onTap: () => print('${value[index]}'),
                            title: Text('${value[index]}'),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
    //   }
    // );
  }
}
