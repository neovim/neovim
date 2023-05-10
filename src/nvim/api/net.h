#ifndef NVIM_API_FETCH_H
#define NVIM_API_FETCH_H

#include <bits/stdint-uintn.h>
#include <curl/curl.h>
#include <lua.h>

#include "nvim/api/keysets.h"
#include "nvim/api/private/defs.h"

void nvim_fetch(uint64_t channel_id, String url, Dict(fetch) * opts, lua_State *lstate, Error *err);

void net_teardown(void);

typedef struct {
  char *data;
  size_t size;
} MemoryStruct;

typedef struct {
  Dictionary dict;
  bool is_final_response;
} HeaderMemoryStruct;

typedef struct {
  String url;
  Dict(fetch) opts;
  CURL *easy_handle;
  int on_complete;
  int on_err;
  curl_mime *mime_post_data;
  struct curl_slist *headers;
  lua_State *lstate;
} FetchData;

typedef struct {
  int on_complete;
  lua_State *lstate;

  MemoryStruct response;
  HeaderMemoryStruct headers;

  long http_response_code;
} AsyncCompleteData;

typedef struct {
  int on_err;
  lua_State *lstate;
  CURLcode res;
  String error;
} AsyncErrData;

#endif  // NVIM_API_FETCH_H
