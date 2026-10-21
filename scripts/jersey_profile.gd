extends RefCounted
## Shared sewn neckline contract for geometry and cloth shading.
const HEIGHT:=1.56
const FRONT_DROP:=0.032
const ROUND_DROP:=0.008
const POWER:=4.0
const BAND_WIDTH:=0.012
const SHADER_PROFILE:=Vector4(HEIGHT,FRONT_DROP,ROUND_DROP,POWER)
static func neck(angle: float) -> float:
	var front:=maxf(0.0,sin(angle))
	return HEIGHT-FRONT_DROP*pow(front,POWER)-ROUND_DROP*front
