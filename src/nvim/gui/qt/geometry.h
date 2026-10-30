// The sizes the canvas is drawn with (world units: unzoomed pixels): a
// card's bars, its rows of code, the gaps between cards and lanes.
#pragma once

#include "gridpaint.h"

#include <algorithm>

namespace biscide {

struct CardMetrics {
  CellMetrics cell;
  float cols = 80;  ///< a card's width, in cells
  float title_h = 28;
  float pad = 8;
  float card_gap = 18;    ///< between two cards of a lane
  float column_gap = 60;  ///< between two lanes
  float border_slack = 4;

  float line_h() const { return cell.cell_h; }
  float node_w() const { return cell.cell_w * cols + pad * 2; }
  /// A card `rows` rows of code tall: its title and bottom bars, its code.
  float height(int rows) const {
    return title_h * 2 + pad * 2 + border_slack + static_cast<float>(std::max(rows, 1)) * line_h();
  }
  /// The rows of code a card `height` tall has room for.
  float bars() const { return title_h * 2 + pad * 2 + border_slack; }
};

}  // namespace biscide
