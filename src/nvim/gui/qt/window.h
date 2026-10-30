// biscide's window: a bar on top (the project panel's switch, the active
// file), the project's files on the left (tree_panel), the canvas with the
// messages floating at its right (messages_panel), the status line at the
// bottom (status_bar: Nvim's mode, its command line and messages); over
// the canvas, a picker (picker_panel) and what pops up (popups). It is Nvim's
// own UI (`nvim --gui`): every key goes to the editor, and the editor's
// grids, messages and command line are shown here.
#pragma once

#include "canvas.h"
#include "editor.h"
#include "messages_panel.h"
#include "picker_panel.h"
#include "popups.h"
#include "screen.h"
#include "status_bar.h"
#include "tree_panel.h"
#include "value.h"

#include <QWidget>

namespace biscide {

class Window : public QWidget {
  Q_OBJECT
 public:
  Window(Editor& editor, QWidget* parent = nullptr);
  /// A batch of Nvim's UI events, whole (it ended with `flush`).
  void redraw(const std::vector<std::pair<std::string, mp::Array>>& batch);
  /// A payload of biscide's runtime (`vim._gui_send(kind, payload)`).
  void biscide(const std::string& kind, const mp::Value& payload);
  /// Nvim exits: the window closes.
  void quit();

 protected:
  void paintEvent(QPaintEvent*) override;
  void resizeEvent(QResizeEvent*) override;
  void keyPressEvent(QKeyEvent*) override;
  void closeEvent(QCloseEvent*) override;
  bool focusNextPrevChild(bool) override { return false; }
  void mousePressEvent(QMouseEvent*) override;
  bool event(QEvent*) override;

 private:
  void layout();
  void send_view();
  void update_title();
  void update_status();
  /// The messages panel shown or not ("toggle", "open", "close", "clear").
  void messages_panel(const std::string& action);
  QRectF switch_rect() const;
  QString mode_label() const;

  Editor& nvim_;
  Screen screen_;
  CellMetrics cm_;
  Canvas* canvas_;
  TreePanel* tree_;
  MessagesPanel* messages_;
  PickerPanel* picker_;
  Popups* popups_;
  StatusBar* status_;
  bool messages_open_ = false;
  uint64_t seen_messages_ = 0;
  bool quitting_ = false;
  bool started_ = false;
  std::string sent_view_;
};

}  // namespace biscide
