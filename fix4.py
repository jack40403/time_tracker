import os

with open('lib/pages/history_page.dart', 'rb') as f:
    lines = f.read().decode('utf-8', 'ignore').split('\n')

start_idx = -1
end_idx = -1
for i, l in enumerate(lines):
    if l.strip() == 'return Scaffold(':
        start_idx = i
    if l.strip() == 'Widget _buildFilterChip(String value, String label, String currentFilter, WidgetRef ref) {':
        end_idx = i
        break

if start_idx != -1 and end_idx != -1:
    new_block = """    return Scaffold(
      appBar: AppBar(
        title: Text('歷史紀錄', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showManualAddDialog,
        icon: const Icon(Icons.add),
        label: const Text('手動新增'),
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          // Time Machine
          Center(
            child: Container(
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.all(4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildFilterChip('daily', '每日', filter, ref),
                  _buildFilterChip('weekly', '每週', filter, ref),
                  _buildFilterChip('monthly', '每月', filter, ref),
                  _buildFilterChip('yearly', '每年', filter, ref),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => ref.read(historyOffsetProvider.notifier).setOffset(offset + 1)),
              Text(_getOffsetText(filter, offset), style: const TextStyle(fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.chevron_right), onPressed: offset > 0 ? () => ref.read(historyOffsetProvider.notifier).setOffset(offset - 1) : null),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: sortedDates.isEmpty
                ? Center(child: Text('沒有紀錄', style: TextStyle(color: Colors.grey.shade400)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: sortedDates.length,
                    itemBuilder: (context, idx) {
                      final date = sortedDates[idx];
                      final dateSessions = grouped[date]!;
                      final dailyTotal = dateSessions.fold(0, (sum, s) => sum + s.durationSeconds);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 24, bottom: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(date, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                Text('總計 ${_formatTime(dailyTotal)}', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 16)),
                              ],
                            ),
                          ),
                          DayTimelineChart(
                            sessions: allSessions,
                            catColors: catColors,
                            targetDay: DateTime.parse(date),
                          ),
                          const SizedBox(height: 12),
                          ...dateSessions.map((s) {
                            final color = catColors[s.category] ?? Colors.grey;
                            return Dismissible(
                              key: ValueKey('${s.category}_${s.date.millisecondsSinceEpoch}'),
                              direction: DismissDirection.endToStart,
                              onDismissed: (_) {
                                ref.read(sessionsProvider.notifier).deleteSession(s);
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已刪除紀錄')));
                              },
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(color: Colors.red.shade400, borderRadius: BorderRadius.circular(16)),
                                child: const Icon(Icons.delete_outline, color: Colors.white),
                              ),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: Theme.of(context).colorScheme.outlineVariant)),
                                child: Row(
                                  children: [
                                    Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(s.category, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                          Text('${s.date.hour.toString().padLeft(2, '0')}:${s.date.minute.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 15, color: Colors.grey)),
                                        ],
                                      ),
                                    ),
                                    Text(_formatTime(s.durationSeconds), style: GoogleFonts.shareTechMono(fontWeight: FontWeight.bold, fontSize: 18)),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  """
    lines = lines[:start_idx] + new_block.split('\n') + lines[end_idx:]

with open('lib/pages/history_page.dart', 'w', encoding='utf-8') as f:
    f.write('\n'.join(lines))
