uniform vec4 cameraO;
//uniform mat4 cameraT;

uniform sampler2D skyTex;

float PI = 3.14159265;
float TAU = 6.28318531;

vec3 qtor(vec4 q, vec3 v) { return v + 2*cross(cross(v, q.xyz) - q.w*v, q.xyz); }

vec2 hdridir(vec3 d) {
	float x = d.x;
	float y = d.y;
	float z = d.z;

	return vec2(
		atan(z, x)/TAU,
		atan(-y, -sqrt(x*x + z*z))/PI
	);
}

void effect() {
	vec3 relD = qtor(cameraO, vec3(2*(VaryingTexCoord.xy - 0.5), 1));

	love_Canvases[0] = texture2D(skyTex, hdridir(relD));
}