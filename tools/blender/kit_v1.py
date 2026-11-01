"""Hawkey kit v1, built headless in Blender around the CC0 base body.

Run through the Blender bridge (tools/blender/README.md):
    blender -b --factory-startup --python kit_v1.py -- <bridge_root>
Reads <bridge_root>/input/player-base-v1.glb, writes <bridge_root>/out/kit_v1.glb
(Jersey and Pants skinned to the base skeleton) and preview renders.

Garments start from the base body's shirt and shorts regions, lose the anatomy
(smoothed), are held outside the body with Blender's Shrinkwrap (keep-outside),
pushed out to garment volume (shoulder pads, padded hips and thighs), get real
openings (long loose hem over the pants, wrist cuffs, ribbed collar, open pant
legs, belt band), thickness, and the body's own skin weights.
"""
import bpy, bmesh, sys, os, math
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = sys.argv[sys.argv.index("--") + 1]
OUT = os.path.join(ROOT, "out")
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, "input", "player-base-v1.glb"))
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
body = bpy.data.objects["base_male_body"]
for o in list(bpy.data.objects):
    if o.type == "MESH" and o is not body:
        bpy.data.objects.remove(o)
arm.data.pose_position = "REST"
bpy.context.view_layer.update()
scene = bpy.context.scene

def ss(a, b, x):
    t = 0.0 if b == a else max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)

# ---------------------------------------------------------------- body data
col = body.data.color_attributes.get("Color") or body.data.attributes["Color"]
region = [0] * len(body.data.vertices)
if col.domain == "POINT":
    for i, d in enumerate(col.data):
        region[i] = int(round(d.color[0] * 8))
else:
    for poly in body.data.polygons:
        for li, vi in zip(poly.loop_indices, poly.vertices):
            region[vi] = int(round(col.data[li].color[0] * 8))
world = body.matrix_world.copy()
# A rest-space copy of the body: Shrinkwrap target and distance checks.
body_rest = bpy.data.objects.new("BodyRest", body.data.copy())
scene.collection.objects.link(body_rest)
body_rest.matrix_world = world
# Unsmoothed copy: last-pass guard so thin limbs (shrunk by smoothing) stay covered.
body_true = bpy.data.objects.new("BodyTrue", body.data.copy())
scene.collection.objects.link(body_true)
body_true.matrix_world = world
# Wrap against a smoothed body so nipples, navel and seams don't print through.
_sm = body_rest.modifiers.new("smooth", "SMOOTH")
_sm.factor = 0.9
_sm.iterations = 12
bpy.context.view_layer.objects.active = body_rest
bpy.ops.object.modifier_apply(modifier=_sm.name)
bm_body = bmesh.new()
bm_body.from_mesh(body.data)
bm_body.transform(world)
bm_body.normal_update()
bm_body.verts.ensure_lookup_table()
bm_body.faces.ensure_lookup_table()
body_tree = BVHTree.FromBMesh(bm_body)
group_names = [g.name for g in body.vertex_groups]
body_w = [dict() for _ in body.data.vertices]
for v in body.data.vertices:
    for g in v.groups:
        if g.weight > 0.001:
            body_w[v.index][g.group] = g.weight

# ---------------------------------------------------------------- helpers
def components(bm):
    seen, comps = set(), []
    for v in bm.verts:
        if v in seen:
            continue
        stack, comp = [v], []
        seen.add(v)
        while stack:
            c = stack.pop()
            comp.append(c)
            for e in c.link_edges:
                o = e.other_vert(c)
                if o not in seen:
                    seen.add(o)
                    stack.append(o)
        comps.append(comp)
    return comps

def boundary_loops(bm):
    edges = {e for e in bm.edges if e.is_boundary}
    loops = []
    while edges:
        e = edges.pop()
        loop = [e.verts[0], e.verts[1]]
        grow = True
        while grow:
            grow = False
            for nb in loop[-1].link_edges:
                if nb in edges:
                    edges.discard(nb)
                    loop.append(nb.other_vert(loop[-1]))
                    grow = True
                    break
        if loop[0] is loop[-1]:
            loop.pop()
        loops.append(loop)
    return loops

