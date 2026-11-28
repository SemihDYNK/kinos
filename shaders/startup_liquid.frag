#version 460 core

// Le fond liquide de l'intro de Kinos : des ruisseaux de lumière aux
// couleurs du film, qui coulent sur un fond presque noir, révélés au clap
// par l'onde d'une goutte tombée sur le K.

#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
// Secondes depuis le début de l'aurore, et depuis le clap (négatif avant).
uniform float uTime;
uniform float uWave;
// Intensité globale (0 : le fond seul, 1 : le liquide entier).
uniform float uIntensity;
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

// Le même bruit, en trois octaves : un champ lisse pour les ruisseaux.
float fbm3(vec2 p) {
  float v = 0.0;
  float a = 0.5;
  for (int i = 0; i < 3; i++) {
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

  // Le liquide : un bruit qui se déforme deux fois sur lui-même, assez
  // vite pour qu'on le voie couler pendant les trois secondes de l'intro.
  vec2 p = (uv + offset) * vec2(aspect, 1.0) * 1.6;
  float t = uTime * 0.22;
  vec2 q = vec2(fbm(p + t), fbm(p + vec2(5.2, 1.3) - t));
  vec2 r = vec2(fbm(p + 3.0 * q + vec2(1.7, 9.2) + t * 1.4),
                fbm(p + 3.0 * q + vec2(8.3, 2.8) - t));
  float f = fbm(p + 3.0 * r);

  // Les ruisseaux : les lignes de niveau d'un champ lisse et lent (de
  // longues courbes, pas les détails du liquide), qui défilent le long de
  // lui, seulement là où un second champ les laisse passer. Un cœur fin et
  // chaud, une lueur de l'encre, une frange de la teinte opposée au bord.
  vec2 s0 = (uv + offset) * vec2(aspect, 1.0) * 0.9;
  vec2 w = vec2(fbm3(s0 + t * 0.5), fbm3(s0 + vec2(4.1, 7.3) - t * 0.5));
  float g = fbm3(s0 + 1.6 * w + vec2(t * 0.3, 0.0));
  float phase = g * 11.0 - uTime * 0.45;
  float line = 1.0 - abs(fract(phase) - 0.5) * 2.0;
  float keep = smoothstep(0.3, 0.55, fbm3(s0 * 0.7 + vec2(3.1, 7.4) - w));
  float core = pow(line, 26.0) * keep;
  float glow = pow(line, 5.0) * keep;
  float fringe = (pow(line, 10.0) - pow(line, 22.0)) * keep;

  vec3 color = uGround * (0.6 + 0.8 * f);
  // Le corps du liquide, à peine : la nuit reste dominante.
  color += uInk * smoothstep(0.5, 0.95, f + 0.2 * length(r)) * 0.12;
  color += uInk * glow * 1.4;
  color += normalize(uGround + 1e-3) * fringe * 0.7;
  color += uHot * core * 1.8;

  // Ce que l'onde a découvert.
  float lit = uWave > 0.0
                  ? smoothstep(front + 0.02, front - 0.3, dist + (f - 0.5) * 0.12)
                  : 0.0;
  float mask = lit * uIntensity;

  color = mix(uBlack, color, mask);
  color += vec3(spec) * (0.35 + 0.65 * (1.0 - mask * 0.5)) * uIntensity;
  color += (hash(px + fract(uTime * 7.0) * 91.0) - 0.5) * uGrain;
  fragColor = vec4(color, 1.0);
}
