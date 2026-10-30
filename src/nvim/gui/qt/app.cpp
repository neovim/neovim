// The built-in GUI's side of the bridge (gui/bridge.h): Qt on a thread of
// its own, the editor on Nvim's main thread. Nvim's UI events arrive on the
// editor's thread and are copied into a batch; at each `flush` the batch
// goes to the GUI's thread, which paints it. What the GUI asks of the
// editor (keys, the mouse, Lua, commands) goes the other way, queued to the
// editor's loop by gui/gui.c.

#include "editor.h"
#include "nvim/gui/bridge.h"
#include "theme.h"
#include "value.h"
#include "window.h"

#include <QApplication>
#include <QMetaObject>
#include <QPointer>
#include <QTimer>

#include <atomic>
#include <condition_variable>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <memory>
#include <mutex>
#include <thread>
#include <utility>
#include <vector>

// The resources (icons) of this static library, registered by hand.
static void init_resources() { Q_INIT_RESOURCE(resources); }

namespace biscide {

namespace {

/// Converts a Value back to the bridge's, for the Lua the GUI runs; the
/// strings and lists live in `keep` until the call returns.
struct BridgeBuilder {
  std::vector<std::unique_ptr<GuiValue[]>> arrays;
  std::vector<std::unique_ptr<GuiPair[]>> maps;

  GuiValue build(const mp::Value& v) {
    GuiValue g{};
    std::visit(
        [&](auto&& x) {
          using T = std::decay_t<decltype(x)>;
          if constexpr (std::is_same_v<T, std::monostate>) {
            g.type = kGuiNil;
          } else if constexpr (std::is_same_v<T, bool>) {
            g.type = kGuiBool;
            g.data.boolean = x;
          } else if constexpr (std::is_same_v<T, int64_t> || std::is_same_v<T, uint64_t>) {
            g.type = kGuiInt;
            g.data.integer = static_cast<int64_t>(x);
          } else if constexpr (std::is_same_v<T, double>) {
            g.type = kGuiFloat;
            g.data.floating = x;
          } else if constexpr (std::is_same_v<T, std::string>) {
            g.type = kGuiString;
            g.data.string.data = x.data();
            g.data.string.size = x.size();
          } else if constexpr (std::is_same_v<T, mp::Array>) {
            auto items = std::make_unique<GuiValue[]>(x.size());
            for (size_t i = 0; i < x.size(); i++) items[i] = build(x[i]);
            g.type = kGuiArray;
            g.data.array.items = items.get();
            g.data.array.size = x.size();
            arrays.push_back(std::move(items));
          } else if constexpr (std::is_same_v<T, mp::Map>) {
            auto items = std::make_unique<GuiPair[]>(x.size());
            for (size_t i = 0; i < x.size(); i++) {
              items[i].key = build(x[i].first);
              items[i].value = build(x[i].second);
            }
            g.type = kGuiMap;
            g.data.map.items = items.get();
            g.data.map.size = x.size();
            maps.push_back(std::move(items));
          }
        },
        v.v);
    return g;
  }
};

/// The GUI: its thread, its window, the batch being gathered.
struct Gui {
  std::thread thread;
  QPointer<Window> window;
  QApplication* app = nullptr;
  Editor editor;
  std::mutex mutex;
  std::condition_variable ready_cv;
  bool ready = false;
  std::string error;
  /// The events since the last flush (only the editor's thread adds).
  std::vector<std::pair<std::string, mp::Array>> batch;
};

Gui* gui = nullptr;

/// `BISCIDE_DEBUG`: what the bridge does, on stderr.
void debug(const char* what) {
  static const bool on = std::getenv("BISCIDE_DEBUG") != nullptr;
  if (on) std::fprintf(stderr, "gui: %s\n", what);
}

/// Runs `fn` on the GUI's thread, with its window (if it is still there).
template <typename Fn>
void on_gui(Fn fn) {
  if (!gui || !gui->window) return;
  QPointer<Window> w = gui->window;
  QMetaObject::invokeMethod(
      w.data(), [w, fn = std::move(fn)]() mutable {
        if (w) fn(*w);
      },
      Qt::QueuedConnection);
}

void run(std::string progpath) {
  static int argc = 1;
  static char* argv[] = {nullptr, nullptr};
  static std::string arg0;
  arg0 = progpath.empty() ? "nvim" : progpath;
  argv[0] = arg0.data();
  QApplication app(argc, argv);
  init_resources();
  app.setApplicationName("biscide");
  app.setFont(theme::ui_font());
  // Closing the window asks the editor (unsaved buffers); it quits Qt.
  app.setQuitOnLastWindowClosed(false);
  Window window(gui->editor);
  window.show();
  // For checking the GUI without a screen: `BISCIDE_SCREENSHOT=out.png` (with
  // QT_QPA_PLATFORM=offscreen) saves the window after a moment, then quits;
  // `BISCIDE_KEYS` are typed first, `BISCIDE_FRAMES` frames saved as they act.
  if (const char* shot = std::getenv("BISCIDE_SCREENSHOT"); shot && *shot) {
    std::string path = shot;
    // Groups of keys separated by "|" are typed 600 ms apart.
    int delay = 2500;
    if (const char* keys = std::getenv("BISCIDE_KEYS"); keys && *keys) {
      QStringList groups = QString::fromUtf8(keys).split('|');
      for (const QString& g : groups) {
        QTimer::singleShot(delay, &window, [k = g.toStdString()] { gui->editor.input(k); });
        delay += 600;
      }
    }
    // `BISCIDE_FRAMES=n`: n frames too, 50 ms apart from the last keys
    // (out-1.png, …): how things move.
    if (const char* frames = std::getenv("BISCIDE_FRAMES"); frames && *frames) {
      QString base = QString::fromStdString(path);
      base.chop(4);
      int n = std::atoi(frames);
      for (int k = 0; k < n; k++)
        QTimer::singleShot(delay - 600 + 20 + k * 50, &window,
                           [&window, f = QString("%1-%2.png").arg(base).arg(k + 1)] { window.grab().save(f); });
    }
    QTimer::singleShot(delay + 1500, &window, [&window, path] {
      window.grab().save(QString::fromStdString(path));
      gui->editor.command("qall!");
    });
  }
  {
    std::lock_guard lock(gui->mutex);
    gui->app = &app;
    gui->window = &window;
    gui->ready = true;
  }
  gui->ready_cv.notify_all();
  app.exec();
  std::lock_guard lock(gui->mutex);
  gui->window = nullptr;
  gui->app = nullptr;
}

/// Whether Qt can open a window here.
bool has_display(std::string& why) {
  const char* platform = std::getenv("QT_QPA_PLATFORM");
  if (platform && *platform) return true;
  const char* x = std::getenv("DISPLAY");
  const char* wl = std::getenv("WAYLAND_DISPLAY");
  if ((x && *x) || (wl && *wl)) return true;
  why = "no display (neither $DISPLAY nor $WAYLAND_DISPLAY is set)";
  return false;
}

}  // namespace

// ---- The editor, as the widgets call it ----

void Editor::input(const std::string& keys) { gui_input(keys.data(), keys.size()); }

void Editor::mouse(const std::string& button, const std::string& action, const std::string& mods, int64_t grid,
                   int row, int col) {
  gui_input_mouse(button.c_str(), action.c_str(), mods.c_str(), grid, row, col);
}

void Editor::lua(const std::string& code, mp::Array args) {
  BridgeBuilder b;
  GuiValue g = b.build(mp::Value(std::move(args)));
  gui_exec_lua(code.c_str(), &g);
}

void Editor::command(const std::string& cmd) { gui_command(cmd.c_str()); }

}  // namespace biscide

