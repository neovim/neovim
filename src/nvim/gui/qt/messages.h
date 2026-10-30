// Nvim's messages and command line, as its UI protocol tells them
// (`ext_messages`, `ext_cmdline`, `ext_popupmenu`): the GUI shows them
// itself, not as rows of a grid. The messages are kept in a log (the
// messages panel shows it) and those Nvim shows now (the status line,
// until `msg_clear`); the command line by its levels (the status line shows
// the innermost), with the block of lines typed before it (`:function`);
// the popup menu's items (completion, of the command line too).
#pragma once

#include "value.h"

#include <QDateTime>

#include <cstdint>
#include <optional>
#include <string>
#include <vector>

namespace biscide {

/// A piece of text in one highlight (`hl_attr_define`'s id).
struct Chunk {
  int64_t attr = 0;
  std::string text;
};
using Chunks = std::vector<Chunk>;

/// The chunks' text, joined.
std::string text_of(const Chunks& c);
/// The chunks cut at their line breaks: a list of lines.
std::vector<Chunks> lines_of(const Chunks& c);

struct Message {
  enum class Level { Error, Warning, Output, Info };
  std::string kind;
  Chunks content;
  /// `msg_show`'s id: a message of the same id replaces it.
  std::optional<std::string> id;
  bool typed = false;  ///< from a command typed on the command line
  QDateTime at;
  uint64_t seq = 0;

  Level level() const;
  int lines() const;
};

class Messages {
 public:
  /// Every message (but the passing ones: searches, completion), oldest
  /// first.
  std::vector<Message> log;
  /// The messages Nvim shows now (until `msg_clear`).
  std::vector<Message> shown;
  Chunks showmode, showcmd;
  /// Errors and warnings the log has that the panel has not shown.
  int unread_errors = 0, unread_warnings = 0;
  /// Nvim asked for the panel (`:messages`, a typed command's long output);
  /// the GUI takes it (and clears it).
  bool want_panel = false;
  /// Bumped at each change of the log.
  uint64_t version = 0;

  /// Takes a `msg_*` event; whether it was one.
  bool apply(const std::string& name, const mp::Array& args);
  void clear_log();
  void read() { unread_errors = unread_warnings = 0; }

 private:
  void add(Message m, bool replace_last, bool append);
  uint64_t seq_ = 0;
};

/// A level of the command line (a `<C-r>=` in one makes another).
struct CmdlineLevel {
  Chunks content;
  int64_t pos = 0;  ///< the cursor's byte
  std::string firstc, prompt;
  int64_t indent = 0;
  /// A character being typed in (`<C-v>`, `<C-k>`), shown at the cursor.
  std::string special;
};

class Cmdline {
 public:
  std::vector<CmdlineLevel> levels;
  std::vector<Chunks> block;

  bool active() const { return !levels.empty(); }
  const CmdlineLevel* top() const { return levels.empty() ? nullptr : &levels.back(); }
  /// Takes a `cmdline_*` event; whether it was one.
  bool apply(const std::string& name, const mp::Array& args);
};

/// The popup menu (`ext_popupmenu`): its items, which is selected, where
/// it is anchored (a grid's cell; grid -1: the command line's column).
class Popupmenu {
 public:
  struct Item {
    std::string word, kind, menu, info;
  };
  std::vector<Item> items;
  int selected = -1;
  int64_t row = 0, col = 0, grid = 0;
  bool shown = false;

  bool apply(const std::string& name, const mp::Array& args);
};

/// A chunk list from `msg_show`/`cmdline_show` content (`[attr, text, hl]`
/// tuples).
Chunks chunks_from(const mp::Value* content);

}  // namespace biscide
