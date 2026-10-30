// The camera rig, in one of two states: framing the lanes around the
// active card (across, it keeps the lanes in view as the window is
// resized; up and down it is free), or following a card (the card
// cursor's: the camera keeps it in the view's middle). It moves to what it
// aims at as springs (motion.h): a new aim while it moves keeps its speed,
// so it never jerks.
#pragma once

#include "motion.h"

namespace biscide {

class CameraRig {
 public:
  enum class Mode { Frame, Follow };

  const Camera& camera() const { return cam_; }
  /// Where it is going (where it is, when it stays).
  Camera target() const { return {x_.target, y_.target, zoom_.target}; }
  Mode mode() const { return mode_; }
  bool gliding() const { return moving_; }

  /// Moves to `to`, in `mode` from now on.
  void glide(const Camera& to, Mode mode, float t);
  /// At `to` at once (the first view; a resize).
  void jump(const Camera& to, Mode mode);
  /// Moves on to now; whether it still moves.
  bool tick(float t);

 private:
  void set_target(const Camera& to);
  Camera cam_;
  Spring x_, y_, zoom_{1, 0, 1};
  Mode mode_ = Mode::Frame;
  bool moving_ = false;
  float last_ = 0;
};

}  // namespace biscide
