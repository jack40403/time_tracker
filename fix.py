import re

with open('lib/pages/history_page.dart', 'rb') as f:
    text = f.read().decode('utf-8', 'ignore')

text = re.sub(r"title: Text\('歷史?[^,]*, style:", "title: Text('歷史紀錄', style:", text)
text = re.sub(r"label: const Text\('[^']*'\),", "label: const Text('手動新增'),", text)
text = re.sub(r"_buildFilterChip\('daily', '[^']*', filter, ref\)", "_buildFilterChip('daily', '每日', filter, ref)", text)
text = re.sub(r"_buildFilterChip\('weekly', '[^']*', filter, ref\)", "_buildFilterChip('weekly', '每週', filter, ref)", text)
text = re.sub(r"_buildFilterChip\('monthly', '[^']*', filter, ref\)", "_buildFilterChip('monthly', '每月', filter, ref)", text)
text = re.sub(r"_buildFilterChip\('yearly', '[^']*', filter, ref\)", "_buildFilterChip('yearly', '每年', filter, ref)", text)
text = re.sub(r"Text\('沒有?[^']*', style: TextStyle\(color: Colors\.grey\.shade400\)\)\)", "Text('沒有紀錄', style: TextStyle(color: Colors.grey.shade400)))", text)
text = re.sub(r"Text\('已?[^']*'\)\)\);", "Text('已刪除'))));", text)
text = re.sub(r"Text\('總計 \$\{_formatTime\(dailyTotal\)\}", "Text('總計 ${_formatTime(dailyTotal)}'", text)
text = re.sub(r"if \(offset == 0\) return filter == 'daily' \? '[^']*' : filter == 'weekly' \? '[^']*' : filter == 'monthly' \? '[^']*' : '[^']*';", "if (offset == 0) return filter == 'daily' ? '今天' : filter == 'weekly' ? '本週' : filter == 'monthly' ? '本月' : '今年';", text)
text = re.sub(r"return filter == 'daily' \? '[^']* \$\{target\.month\}/.*?;", "return filter == 'daily' ? '${target.month}/${target.day}' : filter == 'weekly' ? '${mon.month}/${mon.day} - ${sun.month}/${sun.day}' : filter == 'monthly' ? '${targetMonth.year}/${targetMonth.month}' : '${targetYear}年';", text)

with open('lib/pages/history_page.dart', 'w', encoding='utf-8') as f:
    f.write(text)

print('Done')
