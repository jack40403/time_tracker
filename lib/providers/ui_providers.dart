import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StatsOffsetNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void setOffset(int val) => state = val;
  void reset() => state = 0;
}

final statsOffsetProvider = NotifierProvider<StatsOffsetNotifier, int>(() => StatsOffsetNotifier());

class StatsFilterNotifier extends Notifier<String> {
  @override
  String build() => 'daily';
  void setFilter(String val) {
    if (state != val) {
      state = val;
      ref.read(statsOffsetProvider.notifier).reset();
    }
  }
}

final statsFilterProvider = NotifierProvider<StatsFilterNotifier, String>(() => StatsFilterNotifier());

class StatsCustomRangeNotifier extends Notifier<DateTimeRange?> {
  @override
  DateTimeRange? build() => null;
  void setRange(DateTimeRange? range) => state = range;
}

final statsCustomRangeProvider = NotifierProvider<StatsCustomRangeNotifier, DateTimeRange?>(() => StatsCustomRangeNotifier());

class HistoryOffsetNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void setOffset(int val) => state = val;
}

final historyOffsetProvider = NotifierProvider<HistoryOffsetNotifier, int>(() => HistoryOffsetNotifier());

class HistoryFilterNotifier extends Notifier<String> {
  @override
  String build() => 'daily';
  void setFilter(String val) {
    if (state != val) {
      state = val;
      ref.read(historyOffsetProvider.notifier).setOffset(0);
    }
  }
}

final historyFilterProvider = NotifierProvider<HistoryFilterNotifier, String>(() => HistoryFilterNotifier());

class HistoryCustomRangeNotifier extends Notifier<DateTimeRange?> {
  @override
  DateTimeRange? build() => null;
  void setRange(DateTimeRange? range) => state = range;
}

final historyCustomRangeProvider = NotifierProvider<HistoryCustomRangeNotifier, DateTimeRange?>(() => HistoryCustomRangeNotifier());

class HistoryCategoryFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void setCategory(String? cat) => state = cat;
}

final historyCategoryFilterProvider = NotifierProvider<HistoryCategoryFilterNotifier, String?>(() => HistoryCategoryFilterNotifier());

class StatsCategoryFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void setCategory(String? cat) => state = cat;
}

final statsCategoryFilterProvider = NotifierProvider<StatsCategoryFilterNotifier, String?>(() => StatsCategoryFilterNotifier());
