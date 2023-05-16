#include <curl/curl.h>
#include <curl/easy.h>
#include <curl/multi.h>
#include <lauxlib.h>
#include <lua.h>
#include <stdio.h>
#include <string.h>

#include "net.h"

#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/private/validate.h"
#include "nvim/lua/executor.h"
#include "nvim/main.h"
#include "nvim/memory.h"
#include "nvim/types.h"

bool initialized = false;
CURLSH *shared_handle = NULL;

static size_t write_cb(void *contents, size_t size, size_t nmemb, void *userp)
{
  size_t realsize = size * nmemb;

  if (realsize == 0) {
    return 0;
  }

  String *data = (String *)userp;

  char *new_buffer = xrealloc(data->data, data->size + realsize + 1);

  data->data = new_buffer;
  strncpy(&(data->data[data->size]), contents, realsize);
  data->size += realsize;
  data->data[data->size] = 0;

  return realsize;
}

static size_t write_header_cb(void *contents, size_t size, size_t nmemb, void *userp)
{
  const size_t HEADER_ELEMENTS = 2;
  const size_t MAX_LINE_LENGTH = 5;

  size_t realsize = size * nmemb;
  HeaderMemoryStruct *data = (HeaderMemoryStruct *)userp;

  if (strncmp(contents, "HTTP/", MAX_LINE_LENGTH) == 0) {
    if (data->is_final_response) {
      api_free_dictionary(data->dict);
    }
    Dictionary header_dict = ARRAY_DICT_INIT;
    data->dict = header_dict;
    data->is_final_response = false;
  } else if (realsize == HEADER_ELEMENTS && strncmp(contents, "\r\n", HEADER_ELEMENTS) == 0) {
    // line is blank
    data->is_final_response = true;
  } else if (!data->is_final_response) {
    char *header_line = xmalloc(realsize + 1);
    memcpy(header_line, contents, realsize);
    header_line[realsize] = '\0';

    char *save_ptr;
    char *key = strtok_r(header_line, ":", &save_ptr);
    char *value = strtok_r(NULL, "\r\n", &save_ptr);

    if (key && value) {
      while (*value == ' ') {
        value++;
      }

      char *key_copy = strdup(key);
      char *value_copy = strdup(value);

      String key_str;
      key_str.data = key_copy;
      key_str.size = strlen(key_copy);

      String value_str;
      value_str.data = value_copy;
      value_str.size = strlen(value_copy);

      PUT(data->dict, key_str.data, STRING_OBJ(value_str));
    }

    XFREE_CLEAR(header_line);
  }

  return realsize;
}

static void async_complete_cb(void **argv)
{
  AsyncCompleteData *data = (AsyncCompleteData *)argv[0];
  Array args = ARRAY_DICT_INIT;

  Object items[1];
  args.size = 1;
  args.items = items;

  Dictionary res_dict = ARRAY_DICT_INIT;

  long code = data->http_response_code;

  PUT(res_dict, "status", FLOAT_OBJ((double)code));

  PUT(res_dict, "text", STRING_OBJ(data->response));
  PUT(res_dict, "headers", DICTIONARY_OBJ(data->headers.dict));

  args.items[0] = DICTIONARY_OBJ(res_dict);

  nlua_call_ref(data->on_complete, NULL, args, false, NULL);
  api_free_luaref(data->on_complete);

  XFREE_CLEAR(data->response.data);
  XFREE_CLEAR(data);
}

static void async_err_cb(void **argv)
{
  AsyncErrData *data = (AsyncErrData *)argv[0];
  Array args = ARRAY_DICT_INIT;

  Object items[2];
  args.size = 2;
  args.items = items;

  args.items[0] = INTEGER_OBJ(data->res);
  args.items[1] = STRING_OBJ(data->error);

  nlua_call_ref(data->on_err, NULL, args, false, NULL);
  api_free_luaref(data->on_err);

  XFREE_CLEAR(data);
}