def centre(loop):
    c = Vector()
    for v in loop:
        c += v.co
    return c / len(loop)

def shell(keep_regions, name, is_opening):
    bm = bmesh.new()
    bm.from_mesh(body.data)
    bm.transform(world)
    tag = bm.verts.layers.int.new("region")
    bm.verts.ensure_lookup_table()
    for v in bm.verts:
        v[tag] = region[v.index]
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v[tag] not in keep_regions], context="VERTS")
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.002)
    comps = components(bm)
    print(name, "components", sorted((len(c) for c in comps), reverse=True)[:8])
    small = [v for c in comps if len(c) < 60 for v in c]
    bmesh.ops.delete(bm, geom=small, context="VERTS")
    # Fill every hole that is not a real opening of the garment.
    for lp in boundary_loops(bm):
        if not is_opening(lp):
            edges = list({e for v in lp for e in v.link_edges if e.is_boundary})
            bmesh.ops.holes_fill(bm, edges=edges, sides=0)
    print(name, "faces", len(bm.faces), "openings", [(len(l), tuple(round(x, 2) for x in centre(l))) for l in boundary_loops(bm)])
    return bm

def to_object(bm, name):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    scene.collection.objects.link(ob)
    return ob

def edit(ob, fn):
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.normal_update()
    fn(bm)
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()

def relax(ob, iterations, factor):
    def run(bm):
        movable = [v for v in bm.verts if not v.is_boundary]
        for _ in range(iterations):
            bmesh.ops.smooth_vert(bm, verts=movable, factor=factor, use_axis_x=True, use_axis_y=True, use_axis_z=True)
    edit(ob, run)

def outward_normals(ob):
    def run(bm):
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.normal_update()
        score = sum(f.normal.dot(f.calc_center_median() - Vector((0, 0, f.calc_center_median().z))) for f in bm.faces)
        if score < 0:
            bmesh.ops.reverse_faces(bm, faces=bm.faces)
    edit(ob, run)

def apply_mod(ob, mod):
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.ops.object.modifier_apply(modifier=mod.name)

def keep_outside(ob, target, offset):
    m = ob.modifiers.new("keep_out", "SHRINKWRAP")
    m.target = target
    m.wrap_method = "NEAREST_SURFACEPOINT"
    m.wrap_mode = "OUTSIDE"
    m.offset = offset
    apply_mod(ob, m)

def push(ob, amount):
    def run(bm):
        bm.normal_update()
        moves = [(v, v.normal.copy() * amount(v.co)) for v in bm.verts]
        for v, d in moves:
            v.co += d
    edit(ob, run)

def stat(ob, label):
    zs = [v.co.z for v in ob.data.vertices]
    xs = [abs(v.co.x) for v in ob.data.vertices]
    print("STEP", ob.name, label, "verts", len(zs), "z", round(min(zs), 3), round(max(zs), 3), "max|x|", round(max(xs), 3))

def guarded_outside(ob, target, offset, limit=0.12):
    """Keep-outside, but undo any point the wrap would throw further than limit."""
    before = [v.co.copy() for v in ob.data.vertices]
    keep_outside(ob, target, offset)
    wild = 0
    for v, b in zip(ob.data.vertices, before):
        if (v.co - b).length > limit:
            v.co = b
            wild += 1
    ob.data.update()
    if wild:
        print("GUARD", ob.name, "reverted", wild, "points")

def decimate(ob, faces):
    have = len(ob.data.polygons)
    if have > faces:
        m = ob.modifiers.new("decimate", "DECIMATE")
        m.ratio = faces / have
        apply_mod(ob, m)

def clearance(ob, label):
    """Smallest signed distance from garment points to the body surface."""
    worst = 1e9
    inside = 0
    for v in ob.data.vertices:
        p = ob.matrix_world @ v.co
        loc, nrm, fi, dist = body_tree.find_nearest(p)
        if loc is None or dist > 0.25:
            continue
        gap = (p - loc).dot(bm_body.faces[fi].normal)
        worst = min(worst, gap)
        inside += gap < 0.0
    print("CLEARANCE", label, "min_gap_m", round(worst, 4), "points_inside", inside, "of", len(ob.data.vertices))
    return worst

