// Shared by the voice visualizations. Ported from the GLSL of the web
// reference (github.com/GetStream/stream-voice-agent-demo,
// `app/components/visualizations/shaders.ts`) by way of iOS StreamChatAI's
// Metal port, keeping the math line for line so every platform renders alike.
//
// Colors arrive as HSV, hue a fraction of a turn, and leave premultiplied, so
// the halo melts into whatever is behind the view.

#include <flutter/runtime_effect.glsl>

precision highp float;

// The order is the order `VoiceVisualizationUniforms.apply` sets them in.
uniform vec2 uSize;
uniform vec3 uCol0;
uniform vec3 uCol1;
uniform vec3 uCol2;
uniform vec3 uCol3;
uniform vec3 uCol4;
uniform vec2 uTap;
uniform vec2 uHover;
uniform float uTime;
uniform float uCount;
uniform float uBright;
uniform float uSat;
uniform float uLoad;
uniform float uFlow;
uniform float uFlowSpin;
uniform float uOrbSpin;
uniform float uReact;
uniform float uExpressivity;
uniform float uDark;
uniform float uTapTime;
uniform float uHoverAmt;
uniform float uMic;
uniform float uVoice;
uniform float uScale;
uniform float uPixelRatio;

out vec4 fragColor;

// `pow` of a negative base is NaN on Metal, which Impeller targets.
float sq(float x) { return x * x; }

// `smoothstep` with its edges reversed is undefined; this is the formula WebGL
// drivers evaluate either way round.
float ss(float edge0, float edge1, float x) {
    float t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
}

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

vec3 desat(vec3 c, float s) {
    float l = dot(c, vec3(0.299, 0.587, 0.114));
    return mix(vec3(l), c, s);
}

vec3 saturate3(vec3 c, float s) {
    float l = dot(c, vec3(0.299, 0.587, 0.114));
    return clamp(mix(vec3(l), c, s), 0.0, 1.0);
}

vec2 rot2(vec2 p, float a) {
    float s = sin(a);
    float c = cos(a);
    return vec2(c * p.x + s * p.y, -s * p.x + c * p.y);
}

// The chosen color as is; dark mode lifts saturation a touch so it stays vivid
// on black.
vec3 vivid(vec3 hsv) {
    return hsv2rgb(vec3(hsv.x, clamp(hsv.y + uDark * 0.06, 0.0, 1.0), hsv.z));
}

// Waves spreading out from the last tap, fading within a second and a half.
float tapRipple(vec2 p) {
    float age = uTapTime;
    if (age > 1.5) return 0.0;
    float d = distance(p, uTap);
    float front = age * 0.75;
    float env = exp(-sq((d - front) / 0.14));
    float decay = exp(-age * 2.6);
    return sin(d * 34.0 - age * 24.0) * env * decay;
}

// A gentle ripple following a hovering pointer.
float hoverRipple(vec2 p) {
    if (uHoverAmt <= 0.001) return 0.0;
    float d = distance(p, uHover);
    float env = exp(-sq(d / 0.22));
    return sin(d * 30.0 - uTime * 7.0) * env * uHoverAmt * 0.6;
}

float poke(vec2 p) {
    return tapRipple(p) + hoverRipple(p);
}

// Ashima / Stefan Gustavson 3D simplex noise.
vec4 permute(vec4 x) { return mod(((x * 34.0) + 1.0) * x, 289.0); }
vec4 taylorInvSqrt(vec4 r) { return 1.79284291400159 - 0.85373472095314 * r; }

float snoise(vec3 v) {
    const vec2 C = vec2(1.0 / 6.0, 1.0 / 3.0);
    const vec4 D = vec4(0.0, 0.5, 1.0, 2.0);
    vec3 i = floor(v + dot(v, C.yyy));
    vec3 x0 = v - i + dot(i, C.xxx);
    vec3 g = step(x0.yzx, x0.xyz);
    vec3 l = 1.0 - g;
    vec3 i1 = min(g.xyz, l.zxy);
    vec3 i2 = max(g.xyz, l.zxy);
    vec3 x1 = x0 - i1 + 1.0 * C.xxx;
    vec3 x2 = x0 - i2 + 2.0 * C.xxx;
    vec3 x3 = x0 - 1.0 + 3.0 * C.xxx;
    i = mod(i, 289.0);
    vec4 p = permute(permute(permute(
                i.z + vec4(0.0, i1.z, i2.z, 1.0))
              + i.y + vec4(0.0, i1.y, i2.y, 1.0))
              + i.x + vec4(0.0, i1.x, i2.x, 1.0));
    float n_ = 1.0 / 7.0;
    vec3 ns = n_ * D.wyz - D.xzx;
    vec4 j = p - 49.0 * floor(p * ns.z * ns.z);
    vec4 x_ = floor(j * ns.z);
    vec4 y_ = floor(j - 7.0 * x_);
    vec4 x = x_ * ns.x + ns.yyyy;
    vec4 y = y_ * ns.x + ns.yyyy;
    vec4 h = 1.0 - abs(x) - abs(y);
    vec4 b0 = vec4(x.xy, y.xy);
    vec4 b1 = vec4(x.zw, y.zw);
    vec4 s0 = floor(b0) * 2.0 + 1.0;
    vec4 s1 = floor(b1) * 2.0 + 1.0;
    vec4 sh = -step(h, vec4(0.0));
    vec4 a0 = b0.xzyw + s0.xzyw * sh.xxyy;
    vec4 a1 = b1.xzyw + s1.xzyw * sh.zzww;
    vec3 p0 = vec3(a0.xy, h.x);
    vec3 p1 = vec3(a0.zw, h.y);
    vec3 p2 = vec3(a1.xy, h.z);
    vec3 p3 = vec3(a1.zw, h.w);
    vec4 norm = taylorInvSqrt(vec4(dot(p0, p0), dot(p1, p1), dot(p2, p2), dot(p3, p3)));
    p0 *= norm.x;
    p1 *= norm.y;
    p2 *= norm.z;
    p3 *= norm.w;
    vec4 m = max(0.6 - vec4(dot(x0, x0), dot(x1, x1), dot(x2, x2), dot(x3, x3)), 0.0);
    m = m * m;
    return 42.0 * dot(m * m, vec4(dot(p0, x0), dot(p1, x1), dot(p2, x2), dot(p3, x3)));
}

// How much the agent is talking, 0 to 1: a slow phrase gate times a faster
// syllable wobble, so speech ebbs and pauses instead of droning.
float speechEnv(float t) {
    float gate = ss(-0.25, 0.35, snoise(vec3(t * 0.6, 21.0, 0.0)));
    float syl = 0.55 + 0.45 * snoise(vec3(t * 3.0, 5.0, 0.0));
    return clamp(gate * syl, 0.0, 1.0);
}

// Centred coordinates normalized to the shorter side, y up, shrunk or grown by
// a tap's bounce. Flutter's fragment origin is the top left, so y is flipped.
vec2 coords(vec2 position) {
    float m = min(uSize.x, uSize.y);
    vec2 q = vec2(position.x - 0.5 * uSize.x, 0.5 * uSize.y - position.y) / m;
    return q / uScale;
}
