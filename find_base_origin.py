import re

with open('/tmp/raw_5fe.svg', 'r', errors='ignore') as f:
    text = f.read()

# Search for 57114.71
matches = re.findall(r'.{0,60}57114\.71.{0,60}', text)
print(f"Total occurrences of 57114.71: {len(matches)}")
for m in matches[:10]:
    print('-->', m.strip())
