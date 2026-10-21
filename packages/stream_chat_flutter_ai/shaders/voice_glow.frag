#version 460 core

// GLOW: a soft, airy globe. Color masses orbit inside it, concentric waves
// drift through them, and the gaps between them let the background show
// through.

#include "voice_common.glsl"

void main() {
    vec2 q = coords(FlutterFragCoord().xy);
    float t = uTime;
    float r = length(q);

    float speak = ss(0.6, 1.0, uReact);
    float speech = uReact * mix(0.55 + 0.25 * sin(t * 1.6), speechEnv(t), speak);
    speech = mix(speech, uMic, uVoice);
    float speechSmooth = mix(speech, uReact * (0.55 + 0.25 * sin(t * 1.6)), 0.5 * speak);
    float energy = 0.12 + 0.30 * uReact + 0.18 * uFlow + 0.28 * uLoad + 0.06 * speechSmooth;
    float R = 0.24 * (1.0 + speechSmooth * 0.20 + uLoad * 0.05 * sin(t * 2.0) + uReact * 0.04 * sin(t * 1.6));
    float p = r / R;

    float core = exp(-2.0 * p * p);
    float body = ss(1.06, 0.62, p);

    vec2 P = q / R;
    float pl = length(P);
    float nt = t * 0.15 + uFlowSpin * 0.05;
    float nAmp = 0.20 + 0.28 * energy;
    vec2 sp = P + nAmp * vec2(snoise(vec3(P * 0.7, nt)), snoise(vec3(P * 0.7 + 4.7, nt)));
    float ang = atan(P.y, P.x);
    float wave = (0.018 + 0.025 * energy) * sin(pl * 5.0 - t * 2.0) * ss(0.0, 0.4, pl);
    sp += wave * vec2(-sin(ang), cos(ang));
    sp = rot2(sp, uFlowSpin * 0.30);
    vec2 gtoP = q - (uHoverAmt > 0.001 ? uHover : uTap);
    sp += (gtoP / (length(gtoP) + 1e-4)) * poke(q) * 0.5;
    float bt = t;
    float a0 = uOrbSpin * 0.42 + 2.0 * snoise(vec3(bt * 0.12, 0.0, 0.0));
    float a1 = -uOrbSpin * 0.34 + 2.0 * snoise(vec3(bt * 0.10, 5.0, 0.0)) + 2.0;
    float a2 = uOrbSpin * 0.30 + 2.0 * snoise(vec3(bt * 0.11, 9.0, 0.0)) + 1.0;
    float a3 = -uOrbSpin * 0.26 + 2.0 * snoise(vec3(bt * 0.09, 14.0, 0.0)) + 3.5;
    vec2 c0 = 0.40 * vec2(cos(a0), sin(a0));
    vec2 c1 = 0.38 * vec2(cos(a1), sin(a1));
    vec2 c2c = 0.36 * vec2(cos(a2), sin(a2));
    vec2 c3c = 0.34 * vec2(cos(a3), sin(a3));
    float b0 = ss(1.15, 0.1, length(sp - c0));
    float b1 = ss(1.30, 0.1, length(sp - c1));
    float b2 = ss(1.20, 0.1, length(sp - c2c));
    float b3 = ss(1.25, 0.1, length(sp - c3c));

    vec3 k0 = saturate3(vivid(uCol0), 1.7);
    vec3 kL = saturate3(clamp(vivid(uCol0) * 1.18, 0.0, 1.0), 1.3);
    vec3 kD = saturate3(vivid(uCol0) * 0.85, 1.3);
    vec3 colB = mix(kL, saturate3(vivid(uCol1), 1.7), clamp(uCount - 1.0, 0.0, 1.0));
    vec3 colC = mix(kD, saturate3(vivid(uCol2), 1.7), clamp(uCount - 2.0, 0.0, 1.0));
    vec3 colD = saturate3(vivid(uCol3), 1.7);
    vec3 colE = saturate3(vivid(uCol4), 1.7);
    vec3 base = saturate3(mix(vivid(uCol0), vec3(1.0), 0.06), 1.3);
    vec3 col = base;
    col = mix(col, k0, b0);
    col = mix(col, colB, b1);
    col = mix(col, colC, b0 * 0.5);
    col = mix(col, colD, b2 * clamp(uCount - 3.0, 0.0, 1.0));
    col = mix(col, colE, b3 * clamp(uCount - 4.0, 0.0, 1.0));
    col = saturate3(col, 1.15);
    col = clamp(col * 1.12, 0.0, 1.0);
    col = desat(col, uSat);

    float z = sqrt(max(1.0 - p * p, 0.0));
    vec3 nrm = normalize(vec3(q / R, z + 1e-4));
    vec3 Ld = normalize(vec3(-0.35, 0.45, 0.85));
    float diff = clamp(dot(nrm, Ld), 0.0, 1.0);
    col *= 0.80 + 0.20 * diff;
    float fres = pow(1.0 - clamp(nrm.z, 0.0, 1.0), 2.5);
    col += fres * 0.10 * mix(vec3(1.0), k0, 0.6);

    vec3 haloCol = mix(mix(vivid(uCol0), vec3(1.0), 0.75), mix(vivid(uCol0), vec3(1.0), 0.32), uDark);
    float halo = exp(-sq(max(r - R * 0.8, 0.0) / 0.09));
    float haloA = halo * (mix(0.05, 0.10, uDark) + 0.05 * uReact);
    float waves = clamp(b0 + 0.8 * b1, 0.0, 1.0);
    float bodyA = clamp(body * (0.15 + 0.60 * waves + 0.06 * core) * (0.92 + 0.08 * fres), 0.0, 1.0);
    float fade = mix(1.0, 0.45 + 0.35 * sin(t * 2.0), uLoad);
    vec3 pm = col * bodyA + haloCol * haloA * (1.0 - bodyA);
    float al = bodyA + haloA * (1.0 - bodyA);
    float gain = uBright * fade;
    fragColor = vec4(pm * gain, al * gain);
}
