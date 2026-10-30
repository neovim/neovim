#include "picker_panel.h"

#include "theme.h"

#include <QFontMetricsF>
#include <QMouseEvent>
#include <QPainter>
#include <QWheelEvent>

#include <algorithm>

namespace biscide {

namespace {

constexpr float HEADER = 36.0f;
constexpr float PROMPT_H = 34.0f;
constexpr float ROW_H = 26.0f;
constexpr float PAD = 10.0f;

/// An item's kind as a badge: an icon, or a letter on a colour.
struct Badge {
  QString icon, letter;
  QColor color;
};

Badge badge_of(const std::string& kind) {
  if (kind == "func" || kind == "function") return {{}, "f", theme::accent};
  if (kind == "method") return {{}, "m", theme::violet};
  if (kind == "type" || kind == "struct" || kind == "interface" || kind == "enum" || kind == "trait" ||
      kind == "union")
    return {{}, "T", theme::green};
  if (kind == "var" || kind == "const" || kind == "static" || kind == "let") return {{}, "v", theme::cyan};
  if (kind == "macro") return {{}, "!", theme::warning};
  if (kind == "impl" || kind == "mod") return {{}, "{}", theme::text_muted};
  if (kind == "file:go") return {"file", {}, theme::cyan};
  if (kind == "file:rust") return {"file", {}, QColor(0xD9, 0x84, 0x52)};
  if (kind.rfind("file", 0) == 0) return {"file", {}, theme::text_muted};
  if (kind == "dir") return {"folder", {}, QColor(0xC9, 0xA2, 0x6D)};
  if (kind == "error") return {"error", {}, theme::error};
  if (kind == "warn") return {"warning", {}, theme::warning};
  if (kind == "info" || kind == "hint") return {"info", {}, theme::accent};
  if (kind == "grep") return {"search", {}, theme::text_muted};
  if (kind == "command") return {{}, ":", theme::cyan};
  if (kind == "keymap") return {"keyboard", {}, theme::text_muted};
  if (kind == "history") return {"clock", {}, theme::text_muted};
  if (kind == "picker") return {"layers", {}, theme::cyan};
  if (kind == "fix") return {{}, "⚡", theme::warning};
  if (kind == "import") return {{}, "↓", theme::cyan};
  if (kind == "create") return {{}, "+", theme::green};
  if (kind == "template") return {"file", {}, theme::violet};
  return {{}, "·", theme::text_disabled};
}

}  // namespace

PickerPanel::PickerPanel(const Screen& screen, Editor& editor, const CellMetrics& cm, QWidget* parent)
    : QWidget(parent), screen_(screen), editor_(editor), cm_(cm) {
  setFocusPolicy(Qt::NoFocus);
  setMouseTracking(true);
  hide();
}

void PickerPanel::set(const mp::Value& payload) {
  bool was = open_;
  open_ = payload.get("open") && payload.get("open")->as_bool().value_or(false);
  auto str = [&](const char* k) { return payload.get(k) ? payload.get(k)->str_or() : std::string(); };
  auto num = [&](const char* k) { return payload.get(k) ? payload.get(k)->int_or(0) : 0; };
  title_ = str("title");
  preview_title_ = str("preview_title");
  empty_ = str("empty");
  prompt_win_ = num("prompt_win");
  preview_win_ = num("preview_win");
  count_ = num("count");
  total_ = num("total");
  busy_ = payload.get("busy") && payload.get("busy")->as_bool().value_or(false);
  if (auto list = payload.get("items"); list && list->as_array()) {
    items_.clear();
    for (auto& v : *list->as_array()) {
      Item it;
      if (auto x = v.get("text")) it.text = x->str_or();
      if (auto x = v.get("detail")) it.detail = x->str_or();
      if (auto x = v.get("kind")) it.kind = x->str_or();
      if (auto x = v.get("pos"); x && x->as_array())
        for (auto& k : *x->as_array()) it.pos.push_back(static_cast<int>(k.int_or(0)));
      items_.push_back(std::move(it));
    }
  }
  selected_ = static_cast<int>(num("selected")) - 1;
  if (!was && open_) scroll_ = 0;
  keep_selected_in_view();
  setVisible(open_);
  if (open_) raise();
  if (was != open_) emit changed();
  update();
}

QRectF PickerPanel::box() const {
  float w = std::min(1200.0f, static_cast<float>(width()) * 0.9f);
  float h = std::min(720.0f, static_cast<float>(height()) * 0.84f);
  float y = std::max(12.0f, (static_cast<float>(height()) - h) * 0.3f);
  return QRectF((width() - w) / 2, y, w, h);
}

QRectF PickerPanel::prompt_rect() const {
  QRectF b = box();
  return QRectF(b.x() + PAD, b.y() + HEADER, b.width() - 2 * PAD, PROMPT_H - 6);
}

QRectF PickerPanel::list_rect() const {
  QRectF b = box();
  float top = b.y() + HEADER + PROMPT_H + 4;
  float w = preview_win_ ? b.width() * 0.44f : b.width();
  return QRectF(b.x() + PAD / 2, top, w - PAD, b.bottom() - top - PAD);
}

QRectF PickerPanel::preview_rect() const {
  QRectF b = box(), l = list_rect();
  float top = l.y() + 26;
  return QRectF(l.right() + PAD, top, b.right() - l.right() - 2 * PAD, b.bottom() - top - PAD);
}

int PickerPanel::prompt_cols() const {
  return std::max(10, static_cast<int>((prompt_rect().width() - 40) / cm_.cell_w));
}

std::pair<int, int> PickerPanel::preview_size() const {
  // Its size as it would be with a preview.
  QRectF b = box();
  float top = b.y() + HEADER + PROMPT_H + 4 + 26;
  float w = b.width() - b.width() * 0.44f - 2 * PAD;
  return {std::max(10, static_cast<int>((w - 12) / cm_.cell_w)),
          std::max(3, static_cast<int>((b.bottom() - top - PAD - 8) / cm_.cell_h))};
}

void PickerPanel::resizeEvent(QResizeEvent*) {
  keep_selected_in_view();
  emit sizes_changed();
}

void PickerPanel::keep_selected_in_view() {
  float body = static_cast<float>(list_rect().height());
  float top = static_cast<float>(selected_) * ROW_H, bottom = top + ROW_H;
  if (top < scroll_) scroll_ = top;
  if (bottom > scroll_ + body) scroll_ = bottom - body;
  float max = std::max(0.0f, static_cast<float>(items_.size()) * ROW_H - body);
  scroll_ = std::clamp(scroll_, 0.0f, max);
}

int PickerPanel::item_at(QPointF at) const {
  QRectF l = list_rect();
  if (!l.contains(at)) return -1;
  int k = static_cast<int>((static_cast<float>(at.y() - l.y()) + scroll_) / ROW_H);
  return k >= 0 && k < static_cast<int>(items_.size()) ? k : -1;
}

/// An item: its badge, its text (the matched characters lit), its detail.
void PickerPanel::paint_item(QPainter& p, const Item& it, QRectF line, bool selected) {
  if (selected) {
    p.setPen(Qt::NoPen);
    p.setBrush(theme::selection_bg);
    p.drawRoundedRect(line, 5, 5);
  }
  float cy = static_cast<float>(line.center().y());
  Badge b = badge_of(it.kind);
  QRectF br(line.x() + 8, cy - 8, 16, 16);
  if (!b.icon.isEmpty()) {
    p.drawPixmap(QPointF(br.x() + 1, br.y() + 1), theme::icon(b.icon, b.color, 14));
  } else {
    p.setPen(Qt::NoPen);
    p.setBrush(theme::with_alpha(b.color, 0.18f));
    p.drawRoundedRect(br, 4, 4);
    QFont f = theme::mono_font();
    f.setPixelSize(11);
    f.setBold(true);
    p.setFont(f);
    p.setPen(b.color);
    p.drawText(br, Qt::AlignCenter, b.letter);
  }
  QFont ui = theme::ui_font();
  QFont hit = ui;
  hit.setBold(true);
  QFontMetricsF fm(ui), fh(hit);
  float x = static_cast<float>(br.right()) + 10;
  float right = static_cast<float>(line.right()) - 8;
  QList<uint> cps = QString::fromStdString(it.text).toUcs4();
  std::vector<bool> lit(static_cast<size_t>(cps.size()), false);
  for (int k : it.pos)
    if (k >= 0 && k < cps.size()) lit[static_cast<size_t>(k)] = true;
  // The text in runs of lit and not.
  qsizetype k = 0;
  while (k < cps.size() && x < right) {
    bool on = lit[static_cast<size_t>(k)];
    qsizetype start = k;
    while (k < cps.size() && lit[static_cast<size_t>(k)] == on) k++;
    QString run = QString::fromUcs4(reinterpret_cast<const char32_t*>(cps.constData() + start), k - start);
    p.setFont(on ? hit : ui);
    p.setPen(on ? theme::accent.lighter(135) : (selected ? theme::text : theme::text));
    const QFontMetricsF& m = on ? fh : fm;
    float w = static_cast<float>(m.horizontalAdvance(run));
    if (x + w > right) run = m.elidedText(run, Qt::ElideRight, right - x);
    p.drawText(QRectF(x, line.y(), right - x, line.height()), Qt::AlignVCenter, run);
    x += w;
  }
  if (!it.detail.empty() && x + 30 < right) {
    QFont small = ui;
    small.setPixelSize(12);
    p.setFont(small);
    p.setPen(theme::text_disabled);
    QString d = QFontMetricsF(small).elidedText(QString::fromStdString(it.detail), Qt::ElideLeft, right - x - 14);
    p.drawText(QRectF(x + 14, line.y(), right - x - 14, line.height()), Qt::AlignVCenter, d);
  }
}

void PickerPanel::paintEvent(QPaintEvent*) {
  if (!open_) return;
  QPainter p(this);
  p.setRenderHint(QPainter::Antialiasing);
  p.fillRect(rect(), QColor(0, 0, 0, 90));
  QRectF b = box();
  p.setPen(QPen(theme::border_strong, 1));
  p.setBrush(theme::frame_bg);
  p.drawRoundedRect(b, 10, 10);
  // The header: the title, the counts.
  QFont ui = theme::ui_font();
  QFont title = ui;
  title.setBold(true);
  p.setFont(title);
  p.setPen(theme::text);
  p.drawText(QRectF(b.x() + 16, b.y(), b.width() / 2, HEADER), Qt::AlignVCenter, QString::fromStdString(title_));
  QFont small = ui;
  small.setPixelSize(12);
  p.setFont(small);
  p.setPen(theme::text_disabled);
  QString counts = QString("%1 / %2%3").arg(count_).arg(total_).arg(busy_ ? "  …" : "");
  p.drawText(QRectF(b.center().x(), b.y(), b.width() / 2 - 16, HEADER), Qt::AlignVCenter | Qt::AlignRight, counts);
  // The prompt: a Nvim window.
  QRectF pr = prompt_rect();
  p.setPen(QPen(theme::accent, 1));
  p.setBrush(theme::island_bg);
  p.drawRoundedRect(pr, 6, 6);
  p.drawPixmap(QPointF(pr.x() + 10, pr.center().y() - 7), theme::icon("search", theme::text_muted, 14));
  if (auto g = screen_.grid_of(prompt_win_)) {
    GridLook look;
    look.rows = 1;
    look.cols = prompt_cols();
    paint_grid(p, screen_, *g, QPointF(pr.x() + 32, pr.center().y() - cm_.cell_h / 2), cm_, look);
  }
  // The items.
  QRectF l = list_rect();
  p.save();
  p.setClipRect(l);
  if (items_.empty()) {
    p.setFont(ui);
    p.setPen(theme::text_disabled);
    QString words = busy_ ? QString("Looking…") : QString::fromStdString(empty_.empty() ? "Nothing matches." : empty_);
    p.drawText(l.adjusted(16, 12, -16, 0), Qt::AlignTop | Qt::AlignLeft, words);
  }
  int first = std::max(0, static_cast<int>(scroll_ / ROW_H));
  int last = std::min(static_cast<int>(items_.size()), first + static_cast<int>(l.height() / ROW_H) + 2);
  for (int k = first; k < last; k++) {
    QRectF line(l.x(), l.y() + static_cast<float>(k) * ROW_H - scroll_, l.width(), ROW_H);
    if (k == hovered_ && k != selected_) {
      p.setPen(Qt::NoPen);
      p.setBrush(theme::hover_bg);
      p.drawRoundedRect(line, 5, 5);
    }
    paint_item(p, items_[static_cast<size_t>(k)], line, k == selected_);
  }
  p.restore();
  // The preview: its title, a Nvim window on the item's file.
  if (preview_win_) {
    QRectF v = preview_rect();
    p.fillRect(QRectF(l.right() + PAD / 2, l.y(), 1, b.bottom() - l.y() - PAD), theme::border);
    p.setFont(small);
    p.setPen(theme::text_muted);
    p.drawText(QRectF(v.x(), l.y(), v.width(), 24), Qt::AlignVCenter,
               QFontMetricsF(small).elidedText(QString::fromStdString(preview_title_), Qt::ElideLeft, v.width()));
    p.setPen(Qt::NoPen);
    p.setBrush(QColor(rgb(screen_.bg)));
    p.drawRoundedRect(v, 6, 6);
    if (auto g = screen_.grid_of(preview_win_)) {
      p.save();
      p.setClipRect(v.adjusted(4, 4, -4, -4));
      GridLook look;
      auto [cols, rows] = preview_size();
      look.rows = rows;
      look.cols = cols;
      look.cursor = false;
      paint_grid(p, screen_, *g, v.topLeft() + QPointF(6, 4), cm_, look);
      p.restore();
    }
  }
}

void PickerPanel::mousePressEvent(QMouseEvent* e) {
  QPointF at = e->position();
  if (!box().contains(at)) {
    editor_.lua("require('biscide.picker').close()");
    return;
  }
  int k = item_at(at);
  if (k >= 0) editor_.lua("require('biscide.picker').select(...)", {static_cast<int64_t>(k + 1)});
}

void PickerPanel::mouseDoubleClickEvent(QMouseEvent* e) {
  int k = item_at(e->position());
  if (k >= 0) editor_.lua("require('biscide.picker').confirm(...)", {static_cast<int64_t>(k + 1)});
}

void PickerPanel::mouseMoveEvent(QMouseEvent* e) {
  int k = item_at(e->position());
  if (k != hovered_) {
    hovered_ = k;
    update();
  }
}

void PickerPanel::wheelEvent(QWheelEvent* e) {
  QPointF at = e->position();
  QPoint px = e->pixelDelta();
  float dy = px.isNull() ? static_cast<float>(e->angleDelta().y()) / 120.0f * 3 * ROW_H : static_cast<float>(px.y());
  if (dy == 0) return;
  if (preview_win_ && preview_rect().contains(at)) {
    if (auto g = screen_.grid_of(preview_win_)) editor_.mouse("wheel", dy > 0 ? "up" : "down", "", *g, 0, 0);
    return;
  }
  float max = std::max(0.0f, static_cast<float>(items_.size()) * ROW_H - static_cast<float>(list_rect().height()));
  scroll_ = std::clamp(scroll_ - dy, 0.0f, max);
  update();
}

}  // namespace biscide
