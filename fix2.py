import re

with open('lib/pages/history_page.dart', 'rb') as f:
    text = f.read().decode('utf-8', 'ignore')

lines = text.split('\n')

def replace_line(num, new_text):
    if num - 1 < len(lines):
        lines[num - 1] = new_text

replace_line(93, "                Text('手動新增紀錄', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold)),")
replace_line(97, "                    Text('選擇分類', style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),")
replace_line(119, "                    Text('選擇日期', style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),")
replace_line(150, "                    Text('開始時間', style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),")
replace_line(175, "                    Text('結束時間', style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),")
replace_line(218, "                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('錯誤：結束時間必須晚於開始時間'), behavior: SnackBarBehavior.floating));")
replace_line(231, "                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已成功新增紀錄', style: TextStyle(fontSize: 18)), behavior: SnackBarBehavior.floating));")
replace_line(238, "                        child: const Text('新增紀錄', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),")
replace_line(266, "        title: Text('歷史紀錄', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),")
replace_line(271, "        label: const Text('手動新增'),")
replace_line(304, "            child: sortedDates.isEmpty ? Center(child: Text('沒有紀錄', style: TextStyle(color: Colors.grey.shade400))) : ListView.builder(")
replace_line(321, "                                Text('總計 ${_formatTime(dailyTotal)}', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 16)),")
replace_line(338, "                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已刪除紀錄')));")

# Write back
with open('lib/pages/history_page.dart', 'w', encoding='utf-8') as f:
    f.write('\n'.join(lines))

print('Done')
