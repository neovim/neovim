#include "overlays.h"

#include "theme.h"

#include <QFontMetricsF>

namespace biscide {

namespace {

QFont label_font() {
  QFont f = theme::ui_font();
  f.setPixelSize(12);
  return f;
}

}  // namespace

void Overlays::paint(QPainter& p, const PaintContext& c) {
  paint_history(p, c);
  paint_key(p, c);
}

// ---- The history ----

void Overlays::paint_history(QPainter& p, const PaintContext& c) {
  history_hits_.clear();
  const auto& names = c.st.history;
  if (names.empty()) return;
  QFont f = label_font();
  QFontMetricsF fm(f);
  p.setFont(f);
  int at = c.st.history_at;
  int from = std::max(1, at - 8), to = std::min(static_cast<int>(names.size()), at + 4);
  float x = left() - 2, y = 6;
  auto sep = [&](const QString& s) {
    p.setPen(theme::text_disabled);
    float w = static_cast<float>(fm.horizontalAdvance(s));
    p.drawText(QRectF(x, y, w + 2, 24), Qt::AlignVCenter, s);
    x += w + 6;
  };
  if (from > 1) sep("…");
  for (int k = from; k <= to && x < c.size.width() - 40; k++) {
    if (k > from) sep("›");
    QString name = QString::fromStdString(names[static_cast<size_t>(k - 1)]);
    float w = static_cast<float>(fm.horizontalAdvance(name)) + 16;
    QRectF chip(x, y + 2, w, 20);
    bool here = k == at;
    p.setPen(QPen(here ? theme::accent : theme::border, 1));
    p.setBrush(here ? theme::selection_bg : theme::with_alpha(theme::frame_bg, 0.9f));
    p.drawRoundedRect(chip, 5, 5);
    p.setPen(here ? theme::text : theme::text_muted);
    p.drawText(chip, Qt::AlignCenter, name);
    history_hits_.push_back({chip, k});
    x += w + 6;
  }
  if (to < static_cast<int>(names.size())) sep("…");
}

std::optional<int> Overlays::history_at(QPointF at) const {
  for (auto& [r, k] : history_hits_)
    if (r.contains(at)) return k;
  return std::nullopt;
}

// ---- The key to the colours ----

void Overlays::paint_key(QPainter& p, const PaintContext& c) {
  QFont f = label_font();
  p.setFont(f);
  if (!show_key) {
    QString s = "Colours";
    float w = static_cast<float>(QFontMetricsF(f).horizontalAdvance(s)) + 16;
    key_box_ = QRectF(left(), c.size.height() - 34, w, 22);
    key_close_ = QRectF();
    p.setPen(QPen(theme::border, 1));
    p.setBrush(theme::with_alpha(theme::frame_bg, 0.9f));
    p.drawRoundedRect(key_box_, 5, 5);
    p.setPen(theme::text_muted);
    p.drawText(key_box_, Qt::AlignCenter, s);
    return;
  }
  struct Row {
    QColor color;
    const char* text;
  };
  const Row rows[] = {{theme::kind_color("call"), "calls it"},
                      {theme::kind_color("parameter"), "has it in parameters or results"},
                      {theme::kind_color("field"), "has it in its fields"},
                      {theme::kind_color("type_use"), "uses the type"},
                      {theme::kind_color("reference"), "uses the value"},
                      {theme::kind_color("receiver"), "is a method of it"},
                      {theme::error, "points outward: a layer violation"}};
  float h = 52 + static_cast<float>(std::size(rows)) * 18;
  QRectF box(left(), c.size.height() - h - 10, 260, h);
  key_box_ = box;
  key_close_ = QRectF(box.right() - 24, box.y() + 6, 16, 18);
  p.setPen(QPen(theme::border, 1));
  p.setBrush(theme::with_alpha(theme::frame_bg, 0.94f));
  p.drawRoundedRect(box, 8, 8);
  p.setPen(theme::text);
  p.drawText(QRectF(box.x() + 10, box.y() + 6, 200, 18), Qt::AlignVCenter, "Colours");
  p.setPen(theme::text_muted);
  p.drawText(key_close_, Qt::AlignCenter, "×");
  float y = box.y() + 26;
  p.setPen(QPen(theme::accent, 1));
  p.setBrush(Qt::NoBrush);
  p.drawRoundedRect(QRectF(box.x() + 13, y + 4, 16, 10), 2, 2);
  p.setPen(theme::text_muted);
  p.drawText(QRectF(box.x() + 40, y, 210, 18), Qt::AlignVCenter, "the declaration in the middle");
  y += 22;
  for (auto& r : rows) {
    p.fillRect(QRectF(box.x() + 12, y + 8, 18, 2), r.color);
    p.drawText(QRectF(box.x() + 40, y, 210, 18), Qt::AlignVCenter, r.text);
    y += 18;
  }
}

}  // namespace biscide
