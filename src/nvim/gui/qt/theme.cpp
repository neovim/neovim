#include "theme.h"

#include <QFile>
#include <QFontDatabase>
#include <QHash>
#include <QPainter>
#include <QPixmap>
#include <QSvgRenderer>

namespace biscide::theme {

QColor kind_color(const std::string& kind) {
  if (kind == "call") return accent;
  if (kind == "parameter") return cyan;
  if (kind == "field") return violet;
  if (kind == "type_use") return green;
  if (kind == "receiver") return warning;
  return text_muted;
}

namespace {

QString first_installed(std::initializer_list<const char*> names) {
  const QStringList families = QFontDatabase::families();
  for (const char* n : names)
    if (families.contains(QString::fromUtf8(n), Qt::CaseInsensitive)) return QString::fromUtf8(n);
  return {};
}

}  // namespace

QFont mono_font() {
  QString family = first_installed({"JetBrains Mono", "JetBrainsMono Nerd Font", "Fira Code", "Noto Sans Mono",
                                    "DejaVu Sans Mono"});
  QFont f = family.isEmpty() ? QFontDatabase::systemFont(QFontDatabase::FixedFont) : QFont(family);
  f.setStyleHint(QFont::Monospace);
  f.setPixelSize(13);
  f.setKerning(false);
  return f;
}

QFont ui_font() {
  QString family = first_installed({"Inter", "Noto Sans", "Cantarell", "DejaVu Sans"});
  QFont f = family.isEmpty() ? QFontDatabase::systemFont(QFontDatabase::GeneralFont) : QFont(family);
  f.setPixelSize(13);
  return f;
}

QPixmap icon(const QString& name, const QColor& color, int px) {
  static QHash<QString, QPixmap> cache;
  QString key = QString("%1/%2/%3").arg(name).arg(color.rgba()).arg(px);
  if (auto it = cache.find(key); it != cache.end()) return *it;
  QFile f(":/biscide/icons/" + name + ".svg");
  QByteArray svg;
  if (f.open(QIODevice::ReadOnly)) svg = f.readAll();
  // The icons draw in currentColor.
  svg.replace("currentColor", color.name().toUtf8());
  svg.replace("#fff", color.name().toUtf8());
  QSvgRenderer r(svg);
  QPixmap pm(px * 2, px * 2);
  pm.fill(Qt::transparent);
  {
    QPainter p(&pm);
    r.render(&p);
  }
  pm.setDevicePixelRatio(2.0);
  cache.insert(key, pm);
  return pm;
}

}  // namespace biscide::theme