static void fetch_worker(void *arg)
{
  FetchData *fetch_data = (FetchData *)arg;
  CURL *easy_handle = fetch_data->easy_handle;

  String response_chunk = STRING_INIT;

  HeaderMemoryStruct header_data;

  Dictionary header_dict = ARRAY_DICT_INIT;
  header_data.dict = header_dict;
  header_data.is_final_response = false;

  char error_buffer[CURL_ERROR_SIZE];

  curl_easy_setopt(easy_handle, CURLOPT_ERRORBUFFER, error_buffer);
  curl_easy_setopt(easy_handle, CURLOPT_WRITEFUNCTION, write_cb);
  curl_easy_setopt(easy_handle, CURLOPT_WRITEDATA, (void *)&response_chunk);
  curl_easy_setopt(easy_handle, CURLOPT_HEADERFUNCTION, write_header_cb);
  curl_easy_setopt(easy_handle, CURLOPT_HEADERDATA, (void *)&header_data);

  CURLcode res = curl_easy_perform(easy_handle);

  if (res != CURLE_OK) {
    AsyncErrData *async_data = xmalloc(sizeof(AsyncErrData));
    async_data->lstate = fetch_data->lstate;
    async_data->res = res;
    async_data->on_err = fetch_data->on_err;

    if (error_buffer[0] == '\0') {
      strncpy(error_buffer, curl_easy_strerror(res), CURL_ERROR_SIZE - 1);
      error_buffer[CURL_ERROR_SIZE - 1] = '\0';
    }

    async_data->error.data = error_buffer;
    async_data->error.size = strlen(error_buffer);

    Event event;
    event.handler = async_err_cb;
    event.argv[0] = async_data;

    multiqueue_put_event(main_loop.fast_events, event);

    XFREE_CLEAR(response_chunk.data);
    XFREE_CLEAR(header_data.dict);
    goto cleanup;
  }

  if (fetch_data->on_complete != -1) {
    AsyncCompleteData *async_data = xmalloc(sizeof(AsyncCompleteData));
    async_data->on_complete = fetch_data->on_complete;
    async_data->lstate = fetch_data->lstate;
    async_data->response = response_chunk;
    async_data->headers = header_data;

    curl_easy_getinfo(easy_handle, CURLINFO_RESPONSE_CODE, &async_data->http_response_code);

    Event event;
    event.handler = async_complete_cb;
    event.argv[0] = async_data;

    multiqueue_put_event(main_loop.fast_events, event);
  } else {
    XFREE_CLEAR(response_chunk.data);
    XFREE_CLEAR(header_data.dict);
    goto cleanup;
  }

cleanup:
  XFREE_CLEAR(fetch_data->data);
  curl_mime_free(fetch_data->multipart_form);
  curl_slist_free_all(fetch_data->headers);
  curl_easy_cleanup(easy_handle);
  XFREE_CLEAR(fetch_data);
}