def extrude_openings(ob, plan):
    """plan(loop_centre, loop) -> None or offset_fn(co, t, centre) with steps."""
    def run(bm):
        for lp in boundary_loops(bm):
            c = centre(lp)
            job = plan(c, lp)
            if not job:
                continue
            fn, steps = job
            current = lp
            for s in range(1, steps + 1):
                new = [bm.verts.new(fn(v.co, s / steps, c)) for v in current]
                n = len(current)
                for i in range(n):
                    try:
                        bm.faces.new((current[i], current[(i + 1) % n], new[(i + 1) % n], new[i]))
                    except ValueError:
                        pass
                current = new
    edit(ob, run)

def finish(ob, thickness, color):
    outward_normals(ob)
    if thickness > 0.0:
        m = ob.modifiers.new("solidify", "SOLIDIFY")
        m.thickness = thickness
        m.offset = -1.0
        m.use_even_offset = False
        m.use_quality_normals = True
        apply_mod(ob, m)
    stat(ob, "final")
    mat = bpy.data.materials.new(ob.name + "_mat")
    mat.diffuse_color = color
    ob.data.materials.append(mat)
    for p in ob.data.polygons:
        p.use_smooth = True

def skin(ob):
    for gname in group_names:
        ob.vertex_groups.new(name=gname)
    for v in ob.data.vertices:
        loc, nrm, fi, dist = body_tree.find_nearest(v.co)
        face = bm_body.faces[fi]
        acc, total = {}, 0.0
        for fv in face.verts:
            w = 1.0 / max(0.002, (fv.co - loc).length)
            total += w
            for g, gw in body_w[fv.index].items():
                acc[g] = acc.get(g, 0.0) + gw * w
        if abs(v.co.x) < 0.16:
            # Chest/back panel: arms don't drag the front of the sweater.
            acc = {g: x for g, x in acc.items() if not group_names[g].startswith(("upperarm", "lowerarm", "wrist", "elbow"))} or acc
        top = sorted(acc.items(), key=lambda kv: -kv[1])[:4]
        s = sum(x for _, x in top) or 1.0
        for g, x in top:
            if x / s > 0.01:
                ob.vertex_groups[group_names[g]].add([v.index], x / s, "REPLACE")
    ob.parent = arm
    m = ob.modifiers.new("Armature", "ARMATURE")
    m.object = arm

# ---------------------------------------------------------------- clean forms
def bone_world(name, tail=False):
    b = arm.data.bones[name]
    return arm.matrix_world @ (b.tail_local if tail else b.head_local)

body_pts = [(world @ v.co, region[v.index]) for v in body.data.vertices]

def ring_size(centre_pt, axis, half_len, pred, ease, minimum, max_r=1.0):
    """Ellipse half-axes of body points in a slab round an axis (x/y extents)."""
    u = axis.cross(Vector((0, 1, 0)))
    if u.length < 0.1:
        u = axis.cross(Vector((1, 0, 0)))
    u.normalize()
    w = axis.cross(u).normalized()
    a = b = minimum
    for p, r in body_pts:
        d = p - centre_pt
        if abs(d.dot(axis)) > half_len or not pred(p, r):
            continue
        if (d - axis * d.dot(axis)).length > max_r:
            continue
        a = max(a, abs(d.dot(u)))
        b = max(b, abs(d.dot(w)))
    return u, w, a + ease, b + ease

def tube(name, points, sizes, segments=28, cap=True):
    """Closed loft through ring centres with per-ring frames and radii."""
    bm = bmesh.new()
    rings = []
    for c, (u, w, a, b) in zip(points, sizes):
        rings.append([bm.verts.new(c + u * (a * math.cos(t)) + w * (b * math.sin(t)))
                      for t in (2 * math.pi * k / segments for k in range(segments))])
    for r0, r1 in zip(rings, rings[1:]):
        for k in range(segments):
            bm.faces.new((r0[k], r0[(k + 1) % segments], r1[(k + 1) % segments], r1[k]))
    if cap:
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])
    return to_object(bm, name)

