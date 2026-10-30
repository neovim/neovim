#include "screen.h"

namespace biscide {

void Grid::resize(int w, int h) {
  if (w == width && h == height) return;
  std::vector<Cell> next(static_cast<size_t>(std::max(0, w * h)));
  for (int r = 0; r < std::min(h, height); r++)
    for (int c = 0; c < std::min(w, width); c++)
      next[static_cast<size_t>(r * w + c)] = cells[static_cast<size_t>(r * width + c)];
  width = w;
  height = h;
  cells = std::move(next);
}

void Grid::put_line(int row, int col, const mp::Array& data) {
  if (row < 0 || row >= height) return;
  int64_t hl = 0;
  for (auto& item : data) {
    auto a = item.as_array();
    if (!a || a->empty()) continue;
    const std::string text = (*a)[0].str_or();
    if (a->size() > 1) hl = (*a)[1].int_or(hl);
    int64_t repeat = a->size() > 2 ? (*a)[2].int_or(1) : 1;
    for (int64_t k = 0; k < repeat; k++) {
      if (col >= width) return;
      auto& cell = cells[static_cast<size_t>(row * width + col)];
      cell.text = text;
      cell.hl = hl;
      col++;
    }
  }
}

void Grid::scroll(int top, int bot, int left, int right, int rows) {
  bot = std::min(bot, height);
  right = std::min(right, width);
  if (top >= bot || left >= right) return;
  auto copy = [&](int from, int to) {
    for (int c = left; c < right; c++)
      cells[static_cast<size_t>(to * width + c)] = cells[static_cast<size_t>(from * width + c)];
  };
  if (rows > 0) {
    for (int to = top; to < bot - rows; to++) copy(to + rows, to);
  } else {
    for (int to = bot - 1; to >= top - rows; to--) copy(to + rows, to);
  }
}

namespace {

std::optional<uint32_t> color(const mp::Value* v) {
  if (!v) return std::nullopt;
  auto i = v->as_int();
  if (!i || *i < 0) return std::nullopt;
  return static_cast<uint32_t>(*i);
}

int arg_int(const mp::Array& a, size_t i, int64_t d = 0) {
  return i < a.size() ? static_cast<int>(a[i].int_or(d)) : static_cast<int>(d);
}

}  // namespace

bool Screen::apply(const std::string& name, const mp::Array& a) {
  if (name == "flush") return true;
  if (messages.apply(name, a) || cmdline.apply(name, a) || pum.apply(name, a)) return false;
  if (name == "grid_resize") {
    grids[arg_int(a, 0)].resize(arg_int(a, 1), arg_int(a, 2));
  } else if (name == "grid_clear") {
    if (auto it = grids.find(arg_int(a, 0)); it != grids.end())
      for (auto& c : it->second.cells) c = Cell{};
  } else if (name == "grid_destroy") {
    int64_t g = arg_int(a, 0);
    grids.erase(g);
    std::erase_if(windows_, [g](auto& p) { return p.second == g; });
    viewports_.erase(g);
  } else if (name == "grid_line") {
    if (auto it = grids.find(arg_int(a, 0)); it != grids.end() && a.size() > 3)
      if (auto cells = a[3].as_array()) it->second.put_line(arg_int(a, 1), arg_int(a, 2), *cells);
  } else if (name == "grid_cursor_goto") {
    cursor_grid = arg_int(a, 0);
    cursor_row = arg_int(a, 1);
    cursor_col = arg_int(a, 2);
  } else if (name == "grid_scroll") {
    if (auto it = grids.find(arg_int(a, 0)); it != grids.end())
      it->second.scroll(arg_int(a, 1), arg_int(a, 2), arg_int(a, 3), arg_int(a, 4), arg_int(a, 5));
  } else if (name == "win_pos" || name == "win_float_pos" || name == "win_external_pos") {
    int64_t g = arg_int(a, 0);
    auto win = a.size() > 1 ? a[1].as_int() : std::nullopt;
    if (win) {
      std::erase_if(windows_, [g](auto& p) { return p.second == g; });
      windows_[*win] = g;
    }
  } else if (name == "win_close" || name == "win_hide") {
    int64_t g = arg_int(a, 0);
    std::erase_if(windows_, [g](auto& p) { return p.second == g; });
  } else if (name == "win_viewport") {
    Viewport v;
    v.topline = arg_int(a, 2);
    v.botline = arg_int(a, 3);
    v.curline = arg_int(a, 4);
    v.curcol = arg_int(a, 5);
    v.line_count = arg_int(a, 6);
    viewports_[arg_int(a, 0)] = v;
  } else if (name == "hl_attr_define") {
    HlAttr h;
    const mp::Value* m = a.size() > 1 ? &a[1] : nullptr;
    if (m) {
      h.fg = color(m->get("foreground"));
      h.bg = color(m->get("background"));
      h.sp = color(m->get("special"));
      auto flag = [&](const char* k) {
        auto v = m->get(k);
        return v && v->as_bool().value_or(false);
      };
      h.reverse = flag("reverse");
      h.bold = flag("bold");
      h.italic = flag("italic");
      h.underline = flag("underline");
      h.undercurl = flag("undercurl");
      h.strikethrough = flag("strikethrough");
    }
    hl[arg_int(a, 0)] = h;
  } else if (name == "default_colors_set") {
    if (auto c = color(a.size() > 0 ? &a[0] : nullptr)) fg = *c;
    if (auto c = color(a.size() > 1 ? &a[1] : nullptr)) bg = *c;
    if (auto c = color(a.size() > 2 ? &a[2] : nullptr)) sp = *c;
  } else if (name == "mode_info_set") {
    modes_.clear();
    if (auto list = a.size() > 1 ? a[1].as_array() : nullptr) {
      for (auto& m : *list) {
        ModeInfo info;
        auto shape = m.get("cursor_shape");
        std::string s = shape ? shape->str_or() : "";
        info.shape = s == "horizontal" ? CursorShape::Horizontal
                     : s == "vertical" ? CursorShape::Vertical
                                       : CursorShape::Block;
        if (auto p = m.get("cell_percentage")) info.percentage = static_cast<float>(p->int_or(0)) / 100.0f;
        if (auto at = m.get("attr_id")) info.attr = at->int_or(0);
        modes_.push_back(info);
      }
    }
  } else if (name == "mode_change") {
    mode_name = a.size() > 0 ? a[0].str_or() : "";
    mode_ = static_cast<size_t>(arg_int(a, 1));
  } else if (name == "set_title") {
    title = a.size() > 0 ? a[0].str_or() : "";
  }
  return false;
}

std::optional<int64_t> Screen::grid_of(int64_t win) const {
  auto it = windows_.find(win);
  if (it == windows_.end()) return std::nullopt;
  return it->second;
}

const Viewport* Screen::viewport(int64_t grid) const {
  auto it = viewports_.find(grid);
  return it == viewports_.end() ? nullptr : &it->second;
}

void Screen::colors(int64_t id, uint32_t& f, uint32_t& b, uint32_t& s) const {
  auto it = hl.find(id);
  const HlAttr* a = it == hl.end() ? nullptr : &it->second;
  f = a && a->fg ? *a->fg : fg;
  b = a && a->bg ? *a->bg : bg;
  s = a && a->sp ? *a->sp : sp;
  if (a && a->reverse) std::swap(f, b);
}

ModeInfo Screen::mode() const { return mode_ < modes_.size() ? modes_[mode_] : ModeInfo{}; }

}  // namespace biscide
