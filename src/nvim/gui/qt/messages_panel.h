// The messages panel, floating over the canvas's right: every message Nvim
// gave (messages.h's log), newest at the bottom, each with its kind, its
// time and its text in its own highlights, wrapped to the panel. Errors and
// warnings are marked; the panel can show only them. It follows the newest
// while scrolled to the bottom. A double click copies a message; its left
// edge resizes it.
#pragma once

#include "gridpaint.h"
#include "screen.h"

#include <QWidget>

#include <vector>

namespace biscide {

class MessagesPanel : public QWidget {
  Q_OBJECT
 public:
  MessagesPanel(Screen& screen, const CellMetrics& cm, QWidget* parent = nullptr);

  /// The width it wants (dragged by its edge).
  float preferred_width() const { return width_; }
  /// The log changed: laid out again (kept at the bottom if it was).
  void changed();
  /// The newest message in view.
  void to_bottom();

 signals:
  void width_changed();
  void close_clicked();

 protected:
  void paintEvent(QPaintEvent*) override;
  void resizeEvent(QResizeEvent*) override;
  void mousePressEvent(QMouseEvent*) override;
  void mouseMoveEvent(QMouseEvent*) override;
  void mouseReleaseEvent(QMouseEvent*) override;
  void mouseDoubleClickEvent(QMouseEvent*) override;
  void wheelEvent(QWheelEvent*) override;

 private:
  /// A message laid out: its lines wrapped to the panel, where it is.
  struct Block {
    size_t index;  ///< in the log
    std::vector<Chunks> lines;
    float y = 0, h = 0;
  };
  void layout();
  float body_h() const;
  float max_scroll() const;
  QRectF body_rect() const;
  QRectF close_rect() const;
  QRectF clear_rect() const;
  QRectF filter_rect() const;
  const Block* block_at(QPointF at) const;
  /// The panel's own size (inside its shadow's margin), a point in it.
  float w() const;
  float h() const;
  QPointF local(QPointF at) const;

  Screen& screen_;
  const CellMetrics& cm_;
  std::vector<Block> blocks_;
  uint64_t laid_version_ = UINT64_MAX;
  int laid_cols_ = -1;
  bool laid_errors_only_ = false;
  float content_h_ = 0;
  float scroll_ = 0;
  bool at_bottom_ = true;
  bool errors_only_ = false;
  float width_ = 420;
  bool resizing_ = false;
  float press_x_ = 0, press_width_ = 0;
  int copied_ = -1;
};

}  // namespace biscide
