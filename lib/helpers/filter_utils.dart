import 'package:flutter/material.dart';
import '../models/time_session.dart';

class FilterUtils {
  static List<TimeSession> getFilteredSessions(
    List<TimeSession> sessions,
    String filter,
    int offset,
    DateTimeRange? customRange,
  ) {
    if (filter == 'custom' && customRange != null) {
      final start = DateTime(customRange.start.year, customRange.start.month, customRange.start.day);
      final end = DateTime(customRange.end.year, customRange.end.month, customRange.end.day, 23, 59, 59);
      return sessions.where((s) => s.date.isAfter(start.subtract(const Duration(seconds: 1))) && s.date.isBefore(end.add(const Duration(seconds: 1)))).toList();
    }

    final now = DateTime.now();
    if (filter == 'daily') {
      final target = now.subtract(Duration(days: offset));
      return sessions.where((s) {
        final sDate = s.date.toLocal();
        return sDate.year == target.year && sDate.month == target.month && sDate.day == target.day;
      }).toList();
    } else if (filter == 'weekly') {
      final targetDate = now.subtract(Duration(days: offset * 7));
      final mon = targetDate.subtract(Duration(days: targetDate.weekday - 1));
      final sun = mon.add(const Duration(days: 6));
      final start = DateTime(mon.year, mon.month, mon.day);
      final end = DateTime(sun.year, sun.month, sun.day, 23, 59, 59);
      return sessions.where((s) => s.date.isAfter(start.subtract(const Duration(seconds: 1))) && s.date.isBefore(end.add(const Duration(seconds: 1)))).toList();
    } else if (filter == 'monthly') {
      final targetMonth = DateTime(now.year, now.month - offset);
      return sessions.where((s) => s.date.year == targetMonth.year && s.date.month == targetMonth.month).toList();
    } else if (filter == 'yearly') {
      final targetYear = now.year - offset;
      return sessions.where((s) => s.date.year == targetYear).toList();
    }
    return sessions;
  }

  static String getFilterLabel(String filter, int offset, DateTimeRange? customRange) {
    if (filter == 'custom' && customRange != null) {
      return '${customRange.start.month}/${customRange.start.day} - ${customRange.end.month}/${customRange.end.day}';
    }
    if (filter == 'custom') return '選擇區間';

    if (offset == 0) return filter == 'daily' ? '今天' : filter == 'weekly' ? '本週' : filter == 'monthly' ? '本月' : '今年';
    if (offset == 1) return filter == 'daily' ? '昨天' : filter == 'weekly' ? '上週' : filter == 'monthly' ? '上個月' : '去年';
    
    final now = DateTime.now();
    if (filter == 'daily') {
        final target = now.subtract(Duration(days: offset));
        return '${target.month}/${target.day}';
    } else if (filter == 'weekly') {
        final targetDate = now.subtract(Duration(days: offset * 7));
        final mon = targetDate.subtract(Duration(days: targetDate.weekday - 1));
        final sun = mon.add(const Duration(days: 6));
        return '${mon.month}/${mon.day} - ${sun.month}/${sun.day}';
    } else if (filter == 'monthly') {
        final targetMonth = DateTime(now.year, now.month - offset);
        return '${targetMonth.year}/${targetMonth.month}';
    } else {
        final targetYear = now.year - offset;
        return '${targetYear}年';
    }
  }
}
