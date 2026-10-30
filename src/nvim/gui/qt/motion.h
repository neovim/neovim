// How the canvas is seen and how things move on it: the camera, a card's
// slide and fade, a card's scroll. World units are unzoomed pixels. What
// travels (the camera, the cards sliding) moves as a critically damped
// spring: it eases out of rest and into place, and the camera and the
// cards, starting together, keep together all the way.
#pragma once

#include <algorithm>
#include <cmath>
#include <utility>

namespace biscide {

constexpr float ZOOM_MIN = 0.25f;
constexpr float ZOOM_MAX = 1.4f;

/// The world point at the viewport's top left, and the zoom.
/// Screen = (world − offset) × zoom.
struct Camera {
  float ox = 0, oy = 0, zoom = 1;
  std::pair<float, float> to_screen(float x, float y) const { return {(x - ox) * zoom, (y - oy) * zoom}; }
  std::pair<float, float> to_world(float x, float y) const { return {x / zoom + ox, y / zoom + oy}; }
};

/// Fast at first, gently into place.
inline float ease_out_cubic(float t) {
  t = std::clamp(t, 0.0f, 1.0f);
  return 1 - std::pow(1 - t, 3.0f);
}

/// The springs' rate (per second): about half a second to settle.
constexpr float SPRING = 11.0f;
/// How much of a move begun from rest `t` seconds ago is left.
inline float spring_left(float t) {
  if (t <= 0) return 1;
  float w = SPRING * t;
  return (1 + w) * std::exp(-w);
}
/// Little enough left: in place.
constexpr float SPRING_DONE = 0.002f;

/// A value moving to its target as a critically damped spring (the
/// camera's each coordinate): a new target mid-way keeps its speed.
struct Spring {
  float value = 0, velocity = 0, target = 0;
  /// Moves on by `dt` seconds (exactly, whatever the step).
  void step(float dt) {
    float x = value - target;
    float e = std::exp(-SPRING * dt);
    float k = velocity + SPRING * x;
    value = target + (x + k * dt) * e;
    velocity = (velocity - SPRING * k * dt) * e;
  }
  bool settled(float eps) const { return std::abs(value - target) < eps && std::abs(velocity) < eps * SPRING; }
  void snap() {
    value = target;
    velocity = 0;
  }
};

struct Fade {
  float from = 1, to = 1, start = 0, duration = 0;
  float at(float now) const {
    if (duration <= 0) return to;
    return from + (to - from) * ease_out_cubic((now - start) / duration);
  }
  bool done(float now) const { return now - start >= duration; }
};

/// A card's own motion when the lanes change: it slides from where it was
/// (`dx`, `dy` away from its new place) into place, and fades in or stays.
struct CardMotion {
  float dx = 0, dy = 0, start = 0;
  Fade fade;
  bool slides = false;
  std::pair<float, float> offset(float now) const {
    if (!slides) return {0, 0};
    float left = spring_left(now - start);
    if (left < SPRING_DONE) return {0, 0};
    return {dx * left, dy * left};
  }
  float opacity(float now) const { return std::clamp(fade.at(now), 0.0f, 1.0f); }
  bool done(float now) const { return (!slides || spring_left(now - start) < SPRING_DONE) && fade.done(now); }
};

}  // namespace biscide
