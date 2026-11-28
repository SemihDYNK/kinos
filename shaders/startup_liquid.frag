#version 460 core

// Le fond liquide de l'intro de Kinos : des volutes aux couleurs du film
// (une encre qui se déforme sur elle-même), révélées au clap par l'onde
// d'une goutte tombée sur le K. Variante « faisceau » : après l'onde, le
// liquide se retire dans un faisceau qui s'ouvre depuis le K.

#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
// Secondes depuis le début de l'aurore, et depuis le clap (négatif avant).
uniform float uTime;
uniform float uWave;
// Intensité globale (0 : le fond seul, 1 : le liquide entier).
uniform float uIntensity;
// 0 : la goutte ; 1 : la goutte puis le faisceau.
uniform float uMode;
// Source du faisceau (pixels) et son ouverture (0 à 1).
uniform vec2 uSource;
uniform float uBeam;
uniform vec3 uBlack;
uniform vec3 uGround;
uniform vec3 uInk;
uniform vec3 uHot;
uniform float uGrain;

out vec4 fragColor;

float hash(vec2 p) {
  return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
             mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
  float v = 0.0;
  float a = 0.5;
  for (int i = 0; i < 5; i++) {
    v += a * noise(p);
    p = p * 2.03 + vec2(1.7, 9.2);
    a *= 0.5;
  }
  return v;
}

// Vitesse du front de l'onde, en hauteurs d'écran par seconde.
const float kSpeed = 0.95;
// Fréquence des rides (par hauteur d'écran).
const float kRipples = 55.0;

void main() {
  vec2 px = FlutterFragCoord().xy;
  vec2 uv = px / uSize;
  float aspect = uSize.x / uSize.y;
  vec2 d = (uv - 0.5) * vec2(aspect, 1.0);
  float dist = length(d);

  // L'onde : des rides qui partent du centre, amorties derrière le front
  // et avec le temps. Elles déforment le liquide et accrochent la lumière.
  float front = uWave * kSpeed;
  float spec = 0.0;
  vec2 offset = vec2(0.0);
  if (uWave > 0.0) {
    float x = dist - front;
    float envelope = smoothstep(0.03, -0.02, x) * exp(-2.6 * max(0.0, -x)) *
                     exp(-uWave * 0.75);
    float slope = cos(x * kRipples) * envelope;
    offset = normalize(d + 1e-4) * sin(x * kRipples) * envelope * 0.025;
    spec = pow(max(0.0, slope), 3.0) * 0.9;
  }

  // Les volutes : un bruit qui se déforme deux fois sur lui-même.
  vec2 p = (uv + offset) * vec2(aspect, 1.0) * 2.0;
  float t = uTime * 0.09;
  vec2 q = vec2(fbm(p + t), fbm(p + vec2(5.2, 1.3) - t));
  vec2 r = vec2(fbm(p + 3.5 * q + vec2(1.7, 9.2) + t * 1.4),
                fbm(p + 3.5 * q + vec2(8.3, 2.8) - t));
  float f = fbm(p + 3.5 * r);
  float ink = smoothstep(0.42, 0.9, f * f * 1.7 + length(r) * 0.22);
  vec3 color = mix(uGround, uInk, ink);
  color = mix(color, uHot, smoothstep(0.72, 1.0, ink + 0.25 * r.x) * 0.85);

  // Ce que l'onde a découvert.
  float lit = uWave > 0.0
                  ? smoothstep(front + 0.02, front - 0.3, dist + (f - 0.5) * 0.12)
                  : 0.0;
  float mask = lit;
  if (uMode > 0.5) {
    // Le faisceau, depuis le K : un éventail qui s'ouvre jusqu'à tout
    // couvrir. L'onde s'efface pendant qu'il s'ouvre.
    vec2 b = (px - uSource) / uSize.y;
    float angle = abs(atan(b.y, b.x));
    float width = mix(0.02, 1.75, uBeam * uBeam);
    float beam = smoothstep(width, width - 0.25, angle) *
                 smoothstep(-0.2, 0.05, b.x);
    beam = max(beam, step(1.0, uBeam));
    mask = max(lit * (1.0 - smoothstep(0.0, 0.5, uWave - 0.45)), beam);
  }
  mask *= uIntensity;

  color = mix(uBlack, color, mask);
  color += vec3(spec) * (0.35 + 0.65 * (1.0 - mask * 0.5)) * uIntensity;
  color += (hash(px + fract(uTime * 7.0) * 91.0) - 0.5) * uGrain;
  fragColor = vec4(color, 1.0);
}
