"""Convert the BUILDWEALTH player FBX into a compact, runtime-ready USDZ."""

import bpy
import sys
from pathlib import Path


def arguments() -> tuple[Path, Path]:
    try:
        separator = sys.argv.index("--")
        source, destination = sys.argv[separator + 1 : separator + 3]
    except (ValueError, IndexError):
        raise SystemExit("usage: blender --background --python export_player.py -- input.fbx output.usdz")
    return Path(source).resolve(), Path(destination).resolve()


source, destination = arguments()
destination.parent.mkdir(parents=True, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(
    filepath=str(source),
    automatic_bone_orientation=True,
    use_anim=True,
)

for material in bpy.data.materials:
    if not material.use_nodes or material.node_tree is None:
        continue

    missing_images = [
        node
        for node in material.node_tree.nodes
        if node.type == "TEX_IMAGE"
        and (node.image is None or not Path(bpy.path.abspath(node.image.filepath)).exists())
    ]
    for node in missing_images:
        material.node_tree.nodes.remove(node)

    if missing_images:
        shader = next(
            (node for node in material.node_tree.nodes if node.type == "BSDF_PRINCIPLED"),
            None,
        )
        if shader is not None:
            shader.inputs["Base Color"].default_value = (0.22, 0.34, 0.12, 1.0)
            shader.inputs["Roughness"].default_value = 0.72
            shader.inputs["Metallic"].default_value = 0.0

for item in bpy.context.scene.collection.all_objects:
    item.select_set(True)

bpy.ops.wm.usd_export(
    filepath=str(destination),
    selected_objects_only=False,
    export_animation=True,
    export_materials=True,
    export_textures=True,
    relative_paths=True,
    generate_preview_surface=True,
    root_prim_path="/Player",
)