def limb(name, a_pt, b_pt, steps, pred, ease, minimum, extend=(0.0, 0.0), midline_gap=None, max_r=1.0):
    axis = (b_pt - a_pt).normalized()
    a_pt = a_pt - axis * extend[0]
    b_pt = b_pt + axis * extend[1]
    length = (b_pt - a_pt).length
    pts, sizes = [], []
    for k in range(steps + 1):
        c = a_pt + axis * (length * k / steps)
        u, w, a, b = ring_size(c, axis, length / steps * 0.6, pred, ease, minimum, max_r)
        if midline_gap is not None:
            # Keep each pant leg on its own side of the body's midline.
            reach_x = abs(u.x) * a + abs(w.x) * b
            limit = abs(c.x) - midline_gap
            if reach_x > limit > 0.02:
                a *= limit / reach_x
                b *= limit / reach_x
                c = c.copy()
        sizes.append((u, w, a, b))
        pts.append(c)
    return tube(name, pts, sizes)

def torso(name, z0, z1, steps, pred, ease, minimum, y_shift=0.0):
    pts, sizes = [], []
    for k in range(steps + 1):
        z = z0 + (z1 - z0) * k / steps
        c = Vector((0, y_shift, z))
        # centre the slab on the body's own front/back middle
        ys = [p.y for p, r in body_pts if abs(p.z - z) < 0.02 and pred(p, r)]
        if ys:
            c.y = (min(ys) + max(ys)) * 0.5
        sizes.append(ring_size(c, Vector((0, 0, 1)), (z1 - z0) / steps * 0.6, pred, ease, minimum))
        pts.append(c)
    return tube(name, pts, sizes)

def fuse(name, parts, voxel):
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    ob = parts[0]
    ob.name = name
    m = ob.modifiers.new("remesh", "REMESH")
    m.mode = "VOXEL"
    m.voxel_size = voxel
    m.use_smooth_shade = True
    apply_mod(ob, m)
    return ob

def cut(ob, planes):
    """Remove everything on the outer side of each (point, normal) plane."""
    def run(bm):
        for co, no in planes:
            geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
            bmesh.ops.bisect_plane(bm, geom=geom, plane_co=co, plane_no=no, clear_outer=True)
    edit(ob, run)

def tidy(ob, label):
    def run(bm):
        comps = components(bm)
        biggest = max(comps, key=len)
        bmesh.ops.delete(bm, geom=[v for c in comps if c is not biggest for v in c], context="VERTS")
    edit(ob, run)
    bm = bmesh.new(); bm.from_mesh(ob.data)
    print(label, "faces", len(bm.faces), "openings", [(len(l), tuple(round(x, 2) for x in centre(l))) for l in boundary_loops(bm)])
    bm.free()

trunk = lambda p, r: r in (1, 2) and abs(p.x) < 0.26
L, R = "L", "R"

# ---------------------------------------------------------------- pants (the sweater hangs over them)
hip_l, knee_l = bone_world("upperleg01.L"), bone_world("lowerleg01.L")
hip_r, knee_r = bone_world("upperleg01.R"), bone_world("lowerleg01.R")
thigh = lambda side_x: (lambda p, r: r in (2, 1, 3) and p.x * side_x > 0.0)
pelvis = torso("pelvis", 0.80, 1.10, 8, lambda p, r: r in (1, 2) and abs(p.x) < 0.24 and p.z > 0.78, 0.045, 0.1)
legs = [limb("thigh" + s, h + Vector((0.025 if s == L else -0.025, 0, 0)), k, 6, thigh(1 if s == L else -1), 0.05, 0.07, (0.0, 0.0), midline_gap=0.012, max_r=0.16)
        for s, h, k in ((L, hip_l, knee_l), (R, hip_r, knee_r))]
pants = fuse("Pants", [pelvis] + legs, 0.014)
pants_planes = [(Vector((0, 0, 1.08)), Vector((0, 0, 1)))]
for h, k in ((hip_l, knee_l), (hip_r, knee_r)):
    axis = (k - h).normalized()
    pants_planes.append((h + (k - h) * 0.80, axis))  # leg opening a hand above the knee
