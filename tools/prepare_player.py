"""Prepare the CC0 Innerscene/MakeHuman base as a clothed, reduced game mesh.
Usage: python tools/prepare_player.py downloaded-source.glb assets/player-base-v1.glb
Requires numpy, scipy, trimesh, fast-simplification. Original source/CC0 in ASSETS.md.
"""
import copy, json, struct, sys
from pathlib import Path
import numpy as np
import trimesh
import fast_simplification
from scipy.spatial import cKDTree

raw = Path(sys.argv[1]).read_bytes()
json_size = struct.unpack_from("<I", raw, 12)[0]
doc = json.loads(raw[20:20+json_size])
bin_start = 20 + json_size
binary = raw[bin_start+8:]
out = bytearray()
views, accessors = [], []
types = {5126:np.float32,5125:np.uint32,5123:np.uint16,5121:np.uint8}
dimensions = {"SCALAR":1,"VEC2":2,"VEC3":3,"VEC4":4,"MAT4":16}
def read(index):
    a = doc["accessors"][index]; v = doc["bufferViews"][a["bufferView"]]
    offset = v.get("byteOffset",0)+a.get("byteOffset",0)
    dtype = types[a["componentType"]]
    return np.frombuffer(binary,dtype=dtype,count=a["count"]*dimensions[a["type"]],offset=offset).reshape(a["count"],dimensions[a["type"]]).copy()
def append(array, component, kind):
    while len(out)%4: out.append(0)
    offset = len(out); chunk = array.astype(types[component]).tobytes();out.extend(chunk)
    views.append({"buffer":0,"byteOffset":offset,"byteLength":len(chunk)})
    a = {"bufferView":len(views)-1,"componentType":component,"count":len(array),"type":kind}
    if kind == "VEC3":a.update(min=array.min(axis=0).tolist(),max=array.max(axis=0).tolist())
    accessors.append(a)
    return len(accessors)-1

skin = doc["skins"][0]
bone_names = [doc["nodes"][i]["name"] for i in skin["joints"]]
new_meshes = []
for mesh_id, mesh in enumerate(doc["meshes"]):
    primitives = []
    for primitive in mesh["primitives"]:
        a=primitive["attributes"]
        points=read(a["POSITION"])
        faces=read(primitive["indices"]).reshape(-1,3)
        source_points = points.copy()
        # The source splits surface vertices at seams. Weld before simplification;
        # simplifying disconnected seam triangles produces visible holes.
        welded = trimesh.Trimesh(points,faces,process=True)
        welded.merge_vertices(merge_tex=True,merge_norm=True)
        points,faces = np.asarray(welded.vertices),np.asarray(welded.faces)
        target_count = min(len(faces),18000 if len(faces)>20000 else 1800)
        if len(faces)>target_count:
            points,faces=fast_simplification.simplify(points.astype(np.float64),faces.astype(np.int32),target_count=target_count)
        nearest = cKDTree(source_points).query(points)[1]
        joints=read(a["JOINTS_0"])[nearest]
        weights=read(a["WEIGHTS_0"])[nearest]
        names=[bone_names[i] for i in joints[np.arange(len(joints)),weights.argmax(axis=1)]]
        regions=[]
        for p,name in zip(points,names):
            if any(x in name for x in ["finger","wrist","metacarpal"]):region=4
            elif any(x in name for x in ["toe","foot"]):region=5
            elif "lowerleg" in name:region=3
            elif any(x in name for x in ["upperleg","pelvis"]) or name=="root":region=2
            elif any(x in name for x in ["spine","arm","breast","clavicle","shoulder"]):region=1
            else:region=0
            regions.append(region)
        geometry=trimesh.Trimesh(points,faces,process=False)
        normals=np.array(geometry.vertex_normals)
        regions=np.array(regions)
        # Padded cloth envelope. Pants/jersey retain silhouette without exposed anatomy.
        padding=np.select([regions==1,regions==2,regions==3,regions==4],[0.027,0.035,0.012,0.012],default=0)
        points=points + normals * padding[:,None]
        colors=np.ones((len(points),4),dtype=np.float32)
        colors[:,0]=regions / 8
        colors[:,1]=np.clip(points[:,1]/2,0,1)
        attrs={"POSITION":append(points,5126,"VEC3"),"NORMAL":append(normals,5126,"VEC3"),
               "JOINTS_0":append(joints,5123,"VEC4"),"WEIGHTS_0":append(weights,5126,"VEC4"),
               "COLOR_0":append(colors,5126,"VEC4")}
        primitives.append({"attributes":attrs,"indices":append(faces.reshape(-1,1),5125,"SCALAR"),"material":0})
    new_meshes.append({"name":mesh.get("name","human"),"primitives":primitives})
skin["inverseBindMatrices"] = append(read(skin["inverseBindMatrices"]),5126,"MAT4")
doc["meshes"]=new_meshes
doc["buffers"]=[{"byteLength":len(out)}]
doc["bufferViews"]=views
doc["accessors"]=accessors
doc["asset"]["extras"]={"source":"Innerscene, adapted from MakeHuman CC0 assets","license":"CC0-1.0"}
j=json.dumps(doc,separators=(",",":")).encode()
j+=b" "*((-len(j))%4)
out.extend(b"\0"*((-len(out))%4))
result=struct.pack("<III",0x46546c67,2,12+8+len(j)+8+len(out))+struct.pack("<II",len(j),0x4e4f534a)+j+struct.pack("<II",len(out),0x004e4942)+out
Path(sys.argv[2]).write_bytes(result)
print("Prepared",len(result),"bytes")
