#include "window.h"

#include "keys.h"
#include "theme.h"

#include <QApplication>
#include <QCloseEvent>
#include <QKeyEvent>
#include <QPainter>

namespace biscide {

Window::Window(Editor& editor, QWidget* parent) : QWidget(parent), nvim_(editor) {
  setWindowTitle("biscide");
  setMinimumSize(700, 420);
  resize(1500, 920);
  setFocusPolicy(Qt::StrongFocus);
  setAttribute(Qt::WA_InputMethodEnabled, false);
  cm_ = cell_metrics(theme::mono_font(), 18);
  canvas_ = new Canvas(screen_, nvim_, this);
  tree_ = new TreePanel(nvim_, this);
  messages_ = new MessagesPanel(screen_, cm_, this);
  status_ = new StatusBar(screen_, cm_, this);
  popups_ = new Popups(
      screen_, cm_, [this](int64_t grid, int row, int col) { return canvas_->cell_rect(grid, row, col); },
      [this](int col) {
        return static_cast<float>(status_->mapTo(this, QPointF(status_->column_x(col), 0)).x() - popups_->x());
      },
      this);
  picker_ = new PickerPanel(screen_, nvim_, cm_, this);
  connect(canvas_, &Canvas::view_changed, this, &Window::send_view);
  connect(tree_, &TreePanel::width_changed, this, &Window::layout);
  connect(tree_, &TreePanel::changed, this, &Window::layout);
  connect(messages_, &MessagesPanel::width_changed, this, &Window::layout);
  connect(messages_, &MessagesPanel::close_clicked, this, [this] { messages_panel("close"); });
  connect(status_, &StatusBar::messages_clicked, this, [this] { messages_panel("toggle"); });
  connect(picker_, &PickerPanel::sizes_changed, this, &Window::send_view);
  connect(picker_, &PickerPanel::changed, this, &Window::update_status);
  // Laid out now: the first view sent is the window's.
  layout();
}

void Window::redraw(const std::vector<std::pair<std::string, mp::Array>>& batch) {
  for (auto& [name, args] : batch) screen_.apply(name, args);
  auto& msgs = screen_.messages;
  if (msgs.want_panel) {
    msgs.want_panel = false;
    messages_panel("open");
  }
  if (msgs.version != seen_messages_) {
    seen_messages_ = msgs.version;
    if (messages_open_) {
      msgs.read();
      messages_->changed();
    }
  }
  canvas_->screen_changed();
  update_status();
  popups_->update();
  if (picker_->open()) picker_->update();
  update_title();
}

void Window::quit() {
  quitting_ = true;
  close();
}

QRectF Window::switch_rect() const { return QRectF(8, 4, 150, theme::bar_h - 8); }

void Window::layout() {
  int top = static_cast<int>(theme::bar_h), bottom = height() - static_cast<int>(theme::status_h);
  int tw = tree_->open() ? static_cast<int>(tree_->preferred_width()) : 0;
  tree_->setGeometry(0, top, tw, bottom - top);
  tree_->setVisible(tw > 0);
  QRect middle(tw + 6, top, width() - tw - 12, bottom - top);
  canvas_->setGeometry(middle);
  popups_->setGeometry(middle);
  picker_->setGeometry(middle);
  // The messages float over the canvas's right (their widget has room for
  // the shadow around them).
  int mw = std::min(static_cast<int>(messages_->preferred_width()), middle.width() - 40);
  messages_->setGeometry(middle.right() - mw, top, mw, bottom - top);
  messages_->setVisible(messages_open_);
  status_->setGeometry(0, bottom, width(), static_cast<int>(theme::status_h));
  messages_->raise();
  popups_->raise();
  picker_->raise();
  update();
  send_view();
}

void Window::resizeEvent(QResizeEvent*) { layout(); }

void Window::send_view() {
  auto [pcols, prows] = picker_->preview_size();
  mp::Map picker{{"cols", static_cast<int64_t>(picker_->prompt_cols())},
                 {"preview_cols", static_cast<int64_t>(pcols)},
                 {"preview_rows", static_cast<int64_t>(prows)}};
  mp::Map view{{"max_rows", static_cast<int64_t>(canvas_->max_rows())}, {"picker", picker}};
  // Sent when it changed (and biscide is there to hear it).
  std::string key = std::to_string(canvas_->max_rows()) + "/" + std::to_string(picker_->prompt_cols()) + "/" +
                    std::to_string(pcols) + "/" + std::to_string(prows);
  if (!started_ || key == sent_view_) return;
  sent_view_ = key;
  nvim_.lua("require('biscide').view(...)", {view});
}

void Window::messages_panel(const std::string& action) {
  if (action == "clear") {
    screen_.messages.clear_log();
    messages_->changed();
    update_status();
    return;
  }
  bool open = action == "open" || (action == "toggle" && !messages_open_);
  if (open == messages_open_) {
    if (open) messages_->to_bottom();
    return;
  }
  messages_open_ = open;
  if (open) {
    screen_.messages.read();
    messages_->to_bottom();
  }
  update_status();
  layout();
}

void Window::biscide(const std::string& kind, const mp::Value& payload) {
  if (kind == "state") {
    if (!started_) {
      // biscide is running: the view as it is now (sizes sent before were
      // not heard).
      started_ = true;
      sent_view_.clear();
      send_view();
    }
    canvas_->set_state(LanesState::parse(payload));
    update_title();
    update_status();
    update();
  } else if (kind == "tree") {
    tree_->set(payload);
    canvas_->set_cards_focused(!tree_->focused() && !picker_->open());
    update_status();
    update();
  } else if (kind == "picker") {
    picker_->set(payload);
    canvas_->set_cards_focused(!tree_->focused() && !picker_->open());
    update_status();
  } else if (kind == "messages") {
    messages_panel(payload.get("action") ? payload.get("action")->str_or("toggle") : "toggle");
  } else if (kind == "cols") {
    canvas_->set_card_cols(static_cast<int>(payload.int_or(80)));
  }
}

void Window::update_title() {
  const auto& st = canvas_->state();
  QString title = "biscide";
  if (st.valid)
    if (auto n = st.node(st.active)) title = QString::fromStdString(n->rel) + " — biscide";
  if (windowTitle() != title) setWindowTitle(title);
}

void Window::update_status() {
  const auto& st = canvas_->state();
  QString info;
  if (st.building) info = "reading the program…";
  else if (st.valid) info = QString("%1 declarations").arg(st.declarations);
  status_->set_mode(mode_label());
  status_->set_info(info);
  status_->set_panel_open(messages_open_);
  status_->update();
}

QString Window::mode_label() const {
  if (picker_->open()) return "PICK";
  if (tree_->focused()) return "TREE";
  std::string m = screen_.mode_name;
  if (m.empty() || m == "normal") return "NORMAL";
  if (m.rfind("cmdline", 0) == 0) return "COMMAND";
  if (m.rfind("visual", 0) == 0) return "VISUAL";
  if (m == "insert") return "INSERT";
  if (m == "replace") return "REPLACE";
  if (m == "operator") return "PENDING";
  return QString::fromStdString(m).toUpper();
}

void Window::paintEvent(QPaintEvent*) {
  QPainter p(this);
  p.setRenderHint(QPainter::Antialiasing);
  p.fillRect(rect(), theme::frame_bg);
  QFont ui = theme::ui_font();
  // The bar: the panel's switch and the active declaration's file.
  QRectF sw = switch_rect();
  p.setPen(Qt::NoPen);
  p.setBrush(tree_->open() ? theme::selection_bg : Qt::transparent);
  p.drawRoundedRect(sw, 5, 5);
  ui.setPixelSize(12);
  p.setFont(ui);
  p.setPen(tree_->open() ? theme::text : theme::text_muted);
  p.drawText(sw, Qt::AlignCenter, "Project  <leader>e");
  p.drawPixmap(QPointF(sw.right() + 14, 8), theme::icon("layers", theme::cyan, 14));
  const auto& st = canvas_->state();
  QString where = QString::fromStdString(st.root.substr(st.root.find_last_of('/') + 1));
  if (st.valid)
    if (auto n = st.node(st.active)) where = QString::fromStdString(n->rel) + "  —  " + where;
  ui.setPixelSize(13);
  p.setFont(ui);
  p.setPen(theme::text_muted);
  p.drawText(QRectF(sw.right() + 36, 0, width() - sw.right() - 50, theme::bar_h), Qt::AlignVCenter,
             where + "  ·  folder");
}

void Window::mousePressEvent(QMouseEvent* e) {
  if (switch_rect().contains(e->position())) nvim_.lua("vim.cmd('BiscideTree toggle')");
}

bool Window::event(QEvent* e) {
  // Tab and Shift+Tab are keys for Neovim, not focus moves.
  if (e->type() == QEvent::KeyPress) {
    auto* k = static_cast<QKeyEvent*>(e);
    if (k->key() == Qt::Key_Tab || k->key() == Qt::Key_Backtab) {
      keyPressEvent(k);
      return true;
    }
  }
  return QWidget::event(e);
}

void Window::keyPressEvent(QKeyEvent* e) {
  std::string keys = key_notation(e->key(), e->modifiers(), e->text());
  if (!keys.empty() && nvim_.running()) nvim_.input(keys);
}

void Window::closeEvent(QCloseEvent* e) {
  if (quitting_ || !nvim_.running()) {
    e->accept();
    return;
  }
  // Nvim decides: it asks about unsaved buffers on its command line.
  e->ignore();
  nvim_.command("confirm qall");
}

}  // namespace biscide
