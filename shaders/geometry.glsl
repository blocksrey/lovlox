varying vec3 worldP;
varying vec3 worldN;

#ifdef VERTEX
	uniform vec3 cameraP;
	uniform vec4 cameraO;
	uniform mat4 cameraT;

	uniform vec3 objectP;
	uniform vec4 objectO;
	uniform vec3 objectS;

	attribute vec3 vertexP;
	attribute vec3 vertexN;

	vec3 qrot(vec4 q, vec3 v) { return v + 2*cross(cross(v, q.xyz) - q.w*v, q.xyz); }
	vec3 qtor(vec4 q, vec3 v) { return v + 2*cross(cross(v, q.xyz) + q.w*v, q.xyz); }

	vec4 position(mat4 _, vec4 __) {
		worldP = objectP + qrot(objectO, objectS*vertexP);
		worldN = qrot(objectO, vertexN);

		return cameraT*vec4(qtor(cameraO, worldP - cameraP), 1);
	}
#endif

#ifdef PIXEL
	uniform vec4 objectC;

	void effect() {
		love_Canvases[0] = vec4(worldP, 1);
		love_Canvases[1] = vec4(worldN, 1);
		love_Canvases[2] = objectC;
	}
#endif
