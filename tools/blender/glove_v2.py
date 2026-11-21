import bpy, bmesh, json, math, os, sys
# Builds assets/gear/glove-v2.glb: glove_v1 (closed-fist skater glove, our own
# design, no source asset) with each finger ONE continuous padded roll wrapped
# round the shaft - three puffed segments with sewn breaks (finger_roll) - in
# place of v1's three separate egg-shaped pillows per finger, which read as a
# bunch of grapes with dark gaps. Neighbouring rolls touch, as on a real glove.
#   blender -b --factory-startup --python-exit-code 1 --python tools/blender/glove_v2.py -- <bridge>
# writes <bridge>/out/glove-v2.glb (+ previews); copy it to assets/gear/.
#
# Frame = Godot glove space used by skater_visual.gd fit_glove(): cuff toward +Y,
# shaft through the fist along X at GLOVE_HOLE (0,-0.035,-0.005), back of the hand +Z.
# glove_L has its thumb on +X (GLOVE_THUMB[0] = +1), glove_R is its mirror.
# Vertex colours are MASKS, recoloured per team in Godot (skater_visual.glove_part):
#   black = palm leather, red = kit, green = kit roll (darker), blue = cuff, white = trim.
from mathutils import Vector
OUT = os.path.join(sys.argv[sys.argv.index('--') + 1], 'out') if '--' in sys.argv else 'out'
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
s = bpy.context.scene
MASK = {'palm': (0, 0, 0), 'kit': (1, 0, 0), 'roll': (0, 1, 0), 'cuff': (0, 0, 1), 'trim': (1, 1, 1)}
HOLE = Vector((0, -0.035, -0.005))

def f(x, e):
    return math.copysign(abs(x) ** e, x)

class Part:
    def __init__(self):
        self.v = []; self.faces = []; self.col = []
    def add(self, verts, faces, mask):
        o = len(self.v)
        self.v += verts; self.col += [MASK[mask]] * len(verts)
        self.faces += [tuple(i + o for i in fc) for fc in faces]

def superellipsoid(nu, nv, e1, e2, place):
    """Closed pillow: poles at t=-1/+1, nv rings between. place(t, n, b) -> Vector
    maps unit local coords (t long axis, n outward, b width) to glove space."""
    verts = [place(-1.0, 0.0, 0.0)]
    for j in range(nv):
        v = -math.pi / 2 + math.pi * (j + 1) / (nv + 1)
        for i in range(nu):
            u = 2 * math.pi * i / nu
            g = f(math.cos(v), e1)
            verts.append(place(f(math.sin(v), e1), f(math.cos(u), e2) * g, f(math.sin(u), e2) * g))
    verts.append(place(1.0, 0.0, 0.0))
    faces = []
    for i in range(nu):
        faces.append((0, 1 + (i + 1) % nu, 1 + i))
    for j in range(nv - 1):
        a = 1 + j * nu; b = a + nu
        for i in range(nu):
            i2 = (i + 1) % nu
            faces.append((a + i, a + i2, b + i2, b + i))
    last = 1 + nv * nu; top = 1 + (nv - 1) * nu
    for i in range(nu):
        faces.append((top + i, top + (i + 1) % nu, last))
    return verts, faces

def arc_segment(x, r, phi0, phi1, half_n, half_b, nu=12, nv=4, e1=0.6, e2=0.95, bulge=0.0):
    """Finger pad bent round the shaft: angle phi from +Z (back) through -Y (bottom) to -Z (palm)."""
    pc = 0.5 * (phi0 + phi1); ph = 0.5 * (phi1 - phi0)
    def place(t, n, b):
        phi = math.radians(pc + t * ph)
        rr = r + n * half_n * (1.0 + bulge * (1 - t * t))
        return HOLE + Vector((x + b * half_b, -math.sin(phi) * rr, math.cos(phi) * rr))
    return superellipsoid(nu, nv, e1, e2, place)

