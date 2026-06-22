import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/time_session.dart';

class DayTimelineChart extends StatelessWidget {
  final List<TimeSession> sessions;
  final Map<String, Color> catColors;
  final DateTime? targetDay;

  const DayTimelineChart({
    super.key,
    required this.sessions,
    required this.catColors,
    this.targetDay,
  });

  @override
  Widget build(BuildContext context) {
    // If targetDay is provided, filter sessions by that day
    final daySessions = targetDay == null ? sessions : sessions.where((s) =>
      s.date.year == targetDay!.year &&
      s.date.month == targetDay!.month &&
      s.date.day == targetDay!.day
    ).toList();

    const secondsInDay = 86400.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline track
          LayoutBuilder(
            builder: (context, constraints) {
              final totalWidth = constraints.maxWidth;
              return SizedBox(
                height: 36,
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    // Background track (Groove look)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    // Hour dividers (every 6h)
                    ...List.generate(3, (i) {
                      final x = ((i + 1) * 6 / 24) * totalWidth;
                      return Positioned(
                        left: x,
                        top: 0,
                        bottom: 0,
                        width: 1.5,
                        child: Container(color: Colors.white.withOpacity(0.1)),
                      );
                    }),
                    // Session blocks
                    ...daySessions.map((s) {
                      if (totalWidth <= 0) return const SizedBox.shrink();
                      
                      final startSecs = s.date.hour * 3600.0 + s.date.minute * 60.0;
                      
                      final left = (startSecs / secondsInDay) * totalWidth;
                      final width = (s.durationSeconds / secondsInDay) * totalWidth;

                      final color = catColors[s.category] ?? Colors.blue;
                      
                      // Ensure a minimum visual width and a small gap
                      final visualWidth = math.max(3.0, width - 1.0);
                      
                      final endTime = s.date.add(Duration(seconds: s.durationSeconds));
                      final startStr = '${s.date.hour.toString().padLeft(2, '0')}:${s.date.minute.toString().padLeft(2, '0')}';
                      final endStr = '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';

                      return Positioned(
                        left: left + 0.5,
                        top: 2,
                        bottom: 2,
                        width: visualWidth,
                        child: Tooltip(
                          triggerMode: TooltipTriggerMode.tap,
                          preferBelow: false,
                          message: '${s.category}\n$startStr - $endStr · ${s.durationSeconds ~/ 60} 分',
                          child: Container(
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.black.withOpacity(0.15), width: 0.5),
                              boxShadow: [
                                BoxShadow(color: color.withOpacity(0.4), blurRadius: 3, offset: const Offset(0, 1)),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          // Hour labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('0:00', style: TextStyle(fontSize: 13, color: Colors.grey)),
              Text('6:00', style: TextStyle(fontSize: 13, color: Colors.grey)),
              Text('12:00', style: TextStyle(fontSize: 13, color: Colors.grey)),
              Text('18:00', style: TextStyle(fontSize: 13, color: Colors.grey)),
              Text('24:00', style: TextStyle(fontSize: 13, color: Colors.grey)),
            ],
          ),
          if (daySessions.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Center(child: Text('今日尚無專注紀錄', style: TextStyle(color: Colors.grey, fontSize: 15))),
            ),
        ],
      ),
    );
  }
}
