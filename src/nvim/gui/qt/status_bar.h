// The status line at the window's bottom: Nvim's mode, then its command
// line while one is typed (its cursor too), else the last message Nvim
// shows (its first line; the messages panel has it all); on the right the
// pending command (showcmd), the mode's message ("recording @q"), what the
// program has, and the messages panel's switch with the errors and
// warnings it has not shown.
#pragma once

#include "gridpaint.h"
#include "screen.h"

#include <QWidget>

namespace biscide {

class StatusBar : public QWidget {
  Q_OBJECT
 public:
  StatusBar(const Screen& screen, const CellMetrics& cm, QWidget* parent = nullptr);

  /// The mode's label (biscide's own: TREE, PICK; else Nvim's).
  void set_mode(const QString& mode) { mode_ = mode; }
  /// The right end's words ("1534 declarations").
  void set_info(const QString& info) { info_ = info; }
  void set_panel_open(bool open) { panel_open_ = open; }
  /// Where a column of the command line's text is (in this widget): the
  /// command line's completion menu is put above it.
  float column_x(int col) const { return text_x_ + cm_.cell_w * static_cast<float>(col); }

 signals:
  void messages_clicked();

 protected:
  void paintEvent(QPaintEvent*) override;
  void mousePressEvent(QMouseEvent*) override;

 private:
  QRectF switch_rect() const;
  float paint_cmdline(QPainter& p, float x, float right);
  void paint_message(QPainter& p, float x, float right);

  const Screen& screen_;
  const CellMetrics& cm_;
  QString mode_ = "NORMAL", info_;
  bool panel_open_ = false;
  float text_x_ = 0;
};

}  // namespace biscide
