"""Build the reusable BUILDWEALTH character, materials, and animation clips."""

import bpy
import math
import sys
from pathlib import Path
from mathutils import Vector


def arguments() -> tuple[Path, Path, Path, Path]:
    try:
        separator = sys.argv.index("--")
        base, idle, walk, output = sys.argv[separator + 1 : separator + 5]
    except (ValueError, IndexError):
        raise SystemExit(
            "usage: blender --background --python build_character.py -- "
            "player.fbx idle.fbx walk.fbx output.blend"
        )
    return tuple(Path(value).resolve() for value in (base, idle, walk, output))


def import_fbx(path: Path) -> tuple[list[bpy.types.Object], list[bpy.types.Action]]:
    old_objects = set(bpy.data.objects)
    old_actions = set(bpy.data.actions)
    bpy.ops.import_scene.fbx(
        filepath=str(path),
        automatic_bone_orientation=True,
        use_anim=True,
    )
    return (
        [item for item in bpy.data.objects if item not in old_objects],
        [item for item in bpy.data.actions if item not in old_actions],
    )


def remove_objects(objects: list[bpy.types.Object]) -> None:
    for item in objects:
        bpy.data.objects.remove(item, do_unlink=True)


def save_embedded_textures(directory: Path) -> None:
    directory.mkdir(parents=True, exist_ok=True)
    names = {
        "file1": "Ch20_Diffuse.png",
        "file3": "Ch20_Normal.png",
        "file5": "Ch20_Specular.png",
        "file6": "Ch20_Glossiness.png",
    }
    replacements = {}
    for image in list(bpy.data.images):
        if image.name not in names:
            continue
        destination = directory / names[image.name]
        if image.packed_file is None:
            raise RuntimeError(f"Expected embedded texture data for {image.name}")
        destination.write_bytes(image.packed_file.data)
        external = bpy.data.images.load(str(destination), check_existing=False)
        external.name = f"{image.name}_external"
        replacements[image] = external

    for material in bpy.data.materials:
        if material.node_tree is None:
            continue
        for node in material.node_tree.nodes:
            if node.type == "TEX_IMAGE" and node.image in replacements:
                node.image = replacements[node.image]

    for original in replacements:
        if original.users == 0:
            bpy.data.images.remove(original)


def configure_material() -> None:
    material = bpy.data.materials.get("Ch20_body")
    if material is None or material.node_tree is None:
        return

    nodes = material.node_tree.nodes
    diffuse = nodes.get("Image Texture")
    normal = nodes.get("Image Texture.001")
    specular = nodes.get("Image Texture.002")
    gloss = nodes.get("Image Texture.003")

    if diffuse and diffuse.image:
        diffuse.image.colorspace_settings.name = "sRGB"
    for node in (normal, specular, gloss):
        if node and node.image:
            node.image.colorspace_settings.name = "Non-Color"

    shader = next((node for node in nodes if node.type == "BSDF_PRINCIPLED"), None)
    if shader is not None:
        shader.inputs["Roughness"].default_value = 0.58
        shader.inputs["Metallic"].default_value = 0.0


def configure_preview(character: bpy.types.Object, mesh: bpy.types.Object) -> None:
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.render.resolution_x = 900
    scene.render.resolution_y = 900
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    if scene.world is None:
        scene.world = bpy.data.worlds.new("BUILDWEALTH Preview World")
    scene.world.color = (0.018, 0.022, 0.035)

    floor_material = bpy.data.materials.new("Preview Floor")
    floor_material.diffuse_color = (0.035, 0.045, 0.065, 1.0)
    bpy.ops.mesh.primitive_plane_add(size=8, location=(0, 0, 0))
    floor = bpy.context.object
    floor.name = "PREVIEW_FLOOR"
    floor.data.materials.append(floor_material)

    bpy.ops.object.light_add(type="AREA", location=(2.8, -3.5, 4.5))
    key = bpy.context.object
    key.name = "PREVIEW_KEY"
    key.data.energy = 1_100
    key.data.shape = "DISK"
    key.data.size = 3.5
    key.rotation_euler = (math.radians(28), 0, math.radians(35))

    bpy.ops.object.light_add(type="AREA", location=(-3, -1, 2.7))
    fill = bpy.context.object
    fill.name = "PREVIEW_FILL"
    fill.data.energy = 650
    fill.data.color = (0.45, 0.62, 1.0)
    fill.data.size = 3

    bpy.ops.object.light_add(type="AREA", location=(0, 2.5, 3.5))
    rim = bpy.context.object
    rim.name = "PREVIEW_RIM"
    rim.data.energy = 850
    rim.data.color = (0.65, 1.0, 0.25)
    rim.data.size = 2.5

    bpy.ops.object.camera_add(location=(3.8, -6.8, 2.8))
    camera = bpy.context.object
    camera.name = "PREVIEW_CAMERA"
    scene.camera = camera

    target = Vector((0, 0, 1.05))
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.lens = 58

    character.show_in_front = True
    mesh.select_set(True)
    character.select_set(True)
    bpy.context.view_layer.objects.active = character


