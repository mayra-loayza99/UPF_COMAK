"""
Create left-side cartilage STL meshes by mirroring the right-side ones.

The bilateral model references lenhart2015-L-*-cartilage.stl files that do not
exist on disk.  This script generates them by reflecting the right-side meshes
across the X=0 plane (negating the X coordinate of every vertex and reversing
triangle winding to maintain outward normals).

Usage
-----
    python create_left_cartilage_meshes.py <geometry_dir>
    python create_left_cartilage_meshes.py   # uses hardcoded HOLOA_040 path

The script writes:
    lenhart2015-L-femur-cartilage.stl
    lenhart2015-L-tibia-cartilage.stl
    lenhart2015-L-patella-cartilage.stl
    lenhart2015-L-femur-bone.stl
    lenhart2015-L-tibia-bone.stl
    lenhart2015-L-patella-bone.stl
    lenhart2015-L-fibula-bone.stl
into the same directory.
"""

import struct
import sys
from pathlib import Path

DEFAULT_GEOM = (
    r"D:\mayra\Descargas\UPF_COMAK-master\UPF_COMAK-master"
    r"\COMAK\processed_data\HOLOA_040\model\Geometry"
)

PAIRS = [
    ("lenhart2015-R-femur-cartilage.stl",   "lenhart2015-L-femur-cartilage.stl"),
    ("lenhart2015-R-tibia-cartilage.stl",    "lenhart2015-L-tibia-cartilage.stl"),
    ("lenhart2015-R-patella-cartilage.stl",  "lenhart2015-L-patella-cartilage.stl"),
    ("lenhart2015-R-femur-bone.stl",         "lenhart2015-L-femur-bone.stl"),
    ("lenhart2015-R-tibia-bone.stl",         "lenhart2015-L-tibia-bone.stl"),
    ("lenhart2015-R-patella-bone.stl",       "lenhart2015-L-patella-bone.stl"),
    ("lenhart2015-R-fibula-bone.stl",        "lenhart2015-L-fibula-bone.stl"),
]


def read_binary_stl(path: Path):
    """Return (header, list_of_triangles).
    Each triangle is (normal, v0, v1, v2, attr) where each is a tuple of floats.
    """
    data = path.read_bytes()
    header = data[:80]
    n_tri = struct.unpack_from("<I", data, 80)[0]
    triangles = []
    offset = 84
    for _ in range(n_tri):
        vals = struct.unpack_from("<12fH", data, offset)
        normal = vals[0:3]
        v0     = vals[3:6]
        v1     = vals[6:9]
        v2     = vals[9:12]
        attr   = vals[12]
        triangles.append((normal, v0, v1, v2, attr))
        offset += 50
    return header, triangles


def write_binary_stl(path: Path, header: bytes, triangles):
    with open(path, "wb") as f:
        f.write(header)
        f.write(struct.pack("<I", len(triangles)))
        for normal, v0, v1, v2, attr in triangles:
            f.write(struct.pack("<12fH", *normal, *v0, *v1, *v2, attr))


def mirror_x(triangles):
    """Mirror every triangle across X=0: negate X of all vertices and normal,
    then reverse vertex order (v1 <-> v2) to maintain outward-facing normals."""
    out = []
    for normal, v0, v1, v2, attr in triangles:
        mn = (-normal[0], normal[1], normal[2])
        mv0 = (-v0[0], v0[1], v0[2])
        mv1 = (-v1[0], v1[1], v1[2])
        mv2 = (-v2[0], v2[1], v2[2])
        # swap v1 and v2 to fix winding after reflection
        out.append((mn, mv0, mv2, mv1, attr))
    return out


def is_ascii_stl(path: Path) -> bool:
    try:
        head = path.read_bytes()[:256]
        return head.startswith(b"solid") and b"\n" in head
    except Exception:
        return False


def convert_ascii_to_binary(path: Path) -> None:
    """Simple ASCII STL → binary conversion (in-place backup)."""
    lines = path.read_text(errors="replace").splitlines()
    triangles = []
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        if line.startswith("facet normal"):
            vals = list(map(float, line.split()[2:5]))
            normal = tuple(vals)
            # skip "outer loop"
            i += 2
            verts = []
            for _ in range(3):
                v = tuple(map(float, lines[i].strip().split()[1:4]))
                verts.append(v)
                i += 1
            triangles.append((normal, verts[0], verts[1], verts[2], 0))
        i += 1
    header = b"Converted from ASCII STL" + b" " * 56
    tmp = path.with_suffix(".bin_tmp")
    write_binary_stl(tmp, header, triangles)
    tmp.replace(path)


def process(geom_dir: Path) -> None:
    for src_name, dst_name in PAIRS:
        src = geom_dir / src_name
        dst = geom_dir / dst_name

        if not src.exists():
            print(f"  SKIP  {src_name} (not found)")
            continue

        if dst.exists():
            print(f"  EXISTS {dst_name} — overwriting")

        if is_ascii_stl(src):
            print(f"  Converting ASCII to binary: {src_name}")
            import shutil, tempfile
            tmp = Path(tempfile.mktemp(suffix=".stl"))
            shutil.copy2(src, tmp)
            convert_ascii_to_binary(tmp)
            header, tris = read_binary_stl(tmp)
            tmp.unlink()
        else:
            header, tris = read_binary_stl(src)

        mirrored = mirror_x(tris)
        write_binary_stl(dst, header, mirrored)
        print(f"  OK    {src_name} -> {dst_name}  ({len(mirrored)} triangles)")


if __name__ == "__main__":
    geom_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(DEFAULT_GEOM)
    if not geom_dir.is_dir():
        print(f"ERROR: directory not found: {geom_dir}")
        sys.exit(1)
    print(f"Geometry dir: {geom_dir}")
    process(geom_dir)
    print("Done.")