using biscide::gui;

// ---- The bridge: Nvim → the GUI ----

extern "C" bool guiq_start(const GuiStartOptions* opts, char* error, size_t errlen) {
  std::string why;
  if (!biscide::has_display(why)) {
    std::snprintf(error, errlen, "%s", why.c_str());
    return false;
  }
  biscide::debug("start");
  gui = new biscide::Gui();
  std::string progpath = opts && opts->progpath ? opts->progpath : "";
  gui->thread = std::thread(biscide::run, progpath);
  std::unique_lock lock(gui->mutex);
  gui->ready_cv.wait(lock, [] { return gui->ready; });
  biscide::debug("ready");
  return true;
}

extern "C" void guiq_stop(void) {
  if (!gui) return;
  biscide::debug("stop");
  {
    std::lock_guard lock(gui->mutex);
    if (gui->window) {
      QPointer<biscide::Window> w = gui->window;
      QApplication* app = gui->app;
      QMetaObject::invokeMethod(
          app, [w, app] {
            if (w) w->quit();
            app->quit();
          },
          Qt::QueuedConnection);
    }
  }
  if (gui->thread.joinable()) gui->thread.join();
  biscide::debug("stopped");
}

extern "C" void guiq_event(const char* name, const GuiValue* args) {
  if (!gui) return;
  biscide::mp::Array copy;
  if (args && args->type == kGuiArray) {
    copy.reserve(args->data.array.size);
    for (size_t i = 0; i < args->data.array.size; i++) copy.push_back(biscide::mp::from_bridge(args->data.array.items[i]));
  }
  if (std::strcmp(name, "flush") == 0) biscide::debug("flush");
  if (std::strcmp(name, "flush") != 0) {
    gui->batch.emplace_back(name, std::move(copy));
    return;
  }
  auto batch = std::make_shared<std::vector<std::pair<std::string, biscide::mp::Array>>>(std::move(gui->batch));
  gui->batch.clear();
  biscide::on_gui([batch](biscide::Window& w) { w.redraw(*batch); });
}

extern "C" void guiq_send(const char* kind, const GuiValue* payload) {
  if (!gui) return;
  // What was drawn before it, first (the windows it names).
  if (!gui->batch.empty()) {
    auto batch = std::make_shared<std::vector<std::pair<std::string, biscide::mp::Array>>>(std::move(gui->batch));
    gui->batch.clear();
    biscide::on_gui([batch](biscide::Window& w) { w.redraw(*batch); });
  }
  auto value = std::make_shared<biscide::mp::Value>(payload ? biscide::mp::from_bridge(*payload) : biscide::mp::Value());
  std::string k = kind;
  biscide::on_gui([k, value](biscide::Window& w) { w.biscide(k, *value); });
}
