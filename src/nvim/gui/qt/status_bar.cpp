#include "status_bar.h"

#include "theme.h"

#include <QMouseEvent>
#include <QPainter>

namespace biscide {

namespace {

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

}  // namespace

StatusBar::StatusBar(const Screen& screen, const CellMetrics& cm, QWidget* parent)
    : QWidget(parent), screen_(screen), cm_(cm) {
  setFocusPolicy(Qt::NoFocus);
  setAttribute(Qt::WA_OpaquePaintEvent);
}

QRectF StatusBar::switch_rect() const { return QRectF(width() - 118, 3, 110, height() - 6); }

/// The command line: what is typed (its first character, its prompt, its
/// indent, its text) and the cursor in it; the x it ended at.
float StatusBar::paint_cmdline(QPainter& p, float x, float right) {
  const CmdlineLevel* l = screen_.cmdline.top();
  Chunks line;
  std::string head = l->firstc + l->prompt + std::string(static_cast<size_t>(std::max<int64_t>(0, l->indent)), ' ');
  if (!head.empty()) line.push_back({0, head});
  line.insert(line.end(), l->content.begin(), l->content.end());
  // The cursor's column: the head's and the text's before its byte.
  std::string text = text_of(l->content);
  int cursor_col = text_cols(head) + text_cols(text.substr(0, static_cast<size_t>(std::clamp<int64_t>(l->pos, 0, static_cast<int64_t>(text.size())))));
  int max_cols = static_cast<int>((right - x) / cm_.cell_w);
  // The cursor kept in view: the text scrolled left past it.
  int skip = std::max(0, cursor_col + 2 - max_cols);
  float y = (static_cast<float>(height()) - cm_.cell_h) / 2;
  p.save();
  p.setClipRect(QRectF(x, 0, right - x, height()));
  QPointF origin(x - cm_.cell_w * static_cast<float>(skip), y);
  paint_chunks(p, screen_, line, origin, cm_);
  float cx = static_cast<float>(origin.x()) + cm_.cell_w * static_cast<float>(cursor_col);
  if (!l->special.empty()) {
    p.setPen(theme::cyan);
    p.setFont(cm_.font);
    p.drawText(QPointF(cx, y + cm_.ascent), QString::fromStdString(l->special));
  }
  p.fillRect(QRectF(cx, y + 1, 2, cm_.cell_h - 2), theme::text);
  p.restore();
  return cx;
}

/// The last message Nvim shows: its first line, how many more it has.
void StatusBar::paint_message(QPainter& p, float x, float right) {
  const auto& shown = screen_.messages.shown;
  if (shown.empty()) return;
  const Message& m = shown.back();
  auto lines = lines_of(m.content);
  float y = (static_cast<float>(height()) - cm_.cell_h) / 2;
  Message::Level level = m.level();
  if (level == Message::Level::Error || level == Message::Level::Warning) {
    p.drawPixmap(QPointF(x, (height() - 14) / 2.0),
                 theme::icon(level == Message::Level::Error ? "error" : "warning", level_color(level), 14));
    x += 20;
  }
  QString more;
  if (lines.size() > 1) more = QString("  +%1 lines").arg(lines.size() - 1);
  QFont ui = theme::ui_font();
  ui.setPixelSize(12);
  float mw = more.isEmpty() ? 0 : static_cast<float>(QFontMetricsF(ui).horizontalAdvance(more)) + 8;
  int cols = static_cast<int>((right - x - mw) / cm_.cell_w);
  // The first line that says something.
  const Chunks* first = &lines.front();
  for (auto& l : lines)
    if (!text_of(l).empty()) {
      first = &l;
      break;
    }
  int used = paint_chunks(p, screen_, *first, QPointF(x, y), cm_, cols);
  if (!more.isEmpty()) {
    p.setFont(ui);
    p.setPen(theme::text_disabled);
    p.drawText(QRectF(x + cm_.cell_w * static_cast<float>(used), 0, mw, height()), Qt::AlignVCenter, more);
  }
}

void StatusBar::paintEvent(QPaintEvent*) {
  QPainter p(this);
  p.setRenderHint(QPainter::Antialiasing);
  p.fillRect(rect(), theme::frame_bg);
  p.fillRect(QRectF(0, 0, width(), 1), theme::border);
  // The mode.
  bool cmdline = screen_.cmdline.active();
  QString mode = cmdline && mode_ != "PICK" ? QString("COMMAND") : mode_;
  QFont mono = cm_.font;
  p.setFont(mono);
  QColor mc = mode == "INSERT" ? theme::green : (mode == "NORMAL" ? theme::accent : theme::cyan);
  p.setPen(mc);
  float mw = static_cast<float>(QFontMetricsF(mono).horizontalAdvance(mode)) + 24;
  p.drawText(QRectF(12, 0, mw, height()), Qt::AlignVCenter, mode);
  // The right end: showcmd, the mode's message, the program, the switch.
  QRectF sw = switch_rect();
  QFont ui = theme::ui_font();
  ui.setPixelSize(12);
  QFontMetricsF uf(ui);
  float right = static_cast<float>(sw.x()) - 12;
  if (!info_.isEmpty()) {
    float w = static_cast<float>(uf.horizontalAdvance(info_));
    p.setFont(ui);
    p.setPen(theme::text_muted);
    p.drawText(QRectF(right - w, 0, w + 2, height()), Qt::AlignVCenter, info_);
    right -= w + 16;
  }
  float y = (static_cast<float>(height()) - cm_.cell_h) / 2;
  for (const Chunks* c : {&screen_.messages.showmode, &screen_.messages.showcmd}) {
    std::string t = text_of(*c);
    // Nvim's own mode message ("-- INSERT --") the mode's label says.
    if (t.empty() || t.rfind("-- ", 0) == 0) continue;
    float w = cm_.cell_w * static_cast<float>(text_cols(t));
    paint_chunks(p, screen_, *c, QPointF(right - w, y), cm_);
    right -= w + 16;
  }
  // The middle: the command line, else the message.
  text_x_ = 12 + mw;
  if (cmdline) {
    paint_cmdline(p, text_x_, right);
  } else {
    paint_message(p, text_x_, right);
  }
  // The messages panel's switch, with what it has not shown.
  const auto& msgs = screen_.messages;
  p.setPen(Qt::NoPen);
  p.setBrush(panel_open_ ? theme::selection_bg : QColor(Qt::transparent));
  p.drawRoundedRect(sw, 5, 5);
  p.drawPixmap(QPointF(sw.x() + 8, sw.center().y() - 7), theme::icon("messages", theme::text_muted, 14));
  p.setFont(ui);
  p.setPen(panel_open_ ? theme::text : theme::text_muted);
  p.drawText(sw.adjusted(28, 0, 0, 0), Qt::AlignVCenter, "Messages");
  int unread = msgs.unread_errors > 0 ? msgs.unread_errors : msgs.unread_warnings;
  if (unread > 0 && !panel_open_) {
    QString n = unread > 99 ? QString("99+") : QString::number(unread);
    QFont small = ui;
    small.setPixelSize(10);
    small.setBold(true);
    float bw = std::max(16.0f, static_cast<float>(QFontMetricsF(small).horizontalAdvance(n)) + 8);
    QRectF badge(sw.right() - bw - 6, sw.center().y() - 7, bw, 14);
    p.setPen(Qt::NoPen);
    p.setBrush(msgs.unread_errors > 0 ? theme::error : theme::warning);
    p.drawRoundedRect(badge, 7, 7);
    p.setFont(small);
    p.setPen(theme::island_bg);
    p.drawText(badge, Qt::AlignCenter, n);
  }
}

void StatusBar::mousePressEvent(QMouseEvent* e) {
  // The switch, or the message (it is read in full in the panel).
  if (switch_rect().contains(e->position()) || (!screen_.messages.shown.empty() && e->position().x() > text_x_))
    emit messages_clicked();
}

}  // namespace biscide
