// The bridge between Nvim (C) and its built-in GUI (Qt, C++): plain C types
// only, so both sides include it. Nvim's editor runs on the main thread;
// the GUI runs on a thread of its own.
//
// Nvim → GUI (called on the editor thread; the GUI copies what it is given
// before returning): guiq_*.
// GUI → Nvim (callable from any thread; the work is queued to the editor
// thread): gui_*.

#ifndef NVIM_GUI_BRIDGE_H
#define NVIM_GUI_BRIDGE_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/// A value Nvim hands the GUI: an event's arguments, a payload from Lua.
typedef enum {
  kGuiNil,
  kGuiBool,
  kGuiInt,
  kGuiFloat,
  kGuiString,
  kGuiArray,
  kGuiMap,
} GuiValueType;

typedef struct GuiValue GuiValue;
typedef struct GuiPair GuiPair;

struct GuiValue {
  GuiValueType type;
  union {
    bool boolean;
    int64_t integer;
    double floating;
    struct {
      const char *data;
      size_t size;
    } string;
    struct {
      GuiValue *items;
      size_t size;
    } array;
    struct {
      GuiPair *items;
      size_t size;
    } map;
  } data;
};

struct GuiPair {
  GuiValue key;
  GuiValue value;
};

/// Where the GUI's files are, and what to open.
typedef struct {
  const char *progpath;  ///< Nvim's own path.
} GuiStartOptions;

// ---- Nvim → GUI ----

/// Starts the GUI's thread and opens its window; false (with `error`, at
/// most `errlen` bytes) when it cannot.
bool guiq_start(const GuiStartOptions *opts, char *error, size_t errlen);
/// The GUI's thread stopped and joined (Nvim is exiting).
void guiq_stop(void);
/// One UI event (`grid_line`, `win_float_pos`, `flush`, …) and its
/// arguments, as Nvim's UI protocol has them.
void guiq_event(const char *name, const GuiValue *args);
/// A payload biscide's runtime sends the GUI (`vim._gui_send(kind, payload)`).
void guiq_send(const char *kind, const GuiValue *payload);

// ---- GUI → Nvim ----

/// Keys, in Nvim's notation.
void gui_input(const char *keys, size_t len);
/// The mouse on cell `row`, `col` of grid `grid`.
void gui_input_mouse(const char *button, const char *action, const char *modifier, int64_t grid,
                     int64_t row, int64_t col);
/// Runs Lua (`...` are `args`, copied); an error is Nvim's error message.
void gui_exec_lua(const char *code, const GuiValue *args);
/// Runs an Ex command.
void gui_command(const char *cmd);

#ifdef __cplusplus
}
#endif

#endif  // NVIM_GUI_BRIDGE_H
