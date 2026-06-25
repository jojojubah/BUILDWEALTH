import re
from pathlib import Path

import bpy


ROOT = Path(__file__).resolve().parents[1]
BLEND_PATH = ROOT / "Source" / "Blender" / "FloatingCliffCity.blend"
USDZ_PATH = ROOT / "Assets" / "City" / "FloatingCliffCity.usdz"

# The road surface ends at 10 m from the origin-facing side of each block.
# Place the lamp centres farther onto the sidewalk while retaining generous
# clearance from buildings and entrances.
SIDEWALK_OFFSET = 10.85
LAMP_PATTERN = re.compile(r"^Lamp (Post|Head)(?:\.\d{3})?$")


def move_to_sidewalk(obj):
    x, y, _ = obj.location

    if min(abs(abs(y) - 10.1), abs(abs(y) - SIDEWALK_OFFSET)) < 0.05:
        obj.location.y = SIDEWALK_OFFSET if y > 0 else -SIDEWALK_OFFSET
        return True

    if min(abs(abs(x) - 10.1), abs(abs(x) - SIDEWALK_OFFSET)) < 0.05:
        obj.location.x = SIDEWALK_OFFSET if x > 0 else -SIDEWALK_OFFSET
        return True

    return False


moved = []
for obj in bpy.data.objects:
    if LAMP_PATTERN.fullmatch(obj.name) and move_to_sidewalk(obj):
        moved.append(obj.name)

if len(moved) != 48:
    raise RuntimeError(f"Expected 48 lamp pieces, moved {len(moved)}")

bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))
bpy.ops.wm.usd_export(
    filepath=str(USDZ_PATH),
    selected_objects_only=False,
    visible_objects_only=False,
    export_materials=True,
    export_textures=False,
    relative_paths=True,
    evaluation_mode="RENDER",
    convert_orientation=True,
    export_global_forward_selection="NEGATIVE_Z",
    export_global_up_selection="Y",
    root_prim_path="/BUILDWEALTH",
)

print(f"Moved {len(moved) // 2} streetlight assemblies onto the sidewalks")
print(f"Saved {BLEND_PATH}")
print(f"Exported {USDZ_PATH}")
