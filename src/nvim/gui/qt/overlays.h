// What floats over the stage, at the view's own scale: the history along
// the top, the key to the colours in the bottom-left corner. Each knows
// where it is drawn, for the mouse.
#pragma once

#include "card_painter.h"

#include <QRectF>

#include <optional>
#include <utility>
#include <vector>

namespace biscide {

class Overlays {
 public:
  bool show_key = false;

  void paint(QPainter& p, const PaintContext& c);

  /// The history's entry (from 1) under a point.
  std::optional<int> history_at(QPointF at) const;
  /// Whether a point is on the key (or its chip); on its close button.
  bool on_key(QPointF at) const { return key_box_.contains(at); }
  bool on_key_close(QPointF at) const { return key_close_.contains(at); }

  /// The left edge of what floats at the canvas's left.
  float left() const { return 10; }

 private:
  void paint_history(QPainter& p, const PaintContext& c);
  void paint_key(QPainter& p, const PaintContext& c);

  std::vector<std::pair<QRectF, int>> history_hits_;
  QRectF key_box_, key_close_;
};

}  // namespace biscide
