#include "canvas.h"

#include "card_painter.h"
#include "theme.h"
#include "util.h"

#include <QMouseEvent>
#include <QPainter>
#include <QWheelEvent>

#include <cmath>

namespace biscide {

namespace {

/// How much of the previous lane the view shows (its right part).
constexpr float PREV_SHOWN = 1.0f / 8.0f;
/// The least room above a tall card; the room the history takes.
constexpr float TOP_SHARE = 0.08f;
constexpr float HEAD = 36.0f;
/// The most of the view's height a card takes.
constexpr float CARD_SHARE = 0.9f;
constexpr float FLASH = 0.9f;
/// A card fading below this is not clicked.
constexpr float CLICKABLE = 0.3f;
/// How far the pointer moves before a press is a drag.
constexpr float DRAG_SLOP = 4.0f;
constexpr float WHEEL_PX = 60.0f;
/// How fast a card's scroll catches up (per second), when it is near
/// enough; the rows kept between the cursor and a card's edge.
constexpr float SCROLL_RATE = 18.0f;
constexpr float SCROLL_NEAR = 0.01f;
constexpr int SCROLL_MARGIN = 3;
/// A card this near (screen pixels) to the middle of the view is there.
constexpr float CENTRED_PX = 24.0f;

}  // namespace

Canvas::Canvas(Screen& screen, Editor& editor, QWidget* parent)
    : QWidget(parent), screen_(screen), editor_(editor), stage_(m_) {
  setMouseTracking(true);
  setFocusPolicy(Qt::NoFocus);
  setAttribute(Qt::WA_OpaquePaintEvent);
  m_.cell = cell_metrics(theme::mono_font(), 18);
  clock_.start();
  timer_.setInterval(16);
  connect(&timer_, &QTimer::timeout, this, &Canvas::frame);
}

void Canvas::lua(const std::string& code, mp::Array args) { editor_.lua(code, std::move(args)); }

QSizeF Canvas::view() const {
  return width() < 1 ? QSizeF(1200, 760) : QSizeF(width(), height());
}

PaintContext Canvas::context() const {
  return {screen_, m_, rig_.camera(), st_, view(), cards_focused_, [this](int64_t win) { return scroll_of(win); }};
}

// ---- A card's own scroll ----

float Canvas::scroll_of(int64_t win) const {
  auto it = scrolls_.find(win);
  return it == scrolls_.end() ? 0 : it->second.pos;
}

float Canvas::scroll_max(const Placed& c) const {
  auto grid = screen_.grid_of(c.win);
  auto it = grid ? screen_.grids.find(*grid) : screen_.grids.end();
  if (it == screen_.grids.end()) return 0;
  return static_cast<float>(std::max(0, it->second.height - c.rows));
}

void Canvas::screen_changed() {
  follow_cursor();
  focus_typing();
  update();
}

void Canvas::focus_typing() {
  const std::string& mode = screen_.mode_name;
  bool typing = mode == "insert" || mode == "replace";
  const Placed* card = nullptr;
  if (typing)
    for (auto& c : stage_.cards())
      if (screen_.grid_of(c.win) == screen_.cursor_grid) card = &c;
  if (!card) {
    typing_key_.clear();
    typing_rows_ = -1;
    return;
  }
  if (card->key == typing_key_ && card->rows == typing_rows_) return;
  typing_key_ = card->key;
  typing_rows_ = card->rows;
  // Where it lies once it has slid into place.
  Drawn d{card->x, card->y - stage_.lane_scroll_target(card->lane), card->w, card->h};
  rig_.glide(centred_on(d), CameraRig::Mode::Follow, now());
  run();
}

void Canvas::follow_cursor() {
  // The cards' windows may have grown or shrunk.
  for (auto& c : stage_.cards())
    if (auto it = scrolls_.find(c.win); it != scrolls_.end())
      it->second.target = std::clamp(it->second.target, 0.0f, scroll_max(c));
  if (screen_.cursor_grid == seen_cursor_grid_ && screen_.cursor_row == seen_cursor_row_) return;
  seen_cursor_grid_ = screen_.cursor_grid;
  seen_cursor_row_ = screen_.cursor_row;
  for (auto& c : stage_.cards()) {
    if (screen_.grid_of(c.win) != screen_.cursor_grid) continue;
    float max = scroll_max(c);
    Scroll& s = scrolls_[c.win];
    float margin = static_cast<float>(std::min(SCROLL_MARGIN, c.rows / 4));
    float row = static_cast<float>(screen_.cursor_row);
    if (row < s.target + margin) s.target = row - margin;
    if (row > s.target + static_cast<float>(c.rows) - 1 - margin) s.target = row - static_cast<float>(c.rows) + 1 + margin;
    s.target = std::clamp(s.target, 0.0f, max);
    if (s.target != s.pos) run();
    return;
  }
}

bool Canvas::step_scrolls(float dt) {
  bool moving = false;
  float k = 1 - std::exp(-SCROLL_RATE * dt);
  for (auto& [_, s] : scrolls_) {
    if (s.pos == s.target) continue;
    s.pos += (s.target - s.pos) * k;
    if (std::abs(s.target - s.pos) < SCROLL_NEAR) s.pos = s.target;
    moving = moving || s.pos != s.target;
  }
  return moving;
}

// ---- The camera's views ----

std::pair<float, float> Canvas::frame_x() const {
  float vw = static_cast<float>(view().width());
  float w = m_.node_w();
  float left = stage_.column_x(Lane::Prev) + w * (1 - PREV_SHOWN);
  float right = stage_.column_x(Lane::Uses) + w + m_.column_gap / 2;
  float span = right - left;
  float zoom = std::clamp(vw / span, ZOOM_MIN, ZOOM_MAX);
  return {left - std::max(vw / zoom - span, 0.0f) / 2, zoom};
}

int Canvas::max_rows() const {
  float vw = static_cast<float>(view().width()), vh = static_cast<float>(view().height());
  float w = m_.node_w();
  float span = w * (3 + PREV_SHOWN) + m_.column_gap * 3.5f;
  float zoom = std::clamp(vw / span, ZOOM_MIN, ZOOM_MAX);
  return std::max(3, static_cast<int>(std::floor((vh * CARD_SHARE / zoom - m_.bars()) / m_.line_h())));
}

/// The lanes framed across, the active card in the middle of the view's
/// height (a tall one near its top).
Camera Canvas::framing(const Drawn& active) const {
  float vh = static_cast<float>(view().height());
  auto [x, zoom] = frame_x();
  float room = vh - HEAD;
  float top = HEAD + std::max((room - active.h * zoom) / 2, room * TOP_SHARE);
  return {x, active.y - top / zoom, zoom};
}

/// A card in the view's middle, the room above it as the room below (one
/// taller than the view: its top under the history), at the lanes' zoom.
Camera Canvas::centred_on(const Drawn& d) const {
  QSizeF v = view();
  float zoom = frame_x().second;
  float room = static_cast<float>(v.height()) - HEAD;
  float top = HEAD + std::max((room - d.h * zoom) / 2, 0.0f);
  return {d.x + d.w / 2 - static_cast<float>(v.width()) / 2 / zoom, d.y - top / zoom, zoom};
}

float Canvas::view_middle() const {
  float vh = static_cast<float>(view().height());
  return rig_.camera().to_world(0, HEAD + (vh - HEAD) / 2).second;
}

/// Framing the lanes, the view across is kept on them (the window resized,
/// the cards' width changed): only up and down is free.
void Canvas::hold_frame() {
  if (rig_.mode() != CameraRig::Mode::Frame || rig_.gliding() || stage_.cards().empty()) return;
  Camera cam = rig_.camera();
  auto [x, zoom] = frame_x();
  if (std::abs(zoom - cam.zoom) > 1e-6f) {
    float middle = view_middle();
    cam.zoom = zoom;
    cam.oy = middle - static_cast<float>(view().height()) / 2 / zoom;
  }
  cam.ox = x;
  rig_.jump(cam, CameraRig::Mode::Frame);
}

/// The camera onto what it watches: the card the state says to follow
/// (the card cursor's), else the lanes around the active card.
void Canvas::aim(bool glide) {
  float t = now();
  const Placed* active = stage_.card(st_.active, Lane::File);
  if (!active) return;
  std::optional<Drawn> target;
  if (st_.follow == "new") {
    target = stage_.new_card(st_.new_rows);
  } else if (auto p = stage_.by_key(st_.follow); p && p != active) {
    target = stage_.drawn(*p, t);
    flash_ = std::pair{p->key, t};
  }
  Camera to = target ? centred_on(*target) : framing(stage_.drawn(*active, t));
  auto mode = target ? CameraRig::Mode::Follow : CameraRig::Mode::Frame;
  if (glide) {
    rig_.glide(to, mode, t);
  } else {
    rig_.jump(to, mode);
  }
  run();
}

// ---- The state, as the editor tells it ----

void Canvas::set_card_cols(int cols) {
  m_.cols = static_cast<float>(cols);
  emit view_changed();
  update();
}

void Canvas::set_state(LanesState s) {
  float t = now();
  bool had_lanes = st_.valid && !stage_.cards().empty();
  std::string old_decl, new_decl;
  if (had_lanes)
    if (auto a = stage_.card(st_.active, Lane::File)) old_decl = a->decl;
  if (s.valid)
    if (auto c = s.card(s.active, Lane::File)) new_decl = decl_of(c->key);
  // The same card's window (renamed as it was typed in) is no change.
  bool same_window = false;
  if (had_lanes && s.valid)
    if (auto a = stage_.card(st_.active, Lane::File))
      if (auto c = s.card(s.active, Lane::File)) same_window = a->win == c->win;
  bool active_changed = !had_lanes || (new_decl != old_decl && !same_window);
  bool centre = s.centre != seen_centre_;
  bool focus = s.focus != seen_focus_;
  seen_centre_ = s.centre;
  seen_focus_ = s.focus;
  st_ = std::move(s);
  if (!st_.valid) {
    stage_.clear();
    update();
    return;
  }
  if (!active_changed && stage_.same_cards(st_)) {
    stage_.adopt(st_);
  } else {
    Arrival how = Arrival::Within;
    Lane from = Lane::File;
    Direction dir = Direction::None;
    if (had_lanes && active_changed) std::tie(how, from, dir) = arrival(new_decl);
    stage_.arrange(st_, how, from, dir, old_decl, t, [this](const Drawn& d) { return in_view(d); });
  }
  if (!had_lanes) {
    aim(false);
  } else if (centre || focus || active_changed) {
    aim(true);
  }
  // Typed in, the card grew or shrank: the camera on it again.
  focus_typing();
  run();
  update();
}

/// How the new active card came, as biscide says: from the card picked (in
/// the lane it was picked in, though the file lane has it too), else back
/// or forth; a jump to a card in view goes to it.
std::tuple<Arrival, Lane, Direction> Canvas::arrival(const std::string& new_decl) const {
  Direction dir = st_.arrival_dir == "back"      ? Direction::Back
                  : st_.arrival_dir == "forward" ? Direction::Forward
                                                 : Direction::None;
  if (st_.arrival_how == "side" && !st_.arrival_from.empty()) {
    Lane l = lane_of(st_.arrival_from);
    if (stage_.by_decl(new_decl, l)) return {l == Lane::File ? Arrival::Within : Arrival::Side, l, dir};
  }
  if (st_.arrival_how == "within" && stage_.by_decl(new_decl, Lane::File))
    return {Arrival::Within, Lane::File, dir};
  // Back: the previous card first; forth: what it uses first.
  std::initializer_list<Lane> order = dir == Direction::Back
                                          ? std::initializer_list<Lane>{Lane::Prev, Lane::UsedBy, Lane::Uses}
                                          : std::initializer_list<Lane>{Lane::Uses, Lane::UsedBy, Lane::Prev};
  for (Lane l : order)
    if (stage_.by_decl(new_decl, l)) return {Arrival::Side, l, dir};
  if (stage_.by_decl(new_decl, Lane::File)) return {Arrival::Within, Lane::File, dir};
  return {Arrival::Jump, Lane::File, dir};
}

void Canvas::set_cards_focused(bool focused) {
  cards_focused_ = focused;
  update();
}

std::optional<QRectF> Canvas::cell_rect(int64_t grid, int row, int col) const {
  float t = now();
  for (auto& c : stage_.cards()) {
    if (screen_.grid_of(c.win) != grid) continue;
    Drawn d = stage_.drawn(c, t);
    const Camera& cam = rig_.camera();
    auto [x, y] = cam.to_screen(d.x + m_.pad + m_.cell.cell_w * static_cast<float>(col),
                                d.y + m_.title_h + m_.pad + m_.line_h() * (static_cast<float>(row) - scroll_of(c.win)));
    return QRectF(x, y, m_.cell.cell_w * cam.zoom, m_.line_h() * cam.zoom);
  }
  return std::nullopt;
}

// ---- The frames ----

void Canvas::run() {
  if (!timer_.isActive()) {
    last_frame_ = now();
    timer_.start();
  }
}

void Canvas::frame() {
  float t = now();
  bool camera = rig_.tick(t);
  stage_.tick(t);
  bool scrolling = step_scrolls(std::clamp(t - last_frame_, 0.0f, 0.05f));
  last_frame_ = t;
  update();
  bool flashing = flash_ && t - flash_->second < FLASH;
  if (!camera && !stage_.moving(t) && !flashing && !scrolling) timer_.stop();
}

void Canvas::resizeEvent(QResizeEvent*) {
  emit view_changed();
  if (rig_.mode() == CameraRig::Mode::Follow) aim(false);
}

bool Canvas::in_view(const Drawn& d) const {
  QSizeF v = view();
  const Camera& cam = rig_.camera();
  auto [sx, sy] = cam.to_screen(d.x, d.y);
  return sx < v.width() && sy < v.height() && sx + d.w * cam.zoom > 0 && sy + d.h * cam.zoom > 0;
}

void Canvas::paintEvent(QPaintEvent*) {
  hold_frame();

  QPainter p(this);
  p.setRenderHint(QPainter::Antialiasing);
  p.setRenderHint(QPainter::TextAntialiasing);
  p.fillRect(rect(), theme::island_bg);
  float t = now();
  PaintContext c = context();
  paint_dots(p, c);
  paint_curves(p, c, stage_, t);
  for (auto& g : stage_.ghosts()) {
    float o = g.fade.at(t);
    if (o <= 0.01f || !in_view(g.drawn)) continue;
    CardLook look;
    look.ghost = true;
    look.opacity = o;
    paint_card(p, c, g.card, g.drawn, look);
  }
  bool flashing = flash_ && t - flash_->second < FLASH;
  for (auto& card : stage_.cards()) {
    Drawn d = stage_.drawn(card, t);
    float o = stage_.opacity(card, st_.active, t);
    if (o <= 0.01f || !in_view(d)) continue;
    CardLook look;
    look.active = card.lane == Lane::File && card.node == st_.active;
    look.cursor = st_.cursor && st_.cursor->first == card.node && st_.cursor->second == card.lane;
    look.hovered = hovered_ == card.key || (flashing && flash_->first == card.key);
    look.missing = card.node < 0;
    look.opacity = o;
    paint_card(p, c, card, d, look);
  }
  if (auto n = stage_.new_card(st_.new_rows); n && in_view(*n)) paint_new_card(p, c, *n);
  if (!st_.valid) {
    p.setPen(theme::text_disabled);
    p.setFont(theme::ui_font());
    QString words = st_.building ? "Reading the program: every Go and Rust file of the project…"
                                 : (st_.notice.empty() ? "Starting…" : QString::fromStdString(st_.notice));
    p.drawText(QRectF(overlays_.left() + 14, 24, width() - 48, 40), Qt::AlignLeft | Qt::AlignTop, words);
  }
  overlays_.paint(p, c);
}

// ---- The mouse ----

const Placed* Canvas::hit(QPointF at) const {
  auto [wx, wy] = rig_.camera().to_world(static_cast<float>(at.x()), static_cast<float>(at.y()));
  float t = now();
  for (auto& p : stage_.cards())
    if (stage_.opacity(p, st_.active, t) >= CLICKABLE && stage_.drawn(p, t).contains(wx, wy)) return &p;
  return nullptr;
}

std::optional<Lane> Canvas::lane_at(float x) const {
  float w = rig_.camera().to_world(x, 0).first;
  for (Lane l : {Lane::Prev, Lane::UsedBy, Lane::File, Lane::Uses}) {
    float left = stage_.column_x(l);
    if (w >= left - m_.column_gap / 2 && w <= left + m_.node_w() + m_.column_gap / 2) return l;
  }
  return std::nullopt;
}

std::optional<std::pair<int, int>> Canvas::cell_at(const Placed& c, QPointF at) const {
  auto [wx, wy] = rig_.camera().to_world(static_cast<float>(at.x()), static_cast<float>(at.y()));
  Drawn d = stage_.drawn(c, now());
  float x = wx - d.x - m_.pad, y = wy - d.y - m_.title_h - m_.pad;
  if (x < 0 || y < 0 || y >= m_.line_h() * static_cast<float>(c.rows)) return std::nullopt;
  // The row of its window: the card is scrolled in it.
  int row = static_cast<int>(y / m_.line_h() + scroll_of(c.win)), col = static_cast<int>(x / m_.cell.cell_w);
  if (col >= static_cast<int>(m_.cols)) return std::nullopt;
  return std::pair{row, col};
}

std::string Canvas::word_at(const Placed& c, QPointF at) const {
  auto cell = cell_at(c, at);
  auto grid = screen_.grid_of(c.win);
  if (!cell || !grid) return {};
  std::string row = grid_row_text(screen_, *grid, cell->first);
  auto cs = chars(row);
  size_t k = static_cast<size_t>(cell->second);
  if (k >= cs.size() || !is_word(cs[k].c)) return {};
  size_t a = k, b = k;
  while (a > 0 && is_word(cs[a - 1].c)) a--;
  while (b < cs.size() && is_word(cs[b].c)) b++;
  return row.substr(cs[a].byte, (b < cs.size() ? cs[b].byte : row.size()) - cs[a].byte);
}

/// Card `c` brought beside the point `at` (its title level with it), all
/// of it in view as far as it fits: its lane scrolls there.
void Canvas::bring(const Placed& c, QPointF at) {
  Camera cam = rig_.target();
  float vh = static_cast<float>(view().height());
  float top = cam.oy + HEAD / cam.zoom, bottom = cam.oy + vh / cam.zoom;
  float y = cam.to_world(static_cast<float>(at.x()), static_cast<float>(at.y())).second - m_.title_h / 2;
  y = std::max(top, std::min(y, bottom - c.h - 8 / cam.zoom));
  stage_.scroll_card_to(c, y);
  run();
}

bool Canvas::on_new_card(QPointF at) const {
  auto n = stage_.new_card(st_.new_rows);
  if (!n) return false;
  auto [wx, wy] = rig_.camera().to_world(static_cast<float>(at.x()), static_cast<float>(at.y()));
  return n->contains(wx, wy);
}

/// A press on what floats over the stage; whether it took it.
bool Canvas::press_overlay(QPointF at) {
  if (auto k = overlays_.history_at(at)) {
    lua("require('biscide').history_to(...)", {static_cast<int64_t>(*k)});
    return true;
  }
  if (overlays_.on_key(at)) {
    if (!overlays_.show_key || overlays_.on_key_close(at)) overlays_.show_key = !overlays_.show_key;
    update();
    return true;
  }
  return false;
}

void Canvas::mousePressEvent(QMouseEvent* e) {
  QPointF at = e->position();
  press_ = {};
  if (e->button() != Qt::LeftButton || press_overlay(at)) return;
  const Placed* c = hit(at);
  if (c && c->lane == Lane::File && c->node == st_.active) {
    // The active card's code is Nvim's: its cursor goes there.
    auto cell = cell_at(*c, at);
    auto grid = screen_.grid_of(c->win);
    if (cell && grid) {
      editor_.mouse("left", "press", "", *grid, cell->first, cell->second);
      press_ = Press::on_nvim(at, *grid, *cell);
      // A name its uses lane shows: the card cursor onto that card, and
      // the card brought beside the name (its lane scrolls; the camera
      // stays).
      std::string word = word_at(*c, at);
      for (auto u : st_.uses)
        if (auto n = st_.node(u); n && !word.empty() && n->short_name == word) {
          lua("require('biscide').mark(...)", {u, std::string("uses"), true});
          if (auto used = stage_.card(u, Lane::Uses)) bring(*used, at);
          break;
        }
      return;
    }
  }
  if (!c && on_new_card(at)) {
    lua("require('biscide').new()");
    return;
  }
  press_ = Press::on_card(at, c ? c->key : "", lane_at(static_cast<float>(at.x())));
}

void Canvas::mouseMoveEvent(QMouseEvent* e) {
  QPointF at = e->position();
  bool held = e->buttons() & Qt::LeftButton;
  switch (held ? press_.kind : Press::Kind::None) {
    case Press::Kind::Nvim: {
      // A drag selects, from the cell pressed; staying on a cell is no drag.
      const Placed* c = stage_.card(st_.active, Lane::File);
      auto cell = c ? cell_at(*c, at) : std::nullopt;
      if (cell && *cell != press_.cell && press_.grid == screen_.grid_of(c->win).value_or(-1)) {
        press_.cell = *cell;
        editor_.mouse("left", "drag", "", press_.grid, cell->first, cell->second);
      }
      return;
    }
    case Press::Kind::Card:
    case Press::Kind::Lane: {
      QPointF moved = at - press_.at;
      if (!press_.dragged && std::hypot(moved.x(), moved.y()) < DRAG_SLOP) return;
      if (!press_.dragged) press_.at = at;
      press_.dragged = true;
      // The lane dragged moves, up and down only.
      if (press_.lane)
        stage_.scroll(*press_.lane, -static_cast<float>(at.y() - press_.at.y()) / rig_.camera().zoom, view_middle(),
                      false);
      press_.at = at;
      update();
      return;
    }
    case Press::Kind::None:
      break;
  }
  const Placed* c = hit(at);
  std::string h = c ? c->key : "";
  if (h != hovered_) {
    hovered_ = h;
    update();
  }
}

void Canvas::mouseReleaseEvent(QMouseEvent*) {
  Press done = press_;
  press_ = {};
  switch (done.kind) {
    case Press::Kind::Nvim:
      // Released where it was last: a tap is no selection.
      editor_.mouse("left", "release", "", done.grid, done.cell.first, done.cell.second);
      return;
    case Press::Kind::Card:
      if (done.dragged) return;
      // A tap on a card: the card cursor on it.
      if (auto p = stage_.by_key(done.card)) lua("require('biscide').mark(...)", {p->node, std::string(lane_name(p->lane))});
      return;
    default:
      return;
  }
}

void Canvas::mouseDoubleClickEvent(QMouseEvent* e) {
  QPointF at = e->position();
  const Placed* c = hit(at);
  // On the active card a double click is no selection: Nvim does not hear
  // it. On another card, it becomes the active one.
  if (!c || (c->lane == Lane::File && c->node == st_.active)) return;
  press_ = {};
  lua("require('biscide').activate(...)", {c->node, std::string(lane_name(c->lane))});
}

void Canvas::wheelEvent(QWheelEvent* e) {
  QPointF at = e->position();
  QPoint px = e->pixelDelta();
  float dy = px.isNull() ? static_cast<float>(e->angleDelta().y()) / 120.0f * WHEEL_PX : static_cast<float>(px.y());
  if (dy == 0) return;
  // Over a card whose code is longer than it shows: it is brought into view
  // in its lane first (the lane scrolls it to the middle, a tall one to
  // the top, all of it seen); then it scrolls, smoothly; at its end, what
  // is left of the scroll goes on to its lane.
  if (const Placed* c = hit(at)) {
    float max = scroll_max(*c);
    Scroll* scroll = max > 0 ? &scrolls_[c->win] : nullptr;
    // It still scrolls this way (at its end, the lane does: no centring).
    bool scrolls = scroll && (dy < 0 ? scroll->target < max : scroll->target > 0);
    if (scrolls) {
      // Where its top goes, the camera where it is going: the middle of the
      // view (a tall card's top near the view's top).
      Camera cam = rig_.target();
      Drawn d = stage_.drawn(*c, now());
      float y = cam.oy + (d.y - centred_on(d).oy);
      if (std::abs((c->y - y) - stage_.lane_scroll_target(c->lane)) * cam.zoom > CENTRED_PX) {
        stage_.scroll_card_to(*c, y);
        run();
        return;
      }
      Scroll& s = *scroll;
      float row_px = m_.line_h() * rig_.camera().zoom;
      float want = s.target - dy / row_px;
      s.target = std::clamp(want, 0.0f, max);
      run();
      dy = -(want - s.target) * row_px;
      if (std::abs(dy) < 0.5f) return;
    }
  }
  if (auto l = lane_at(static_cast<float>(at.x()))) {
    stage_.scroll(*l, -dy / rig_.camera().zoom, view_middle());
    run();
  }
}

}  // namespace biscide
