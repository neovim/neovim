// biscide's colours and fonts: a dark scheme in the manner of JetBrains'
// Islands Dark (the code's own colours are Neovim's: colors/biscide.lua).
#pragma once

#include <QColor>
#include <QFont>
#include <QString>

namespace biscide::theme {

inline const QColor frame_bg{0x26, 0x28, 0x2C};
inline const QColor island_bg{0x19, 0x1A, 0x1C};
inline const QColor editor_bg{0x1E, 0x1F, 0x22};
inline const QColor border{0x33, 0x35, 0x3B};
inline const QColor border_strong{0x43, 0x45, 0x4A};
inline const QColor hover_bg{255, 255, 255, 0x17};
inline const QColor selection_bg{0x2A, 0x43, 0x71};
inline const QColor text{0xD1, 0xD3, 0xD9};
inline const QColor text_muted{0x9F, 0xA2, 0xA8};
inline const QColor text_disabled{0x73, 0x76, 0x7C};
inline const QColor accent{0x38, 0x71, 0xE1};
inline const QColor green{0x6D, 0xB0, 0x83};
inline const QColor error{0xF5, 0x7E, 0x84};
inline const QColor warning{0xD5, 0x96, 0x37};
inline const QColor cyan{0x2A, 0xAC, 0xB8};
inline const QColor violet{0xC7, 0x7D, 0xBB};

constexpr float ui_font_px = 13.0f;
constexpr float mono_font_px = 12.5f;
constexpr float status_h = 26.0f;
constexpr float bar_h = 30.0f;

inline QColor with_alpha(QColor c, float a) {
  c.setAlphaF(a);
  return c;
}

/// The colour of a link of a kind ("call", "parameter", …).
QColor kind_color(const std::string& kind);

/// The first installed of biscide's monospace fonts, and of its UI fonts.
QFont mono_font();
QFont ui_font();

/// An icon of the resources (`:/biscide/icons/<name>.svg`), in `color`.
QPixmap icon(const QString& name, const QColor& color, int px);

}  // namespace biscide::theme
