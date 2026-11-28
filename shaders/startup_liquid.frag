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

// Phase des ruisseaux en un point (coordonnées en hauteurs d'écran) : une
// pente en diagonale, ondulée par un champ lisse qui se déforme lentement.
// Ses lignes sont de longs arcs presque parallèles qui balaient l'écran,
// jamais des boucles fermées.
float streamPhase(vec2 s0, float t) {
  vec2 w = vec2(fbm3(s0 * 0.8 + t * 0.2), fbm3(s0 * 0.8 + vec2(4.1, 7.3) - t * 0.2));
  return dot(s0, vec2(0.75, 0.55)) * 4.0 + fbm3(s0 * 0.9 + 1.5 * w) * 5.0;
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

  // Les ruisseaux : quelques larges rubans de lumière qui glissent
  // lentement, de largeur constante (la distance à leur ligne centrale
  // tient compte de la pente du champ : sans elle, un champ presque plat
  // donnait des flaques). Sur leur largeur, un dégradé : la teinte opposée
  // au bord, l'encre, puis le cœur chaud ; une lueur douce les entoure.
  // Un second champ, presque fixe, les fait naître et s'éteindre.
  vec2 s0 = (uv + offset) * vec2(aspect, 1.0) * 0.55;
  float e = 0.004;
  float ph = streamPhase(s0, t);
  vec2 grad = vec2(streamPhase(s0 + vec2(e, 0.0), t) - ph,
                   streamPhase(s0 + vec2(0.0, e), t) - ph) / (e / 0.55);
  float flow = ph - uTime * 0.12;
  float v = fract(flow) - 0.5;
  // Chaque ruban a sa lumière : certains s'éteignent, d'autres brillent.
  float id = floor(flow + 0.5);
  float own = hash(vec2(id, 7.0));
  float lightness = own < 0.15 ? 0.0 : mix(0.4, 1.0, (own - 0.15) / 0.85);
  float keep = smoothstep(0.22, 0.5, fbm3(s0 * 0.45 + vec2(3.1, 7.4) + t * 0.05));
  // Sa largeur va et vient le long de sa course.
  float width = mix(0.04, 0.1, fbm3(s0 * 1.3 + vec2(id * 3.7, 1.0)));
  float slope = max(length(grad), 0.5);
  float across = 1.0 - clamp(abs(v) / slope / width, 0.0, 1.0);
  float band = smoothstep(0.0, 0.25, across) * keep * lightness;
  float halo = 1.0 - clamp(abs(v) / slope / (width * 3.0), 0.0, 1.0);
  halo = halo * halo * keep * lightness;

  vec3 fringe = normalize(uGround + 1e-3) * 0.75;
  vec3 ribbon = mix(fringe, uInk * 1.5, smoothstep(0.05, 0.6, across));
  ribbon = mix(ribbon, uHot * 1.2, smoothstep(0.7, 1.0, across));
  // Le long du ruban, la lumière va et vient avec le second champ.
  ribbon *= 0.6 + 0.4 * keep;

  vec3 color = uGround * (0.5 + 0.6 * f);
  color += uInk * halo * 0.3;
  color = mix(color, min(ribbon, vec3(1.0)), band);

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
