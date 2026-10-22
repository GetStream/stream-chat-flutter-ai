#version 460 core

// WAVE: a single string, flat at its ends, carrying a travelling wave packet
// that erupts with speech. The colors flow along it in broad, drifting bands.

#include "voice_common.glsl"

void main() {
    vec2 q = coords(FlutterFragCoord().xy);
    float t = uTime;
    float x = q.x;

    float sigma = 0.18;
    float center = uLoad * 0.30 * sin(t * 1.3);
    float env = exp(-sq((x - center) / sigma));
    float freq = 24.0 + 26.0 * uReact + 10.0 * uFlow;
    float phase = x * freq - t * 5.0;

    float base = 0.018 + 0.022 * uReact;
    float speak = ss(0.6, 1.0, uReact);
    float drive = mix(speak * 0.26 * speechEnv(t), 0.30 * uMic, uVoice);
    float amp = env * (base + drive + 0.14 * uFlow + 0.10 * uLoad);
    float y = amp * sin(phase);

    float wAge = uTapTime;
    float wBump = exp(-sq((x - uTap.x) / 0.12))
                * sin((x - uTap.x) * 40.0 - wAge * 24.0)
                * exp(-wAge * 2.6) * (1.0 - step(1.5, wAge));
    y += wBump * 0.05;
    float wHov = exp(-sq((x - uHover.x) / 0.12))
               * sin((x - uHover.x) * 40.0 - t * 7.0) * uHoverAmt;
    y += wHov * 0.04;

    float dydx = amp * freq * cos(phase);
    float halfWv = 0.0030 * sqrt(1.0 + dydx * dydx);
    // Coordinates are logical pixels; the edge is smoothed over physical ones.
    float pix = 1.4 / (min(uSize.x, uSize.y) * uPixelRatio);
    float core = 1.0 - ss(halfWv - pix, halfWv + pix, abs(q.y - y));

    vec3 k0 = vivid(uCol0);
    vec3 k1 = vivid(uCol1);
    vec3 k2 = vivid(uCol2);
    vec3 k3 = vivid(uCol3);
    vec3 k4 = vivid(uCol4);
    float gx = clamp(x + 0.5, 0.0, 1.0);
    float seg = 1.0 / max(uCount, 1.0);
    float bandW = seg * 0.7;
    float m0 = 0.5 * seg + 0.12 * sin(t * 0.13);
    float m1 = 1.5 * seg + 0.13 * sin(t * 0.11 + 2.1);
    float m2 = 2.5 * seg + 0.12 * sin(t * 0.17 + 4.2);
    float m3 = 3.5 * seg + 0.12 * sin(t * 0.15 + 1.0);
    float m4 = 4.5 * seg + 0.12 * sin(t * 0.10 + 3.3);
    float w0 = exp(-sq((gx - m0) / bandW));
    float w1 = exp(-sq((gx - m1) / bandW)) * clamp(uCount - 1.0, 0.0, 1.0);
    float w2 = exp(-sq((gx - m2) / bandW)) * clamp(uCount - 2.0, 0.0, 1.0);
    float w3 = exp(-sq((gx - m3) / bandW)) * clamp(uCount - 3.0, 0.0, 1.0);
    float w4 = exp(-sq((gx - m4) / bandW)) * clamp(uCount - 4.0, 0.0, 1.0);
    vec3 col = (k0 * w0 + k1 * w1 + k2 * w2 + k3 * w3 + k4 * w4) / (w0 + w1 + w2 + w3 + w4 + 1e-4);
    col = saturate3(col, 1.2);
    col = desat(col, uSat);

    float edgeFade = ss(0.40, 0.24, abs(x));
    float a = core * edgeFade * uBright;
    fragColor = vec4(col * a, a);
}
