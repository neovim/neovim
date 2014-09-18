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

#define FEATURE(feature_name, ...) {                                        \
  .name = feature_name,                                                     \
  .handlers = NULL,                                                         \
  .methods = (char *[]){__VA_ARGS__, NULL}                                  \
}

typedef struct {
  char *name, **methods;
  size_t name_length;
  Map(cstr_t, Function) *handlers;
} Feature;

static Feature features[] = {
  FEATURE("python",
          "execute",
          "execute_file",
          "do_range",
          "eval"),

  FEATURE("clipboard",
          "get",
          "set")
};

static PMap(cstr_t) *registered_providers = NULL;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/provider.c.generated.h"
#endif


void provider_init(void)
{
  registered_providers = pmap_new(cstr_t)();

  for (size_t i = 0; i < FEATURE_COUNT; i++) {
    features[i].handlers = map_new(cstr_t, Function)();
  }
}

bool provider_has_feature(char *name)
{
  Feature *f = pmap_get(cstr_t)(registered_providers, name);
  return f != NULL && is_provided(f);
}

void provider_register(char *name, Dictionary handlers, Error *err)
{
  Feature *f = NULL;
  for (size_t i = 0; i < FEATURE_COUNT; i++) {
    if (!STRICMP(name, features[i].name)) {
      f = &features[i];
      break;
    }
  }

  if (!f) {
    api_set_error(err, Validation, _("Unknown feature \"%s\""), name);
    return;
  }

  if (is_provided(f)) {
    api_set_error(err,
                  Exception,
                  _("Feature \"%s\" is already provided by another "
                    "extension"),
                  name);
    return;
  }

  DLOG("Registering provider for \"%s\"", name);

  // Associate all method names with the feature struct
  size_t i;
  char *method;
  for (method = f->methods[i = 0]; method; method = f->methods[++i]) {
    size_t j;
    for (j = 0; j < handlers.size; j++) {
      KeyValuePair e = handlers.items[j];

      if (e.value.type != kObjectTypeFunction) {
        api_set_error(err,
                      Validation,
                      _("Dictionary key \"%s\" is not associated with a "
                        "function"),
                      e.key.data);
        return;
      }

      if (!strcmp(method, e.key.data)) {
        Function function = map_get(cstr_t, Function)(f->handlers, method);
        // Ensure memory allocated for the current value(if exists) is
        // freed
        api_free_function(function);
        function = e.value.data.function;
        // Copy the function id because `handlers` will be freed soon
        function.data.name = xstrdup(function.data.name);
        map_put(cstr_t, Function)(f->handlers, method, function);
        break;
      }
    }

    if (j == handlers.size) {
      // Did not find method in handlers dictionary
      api_set_error(err,
                    Validation,
                    _("Dictionary does not contain an implementation "
                      "for \"%s\""),
                    method);
      return;
    }
  }

  pmap_put(cstr_t)(registered_providers, f->name, f);
  DLOG("Registered provider for \"%s\"", name);
}

Object provider_call(char *name, char *method, Array args)
{
  Feature *f = pmap_get(cstr_t)(registered_providers, name);

  if (!f) {
    char buf[256];
    snprintf(buf,
             sizeof(buf),
             "Provider for method \"%s\" is not available",
             method);
    vim_report_error(cstr_as_string(buf));
    api_free_array(args);
    return NIL;
  }

  Function function = map_get(cstr_t, Function)(f->handlers, method);
  Error err = ERROR_INIT;
  Object result = api_call_function(&function, args, &err);

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

static bool is_provided(Feature *f)
{
  size_t i;
  char *method;
  for (method = f->methods[i = 0]; method; method = f->methods[++i]) {
    Function function = map_get(cstr_t, Function)(f->handlers, method);

    if (!api_function_is_valid(&function)) {
      return false;
    }
  }

  return true;
}
