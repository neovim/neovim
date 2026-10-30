#include "camera.h"

#include <algorithm>

namespace biscide {

namespace {

/// In place: within this much (world units; of the zoom, a part of it).
constexpr float NEAR = 0.3f;
constexpr float NEAR_ZOOM = 0.0005f;

}  // namespace

void CameraRig::set_target(const Camera& to) {
  x_.target = to.ox;
  y_.target = to.oy;
  zoom_.target = to.zoom;
}

void CameraRig::glide(const Camera& to, Mode mode, float t) {
  mode_ = mode;
  if (!moving_) last_ = t;
  set_target(to);
  moving_ = true;
}

void CameraRig::jump(const Camera& to, Mode mode) {
  mode_ = mode;
  set_target(to);
  x_.snap();
  y_.snap();
  zoom_.snap();
  moving_ = false;
  cam_ = to;
}

bool CameraRig::tick(float t) {
  if (!moving_) return false;
  // A frame late (the window was busy) is not a leap.
  float dt = std::clamp(t - last_, 0.0f, 0.05f);
  last_ = t;
  x_.step(dt);
  y_.step(dt);
  zoom_.step(dt);
  if (x_.settled(NEAR) && y_.settled(NEAR) && zoom_.settled(NEAR_ZOOM)) {
    x_.snap();
    y_.snap();
    zoom_.snap();
    moving_ = false;
  }
  cam_ = {x_.value, y_.value, zoom_.value};
  return moving_;
}

}  // namespace biscide
