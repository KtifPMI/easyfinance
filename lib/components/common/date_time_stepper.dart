import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class DateTimeStepper extends StatefulWidget {
  final DateTime initial;
  final ValueChanged<DateTime> onChanged;
  const DateTimeStepper({super.key, required this.initial, required this.onChanged});

  @override
  State<DateTimeStepper> createState() => _DateTimeStepperState();
}

class _DateTimeStepperState extends State<DateTimeStepper> {
  late int _day, _month, _year, _hour, _minute;
  late DateTime _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initial;
    _day = _value.day;
    _month = _value.month;
    _year = _value.year;
    _hour = _value.hour;
    _minute = _value.minute;
  }

  int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

  void _update() {
    final d = _daysInMonth(_year, _month);
    if (_day > d) _day = d;
    _value = DateTime(_year, _month, _day, _hour, _minute);
    widget.onChanged(_value);
    setState(() {});
  }

  String _monthLabel(int m) {
    const keys = ['month.short.1', 'month.short.2', 'month.short.3', 'month.short.4', 'month.short.5', 'month.short.6', 'month.short.7', 'month.short.8', 'month.short.9', 'month.short.10', 'month.short.11', 'month.short.12'];
    return context.tr(keys[m - 1]);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _stepper('${_day.toString().padLeft(2, '0')}', () { if (_day < _daysInMonth(_year, _month)) { _day++; _update(); } }, () { if (_day > 1) { _day--; _update(); } }),
        _stepper(_monthLabel(_month).toUpperCase(), () { if (_month < 12) { _month++; _update(); } }, () { if (_month > 1) { _month--; _update(); } }),
        _stepper('$_year', () { _year++; _update(); }, () { _year--; _update(); }),
        _stepper('${_hour.toString().padLeft(2, '0')}', () { if (_hour < 23) { _hour++; _update(); } }, () { if (_hour > 0) { _hour--; _update(); } }),
        _stepper('${_minute.toString().padLeft(2, '0')}', () { if (_minute < 59) { _minute++; _update(); } }, () { if (_minute > 0) { _minute--; _update(); } }),
      ],
    );
  }

  Widget _stepper(String label, VoidCallback onUp, VoidCallback onDown) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(onTap: onUp, child: Icon(Icons.keyboard_arrow_up, size: 28, color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey)),
        Container(
          width: 52,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
        GestureDetector(onTap: onDown, child: Icon(Icons.keyboard_arrow_down, size: 28, color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey)),
      ],
    );
  }
}
