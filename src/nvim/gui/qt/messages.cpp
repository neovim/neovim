#include "messages.h"

#include <algorithm>

namespace biscide {

namespace {

/// The log's most messages: the oldest go.
constexpr size_t LOG_MAX = 2000;

bool arg_bool(const mp::Array& a, size_t i) { return i < a.size() && a[i].as_bool().value_or(false); }
int64_t arg_int(const mp::Array& a, size_t i, int64_t d = 0) { return i < a.size() ? a[i].int_or(d) : d; }
std::string arg_str(const mp::Array& a, size_t i) { return i < a.size() ? a[i].str_or() : std::string(); }

/// Messages that pass: shown, not logged.
bool passing(const std::string& kind) {
  return kind == "search_cmd" || kind == "search_count" || kind == "completion" || kind == "empty" ||
         kind == "wildlist";
}

}  // namespace

Chunks chunks_from(const mp::Value* content) {
  Chunks out;
  const mp::Array* list = content ? content->as_array() : nullptr;
  if (!list) return out;
  for (auto& c : *list) {
    const mp::Array* t = c.as_array();
    if (!t || t->size() < 2) continue;
    out.push_back({(*t)[0].int_or(0), (*t)[1].str_or()});
  }
  return out;
}

std::string text_of(const Chunks& c) {
  std::string s;
  for (auto& k : c) s += k.text;
  return s;
}

std::vector<Chunks> lines_of(const Chunks& c) {
  std::vector<Chunks> out(1);
  for (auto& k : c) {
    size_t from = 0;
    while (true) {
      size_t nl = k.text.find('\n', from);
      std::string piece = k.text.substr(from, nl == std::string::npos ? std::string::npos : nl - from);
      if (!piece.empty()) out.back().push_back({k.attr, piece});
      if (nl == std::string::npos) break;
      out.emplace_back();
      from = nl + 1;
    }
  }
  // A message ends with its last line, not a break.
  while (out.size() > 1 && out.back().empty()) out.pop_back();
  return out;
}

// ---- Messages ----

Message::Level Message::level() const {
  if (kind == "emsg" || kind == "echoerr" || kind == "lua_error" || kind == "rpc_error" || kind == "shell_err")
    return Level::Error;
  if (kind == "wmsg") return Level::Warning;
  if (kind == "list_cmd" || kind == "lua_print" || kind == "shell_out" || kind == "shell_ret" ||
      kind == "shell_cmd" || kind == "verbose")
    return Level::Output;
  return Level::Info;
}

int Message::lines() const { return static_cast<int>(lines_of(content).size()); }

void Messages::add(Message m, bool replace_last, bool append) {
  auto in_log = [this](uint64_t seq) -> Message* {
    for (auto it = log.rbegin(); it != log.rend(); ++it)
      if (it->seq == seq) return &*it;
    return nullptr;
  };
  // A message of the same id (progress) is replaced where it is.
  if (m.id) {
    for (auto& s : shown)
      if (s.id == m.id) {
        uint64_t seq = s.seq;
        m.seq = seq;
        s = m;
        if (auto l = in_log(seq)) *l = m;
        version++;
        return;
      }
  }
  if (append && !shown.empty()) {
    Message& last = shown.back();
    last.content.insert(last.content.end(), m.content.begin(), m.content.end());
    if (auto l = in_log(last.seq)) *l = last;
    version++;
    return;
  }
  if (replace_last && !shown.empty()) {
    m.seq = shown.back().seq;
    shown.back() = m;
    if (auto l = in_log(m.seq)) *l = m;
    version++;
    return;
  }
  m.seq = ++seq_;
  shown.push_back(m);
  if (passing(m.kind)) return;
  if (m.level() == Message::Level::Error) unread_errors++;
  if (m.level() == Message::Level::Warning) unread_warnings++;
  // A command's output longer than a line is read in the panel.
  if (m.typed && m.lines() > 1) want_panel = true;
  log.push_back(std::move(m));
  if (log.size() > LOG_MAX) log.erase(log.begin(), log.begin() + static_cast<long>(log.size() - LOG_MAX));
  version++;
}

bool Messages::apply(const std::string& name, const mp::Array& a) {
  if (name == "msg_show") {
    Message m;
    m.kind = arg_str(a, 0);
    m.content = chunks_from(a.size() > 1 ? &a[1] : nullptr);
    if (a.size() > 5 && !a[5].is_nil()) {
      if (auto s = a[5].as_str()) m.id = *s;
      else m.id = std::to_string(a[5].int_or(0));
    }
    m.typed = arg_str(a, 6) == "typed_cmd";
    m.at = QDateTime::currentDateTime();
    add(std::move(m), arg_bool(a, 2), arg_bool(a, 4));
  } else if (name == "msg_clear") {
    shown.clear();
  } else if (name == "msg_showmode") {
    showmode = chunks_from(a.size() > 0 ? &a[0] : nullptr);
  } else if (name == "msg_showcmd") {
    showcmd = chunks_from(a.size() > 0 ? &a[0] : nullptr);
  } else if (name == "msg_history_show") {
    want_panel = true;
  } else if (name == "msg_history_clear") {
    clear_log();
  } else if (name != "msg_ruler") {
    return false;
  }
  return true;
}

void Messages::clear_log() {
  log.clear();
  read();
  version++;
}

// ---- The command line ----

bool Cmdline::apply(const std::string& name, const mp::Array& a) {
  if (name == "cmdline_show") {
    size_t level = static_cast<size_t>(std::max<int64_t>(1, arg_int(a, 5, 1)));
    levels.resize(level);
    CmdlineLevel& l = levels[level - 1];
    l.content = chunks_from(a.size() > 0 ? &a[0] : nullptr);
    l.pos = arg_int(a, 1);
    l.firstc = arg_str(a, 2);
    l.prompt = arg_str(a, 3);
    l.indent = arg_int(a, 4);
    l.special.clear();
  } else if (name == "cmdline_pos") {
    size_t level = static_cast<size_t>(std::max<int64_t>(1, arg_int(a, 1, 1)));
    if (level <= levels.size()) {
      levels[level - 1].pos = arg_int(a, 0);
      levels[level - 1].special.clear();
    }
  } else if (name == "cmdline_special_char") {
    size_t level = static_cast<size_t>(std::max<int64_t>(1, arg_int(a, 2, 1)));
    if (level <= levels.size()) levels[level - 1].special = arg_str(a, 0);
  } else if (name == "cmdline_hide") {
    levels.resize(static_cast<size_t>(std::max<int64_t>(0, arg_int(a, 0, 1) - 1)));
  } else if (name == "cmdline_block_show") {
    block.clear();
    if (auto lines = a.size() > 0 ? a[0].as_array() : nullptr)
      for (auto& line : *lines) block.push_back(chunks_from(&line));
  } else if (name == "cmdline_block_append") {
    block.push_back(chunks_from(a.size() > 0 ? &a[0] : nullptr));
  } else if (name == "cmdline_block_hide") {
    block.clear();
  } else {
    return false;
  }
  return true;
}

// ---- The popup menu ----

bool Popupmenu::apply(const std::string& name, const mp::Array& a) {
  if (name == "popupmenu_show") {
    items.clear();
    if (auto list = a.size() > 0 ? a[0].as_array() : nullptr)
      for (auto& i : *list) {
        auto t = i.as_array();
        if (!t) continue;
        auto s = [&](size_t k) { return k < t->size() ? (*t)[k].str_or() : std::string(); };
        items.push_back({s(0), s(1), s(2), s(3)});
      }
    selected = static_cast<int>(arg_int(a, 1, -1));
    row = arg_int(a, 2);
    col = arg_int(a, 3);
    grid = arg_int(a, 4);
    shown = true;
  } else if (name == "popupmenu_select") {
    selected = static_cast<int>(arg_int(a, 0, -1));
  } else if (name == "popupmenu_hide") {
    shown = false;
    items.clear();
  } else {
    return false;
  }
  return true;
}

}  // namespace biscide