stat(pants, "fused")
cut(pants, pants_planes)
tidy(pants, "pants")
decimate(pants, 9000)
stat(pants, "cut")
for cycle in range(3):
    relax(pants, 6, 0.5)
    guarded_outside(pants, body_rest, 0.04)
stat(pants, "wrapped")
push(pants, lambda p: 0.018 * math.exp(-(((p.z - 0.96) / 0.07) ** 2)) + 0.010 * ss(0.85, 0.65, p.z))
guarded_outside(pants, body_rest, 0.04)
stat(pants, "shaped")
guarded_outside(pants, body_true, 0.008)
outward_normals(pants)
_shell = bpy.data.objects.new("PantsShell", pants.data.copy())
scene.collection.objects.link(_shell)
decimate(pants, 2900)
relax(pants, 1, 0.3)
finish(pants, 0.0, (0.04, 0.05, 0.07, 1))
clearance(pants, "pants")

# ---------------------------------------------------------------- sweater
sh_l, el_l, wr_l = bone_world("upperarm01.L"), bone_world("lowerarm01.L"), bone_world("wrist.L")
sh_r, el_r, wr_r = bone_world("upperarm01.R"), bone_world("lowerarm01.R"), bone_world("wrist.R")
armside = lambda side_x: (lambda p, r: r == 1 and p.x * side_x > 0.15)
body_tube = torso("trunk", 0.86, 1.52, 14, lambda p, r: r == 1 and abs(p.x) < 0.24, 0.035, 0.1)
sleeves = []
for s, sh, el, wr in ((L, sh_l, el_l, wr_l), (R, sh_r, el_r, wr_r)):
    sx = 1 if s == L else -1
    # Fixed pro-sleeve girth over elbow pads (the wrap below keeps it off a
    # thicker arm); sizing from body points ballooned once the arms came down.
    sleeves.append(limb("upper" + s, sh, el, 5, lambda p, r: False, 0.0, 0.066, (0.06, 0.0)))
    sleeves.append(limb("lower" + s, el, wr, 5, lambda p, r: False, 0.0, 0.056, (0.03, 0.02)))
neck_ring = torso("neckband", 1.48, 1.56, 2, lambda p, r: abs(p.x) < 0.09 and p.z > 1.46, 0.02, 0.06)
jersey = fuse("Jersey", [body_tube, neck_ring] + sleeves, 0.013)
jersey_planes = [(Vector((0, 0, 0.90)), Vector((0, 0, -1))), (Vector((0, 0, 1.545)), Vector((0, 0, 1)))]
for el, wr in ((el_l, wr_l), (el_r, wr_r)):
    axis = (wr - el).normalized()
    jersey_planes.append((wr - axis * 0.005, axis))  # sleeve ends at the wrist
stat(jersey, "fused")
cut(jersey, jersey_planes)
tidy(jersey, "jersey")
decimate(jersey, 12000)
stat(jersey, "cut")
for cycle in range(3):
    relax(jersey, 8, 0.5)
    guarded_outside(jersey, body_rest, 0.016)
stat(jersey, "wrapped")
def jersey_volume(p):
    ax = abs(p.x)
    d = 0.014 * math.exp(-(((ax - 0.17) / 0.07) ** 2 + ((p.z - 1.43) / 0.06) ** 2))  # shoulder caps
    d += 0.008 * ss(1.15, 1.35, p.z) * (ax < 0.24)                                     # chest protector
    return d
push(jersey, jersey_volume)
guarded_outside(jersey, body_rest, 0.015)
stat(jersey, "shaped")
# Sleeves only: the true arm may be thicker than the smoothed one, but on the
# torso this pass prints the shoulder blades through.
_before = [v.co.copy() for v in jersey.data.vertices]
guarded_outside(jersey, body_true, 0.008)
for v, b in zip(jersey.data.vertices, _before):
    if abs(b.x) < 0.22:
        v.co = b
