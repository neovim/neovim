// A key pressed, in Neovim's notation.
#pragma once

#include <QString>
#include <Qt>

#include <string>

namespace biscide {

/// Neovim's notation of a key pressed (`<C-o>`, `x`, `<lt>`, `<S-Tab>`);
/// empty for a modifier alone.
std::string key_notation(int key, Qt::KeyboardModifiers mods, const QString& text);

}  // namespace biscide
