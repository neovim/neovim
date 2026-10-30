#include "stage.h"

#include <cmath>

namespace biscide {

namespace {

/// How long a new card fades in, an old one fades out (the left lanes'
/// faster on a move); when, on a move, new cards fade in (the left lanes'
/// once the camera has landed). Cards slide as springs (motion.h).
constexpr float FADE_IN = 0.24f;
constexpr float FADE_OUT = 0.22f;
constexpr float FADE_OUT_LEFT = 0.14f;
constexpr float NEW_DELAY = 0.12f;
constexpr float LEFT_DELAY = 0.42f;
/// How fast a lane's scroll catches up (per second).
constexpr float LANE_SCROLL_RATE = 14.0f;
/// How far the file's other declarations step back.
constexpr float FILE_OPACITY = 0.85f;

bool is_left(Lane l) { return l == Lane::Prev || l == Lane::UsedBy; }

int slot(Lane l) { return static_cast<int>(l); }

}  // namespace

std::string decl_of(const std::string& key) {
  auto at = key.rfind(':');
  return at == std::string::npos ? key : key.substr(0, at);
}

float Stage::column_x(Lane l) const {
  float w = m_.node_w(), gap = m_.column_gap;
  switch (l) {
    case Lane::Prev: return centre_x_ - (w + gap) * 2;
    case Lane::UsedBy: return centre_x_ - (w + gap);
    case Lane::File: return centre_x_;
    case Lane::Uses: return centre_x_ + w + gap;
  }
  return centre_x_;
}

CardMotion Stage::motion_of(const Placed& p) const {
  auto it = motion_.find(p.key);
  return it == motion_.end() ? CardMotion{} : it->second;
}

Drawn Stage::drawn(const Placed& p, float t) const {
  auto [dx, dy] = motion_of(p).offset(t);
  return {p.x + dx, p.y + dy - scroll_[slot(p.lane)], p.w, p.h};
}

float Stage::opacity(const Placed& p, int64_t active, float t) const {
  float fade = motion_of(p).opacity(t);
  return p.lane == Lane::File && p.node != active ? fade * FILE_OPACITY : fade;
}

const Placed* Stage::card(int64_t node, Lane lane) const {
  for (auto& p : cards_)
    if (p.node == node && p.lane == lane) return &p;
  return nullptr;
}

const Placed* Stage::by_decl(const std::string& decl, Lane lane) const {
  for (auto& p : cards_)
    if (p.decl == decl && p.lane == lane) return &p;
  return nullptr;
}

const Placed* Stage::by_key(const std::string& key) const {
  for (auto& p : cards_)
    if (p.key == key) return &p;
  return nullptr;
}

bool Stage::same_cards(const LanesState& s) const {
  if (s.cards.size() != cards_.size()) return false;
  for (auto& c : s.cards) {
    auto* p = by_decl(decl_of(c.key), c.lane);
    if (!p || p->rows != c.rows) return false;
  }
  return true;
}

void Stage::adopt(const LanesState& s) {
  for (auto& c : s.cards)
    for (auto& p : cards_)
      if (p.decl == decl_of(c.key) && p.lane == c.lane) {
        p.node = c.node;
        p.win = c.win;
        p.textoff = c.textoff;
        p.key = c.key;
      }
}

void Stage::clear() {
  cards_.clear();
  ghosts_.clear();
  motion_.clear();
}

Placed Stage::make(const CardInfo& c, float y) const {
  Placed p;
  p.key = c.key;
  p.decl = decl_of(c.key);
  p.node = c.node;
  p.lane = c.lane;
  p.rows = c.rows;
  p.win = c.win;
  p.textoff = c.textoff;
  p.w = m_.node_w();
  p.h = m_.height(c.rows);
  p.x = column_x(c.lane);
  p.y = y;
  return p;
}

void Stage::arrange(const LanesState& s, Arrival how, Lane from, Direction dir, const std::string& old_decl,
                    float t, const std::function<bool(const Drawn&)>& in_view) {
  std::string new_decl;
  if (auto c = s.card(s.active, Lane::File)) new_decl = decl_of(c->key);
  struct Was {
    Placed card;
    Drawn drawn;
    CardMotion motion;
  };
  std::vector<Was> before;
  for (auto& p : cards_) before.push_back({p, drawn(p, t), motion_of(p)});
  // Where the new middle lane lies: where its card is drawn now (else
  // level with the old one).
  float ax = centre_x_, ay = 0;
  const Placed* anchor = nullptr;
  if (how == Arrival::Side) anchor = by_decl(new_decl, from);
  if (how == Arrival::Within) anchor = by_decl(new_decl, Lane::File);
  // Its window the same (its declaration renamed as it was typed in): the
  // same card.
  if (!anchor)
    if (auto c = s.card(s.active, Lane::File))
      for (auto& p : cards_)
        if (p.win == c->win && p.lane == Lane::File) anchor = &p;
  if (anchor) {
    auto d = drawn(*anchor, t);
    ax = d.x;
    ay = d.y;
  } else {
    if (auto old = by_decl(old_decl, Lane::File)) ay = drawn(*old, t).y;
    // Back: the new lanes on the left of the old; forth: on their right.
    float step = 2 * (m_.node_w() + m_.column_gap);
    if (dir == Direction::Back) ax -= step;
    if (dir == Direction::Forward) ax += step;
  }
  centre_x_ = ax;

  // The file stacked from the active card down and up; the side lanes
  // around its middle; the previous one level with it.
  auto lane_cards = [&](const std::vector<int64_t>& ids, Lane l) {
    std::vector<const CardInfo*> out;
    for (auto id : ids)
      if (auto c = s.card(id, l)) out.push_back(c);
    return out;
  };
  std::vector<Placed> next;
  auto file = lane_cards(s.file, Lane::File);
  size_t at = 0;
  for (size_t k = 0; k < file.size(); k++)
    if (file[k]->node == s.active) at = k;
  float y = ay;
  for (size_t k = at; k < file.size(); k++) {
    auto p = make(*file[k], y);
    y += p.h + m_.card_gap;
    next.push_back(p);
  }
  y = ay;
  for (size_t k = at; k-- > 0;) {
    auto p = make(*file[k], 0);
    y -= p.h + m_.card_gap;
    p.y = y;
    next.push_back(p);
  }
  float middle = ay + (file.empty() ? 0 : m_.height(file[at]->rows) / 2);
  for (Lane l : {Lane::UsedBy, Lane::Uses}) {
    auto cs = lane_cards(l == Lane::UsedBy ? s.used_by : s.uses, l);
    float total = -m_.card_gap;
    for (auto c : cs) total += m_.height(c->rows) + m_.card_gap;
    float yy = middle - std::max(total, 0.0f) / 2;
    for (auto c : cs) {
      auto p = make(*c, yy);
      yy += p.h + m_.card_gap;
      next.push_back(p);
    }
  }
  if (s.prev)
    if (auto c = s.card(*s.prev, Lane::Prev)) next.push_back(make(*c, ay));
  cards_ = std::move(next);
  for (float& v : scroll_) v = 0;
  for (float& v : scroll_target_) v = 0;

  // Each card's motion from where it (or its like) was drawn.
  bool is_move = how != Arrival::Within;
  std::vector<bool> used(before.size(), false);
  auto pick = [&](const std::string& decl, const std::function<bool(const Placed&)>& same) -> std::optional<size_t> {
    for (size_t k = 0; k < before.size(); k++)
      if (!used[k] && before[k].card.decl == decl && same(before[k].card)) return k;
    return std::nullopt;
  };
  std::map<std::string, CardMotion> motion;
  for (auto& p : cards_) {
    std::optional<size_t> found;
    // Across to a side lane's card, the file around it is laid out anew
    // (the old one slid along would seem to stand still).
    bool fresh = how == Arrival::Side && p.lane == Lane::File && p.decl != new_decl;
    if (p.decl == old_decl && p.lane == Lane::UsedBy) {
      // The card that was the active one, now among its users: it slides.
      found = pick(p.decl, [](const Placed& q) { return q.lane == Lane::File; });
    } else if (!fresh && !(is_move && is_left(p.lane))) {
      if (how == Arrival::Side && p.decl == new_decl && p.lane == Lane::File)
        found = pick(p.decl, [&](const Placed& q) { return q.lane == from; });
      if (!found) found = pick(p.decl, [&](const Placed& q) { return q.lane == p.lane; });
      if (!found) found = pick(p.decl, [](const Placed&) { return true; });
      // The same window, renamed.
      if (!found)
        for (size_t k = 0; k < before.size(); k++)
          if (!used[k] && before[k].card.win == p.win && before[k].card.lane == p.lane) {
            found = k;
            break;
          }
    }
    CardMotion m;
    m.start = t;
    if (found) {
      used[*found] = true;
      auto& was = before[*found];
      m.dx = was.drawn.x - p.x;
      m.dy = was.drawn.y - p.y;
      m.slides = std::abs(m.dx) > 0.5f || std::abs(m.dy) > 0.5f;
      m.fade = was.motion.fade;
    } else {
      float delay = !is_move ? 0 : is_left(p.lane) ? LEFT_DELAY : NEW_DELAY;
      m.fade = {0, 1, t + delay, FADE_IN};
    }
    motion[p.key] = m;
  }
  for (size_t k = 0; k < before.size(); k++) {
    auto& was = before[k];
    float o = was.motion.opacity(t);
    if (used[k] || o < 0.02f || !in_view(was.drawn)) continue;
    ghosts_.push_back({was.card, was.drawn, {o, 0, t, is_move && is_left(was.card.lane) ? FADE_OUT_LEFT : FADE_OUT}});
  }
  motion_ = std::move(motion);
}

std::optional<Drawn> Stage::new_card(int rows) const {
  const Placed* last = nullptr;
  for (auto& p : cards_)
    if (p.lane == Lane::File && (!last || p.y + p.h > last->y + last->h)) last = &p;
  if (!last) return std::nullopt;
  float y = last->y + last->h + m_.card_gap - scroll_[slot(Lane::File)];
  return Drawn{last->x, y, m_.node_w(), m_.height(rows)};
}

void Stage::scroll(Lane l, float dy, float middle, bool glide) {
  bool any = false;
  float top = 0, bottom = 0;
  for (auto& p : cards_) {
    if (p.lane != l) continue;
    top = any ? std::min(top, p.y) : p.y;
    bottom = any ? std::max(bottom, p.y + p.h) : p.y + p.h;
    any = true;
  }
  float& s = scroll_target_[slot(l)];
  s += dy;
  if (any) s = std::clamp(s, top - middle, std::max(bottom - middle, top - middle));
  if (!glide) scroll_[slot(l)] = s;
}

void Stage::scroll_card_to(const Placed& p, float y) { scroll_target_[slot(p.lane)] = p.y - y; }

void Stage::tick(float t) {
  std::erase_if(ghosts_, [t](const Ghost& g) { return g.fade.done(t); });
  // The lanes' scrolls glide to where they are going.
  float k = 1 - std::exp(-LANE_SCROLL_RATE * std::clamp(t - last_tick_, 0.0f, 0.05f));
  last_tick_ = t;
  for (int l = 0; l < 4; l++) {
    scroll_[l] += (scroll_target_[l] - scroll_[l]) * k;
    if (std::abs(scroll_target_[l] - scroll_[l]) < 0.3f) scroll_[l] = scroll_target_[l];
  }
}

bool Stage::moving(float t) const {
  if (!ghosts_.empty()) return true;
  for (int l = 0; l < 4; l++)
    if (scroll_[l] != scroll_target_[l]) return true;
  for (auto& [_, m] : motion_)
    if (!m.done(t)) return true;
  return false;
}

}  // namespace biscide
