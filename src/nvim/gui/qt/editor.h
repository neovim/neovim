// The editor, as the GUI's widgets call it: keys, the mouse, Lua, Ex
// commands, straight into Nvim (gui/bridge.h), queued to its thread.
#pragma once

#include "value.h"

#include <string>

namespace biscide {

class Editor {
 public:
  bool running() const { return true; }
  void input(const std::string& keys);
  void mouse(const std::string& button, const std::string& action, const std::string& mods, int64_t grid,
             int row, int col);
  /// Runs Lua, `...` being `args`.
  void lua(const std::string& code, mp::Array args = {});
  void command(const std::string& cmd);
};

}  // namespace biscide
