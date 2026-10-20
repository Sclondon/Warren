// What moves a low plant (Undergrowth): a little sway in the wind, and anyone
// going through it (the shader's `pushers`, x y z and a radius, `pusher_count`
// of them) pushing it aside and down. `tall` is how far up the plant the vertex
// is (the higher, the further it goes). The answer is in the model's own space.

// How the pushers push a plant whose foot is at `here` (world): in x and z, the
// way away from each one near enough, by how strongly (0 to 1, more the nearer);
// in y, how strongly in all. `widen` stretches how far each one reaches (1 for
// the low plants; the corn, Corn, feels them further off).
vec3 pushed(vec3 here, float widen) {
	vec3 push = vec3(0.0);
	for (int i = 0; i < 8; i++) {
		if (i >= pusher_count) {
			break;
		}
		vec4 p = pushers[i];
		vec2 away = here.xz - p.xz;
		float far = length(away);
		float reach = (p.w * 1.5 + 0.35) * widen;
		if (far < reach && abs(here.y - p.y) < 2.5) {
			float k = 1.0 - far / reach;
			k *= k;
			push.xz += away / max(far, 0.001) * k;
			push.y += k;
		}
	}
	return push;
}

vec3 bent(mat4 model, vec3 vertex, float tall, float sway_by, float time) {
	vec3 here = (model * vec4(vertex, 1.0)).xyz;
	float t = time * 1.3 + dot(here.xz, vec2(0.21, 0.17));
	vec3 move = vec3(sin(t), 0.0, cos(t * 0.8)) * sway_by * tall * tall;
	// (pushed as a whole from its foot, all of it leaning the one way: from each
	// point's own place, its fronds were each pushed their own way and the plant
	// warped round him, the user, 2026-10-20: "The ferns seem to warp around the
	// player rather than be pushed away")
	vec3 foot = (model * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 push = pushed(foot, 1.0);
	move.xz += push.xz * tall * 0.9;
	move.y -= push.y * tall * 0.4;
	return inverse(mat3(model)) * move;
}
