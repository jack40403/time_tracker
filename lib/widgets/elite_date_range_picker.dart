import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;

class EliteDateRangePicker extends StatefulWidget {
  final DateTimeRange? initialDateRange;
  final DateTime firstDate;
  final DateTime lastDate;

  const EliteDateRangePicker({
    super.key,
    this.initialDateRange,
    required this.firstDate,
    required this.lastDate,
  });

  static Future<DateTimeRange?> show(
    BuildContext context, {
    DateTimeRange? initialDateRange,
    DateTime? firstDate,
    DateTime? lastDate,
  }) {
    return showDialog<DateTimeRange>(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => EliteDateRangePicker(
        initialDateRange: initialDateRange,
        firstDate: firstDate ?? DateTime(2000),
        lastDate: lastDate ?? DateTime.now(),
      ),
    );
  }

  @override
  State<EliteDateRangePicker> createState() => _EliteDateRangePickerState();
}

class _EliteDateRangePickerState extends State<EliteDateRangePicker> {
  late DateTime _currentMonth;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isMonthYearSelection = false;

  final List<String> _weekdays = ['一', '二', '三', '四', '五', '六', '日'];
  final List<String> _months = ['1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月', '9月', '10月', '11月', '12月'];

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialDateRange?.start;
    _endDate = widget.initialDateRange?.end;
    _currentMonth = DateTime((_startDate ?? DateTime.now()).year, (_startDate ?? DateTime.now()).month);
  }

  void _onDateSelected(DateTime date) {
    setState(() {
      if (_startDate == null || (_startDate != null && _endDate != null)) {
        _startDate = date;
        _endDate = null;
      } else {
        if (date.isBefore(_startDate!)) {
          _endDate = _startDate;
          _startDate = date;
        } else {
          _endDate = date;
        }
      }
    });
  }

  void _changeMonth(int offset) {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + offset);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWeb = MediaQuery.of(context).size.width > 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: isWeb ? 40 : 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 800, maxHeight: 900),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withOpacity(0.95),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 40, spreadRadius: 0),
            ],
            border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(theme),
              const Divider(height: 1),
              Expanded(
                child: _isMonthYearSelection ? _buildMonthYearPicker(theme) : _buildCalendar(theme),
              ),
              const Divider(height: 1),
              _buildFooter(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.05),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildDateLabel('開始日期', _startDate, theme),
          Icon(Icons.arrow_forward_rounded, color: theme.colorScheme.primary.withOpacity(0.3), size: 32),
          _buildDateLabel('結束日期', _endDate, theme),
        ],
      ),
    );
  }

  Widget _buildDateLabel(String label, DateTime? date, ThemeData theme) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14)),
        const SizedBox(height: 8),
        Text(
          date == null ? '未選擇' : '${date.year} / ${date.month} / ${date.day}',
          style: GoogleFonts.shareTechMono(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: date == null ? theme.colorScheme.onSurfaceVariant.withOpacity(0.5) : theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildCalendar(ThemeData theme) {
    return Column(
      children: [
        _buildCalendarHeader(theme),
        _buildWeekdays(theme),
        Expanded(
          child: GestureDetector(
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity! > 0) _changeMonth(-1);
              if (details.primaryVelocity! < 0) _changeMonth(1);
            },
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                childAspectRatio: 1.0,
              ),
              itemCount: _daysInMonth(_currentMonth) + _firstWeekdayOfMonth(_currentMonth) - 1,
              itemBuilder: (context, index) {
                final firstWeekday = _firstWeekdayOfMonth(_currentMonth);
                if (index < firstWeekday - 1) return const SizedBox();

                final day = index - firstWeekday + 2;
                final date = DateTime(_currentMonth.year, _currentMonth.month, day);
                return _buildDayCell(date, theme);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(icon: const Icon(Icons.chevron_left_rounded, size: 32), onPressed: () => _changeMonth(-1)),
          InkWell(
            onTap: () => setState(() => _isMonthYearSelection = true),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '${_currentMonth.year} 年 ${_currentMonth.month} 月',
                style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          IconButton(icon: const Icon(Icons.chevron_right_rounded, size: 32), onPressed: () => _changeMonth(1)),
        ],
      ),
    );
  }

  Widget _buildWeekdays(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: _weekdays.map((d) => Text(d, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold, fontSize: 16))).toList(),
      ),
    );
  }

  Widget _buildDayCell(DateTime date, ThemeData theme) {
    final bool isStart = _startDate != null && _isSameDay(date, _startDate!);
    final bool isEnd = _endDate != null && _isSameDay(date, _endDate!);
    final bool isInRange = _startDate != null && _endDate != null && date.isAfter(_startDate!) && date.isBefore(_endDate!);
    final bool isToday = _isSameDay(date, DateTime.now());

    Color? textColor = theme.colorScheme.onSurface;
    BoxDecoration? decoration;

    if (isStart || isEnd) {
      textColor = Colors.white;
      decoration = BoxDecoration(
        color: theme.colorScheme.primary,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: theme.colorScheme.primary.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      );
    } else if (isInRange) {
      decoration = BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.15),
        // Connect range visuals
      );
    }

    return InkWell(
      onTap: () => _onDateSelected(date),
      borderRadius: BorderRadius.circular(50),
      child: Container(
        alignment: Alignment.center,
        margin: const EdgeInsets.all(2),
        decoration: decoration,
        child: Text(
          '${date.day}',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: isStart || isEnd || isToday ? FontWeight.bold : FontWeight.normal,
            color: textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildMonthYearPicker(ThemeData theme) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('選擇年份與月份', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => setState(() => _isMonthYearSelection = false)),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              // Year list
              Expanded(
                flex: 1,
                child: ListView.builder(
                  itemCount: widget.lastDate.year - widget.firstDate.year + 1,
                  itemBuilder: (context, index) {
                    final year = widget.lastDate.year - index;
                    final isSelected = year == _currentMonth.year;
                    return InkWell(
                      onTap: () => setState(() => _currentMonth = DateTime(year, _currentMonth.month)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        color: isSelected ? theme.colorScheme.primary.withOpacity(0.1) : null,
                        alignment: Alignment.center,
                        child: Text(
                          '$year',
                          style: TextStyle(fontSize: 18, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? theme.colorScheme.primary : null),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const VerticalDivider(width: 1),
              // Month grid
              Expanded(
                flex: 2,
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 1.5,
                  ),
                  itemCount: 12,
                  itemBuilder: (context, index) {
                    final month = index + 1;
                    final isSelected = month == _currentMonth.month;
                    return InkWell(
                      onTap: () => setState(() {
                        _currentMonth = DateTime(_currentMonth.year, month);
                        _isMonthYearSelection = false;
                      }),
                      child: Container(
                        alignment: Alignment.center,
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isSelected ? theme.colorScheme.primary : null,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _months[index],
                          style: TextStyle(fontSize: 16, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.white : null),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 16),
          FilledButton(
            onPressed: (_startDate != null && _endDate != null) ? () {
              Navigator.pop(context, DateTimeRange(start: _startDate!, end: _endDate!));
            } : null,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('確定', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  int _daysInMonth(DateTime date) => DateTime(date.year, date.month + 1, 0).day;
  int _firstWeekdayOfMonth(DateTime date) => DateTime(date.year, date.month, 1).weekday;
  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}
