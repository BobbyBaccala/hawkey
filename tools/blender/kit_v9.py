"""Hawkey kit v2 (Blender kit pass 2): clean, deliberately shaped sweater and
breezers around the CC0 base body, built headless in Blender.

Run through the Blender bridge (tools/blender/README.md):
    blender -b --factory-startup --python kit_v2.py -- <bridge_root>
Reads <bridge_root>/input/player-base-v1.glb, writes <bridge_root>/out/<script>.glb
(Jersey and Pants skinned to the base skeleton) and preview renders.

Pass 1 shrink-wrapped the garments onto a smoothed body, which printed the
navel, hip and shoulder-blade hollows into the cloth (dents and lumps in game)
and left the breezers as tight shorts that crumpled in a crouch. Pass 2:
- garments are lofted superellipse sections sized from body measurements,
  with the profile smoothed along its length (no lumps), shoulder pads, a
  chest protector, a flared hem, padded hips/thighs and flared leg openings;
- the body is never used as a wrap target: only points the body would poke
  through are lifted out along the garment normal, with the lift spread over
  the neighbours so it becomes a soft bulge rather than a dent;
- breezers get a raised belt band and rolled leg openings (real thickness at
  the hem) and stiff skinning (weights smoothed over the surface, limited to
  the pelvis/spine/thigh bones) so they hold their shape in a skating crouch.
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


# ---------------------------------------------------------------- pass 2 helpers
def measure_torso(z0, z1, steps, pred, ease, minimum):
    pts, sizes = [], []
    for k in range(steps + 1):
        z = z0 + (z1 - z0) * k / steps
        c = Vector((0, 0, z))
        ys = [p.y for p, r in body_pts if abs(p.z - z) < 0.02 and pred(p, r)]
        if ys:
            c.y = (min(ys) + max(ys)) * 0.5
        sizes.append(ring_size(c, Vector((0, 0, 1)), (z1 - z0) / steps * 0.6, pred, ease, minimum))
        pts.append(c)
    # The ring centres wander with the anatomy: smooth them too.
    ys = [c.y for c in pts]
    for k in range(1, len(pts) - 1):
        pts[k].y = 0.25 * ys[k - 1] + 0.5 * ys[k] + 0.25 * ys[k + 1]
    return pts, sizes

def measure_limb(a_pt, b_pt, steps, pred, ease, minimum, extend=(0.0, 0.0), midline_gap=None, max_r=1.0):
    axis = (b_pt - a_pt).normalized()
    a_pt = a_pt - axis * extend[0]
    b_pt = b_pt + axis * extend[1]
    length = (b_pt - a_pt).length
    pts, sizes = [], []
    for k in range(steps + 1):
        c = a_pt + axis * (length * k / steps)
        u, w, a, b = ring_size(c, axis, length / steps * 0.6, pred, ease, minimum, max_r)
        if midline_gap is not None:
            reach_x = abs(u.x) * a + abs(w.x) * b
            limit = abs(c.x) - midline_gap
            if reach_x > limit > 0.02:
                a *= limit / reach_x
                b *= limit / reach_x
        sizes.append((u, w, a, b))
        pts.append(c)
    return pts, sizes

def smooth_sizes(sizes, passes=3, keep=0.004):
    """Smooth the half-axes along the loft; never shrink a ring by more than keep."""
    out = list(sizes)
    for _ in range(passes):
        nxt = []
        for k, (u, w, a, b) in enumerate(out):
            if 0 < k < len(out) - 1:
                a2 = 0.25 * out[k - 1][2] + 0.5 * a + 0.25 * out[k + 1][2]
                b2 = 0.25 * out[k - 1][3] + 0.5 * b + 0.25 * out[k + 1][3]
                a, b = max(a2, a - keep), max(b2, b - keep)
            nxt.append((u, w, a, b))
        out = nxt
    return out

def loft(name, pts, sizes, segments=40, n=2.0):
    """Closed superellipse loft (n=2 ellipse, larger n squarer)."""
    bm = bmesh.new()
    rings = []
    e = 2.0 / n
    for c, (u, w, a, b) in zip(pts, sizes):
        ring = []
        for k in range(segments):
            t = 2 * math.pi * k / segments
            ct, st = math.cos(t), math.sin(t)
            x = math.copysign(abs(ct) ** e, ct)
            y = math.copysign(abs(st) ** e, st)
            ring.append(bm.verts.new(c + u * (a * x) + w * (b * y)))
        rings.append(ring)
    for r0, r1 in zip(rings, rings[1:]):
        for k in range(segments):
            bm.faces.new((r0[k], r0[(k + 1) % segments], r1[(k + 1) % segments], r1[k]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    return to_object(bm, name)

def target(ob):
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.transform(ob.matrix_world)
    bm.normal_update()
    bm.faces.ensure_lookup_table()
    return BVHTree.FromBMesh(bm), bm

BODY = (body_tree, bm_body)
# In game the base body is discarded under the kit (uniform.gdshader: region 1
# torso/arms always, region 2 shorts for skaters, hands under gloves), so the
# garments only have to clear the parts that are drawn: head/neck (0) and the
# legs below the breezers (3). Lifting off hidden anatomy only adds lumps.
def visible_body():
    bm = bm_body.copy()
    bm.verts.ensure_lookup_table()
    drop = [f for f in bm.faces if any(region[v.index] not in (0, 3) for v in f.verts)]
    bmesh.ops.delete(bm, geom=drop, context="FACES")
    bm.normal_update()
    bm.faces.ensure_lookup_table()
    print("VISIBLE body faces", len(bm.faces), "of", len(bm_body.faces))
    return BVHTree.FromBMesh(bm), bm
VIS = visible_body()

def lift_out(ob, targets, gap, spread=3, label="", only=None, reach=0.12, cap=0.035):
    """Lift garment points the targets poke through (closer than gap) out
    along the garment normal; the lift is spread over neighbours so it reads
    as a soft bulge, never a dent. Returns the largest lift."""
    outward_normals(ob)
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.normal_update()
    bm.verts.ensure_lookup_table()
    need = [0.0] * len(bm.verts)
    for v in bm.verts:
        if only is not None and not only(v.co):
            continue
        for tree, tbm in targets:
            loc, nrm, fi, dist = tree.find_nearest(v.co)
            if loc is None or dist > reach:
                continue
            fn = tbm.faces[fi].normal
            # Only a surface facing the same way as the garment here can push
            # it out (the torso must not push the inside of a sleeve, one
            # thigh must not push the other leg).
            if fn.dot(v.normal) < 0.4:
                continue
            g = (v.co - loc).dot(fn)
            want = gap - g
            if want > cap:
                want = cap
            need[v.index] = max(need[v.index], want)
    for _ in range(spread):
        nxt = list(need)
        for v in bm.verts:
            nb = [need[e.other_vert(v).index] for e in v.link_edges]
            if nb:
                nxt[v.index] = max(need[v.index], 0.6 * sum(nb) / len(nb))
        need = nxt
    moved = 0
    for v in bm.verts:
        if need[v.index] > 1e-5:
            v.co += v.normal * need[v.index]
            moved += 1
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()
    print("LIFT", label, "moved", moved, "max_cm", round(max(need) * 100, 2))
    return max(need)

def bump(c, r):
    """Gaussian bump weight around point c, radii r (Vector)."""
    def f(p):
        d = p - c
        return math.exp(-((d.x / r.x) ** 2 + (d.y / r.y) ** 2 + (d.z / r.z) ** 2))
    return f

def stiff_weights(ob, allowed, iterations, strength=0.5):
    """Smooth skin weights over the garment surface (stiff padded gear), keep
    only bones whose names start with one of `allowed`, top 4, normalised."""
    names = [g.name for g in ob.vertex_groups]
    ok = [n.startswith(allowed) for n in names]
    me = ob.data
    w = [dict() for _ in me.vertices]
    for v in me.vertices:
        for g in v.groups:
            if ok[g.group] and g.weight > 0.0:
                w[v.index][g.group] = g.weight
    nbrs = [[] for _ in me.vertices]
    for e in me.edges:
        a, b = e.vertices
        nbrs[a].append(b)
        nbrs[b].append(a)
    for _ in range(iterations):
        nxt = []
        for i, d in enumerate(w):
            acc = {g: x * (1.0 - strength) for g, x in d.items()}
            if nbrs[i]:
                s = strength / len(nbrs[i])
                for j in nbrs[i]:
                    for g, x in w[j].items():
                        acc[g] = acc.get(g, 0.0) + x * s
            nxt.append(acc)
        w = nxt
    for gi in range(len(names)):
        ob.vertex_groups[gi].remove(list(range(len(me.vertices))))
    for i, d in enumerate(w):
        top = sorted(d.items(), key=lambda kv: -kv[1])[:4]
        s = sum(x for _, x in top) or 1.0
        for g, x in top:
            if x / s > 0.01:
                ob.vertex_groups[g].add([i], x / s, "REPLACE")

def smooth_region_weights(ob, drop, region, iterations, strength=0.5):
    """Drop bones whose names start with `drop`, then smooth weights over the
    surface for vertices where region(co) is true (others keep theirs)."""
    names = [g.name for g in ob.vertex_groups]
    me = ob.data
    w = [{g.group: g.weight for g in v.groups if g.weight > 0.0 and not names[g.group].startswith(drop)} for v in me.vertices]
    for d in w:
        s_ = sum(d.values()) or 1.0
        for g in d:
            d[g] /= s_
    nbrs = [[] for _ in me.vertices]
    for e in me.edges:
        a, b = e.vertices
        nbrs[a].append(b)
        nbrs[b].append(a)
    mask = [region(v.co) for v in me.vertices]
    for _ in range(iterations):
        nxt = []
        for i, d in enumerate(w):
            if not mask[i] or not nbrs[i]:
                nxt.append(d)
                continue
            acc = {g: x * (1.0 - strength) for g, x in d.items()}
            s_ = strength / len(nbrs[i])
            for j in nbrs[i]:
                for g, x in w[j].items():
                    acc[g] = acc.get(g, 0.0) + x * s_
            nxt.append(acc)
        w = nxt
    for gi in range(len(names)):
        ob.vertex_groups[gi].remove(list(range(len(me.vertices))))
    for i, d in enumerate(w):
        top = sorted(d.items(), key=lambda kv: -kv[1])[:4]
        s_ = sum(x for _, x in top) or 1.0
        for g, x in top:
            if x / s_ > 0.01:
                ob.vertex_groups[g].add([i], x / s_, "REPLACE")

def roll_openings(ob, select, inward, up, steps=2):
    """Turn the chosen open edges in and up: visible thickness at a hem."""
    def plan(c, lp):
        if not select(c):
            return None
        def fn(co, t, cc):
            radial = Vector((co.x - cc.x, co.y - cc.y, co.z - cc.z))
            radial -= Vector((0, 0, radial.z))
            out = co - radial.normalized() * inward * min(1.0, t * 2.0)
            out.z += up * max(0.0, t * 2.0 - 1.0)
            return out
        return fn, steps
    extrude_openings(ob, plan)

def decimate_to_verts(ob, target):
    for _ in range(4):
        have = len(ob.data.vertices)
        if have <= target:
            return
        m = ob.modifiers.new("decimate", "DECIMATE")
        m.ratio = max(0.05, target / have * 0.98)
        apply_mod(ob, m)

def level_opening(ob, select, z_of, passes=6):
    """Square up a ragged opening: put its edge back on the cut height and
    smooth it along the loop (a hem the lift pushed about unevenly)."""
    def run(bm):
        for lp in boundary_loops(bm):
            c = centre(lp)
            if not select(c):
                continue
            n = len(lp)
            for _ in range(passes):
                new = []
                for i, v in enumerate(lp):
                    a, b = lp[i - 1].co, lp[(i + 1) % n].co
                    new.append((a + b + v.co * 2.0) * 0.25)
                for v, co in zip(lp, new):
                    v.co = co
            for v in lp:
                v.co.z = z_of(v.co)
            # pull the first row above the edge along so the hem band is even
            for v in lp:
                for e in v.link_edges:
                    o = e.other_vert(v)
                    if not o.is_boundary:
                        o.co.x = o.co.x * 0.5 + v.co.x * 0.5
                        o.co.y = o.co.y * 0.5 + v.co.y * 0.5
    edit(ob, run)

# ---------------------------------------------------------------- breezers
hip_l, knee_l = bone_world("upperleg01.L"), bone_world("lowerleg01.L")
hip_r, knee_r = bone_world("upperleg01.R"), bone_world("lowerleg01.R")
print("BONES hip", tuple(round(x, 3) for x in hip_l), "knee", tuple(round(x, 3) for x in knee_l))
thigh = lambda side_x: (lambda p, r: r in (2, 1, 3) and p.x * side_x > 0.0)
pp, ps = measure_torso(0.80, 1.10, 10, lambda p, r: r in (1, 2) and abs(p.x) < 0.24 and p.z > 0.78, 0.012, 0.1)
ps = smooth_sizes(ps)
pelvis = loft("pelvis", pp, ps, 48, 2.3)
legs = []
for s, h, k in ((L, hip_l, knee_l), (R, hip_r, knee_r)):
    lp, ls = measure_limb(h + Vector((0.025 if s == L else -0.025, 0, 0)), k, 8, thigh(1 if s == L else -1), 0.002, 0.05,
                          max_r=0.105)
    ls = smooth_sizes(ls, 4)
    # kit v6: strong taper (26% width / 22% depth by the knee) so the breezer legs hang like real pants instead of a drum.
    for i in range(1, len(ls)):
        u, w, a, b = ls[i]
        taper = ss(0.12, 1.0, i / (len(ls) - 1))
        ls[i] = (u, w, a * (1.0 - 0.32 * taper), b * (1.0 - 0.28 * taper))
    # Keep each leg on its own side of the crotch (inner wall >= 1.5 cm off the
    # midline) by moving the ring outward and narrowing it, not by squashing.
    for i in range(len(ls)):
        u, w, a, b = ls[i]
        c = lp[i]
        inner = abs(c.x) - (abs(u.x) * a + abs(w.x) * b)
        deficit = 0.015 - inner
        if deficit > 0:
            c = c.copy()
            c.x += math.copysign(deficit * 0.5, c.x)
            reach_x = abs(u.x) * a + abs(w.x) * b
            k = max(0.6, (reach_x - deficit * 0.5) / reach_x)
            ls[i] = (u, w, a * k, b * (0.5 + 0.5 * k))
            lp[i] = c
    legs.append(loft("thigh" + s, lp, ls, 40, 2.3))
pants = fuse("Pants", [pelvis] + legs, 0.012)
pants_planes = [(Vector((0, 0, 1.085)), Vector((0, 0, 1)))]
for h, k in ((hip_l, knee_l), (hip_r, knee_r)):
    axis = (k - h).normalized()
    pants_planes.append((h + (k - h) * 0.80, axis))  # leg opening a hand above the knee
stat(pants, "fused")
cut(pants, pants_planes)
tidy(pants, "pants")
decimate(pants, 12000)
for cycle in range(3):
    relax(pants, 2, 0.5)
    lift_out(pants, [VIS], 0.018, 3, "pants%d" % cycle)
# Padding: hip pads on the sides, thigh guards on the fronts, kidney/tailbone at the back.
pad_fns = [bump(Vector((sx * 0.175, 0.0, 0.985)), Vector((0.06, 0.09, 0.07))) for sx in (1, -1)]
thigh_fns = [bump(Vector((sx * 0.105, -0.11, 0.74)), Vector((0.07, 0.06, 0.09))) for sx in (1, -1)]
back_fn = bump(Vector((0.0, 0.12, 0.98)), Vector((0.12, 0.05, 0.08)))
belt = lambda p: ss(1.035, 1.05, p.z) * ss(1.085, 1.072, p.z)
push(pants, lambda p: 0.012 * max(f(p) for f in pad_fns) + 0.006 * max(f(p) for f in thigh_fns) + 0.010 * back_fn(p) + 0.006 * belt(p))
relax(pants, 1, 0.3)
lift_out(pants, [VIS], 0.016, 3, "pants-final")
outward_normals(pants)
roll_openings(pants, lambda c: c.z < 0.85, 0.012, 0.03)
level_opening(pants, lambda c: c.z < 0.85, lambda co: co.z, 4)
_shell = bpy.data.objects.new("PantsShell", pants.data.copy())
scene.collection.objects.link(_shell)
decimate_to_verts(pants, 3700)
relax(pants, 1, 0.2)
finish(pants, 0.0, (0.04, 0.05, 0.07, 1))
clearance(pants, "pants")

# ---------------------------------------------------------------- sweater
sh_l, el_l, wr_l = bone_world("upperarm01.L"), bone_world("lowerarm01.L"), bone_world("wrist.L")
sh_r, el_r, wr_r = bone_world("upperarm01.R"), bone_world("lowerarm01.R"), bone_world("wrist.R")
tp, ts = measure_torso(0.86, 1.53, 16, lambda p, r: r == 1 and abs(p.x) < 0.24, 0.03, 0.1)
shaped = []
for c, (u, w, a, b) in zip(tp, ts):
    z = c.z
    a += 0.002 * ss(1.28, 1.42, z) * ss(1.53, 1.47, z)     # shoulder pads square the shoulder line
    b += 0.010 * ss(1.15, 1.35, z) * ss(1.53, 1.45, z)     # chest/back protector
    hem = 0.008 * ss(1.04, 0.88, z)                          # loose hem hanging over the breezers
    a, b = a + hem, b + hem
    # Below the belt the sweater hangs outside the padded breezers: never
    # smaller than the breezer ring (plus hip pads) at that height.
    if z < 1.16:
        j = min(range(len(pp)), key=lambda i: abs(pp[i].z - min(z, 1.08)))
        over = ss(1.16, 1.08, z)
        a = max(a, (ps[j][2] + 0.024 + 0.02) * over + a * (1 - over))
        b = max(b, (ps[j][3] + 0.012 + 0.02) * over + b * (1 - over))
    shaped.append((u, w, a, b))
ts = smooth_sizes(shaped, 4)
trunk_ob = loft("trunk", tp, ts, 56, 2.0)
nk_p, nk_s = measure_torso(1.47, 1.56, 2, lambda p, r: abs(p.x) < 0.09 and p.z > 1.45, 0.02, 0.06)
neck_ring = loft("neckband", nk_p, nk_s, 32, 2.0)
sleeves = []
for s, sh, el, wr in ((L, sh_l, el_l, wr_l), (R, sh_r, el_r, wr_r)):
    # Fixed pro-sleeve girth over the elbow pads: full at the shoulder, a
    # rounded pad at the elbow, tapering to a cuff that sits over the glove.
    for a_pt, b_pt, r0, r1, ext in ((sh, el, 0.074, 0.066, (0.07, 0.03)), (el, wr, 0.066, 0.056, (0.03, 0.015))):
        axis = (b_pt - a_pt).normalized()
        a0 = a_pt - axis * ext[0]
        b0 = b_pt + axis * ext[1]
        pts, sizes = [], []
        for k in range(7):
            t = k / 6
            c = a0 + (b0 - a0) * t
            u = axis.cross(Vector((0, 1, 0)))
            if u.length < 0.1:
                u = axis.cross(Vector((1, 0, 0)))
            u.normalize()
            w = axis.cross(u).normalized()
            r = r0 + (r1 - r0) * t
            pts.append(c)
            sizes.append((u, w, r, r * 0.94))
        sleeves.append(loft("sleeve" + s, pts, sizes, 28, 2.0))
jersey = fuse("Jersey", [trunk_ob, neck_ring] + sleeves, 0.011)
jersey_planes = [(Vector((0, 0, 0.90)), Vector((0, 0, -1))), (Vector((0, 0, 1.545)), Vector((0, 0, 1)))]
for el, wr in ((el_l, wr_l), (el_r, wr_r)):
    axis = (wr - el).normalized()
    jersey_planes.append((wr - axis * 0.005, axis))  # sleeve ends at the wrist
stat(jersey, "fused")
cut(jersey, jersey_planes)
tidy(jersey, "jersey")
decimate(jersey, 16000)
for cycle in range(3):
    relax(jersey, 2, 0.5)
    lift_out(jersey, [VIS], 0.014, 3, "jersey%d" % cycle)
# The hem hangs outside the padded breezers.
PANTS = target(bpy.data.objects["PantsShell"])
lift_out(jersey, [PANTS], 0.014, 4, "hem", only=lambda p: p.z < 1.16, cap=0.02)
level_opening(jersey, lambda c: c.z < 1.0, lambda co: 0.90)
relax(jersey, 1, 0.3)
lift_out(jersey, [VIS], 0.012, 3, "jersey-final")
PANTS[1].free()
bpy.data.objects.remove(bpy.data.objects["PantsShell"])
decimate_to_verts(jersey, 4050)
relax(jersey, 1, 0.2)
finish(jersey, 0.0, (0.09, 0.29, 0.6, 1))
clearance(jersey, "jersey")

skin(pants)
stiff_weights(pants, ("root", "pelvis", "spine05", "spine04", "upperleg01", "upperleg02"), 10, 0.5)
skin(jersey)
# Blend local skin-weight transitions before the regional hem constraint.
smooth_region_weights(jersey, (), lambda co: True, 4, 0.30)
# The sweater hangs from the shoulders: no thigh bones (they dragged the hem
# into folds when a leg lifted) and stiffer weights round the waist and hem.
smooth_region_weights(jersey, ("upperleg", "lowerleg", "foot"), lambda co: co.z < 1.24 and abs(co.x) < 0.3, 8, 0.5)
for ob in (jersey, pants):
    zs = [v.co.z for v in ob.data.vertices]
    print("GARMENT", ob.name, "verts", len(ob.data.vertices), "faces", len(ob.data.polygons), "z", round(min(zs), 3), round(max(zs), 3))
bpy.data.objects.remove(body_rest)
bpy.data.objects.remove(body_true)

# ---------------------------------------------------------------- previews
skin_mat = bpy.data.materials.new("skin_preview")
skin_mat.diffuse_color = (0.62, 0.6, 0.58, 1)
body.data.materials.clear()
body.data.materials.append(skin_mat)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
scene.collection.objects.link(cam)
scene.camera = cam
scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "STUDIO"
scene.display.shading.color_type = "MATERIAL"
scene.display.shading.show_cavity = True
scene.display.shading.show_specular_highlight = True
scene.render.film_transparent = False
scene.world = bpy.data.worlds.new("w")
scene.world.color = (0.82, 0.84, 0.86)
scene.render.resolution_x, scene.render.resolution_y = 700, 900
tag = os.path.splitext(os.path.basename(__file__))[0]
def look(loc, at):
    cam.location = Vector(loc)
    cam.rotation_euler = (Vector(at) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
def render(name):
    scene.render.filepath = os.path.join(OUT, tag + "_" + name)
    bpy.ops.render.render(write_still=True)
look((0, -3.6, 1.0), (0, 0, 1.0)); render("front.png")
look((0, 3.6, 1.0), (0, 0, 1.0)); render("back.png")
look((3.6, 0, 1.0), (0, 0, 1.0)); render("side.png")
# Skating crouch: thighs forward, knees bent, arms forward.
arm.data.pose_position = "POSE"
pb = arm.pose.bones
for side, sign in (("L", 1), ("R", -1)):
    for bone, rot in (("upperarm01.", (math.radians(-30), 0, sign * math.radians(-40))), ("lowerarm01.", (math.radians(-45), 0, 0)),
                      ("upperleg01.", (math.radians(-65), 0, 0)), ("lowerleg01.", (math.radians(85), 0, 0))):
        if bone + side in pb:
            b = pb[bone + side]
            b.rotation_mode = "XYZ"
            b.rotation_euler = rot
bpy.context.view_layer.update()
look((3.2, -0.6, 0.9), (0, 0, 0.75)); render("crouch_side.png")
look((2.2, -2.6, 1.0), (0, 0, 0.8)); render("crouch_34.png")
for b in pb:
    b.rotation_euler = (0, 0, 0)
arm.data.pose_position = "REST"
bpy.context.view_layer.update()

bpy.ops.object.select_all(action="DESELECT")
for ob in (arm, jersey, pants):
    ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, tag + ".glb"), export_format="GLB", use_selection=True,
                          export_skins=True, export_animations=False)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, tag + ".blend"))
print("KIT_V8B_OK")


