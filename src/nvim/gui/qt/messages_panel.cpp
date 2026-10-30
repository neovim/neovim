#include "messages_panel.h"

#include "theme.h"

#include <QApplication>
#include <QClipboard>
#include <QMouseEvent>
#include <QPainter>
#include <QPainterPath>
#include <QWheelEvent>

#include <algorithm>

namespace biscide {

namespace {

constexpr float HEADER = 34.0f;
constexpr float PAD = 10.0f;
/// A message's own head: its kind and time.
constexpr float HEAD = 18.0f;
constexpr float GAP = 8.0f;
constexpr float EDGE = 5.0f;
/// The margin around the floating panel (its shadow).
constexpr float INSET = 10.0f;
constexpr float RADIUS = 10.0f;

QColor level_color(Message::Level l) {
  switch (l) {
    case Message::Level::Error:
      return theme::error;
    case Message::Level::Warning:
      return theme::warning;
    case Message::Level::Output:
      return theme::text_muted;
    case Message::Level::Info:
      return theme::accent;
  }
  return theme::text_muted;
}

QString icon_of(Message::Level l) {
  switch (l) {
    case Message::Level::Error:
      return "error";
    case Message::Level::Warning:
      return "warning";
    case Message::Level::Output:
      return "terminal";
    case Message::Level::Info:
      return "info";
  }
  return "info";
}

QString kind_label(const std::string& kind) {
  static const std::pair<const char*, const char*> names[] = {
      {"emsg", "error"},          {"echoerr", "error"},     {"lua_error", "Lua error"},
      {"rpc_error", "RPC error"}, {"wmsg", "warning"},      {"lua_print", "print"},
      {"list_cmd", "output"},     {"shell_out", "shell"},   {"shell_err", "shell error"},
      {"shell_ret", "shell"},     {"shell_cmd", "shell"},   {"echo", "echo"},
      {"echomsg", "message"},     {"bufwrite", "write"},    {"progress", "progress"},
      {"undo", "undo"},           {"confirm", "prompt"},    {"quickfix", "quickfix"},
      {"verbose", "verbose"}};
  for (auto& [k, v] : names)
    if (kind == k) return v;
  return "message";
}

/// A message's lines wrapped to `cols` columns.
std::vector<Chunks> wrap(const Chunks& content, int cols) {
  std::vector<Chunks> out;
  cols = std::max(8, cols);
  for (auto& line : lines_of(content)) {
    Chunks row;
    int used = 0;
    for (auto& c : line) {
      QList<uint> cps = QString::fromStdString(c.text).toUcs4();
      qsizetype from = 0;
      while (from < cps.size()) {
        qsizetype take = std::min<qsizetype>(cps.size() - from, cols - used);
        QList<uint> part = cps.mid(from, take);
        row.push_back({c.attr, QString::fromUcs4(reinterpret_cast<const char32_t*>(part.constData()), part.size()).toStdString()});
        used += static_cast<int>(take);
        from += take;
        if (used >= cols) {
          out.push_back(std::move(row));
          row = {};
          used = 0;
        }
      }
    }
    if (!row.empty() || used == 0) out.push_back(std::move(row));
  }
  return out;
}

}  // namespace

MessagesPanel::MessagesPanel(Screen& screen, const CellMetrics& cm, QWidget* parent)
    : QWidget(parent), screen_(screen), cm_(cm) {
  setFocusPolicy(Qt::NoFocus);
  setMouseTracking(true);
}

float MessagesPanel::w() const { return static_cast<float>(width()) - 2 * INSET; }
float MessagesPanel::h() const { return static_cast<float>(height()) - 2 * INSET; }
QPointF MessagesPanel::local(QPointF at) const { return at - QPointF(INSET, INSET); }

QRectF MessagesPanel::body_rect() const { return QRectF(0, HEADER, w(), h() - HEADER); }
QRectF MessagesPanel::close_rect() const { return QRectF(w() - 30, 0, 26, HEADER); }
QRectF MessagesPanel::clear_rect() const { return QRectF(w() - 58, 0, 26, HEADER); }
QRectF MessagesPanel::filter_rect() const { return QRectF(w() - 150, 7, 88, HEADER - 14); }
float MessagesPanel::body_h() const { return static_cast<float>(h()) - HEADER; }
float MessagesPanel::max_scroll() const { return std::max(0.0f, content_h_ - body_h()); }

void MessagesPanel::layout() {
  int cols = static_cast<int>((static_cast<float>(w()) - 2 * PAD - 8) / cm_.cell_w);
  const auto& log = screen_.messages.log;
  if (laid_version_ == screen_.messages.version && laid_cols_ == cols && laid_errors_only_ == errors_only_) return;
  laid_version_ = screen_.messages.version;
  laid_cols_ = cols;
  laid_errors_only_ = errors_only_;
  blocks_.clear();
  float y = GAP;
  for (size_t i = 0; i < log.size(); i++) {
    auto level = log[i].level();
    if (errors_only_ && level != Message::Level::Error && level != Message::Level::Warning) continue;
    Block b;
    b.index = i;
    b.lines = wrap(log[i].content, cols);
    b.y = y;
    b.h = HEAD + static_cast<float>(b.lines.size()) * cm_.cell_h + 10;
    y += b.h + GAP;
    blocks_.push_back(std::move(b));
  }
  content_h_ = y;
}

void MessagesPanel::changed() {
  layout();
  if (at_bottom_) to_bottom();
  update();
}

void MessagesPanel::to_bottom() {
  layout();
  scroll_ = max_scroll();
  at_bottom_ = true;
  update();
}

void MessagesPanel::resizeEvent(QResizeEvent*) {
  layout();
  scroll_ = at_bottom_ ? max_scroll() : std::min(scroll_, max_scroll());
}

void MessagesPanel::paintEvent(QPaintEvent*) {
  layout();
  QPainter p(this);
  p.setRenderHint(QPainter::Antialiasing);
  // Floating over the canvas: a soft shadow, a rounded panel, clipped to it.
  p.setPen(Qt::NoPen);
  for (int k = 1; k <= 5; k++) {
    float d = INSET * static_cast<float>(k) / 5;
    p.setBrush(QColor(0, 0, 0, 14));
    p.drawRoundedRect(QRectF(INSET - d, INSET - d + 3, w() + 2 * d, h() + 2 * d), RADIUS + d, RADIUS + d);
  }
  p.translate(INSET, INSET);
  QPainterPath shape;
  shape.addRoundedRect(QRectF(0, 0, w(), h()), RADIUS, RADIUS);
  p.fillPath(shape, theme::frame_bg);
  p.setClipPath(shape);
  // The header: its name and count, the filter, clear, close.
  QFont label = theme::ui_font();
  label.setPixelSize(12);
  p.setFont(label);
  p.setPen(theme::text_muted);
  const auto& log = screen_.messages.log;
  p.drawText(QRectF(14, 0, w() - 160, HEADER), Qt::AlignVCenter,
             QString("MESSAGES  %1").arg(static_cast<qulonglong>(log.size())));
  QRectF f = filter_rect();
  p.setPen(QPen(errors_only_ ? theme::accent : theme::border, 1));
  p.setBrush(errors_only_ ? theme::selection_bg : QColor(Qt::transparent));
  p.drawRoundedRect(f, 5, 5);
  QFont small = label;
  small.setPixelSize(11);
  p.setFont(small);
  p.setPen(errors_only_ ? theme::text : theme::text_muted);
  p.drawText(f, Qt::AlignCenter, "Problems only");
  p.drawPixmap(QPointF(clear_rect().center().x() - 7, (HEADER - 14) / 2), theme::icon("trash", theme::text_muted, 14));
  p.drawPixmap(QPointF(close_rect().center().x() - 6, (HEADER - 12) / 2), theme::icon("close", theme::text_muted, 12));
  p.fillRect(QRectF(0, HEADER - 1, w(), 1), theme::border);
  // The messages.
  QRectF body = body_rect();
  p.save();
  p.setClipRect(body, Qt::IntersectClip);
  if (blocks_.empty()) {
    p.setFont(label);
    p.setPen(theme::text_disabled);
    p.drawText(body.adjusted(16, 16, -16, -16), Qt::AlignTop | Qt::AlignHCenter,
               errors_only_ ? "No errors or warnings." : "No messages.");
  }
  for (size_t k = 0; k < blocks_.size(); k++) {
    const Block& b = blocks_[k];
    float top = static_cast<float>(body.y()) + b.y - scroll_;
    if (top > body.bottom() || top + b.h < body.y()) continue;
    const Message& m = log[b.index];
    auto level = m.level();
    QRectF card(PAD - 2, top, w() - 2 * PAD + 2, b.h);
    p.setPen(Qt::NoPen);
    p.setBrush(theme::island_bg);
    p.drawRoundedRect(card, 6, 6);
    if (level == Message::Level::Error || level == Message::Level::Warning)
      p.fillRect(QRectF(card.x(), card.y() + 4, 2, card.height() - 8), level_color(level));
    // Its head: the kind's icon and name, the time.
    p.drawPixmap(QPointF(card.x() + 8, top + 4), theme::icon(icon_of(level), level_color(level), 12));
    p.setFont(small);
    p.setPen(level_color(level));
    p.drawText(QRectF(card.x() + 26, top + 1, 200, HEAD), Qt::AlignVCenter, kind_label(m.kind));
    p.setPen(theme::text_disabled);
    QString when = static_cast<int>(b.index) == copied_ ? QString("copied") : m.at.toString("HH:mm:ss");
    p.drawText(QRectF(card.right() - 120, top + 1, 112, HEAD), Qt::AlignVCenter | Qt::AlignRight, when);
    float y = top + HEAD + 2;
    for (auto& line : b.lines) {
      if (y + cm_.cell_h >= body.y() && y <= body.bottom())
        paint_chunks(p, screen_, line, QPointF(card.x() + 8, y), cm_);
      y += cm_.cell_h;
    }
  }
  p.restore();
  // The scroll bar, while there is more than shows.
  if (max_scroll() > 0) {
    float h = body_h() * body_h() / content_h_;
    float y = static_cast<float>(body.y()) + (body_h() - h) * scroll_ / max_scroll();
    p.setPen(Qt::NoPen);
    p.setBrush(theme::with_alpha(theme::text_disabled, 0.4f));
    p.drawRoundedRect(QRectF(w() - 6, y, 4, h), 2, 2);
  }
  p.setClipping(false);
  p.setPen(QPen(theme::border_strong, 1));
  p.setBrush(Qt::NoBrush);
  p.drawPath(shape);
}

const MessagesPanel::Block* MessagesPanel::block_at(QPointF at) const {
  float y = static_cast<float>(at.y() - HEADER) + scroll_;
  for (auto& b : blocks_)
    if (y >= b.y && y < b.y + b.h) return &b;
  return nullptr;
}

void MessagesPanel::mousePressEvent(QMouseEvent* e) {
  QPointF at = local(e->position());
  if (at.x() < EDGE) {
    resizing_ = true;
    press_x_ = static_cast<float>(e->globalPosition().x());
    press_width_ = width_;
    return;
  }
  if (close_rect().contains(at)) {
    emit close_clicked();
  } else if (clear_rect().contains(at)) {
    screen_.messages.clear_log();
    changed();
  } else if (filter_rect().contains(at)) {
    errors_only_ = !errors_only_;
    to_bottom();
  }
}

void MessagesPanel::mouseMoveEvent(QMouseEvent* e) {
  if (resizing_) {
    width_ = std::clamp(press_width_ - static_cast<float>(e->globalPosition().x()) + press_x_, 240.0f, 1200.0f);
    emit width_changed();
    return;
  }
  setCursor(local(e->position()).x() < EDGE ? Qt::SizeHorCursor : Qt::ArrowCursor);
}

void MessagesPanel::mouseReleaseEvent(QMouseEvent*) { resizing_ = false; }

void MessagesPanel::mouseDoubleClickEvent(QMouseEvent* e) {
  const Block* b = block_at(local(e->position()));
  if (!b || local(e->position()).y() < HEADER) return;
  QApplication::clipboard()->setText(QString::fromStdString(text_of(screen_.messages.log[b->index].content)));
  copied_ = static_cast<int>(b->index);
  update();
}

void MessagesPanel::wheelEvent(QWheelEvent* e) {
  QPoint px = e->pixelDelta();
  float dy = px.isNull() ? static_cast<float>(e->angleDelta().y()) / 120.0f * 3 * cm_.cell_h : static_cast<float>(px.y());
  scroll_ = std::clamp(scroll_ - dy, 0.0f, max_scroll());
  at_bottom_ = scroll_ >= max_scroll() - 1;
  update();
}

}  // namespace biscide
