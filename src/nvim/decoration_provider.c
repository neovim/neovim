#include <assert.h>
#include <lauxlib.h>
#include <stdint.h>
#include <string.h>

#include "klib/kvec.h"
#include "nvim/api/extmark.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/buffer_defs.h"
#include "nvim/decoration.h"
#include "nvim/decoration_defs.h"
#include "nvim/decoration_provider.h"
#include "nvim/globals.h"
#include "nvim/highlight.h"
#include "nvim/log.h"
#include "nvim/lua/executor.h"
#include "nvim/message.h"
#include "nvim/move.h"
#include "nvim/pos_defs.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "decoration_provider.c.generated.h"
#endif

enum { DP_MAX_ERROR = 3, };

static kvec_t(DecorProvider) decor_providers = KV_INITIAL_VALUE;

#define DECORATION_PROVIDER_INIT(ns_id) (DecorProvider) \
  { ns_id, kDecorProviderDisabled, LUA_NOREF, LUA_NOREF, \
    LUA_NOREF, LUA_NOREF, LUA_NOREF, \
    LUA_NOREF, -1, false, false, 0 }

static void decor_provider_error(DecorProvider *provider, const char *name, const char *msg)
{
  const char *ns_name = describe_ns(provider->ns_id, "(UNKNOWN PLUGIN)");
  ILOG("error in provider %s.%s: %s", ns_name, name, msg);
  msg_schedule_semsg_multiline("Error in decoration provider %s.%s:\n%s", ns_name, name, msg);
}

// Note we pass in a provider index as this function may cause decor_providers providers to be
// reallocated so we need to be careful with DecorProvider pointers
static bool decor_provider_invoke(int provider_idx, const char *name, LuaRef ref, Array args,
                                  bool default_true)
{
  Error err = ERROR_INIT;

  textlock++;
  provider_active = true;
  Object ret = nlua_call_ref(ref, name, args, kRetNilBool, NULL, &err);
  provider_active = false;
  textlock--;

  // We get the provider here via an index in case the above call to nlua_call_ref causes
  // decor_providers to be reallocated.
  DecorProvider *provider = &kv_A(decor_providers, provider_idx);

  if (!ERROR_SET(&err)
      && api_object_to_bool(ret, "provider %s retval", default_true, &err)) {
    provider->error_count = 0;
    return true;
  }

  if (ERROR_SET(&err)) {
    decor_provider_error(provider, name, err.msg);
    provider->error_count++;

    if (provider->error_count >= DP_MAX_ERROR) {
      provider->state = kDecorProviderDisabled;
    }
  }

  api_clear_error(&err);
  api_free_object(ret);
  return false;
}

void decor_providers_invoke_spell(win_T *wp, int start_row, int start_col, int end_row, int end_col)
{
  for (size_t i = 0; i < kv_size(decor_providers); i++) {
    DecorProvider *p = &kv_A(decor_providers, i);
    if (p->state != kDecorProviderDisabled && p->spell_nav != LUA_NOREF) {
      MAXSIZE_TEMP_ARRAY(args, 6);
      ADD_C(args, INTEGER_OBJ(wp->handle));
      ADD_C(args, INTEGER_OBJ(wp->w_buffer->handle));
      ADD_C(args, INTEGER_OBJ(start_row));
      ADD_C(args, INTEGER_OBJ(start_col));
      ADD_C(args, INTEGER_OBJ(end_row));
      ADD_C(args, INTEGER_OBJ(end_col));
      decor_provider_invoke((int)i, "spell", p->spell_nav, args, true);
    }
  }
}

/// For each provider invoke the 'start' callback
///
/// @param[out] providers Decoration providers
/// @param[out] err       Provider err
void decor_providers_start(void)
{
  for (size_t i = 0; i < kv_size(decor_providers); i++) {
    DecorProvider *p = &kv_A(decor_providers, i);
    if (p->state != kDecorProviderDisabled && p->redraw_start != LUA_NOREF) {
      MAXSIZE_TEMP_ARRAY(args, 2);
      ADD_C(args, INTEGER_OBJ((int)display_tick));
      bool active = decor_provider_invoke((int)i, "start", p->redraw_start, args, true);
      kv_A(decor_providers, i).state = active ? kDecorProviderActive : kDecorProviderRedrawDisabled;
    }
  }
}

/// For each provider run 'win'. If result is not false, then collect the
/// 'on_line' callback to call inside win_line
///
/// @param      wp             Window
/// @param      providers      Decoration providers
/// @param[out] line_providers Enabled line providers to invoke in win_line
/// @param[out] err            Provider error
void decor_providers_invoke_win(win_T *wp)
{
  // this might change in the future
  // then we would need decor_state.running_decor_provider just like "on_line" below
  assert(kv_size(decor_state.active) == 0);

  if (kv_size(decor_providers) > 0) {
    validate_botline(wp);
  }
  linenr_T botline = MIN(wp->w_botline, wp->w_buffer->b_ml.ml_line_count);

  for (size_t i = 0; i < kv_size(decor_providers); i++) {
    DecorProvider *p = &kv_A(decor_providers, i);
    if (p->state == kDecorProviderWinDisabled) {
      p->state = kDecorProviderActive;
    }

    if (p->state == kDecorProviderActive && p->redraw_win != LUA_NOREF) {
      MAXSIZE_TEMP_ARRAY(args, 4);
      ADD_C(args, WINDOW_OBJ(wp->handle));
      ADD_C(args, BUFFER_OBJ(wp->w_buffer->handle));
      // TODO(bfredl): we are not using this, but should be first drawn line?
      ADD_C(args, INTEGER_OBJ(wp->w_topline - 1));
      ADD_C(args, INTEGER_OBJ(botline - 1));
      if (!decor_provider_invoke((int)i, "win", p->redraw_win, args, true)) {
        kv_A(decor_providers, i).state = kDecorProviderWinDisabled;
      }
    }
  }
}

