#ifndef NVIM_FETCH_H
#define NVIM_FETCH_H

#include <bits/stdint-uintn.h>
#include <curl/curl.h>
#include <lua.h>

#include "nvim/api/keysets.h"
#include "nvim/api/private/defs.h"

int nlua_fetch(lua_State *lstate);

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
  CURL *easy_handle;
  int on_complete;
  int on_err;
  curl_mime *multipart_form;
  char *data;
  struct curl_slist *headers;
  lua_State *lstate;
} FetchData;

typedef struct {
  int on_complete;
  lua_State *lstate;

  String response;
  HeaderMemoryStruct headers;

  long http_response_code;
} AsyncCompleteData;

typedef struct {
  int on_err;
  lua_State *lstate;
  CURLcode res;
  String error;
} AsyncErrData;

#endif  // NVIM_FETCH_H
