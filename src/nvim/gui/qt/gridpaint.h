// Paints one grid of Neovim's screen: per row, the backgrounds other than
// the default as rectangles, the text in runs of one highlight with every
// character a cell wide, then the cursor if it is in this grid: in the
// mode's shape while Neovim has the keyboard, else a hollow block.
#pragma once

#include "screen.h"

#include <QFont>
#include <QPainter>
#include <QPointF>

namespace biscide {

struct CellMetrics {
  QFont font;
  float cell_w;
  float cell_h;
  float ascent;
};

CellMetrics cell_metrics(const QFont& font, float cell_h);

struct GridLook {
  /// The rows and columns painted (from the grid's top left); -1: all.
  int rows = -1, cols = -1;
  int first_row = 0;
  /// The default background painted too (else the card's own shows).
  bool fill_default = false;
  bool cursor = true;
  /// Neovim has the keyboard: the cursor in its mode's shape.
  bool focused = true;
};

void paint_grid(QPainter& p, const Screen& s, int64_t grid, QPointF origin, const CellMetrics& m,
                const GridLook& look);

/// Paints chunks (a message's line, the command line) on one row from
/// `origin`, each character a cell wide, up to `max_cols` columns (-1: all);
/// the columns they took.
int paint_chunks(QPainter& p, const Screen& s, const Chunks& chunks, QPointF origin, const CellMetrics& m,
                 int max_cols = -1);
/// The columns a text takes (a cell a character).
int text_cols(const std::string& text);

/// The text of a row of a grid (the cells joined).
std::string grid_row_text(const Screen& s, int64_t grid, int row);

QColor rgb(uint32_t c);

}  // namespace biscide
