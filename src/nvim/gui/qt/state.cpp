#include "state.h"

namespace biscide {

Lane lane_of(const std::string& c) {
  if (c == "prev") return Lane::Prev;
  if (c == "used_by") return Lane::UsedBy;
  if (c == "uses") return Lane::Uses;
  return Lane::File;
}

const char* lane_name(Lane l) {
  switch (l) {
    case Lane::Prev: return "prev";
    case Lane::UsedBy: return "used_by";
    case Lane::File: return "file";
    case Lane::Uses: return "uses";
  }
  return "file";
}

namespace {

std::vector<int64_t> ids(const mp::Value* v) {
  std::vector<int64_t> out;
  if (auto a = v ? v->as_array() : nullptr)
    for (auto& e : *a) out.push_back(e.int_or(0));
  return out;
}

std::string str(const mp::Value& v, const char* k) {
  auto f = v.get(k);
  return f ? f->str_or() : std::string();
}

int64_t num(const mp::Value& v, const char* k, int64_t d = 0) {
  auto f = v.get(k);
  return f ? f->int_or(d) : d;
}

}  // namespace

LanesState LanesState::parse(const mp::Value& v) {
  LanesState s;
  if (auto b = v.get("building")) s.building = b->as_bool().value_or(false);
  s.root = str(v, "root");
  s.notice = str(v, "notice");
  auto active = v.get("active");
  if (!active || active->is_nil()) return s;
  s.valid = true;
  s.active = active->int_or(0);
  if (auto p = v.get("prev"); p && !p->is_nil()) s.prev = p->int_or(0);
  if (auto l = v.get("lanes")) {
    s.file = ids(l->get("file"));
    s.used_by = ids(l->get("used_by"));
    s.uses = ids(l->get("uses"));
  }
  if (auto cards = v.get("cards"); cards && cards->as_array())
    for (auto& c : *cards->as_array())
      s.cards.push_back({str(c, "key"), num(c, "node"), lane_of(str(c, "column")), num(c, "win"),
                         static_cast<int>(num(c, "rows", 1)), static_cast<int>(num(c, "textoff", 0))});
  if (auto nodes = v.get("nodes"); nodes && nodes->as_map()) {
    for (auto& [k, n] : *nodes->as_map()) {
      NodeInfo info;
      info.id = num(n, "id");
      info.name = str(n, "name");
      info.short_name = str(n, "short");
      info.kind = str(n, "kind");
      info.rel = str(n, "rel");
      info.layer = str(n, "layer");
      info.line = num(n, "line");
      info.lines = num(n, "lines");
      info.used_by = num(n, "used_by");
      info.uses = num(n, "uses");
      s.nodes[info.id] = info;
    }
  }
  if (auto links = v.get("links"); links && links->as_array()) {
    for (auto& l : *links->as_array()) {
      LinkInfo li;
      li.node = num(l, "node");
      li.lane = lane_of(str(l, "column"));
      if (auto ks = l.get("kinds"); ks && ks->as_array())
        for (auto& k : *ks->as_array()) li.kinds.push_back(k.str_or());
      if (auto vi = l.get("violation")) li.violation = vi->as_bool().value_or(false);
      li.row = static_cast<int>(num(l, "row", -1));
      li.vrow = static_cast<int>(num(l, "vrow", -1));
      li.vcol = static_cast<int>(num(l, "vcol", -1));
      li.col = static_cast<int>(num(l, "col", -1));
      s.links.push_back(li);
    }
  }
  if (auto c = v.get("cursor"); c && !c->is_nil()) {
    if (auto n = c->get("new"); n && n->as_bool().value_or(false)) {
      s.cursor_new = true;
    } else {
      s.cursor = std::pair{num(*c, "node"), lane_of(str(*c, "column"))};
    }
  }
  if (auto h = v.get("history")) {
    if (auto names = h->get("names"); names && names->as_array())
      for (auto& n : *names->as_array()) s.history.push_back(n.str_or());
    s.history_at = static_cast<int>(num(*h, "at"));
  }
  if (auto n = v.get("new_card"); n && !n->is_nil()) {
    s.new_win = num(*n, "win");
    s.new_rows = static_cast<int>(num(*n, "rows", 3));
  }
  s.follow = str(v, "follow");
  if (auto a = v.get("arrival"); a && a->as_map()) {
    s.arrival_how = str(*a, "how");
    s.arrival_from = str(*a, "from");
    s.arrival_dir = str(*a, "direction");
  }
  s.centre = num(v, "centre");
  s.focus = num(v, "focus");
  s.declarations = num(v, "declarations");
  return s;
}

const NodeInfo* LanesState::node(int64_t id) const {
  auto it = nodes.find(id);
  return it == nodes.end() ? nullptr : &it->second;
}

const CardInfo* LanesState::card(int64_t node, Lane lane) const {
  for (auto& c : cards)
    if (c.node == node && c.lane == lane) return &c;
  return nullptr;
}

}  // namespace biscide
