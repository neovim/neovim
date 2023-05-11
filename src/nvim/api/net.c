#include <curl/curl.h>
#include <curl/easy.h>
#include <curl/multi.h>
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

const char *VALID_HTTP_METHODS[]
  = { "GET", "POST", "PUT", "DELETE", "HEAD", "OPTIONS", "PATCH", "CONNECT", NULL };

bool initialized = false;
CURLSH *shared_handle = NULL;

static bool is_valid_http_method(String method)
{
  if (method.data == NULL) {
    return false;
  }

  for (const char **valid_method = VALID_HTTP_METHODS; *valid_method != NULL; ++valid_method) {
    if (strncmp(method.data, *valid_method, method.size) == 0) {
      return true;
    }
  }

  return false;
}

static curl_mime *dict_to_mimepost(CURL *easy_handle, Dictionary *dict)
{
  curl_mime *form = curl_mime_init(easy_handle);

  for (size_t i = 0; i < dict->size; ++i) {
    KeyValuePair kv = dict->items[i];
    curl_mimepart *part = curl_mime_addpart(form);
    curl_mime_name(part, string_to_cstr(kv.key));
    curl_mime_data(part, kv.value.data.string.data, CURL_ZERO_TERMINATED);
  }

  return form;
}

static void dict_headers(Dictionary headers_dict, struct curl_slist **headers, Error *err)
{
  for (size_t i = 0; i < headers_dict.size; i++) {
    KeyValuePair header = headers_dict.items[i];
    if (header.value.type == kObjectTypeString) {
      // Single value header

      const char *header_key = string_to_cstr(header.key);
      const char *header_value = string_to_cstr(header.value.data.string);

      size_t header_line_size = strlen(header_key) + strlen(header_value) + 3;

      char *header_line = xmalloc(header_line_size);

      snprintf(header_line, header_line_size, "%s: %s", header_key, header_value);

      *headers = curl_slist_append(*headers, header_line);
      XFREE_CLEAR(header_line);
    } else if (header.value.type == kObjectTypeArray) {
      // Multi-value header

      Array header_values = header.value.data.array;
      for (size_t j = 0; j < header_values.size; j++) {
        if (header_values.items[j].type == kObjectTypeString) {
          const char *header_key = string_to_cstr(header.key);
          const char *header_value = string_to_cstr(header_values.items[j].data.string);
          size_t header_line_size = strlen(header_key) + strlen(header_value) + 3;
          char *header_line = xmalloc(header_line_size);

          snprintf(header_line, header_line_size, "%s: %s", header_key, header_value);

          *headers = curl_slist_append(*headers, header_line);
          XFREE_CLEAR(header_line);
        } else {
          api_set_error(err,
                        kErrorTypeValidation,
                        "Invalid header value type for key '%s', expected string",
                        string_to_cstr(header.key));
          return;
        }
      }
    } else {
      api_set_error(err,
                    kErrorTypeValidation,
                    "Invalid header value type for key '%s', expected string | string[]",
                    string_to_cstr(header.key));
      return;
    }
  }
}

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
  PUT(res_dict, "ok", BOOLEAN_OBJ(code >= 200 && code <= 299));

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
  // Dict(fetch) *opts = &fetch_data->opts;
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
    if (fetch_data->on_err != -1) {
      AsyncErrData *async_data = xmalloc(sizeof(AsyncErrData));
      async_data->lstate = fetch_data->lstate;
      async_data->res = res;
      async_data->on_err = fetch_data->on_err;

      async_data->error.data = error_buffer;
      async_data->error.size = strlen(error_buffer);

      Event event;
      event.handler = async_err_cb;
      event.argv[0] = async_data;

      multiqueue_put_event(main_loop.fast_events, event);
    } else {
      // TODO(marshmallow (mrshmllow)): vim.notify
      fprintf(stderr, "curl fetch failed: %s\n", curl_easy_strerror(res));
    }

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
  curl_mime_free(fetch_data->mime_post_data);
  curl_slist_free_all(fetch_data->headers);
  curl_easy_cleanup(easy_handle);
  XFREE_CLEAR(fetch_data);
}