def export_action(
    character: bpy.types.Object,
    mesh: bpy.types.Object,
    action: bpy.types.Action,
    output: Path,
) -> None:
    character.animation_data_create()
    character.animation_data.action = action
    bpy.context.scene.frame_start = int(action.frame_range[0])
    bpy.context.scene.frame_end = int(action.frame_range[1])
    bpy.context.scene.frame_set(int(action.frame_range[0]))
    bpy.ops.object.select_all(action="DESELECT")
    character.select_set(True)
    mesh.select_set(True)
    bpy.context.view_layer.objects.active = character
    output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.usd_export(
        filepath=str(output),
        selected_objects_only=True,
        export_animation=True,
        export_materials=True,
        export_textures=True,
        relative_paths=True,
        generate_preview_surface=True,
        root_prim_path="/Player",
    )


base_path, idle_path, walk_path, blend_path = arguments()
asset_directory = blend_path.parent
texture_directory = asset_directory / "Textures"

bpy.ops.wm.read_factory_settings(use_empty=True)
base_objects, base_actions = import_fbx(base_path)

character = next(item for item in base_objects if item.type == "ARMATURE")
mesh = next(item for item in base_objects if item.type == "MESH")
character.name = "BUILDWEALTH_Player"
mesh.name = "BUILDWEALTH_Player_Mesh"

save_embedded_textures(texture_directory)
configure_material()

idle_objects, idle_actions = import_fbx(idle_path)
idle_action = idle_actions[0]
idle_action.name = "Happy Idle"
idle_action.use_fake_user = True
remove_objects(idle_objects)

walk_objects, walk_actions = import_fbx(walk_path)
walk_action = walk_actions[0]
walk_action.name = "Walking"
walk_action.use_fake_user = True
remove_objects(walk_objects)

for action in base_actions:
    bpy.data.actions.remove(action)

bpy.ops.outliner.orphans_purge(
    do_local_ids=True,
    do_linked_ids=True,
    do_recursive=True,
)

character.animation_data_create()
character.animation_data.action = idle_action
bpy.context.scene.frame_start = 1
bpy.context.scene.frame_end = 61
bpy.context.scene.frame_set(1)

configure_preview(character, mesh)

bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))

preview_path = asset_directory / "CharacterPreview.png"
bpy.context.scene.render.filepath = str(preview_path)
bpy.context.scene.frame_set(20)
bpy.ops.render.render(write_still=True)

# Preview-only scene objects are excluded from runtime exports.
for name in ("PREVIEW_FLOOR", "PREVIEW_KEY", "PREVIEW_FILL", "PREVIEW_RIM", "PREVIEW_CAMERA"):
    item = bpy.data.objects.get(name)
    if item is not None:
        item.hide_render = True
        item.hide_viewport = True

export_action(character, mesh, idle_action, asset_directory / "PlayerIdle.usdz")
export_action(character, mesh, walk_action, asset_directory / "PlayerWalk.usdz")

# Leave the authoring file ready to open and play the idle action.
for name in ("PREVIEW_FLOOR", "PREVIEW_KEY", "PREVIEW_FILL", "PREVIEW_RIM", "PREVIEW_CAMERA"):
    item = bpy.data.objects.get(name)
    if item is not None:
        item.hide_render = False
        item.hide_viewport = False
character.animation_data.action = idle_action
bpy.context.scene.frame_start = 1
bpy.context.scene.frame_end = 61
bpy.context.scene.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))
