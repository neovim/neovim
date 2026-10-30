// Neovim's screen, as its UI protocol draws it (`ext_linegrid`,
// `ext_multigrid`: a grid per window): the cells and their highlights,
// which window each grid shows and where it is scrolled, the cursor and its
// shape in each mode; and what the GUI shows itself (messages.h): the
// messages, the command line, the popup menu. `apply` takes one redraw
// event.
#pragma once

#include "messages.h"
#include "value.h"

#include <cstdint>
#include <optional>
#include <string>
#include <unordered_map>
#include <vector>

namespace biscide {

struct HlAttr {
  std::optional<uint32_t> fg, bg, sp;
  bool reverse = false, bold = false, italic = false, underline = false, undercurl = false,
       strikethrough = false;
};

struct Cell {
  std::string text = " ";  // empty: a wide character's second half
  int64_t hl = 0;
};

struct Grid {
  int width = 0, height = 0;
  std::vector<Cell> cells;
  const Cell* cell(int row, int col) const {
    if (row < 0 || col < 0 || row >= height || col >= width) return nullptr;
    return &cells[static_cast<size_t>(row * width + col)];
  }
  void resize(int w, int h);
  void put_line(int row, int col, const mp::Array& cells);
  void scroll(int top, int bot, int left, int right, int rows);
};

enum class CursorShape { Block, Horizontal, Vertical };

struct ModeInfo {
  CursorShape shape = CursorShape::Block;
  float percentage = 0;
  int64_t attr = 0;
};

/// Where a window is scrolled (lines from 0) and its cursor.
struct Viewport {
  int64_t topline = 0, botline = 0, curline = 0, curcol = 0, line_count = 0;
};

class Screen {
 public:
  std::unordered_map<int64_t, Grid> grids;
  std::unordered_map<int64_t, HlAttr> hl;
  uint32_t fg = 0xBCBEC4, bg = 0x1E1F22, sp = 0xFF5555;
  int64_t cursor_grid = 0;
  int cursor_row = 0, cursor_col = 0;
  std::string mode_name;
  std::string title;
  Messages messages;
  Cmdline cmdline;
  Popupmenu pum;

  /// Takes a redraw event (`name` and one tuple of its arguments); whether
  /// a batch is whole (`flush`).
  bool apply(const std::string& name, const mp::Array& args);

  std::optional<int64_t> grid_of(int64_t win) const;
  const Viewport* viewport(int64_t grid) const;
  /// A highlight's foreground, background and special colours (reversed
  /// when it says so).
  void colors(int64_t id, uint32_t& f, uint32_t& b, uint32_t& s) const;
  ModeInfo mode() const;

 private:
  std::unordered_map<int64_t, int64_t> windows_;  // window → grid
  std::unordered_map<int64_t, Viewport> viewports_;
  std::vector<ModeInfo> modes_;
  size_t mode_ = 0;
};

}  // namespace biscide
