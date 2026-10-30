#include "popups.h"

#include "theme.h"

#include <QPainter>

#include <algorithm>

namespace biscide {

namespace {

constexpr int PUM_ROWS = 12;

/// A box at the canvas's bottom left, for `rows` lines.
QRectF bottom_box(const QWidget& w, const CellMetrics& m, int rows, int cols) {
  float h = static_cast<float>(rows) * m.cell_h + 20;
  float bw = std::min(static_cast<float>(w.width()) - 24, static_cast<float>(cols) * m.cell_w + 28);
  return QRectF(12, w.height() - h - 10, bw, h);
}

void paint_box(QPainter& p, QRectF r, const QColor& edge) {
  p.setPen(QPen(edge, 1));
  p.setBrush(theme::frame_bg);
  p.drawRoundedRect(r, 8, 8);
}

}  // namespace

Popups::Popups(const Screen& screen, const CellMetrics& cm, CellAt cell_at, CmdlineX cmdline_x, QWidget* parent)
    : QWidget(parent), screen_(screen), cm_(cm), cell_at_(std::move(cell_at)), cmdline_x_(std::move(cmdline_x)) {
  setAttribute(Qt::WA_TransparentForMouseEvents);
  setAttribute(Qt::WA_NoSystemBackground);
  setFocusPolicy(Qt::NoFocus);
}

void Popups::paintEvent(QPaintEvent*) {
  QPainter p(this);
  p.setRenderHint(QPainter::Antialiasing);
  paint_confirm(p);
  paint_block(p);
  paint_pum(p);
}

/// The question a prompt waits on: the last "confirm" message shown.
void Popups::paint_confirm(QPainter& p) {
  const Message* q = nullptr;
  for (auto& m : screen_.messages.shown)
    if (m.kind == "confirm") q = &m;
  if (!q) return;
  auto lines = lines_of(q->content);
  int cols = 0;
  for (auto& l : lines) cols = std::max(cols, text_cols(text_of(l)));
  QRectF r = bottom_box(*this, cm_, static_cast<int>(lines.size()), cols);
  paint_box(p, r, theme::warning);
  float y = static_cast<float>(r.y()) + 10;
  for (auto& l : lines) {
    paint_chunks(p, screen_, l, QPointF(r.x() + 14, y), cm_, static_cast<int>((r.width() - 28) / cm_.cell_w));
    y += cm_.cell_h;
  }
}

/// The lines typed before the command line (`:function`).
void Popups::paint_block(QPainter& p) {
  const auto& block = screen_.cmdline.block;
  if (block.empty() || !screen_.cmdline.active()) return;
  int rows = std::min(static_cast<int>(block.size()), std::max(1, static_cast<int>((height() - 40) / cm_.cell_h)));
  int cols = 0;
  for (auto& l : block) cols = std::max(cols, text_cols(text_of(l)));
  QRectF r = bottom_box(*this, cm_, rows, std::max(cols, 40));
  paint_box(p, r, theme::border_strong);
  float y = static_cast<float>(r.y()) + 10;
  for (size_t k = block.size() - static_cast<size_t>(rows); k < block.size(); k++) {
    paint_chunks(p, screen_, block[k], QPointF(r.x() + 14, y), cm_);
    y += cm_.cell_h;
  }
}

/// The popup menu: its words, their kinds and menus, the selected one lit.
void Popups::paint_pum(QPainter& p) {
  const auto& pum = screen_.pum;
  if (!pum.shown || pum.items.empty()) return;
  int n = static_cast<int>(pum.items.size());
  int rows = std::min(PUM_ROWS, n);
  // The rows shown: the selected one among them.
  int first = std::clamp(pum.selected - rows / 2, 0, std::max(0, n - rows));
  int wcols = 0, kcols = 0, mcols = 0;
  for (auto& it : pum.items) {
    wcols = std::max(wcols, text_cols(it.word));
    kcols = std::max(kcols, text_cols(it.kind));
    mcols = std::max(mcols, text_cols(it.menu));
  }
  wcols = std::min(wcols, 50);
  mcols = std::min(mcols, 30);
  int cols = wcols + (kcols ? kcols + 2 : 0) + (mcols ? mcols + 2 : 0);
  float w = static_cast<float>(cols) * cm_.cell_w + 20;
  float h = static_cast<float>(rows) * cm_.cell_h + 8;
  QRectF r;
  if (pum.grid == -1) {
    // Above the command line, at its column.
    float x = std::clamp(cmdline_x_(static_cast<int>(pum.col)) - 10, 4.0f, static_cast<float>(width()) - w - 4);
    r = QRectF(x, height() - h - 6, w, h);
  } else if (auto cell = cell_at_(pum.grid, static_cast<int>(pum.row), static_cast<int>(pum.col))) {
    // Under the cell (above it, when there is no room).
    float x = std::clamp(static_cast<float>(cell->x()) - 10, 4.0f, static_cast<float>(width()) - w - 4);
    float y = static_cast<float>(cell->bottom()) + 2;
    if (y + h > height()) y = static_cast<float>(cell->y()) - h - 2;
    r = QRectF(x, y, w, h);
  } else {
    return;
  }
  paint_box(p, r, theme::border_strong);
  QFont mono = cm_.font;
  for (int k = 0; k < rows; k++) {
    int i = first + k;
    const auto& it = pum.items[static_cast<size_t>(i)];
    float y = static_cast<float>(r.y()) + 4 + static_cast<float>(k) * cm_.cell_h;
    if (i == pum.selected) p.fillRect(QRectF(r.x() + 3, y, r.width() - 6, cm_.cell_h), theme::selection_bg);
    float x = static_cast<float>(r.x()) + 10;
    p.setFont(mono);
    p.setPen(theme::text);
    QString word = QString::fromStdString(it.word);
    p.drawText(QPointF(x, y + cm_.ascent), QFontMetricsF(mono).elidedText(word, Qt::ElideRight, wcols * cm_.cell_w));
    x += static_cast<float>(wcols + 2) * cm_.cell_w;
    p.setPen(theme::cyan);
    if (kcols) {
      p.drawText(QPointF(x, y + cm_.ascent), QString::fromStdString(it.kind));
      x += static_cast<float>(kcols + 2) * cm_.cell_w;
    }
    p.setPen(theme::text_disabled);
    if (mcols)
      p.drawText(QPointF(x, y + cm_.ascent),
                 QFontMetricsF(mono).elidedText(QString::fromStdString(it.menu), Qt::ElideRight, mcols * cm_.cell_w));
  }
}

}  // namespace biscide
