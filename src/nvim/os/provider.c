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

#define FEATURE_COUNT (sizeof(features) / sizeof(features[0]))

#define FEATURE(feature_name, ...) {            \
  .name = feature_name,                                                     \
  .channel_id = 0,                                                          \
  .methods = (char *[]){__VA_ARGS__, NULL}                                  \
}

typedef struct {
  char *name, **methods;
  size_t name_length;
  uint64_t channel_id;
} Feature;

static Feature features[] = {
  FEATURE("python",
          "python_execute",
          "python_execute_file",
          "python_do_range",
          "python_eval"),

  FEATURE("clipboard",
          "clipboard_get",
          "clipboard_set")
};

static PMap(cstr_t) *registered_providers = NULL;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/provider.c.generated.h"
#endif


void provider_init(void)
{
  registered_providers = pmap_new(cstr_t)();
}

bool provider_has_feature(char *name)
{
  Feature *f = find_feature(name);
  return f != NULL && channel_exists(f->channel_id);
}

bool provider_register(char *name, uint64_t channel_id)
{
  Feature *f = find_feature(name);

  if (!f) {
    return false;
  }

  if (f->channel_id && channel_exists(f->channel_id)) {
    ILOG("Feature \"%s\" is already provided by another channel"
         "(will be replaced)", name);
  }

  DLOG("Registering provider for \"%s\"", name);
  f->channel_id = channel_id;

  // Associate all method names with the feature struct
  size_t i;
  char *method;
  for (method = f->methods[i = 0]; method; method = f->methods[++i]) {
    pmap_put(cstr_t)(registered_providers, method, f);
    DLOG("Channel \"%" PRIu64 "\" will be sent requests for \"%s\"",
         channel_id,
         method);
  }

  ILOG("Registered channel %" PRIu64 " as the provider for the \"%s\" feature",
       channel_id,
       name);

  return true;
}

Object provider_call(char *method, Array args)
{
  Feature *f = pmap_get(cstr_t)(registered_providers, method);

  if (!f || !channel_exists(f->channel_id)) {
    char buf[256];
    snprintf(buf,
             sizeof(buf),
             "Provider for method \"%s\" is not available",
             method);
    vim_report_error(cstr_as_string(buf));
    api_free_array(args);
    return NIL;
  }

  Error err = ERROR_INIT;
  Object result = NIL = channel_send_call(f->channel_id, method, args, &err);

  if (err.set) {
    vim_report_error(cstr_as_string(err.msg));
    api_free_object(result);
    return NIL;
  }
  
  return result;
}

void provider_init_feature_metadata(Dictionary *metadata)
{
  Dictionary md = ARRAY_DICT_INIT;

  for (size_t i = 0; i < FEATURE_COUNT; i++) {
    Array methods = ARRAY_DICT_INIT;
    Feature *f = &features[i];

    size_t j;
    char *method;
    for (method = f->methods[j = 0]; method; method = f->methods[++j]) {
      ADD(methods, STRING_OBJ(cstr_to_string(method)));
    }

    PUT(md, f->name, ARRAY_OBJ(methods));
  }

  PUT(*metadata, "features", DICTIONARY_OBJ(md));
}

static Feature * find_feature(char *name)
{
  for (size_t i = 0; i < FEATURE_COUNT; i++) {
    Feature *f = &features[i];
    if (!STRICMP(name, f->name)) {
      return f;
    }
  }

  return NULL;
}
