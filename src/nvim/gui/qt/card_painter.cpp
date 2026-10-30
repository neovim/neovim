#include "card_painter.h"

#include "theme.h"

#include <QFontMetricsF>
#include <QPainterPath>

#include <cmath>

namespace biscide {

namespace {

/// The background's dots (world units).
constexpr float GRID = 40.0f;
/// How opaque a card's background is: not at all (the canvas shows
/// through its code).
constexpr float CARD_ALPHA = 0.0f;
constexpr int CURVES_MAX = 200;

/// The painter in a card's own units: its top left at the origin, at the
/// camera's zoom.
void enter(QPainter& p, const PaintContext& c, const Drawn& d) {
  auto [sx, sy] = c.cam.to_screen(d.x, d.y);
  p.translate(sx, sy);
  p.scale(c.cam.zoom, c.cam.zoom);
}

QFont small_font() {
  QFont f = theme::ui_font();
  f.setPixelSize(11);
  return f;
}

/// The bar at the top: the kind, the name, how many use it and it uses.
void paint_title(QPainter& p, const PaintContext& c, const NodeInfo& n, float w) {
  float h = c.m.title_h;
  p.fillRect(QRectF(0, 0, w, h), theme::island_bg);
  p.fillRect(QRectF(0, h - 1, w, 1), theme::border);
  QFont small = small_font();
  QFontMetricsF fm(small);
  p.setFont(small);
  p.setPen(n.kind == "missing" ? theme::error : theme::text_disabled);
  QString kind = QString::fromStdString(n.kind);
  float kw = static_cast<float>(fm.horizontalAdvance(kind));
  p.drawText(QRectF(8, 0, kw + 2, h), Qt::AlignVCenter, kind);
  QString degree = QString("←%1 →%2").arg(n.used_by).arg(n.uses);
  float dw = static_cast<float>(fm.horizontalAdvance(degree));
  p.drawText(QRectF(w - dw - 8, 0, dw + 2, h), Qt::AlignVCenter, degree);
  QFont ui = theme::ui_font();
  p.setFont(ui);
  p.setPen(theme::text);
  QRectF name(8 + kw + 6, 0, w - kw - dw - 30, h);
  p.drawText(name, Qt::AlignVCenter,
             QFontMetricsF(ui).elidedText(QString::fromStdString(n.name), Qt::ElideRight, name.width()));
}

/// Which of the part's rows the card shows: "12 lines", "↑ 3–20 of 40 ↓"
/// (its window has them all; the card scrolls in it).
QString extent(const PaintContext& c, const NodeInfo& n, const Placed& card, std::optional<int64_t> grid) {
  QString all = n.lines == 1 ? QString("1 line") : QString("%1 lines").arg(n.lines);
  auto it = grid ? c.screen.grids.find(*grid) : c.screen.grids.end();
  if (it == c.screen.grids.end() || it->second.height <= card.rows) return all;
  int total = it->second.height;
  int first = static_cast<int>(std::lround(c.scroll_of(card.win)));
  int last = std::min(total, first + card.rows);
  return QString("%1%2–%3 of %4%5")
      .arg(first > 0 ? "↑ " : "")
      .arg(first + 1)
      .arg(last)
      .arg(total)
      .arg(last < total ? " ↓" : "");
}

/// The bar at the bottom: where the declaration is, which lines show.
void paint_footer(QPainter& p, const PaintContext& c, const NodeInfo& n, const Placed& card, std::optional<int64_t> grid,
                  const Drawn& d) {
  float h = c.m.title_h, y = d.h - h;
  p.fillRect(QRectF(0, y, d.w, h), theme::island_bg);
  p.fillRect(QRectF(0, y, d.w, 1), theme::border);
  QFont small = small_font();
  QFontMetricsF fm(small);
  p.setFont(small);
  p.setPen(theme::text_disabled);
  QString right = extent(c, n, card, grid);
  float ew = static_cast<float>(fm.horizontalAdvance(right));
  QString place = QString::fromStdString(n.rel) + ":" + QString::number(n.line);
  p.drawText(QRectF(8, y, d.w - ew - 24, h), Qt::AlignVCenter, fm.elidedText(place, Qt::ElideMiddle, d.w - ew - 24));
  p.drawText(QRectF(d.w - ew - 8, y, ew + 2, h), Qt::AlignVCenter, right);
}

QColor border_of(const CardLook& look) {
  if (look.missing) return theme::with_alpha(theme::error, look.hovered ? 1.0f : 0.75f);
  if (look.cursor) return theme::warning;
  if (look.active) return theme::accent;
  if (look.hovered) return theme::text_muted;
  return theme::border_strong;
}

}  // namespace

void paint_dots(QPainter& p, const PaintContext& c) {
  float cell = GRID;
  while (cell * c.cam.zoom < 14) cell *= 2;
  float step = cell * c.cam.zoom;
  auto [sx, sy] = c.cam.to_screen(std::floor(c.cam.ox / cell) * cell, std::floor(c.cam.oy / cell) * cell);
  QColor dot = theme::with_alpha(theme::text_disabled, 0.35f);
  for (float y = sy; y < c.size.height(); y += step)
    for (float x = sx; x < c.size.width(); x += step) p.fillRect(QRectF(x, y, 1.6, 1.6), dot);
}

void paint_card(QPainter& p, const PaintContext& c, const Placed& card, const Drawn& d, const CardLook& look) {
  const NodeInfo* n = c.st.node(card.node);
  if (!n) return;
  p.save();
  p.setOpacity(look.opacity);
  enter(p, c, d);
  QRectF box(0, 0, d.w, d.h);
  QPainterPath outline;
  outline.addRoundedRect(box, 8, 8);
  p.fillPath(outline, theme::with_alpha(rgb(c.screen.bg), CARD_ALPHA));
  p.save();
  p.setClipPath(outline);
  paint_title(p, c, *n, d.w);
  auto grid = c.screen.grid_of(card.win);
  QPointF code(c.m.pad, c.m.title_h + c.m.pad);
  if (grid) {
    // Scrolled in its window: from its first row shown, a fraction up.
    float scroll = c.scroll_of(card.win);
    int first = static_cast<int>(std::floor(scroll));
    GridLook g;
    g.first_row = first;
    g.rows = card.rows + 1;
    g.cols = static_cast<int>(c.m.cols);
    g.cursor = look.active;
    g.focused = look.active && c.cards_focused;
    p.save();
    p.setClipRect(QRectF(0, code.y(), d.w, c.m.line_h() * static_cast<float>(card.rows)), Qt::IntersectClip);
    paint_grid(p, c.screen, *grid, code - QPointF(0, (scroll - static_cast<float>(first)) * c.m.line_h()), c.m.cell, g);
    p.restore();
  }
  paint_footer(p, c, *n, card, grid, d);
  p.restore();
  QPen edge(border_of(look), look.active || look.cursor ? 2.0 : 1.0);
  // A missing declaration's card: dashed, it is not there.
  if (look.missing) edge.setStyle(Qt::DashLine);
  p.setPen(edge);
  p.setBrush(Qt::NoBrush);
  p.drawRoundedRect(box.adjusted(0.5, 0.5, -0.5, -0.5), 8, 8);
  p.restore();
}

void paint_new_card(QPainter& p, const PaintContext& c, const Drawn& d) {
  bool writing = c.st.cursor_new;
  p.save();
  enter(p, c, d);
  QRectF box(0, 0, d.w, d.h);
  p.setBrush(theme::with_alpha(rgb(c.screen.bg), writing ? 0.9f : 0.3f));
  QPen pen(writing ? theme::warning : theme::border_strong, writing ? 2 : 1);
  if (!writing) pen.setStyle(Qt::DashLine);
  p.setPen(pen);
  p.drawRoundedRect(box.adjusted(0.5, 0.5, -0.5, -0.5), 8, 8);
  p.setFont(theme::ui_font());
  p.setPen(theme::text_muted);
  p.drawText(QRectF(8, 0, d.w - 16, c.m.title_h), Qt::AlignVCenter,
             writing ? "new declaration · :w writes it" : "+ new declaration (click, or <leader>n)");
  if (writing)
    if (auto grid = c.screen.grid_of(c.st.new_win)) {
      GridLook g;
      g.rows = c.st.new_rows;
      g.cols = static_cast<int>(c.m.cols);
      g.focused = c.cards_focused;
      paint_grid(p, c.screen, *grid, QPointF(c.m.pad, c.m.title_h + c.m.pad), c.m.cell, g);
    }
  p.restore();
}

void paint_curves(QPainter& p, const PaintContext& c, const Stage& stage, float t) {
  const Placed* active = stage.card(c.st.active, Lane::File);
  if (!active) return;
  Drawn a = stage.drawn(*active, t);
  // A link's row is the file's; the active card's window shows from its
  // top line (the part's first, unless scrolled in it).
  const NodeInfo* an = c.st.node(active->node);
  int64_t top = an ? an->line - 1 : 0;
  if (auto grid = c.screen.grid_of(active->win))
    if (auto vp = c.screen.viewport(*grid)) top = vp->topline;
  int n = 0;
  for (auto& l : c.st.links) {
    // Only to what the active declaration uses: the left lanes have none
    // (the names are marked in their code instead).
    if (l.lane != Lane::Uses || n++ > CURVES_MAX) continue;
    const Placed* used = stage.card(l.node, l.lane);
    if (!used) continue;
    Drawn u = stage.drawn(*used, t);
    float alpha = stage.opacity(*used, c.st.active, t);
    // From the name in the active card's code (its title bar or bottom bar
    // when scrolled out), else its title's right end, to the used card's
    // title.
    std::pair<float, float> from{a.x + a.w, a.y + c.m.title_h / 2};
    bool dot = l.row >= 0;
    if (dot) {
      // Its row of the card's window (else its line's, from the top).
      float r = static_cast<float>(l.vrow >= 0 ? l.vrow : l.row - top) - c.scroll_of(active->win);
      // The text starts after the line numbers.
      int shown = l.vcol >= 0 ? l.vcol : l.col;
      int col = active->textoff + std::min(shown, static_cast<int>(c.m.cols) - active->textoff - 1);
      float x = c.m.pad + (static_cast<float>(col) + 0.5f) * c.m.cell.cell_w;
      float y = r < 0                 ? c.m.title_h / 2
                : r >= static_cast<float>(active->rows) ? a.h - c.m.title_h / 2
                                                         : c.m.title_h + c.m.pad + (r + 0.5f) * c.m.line_h();
      from = {a.x + x, a.y + y};
    }
    QColor color = l.violation ? theme::error : l.kinds.empty() ? theme::text_muted : theme::kind_color(l.kinds.front());
    color = theme::with_alpha(color, 0.8f * alpha);
    auto [fx, fy] = c.cam.to_screen(from.first, from.second);
    auto [tx, ty] = c.cam.to_screen(u.x, u.y + c.m.title_h / 2);
    float reach = std::max(std::abs(tx - fx) / 2, 30.0f);
    QPainterPath curve(QPointF(fx, fy));
    curve.cubicTo(QPointF(fx + reach, fy), QPointF(tx - reach, ty), QPointF(tx, ty));
    p.setPen(QPen(color, 1.5));
    p.setBrush(Qt::NoBrush);
    p.drawPath(curve);
    if (dot) {
      p.setPen(Qt::NoPen);
      p.setBrush(color);
      p.drawEllipse(QPointF(fx, fy), 3.5, 3.5);
    }
    QPainterPath head;
    head.moveTo(tx, ty);
    head.lineTo(tx - 8, ty - 4);
    head.lineTo(tx - 8, ty + 4);
    head.closeSubpath();
    p.fillPath(head, color);
  }
}

}  // namespace biscide