int nlua_fetch(lua_State *lstate)
{
  if (!initialized) {
    curl_global_init(CURL_GLOBAL_DEFAULT);
    shared_handle = curl_share_init();
    curl_share_setopt(shared_handle, CURLSHOPT_SHARE, CURL_LOCK_DATA_CONNECT);

    initialized = true;
  }

  char *url = (char *)luaL_checkstring(lstate, 1);

  if (!url) {
    return luaL_error(lstate, "expected url");
  }
  if (!lua_isfunction(lstate, 2)) {
    return luaL_error(lstate, "expected on_err");
  }
  if (!lua_istable(lstate, 3)) {
    return luaL_error(lstate, "opts must be a table");
  }

  CURL *easy_handle = curl_easy_init();

  if (!easy_handle) {
    luaL_error(lstate, "Error initializing curl easy handle");

    return 0;
  }

  curl_easy_setopt(easy_handle, CURLOPT_SHARE, shared_handle);
  curl_easy_setopt(easy_handle, CURLOPT_URL, url);

  FetchData *fetch_data = xmalloc(sizeof(FetchData));
  fetch_data->easy_handle = easy_handle;
  fetch_data->lstate = lstate;

  fetch_data->on_complete = -1;
  fetch_data->headers = NULL;
  fetch_data->data = NULL;
  fetch_data->multipart_form = NULL;

  lua_pushvalue(lstate, 2);
  fetch_data->on_err = luaL_ref(lstate, LUA_REGISTRYINDEX);

  lua_pushnil(lstate);
  while (lua_next(lstate, 3) != 0) {
    const int KEY = -2;
    const int VALUE = -1;

    char *key = (char *)luaL_checkstring(lstate, KEY);

    if (!key) {
      continue;
    }

    if (strcmp("on_complete", key) == 0) {
      if (!lua_isfunction(lstate, VALUE)) {
        luaL_error(lstate, "on_complete must be a function");
        return 0;
      }

      lua_pushvalue(lstate, VALUE);
      fetch_data->on_complete = luaL_ref(lstate, LUA_REGISTRYINDEX);
    }

    if (strcmp("user", key) == 0) {
      char *user = (char *)luaL_checkstring(lstate, VALUE);

      if (!user) {
        luaL_error(lstate, "user must be a string");
        return 0;
      }

      curl_easy_setopt(easy_handle, CURLOPT_USERPWD, user);
    }

    if (strcmp("method", key) == 0) {
      char *method = (char *)luaL_checkstring(lstate, VALUE);

      if (!method) {
        luaL_error(lstate, "method must be a string");
        return 0;
      }

      if (strcmp(method, "HEAD") == 0) {
        curl_easy_setopt(easy_handle, CURLOPT_NOBODY, 1L);
      } else if (strcmp(method, "GET") == 0) {
        curl_easy_setopt(easy_handle, CURLOPT_HTTPGET, 1L);
      } else {
        curl_easy_setopt(easy_handle, CURLOPT_CUSTOMREQUEST, method);
      }
    }

    if (strcmp("headers", key) == 0) {
      if (!lua_istable(lstate, VALUE)) {
        luaL_error(lstate, "headers must be a table");
        return 0;
      }

      lua_pushvalue(lstate, -1);

      lua_pushnil(lstate);
      while (lua_next(lstate, -2) != 0) {
        if (lua_isstring(lstate, -1) || lua_istable(lstate, -1)) {
          const char *header_key = lua_tostring(lstate, -2);

          if (lua_isstring(lstate, -1)) {
            // Single value header
            const char *header_value = lua_tostring(lstate, -1);

            size_t header_line_size = strlen(header_key) + strlen(header_value) + 3;
            char *header_line = xmalloc(header_line_size);

            snprintf(header_line, header_line_size, "%s: %s", header_key, header_value);

            fetch_data->headers = curl_slist_append(fetch_data->headers, header_line);
            XFREE_CLEAR(header_line);
          } else {
            // Multi-value header
            lua_pushnil(lstate);
            while (lua_next(lstate, -2) != 0) {
              if (lua_isstring(lstate, -1)) {
                const char *header_value = lua_tostring(lstate, -1);
                size_t header_line_size = strlen(header_key) + strlen(header_value) + 3;
                char *header_line = xmalloc(header_line_size);

                snprintf(header_line, header_line_size, "%s: %s", header_key, header_value);

                fetch_data->headers = curl_slist_append(fetch_data->headers, header_line);
                XFREE_CLEAR(header_line);
              } else {
                char *message = NULL;
                sprintf(message,
                        "Invalid header value type for key '%s', expected string",
                        lua_tostring(lstate, -2));
                luaL_error(lstate, message);
                return 0;
              }
              lua_pop(lstate, 1);
            }
          }
        } else {
          char *message = NULL;
          sprintf(message,
                  "Invalid header value type for key '%s', expected string | string[]",
                  lua_tostring(lstate, -2));
          luaL_error(lstate, message);
          return 0;
        }
        lua_pop(lstate, 1);
      }

      curl_easy_setopt(easy_handle, CURLOPT_HTTPHEADER, fetch_data->headers);
      lua_pop(lstate, 1);
    }

    if (strcmp("data", key) == 0) {
      char *data = (char *)luaL_checkstring(lstate, VALUE);

      if (!data) {
        luaL_error(lstate, "data must be a string");
        return 0;
      }

      if (fetch_data->multipart_form != NULL) {
        luaL_error(lstate, "data and multipart_form are mutually exclusive");
        return 0;
      }

      fetch_data->data = xstrdup(data);
      curl_easy_setopt(easy_handle, CURLOPT_POSTFIELDS, fetch_data->data);
    }

    if (strcmp("multipart_form", key) == 0) {
      if (!lua_istable(lstate, VALUE)) {
        luaL_error(lstate, "form must be a table");
        return 0;
      }

      if (fetch_data->data != NULL) {
        luaL_error(lstate, "data and multipart_form are mutually exclusive");
        return 0;
      }

      fetch_data->multipart_form = curl_mime_init(fetch_data->easy_handle);

      lua_pushvalue(lstate, -1);

      lua_pushnil(lstate);
      while (lua_next(lstate, -2) != 0) {
        if (!lua_isstring(lstate, -2) || !lua_isstring(lstate, -1)) {
          lua_pop(lstate, 2);
          continue;
        }

        curl_mimepart *part = curl_mime_addpart(fetch_data->multipart_form);
        curl_mime_name(part, lua_tostring(lstate, -2));
        curl_mime_data(part, lua_tostring(lstate, -1), CURL_ZERO_TERMINATED);

        curl_mime_type(part, "application/octet-stream");

        lua_pop(lstate, 1);
      }

      curl_easy_setopt(easy_handle, CURLOPT_MIMEPOST, fetch_data->multipart_form);
      lua_pop(lstate, 1);
    }

    lua_pop(lstate, 1);
  }

  uv_thread_t fetch_thread;
  uv_thread_create(&fetch_thread, fetch_worker, fetch_data);
  pthread_detach(fetch_thread);

  return 0;
}

void net_teardown(void)
{
  curl_share_cleanup(shared_handle);
  curl_global_cleanup();
}
