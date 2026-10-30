// What pops up over the canvas from Nvim's UI protocol: a prompt's
// question (|:confirm|, |confirm()|: the message before it, until it is
// answered), the lines typed before the command line (`:function`), and the
// popup menu (completion: under the cell it completes in a card, or above
// the command line's column). It takes no mouse.
#pragma once

#include "gridpaint.h"
#include "screen.h"

#include <QWidget>

#include <functional>
#include <optional>

namespace biscide {

class Popups : public QWidget {
  Q_OBJECT
 public:
  /// Where a grid's cell is in this widget (a card's), if shown.
  using CellAt = std::function<std::optional<QRectF>(int64_t grid, int row, int col)>;
  /// Where a column of the command line is, in x (this widget's).
  using CmdlineX = std::function<float(int col)>;

  Popups(const Screen& screen, const CellMetrics& cm, CellAt cell_at, CmdlineX cmdline_x, QWidget* parent = nullptr);

 protected:
  void paintEvent(QPaintEvent*) override;

 private:
  void paint_confirm(QPainter& p);
  void paint_block(QPainter& p);
  void paint_pum(QPainter& p);

  const Screen& screen_;
  const CellMetrics& cm_;
  CellAt cell_at_;
  CmdlineX cmdline_x_;
};

}  // namespace biscide
