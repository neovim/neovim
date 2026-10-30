#include "keys.h"

namespace biscide {

std::string key_notation(int key, Qt::KeyboardModifiers mods, const QString& text) {
  switch (key) {
    case Qt::Key_Shift: case Qt::Key_Control: case Qt::Key_Alt: case Qt::Key_Meta:
    case Qt::Key_AltGr: case Qt::Key_CapsLock: case Qt::Key_NumLock: case Qt::Key_Super_L:
    case Qt::Key_Super_R: case Qt::Key_Hyper_L: case Qt::Key_Hyper_R:
      return {};
    default:
      break;
  }
  bool ctrl = mods & Qt::ControlModifier;
  bool alt = mods & Qt::AltModifier;
  bool shift = mods & Qt::ShiftModifier;
  bool super = mods & Qt::MetaModifier;
  std::string name;
  bool named = true;
  switch (key) {
    case Qt::Key_Escape: name = "Esc"; break;
    case Qt::Key_Return: case Qt::Key_Enter: name = "CR"; break;
    case Qt::Key_Backspace: name = "BS"; break;
    case Qt::Key_Tab: name = "Tab"; break;
    case Qt::Key_Backtab: name = "Tab"; shift = true; break;
    case Qt::Key_Delete: name = "Del"; break;
    case Qt::Key_Insert: name = "Insert"; break;
    case Qt::Key_Up: name = "Up"; break;
    case Qt::Key_Down: name = "Down"; break;
    case Qt::Key_Left: name = "Left"; break;
    case Qt::Key_Right: name = "Right"; break;
    case Qt::Key_Home: name = "Home"; break;
    case Qt::Key_End: name = "End"; break;
    case Qt::Key_PageUp: name = "PageUp"; break;
    case Qt::Key_PageDown: name = "PageDown"; break;
    case Qt::Key_Space: name = "Space"; break;
    default:
      if (key >= Qt::Key_F1 && key <= Qt::Key_F35) {
        name = "F" + std::to_string(key - Qt::Key_F1 + 1);
      } else {
        named = false;
      }
  }
  if (!named) {
    // A character: as typed (shift is part of it), unless Ctrl or Alt.
    if (!ctrl && !alt && !super && !text.isEmpty() && !text.at(0).isNull() && text.at(0).isPrint()) {
      if (text == "<") return "<lt>";
      if (text == "\\") return "<Bslash>";
      return text.toStdString();
    }
    if (key >= Qt::Key_A && key <= Qt::Key_Z) {
      char c = static_cast<char>('a' + (key - Qt::Key_A));
      name = std::string(1, c);
      if (shift && alt && !ctrl) {
        name = std::string(1, static_cast<char>(c - 'a' + 'A'));
        shift = false;
      }
    } else if (key > 0 && key < 0x7f) {
      name = std::string(1, static_cast<char>(key));
      // Shift is part of a symbol already.
      if (!text.isEmpty() && text.at(0).isPrint() && !ctrl) name = text.toStdString();
      shift = false;
    } else if (!text.isEmpty() && text.at(0).isPrint()) {
      name = text.toStdString();
      shift = false;
    } else {
      return {};
    }
    if (name == "<") name = "lt";
    if (name == "\\") name = "Bslash";
    if (name == "|") name = "Bar";
  } else if (name == "Space" && !ctrl && !alt && !super && !shift) {
    return " ";
  }
  std::string m;
  if (ctrl) m += "C-";
  if (alt) m += "A-";
  if (shift) m += "S-";
  if (super) m += "D-";
  if (m.empty() && name.size() == 1) return name;
  return "<" + m + name + ">";
}

}  // namespace biscide
