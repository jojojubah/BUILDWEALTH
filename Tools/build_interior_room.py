import bpy
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ASSET_DIR = ROOT / "Assets" / "Interiors"
BLEND_PATH = ASSET_DIR / "ReusableInteriorRoom.blend"
USDZ_PATH = ASSET_DIR / "ReusableInteriorRoom.usdz"


def material(name, color, metallic=0.0, roughness=0.55):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1.0)
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Roughness"].default_value = roughness
    return mat


def cube(name, location, scale, mat, bevel=0.04):
    bpy.ops.mesh.primitive_cube_add(location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        modifier = obj.modifiers.new("Soft Edges", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
    obj.data.materials.append(mat)
    return obj


bpy.ops.wm.read_factory_settings(use_empty=True)
ASSET_DIR.mkdir(parents=True, exist_ok=True)

floor_mat = material("ROOM_FLOOR", (0.31, 0.33, 0.37), roughness=0.72)
wall_mat = material("ROOM_WALL", (0.72, 0.18, 0.27), roughness=0.62)
ceiling_mat = material("ROOM_CEILING", (0.94, 0.95, 0.97), roughness=0.78)
trim_mat = material("ROOM_TRIM", (0.96, 0.96, 0.94), roughness=0.48)
frame_mat = material("WINDOW_FRAME", (0.12, 0.14, 0.18), metallic=0.15, roughness=0.35)
glass_mat = material("WINDOW_GLASS", (0.18, 0.48, 0.72), metallic=0.05, roughness=0.12)

# Open-front room, ten metres square and 3.6 metres high.
cube("ROOM_FLOOR", (0, 0, -0.12), (5.0, 5.0, 0.12), floor_mat)
cube("ROOM_CEILING", (0, 0, 3.65), (5.0, 5.0, 0.10), ceiling_mat)
cube("ROOM_WALL_LEFT", (-5.0, 0, 1.76), (0.10, 5.0, 1.76), wall_mat)
cube("ROOM_WALL_RIGHT", (5.0, 0, 1.76), (0.10, 5.0, 1.76), wall_mat)

# Far wall built around a real opening rather than placing glass on top.
cube("ROOM_WALL_BACK_LEFT", (-3.65, 5.0, 1.76), (1.35, 0.10, 1.76), wall_mat)
cube("ROOM_WALL_BACK_RIGHT", (3.65, 5.0, 1.76), (1.35, 0.10, 1.76), wall_mat)
cube("ROOM_WALL_BACK_BOTTOM", (0, 5.0, 0.53), (2.30, 0.10, 0.53), wall_mat)
cube("ROOM_WALL_BACK_TOP", (0, 5.0, 3.14), (2.30, 0.10, 0.38), wall_mat)

# Baseboard trim gives the shell useful depth at game-camera distance.
cube("ROOM_TRIM_LEFT", (-4.84, 0, 0.18), (0.08, 4.84, 0.18), trim_mat, bevel=0.02)
cube("ROOM_TRIM_RIGHT", (4.84, 0, 0.18), (0.08, 4.84, 0.18), trim_mat, bevel=0.02)
cube("ROOM_TRIM_BACK", (0, 4.84, 0.18), (4.84, 0.08, 0.18), trim_mat, bevel=0.02)

# Window frame and slightly inset glass.
cube("WINDOW_FRAME_LEFT", (-2.42, 4.82, 1.82), (0.12, 0.12, 1.18), frame_mat, bevel=0.02)
cube("WINDOW_FRAME_RIGHT", (2.42, 4.82, 1.82), (0.12, 0.12, 1.18), frame_mat, bevel=0.02)
cube("WINDOW_FRAME_BOTTOM", (0, 4.82, 0.68), (2.30, 0.12, 0.12), frame_mat, bevel=0.02)
cube("WINDOW_FRAME_TOP", (0, 4.82, 2.96), (2.30, 0.12, 0.12), frame_mat, bevel=0.02)
cube("WINDOW_FRAME_CENTER", (0, 4.80, 1.82), (0.07, 0.10, 1.08), frame_mat, bevel=0.01)
cube("WINDOW_GLASS", (0, 4.94, 1.82), (2.28, 0.025, 1.05), glass_mat, bevel=0.0)

# Simple ceiling panel to make the white ceiling legible in perspective.
cube("CEILING_PANEL", (0, 0.8, 3.48), (1.7, 1.0, 0.05), trim_mat, bevel=0.08)

for obj in bpy.context.scene.objects:
    obj.select_set(obj.type == "MESH")

bpy.context.scene.render.engine = "BLENDER_EEVEE_NEXT"
world = bpy.data.worlds.new("Interior World")
world.color = (0.025, 0.03, 0.045)
bpy.context.scene.world = world
bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))

bpy.ops.wm.usd_export(
    filepath=str(USDZ_PATH),
    selected_objects_only=True,
    export_materials=True,
    export_textures=False,
    relative_paths=True,
    evaluation_mode="RENDER",
)

print(f"Saved {BLEND_PATH}")
print(f"Exported {USDZ_PATH}")
