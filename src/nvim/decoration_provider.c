// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include "nvim/api/extmark.h"
#include "nvim/api/private/helpers.h"
#include "nvim/buffer.h"
#include "nvim/decoration.h"
#include "nvim/decoration_provider.h"
#include "nvim/highlight.h"
#include "nvim/lua/executor.h"

static kvec_t(DecorProvider) decor_providers = KV_INITIAL_VALUE;

#define DECORATION_PROVIDER_INIT(ns_id) (DecorProvider) \
  { ns_id, false, LUA_NOREF, LUA_NOREF, \
    LUA_NOREF, LUA_NOREF, LUA_NOREF, \
    LUA_NOREF, -1 }

static bool decor_provider_invoke(NS ns_id, const char *name, LuaRef ref, Array args,
                                  bool default_true, char **perr)
{
  Error err = ERROR_INIT;

  textlock++;
  provider_active = true;
  Object ret = nlua_call_ref(ref, name, args, true, &err);
  provider_active = false;
  textlock--;

  if (!ERROR_SET(&err)
      && api_object_to_bool(ret, "provider %s retval", default_true, &err)) {
    return true;
  }

  if (ERROR_SET(&err)) {
    const char *ns_name = describe_ns(ns_id);
    ELOG("error in provider %s:%s: %s", ns_name, name, err.msg);
    bool verbose_errs = true;  // TODO(bfredl):
    if (verbose_errs && perr && *perr == NULL) {
      static char errbuf[IOSIZE];
      snprintf(errbuf, sizeof errbuf, "%s: %s", ns_name, err.msg);
      *perr = xstrdup(errbuf);
    }
  }

  api_free_object(ret);
  return false;
}

/// For each provider invoke the 'start' callback
///
/// @param[out] providers Decoration providers
/// @param[out] err       Provider err
void decor_providers_start(DecorProviders *providers, int type, char **err)
{
  kvi_init(*providers);

  for (size_t i = 0; i < kv_size(decor_providers); i++) {
    DecorProvider *p = &kv_A(decor_providers, i);
    if (!p->active) {
      continue;
    }

    bool active;
    if (p->redraw_start != LUA_NOREF) {
      FIXED_TEMP_ARRAY(args, 2);
      args.items[0] = INTEGER_OBJ((int)display_tick);
      args.items[1] = INTEGER_OBJ(type);
      active = decor_provider_invoke(p->ns_id, "start", p->redraw_start, args, true, err);
    } else {
      active = true;
    }

    if (active) {
      kvi_push(*providers, p);
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
void decor_providers_invoke_win(win_T *wp, DecorProviders *providers,
                                DecorProviders *line_providers, char **err)
{
  kvi_init(*line_providers);

  linenr_T knownmax = ((wp->w_valid & VALID_BOTLINE)
                       ? wp->w_botline
                       : (wp->w_topline + wp->w_height_inner));

  for (size_t k = 0; k < kv_size(*providers); k++) {
    DecorProvider *p = kv_A(*providers, k);
    if (p && p->redraw_win != LUA_NOREF) {
      FIXED_TEMP_ARRAY(args, 4);
      args.items[0] = WINDOW_OBJ(wp->handle);
      args.items[1] = BUFFER_OBJ(wp->w_buffer->handle);
      // TODO(bfredl): we are not using this, but should be first drawn line?
      args.items[2] = INTEGER_OBJ(wp->w_topline - 1);
      args.items[3] = INTEGER_OBJ(knownmax);
      if (decor_provider_invoke(p->ns_id, "win", p->redraw_win, args, true, err)) {
        kvi_push(*line_providers, p);
      }
    }
  }

  win_check_ns_hl(wp);
}

/// For each provider invoke the 'line' callback for a given window row.
///
/// @param      wp        Window
/// @param      providers Decoration providers
/// @param      row       Row to invoke line callback for
/// @param[out] has_decor Set when at least one provider invokes a line callback
/// @param[out] err       Provider error
void providers_invoke_line(win_T *wp, DecorProviders *providers, int row, bool *has_decor,
                           char **err)
{
  for (size_t k = 0; k < kv_size(*providers); k++) {
    DecorProvider *p = kv_A(*providers, k);
    if (p && p->redraw_line != LUA_NOREF) {
      FIXED_TEMP_ARRAY(args, 3);
      args.items[0] = WINDOW_OBJ(wp->handle);
      args.items[1] = BUFFER_OBJ(wp->w_buffer->handle);
      args.items[2] = INTEGER_OBJ(row);
      if (decor_provider_invoke(p->ns_id, "line", p->redraw_line, args, true, err)) {
        *has_decor = true;
      } else {
        // return 'false' or error: skip rest of this window
        kv_A(*providers, k) = NULL;
      }

      win_check_ns_hl(wp);
    }
  }
}

/// For each provider invoke the 'buf' callback for a given buffer.
///
/// @param      buf       Buffer
/// @param      providers Decoration providers
/// @param[out] err       Provider error
void decor_providers_invoke_buf(buf_T *buf, DecorProviders *providers, char **err)
{
  for (size_t i = 0; i < kv_size(*providers); i++) {
    DecorProvider *p = kv_A(*providers, i);
    if (p && p->redraw_buf != LUA_NOREF) {
      FIXED_TEMP_ARRAY(args, 1);
      args.items[0] = BUFFER_OBJ(buf->handle);
      decor_provider_invoke(p->ns_id, "buf", p->redraw_buf, args, true, err);
    }
  }
}

/// For each provider invoke the 'end' callback
///
/// @param      providers   Decoration providers
/// @param      displaytick Display tick
/// @param[out] err         Provider error
void decor_providers_invoke_end(DecorProviders *providers, char **err)
{
  for (size_t i = 0; i < kv_size(*providers); i++) {
    DecorProvider *p = kv_A(*providers, i);
    if (p && p->active && p->redraw_end != LUA_NOREF) {
      FIXED_TEMP_ARRAY(args, 1);
      args.items[0] = INTEGER_OBJ((int)display_tick);
      decor_provider_invoke(p->ns_id, "end", p->redraw_end, args, true, err);
    }
  }
}

DecorProvider *get_decor_provider(NS ns_id, bool force)
{
  size_t i;
  size_t len = kv_size(decor_providers);
  for (i = 0; i < len; i++) {
    DecorProvider *item = &kv_A(decor_providers, i);
    if (item->ns_id == ns_id) {
      return item;
    } else if (item->ns_id > ns_id) {
      break;
    }
  }

  if (!force) {
    return NULL;
  }

  // Adding a new provider, so allocate room in the vector
  (void)kv_a(decor_providers, len);
  if (i < len) {
    // New ns_id needs to be inserted between existing providers to maintain
    // ordering, so shift other providers with larger ns_id
    memmove(&kv_A(decor_providers, i + 1),
            &kv_A(decor_providers, i),
            (len - i) * sizeof(kv_a(decor_providers, i)));
  }
  DecorProvider *item = &kv_a(decor_providers, i);
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
  p->active = false;
}

void decor_free_all_mem(void)
{
  for (size_t i = 0; i < kv_size(decor_providers); i++) {
    decor_provider_clear(&kv_A(decor_providers, i));
  }
  kv_destroy(decor_providers);
}