def box_pillow(c, axes, half, nu=14, nv=4, e1=0.8, e2=0.85, bend=0.0):
    """Pillow with long axis axes[0], outward axes[1], width axes[2]; bend drops the
    ends back along -outward (convex backhand)."""
    T, N, B = [Vector(a).normalized() for a in axes]
    def place(t, n, b):
        p = c + T * (t * half[0]) + N * (n * half[1]) + B * (b * half[2])
        return p - N * (bend * (t * half[0]) ** 2)
    return superellipsoid(nu, nv, e1, e2, place)

def seg_pillow(p0, p1, outward, half_n, half_b, **kw):
    p0 = Vector(p0); p1 = Vector(p1); T = (p1 - p0)
    L = T.length; T.normalize()
    N = Vector(outward); N = (N - T * N.dot(T)).normalized(); B = T.cross(N)
    return box_pillow((p0 + p1) / 2, (T, N, B), (L / 2, half_n, half_b), **kw)

# Finger roll: rings along the arc round the shaft. Each of the three segments
# puffs to full size in its middle and pinches to SEAM at the sewn breaks; the
# tip and base close with a pole a little past the last ring.
SEAM = 0.90
SEG_S = (0.0, 0.22, 0.5, 0.78)
def finger_roll(x, r, phis, hn, hb, nu=11, e2=0.8, thin=(1.0, 0.95, 0.88)):
    rings = []   # (phi_deg, scale_n, scale_b)
    for k in range(3):
        a0, a1 = phis[k], phis[k + 1]
        for s_ in SEG_S if k < 2 else SEG_S + (1.0,):
            puff = SEAM + (1 - SEAM) * math.sin(math.pi * s_) ** 0.6
            if k == 0 and s_ == 0.0: puff = 0.80
            if k == 2 and s_ == 1.0: puff = 0.80
            rings.append((a0 + (a1 - a0) * s_, puff * thin[k], 0.94 + 0.06 * puff / max(puff, 1e-6) * thin[k] ** 0.3))
    def at(phi, n, b):
        ph = math.radians(phi)
        nd = Vector((0, -math.sin(ph), math.cos(ph)))
        return HOLE + Vector((x, 0, 0)) + nd * (r + n) + Vector((b, 0, 0))
    verts = []
    p0 = rings[0][0] - 0.35 * (rings[1][0] - rings[0][0]); verts.append(at(p0, 0, 0))
    for (phi, sn, sb) in rings:
        for i in range(nu):
            u = 2 * math.pi * i / nu
            verts.append(at(phi, f(math.cos(u), e2) * hn * sn, f(math.sin(u), e2) * hb * sb))
    p1 = rings[-1][0] + 0.35 * (rings[-1][0] - rings[-2][0]); verts.append(at(p1, 0, 0))
    faces = []
    for i in range(nu): faces.append((0, 1 + (i + 1) % nu, 1 + i))
    for j in range(len(rings) - 1):
        a = 1 + j * nu; b = a + nu
        for i in range(nu):
            i2 = (i + 1) % nu
            faces.append((a + i, a + i2, b + i2, b + i))
    last = len(verts) - 1; top = 1 + (len(rings) - 1) * nu
    for i in range(nu): faces.append((top + i, top + (i + 1) % nu, last))
    return verts, faces

