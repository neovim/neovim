#!/usr/bin/env nvim -l

-- Lints C files in the Neovim source tree.
-- Based on Google "cpplint", modified for Neovim.
--
-- Test coverage: `test/functional/script/clint_spec.lua`
--
-- This can get very confused by /* and // inside strings! We do a small hack,
-- which is to ignore //'s with "'s after them on the same line, but it is far
-- from perfect (in either direction).

local vim = vim

-- Error categories used for filtering
local ERROR_CATEGORIES = {
  'build/endif_comment',
  'build/header_guard',
  'build/include_defs',
  'build/defs_header',
  'build/printf_format',
  'build/storage_class',
  'build/init_macro',
  'readability/bool',
  'readability/multiline_comment',
  -- Dropped 'readability/multiline_string' detection because it is too buggy, and uncommon.
  -- 'readability/multiline_string',
  'readability/nul',
  'readability/utf8',
  'readability/increment',
  'runtime/arrays',
  'runtime/int',
  'runtime/memset',
  'runtime/printf',
  'runtime/printf_format',
  'runtime/threadsafe_fn',
  'runtime/deprecated',
  'whitespace/indent',
  'whitespace/operators',
  'whitespace/cast',
}

-- Default filters (empty by default)
local DEFAULT_FILTERS = {}

-- Assembly state constants
local NO_ASM = 0 -- Outside of inline assembly block
local INSIDE_ASM = 1 -- Inside inline assembly block
local END_ASM = 2 -- Last line of inline assembly block
local BLOCK_ASM = 3 -- The whole block is an inline assembly block

-- Regex compilation cache
local regexp_compile_cache = {}

-- Error suppression state
local error_suppressions = {}
local error_suppressions_2 = {}

-- Configuration
local valid_extensions = { c = true, h = true }

-- Precompiled regex patterns (only the ones still used)
local RE_SUPPRESSION = vim.regex([[\<NOLINT\>]])
local RE_COMMENTLINE = vim.regex([[^\s*//]])
local RE_PATTERN_INCLUDE = vim.regex([[^\s*#\s*include\s*\([<"]\)\([^>"]*\)[>"].*$]])

-- Assembly block matching (using Lua pattern instead of vim.regex for simplicity)
local function match_asm(line)
  return line:find('^%s*asm%s*[{(]')
    or line:find('^%s*_asm%s*[{(]')
    or line:find('^%s*__asm%s*[{(]')
    or line:find('^%s*__asm__%s*[{(]')
end

-- Threading function replacements
local threading_list = {
  { 'asctime(', 'os_asctime_r(' },
  { 'ctime(', 'os_ctime_r(' },
  { 'getgrgid(', 'os_getgrgid_r(' },
  { 'getgrnam(', 'os_getgrnam_r(' },
  { 'getlogin(', 'os_getlogin_r(' },
  { 'getpwnam(', 'os_getpwnam_r(' },
  { 'getpwuid(', 'os_getpwuid_r(' },
  { 'gmtime(', 'os_gmtime_r(' },
  { 'localtime(', 'os_localtime_r(' },
  { 'strtok(', 'os_strtok_r(' },
  { 'ttyname(', 'os_ttyname_r(' },
  { 'asctime_r(', 'os_asctime_r(' },
  { 'ctime_r(', 'os_ctime_r(' },
  { 'getgrgid_r(', 'os_getgrgid_r(' },
  { 'getgrnam_r(', 'os_getgrnam_r(' },
  { 'getlogin_r(', 'os_getlogin_r(' },
  { 'getpwnam_r(', 'os_getpwnam_r(' },
  { 'getpwuid_r(', 'os_getpwuid_r(' },
  { 'gmtime_r(', 'os_gmtime_r(' },
  { 'localtime_r(', 'os_localtime_r(' },
  { 'strtok_r(', 'os_strtok_r(' },
  { 'ttyname_r(', 'os_ttyname_r(' },
}

-- Memory function replacements
local memory_functions = {
  { 'malloc(', 'xmalloc(' },
  { 'calloc(', 'xcalloc(' },
  { 'realloc(', 'xrealloc(' },
  { 'strdup(', 'xstrdup(' },
  { 'free(', 'xfree(' },
}
local memory_ignore_pattern = vim.regex([[src/nvim/memory.c$]])

-- OS function replacements
local os_functions = {
  { 'setenv(', 'os_setenv(' },
  { 'getenv(', 'os_getenv(' },
  { '_wputenv(', 'os_setenv(' },
  { '_putenv_s(', 'os_setenv(' },
  { 'putenv(', 'os_setenv(' },
  { 'unsetenv(', 'os_unsetenv(' },
}

-- CppLintState class equivalent
local CppLintState = {}
CppLintState.__index = CppLintState

function CppLintState.new()
  local self = setmetatable({}, CppLintState)
  self.verbose_level = 1
  self.error_count = 0
  self.filters = vim.deepcopy(DEFAULT_FILTERS)
  self.counting = 'total'
  self.errors_by_category = {}
  self.stdin_filename = ''
  self.output_format = 'emacs'
  self.record_errors_file = nil
  self.suppressed_errors = vim.defaulttable(function()
    return vim.defaulttable(function()
      return {}
    end)
  end)
  return self
end

function CppLintState:set_output_format(output_format)
  self.output_format = output_format
end

function CppLintState:set_verbose_level(level)
  local last_verbose_level = self.verbose_level
  self.verbose_level = level
  return last_verbose_level
end

function CppLintState:set_counting_style(counting_style)
  self.counting = counting_style
end

function CppLintState:set_filters(filters)
  self.filters = vim.deepcopy(DEFAULT_FILTERS)
  for filt in vim.gsplit(filters, ',', { trimempty = true }) do
    local clean_filt = vim.trim(filt)
    if clean_filt ~= '' then
      table.insert(self.filters, clean_filt)
    end
  end

  for _, filt in ipairs(self.filters) do
    if not (filt:sub(1, 1) == '+' or filt:sub(1, 1) == '-') then
      error('Every filter in --filters must start with + or - (' .. filt .. ' does not)')
    end
  end
end

function CppLintState:reset_error_counts()
  self.error_count = 0
  self.errors_by_category = {}
end

function CppLintState:increment_error_count(category)
  self.error_count = self.error_count + 1
  if self.counting == 'toplevel' or self.counting == 'detailed' then
    local cat = category
    if self.counting ~= 'detailed' then
      cat = category:match('([^/]+)') or category
    end
    if not self.errors_by_category[cat] then
      self.errors_by_category[cat] = 0
    end
    self.errors_by_category[cat] = self.errors_by_category[cat] + 1
  end
end

function CppLintState:print_error_counts()
  for category, count in pairs(self.errors_by_category) do
    io.write(string.format("Category '%s' errors found: %d\n", category, count))
  end
  if self.error_count > 0 then
    io.write(string.format('Total errors found: %d\n', self.error_count))
  end
end

function CppLintState:suppress_errors_from(fname)
  if not fname then
    return
  end

  local ok, content = pcall(vim.fn.readfile, fname)
  if not ok then
    return
  end

  for _, line in ipairs(content) do
    local ok2, data = pcall(vim.json.decode, line)
    if ok2 then
      local fname2, lines, category = data[1], data[2], data[3]
      local lines_tuple = vim.tbl_islist(lines) and lines or { lines }
      self.suppressed_errors[fname2][vim.inspect(lines_tuple)][category] = true
    end
  end
end

function CppLintState:record_errors_to(fname)
  if not fname then
    return
  end
  self.record_errors_file = io.open(fname, 'w')
end

-- Global state instance
local cpplint_state = CppLintState.new()

-- Utility functions
local function match(pattern, s)
  if not regexp_compile_cache[pattern] then
    regexp_compile_cache[pattern] = vim.regex(pattern)
  end
  local s_idx, e_idx = regexp_compile_cache[pattern]:match_str(s)
  if s_idx then
    local match_obj = {}
    match_obj.start = s_idx
    match_obj.finish = e_idx
    function match_obj.group(n)
      if n == 0 then
        return s:sub(s_idx + 1, e_idx)
      else
        -- For subgroups, we need to use a different approach
        -- This is a simplified version - full regex groups would need more complex handling
        return s:sub(s_idx + 1, e_idx)
      end
    end
    return match_obj
  end
  return nil
end

-- NOLINT suppression functions
local function parse_nolint_suppressions(raw_line, linenum)
  local s_idx, e_idx = RE_SUPPRESSION:match_str(raw_line)
  if not s_idx then
    return
  end

  -- Extract what comes after NOLINT, looking for optional (category)
  local after_nolint = raw_line:sub(e_idx + 1)
  local category = after_nolint:match('^%s*(%([^)]*%))')

  if not category or category == '(*)' then
    -- Suppress all errors on this line
    if not error_suppressions[vim.NIL] then
      error_suppressions[vim.NIL] = {}
    end
    table.insert(error_suppressions[vim.NIL], linenum)
  else
    -- Extract category name from parentheses
    local cat_name = category:match('^%((.-)%)$')
    if cat_name then
      for _, cat in ipairs(ERROR_CATEGORIES) do
        if cat == cat_name then
          if not error_suppressions[cat_name] then
            error_suppressions[cat_name] = {}
          end
          table.insert(error_suppressions[cat_name], linenum)
          break
        end
      end
    end
  end
end

local function reset_nolint_suppressions()
  error_suppressions = {}
end

local function reset_known_error_suppressions()
  error_suppressions_2 = {}
end

local function is_error_suppressed_by_nolint(category, linenum)
  local cat_suppressed = error_suppressions[category] or {}
  local all_suppressed = error_suppressions[vim.NIL] or {}

  for _, line in ipairs(cat_suppressed) do
    if line == linenum then
      return true
    end
  end
  for _, line in ipairs(all_suppressed) do
    if line == linenum then
      return true
    end
  end
  return false
end

local function is_error_in_suppressed_errors_list(category, linenum)
  local key = category .. ':' .. linenum
  return error_suppressions_2[key] == true
end

-- FileInfo class equivalent
local FileInfo = {}
FileInfo.__index = FileInfo

function FileInfo.new(filename)
  local self = setmetatable({}, FileInfo)
  self._filename = filename
  return self
end

function FileInfo:full_name()
  local abspath = vim.fn.fnamemodify(self._filename, ':p')
  return abspath:gsub('\\', '/')
end

function FileInfo:relative_path()
  local fullname = self:full_name()

  if vim.fn.filereadable(fullname) == 1 then
    -- Find git repository root using vim.fs.root
    local git_root = vim.fs.root(fullname, '.git')
    if git_root then
      local root_dir = vim.fs.joinpath(git_root, 'src', 'nvim')
      local relpath = vim.fs.relpath(root_dir, fullname)
      if relpath then
        return relpath
      end
    end
  end

  return fullname
end

-- Error reporting
local function should_print_error(category, confidence, linenum)
  if is_error_suppressed_by_nolint(category, linenum) then
    return false
  end
  if is_error_in_suppressed_errors_list(category, linenum) then
    return false
  end
  if confidence < cpplint_state.verbose_level then
    return false
  end

  local is_filtered = false
  for _, one_filter in ipairs(cpplint_state.filters) do
    if one_filter:sub(1, 1) == '-' then
      if category:find(one_filter:sub(2), 1, true) == 1 then
        is_filtered = true
      end
    elseif one_filter:sub(1, 1) == '+' then
      if category:find(one_filter:sub(2), 1, true) == 1 then
        is_filtered = false
      end
    end
  end

  return not is_filtered
end

local function error_func(filename, linenum, category, confidence, message)
  if should_print_error(category, confidence, linenum) then
    cpplint_state:increment_error_count(category)

    if cpplint_state.output_format == 'vs7' then
      io.write(
        string.format('%s(%s):  %s  [%s] [%d]\n', filename, linenum, message, category, confidence)
      )
    elseif cpplint_state.output_format == 'eclipse' then
      io.write(
        string.format(
          '%s:%s: warning: %s  [%s] [%d]\n',
          filename,
          linenum,
          message,
          category,
          confidence
        )
      )
    elseif cpplint_state.output_format == 'gh_action' then
      io.write(
        string.format(
          '::error file=%s,line=%s::%s  [%s] [%d]\n',
          filename,
          linenum,
          message,
          category,
          confidence
        )
      )
    else
      io.write(
        string.format('%s:%s:  %s  [%s] [%d]\n', filename, linenum, message, category, confidence)
      )
    end
  end
end

-- String processing functions
local function is_cpp_string(line)
  line = line:gsub('\\\\', 'XX')
  local quote_count = select(2, line:gsub('"', ''))
  local escaped_quote_count = select(2, line:gsub('\\"', ''))
  local combined_quote_count = select(2, line:gsub("'\"'", ''))
  return ((quote_count - escaped_quote_count - combined_quote_count) % 2) == 1
end

local function cleanse_comments(line)
  local commentpos = line:find('//')
  if commentpos and not is_cpp_string(line:sub(1, commentpos - 1)) then
    line = line:sub(1, commentpos - 1):gsub('%s+$', '')
  end
  -- Remove /* */ comments
  line = line:gsub('/%*.-%*/', '')
  return line
end

-- CleansedLines class equivalent
local CleansedLines = {}
CleansedLines.__index = CleansedLines

function CleansedLines.new(lines, init_lines)
  local self = setmetatable({}, CleansedLines)
  self.elided = {}
  self.lines = {}
  self.raw_lines = lines
  self._num_lines = #lines
  self.init_lines = init_lines
  self.lines_without_raw_strings = lines
  self.elided_with_space_strings = {}

  for linenum = 1, #self.lines_without_raw_strings do
    local line = self.lines_without_raw_strings[linenum]
    table.insert(self.lines, cleanse_comments(line))

    local elided = self:_collapse_strings(line)
    table.insert(self.elided, cleanse_comments(elided))

    local elided_spaces = self:_collapse_strings(line, true)
    table.insert(self.elided_with_space_strings, cleanse_comments(elided_spaces))
  end

  return self
end

function CleansedLines:num_lines()
  return self._num_lines
end

function CleansedLines:_collapse_strings(elided, keep_spaces)
  if not RE_PATTERN_INCLUDE:match_str(elided) then
    -- Remove escaped characters
    elided = elided:gsub('\\[abfnrtv?"\\\'\\]', keep_spaces and ' ' or '')
    elided = elided:gsub('\\%d+', keep_spaces and ' ' or '')
    elided = elided:gsub('\\x[0-9a-fA-F]+', keep_spaces and ' ' or '')

    if keep_spaces then
      elided = elided:gsub("'([^'])'", function(c)
        return "'" .. string.rep(' ', #c) .. "'"
      end)
      elided = elided:gsub('"([^"]*)"', function(c)
        return '"' .. string.rep(' ', #c) .. '"'
      end)
    else
      elided = elided:gsub("'([^'])'", "''")
      elided = elided:gsub('"([^"]*)"', '""')
    end
  end
  return elided
end

-- Helper functions for argument parsing
local function print_usage(message)
  local usage = [[
Syntax: clint.lua [--verbose=#] [--output=vs7] [--filter=-x,+y,...]
                 [--counting=total|toplevel|detailed] [--root=subdir]
                 [--linelength=digits] [--record-errors=file]
                 [--suppress-errors=file] [--stdin-filename=filename]
        <file> [file] ...

  The style guidelines this tries to follow are those in
    https://neovim.io/doc/user/dev_style.html#dev-style

  Note: This is Google's https://github.com/cpplint/cpplint modified for use
  with the Neovim project.

  Every problem is given a confidence score from 1-5, with 5 meaning we are
  certain of the problem, and 1 meaning it could be a legitimate construct.
  This will miss some errors, and is not a substitute for a code review.

  To suppress false-positive errors of a certain category, add a
  'NOLINT(category)' comment to the line.  NOLINT or NOLINT(*)
  suppresses errors of all categories on that line.

  The files passed in will be linted; at least one file must be provided.
  Default linted extensions are .cc, .cpp, .cu, .cuh and .h.  Change the
  extensions with the --extensions flag.

  Flags:

    output=vs7
      By default, the output is formatted to ease emacs parsing.  Visual Studio
      compatible output (vs7) may also be used.  Other formats are unsupported.

    verbose=#
      Specify a number 0-5 to restrict errors to certain verbosity levels.

    filter=-x,+y,...
      Specify a comma-separated list of category-filters to apply: only
      error messages whose category names pass the filters will be printed.
      (Category names are printed with the message and look like
      "[whitespace/indent]".)  Filters are evaluated left to right.
      "-FOO" and "FOO" means "do not print categories that start with FOO".
      "+FOO" means "do print categories that start with FOO".

      Examples: --filter=-whitespace,+whitespace/braces
                --filter=whitespace,runtime/printf,+runtime/printf_format
                --filter=-,+build/include_what_you_use

      To see a list of all the categories used in cpplint, pass no arg:
         --filter=

    counting=total|toplevel|detailed
      The total number of errors found is always printed. If
      'toplevel' is provided, then the count of errors in each of
      the top-level categories like 'build' and 'whitespace' will
      also be printed. If 'detailed' is provided, then a count
      is provided for each category.

    root=subdir
      The root directory used for deriving header guard CPP variable.
      By default, the header guard CPP variable is calculated as the relative
      path to the directory that contains .git, .hg, or .svn.  When this flag
      is specified, the relative path is calculated from the specified
      directory. If the specified directory does not exist, this flag is
      ignored.

      Examples:
        Assuing that src/.git exists, the header guard CPP variables for
        src/chrome/browser/ui/browser.h are:

        No flag => CHROME_BROWSER_UI_BROWSER_H_
        --root=chrome => BROWSER_UI_BROWSER_H_
        --root=chrome/browser => UI_BROWSER_H_

    linelength=digits
      This is the allowed line length for the project. The default value is
      80 characters.

      Examples:
        --linelength=120

    extensions=extension,extension,...
      The allowed file extensions that cpplint will check

      Examples:
        --extensions=hpp,cpp

    record-errors=file
      Record errors to the given location. This file may later be used for error
      suppression using suppress-errors flag.

    suppress-errors=file
      Errors listed in the given file will not be reported.

    stdin-filename=filename
      Use specified filename when reading from stdin (file "-").
]]

  if message then
    io.stderr:write(usage .. '\nFATAL ERROR: ' .. message .. '\n')
    os.exit(1)
  else
    io.write(usage)
    os.exit(0)
  end
end

local function print_categories()
  for _, cat in ipairs(ERROR_CATEGORIES) do
    io.write('  ' .. cat .. '\n')
  end
  os.exit(0)
end

-- Argument parsing
local function parse_arguments(args)
  local filenames = {}
  local opts = {
    output_format = 'emacs',
    verbose_level = 1,
    filters = '',
    counting_style = 'total',
    extensions = { 'c', 'h' },
    record_errors_file = nil,
    suppress_errors_file = nil,
    stdin_filename = '',
  }

  local i = 1
  while i <= #args do
    local arg = args[i]

    if arg == '--help' then
      print_usage()
    elseif arg:sub(1, 9) == '--output=' then
      local format = arg:sub(10)
      if
        format ~= 'emacs'
        and format ~= 'vs7'
        and format ~= 'eclipse'
        and format ~= 'gh_action'
      then
        print_usage('The only allowed output formats are emacs, vs7 and eclipse.')
      end
      opts.output_format = format
    elseif arg:sub(1, 10) == '--verbose=' then
      opts.verbose_level = tonumber(arg:sub(11))
    elseif arg:sub(1, 9) == '--filter=' then
      opts.filters = arg:sub(10)
      if opts.filters == '' then
        print_categories()
      end
    elseif arg:sub(1, 12) == '--counting=' then
      local style = arg:sub(13)
      if style ~= 'total' and style ~= 'toplevel' and style ~= 'detailed' then
        print_usage('Valid counting options are total, toplevel, and detailed')
      end
      opts.counting_style = style
    elseif arg:sub(1, 13) == '--extensions=' then
      local exts = arg:sub(14)
      opts.extensions = {}
      for ext in vim.gsplit(exts, ',', { trimempty = true }) do
        table.insert(opts.extensions, vim.trim(ext))
      end
    elseif arg:sub(1, 16) == '--record-errors=' then
      opts.record_errors_file = arg:sub(17)
    elseif arg:sub(1, 18) == '--suppress-errors=' then
      opts.suppress_errors_file = arg:sub(19)
    elseif arg:sub(1, 17) == '--stdin-filename=' then
      opts.stdin_filename = arg:sub(18)
    elseif arg:sub(1, 2) == '--' then
      print_usage('Unknown option: ' .. arg)
    else
      table.insert(filenames, arg)
    end

    i = i + 1
  end

  if #filenames == 0 then
    print_usage('No files were specified.')
  end

  return filenames, opts
end

-- Lint checking functions

local function find_next_multiline_comment_start(lines, lineix)
  while lineix <= #lines do
    if lines[lineix]:find('^%s*/%*') then
      if not lines[lineix]:find('%*/', 1, true) then
        -- Check if this line ends with backslash (line continuation)
        -- If so, don't treat it as a multiline comment start
        local line = lines[lineix]
        if not line:find('\\%s*$') then
          return lineix
        end
      end
    end
    lineix = lineix + 1
  end
  return #lines + 1
end

local function find_next_multiline_comment_end(lines, lineix)
  while lineix <= #lines do
    if lines[lineix]:find('%*/%s*$') then
      return lineix
    end
    lineix = lineix + 1
  end
  return #lines + 1
end

local function remove_multiline_comments_from_range(lines, begin, finish)
  for i = begin, finish do
    lines[i] = '// dummy'
  end
end

local function remove_multiline_comments(filename, lines, error)
  local lineix = 1
  while lineix <= #lines do
    local lineix_begin = find_next_multiline_comment_start(lines, lineix)
    if lineix_begin > #lines then
      return
    end
    local lineix_end = find_next_multiline_comment_end(lines, lineix_begin)
    if lineix_end > #lines then
      error(
        filename,
        lineix_begin,
        'readability/multiline_comment',
        5,
        'Could not find end of multi-line comment'
      )
      return
    end
    remove_multiline_comments_from_range(lines, lineix_begin, lineix_end)
    lineix = lineix_end + 1
  end
end

local function check_for_header_guard(filename, lines, error)
  if filename:match('%.c%.h$') or FileInfo.new(filename):relative_path() == 'func_attr.h' then
    return
  end

  local found_pragma = false
  for _, line in ipairs(lines) do
    if line:find('#pragma%s+once') then
      found_pragma = true
      break
    end
  end

  if not found_pragma then
    error(filename, 1, 'build/header_guard', 5, 'No "#pragma once" found in header')
  end
end

local function check_includes(filename, lines, error)
  if
    filename:match('%.c%.h$')
    or filename:match('%.in%.h$')
    or FileInfo.new(filename):relative_path() == 'func_attr.h'
    or FileInfo.new(filename):relative_path() == 'os/pty_proc.h'
  then
    return
  end

  local check_includes_ignore = {
    'src/nvim/api/private/validate.h',
    'src/nvim/assert_defs.h',
    'src/nvim/channel.h',
    'src/nvim/charset.h',
    'src/nvim/eval/typval.h',
    'src/nvim/event/multiqueue.h',
    'src/nvim/garray.h',
    'src/nvim/globals.h',
    'src/nvim/highlight.h',
    'src/nvim/lua/executor.h',
    'src/nvim/main.h',
    'src/nvim/mark.h',
    'src/nvim/msgpack_rpc/channel_defs.h',
    'src/nvim/msgpack_rpc/unpacker.h',
    'src/nvim/option.h',
    'src/nvim/os/pty_conpty_win.h',
    'src/nvim/os/pty_proc_win.h',
  }

  local skip_headers = {
    'auto/config.h',
    'klib/klist.h',
    'klib/kvec.h',
    'mpack/mpack_core.h',
    'mpack/object.h',
    'nvim/func_attr.h',
    'termkey/termkey.h',
    'vterm/vterm.h',
    'xdiff/xdiff.h',
  }

  for _, ignore in ipairs(check_includes_ignore) do
    if filename:match(ignore .. '$') then
      return
    end
  end

  for i, line in ipairs(lines) do
    local matched = match('#\\s*include\\s*"([^"]*)"', line)
    if matched then
      local name = line:match('#\\s*include\\s*"([^"]*)"')
      local should_skip = false
      for _, skip in ipairs(skip_headers) do
        if name == skip then
          should_skip = true
          break
        end
      end

      if
        not should_skip
        and not name:match('%.h%.generated%.h$')
        and not name:match('/defs%.h$')
        and not name:match('_defs%.h$')
        and not name:match('%.h%.inline%.generated%.h$')
        and not name:match('_defs%.generated%.h$')
        and not name:match('_enum%.generated%.h$')
      then
        error(
          filename,
          i - 1,
          'build/include_defs',
          5,
          'Headers should not include non-"_defs" headers'
        )
      end
    end
  end
end

local function check_non_symbols(filename, lines, error)
  for i, line in ipairs(lines) do
    if line:match('^EXTERN ') or line:match('^extern ') then
      error(
        filename,
        i - 1,
        'build/defs_header',
        5,
        '"_defs" headers should not contain extern variables'
      )
    end
  end
end

local function check_for_bad_characters(filename, lines, error)
  for linenum, line in ipairs(lines) do
    if line:find('\239\187\191') then -- UTF-8 BOM
      error(
        filename,
        linenum - 1,
        'readability/utf8',
        5,
        'Line contains invalid UTF-8 (or Unicode replacement character).'
      )
    end
    if line:find('\0') then
      error(filename, linenum - 1, 'readability/nul', 5, 'Line contains NUL byte.')
    end
  end
end

local function check_for_multiline_comments_and_strings(filename, clean_lines, linenum, error)
  -- Use elided line (with strings collapsed) to avoid false positives from /* */ in strings
  local line = clean_lines.elided[linenum + 1]
  if not line then
    return
  end

  -- Remove all \\ (escaped backslashes) from the line. They are OK, and the
  -- second (escaped) slash may trigger later \" detection erroneously.
  line = line:gsub('\\\\', '')

  local comment_count = select(2, line:gsub('/%*', ''))
  local comment_end_count = select(2, line:gsub('%*/', ''))
  -- Only warn if there are actually more opening than closing comments
  -- (accounting for the possibility that this is a multi-line comment that continues)
  if comment_count > comment_end_count and comment_count > 0 then
    error(
      filename,
      linenum,
      'readability/multiline_comment',
      5,
      'Complex multi-line /*...*/-style comment found. '
        .. 'Lint may give bogus warnings.  '
        .. 'Consider replacing these with //-style comments, '
        .. 'with #if 0...#endif, '
        .. 'or with more clearly structured multi-line comments.'
    )
  end

  -- Dropped 'readability/multiline_string' detection because it produces too many false positives
  -- with escaped quotes in C strings and character literals.
end

local function check_for_old_style_comments(filename, line, linenum, error)
  if line:find('/%*') and line:sub(-1) ~= '\\' and not RE_COMMENTLINE:match_str(line) then
    error(
      filename,
      linenum,
      'readability/old_style_comment',
      5,
      '/*-style comment found, it should be replaced with //-style.  '
        .. '/*-style comments are only allowed inside macros.  '
        .. 'Note that you should not use /*-style comments to document '
        .. 'macros itself, use doxygen-style comments for this.'
    )
  end
end

local function check_posix_threading(filename, clean_lines, linenum, error)
  local line = clean_lines.elided[linenum + 1]

  for _, pair in ipairs(threading_list) do
    local single_thread_function, multithread_safe_function = pair[1], pair[2]
    local start_pos = line:find(single_thread_function, 1, true)

    if start_pos then
      local prev_char = start_pos > 1 and line:sub(start_pos - 1, start_pos - 1) or ''
      if
        start_pos == 1
        or (
          not prev_char:match('%w')
          and prev_char ~= '_'
          and prev_char ~= '.'
          and prev_char ~= '>'
        )
      then
        error(
          filename,
          linenum,
          'runtime/threadsafe_fn',
          2,
          'Use '
            .. multithread_safe_function
            .. '...) instead of '
            .. single_thread_function
            .. '...). If it is missing, consider implementing it;'
            .. ' see os_localtime_r for an example.'
        )
      end
    end
  end
end

local function check_memory_functions(filename, clean_lines, linenum, error)
  if memory_ignore_pattern:match_str(filename) then
    return
  end

  local line = clean_lines.elided[linenum + 1]

  for _, pair in ipairs(memory_functions) do
    local func, suggested_func = pair[1], pair[2]
    local start_pos = line:find(func, 1, true)

    if start_pos then
      local prev_char = start_pos > 1 and line:sub(start_pos - 1, start_pos - 1) or ''
      if
        start_pos == 1
        or (
          not prev_char:match('%w')
          and prev_char ~= '_'
          and prev_char ~= '.'
          and prev_char ~= '>'
        )
      then
        error(
          filename,
          linenum,
          'runtime/memory_fn',
          2,
          'Use ' .. suggested_func .. '...) instead of ' .. func .. '...).'
        )
      end
    end
  end
end

local function check_os_functions(filename, clean_lines, linenum, error)
  local line = clean_lines.elided[linenum + 1]

  for _, pair in ipairs(os_functions) do
    local func, suggested_func = pair[1], pair[2]
    local start_pos = line:find(func, 1, true)

    if start_pos then
      local prev_char = start_pos > 1 and line:sub(start_pos - 1, start_pos - 1) or ''
      if
        start_pos == 1
        or (
          not prev_char:match('%w')
          and prev_char ~= '_'
          and prev_char ~= '.'
          and prev_char ~= '>'
        )
      then
        error(
          filename,
          linenum,
          'runtime/os_fn',
          2,
          'Use ' .. suggested_func .. '...) instead of ' .. func .. '...).'
        )
      end
    end
  end
end

local function check_language(filename, clean_lines, linenum, error)
  local line = clean_lines.elided[linenum + 1]
  if not line or line == '' then
    return
  end

  -- Check for verboten C basic types
  local short_regex = vim.regex([[\<short\>]])
  local long_long_regex = vim.regex([[\<long\> \+\<long\>]])

  if short_regex:match_str(line) then
    error(
      filename,
      linenum,
      'runtime/int',
      4,
      'Use int16_t/int64_t/etc, rather than the C type short'
    )
  elseif long_long_regex:match_str(line) then
    error(
      filename,
      linenum,
      'runtime/int',
      4,
      'Use int16_t/int64_t/etc, rather than the C type long long'
    )
  end

  -- Check for snprintf with non-zero literal size
  local snprintf_match = line:match('snprintf%s*%([^,]*,%s*([0-9]+)%s*,')
  if snprintf_match and snprintf_match ~= '0' then
    error(
      filename,
      linenum,
      'runtime/printf',
      3,
      'If you can, use sizeof(...) instead of ' .. snprintf_match .. ' as the 2nd arg to snprintf.'
    )
  end

  -- Check for sprintf (use vim.regex for proper word boundaries)
  local sprintf_regex = vim.regex([[\<sprintf\>]])
  if sprintf_regex:match_str(line) then
    error(filename, linenum, 'runtime/printf', 5, 'Use snprintf instead of sprintf.')
  end

  -- Check for strncpy (use vim.regex for proper word boundaries)
  local strncpy_regex = vim.regex([[\<strncpy\>]])
  local strncpy_upper_regex = vim.regex([[\<STRNCPY\>]])
  if strncpy_regex:match_str(line) then
    error(
      filename,
      linenum,
      'runtime/printf',
      4,
      'Use xstrlcpy, xmemcpyz or snprintf instead of strncpy (unless this is from Vim)'
    )
  elseif strncpy_upper_regex:match_str(line) then
    error(
      filename,
      linenum,
      'runtime/printf',
      4,
      'Use xstrlcpy, xmemcpyz or snprintf instead of STRNCPY (unless this is from Vim)'
    )
  end

  -- Check for strcpy (use vim.regex for proper word boundaries)
  local strcpy_regex = vim.regex([[\<strcpy\>]])
  if strcpy_regex:match_str(line) then
    error(
      filename,
      linenum,
      'runtime/printf',
      4,
      'Use xstrlcpy, xmemcpyz or snprintf instead of strcpy'
    )
  end

  -- Check for memset with wrong argument order: memset(buf, sizeof(buf), 0)
  -- Pattern: memset(arg1, arg2, 0) where arg2 is NOT a valid fill value
  local memset_start = line:find('memset%s*%([^)]*,%s*[^,]*,%s*0%s*%)')
  if memset_start then
    -- Extract the full memset call
    local memset_part = line:sub(memset_start)
    local first_comma = memset_part:find(',')
    if first_comma then
      local after_first = memset_part:sub(first_comma + 1)
      local second_comma = after_first:find(',')
      if second_comma then
        local second_arg = vim.trim(after_first:sub(1, second_comma - 1))
        local first_arg = vim.trim(memset_part:match('memset%s*%(%s*([^,]*)%s*,'))

        -- Check if second_arg is NOT a simple literal value
        if
          second_arg ~= ''
          and second_arg ~= "''"
          and not second_arg:match('^%-?%d+$')
          and not second_arg:match('^0x[0-9a-fA-F]+$')
        then
          error(
            filename,
            linenum,
            'runtime/memset',
            4,
            'Did you mean "memset(' .. first_arg .. ', 0, ' .. second_arg .. ')"?'
          )
        end
      end
    end
  end

  -- Detect variable-length arrays
  -- Pattern: type varname[size]; where type is an identifier and varname starts with lowercase
  local var_type = line:match('%s*(%w+)%s+')
  if var_type and var_type ~= 'return' and var_type ~= 'delete' then
    -- Look for array declaration pattern
    local array_size = line:match('%w+%s+[a-z]%w*%s*%[([^%]]+)%]')
    if array_size and not array_size:find('%]') then -- Ensure no nested brackets (multidimensional arrays)
      -- Check if size is a compile-time constant
      local is_const = true

      -- Split on common operators (space, +, -, *, /, <<, >>)
      local tokens = vim.split(array_size, '[%s%+%-%*%/%>%<]+')

      for _, tok in ipairs(tokens) do
        tok = vim.trim(tok)
        if tok ~= '' then
          -- Check for sizeof(...) and arraysize(...) or ARRAY_SIZE(...) patterns (before stripping parens)
          local is_valid = tok:find('sizeof%(.+%)')
            or tok:find('arraysize%(%w+%)')
            or tok:find('ARRAY_SIZE%(.+%)')

          if not is_valid then
            -- Strip leading and trailing parentheses for other checks
            tok = tok:gsub('^%(*', ''):gsub('%)*$', '')
            tok = vim.trim(tok)

            if tok ~= '' then
              -- Allow: numeric literals, hex, k-prefixed constants, SCREAMING_CASE, sizeof, arraysize
              is_valid = (
                tok:match('^%d+$') -- decimal number
                or tok:match('^0x[0-9a-fA-F]+$') -- hex number
                or tok:match('^k[A-Z0-9]') -- k-prefixed constant
                or tok:match('^[A-Z][A-Z0-9_]*$') -- SCREAMING_CASE
                or tok:match('^sizeof') -- sizeof(...)
                or tok:match('^arraysize')
              ) -- arraysize(...)
            end
          end

          if not is_valid then
            is_const = false
            break
          end
        end
      end

      if not is_const then
        error(
          filename,
          linenum,
          'runtime/arrays',
          1,
          "Do not use variable-length arrays.  Use an appropriately named ('k' followed by CamelCase) compile-time constant for the size."
        )
      end
    end
  end

  -- Check for TRUE/FALSE (use vim.regex for proper word boundaries)
  local true_regex = vim.regex([[\<TRUE\>]])
  local false_regex = vim.regex([[\<FALSE\>]])
  local maybe_regex = vim.regex([[\<MAYBE\>]])

  if true_regex:match_str(line) then
    error(filename, linenum, 'readability/bool', 4, 'Use true instead of TRUE.')
  end

  if false_regex:match_str(line) then
    error(filename, linenum, 'readability/bool', 4, 'Use false instead of FALSE.')
  end

  -- Check for MAYBE
  if maybe_regex:match_str(line) then
    error(filename, linenum, 'readability/bool', 4, 'Use kNone from TriState instead of MAYBE.')
  end

  -- Detect preincrement/predecrement at start of line
  if line:match('^%s*%+%+') or line:match('^%s*%-%-') then
    error(
      filename,
      linenum,
      'readability/increment',
      5,
      'Do not use preincrement in statements, use postincrement instead'
    )
  end

  -- Detect preincrement/predecrement in for(;; preincrement)
  -- Look for pattern like ";  ++var" or "; --var"
  local last_semi_pos = 0
  for i = 1, #line do
    if line:sub(i, i) == ';' then
      last_semi_pos = i
    end
  end

  if last_semi_pos > 0 then
    -- Check if there's a preincrement/predecrement after the last semicolon
    local after_semi = line:sub(last_semi_pos + 1)
    local op_pos = after_semi:find('%+%+')
    if not op_pos then
      op_pos = after_semi:find('%-%-')
    end
    if op_pos then
      -- Found preincrement/predecrement after last semicolon
      local expr_start = after_semi:sub(1, op_pos - 1):match('^%s*(.*)')
      if not expr_start or expr_start == '' then
        -- Nothing but whitespace before operator, check the expression
        local expr_text = after_semi:sub(op_pos)
        if not expr_text:find(';') and not expr_text:find(' = ') then
          error(
            filename,
            linenum,
            'readability/increment',
            4,
            'Do not use preincrement in statements, including for(;; action)'
          )
        end
      end
    end
  end
end

local function check_for_non_standard_constructs(filename, clean_lines, linenum, error)
  local line = clean_lines.lines[linenum + 1]

  -- Check for printf format issues with %q and %N$ in quoted strings
  -- Extract all quoted strings and check their format specifiers
  for str in line:gmatch('"([^"]*)"') do
    -- Check for %q format (deprecated)
    if str:find('%%%-?%+?%s?%d*q') then
      error(
        filename,
        linenum,
        'runtime/printf_format',
        3,
        '"%q" in format strings is deprecated.  Use "%" PRId64 instead.'
      )
    end

    -- Check for %N$ format (unconventional positional specifier)
    if str:find('%%%d+%$') then
      error(
        filename,
        linenum,
        'runtime/printf_format',
        2,
        '%N$ formats are unconventional.  Try rewriting to avoid them.'
      )
    end
  end

  -- Check for storage class order (type before storage class modifier)
  -- Match type keywords followed by storage class keywords
  local type_keywords = {
    'const',
    'volatile',
    'void',
    'char',
    'short',
    'int',
    'long',
    'float',
    'double',
    'signed',
    'unsigned',
  }
  local storage_keywords = { 'register', 'static', 'extern', 'typedef' }

  for _, type_kw in ipairs(type_keywords) do
    for _, storage_kw in ipairs(storage_keywords) do
      local pattern = '\\<' .. type_kw .. '\\>\\s\\+\\<' .. storage_kw .. '\\>'
      if vim.regex(pattern):match_str(line) then
        error(
          filename,
          linenum,
          'build/storage_class',
          5,
          'Storage class (static, extern, typedef, etc) should be first.'
        )
        return
      end
    end
  end

  -- Check for endif comments
  if line:match('^%s*#%s*endif%s*[^/\\s]+') then
    error(
      filename,
      linenum,
      'build/endif_comment',
      5,
      'Uncommented text after #endif is non-standard.  Use a comment.'
    )
  end
end

-- Nesting state classes
local BlockInfo = {}
BlockInfo.__index = BlockInfo

function BlockInfo.new(seen_open_brace)
  local self = setmetatable({}, BlockInfo)
  self.seen_open_brace = seen_open_brace
  self.open_parentheses = 0
  self.inline_asm = NO_ASM
  return self
end

local PreprocessorInfo = {}
PreprocessorInfo.__index = PreprocessorInfo

function PreprocessorInfo.new(stack_before_if)
  local self = setmetatable({}, PreprocessorInfo)
  self.stack_before_if = stack_before_if
  self.stack_before_else = {}
  self.seen_else = false
  return self
end

local NestingState = {}
NestingState.__index = NestingState

function NestingState.new()
  local self = setmetatable({}, NestingState)
  self.stack = {}
  self.pp_stack = {}
  return self
end

function NestingState:seen_open_brace()
  return #self.stack == 0 or self.stack[#self.stack].seen_open_brace
end

function NestingState:update_preprocessor(line)
  if line:match('^%s*#%s*(if|ifdef|ifndef)') then
    table.insert(self.pp_stack, PreprocessorInfo.new(vim.deepcopy(self.stack)))
  elseif line:match('^%s*#%s*(else|elif)') then
    if #self.pp_stack > 0 then
      if not self.pp_stack[#self.pp_stack].seen_else then
        self.pp_stack[#self.pp_stack].seen_else = true
        self.pp_stack[#self.pp_stack].stack_before_else = vim.deepcopy(self.stack)
      end
      self.stack = vim.deepcopy(self.pp_stack[#self.pp_stack].stack_before_if)
    end
  elseif line:match('^%s*#%s*endif') then
    if #self.pp_stack > 0 then
      if self.pp_stack[#self.pp_stack].seen_else then
        self.stack = self.pp_stack[#self.pp_stack].stack_before_else
      end
      table.remove(self.pp_stack)
    end
  end
end

function NestingState:update(clean_lines, linenum)
  local line = clean_lines.elided[linenum + 1]

  self:update_preprocessor(line)

  if #self.stack > 0 then
    local inner_block = self.stack[#self.stack]
    local depth_change = select(2, line:gsub('%(', '')) - select(2, line:gsub('%)', ''))
    inner_block.open_parentheses = inner_block.open_parentheses + depth_change

    if inner_block.inline_asm == NO_ASM or inner_block.inline_asm == END_ASM then
      if depth_change ~= 0 and inner_block.open_parentheses == 1 and match_asm(line) then
        inner_block.inline_asm = INSIDE_ASM
      else
        inner_block.inline_asm = NO_ASM
      end
    elseif inner_block.inline_asm == INSIDE_ASM and inner_block.open_parentheses == 0 then
      inner_block.inline_asm = END_ASM
    end
  end

  while true do
    local matched = line:match('^[^{;)}]*([{;)}])(.*)$')
    if not matched then
      break
    end

    local token = matched:sub(1, 1)
    if token == '{' then
      if not self:seen_open_brace() then
        self.stack[#self.stack].seen_open_brace = true
      else
        table.insert(self.stack, BlockInfo.new(true))
        if match_asm(line) then
          self.stack[#self.stack].inline_asm = BLOCK_ASM
        end
      end
    elseif token == ';' or token == ')' then
      if not self:seen_open_brace() then
        table.remove(self.stack)
      end
    else -- token == '}'
      if #self.stack > 0 then
        table.remove(self.stack)
      end
    end
    line = matched:sub(2)
  end
end

-- Main processing functions
local function process_line(
  filename,
  clean_lines,
  line,
  nesting_state,
  error,
  extra_check_functions
)
  local raw_lines = clean_lines.raw_lines
  local init_lines = clean_lines.init_lines

  parse_nolint_suppressions(raw_lines[line + 1], line)
  nesting_state:update(clean_lines, line)

  if
    #nesting_state.stack > 0 and nesting_state.stack[#nesting_state.stack].inline_asm ~= NO_ASM
  then
    return
  end

  check_for_multiline_comments_and_strings(filename, clean_lines, line, error)
  check_for_old_style_comments(filename, init_lines[line + 1], line, error)
  check_language(filename, clean_lines, line, error)
  check_for_non_standard_constructs(filename, clean_lines, line, error)
  check_posix_threading(filename, clean_lines, line, error)
  check_memory_functions(filename, clean_lines, line, error)
  check_os_functions(filename, clean_lines, line, error)

  for _, check_fn in ipairs(extra_check_functions or {}) do
    check_fn(filename, clean_lines, line, error)
  end
end

local function process_file_data(filename, file_extension, lines, error, extra_check_functions)
  -- Add marker lines
  table.insert(lines, 1, '// marker so line numbers and indices both start at 1')
  table.insert(lines, '// marker so line numbers end in a known way')

  local nesting_state = NestingState.new()

  reset_nolint_suppressions()
  reset_known_error_suppressions()

  local init_lines = vim.deepcopy(lines)

  if cpplint_state.record_errors_file then
    local function recorded_error(filename_, linenum, category, confidence, message)
      if not is_error_suppressed_by_nolint(category, linenum) then
        local key_start = math.max(1, linenum)
        local key_end = math.min(#lines, linenum + 2)
        local key_lines = {}
        for i = key_start, key_end do
          table.insert(key_lines, lines[i])
        end
        local err = { filename_, key_lines, category }
        cpplint_state.record_errors_file:write(vim.json.encode(err) .. '\n')
      end
      error(filename_, linenum, category, confidence, message)
    end
    error = recorded_error
  end

  remove_multiline_comments(filename, lines, error)
  local clean_lines = CleansedLines.new(lines, init_lines)

  for line = 0, clean_lines:num_lines() - 1 do
    process_line(filename, clean_lines, line, nesting_state, error, extra_check_functions)
  end

  if file_extension == 'h' then
    check_for_header_guard(filename, lines, error)
    check_includes(filename, lines, error)
    if filename:match('/defs%.h$') or filename:match('_defs%.h$') then
      check_non_symbols(filename, lines, error)
    end
  end

  check_for_bad_characters(filename, lines, error)
end

local function process_file(filename, vlevel, extra_check_functions)
  cpplint_state:set_verbose_level(vlevel)

  local lines

  if filename == '-' then
    local stdin = io.read('*all')
    lines = vim.split(stdin, '\n')
    if cpplint_state.stdin_filename ~= '' then
      filename = cpplint_state.stdin_filename
    end
  else
    local ok, content = pcall(vim.fn.readfile, filename)
    if not ok then
      io.stderr:write("Skipping input '" .. filename .. "': Can't open for reading\n")
      return
    end
    lines = content
  end

  -- Remove trailing '\r'
  for i, line in ipairs(lines) do
    if line:sub(-1) == '\r' then
      lines[i] = line:sub(1, -2)
    end
  end

  local file_extension = filename:match('^.+%.(.+)$') or ''

  if filename ~= '-' and not valid_extensions[file_extension] then
    local ext_list = {}
    for ext, _ in pairs(valid_extensions) do
      table.insert(ext_list, '.' .. ext)
    end
    io.stderr:write(
      'Ignoring ' .. filename .. '; only linting ' .. table.concat(ext_list, ', ') .. ' files\n'
    )
  else
    process_file_data(filename, file_extension, lines, error_func, extra_check_functions)
  end
end

-- Main function
local function main(args)
  local filenames, opts = parse_arguments(args)

  cpplint_state:set_output_format(opts.output_format)
  cpplint_state:set_verbose_level(opts.verbose_level)
  cpplint_state:set_filters(opts.filters)
  cpplint_state:set_counting_style(opts.counting_style)
  valid_extensions = {}
  for _, ext in ipairs(opts.extensions) do
    valid_extensions[ext] = true
  end

  cpplint_state:suppress_errors_from(opts.suppress_errors_file)
  cpplint_state:record_errors_to(opts.record_errors_file)
  cpplint_state.stdin_filename = opts.stdin_filename

  cpplint_state:reset_error_counts()

  for _, filename in ipairs(filenames) do
    process_file(filename, cpplint_state.verbose_level)
  end

  cpplint_state:print_error_counts()

  if cpplint_state.record_errors_file then
    cpplint_state.record_errors_file:close()
  end

  vim.cmd.cquit(cpplint_state.error_count > 0 and 1 or 0)
end

-- Export main function
main(_G.arg)
