extends RefCounted
## Original continuous sweater surface. Metres, Y up, matching the existing IK rig.
## No cloth simulation claim: shallow folds and sewn details are modeled at rest.

static func dimensions(goalie: bool) -> Array[Vector3]:
	if goalie:
		return [Vector3(.255,.95,.17),Vector3(.25,1.10,.185),Vector3(.28,1.30,.20),Vector3(.30,1.44,.17),Vector3(.13,1.53,.10)]
	return [Vector3(.24,.98,.16),Vector3(.22,1.10,.155),Vector3(.25,1.31,.17),Vector3(.27,1.44,.14),Vector3(.11,1.50,.09)]

static func section(y: float, sections: Array[Vector3]) -> Vector3:
	for i in range(sections.size()-1):
		if y<=sections[i+1].y:
			var u:=clampf((y-sections[i].y)/(sections[i+1].y-sections[i].y),0,1)
			# Smooth interpolation keeps shoulders from becoming a rigid cone.
			return sections[i].lerp(sections[i+1],smoothstep(0,1,u))
	return sections.back()

static func point(y: float, angle: float, sections: Array[Vector3]) -> Vector3:
	var d:=section(y,sections)
	var x:=cos(angle)
	var z:=sin(angle)
	# A slightly squared chest protector under the goalie sweater, not a sphere.
	var exponent:=0.86
	var hem:=1.0-smoothstep(sections[0].y,sections[0].y+.20,y)
	var fold:float=.0025*sin(angle*7.0+y*13.0)*hem+.0015*sin(angle*11.0-y*19.0)
	return Vector3(signf(x)*pow(absf(x),exponent)*(d.x+fold),y,signf(z)*pow(absf(z),exponent)*(d.z+fold)-.02)

static func torso(goalie: bool) -> ArrayMesh:
	var sections:=dimensions(goalie)
	var vertices:=PackedVector3Array()
	var normals:=PackedVector3Array()
	var uv:=PackedVector2Array()
	var indices:=PackedInt32Array()
	const ROWS:=40
	const SIDES:=64
	for row in range(ROWS+1):
		var y:=lerpf(sections[0].y,sections.back().y,float(row)/ROWS)
		for col in range(SIDES+1):
			var a:=TAU*col/SIDES
			vertices.append(point(y,a,sections))
			var tangent:=point(y,a+.001,sections)-point(y,a-.001,sections)
			var low:=maxf(sections[0].y,y-.001)
			var high:=minf(sections.back().y,y+.001)
			var up:=point(high,a,sections)-point(low,a,sections)
			normals.append(up.cross(tangent).normalized())
			uv.append(Vector2(float(col)/SIDES,y))
			if row<ROWS and col<SIDES:
				var i:=row*(SIDES+1)+col
				indices.append_array(PackedInt32Array([i,i+SIDES+2,i+SIDES+1,i,i+1,i+SIDES+2]))
	var arrays:=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_NORMAL]=normals
	arrays[Mesh.ARRAY_TEX_UV]=uv
	arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

static func fabric(kit: Color, accent: Color, sleeve: bool=false) -> ShaderMaterial:
	var shader:=Shader.new()
	shader.code="""shader_type spatial;
render_mode cull_disabled;
uniform vec4 kit:source_color;
uniform vec4 accent:source_color;
uniform bool sleeve=false;
void fragment(){
 float h=UV.y;
 float band=sleeve ? (smoothstep(.64,.65,h)-smoothstep(.79,.80,h)) : (smoothstep(1.005,1.008,h)-smoothstep(1.041,1.044,h));
 float trim=sleeve ? (smoothstep(.84,.85,h)-smoothstep(.87,.88,h)) : (smoothstep(1.057,1.06,h)-smoothstep(1.070,1.073,h));
 float frequency=sleeve?90.0:180.0;
 float attenuation=1.0-smoothstep(.7,2.0,length(fwidth(UV*frequency)));
 float weave=sin(UV.x*frequency*6.283)*sin(UV.y*frequency*6.283)*.008*attenuation;
 ALBEDO=mix(kit.rgb,accent.rgb,clamp(band+trim,0.0,1.0))+weave;
 ROUGHNESS=.83;
 SPECULAR=.22;
}
"""
	var material:=ShaderMaterial.new()
	material.shader=shader
	material.set_shader_parameter("kit",kit)
	material.set_shader_parameter("accent",accent)
	material.set_shader_parameter("sleeve",sleeve)
	return material

static func collar(parent: Node3D, goalie: bool, kit: Color, accent: Color) -> void:
	var y:=1.53 if goalie else 1.50
	# Low knit collar closes the otherwise raw opening without obscuring the neck.
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in range(2):
		for i in range(64):
			for ij in [Vector2(ring,i),Vector2(ring+1,i+1),Vector2(ring+1,i),Vector2(ring,i),Vector2(ring,i+1),Vector2(ring+1,i+1)]:
				var a:float=ij.y/64*TAU
				var f:float=ij.x/2.0
				var width:=lerpf(.13 if goalie else .11,.075,f)
				var depth:=lerpf(.10 if goalie else .09,.065,f)
				var front:=maxf(0,sin(a))
				st.set_color(accent if f<.5 else kit.darkened(.30))
				st.add_vertex(Vector3(width*cos(a),y+f*.028-front*.018,depth*sin(a)-.02))
	st.generate_normals()
	var instance:=MeshInstance3D.new()
	instance.name="BoundCollar"
	instance.mesh=st.commit()
	var material:=StandardMaterial3D.new()
	material.vertex_color_use_as_albedo=true
	material.roughness=.9
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	instance.material_override=material
	parent.add_child(instance)

static func helmet_mesh() -> ArrayMesh:
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(18):
		for col in range(64):
			for uv in [Vector2(row,col),Vector2(row+1,col+1),Vector2(row+1,col),Vector2(row,col),Vector2(row,col+1),Vector2(row+1,col+1)]:
				var t:float=uv.x/18.0
				var angle:float=uv.y/64.0*TAU
				var phi:float=t*PI*.56
				var forward:float=maxf(0,sin(angle))
				var side:float=absf(cos(angle))
				var y:float=cos(phi)*.112-t*t*(.020*side+.012*(1-forward))
				# A flatter crown and swept front/side shell over the brow and ears.
				var p:=Vector3(sin(phi)*cos(angle)*.112,y,sin(phi)*sin(angle)*(.142 if sin(angle)>0 else .132))
				p.y+=.004*cos(angle*4.0)*sin(phi)*sin(phi)
				st.set_smooth_group(0)
				st.add_vertex(p)
	st.generate_normals()
	return st.commit()