/// Perform an asyncronous network request.
///
/// Example:
/// <pre>lua
/// vim.net.fetch("https://example.com/api/data", {
///   on_complete = function (response)
///     -- Lets read the response!
///
///     if response.ok then
///       -- Read response text
///       local body = response.text
///     else
///   end,
/// })
///
/// -- POST to a url, sending a table as JSON and providing an authorization header
/// vim.net.fetch("https://example.com/api/data", {
///   method = "POST",
///   data = vim.json.encode({
///     key = value
///   }),
///   headers = {
///     Authorization = "Bearer " .. token
///     ["Content-Type"] = "application/json",
///     ["Accept"] = "application/json"
///   },
///   on_complete = function (response)
///     -- Lets read the response!
///
///     if response.ok then
///       -- Read JSON response
///       local table = vim.json.decode(response.test)
///     else
///
///     -- What went wrong?
///     vim.print(response.status)
///   end
/// })
/// </pre>
///
/// @note `opts.form` and `opts.data` are mutually exclusive.
/// @see man://libcurl-errors
///
/// @param channel_id
/// @param url string
/// @param opts table|nil Optional keyword arguments:
///   - form table<string,string>|nil Key-Value form data. Implies
///   `Content-Type: multipart/form-data`.
///   - data string|nil Data to send with the request.
///   - headers table<string, string | string[]>|nil Headers to send. A header can have
///   multiple values.
///   - method string|nil HTTP method to use. Defaults to GET.
///   - redirect string|nil Control redirect follow behavior. Defaults to `follow`.
///   Posible values include:
///     - `follow`: Follow all redirects when fetching a resource.
///     - `none`: Do not follow redirects.
///   - on_complete fun(response: table)|nil Optional callback when response completes. The
///   `response` table has the following values:
///     - ok: bool Response status was within 200-299 range.
///     - text: string Response body. Empty if `method` was HEAD.
///     - headers: table<string, string> Header key-values. Multiple values are sperated by `,`.
///     - status: number HTTP status.
///   - on_err fun(code: number, err: string)|nil Used when request failed. Returned values are:
///     - `code`: `CURLcode`, see man://libcurl-errors. Report errors you feel neovim itself caused
///     to the issue tracker!
///     - `err`: Human readable error string, may or may not be empty.
void nvim_fetch(uint64_t channel_id, String url, Dict(fetch) *opts, lua_State *lstate, Error *err)
  FUNC_API_SINCE(12)
{
  // TODO(marshmallow): Confirm if validate macros require cleanup

  if (opts->data.type != kObjectTypeNil && opts->form.type != kObjectTypeNil) {
    api_set_error(err, kErrorTypeValidation, "form and data are mutually exclusive");
    return;
  }

  if (!initialized) {
    curl_global_init(CURL_GLOBAL_DEFAULT);
    shared_handle = curl_share_init();
    curl_share_setopt(shared_handle, CURLSHOPT_SHARE, CURL_LOCK_DATA_CONNECT);

    initialized = true;
  }

  CURL *easy_handle = curl_easy_init();

  if (!easy_handle) {
    api_set_error(err, kErrorTypeException, "Error initializing curl easy handle");
    return;
  }

  FetchData *fetch_data = xmalloc(sizeof(FetchData));
  fetch_data->url = url;
  fetch_data->opts = *opts;
  fetch_data->easy_handle = easy_handle;
  fetch_data->lstate = lstate;

  fetch_data->on_complete = -1;
  fetch_data->on_err = -1;

  fetch_data->headers = NULL;
  fetch_data->mime_post_data = NULL;

  curl_easy_setopt(easy_handle, CURLOPT_SHARE, shared_handle);
  curl_easy_setopt(easy_handle, CURLOPT_URL, url.data);

  if (opts->headers.type != kObjectTypeNil) {
    VALIDATE_T_DICT("headers", opts->headers, { return; });

    dict_headers(opts->headers.data.dictionary, &fetch_data->headers, err);
    curl_easy_setopt(easy_handle, CURLOPT_HTTPHEADER, fetch_data->headers);
  }

  if (opts->data.type != kObjectTypeNil) {
    VALIDATE_T("data", kObjectTypeString, opts->data.type, { return; });

    curl_easy_setopt(easy_handle, CURLOPT_POSTFIELDS, string_to_cstr(opts->data.data.string));
  }

  if (opts->form.type != kObjectTypeNil) {
    VALIDATE_T_DICT("form", opts->form, { return; });

    fetch_data->mime_post_data = dict_to_mimepost(easy_handle, &opts->form.data.dictionary);
    curl_easy_setopt(easy_handle, CURLOPT_MIMEPOST, fetch_data->mime_post_data);
  }

  if (opts->method.type != kObjectTypeNil) {
    VALIDATE_T("method", kObjectTypeString, opts->method.type, { return; });

    const char *method = string_to_cstr(opts->method.data.string);

    VALIDATE_S(is_valid_http_method(opts->method.data.string), "method", method, { return; });

    if (strcmp(method, "HEAD") == 0) {
      curl_easy_setopt(easy_handle, CURLOPT_NOBODY, 1L);
    } else if (strcmp(method, "GET") == 0) {
      curl_easy_setopt(easy_handle, CURLOPT_HTTPGET, 1L);
    } else {
      curl_easy_setopt(easy_handle, CURLOPT_CUSTOMREQUEST, opts->method.data.string);
    }
  }

  if (opts->redirect.type != kObjectTypeNil) {
    VALIDATE_T("redirect", kObjectTypeString, opts->redirect.type, { return; });

    const char *redirect = string_to_cstr(opts->redirect.data.string);
    bool is_follow = strcmp(redirect, "follow") == 0;

    VALIDATE_S((is_follow || strcmp(redirect, "none") == 0),
               redirect,
               "must be either \"follow\", \"none\", or nil",
               { return; });

    curl_easy_setopt(easy_handle, CURLOPT_FOLLOWLOCATION, is_follow ? 1L : 0L);
  } else {
    curl_easy_setopt(easy_handle, CURLOPT_FOLLOWLOCATION, 1L);
  }

  if (opts->on_complete.type != kObjectTypeNil) {
    VALIDATE_T("on_complete", kObjectTypeLuaRef, opts->on_complete.type, { return; });

    lua_rawgeti(lstate, LUA_REGISTRYINDEX, opts->on_complete.data.luaref);
    int registry_ref = luaL_ref(lstate, LUA_REGISTRYINDEX);
    fetch_data->on_complete = registry_ref;
  }

  if (opts->on_err.type != kObjectTypeNil) {
    VALIDATE_T("on_err", kObjectTypeLuaRef, opts->on_err.type, { return; });

    lua_rawgeti(lstate, LUA_REGISTRYINDEX, opts->on_err.data.luaref);
    int registry_ref = luaL_ref(lstate, LUA_REGISTRYINDEX);
    fetch_data->on_err = registry_ref;
  }

  uv_thread_t fetch_thread;
  uv_thread_create(&fetch_thread, fetch_worker, fetch_data);
  pthread_detach(fetch_thread);
}

void net_teardown(void)
{
  curl_share_cleanup(shared_handle);
  curl_global_cleanup();
}