jersey.data.update()
# The hem hangs outside the padded pants: push it radially past the pants' outer wall.
pants_shell = bpy.data.objects["PantsShell"]
_pbm = bmesh.new(); _pbm.from_mesh(pants_shell.data)
_ptree = BVHTree.FromBMesh(_pbm)
_band = [v.co for v in pants_shell.data.vertices if 0.98 < v.co.z < 1.08]
_cy = sum(p.y for p in _band) / max(1, len(_band))
def _pants_radius(z, d):
    origin = Vector((0.0, _cy, z))
    best, start = None, origin
    for _ in range(6):
        loc, nrm, fi, dist = _ptree.ray_cast(start, d, 1.0)
        if loc is None:
            break
        best = (loc - origin).length
        start = loc + d * 0.001
    return best
_moved = 0
def _hem(bm):
    global _moved
    for v in bm.verts:
        z = v.co.z
        if z > 1.17:
            continue
        w = 1.0 if z < 1.075 else max(0.0, (1.17 - z) / (1.17 - 1.075))
        flat = Vector((v.co.x, v.co.y - _cy, 0.0))
        r = flat.length
        if r < 1e-4:
            continue
        d = flat / r
        rp = _pants_radius(min(z, 1.07), d)
        if rp is None:
            continue
        want = rp + 0.016
        if r < want:
            nr = r + (want - r) * (w * w * (3 - 2 * w))
            v.co = Vector((0.0, _cy, z)) + d * nr
            _moved += 1
edit(jersey, _hem)
print("HEM moved", _moved)
relax(jersey, 2, 0.3)
_under = _low = 0
for v in jersey.data.vertices:
    if v.co.z < 1.075:
        _low += 1
        rp = _pants_radius(v.co.z, Vector((v.co.x, v.co.y - _cy, 0)).normalized())
        if rp is not None and Vector((v.co.x, v.co.y - _cy, 0)).length < rp + 0.004:
            _under += 1
print("WAIST jersey points below pants top", _low, "inside pants", _under)
_pbm.free()
bpy.data.objects.remove(pants_shell)
decimate(jersey, 3500)
relax(jersey, 1, 0.3)
finish(jersey, 0.0, (0.09, 0.29, 0.6, 1))
clearance(jersey, "jersey")

skin(pants)
skin(jersey)
for ob in (jersey, pants):
    zs = [v.co.z for v in ob.data.vertices]
    print("GARMENT", ob.name, "verts", len(ob.data.vertices), "z", round(min(zs), 3), round(max(zs), 3))
bpy.data.objects.remove(body_rest)
bpy.data.objects.remove(body_true)

# ---------------------------------------------------------------- previews
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
scene.collection.objects.link(cam)
scene.camera = cam
scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.color_type = "MATERIAL"
scene.display.shading.show_cavity = True
scene.render.resolution_x, scene.render.resolution_y = 700, 900
tag = os.path.splitext(os.path.basename(__file__))[0]
def render(name, loc, rot):
    cam.location = loc
    cam.rotation_euler = rot
    scene.render.filepath = os.path.join(OUT, tag + "_" + name)
    bpy.ops.render.render(write_still=True)
render("front.png", (0, -3.6, 1.05), (math.radians(90), 0, 0))
render("back.png", (0, 3.6, 1.05), (math.radians(90), 0, math.radians(180)))
arm.data.pose_position = "POSE"
pb = arm.pose.bones
for side, sign in (("L", 1), ("R", -1)):
    for bone, rot in (("upperarm01.", (0, 0, sign * math.radians(-35))), ("lowerarm01.", (math.radians(-45), 0, 0)),
                      ("upperleg01.", (math.radians(-40), 0, 0)), ("lowerleg01.", (math.radians(55), 0, 0))):
        if bone + side in pb:
            b = pb[bone + side]
            b.rotation_mode = "XYZ"
            b.rotation_euler = rot
bpy.context.view_layer.update()
render("posed.png", (2.4, -2.8, 1.0), (math.radians(90), 0, math.radians(40)))
for b in pb:
    b.rotation_euler = (0, 0, 0)
arm.data.pose_position = "REST"
bpy.context.view_layer.update()

bpy.ops.object.select_all(action="DESELECT")
for ob in (arm, jersey, pants):
    ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, tag + ".glb"), export_format="GLB", use_selection=True,
                          export_skins=True, export_animations=False)
print("KIT_V1_OK")
