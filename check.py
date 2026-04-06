with open('lib/pages/history_page.dart', 'rb') as f:
    text = f.read().decode('utf-8', 'ignore')

lines = text.split('\n')
for i, line in enumerate(lines):
    if 'Text(' in line and 'style:' in line:
        print(f'{i+1}: {line.strip()}')
    elif 'Text(' in line and '?' in line:
        print(f'{i+1}: {line.strip()}')
