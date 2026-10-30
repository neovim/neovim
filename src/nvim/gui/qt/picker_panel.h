// A picker (biscide.picker: files, declarations, grep, diagnostics,
// vim.ui.select, …), over the canvas: its title and counts, its prompt (a
// Nvim window: typing is Nvim's insert mode, with its keys), the items it
// matched drawn here (each one's kind, its text with the matched
// characters lit, what more it says), and the selected one's preview (a
// Nvim window on its file). A click selects, a double click picks, a click
// outside closes it.
#pragma once

#include "editor.h"
#include "gridpaint.h"
#include "screen.h"
#include "value.h"

#include <QWidget>

#include <string>
#include <vector>

namespace biscide {

class PickerPanel : public QWidget {
  Q_OBJECT
 public:
  PickerPanel(const Screen& screen, Editor& editor, const CellMetrics& cm, QWidget* parent = nullptr);

  /// The picker as biscide.picker tells it (`vim._gui_send("picker", …)`).
  void set(const mp::Value& payload);
  bool open() const { return open_; }
  /// The prompt's columns, the preview's columns and rows (biscide.picker
  /// sizes its windows to them).
  int prompt_cols() const;
  std::pair<int, int> preview_size() const;

 signals:
  /// Its sizes changed (the window resized).
  void sizes_changed();
  void changed();

 protected:
  void paintEvent(QPaintEvent*) override;
  void mousePressEvent(QMouseEvent*) override;
  void mouseDoubleClickEvent(QMouseEvent*) override;
  void mouseMoveEvent(QMouseEvent*) override;
  void wheelEvent(QWheelEvent*) override;
  void resizeEvent(QResizeEvent*) override;

 private:
  struct Item {
    std::string text, detail, kind;
    std::vector<int> pos;  ///< matched characters (code points, from 0)
  };
  QRectF box() const;
  QRectF prompt_rect() const;
  QRectF list_rect() const;
  QRectF preview_rect() const;
  int item_at(QPointF at) const;
  void keep_selected_in_view();
  void paint_item(QPainter& p, const Item& it, QRectF line, bool selected);

  const Screen& screen_;
  Editor& editor_;
  const CellMetrics& cm_;
  bool open_ = false, busy_ = false;
  std::string title_, preview_title_, empty_;
  int64_t prompt_win_ = 0, preview_win_ = 0;
  std::vector<Item> items_;
  int selected_ = 0;  ///< from 0
  int64_t count_ = 0, total_ = 0;
  float scroll_ = 0;
  int hovered_ = -1;
};

}  // namespace biscide
