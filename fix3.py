import re

with open('lib/pages/history_page.dart', 'rb') as f:
    text = f.read().decode('utf-8', 'ignore')

lines = text.split('\n')

def replace_line(num, new_text):
    if num - 1 < len(lines):
        lines[num - 1] = new_text

replace_line(286, "                  _buildFilterChip('daily', '每日', filter, ref),")
replace_line(287, "                  _buildFilterChip('weekly', '每週', filter, ref),")
replace_line(288, "                  _buildFilterChip('monthly', '每月', filter, ref),")
replace_line(289, "                  _buildFilterChip('yearly', '每年', filter, ref),")
replace_line(297, "              Text(_getOffsetText(filter, offset), style: const TextStyle(fontWeight: FontWeight.bold)),")
replace_line(399, "}")

with open('lib/pages/history_page.dart', 'w', encoding='utf-8') as f:
    f.write('\n'.join(lines))

print('Done')
