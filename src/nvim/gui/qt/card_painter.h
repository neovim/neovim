// Painting the stage: the dotted background moving with the camera, each
// card (its title bar, its window's grid as Nvim draws it, its bottom bar),
// the empty card at the file lane's end, the curves from the active card
// to what it uses.
#pragma once

#include "geometry.h"
#include "motion.h"
#include "screen.h"
#include "stage.h"
#include "state.h"

#include <QPainter>

#include <functional>

namespace biscide {

/// What the painters need of the canvas.
struct PaintContext {
  const Screen& screen;
  const CardMetrics& m;
  const Camera& cam;
  const LanesState& st;
  QSizeF size;
  /// Nvim has the keyboard in the cards (not the tree, not a picker).
  bool cards_focused;
  /// How far a card's window is scrolled in it (rows, a fraction too).
  std::function<float(int64_t win)> scroll_of;
};

/// How a card is drawn.
struct CardLook {
  bool active = false;   ///< the declaration in the middle
  bool cursor = false;   ///< under the card cursor
  bool hovered = false;  ///< under the pointer, or just brought into view
  bool ghost = false;    ///< leaving
  bool missing = false;  ///< a declaration that is nowhere (biscide.missing)
  float opacity = 1;
};

void paint_dots(QPainter& p, const PaintContext& c);
void paint_card(QPainter& p, const PaintContext& c, const Placed& card, const Drawn& d, const CardLook& look);
void paint_new_card(QPainter& p, const PaintContext& c, const Drawn& d);
void paint_curves(QPainter& p, const PaintContext& c, const Stage& stage, float t);

}  // namespace biscide
