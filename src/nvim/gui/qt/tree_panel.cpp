#include "tree_panel.h"

#include "theme.h"

#include <QFontMetricsF>
#include <QMouseEvent>
#include <QPainter>
#include <QWheelEvent>

#include <algorithm>

namespace biscide {

namespace {

constexpr float HEADER = 34.0f;
constexpr float ROW_H = 24.0f;
constexpr float INDENT = 16.0f;
constexpr float EDGE = 5.0f;

/// A file's icon colour, by its kind ("go", "rust", …).
QColor file_color(const std::string& kind) {
  if (kind == "go") return theme::cyan;
  if (kind == "rust") return QColor(0xD9, 0x84, 0x52);
  if (kind == "lua") return theme::accent;
  if (kind == "doc") return theme::text_muted;
  if (kind == "config") return theme::violet;
  return theme::text_disabled;
}

}  // namespace

TreePanel::TreePanel(Editor& editor, QWidget* parent) : QWidget(parent), editor_(editor) {
  setFocusPolicy(Qt::NoFocus);
  setMouseTracking(true);
  setAttribute(Qt::WA_OpaquePaintEvent);
}

void TreePanel::set(const mp::Value& payload) {
  auto flag = [&](const char* k) {
    auto v = payload.get(k);
    return v && v->as_bool().value_or(false);
  };
  bool was_open = open_;
  open_ = flag("open");
  focused_ = flag("focused");
  if (auto r = payload.get("root")) root_ = r->str_or();
  if (auto a = payload.get("active")) active_ = a->str_or();
  if (auto list = payload.get("rows"); list && list->as_array()) {
    rows_.clear();
    for (auto& v : *list->as_array()) {
      Row r;
      if (auto x = v.get("name")) r.name = x->str_or();
      if (auto x = v.get("path")) r.path = x->str_or();
      if (auto x = v.get("kind")) r.kind = x->str_or();
      if (auto x = v.get("depth")) r.depth = static_cast<int>(x->int_or(0));
      if (auto x = v.get("dir")) r.dir = x->as_bool().value_or(false);
      if (auto x = v.get("expanded")) r.expanded = x->as_bool().value_or(false);
      rows_.push_back(std::move(r));
    }
  }
  if (auto s = payload.get("selected")) selected_ = static_cast<int>(s->int_or(1)) - 1;
  keep_selected_in_view();
  if (was_open != open_) emit changed();
  update();
}

float TreePanel::body_h() const { return static_cast<float>(height()) - HEADER; }
float TreePanel::max_scroll() const {
  return std::max(0.0f, static_cast<float>(rows_.size()) * ROW_H + 8 - body_h());
}
QRectF TreePanel::close_rect() const { return QRectF(width() - 32, 0, 26, HEADER); }

void TreePanel::keep_selected_in_view() {
  float top = static_cast<float>(selected_) * ROW_H, bottom = top + ROW_H;
  if (top < scroll_) scroll_ = top;
  if (bottom > scroll_ + body_h()) scroll_ = bottom - body_h() + 4;
  scroll_ = std::clamp(scroll_, 0.0f, max_scroll());
}

void TreePanel::resizeEvent(QResizeEvent*) { keep_selected_in_view(); }

int TreePanel::row_at(QPointF at) const {
  if (at.y() < HEADER) return -1;
  int k = static_cast<int>((static_cast<float>(at.y()) - HEADER + scroll_) / ROW_H);
  return k >= 0 && k < static_cast<int>(rows_.size()) ? k : -1;
}

void TreePanel::paintEvent(QPaintEvent*) {
  QPainter p(this);
  p.setRenderHint(QPainter::Antialiasing);
  p.fillRect(rect(), theme::frame_bg);
  p.fillRect(QRectF(width() - 1, 0, 1, height()), theme::border_strong);
  // The header.
  QFont label = theme::ui_font();
  label.setPixelSize(12);
  p.setFont(label);
  p.setPen(focused_ ? theme::text : theme::text_muted);
  p.drawText(QRectF(14, 0, width() - 60, HEADER), Qt::AlignVCenter, "PROJECT");
  p.drawPixmap(QPointF(close_rect().center().x() - 6, (HEADER - 12) / 2), theme::icon("close", theme::text_muted, 12));
  p.fillRect(QRectF(0, HEADER - 1, width(), 1), theme::border);
  if (focused_) p.fillRect(QRectF(0, HEADER - 2, width(), 2), theme::accent);
  // The rows.
  p.save();
  p.setClipRect(QRectF(0, HEADER, width() - 1, body_h()));
  QFont ui = theme::ui_font();
  QFont bold = ui;
  bold.setBold(true);
  QFontMetricsF fm(ui);
  int first = std::max(0, static_cast<int>(scroll_ / ROW_H));
  int last = std::min(static_cast<int>(rows_.size()), first + static_cast<int>(body_h() / ROW_H) + 2);
  for (int k = first; k < last; k++) {
    const Row& r = rows_[static_cast<size_t>(k)];
    float y = HEADER + static_cast<float>(k) * ROW_H - scroll_;
    QRectF line(4, y, width() - 9, ROW_H);
    if (k == selected_) {
      p.setPen(Qt::NoPen);
      p.setBrush(focused_ ? theme::selection_bg : theme::with_alpha(theme::selection_bg, 0.45f));
      p.drawRoundedRect(line, 5, 5);
    } else if (k == hovered_) {
      p.setPen(Qt::NoPen);
      p.setBrush(theme::hover_bg);
      p.drawRoundedRect(line, 5, 5);
    }
    // Indent guides: a line down each level above.
    for (int d = 1; d < r.depth; d++) {
      float gx = 12 + INDENT * static_cast<float>(d) + 6;
      p.fillRect(QRectF(gx, y, 1, ROW_H), theme::with_alpha(theme::border_strong, 0.7f));
    }
    float x = 12 + INDENT * static_cast<float>(r.depth);
    float cy = y + ROW_H / 2;
    if (r.dir) {
      p.drawPixmap(QPointF(x - 2, cy - 6), theme::icon(r.expanded ? "chevron-down" : "chevron-right", theme::text_muted, 12));
      p.drawPixmap(QPointF(x + 13, cy - 7),
                   theme::icon(r.expanded ? "folder-open" : "folder", QColor(0xC9, 0xA2, 0x6D), 14));
    } else {
      p.drawPixmap(QPointF(x + 13, cy - 7), theme::icon("file", file_color(r.kind), 14));
    }
    bool active = !r.dir && !active_.empty() && r.path == active_;
    p.setFont(k == 0 ? bold : ui);
    p.setPen(active ? theme::accent : (r.dir || k == selected_ ? theme::text : theme::text_muted));
    float tx = x + 33;
    QString name = QString::fromStdString(r.name);
    float room = static_cast<float>(width()) - tx - 14;
    p.drawText(QRectF(tx, y, room, ROW_H), Qt::AlignVCenter, fm.elidedText(name, Qt::ElideMiddle, room));
    if (k == 0 && !root_.empty()) {
      // The root: its path after its name.
      float nw = static_cast<float>(QFontMetricsF(bold).horizontalAdvance(name)) + 10;
      QFont small = ui;
      small.setPixelSize(11);
      p.setFont(small);
      p.setPen(theme::text_disabled);
      p.drawText(QRectF(tx + nw, y, room - nw, ROW_H), Qt::AlignVCenter,
                 QFontMetricsF(small).elidedText(QString::fromStdString(root_), Qt::ElideLeft, room - nw));
    }
    if (active) {
      p.setPen(Qt::NoPen);
      p.setBrush(theme::accent);
      p.drawEllipse(QPointF(width() - 16, cy), 3, 3);
    }
  }
  p.restore();
  if (max_scroll() > 0) {
    float h = body_h() * body_h() / (body_h() + max_scroll());
    float y = HEADER + (body_h() - h) * scroll_ / max_scroll();
    p.setPen(Qt::NoPen);
    p.setBrush(theme::with_alpha(theme::text_disabled, 0.4f));
    p.drawRoundedRect(QRectF(width() - 7, y, 4, h), 2, 2);
  }
}

void TreePanel::mousePressEvent(QMouseEvent* e) {
  QPointF at = e->position();
  if (at.x() > width() - EDGE) {
    resizing_ = true;
    press_x_ = static_cast<float>(e->globalPosition().x());
    press_width_ = width_;
    return;
  }
  if (close_rect().contains(at)) {
    editor_.command("BiscideTree close");
    return;
  }
  int k = row_at(at);
  if (k < 0) return;
  // A click selects (the keyboard to the tree); a folder opens or closes.
  editor_.lua("require('biscide.tree').click(...)", {static_cast<int64_t>(k + 1)});
}

void TreePanel::mouseDoubleClickEvent(QMouseEvent* e) {
  int k = row_at(e->position());
  if (k < 0 || rows_[static_cast<size_t>(k)].dir) return;
  editor_.lua("require('biscide.tree').activate(...)", {static_cast<int64_t>(k + 1)});
}

void TreePanel::mouseMoveEvent(QMouseEvent* e) {
  if (resizing_) {
    width_ = std::clamp(press_width_ + static_cast<float>(e->globalPosition().x()) - press_x_, 160.0f, 900.0f);
    emit width_changed();
    return;
  }
  QPointF at = e->position();
  setCursor(at.x() > width() - EDGE ? Qt::SizeHorCursor : Qt::ArrowCursor);
  int k = row_at(at);
  if (k != hovered_) {
    hovered_ = k;
    update();
  }
}

void TreePanel::mouseReleaseEvent(QMouseEvent*) { resizing_ = false; }

void TreePanel::leaveEvent(QEvent*) {
  hovered_ = -1;
  update();
}

void TreePanel::wheelEvent(QWheelEvent* e) {
  QPoint px = e->pixelDelta();
  float dy = px.isNull() ? static_cast<float>(e->angleDelta().y()) / 120.0f * 3 * ROW_H : static_cast<float>(px.y());
  scroll_ = std::clamp(scroll_ - dy, 0.0f, max_scroll());
  update();
}

}  // namespace biscide
