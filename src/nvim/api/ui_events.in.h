#ifndef NVIM_API_UI_EVENTS_IN_H
#define NVIM_API_UI_EVENTS_IN_H

// This file is not compiled, just parsed for definitons
#ifdef INCLUDE_GENERATED_DECLARATIONS
#error "don't include this file, include nvim/ui.h"
#endif

#include "nvim/api/private/defs.h"
#include "nvim/func_attr.h"
#include "nvim/ui.h"

void resize(Integer rows, Integer columns);
void clear(void);
void eol_clear(void);
void cursor_goto(Integer row, Integer col);
void mode_info_set(Boolean enabled, Array cursor_styles);
void update_menu(void);
void busy_start(void);
void busy_stop(void);
void mouse_on(void);
void mouse_off(void);
void mode_change(String mode, Integer mode_idx);
void set_scroll_region(Integer top, Integer bot, Integer left, Integer right);
void scroll(Integer count);
void highlight_set(HlAttrs attrs) REMOTE_IMPL BRIDGE_IMPL;
void put(String str);
void bell(void);
void visual_bell(void);
void flush(void) REMOTE_IMPL;
void update_fg(Integer fg);
void update_bg(Integer bg);
void update_sp(Integer sp);
void suspend(void) BRIDGE_IMPL;
void set_title(String title);
void set_icon(String icon);

void popupmenu_show(Array items, Integer selected, Integer row, Integer col) REMOTE_ONLY;
void popupmenu_hide(void) REMOTE_ONLY;
void popupmenu_select(Integer selected) REMOTE_ONLY;
void tabline_update(Tabpage current, Array tabs) REMOTE_ONLY;

#endif  // NVIM_API_UI_EVENTS_IN_H