def cuff(part, sides=18):
    """Banded gauntlet: three horizontal padded bands, white binding, rolled-in lip."""
    rings = []
    ys = [0.050 + (0.165 - 0.050) * k / 10 for k in range(11)]
    for k, y in enumerate(ys):
        a = (y - 0.050) / 0.115
        rx = 0.046 + 0.026 * a; rz = 0.040 + 0.025 * a
        band = 1.0 + 0.045 * math.sin(math.pi * ((y - 0.052) / 0.038)) ** 2 if y < 0.166 else 1.0
        rings.append((y, rx * band, rz * band, 'cuff'))
    rings += [(0.171, 0.0735, 0.0665, 'trim'), (0.1765, 0.0755, 0.0685, 'trim'), (0.1795, 0.0725, 0.0655, 'trim'), (0.1775, 0.068, 0.061, 'trim'), (0.171, 0.064, 0.057, 'cuff')]
    verts = []; cols = []
    for (y, rx, rz, m) in rings:
        for j in range(sides):
            a = 2 * math.pi * j / sides
            sq = 1.0 + 0.08 * math.sin(2 * a) ** 2
            cx = math.cos(a) * sq; sz = math.sin(a) * sq
            seam = 1.0 - 0.06 * math.exp(-((cx - 0.35) / 0.1) ** 2) * (sz > 0) - 0.06 * math.exp(-((cx + 0.35) / 0.1) ** 2) * (sz > 0)
            verts.append(Vector((cx * rx * seam, y, sz * rz * seam + 0.004)))
        cols.append(m)
    o = len(part.v)
    part.v += verts
    for m in cols: part.col += [MASK[m]] * sides
    for k in range(len(rings) - 1):
        for j in range(sides):
            j2 = (j + 1) % sides
            a = o + k * sides; b = a + sides
            part.faces.append((a + j, b + j, b + j2, a + j2))

def build(side):
    p = Part()
    # Palm leather core inside the fist.
    p.add(*box_pillow(Vector((0, 0.006, -0.008)), ((1, 0, 0), (0, 0, 1), (0, 1, 0)), (0.049, 0.034, 0.022), nu=8, nv=3, e1=0.6, e2=0.6), 'palm')
    # Dark leather bed under the finger pads (no see-through between fingers).
    p.add(*arc_segment(0.0, 0.031, 20, 182, 0.007, 0.046, nu=8, nv=3, e1=0.8, e2=0.5), 'palm')
    # Fingers from the thumb side outward: index, middle, ring, pinky.
    fingers = [(0.036, 0.0118, 0.0148, 1.0, 0.040), (0.012, 0.0122, 0.0152, 1.07, 0.041), (-0.012, 0.0118, 0.0148, 1.0, 0.040), (-0.036, 0.0106, 0.0136, 0.86, 0.038)]
    for (x, hb, hn, ln, r) in fingers:
        phis = [10 + (a - 10) * ln for a in (10, 70, 130, 186)]
        p.add(*finger_roll(x * side, r, phis, hn, hb * 1.04), 'roll')
    # Backhand: knuckle roll, mid panel, top panel (kit colour), bent convex.
    for (y, z, hy, hz, m) in [(-0.026, 0.036, 0.011, 0.015, 'roll'), (0.004, 0.039, 0.016, 0.016, 'roll'), (0.038, 0.036, 0.016, 0.015, 'kit')]:
        p.add(*box_pillow(Vector((0, y, z)), ((1, 0, 0), (0, 0, 1), (0, 1, 0)), (0.052, hz, hy), bend=4.5), m)
    # Thumb (two pads) and the stiff thumb lock along its outside.
    t = side
    # v2: the thumb comes down the palm side of the shaft and presses against
    # it (v1's lower pad ran straight through the shaft, so the stick hid its
    # middle and the tip showed as a loose shard beside the shaft).
    p.add(*seg_pillow((0.052 * t, 0.024, 0.010), (0.062 * t, -0.012, -0.018), (t, 0, 0.3), 0.017, 0.016, nu=12, nv=4), 'roll')
    p.add(*seg_pillow((0.064 * t, -0.014, -0.034), (0.050 * t, -0.052, -0.040), (t, -0.3, 0), 0.015, 0.0145, nu=12, nv=4, e1=0.8), 'roll')
    p.add(*seg_pillow((0.062 * t, 0.042, 0.020), (0.068 * t, -0.012, 0.015), (t, 0, 0.5), 0.010, 0.012, nu=10, nv=4), 'kit')
    p.ncuff_from = len(p.faces)
    cuff(p)
    return p

