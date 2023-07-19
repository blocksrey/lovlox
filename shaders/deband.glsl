uniform sampler2D worldNs;
uniform sampler2D worldCs;

void effect() {
	vec2 texCoord = vec2(VaryingTexCoord.x, 1 - VaryingTexCoord.y);

	vec4 worldN = texture2D(worldNs, texCoord);
	vec4 worldC = texture2D(worldCs, texCoord);

	float light = 0.5*(1 + dot(worldN.xyz, normalize(vec3(1, 3, -2))));

	love_Canvases[0] = light*worldC;
}