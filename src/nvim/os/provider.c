#include <stdint.h>
#include <inttypes.h>
#include <stdbool.h>
#include <assert.h>

#include "nvim/os/provider.h"
#include "nvim/memory.h"
#include "nvim/api/vim.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/private/defs.h"
#include "nvim/os/channel.h"
#include "nvim/os/shell.h"
#include "nvim/os/os.h"
#include "nvim/log.h"
#include "nvim/map.h"
#include "nvim/message.h"
#include "nvim/os/msgpack_rpc_helpers.h"

#define FEATURE_COUNT (sizeof(features) / sizeof(features[0]))

#define FEATURE(feature_name, provider_bootstrap_command, ...) {            \
  .name = feature_name,                                                     \
  .bootstrap_command = provider_bootstrap_command,                          \
  .argv = NULL,                                                             \
  .channel_id = 0,                                                          \
  .methods = (char *[]){__VA_ARGS__, NULL}                                  \
}

static struct feature {
  char *name, **bootstrap_command, **argv, **methods;
  size_t name_length;
  uint64_t channel_id;
} features[] = {
  FEATURE("python",
          &p_ipy,
          "python_execute",
          "python_execute_file",
          "python_do_range",
          "python_eval"),

  FEATURE("clipboard",
          &p_icpb,
          "clipboard_get",
          "clipboard_set")
};

static Map(cstr_t, uint64_t) *registered_providers = NULL;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/provider.c.generated.h"
#endif


void provider_init(void)
{
  registered_providers = map_new(cstr_t, uint64_t)();
}

bool provider_has_feature(char *name)
{
  for (size_t i = 0; i < FEATURE_COUNT; i++) {
    struct feature *f = &features[i];
    if (!STRICMP(name, f->name)) {
      return f->channel_id || can_execute(f);
    }
  }

  return false;
}

bool provider_available(char *method)
{
  return map_has(cstr_t, uint64_t)(registered_providers, method);
}

bool provider_register(char *method, uint64_t channel_id)
{
  if (map_has(cstr_t, uint64_t)(registered_providers, method)) {
    return false;
  }

  // First check if this method is part of a feature, and if so, update
  // the feature structure with the channel id
  struct feature *f = get_feature_for(method);
  if (f) {
    DLOG("Registering provider for \"%s\" "
        "which is part of the \"%s\" feature",
        method,
        f->name);
    f->channel_id = channel_id;
  }

  map_put(cstr_t, uint64_t)(registered_providers, xstrdup(method), channel_id);
  ILOG("Registered channel %" PRIu64 " as the provider for \"%s\"",
       channel_id,
       method);

  return true;
}

Object provider_call(char *method, Object arg)
{
  uint64_t channel_id = get_provider_for(method);

  if (!channel_id) {
    char buf[256];
    snprintf(buf,
             sizeof(buf),
             "Provider for \"%s\" is not available",
             method);
    report_error(buf);
    msgpack_rpc_free_object(arg);
    return NIL;
  }

  bool error = false;
  Object result = NIL;
  channel_send_call(channel_id, method, arg, &result, &error);

  if (error) {
    report_error(result.data.string.data);
    msgpack_rpc_free_object(result);
    return NIL;
  }
  
  return result;
}

static uint64_t get_provider_for(char *method)
{
  uint64_t channel_id = map_get(cstr_t, uint64_t)(registered_providers, method);

  if (channel_id) {
    return channel_id;
  }

  // Try to bootstrap if the method is part of a feature
  struct feature *f = get_feature_for(method);

  if (!f || !can_execute(f)) {
    ELOG("Cannot bootstrap provider for \"%s\"", method);
    goto err;
  }

  if (f->channel_id) {
    ELOG("Already bootstrapped provider for \"%s\"", f->name);
    goto err;
  }

  f->channel_id = channel_from_job(f->argv);

  if (!f->channel_id) {
    ELOG("The provider for \"%s\" failed to bootstrap", f->name);
    goto err;
  }

  return f->channel_id;

err:
  // Ensure we won't try to restart the provider
  if (f) {
    f->bootstrap_command = NULL;
    f->channel_id = 0;
  }
  return 0;
}

static bool can_execute(struct feature *f)
{
  if (!f->bootstrap_command) {
    return false;
  }

  char *cmd = *f->bootstrap_command;

  if (!cmd || !strlen(cmd)) {
    return false;
  }

  if (!f->argv) {
    f->argv = shell_build_argv((uint8_t *)cmd, NULL);
  }

  return os_can_exe((uint8_t *)f->argv[0]);
}

static void report_error(char *str)
{
  vim_err_write((String) {.data = str, .size = strlen(str)});
  vim_err_write((String) {.data = "\n", .size = 1});
}

static bool feature_has_method(struct feature *f, char *method)
{
  size_t i;
  char *m;

  for (m = f->methods[i = 0]; m; m = f->methods[++i]) {
    if (!STRCMP(method, m)) {
      return true;
    }
  }

  return false;
}


static struct feature *get_feature_for(char *method)
{
  for (size_t i = 0; i < FEATURE_COUNT; i++) {
    struct feature *f = &features[i];
    if (feature_has_method(f, method)) {
      return f;
    }
  }

  return NULL;
}
