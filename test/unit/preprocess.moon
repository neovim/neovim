-- helps managing loading different headers into the LuaJIT ffi. Untested on
-- windows, will probably need quite a bit of adjustment to run there.

ffi = require("ffi")

ccs = {}

env_cc = os.getenv("CC")
if env_cc
  table.insert(ccs, {path: "/usr/bin/env #{env_cc}", type: "gcc"})

if ffi.os == "Windows"
  table.insert(ccs, {path: "cl", type: "msvc"})

table.insert(ccs, {path: "/usr/bin/env cc", type: "gcc"})
table.insert(ccs, {path: "/usr/bin/env gcc", type: "gcc"})
table.insert(ccs, {path: "/usr/bin/env gcc-4.9", type: "gcc"})
table.insert(ccs, {path: "/usr/bin/env gcc-4.8", type: "gcc"})
table.insert(ccs, {path: "/usr/bin/env gcc-4.7", type: "gcc"})
table.insert(ccs, {path: "/usr/bin/env clang", type: "clang"})
table.insert(ccs, {path: "/usr/bin/env icc", type: "gcc"})

quote_me = '[^%w%+%-%=%@%_%/]' -- complement (needn't quote)
shell_quote = (str) ->
  if string.find(str, quote_me) or str == '' then
    "'" .. string.gsub(str, "'", [['"'"']]) .. "'"
  else
    str

-- parse Makefile format dependencies into a Lua table
parse_make_deps = (deps) ->
  -- remove line breaks and line concatenators
  deps = deps\gsub("\n", "")\gsub("\\", "")

  -- remove the Makefile "target:" element
  deps = deps\gsub(".+:", "")

  -- remove redundant spaces
  deps = deps\gsub("  +", " ")

  -- split according to token (space in this case)
  headers = {}
  for token in deps\gmatch("[^%s]+")
    -- headers[token] = true
    headers[#headers + 1] = token

  -- resolve path redirections (..) to normalize all paths
  for i, v in ipairs(headers)
    -- double dots (..)
    headers[i] = v\gsub("/[^/%s]+/%.%.", "")

    -- single dot (.)
    headers[i] = v\gsub("%./", "")

  headers

-- will produce a string that represents a meta C header file that includes
-- all the passed in headers. I.e.:
--
-- headerize({"stdio.h", "math.h", true}
-- produces:
-- #include <stdio.h>
-- #include <math.h>
--
-- headerize({"vim.h", "memory.h", false}
-- produces:
-- #include "vim.h"
-- #include "memory.h"
headerize = (headers, global) ->
  pre = '"'
  post = pre
  if global
    pre = "<"
    post = ">"

  formatted = ["#include #{pre}#{hdr}#{post}" for hdr in *headers]
  table.concat(formatted, "\n")

class Gcc
  -- preprocessor flags that will hopefully make the compiler produce C
  -- declarations that the LuaJIT ffi understands.
  @@preprocessor_extra_flags = {
   '-D "aligned(ARGS)="',
   '-D "__attribute__(ARGS)="',
   '-D "__asm(ARGS)="',
   '-D "__asm__(ARGS)="',
   '-D "__inline__="',
   '-D_GNU_SOURCE',
   '-DINCLUDE_GENERATED_DECLARATIONS'
  }

  new: (path) =>
    @path = path

  add_to_include_path: (...) =>
      paths = {...}
      for path in *paths
          directive = '-I ' .. '"' .. path .. '"'
          @@preprocessor_extra_flags[#@@preprocessor_extra_flags + 1] = directive

  -- returns a list of the headers files upon which this file relies
  dependencies: (hdr) =>
    out = io.popen("#{@path} -M #{hdr} 2>&1")
    deps = out\read("*a")
    out\close!

    if deps
      parse_make_deps(deps)
    else
      nil

  -- returns a stream representing a preprocessed form of the passed-in
  -- headers. Don't forget to close the stream by calling the close() method
  -- on it.
  preprocess_stream: (...) =>
    paths = {...}
    -- create pseudo-header
    pseudoheader = headerize(paths, false)
    defines = table.concat(@@preprocessor_extra_flags, ' ')
    cmd = ("echo $hdr | #{@path} #{defines} -std=c99 -P -E -")\gsub('$hdr', shell_quote(pseudoheader))
    -- lfs = require("lfs")
    -- print("CWD: #{lfs.currentdir!}")
    -- print("CMD: #{cmd}")
    -- io.stderr\write("CWD: #{lfs.currentdir!}\n")
    -- io.stderr\write("CMD: #{cmd}\n")
    io.popen(cmd)

class Clang extends Gcc
class Msvc extends Gcc

type_to_class = {
  "gcc": Gcc,
  "clang": Clang,
  "msvc": Msvc
}

find_best_cc = (ccs) ->
  for _, meta in pairs(ccs)
    version = io.popen("#{meta.path} -v 2>&1")
    version\close!
    if version
      return type_to_class[meta.type](meta.path)
  nil

-- find the best cc. If os.exec causes problems on windows (like popping up
-- a console window) we might consider using something like this:
-- http://scite-ru.googlecode.com/svn/trunk/pack/tools/LuaLib/shell.html#exec
cc = nil
if cc == nil
  cc = find_best_cc(ccs)

return {
  includes: (hdr) -> cc\dependencies(hdr)
  preprocess_stream: (...) -> cc\preprocess_stream(...)
  add_to_include_path: (...) -> cc\add_to_include_path(...)
}