/// For each provider invoke the 'line' callback for a given window row.
///
/// @param      wp        Window
/// @param      providers Decoration providers
/// @param      row       Row to invoke line callback for
/// @param[out] has_decor Set when at least one provider invokes a line callback
/// @param[out] err       Provider error
void decor_providers_invoke_line(win_T *wp, int row, bool *has_decor)
{
  decor_state.running_decor_provider = true;
  for (size_t i = 0; i < kv_size(decor_providers); i++) {
    DecorProvider *p = &kv_A(decor_providers, i);
    if (p->state == kDecorProviderActive && p->redraw_line != LUA_NOREF) {
      MAXSIZE_TEMP_ARRAY(args, 3);
      ADD_C(args, WINDOW_OBJ(wp->handle));
      ADD_C(args, BUFFER_OBJ(wp->w_buffer->handle));
      ADD_C(args, INTEGER_OBJ(row));
      if (decor_provider_invoke((int)i, "line", p->redraw_line, args, true)) {
        *has_decor = true;
      } else {
        // return 'false' or error: skip rest of this window
        kv_A(decor_providers, i).state = kDecorProviderWinDisabled;
      }

      hl_check_ns();
    }
  }
  decor_state.running_decor_provider = false;
}

/// For each provider invoke the 'buf' callback for a given buffer.
///
/// @param      buf       Buffer
/// @param      providers Decoration providers
/// @param[out] err       Provider error
void decor_providers_invoke_buf(buf_T *buf)
{
  for (size_t i = 0; i < kv_size(decor_providers); i++) {
    DecorProvider *p = &kv_A(decor_providers, i);
    if (p->state == kDecorProviderActive && p->redraw_buf != LUA_NOREF) {
      MAXSIZE_TEMP_ARRAY(args, 2);
      ADD_C(args, BUFFER_OBJ(buf->handle));
      ADD_C(args, INTEGER_OBJ((int64_t)display_tick));
      decor_provider_invoke((int)i, "buf", p->redraw_buf, args, true);
    }
  }
}

/// For each provider invoke the 'end' callback
///
/// @param      providers   Decoration providers
/// @param      displaytick Display tick
/// @param[out] err         Provider error
void decor_providers_invoke_end(void)
{
  for (size_t i = 0; i < kv_size(decor_providers); i++) {
    DecorProvider *p = &kv_A(decor_providers, i);
    if (p->state != kDecorProviderDisabled && p->redraw_end != LUA_NOREF) {
      MAXSIZE_TEMP_ARRAY(args, 1);
      ADD_C(args, INTEGER_OBJ((int)display_tick));
      decor_provider_invoke((int)i, "end", p->redraw_end, args, true);
      kv_A(decor_providers, i).state = kDecorProviderActive;
    }
  }
  decor_check_to_be_deleted();
}

/// Mark all cached state of per-namespace highlights as invalid. Revalidate
/// current namespace.
///
/// Expensive! Should on be called by an already throttled validity check
/// like highlight_changed() (throttled to the next redraw or mode change)
void decor_provider_invalidate_hl(void)
{
  for (size_t i = 0; i < kv_size(decor_providers); i++) {
    kv_A(decor_providers, i).hl_cached = false;
  }

  if (ns_hl_active) {
    ns_hl_active = -1;
    hl_check_ns();
  }
}

DecorProvider *get_decor_provider(NS ns_id, bool force)
{
  assert(ns_id > 0);
  size_t len = kv_size(decor_providers);
  for (size_t i = 0; i < len; i++) {
    DecorProvider *p = &kv_A(decor_providers, i);
    if (p->ns_id == ns_id) {
      return p;
    }
  }

  if (!force) {
    return NULL;
  }

  DecorProvider *item = &kv_a(decor_providers, len);
  *item = DECORATION_PROVIDER_INIT(ns_id);

  return item;
}

void decor_provider_clear(DecorProvider *p)
{
  if (p == NULL) {
    return;
  }
  NLUA_CLEAR_REF(p->redraw_start);
  NLUA_CLEAR_REF(p->redraw_buf);
  NLUA_CLEAR_REF(p->redraw_win);
  NLUA_CLEAR_REF(p->redraw_line);
  NLUA_CLEAR_REF(p->redraw_end);
  NLUA_CLEAR_REF(p->spell_nav);
  p->state = kDecorProviderDisabled;
}

void decor_free_all_mem(void)
{
  for (size_t i = 0; i < kv_size(decor_providers); i++) {
    decor_provider_clear(&kv_A(decor_providers, i));
  }
  kv_destroy(decor_providers);
}
