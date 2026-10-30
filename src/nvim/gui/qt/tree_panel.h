// The project's files, on the window's left: the tree biscide.tree keeps (its
// rows, which is selected, which file is the active declaration's), drawn
// here: chevrons, folder and file icons in their language's colour, indent
// guides, the selected row, the one under the pointer. The keys are Nvim's
// (the tree's buffer has them); the mouse calls biscide.tree: a click selects
// (a folder opens or closes), a double click opens a file. Its right edge
// resizes it.
#pragma once

#include "editor.h"
#include "value.h"

#include <QWidget>

#include <string>
#include <vector>

namespace biscide {

class TreePanel : public QWidget {
  Q_OBJECT
 public:
  explicit TreePanel(Editor& editor, QWidget* parent = nullptr);

  /// The tree as biscide.tree tells it (`vim._gui_send("tree", …)`).
  void set(const mp::Value& payload);
  bool open() const { return open_; }
  bool focused() const { return focused_; }
  float preferred_width() const { return width_; }

 signals:
  void width_changed();
  void changed();

 protected:
  void paintEvent(QPaintEvent*) override;
  void mousePressEvent(QMouseEvent*) override;
  void mouseMoveEvent(QMouseEvent*) override;
  void mouseReleaseEvent(QMouseEvent*) override;
  void mouseDoubleClickEvent(QMouseEvent*) override;
  void wheelEvent(QWheelEvent*) override;
  void leaveEvent(QEvent*) override;
  void resizeEvent(QResizeEvent*) override;

 private:
  struct Row {
    std::string name, path, kind;
    int depth = 0;
    bool dir = false, expanded = false;
  };
  int row_at(QPointF at) const;
  float body_h() const;
  float max_scroll() const;
  void keep_selected_in_view();
  QRectF close_rect() const;

  Editor& editor_;
  std::vector<Row> rows_;
  std::string root_, active_;
  int selected_ = 0;  ///< from 0
  bool open_ = false, focused_ = false;
  float scroll_ = 0;
  int hovered_ = -1;
  float width_ = 300;
  bool resizing_ = false;
  float press_x_ = 0, press_width_ = 0;
};

}  // namespace biscide
