// UTF-8 text by code points, as the canvas needs it.
#pragma once

#include <QChar>

#include <string>
#include <string_view>
#include <vector>

namespace biscide {

/// A code point of a UTF-8 text and the byte it starts at.
struct Char {
  size_t byte;
  char32_t c;
};

inline size_t utf8_len(unsigned char lead) {
  if (lead < 0x80) return 1;
  if ((lead >> 5) == 0x6) return 2;
  if ((lead >> 4) == 0xE) return 3;
  if ((lead >> 3) == 0x1E) return 4;
  return 1;
}

/// `text`'s code points with their bytes.
inline std::vector<Char> chars(std::string_view text) {
  std::vector<Char> out;
  QString s = QString::fromUtf8(text.data(), static_cast<qsizetype>(text.size()));
  size_t byte = 0;
  for (char32_t c : s.toUcs4()) {
    out.push_back({byte, c});
    byte += byte < text.size() ? utf8_len(static_cast<unsigned char>(text[byte])) : 1;
  }
  return out;
}

/// Whether `c` can be part of an identifier.
inline bool is_word(char32_t c) {
  if (c < 0x80) return (c >= '0' && c <= '9') || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_';
  return QChar::isLetterOrNumber(c);
}

}  // namespace biscide