objs = []
for name, side in [('glove_L', 1.0), ('glove_R', -1.0)]:
    p = build(side)
    me = bpy.data.meshes.new(name)
    me.from_pydata([(v.x, -v.z, v.y) for v in p.v], [], p.faces)  # Godot -> Blender axes
    me.validate()
    bm = bmesh.new(); bm.from_mesh(me); bm.faces.ensure_lookup_table()
    bmesh.ops.recalc_face_normals(bm, faces=[fc for fc in bm.faces if fc.index < p.ncuff_from])
    bm.to_mesh(me); bm.free()
    for poly in me.polygons: poly.use_smooth = True
    a = me.color_attributes.new('Col', 'FLOAT_COLOR', 'POINT')
    for d, c in zip(a.data, p.col): d.color = (*c, 1.0)
    ob = bpy.data.objects.new(name, me); s.collection.objects.link(ob); objs.append(ob)

rep = {}
for o in objs:
    vs = [v.co for v in o.data.vertices]
    rep[o.name] = {'tris': sum(len(q.vertices) - 2 for q in o.data.polygons), 'verts': len(vs),
                   'min': [round(min(v[i] for v in vs), 4) for i in range(3)], 'max': [round(max(v[i] for v in vs), 4) for i in range(3)]}
print('GLOVE_REPORT', json.dumps(rep)); json.dump(rep, open(OUT + '/glove-v2-report.json', 'w'), indent=1)
bpy.ops.object.select_all(action='DESELECT')
for o in objs: o.select_set(True)
try:
    bpy.ops.export_scene.gltf(filepath=OUT + '/glove-v2.glb', use_selection=True, export_format='GLB', export_vertex_color='ACTIVE', export_all_vertex_colors=False, export_texcoords=False)
except TypeError:   # Blender 4.0 (cloud): older exporter option names
    bpy.ops.export_scene.gltf(filepath=OUT + '/glove-v2.glb', use_selection=True, export_format='GLB', export_colors=True, export_texcoords=False)
bpy.ops.wm.save_as_mainfile(filepath=OUT + '/glove-v2-' + 'v2' + '.blend')

# Preview: recolour masks to a teal kit, add a stick shaft through the hole.
PREV = {(0, 0, 0): (0.05, 0.05, 0.06), (1, 0, 0): (0.05, 0.42, 0.45), (0, 1, 0): (0.03, 0.27, 0.30), (0, 0, 1): (0.07, 0.48, 0.50), (1, 1, 1): (0.92, 0.92, 0.9)}
for o in objs:
    for d in o.data.color_attributes['Col'].data:
        k = tuple(round(c) for c in d.color[:3]); d.color = (*PREV[k], 1)
bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0.005, -0.035))
sh = bpy.context.active_object; sh.scale = (0.5, 0.019, 0.028)
sa = sh.data.color_attributes.new('Col', 'FLOAT_COLOR', 'POINT')
for d in sa.data: d.color = (0.6, 0.45, 0.25, 1)
objs[1].location.x = 0.25
s.render.engine = 'BLENDER_WORKBENCH'; s.display.shading.light = 'STUDIO'; s.display.shading.color_type = 'VERTEX'; s.display.shading.show_cavity = True
s.render.resolution_x, s.render.resolution_y = 900, 700
cd = bpy.data.cameras.new('NC'); cd.type = 'ORTHO'; cd.ortho_scale = 0.30
cam = bpy.data.objects.new('NC', cd); s.collection.objects.link(cam); s.camera = cam
def view(d, path, ctr=(0, 0, 0.035), scale=0.30):
    d = Vector(d).normalized(); cd.ortho_scale = scale
    cam.location = Vector(ctr) + d * 2; cam.rotation_euler = (-d).to_track_quat('-Z', 'Y').to_euler()
    s.render.filepath = path; bpy.ops.render.render(write_still=True)
objs[1].hide_render = True
view((0, -1, 0.15), OUT + '/glove-v2-back.png')      # back of the hand (Godot +Z = Blender -Y)
view((1, 0, 0), OUT + '/glove-v2-side.png')           # thumb side
view((0.8, -0.7, 0.4), OUT + '/glove-v2-three_q.png')
view((-0.3, 1, 0.1), OUT + '/glove-v2-palm.png')
objs[1].hide_render = False
view((0.2, -1, 0.35), OUT + '/glove-v2-pair.png', ctr=(0.125, 0, 0.04), scale=0.45)
print('GLOVE_V2_OK')
