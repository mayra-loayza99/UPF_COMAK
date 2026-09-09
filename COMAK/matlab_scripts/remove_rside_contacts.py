"""
Remove tf_contact and pf_contact (right-side contacts, no _r suffix) from
model_two_legs_HOLOA_040.osim and write model_two_legs_HOLOA_040_lside.osim.

These contacts cause COMAKTool to crash when running left-side COMAK because
COMAK iterates over ALL Smith2018ArticularContactForce objects regardless of
appliesForce flag, and the right-side secondary coordinates are PRESCRIBED (not
in the secondary list), causing a -1 index lookup -> crash.
"""
import re
import sys

INPUT  = r"D:\mayra\Descargas\UPF_COMAK-master\UPF_COMAK-master\COMAK\processed_data\HOLOA_040\model\model_two_legs_HOLOA_040.osim"
OUTPUT = r"D:\mayra\Descargas\UPF_COMAK-master\UPF_COMAK-master\COMAK\processed_data\HOLOA_040\model\model_two_legs_HOLOA_040_lside.osim"

with open(INPUT, 'r', encoding='utf-8') as f:
    content = f.read()

original_len = len(content)

for name in ('tf_contact', 'pf_contact'):
    pattern = (
        r'\n[ \t]*<Smith2018ArticularContactForce name="' + re.escape(name) + r'">'
        r'.*?</Smith2018ArticularContactForce>'
    )
    before = len(content)
    content = re.sub(pattern, '', content, flags=re.DOTALL)
    removed = before - len(content)
    print(f"  Removed '{name}': {removed} characters deleted")

with open(OUTPUT, 'w', encoding='utf-8') as f:
    f.write(content)

print(f"\nDone. Input {original_len} chars -> Output {len(content)} chars")
print(f"Output: {OUTPUT}")

# Verify the result
remaining = re.findall(r'Smith2018ArticularContactForce name="[^"]*"', content)
print(f"Remaining Smith2018ArticularContactForce entries: {remaining}")
