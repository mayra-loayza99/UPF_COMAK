"""
Create a LEFT-SIDE ONLY model from the bilateral model.

Keeps ALL structural elements (bodies, joints, coordinates, markers, constraints).
Keeps all LEFT-SIDE forces: muscles (_l), contacts (_l), ligaments (_l), springs (_l).
Removes RIGHT-SIDE forces: muscles (_r), contacts (no _l), ligaments (no _l), springs (_r).

This allows COMAK to run on the left knee with the bilateral joint structure,
while the right-side coordinates are prescribed from the bilateral IK file.

Usage:
    python create_lonly_model.py <input_osim> <output_osim>
    python create_lonly_model.py  (uses hardcoded HOLOA_040 paths)
"""
import re
import sys

if len(sys.argv) == 3:
    INPUT  = sys.argv[1]
    OUTPUT = sys.argv[2]
else:
    INPUT  = r"D:\mayra\Descargas\UPF_COMAK-master\UPF_COMAK-master\COMAK\processed_data\HOLOA_040\model\model_two_legs_HOLOA_040.osim"
    OUTPUT = r"D:\mayra\Descargas\UPF_COMAK-master\UPF_COMAK-master\COMAK\processed_data\HOLOA_040\model\model_two_legs_HOLOA_040_lonly.osim"

with open(INPUT, 'r', encoding='utf-8') as f:
    content = f.read()

original_len = len(content)


def remove_force_blocks(content, tag, name_filter):
    """Remove all XML blocks <tag name="X">...</tag> where name_filter(X) is True."""
    pattern = (
        r'\n[ \t]*<' + re.escape(tag) + r' name="([^"]+)">'
        r'.*?</' + re.escape(tag) + r'>'
    )
    removed = []

    def _replace(m):
        name = m.group(1)
        if name_filter(name):
            removed.append(name)
            return ''
        return m.group(0)

    new_content = re.sub(pattern, _replace, content, flags=re.DOTALL)
    return new_content, removed


# 1. Remove right-side muscles (name ends in _r); keep 'default' template
content, removed = remove_force_blocks(
    content, 'Millard2012EquilibriumMuscle',
    lambda n: n.endswith('_r'))
print(f"Removed {len(removed)} right-side muscles")

# 2. Remove right-side contacts (name NOT ending in _l, not 'default')
content, removed = remove_force_blocks(
    content, 'Smith2018ArticularContactForce',
    lambda n: not n.endswith('_l') and n != 'default')
print(f"Removed {len(removed)} right-side contacts: {removed}")

# 3. Remove right-side ligaments (name NOT ending in _l, not 'default')
content, removed = remove_force_blocks(
    content, 'Blankevoort1991Ligament',
    lambda n: not n.endswith('_l') and n != 'default')
print(f"Removed {len(removed)} right-side ligaments")

# 4. Remove right-side passive springs (name ends in _r)
content, removed = remove_force_blocks(
    content, 'SpringGeneralizedForce',
    lambda n: n.endswith('_r'))
print(f"Removed {len(removed)} right-side springs: {removed}")

with open(OUTPUT, 'w', encoding='utf-8') as f:
    f.write(content)

print(f"\nInput:  {original_len} chars")
print(f"Output: {len(content)} chars")
print(f"Saved:  {OUTPUT}")

# Verification
remaining_muscles = re.findall(
    r'<Millard2012EquilibriumMuscle name="([^"]+)"', content)
real_muscles = [m for m in remaining_muscles if m != 'default']
print(f"\nRemaining muscles: {len(real_muscles)}")
print(f"  First 5: {real_muscles[:5]}")
print(f"  Last 5:  {real_muscles[-5:]}")

remaining_contacts = re.findall(
    r'<Smith2018ArticularContactForce name="([^"]+)"', content)
print(f"Remaining contacts: {[c for c in remaining_contacts if c != 'default']}")

remaining_ligs = re.findall(
    r'<Blankevoort1991Ligament name="([^"]+)"', content)
real_ligs = [l for l in remaining_ligs if l != 'default']
print(f"Remaining ligaments: {len(real_ligs)}")

remaining_springs = re.findall(
    r'<SpringGeneralizedForce name="([^"]+)"', content)
print(f"Remaining springs: {[s for s in remaining_springs if s != 'default']}")
