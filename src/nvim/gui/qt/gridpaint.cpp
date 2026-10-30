#include "gridpaint.h"

#include <QFontMetricsF>

namespace biscide {

QColor rgb(uint32_t c) { return QColor((c >> 16) & 0xFF, (c >> 8) & 0xFF, c & 0xFF); }

CellMetrics cell_metrics(const QFont& font, float cell_h) {
  QFontMetricsF fm(font);
  float w = static_cast<float>(fm.horizontalAdvance(QLatin1Char('m')));
  float ascent = static_cast<float>(fm.ascent());
  float text_h = static_cast<float>(fm.ascent() + fm.descent());
  return {font, w, cell_h, ascent + (cell_h - text_h) / 2};
}

namespace {

QFont font_of(const CellMetrics& m, const HlAttr* a) {
  if (!a || (!a->bold && !a->italic && !a->underline && !a->undercurl && !a->strikethrough)) return m.font;
  QFont f = m.font;
  if (a->bold) f.setBold(true);
  if (a->italic) f.setItalic(true);
  if (a->strikethrough) f.setStrikeOut(true);
  return f;
}

/// Fills a run of cells' background. Under the camera's zoom, edges fall
/// between device pixels: anti-aliased, two runs (or rows) side by side
/// would leave a faint seam between them. So the rectangle is filled
/// without anti-aliasing, a hair bigger, to overlap its neighbours.
void fill_cells(QPainter& p, double x, double y, double w, double h, const QColor& color) {
  const double hair = 0.6 / std::max(0.1, p.transform().m11());
  bool aa = p.testRenderHint(QPainter::Antialiasing);
  p.setRenderHint(QPainter::Antialiasing, false);
  p.fillRect(QRectF(x, y, w + hair, h + hair), color);
  p.setRenderHint(QPainter::Antialiasing, aa);
}

}  // namespace

void paint_grid(QPainter& p, const Screen& s, int64_t grid, QPointF origin, const CellMetrics& m,
                const GridLook& look) {
  auto it = s.grids.find(grid);
  if (it == s.grids.end()) return;
  const Grid& g = it->second;
  int rows = look.rows < 0 ? g.height : std::min(look.rows, g.height - look.first_row);
  int cols = look.cols < 0 ? g.width : std::min(look.cols, g.width);
  for (int r = 0; r < rows; r++) {
    int gr = r + look.first_row;
    float y = static_cast<float>(origin.y()) + m.cell_h * static_cast<float>(r);
    // Backgrounds.
    int c = 0;
    while (c < cols) {
      uint32_t f, b, sp;
      s.colors(g.cell(gr, c)->hl, f, b, sp);
      int start = c;
      while (c < cols) {
        uint32_t f2, b2, sp2;
        s.colors(g.cell(gr, c)->hl, f2, b2, sp2);
        if (b2 != b) break;
        c++;
      }
      if (b != s.bg || look.fill_default) fill_cells(p, origin.x() + m.cell_w * static_cast<float>(start), y,
                                                      m.cell_w * static_cast<float>(c - start), m.cell_h, rgb(b));
    }
    // Text, in runs of one highlight.
    c = 0;
    while (c < cols) {
      const Cell* cell = g.cell(gr, c);
      int64_t hl = cell->hl;
      int start = c;
      QString text;
      while (c < cols && g.cell(gr, c)->hl == hl) {
        const Cell* k = g.cell(gr, c);
        if (k->text.empty()) {
          // A wide character's second half: its run ends here.
          c++;
          break;
        }
        text += QString::fromStdString(k->text);
        c++;
        if (k->text.size() > 1 && c < cols && g.cell(gr, c)->text.empty()) {
          c++;
          break;
        }
      }
      if (text.trimmed().isEmpty()) continue;
      auto ha = s.hl.find(hl);
      const HlAttr* a = ha == s.hl.end() ? nullptr : &ha->second;
      uint32_t f, b, sp;
      s.colors(hl, f, b, sp);
      p.setFont(font_of(m, a));
      p.setPen(rgb(f));
      // Each character in its cell: drawn one at a time where the text has
      // characters the font's advance does not keep to the grid.
      float x = static_cast<float>(origin.x()) + m.cell_w * static_cast<float>(start);
      float base = y + m.ascent;
      bool ascii = true;
      for (QChar ch : text)
        if (ch.unicode() >= 0x80) ascii = false;
      if (ascii) {
        p.drawText(QPointF(x, base), text);
      } else {
        int col = 0;
        for (int k = 0; k < text.size(); k++) {
          QString one = text.mid(k, 1);
          if (text[k].isHighSurrogate() && k + 1 < text.size()) one = text.mid(k++, 2);
          p.drawText(QPointF(x + m.cell_w * static_cast<float>(col), base), one);
          col++;
        }
      }
      if (a && (a->underline || a->undercurl)) {
        p.setPen(QPen(rgb(sp), 1));
        float uy = y + m.cell_h - 2;
        p.drawLine(QPointF(x, uy), QPointF(x + m.cell_w * static_cast<float>(c - start), uy));
      }
    }
  }
  if (!look.cursor || s.cursor_grid != grid) return;
  int cr = s.cursor_row - look.first_row, cc = s.cursor_col;
  if (cr < 0 || cr >= rows || cc < 0 || cc >= cols) return;
  const Cell* cell = g.cell(s.cursor_row, cc);
  QRectF q(origin.x() + m.cell_w * static_cast<float>(cc), origin.y() + m.cell_h * static_cast<float>(cr),
           m.cell_w, m.cell_h);
  uint32_t f, b, sp;
  s.colors(cell ? cell->hl : 0, f, b, sp);
  if (!look.focused) {
    p.setPen(QPen(rgb(f), 1));
    p.setBrush(Qt::NoBrush);
    p.drawRect(q.adjusted(0.5, 0.5, -0.5, -0.5));
    return;
  }
  ModeInfo mode = s.mode();
  uint32_t cf = b, cb = f;
  if (mode.attr != 0) {
    uint32_t af, ab, asp;
    s.colors(mode.attr, af, ab, asp);
    cf = ab;
    cb = af;
    if (s.hl.count(mode.attr) && !s.hl.at(mode.attr).bg) std::swap(cf, cb);
  }
  float pct = mode.percentage > 0 ? mode.percentage : 0.25f;
  switch (mode.shape) {
    case CursorShape::Vertical:
      q.setWidth(std::max(2.0f, m.cell_w * pct));
      p.fillRect(q, rgb(cb));
      return;
    case CursorShape::Horizontal: {
      float h = std::max(2.0f, m.cell_h * pct);
      q.setTop(q.bottom() - h);
      p.fillRect(q, rgb(cb));
      return;
    }
    case CursorShape::Block:
      p.fillRect(q, rgb(cb));
      if (cell && !cell->text.empty() && cell->text != " ") {
        p.setPen(rgb(cf));
        p.setFont(m.font);
        p.drawText(QPointF(q.x(), q.y() + m.ascent), QString::fromStdString(cell->text));
      }
      return;
  }
}

int text_cols(const std::string& text) {
  return static_cast<int>(QString::fromStdString(text).toUcs4().size());
}

int paint_chunks(QPainter& p, const Screen& s, const Chunks& chunks, QPointF origin, const CellMetrics& m,
                 int max_cols) {
  int col = 0;
  for (auto& c : chunks) {
    if (max_cols >= 0 && col >= max_cols) break;
    QList<uint> cps = QString::fromStdString(c.text).toUcs4();
    if (max_cols >= 0 && col + cps.size() > max_cols) cps.resize(max_cols - col);
    if (cps.isEmpty()) continue;
    uint32_t f, b, sp;
    s.colors(c.attr, f, b, sp);
    float x = static_cast<float>(origin.x()) + m.cell_w * static_cast<float>(col);
    float w = m.cell_w * static_cast<float>(cps.size());
    if (b != s.bg) fill_cells(p, x, origin.y(), w, m.cell_h, rgb(b));
    auto ha = s.hl.find(c.attr);
    const HlAttr* a = ha == s.hl.end() ? nullptr : &ha->second;
    p.setFont(font_of(m, a));
    p.setPen(rgb(f));
    float base = static_cast<float>(origin.y()) + m.ascent;
    for (int k = 0; k < cps.size(); k++) {
      char32_t ch = cps[k];
      if (ch != ' ')
        p.drawText(QPointF(x + m.cell_w * static_cast<float>(k), base), QString::fromUcs4(&ch, 1));
    }
    if (a && (a->underline || a->undercurl)) {
      p.setPen(QPen(rgb(sp), 1));
      float uy = static_cast<float>(origin.y()) + m.cell_h - 2;
      p.drawLine(QPointF(x, uy), QPointF(x + w, uy));
    }
    col += static_cast<int>(cps.size());
  }
  return col;
}

std::string grid_row_text(const Screen& s, int64_t grid, int row) {
  auto it = s.grids.find(grid);
  if (it == s.grids.end()) return {};
  std::string out;
  for (int c = 0; c < it->second.width; c++)
    if (auto cell = it->second.cell(row, c)) out += cell->text;
  return out;
}

}  // namespace biscide
