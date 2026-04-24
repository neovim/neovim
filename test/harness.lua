--- Result statuses emitted for test, hook, and synthetic records.
--- @alias test.harness.ResultStatus
---| 'success'
---| 'pending'
---| 'failure'
---| 'error'

--- Hook phases supported by the chunk environment.
--- @alias test.harness.HookKind
---| 'setup'
---| 'teardown'
---| 'before_each'
---| 'after_each'

--- Execution scopes that can run under harness error handling.
--- @alias test.harness.ExecutionScope
---| 'test'
---| 'setup'
---| 'teardown'
---| 'before_each'
---| 'after_each'
---| 'suite_end'

--- Source location recorded for defined suites, tests, and hooks.
--- @class test.harness.Trace
--- @field short_src string
--- @field currentline integer

--- Structured error payload used internally by the harness.
--- @class test.harness.ErrorPayload
--- @field __harness_pending? boolean
--- @field message string
--- @field trace? test.harness.Trace
--- @field traceback? string

--- @alias test.harness.Element
--- | test.harness.Suite
--- | test.harness.Test

--- Base node shared by suite and test definitions.
--- @class test.harness.ElementBase
--- @field name string
--- @field parent? test.harness.Suite
--- @field trace? test.harness.Trace
--- @field duration? number
--- @field full_name? string

--- Registered callback together with the location where it was registered.
--- @class test.harness.RegisteredCallback
--- @field fn fun()
--- @field trace? test.harness.Trace

--- Hook callbacks grouped by phase.
--- @class test.harness.HookSet
--- @field setup test.harness.RegisteredCallback[]
--- @field teardown test.harness.RegisteredCallback[]
--- @field before_each test.harness.RegisteredCallback[]
--- @field after_each test.harness.RegisteredCallback[]

--- Suite node containing hooks and nested children.
--- @class test.harness.Suite : test.harness.ElementBase
--- @field kind 'suite'
--- @field is_file boolean
--- @field children test.harness.Element[]
--- @field selected_count integer
--- @field hooks test.harness.HookSet

--- Test node containing an optional runnable body.
--- @class test.harness.Test : test.harness.ElementBase
--- @field kind 'test'
--- @field fn? fun()
--- @field parent test.harness.Suite
--- @field pending_message? string
--- @field selected? boolean

--- Normalized result returned from running a test or hook.
--- @class test.harness.Result
--- @field status test.harness.ResultStatus
--- @field message? string
--- @field traceback? string
--- @field trace? test.harness.Trace

--- Collected test file path plus its display label.
--- @class test.harness.FileEntry
--- @field path string
--- @field display_name string

--- Shallow process baseline restored between test files.
--- Mutable tables intentionally preserve identity here; deeper isolation
--- requires separate processes rather than table cloning inside one Lua state.
--- @class test.harness.RuntimeBaseline
--- @field cwd string
--- @field package_path string
--- @field package_cpath string
--- @field package_preload table<string, any>
--- @field globals table<any, any>
--- @field loaded table<string, any>
--- @field env table<string, string>
--- @field arg table<integer, string>

--- Parsed CLI options controlling one harness run.
--- @class test.harness.Options
--- @field keep_going boolean
--- @field verbose boolean
--- @field repeat_count integer
--- @field summary_file string
--- @field helper? string
--- @field tags string[]
--- @field filter? string
--- @field filter_out? string
--- @field lpaths string[]
--- @field cpaths string[]
--- @field paths string[]

--- Stored suite-end callback together with its registration site.
--- @class test.harness.SuiteEndRegistration : test.harness.RegisteredCallback
--- @field key string

--- Active execution context for one running hook or test.
--- @class test.harness.Execution
--- @field scope test.harness.ExecutionScope
--- @field finalizers test.harness.RegisteredCallback[]

--- Mutable harness state shared across definition and execution.
--- @class test.harness.State
--- @field suite_end_callbacks test.harness.SuiteEndRegistration[]
--- @field current_define_suite? test.harness.Suite
--- @field current_execution? test.harness.Execution

local uv = vim.uv

--- Public test harness module surface.
--- @class test.harness
--- @field is_ci fun(name?: 'github'): boolean
--- @field on_suite_end fun(callback: fun()): fun()
--- @field read_nvim_log fun(logfile?: string, ci_rename?: boolean): string?
local M = {}

--- @type test.harness.State
local state = {
  suite_end_callbacks = {},
  current_define_suite = nil,
  current_execution = nil,
}

--- Return the current wall-clock time in seconds.
--- @return number
local function now_seconds()
  local sec, usec = assert(uv.gettimeofday())
  return sec + usec * 1e-6
end

--- Check whether the harness is running in CI, optionally for one provider.
--- @param name? 'github'
--- @return boolean
function M.is_ci(name)
  local any_provider = (name == nil)
  assert(any_provider or name == 'github')
  local github_actions = ((any_provider or name == 'github') and nil ~= os.getenv('GITHUB_ACTIONS'))
  return github_actions
end

--- Read the last `keep` lines from a file.
--- @param path string
--- @param keep integer
--- @return string[]?
local function read_tail_lines(path, keep)
  local file = io.open(path, 'r')
  if not file then
    return nil
  end

  local lines = {}
  for line in file:lines() do
    lines[#lines + 1] = line
    if #lines > keep then
      table.remove(lines, 1)
    end
  end
  file:close()
  return lines
end

-- TODO(lewis6991): move out of harness
--- Read and optionally rename the current Nvim log for failure output.
--- @param logfile? string
--- @param ci_rename? boolean
--- @return string?
function M.read_nvim_log(logfile, ci_rename)
  logfile = logfile or os.getenv('NVIM_LOG_FILE') or 'nvim.log'
  if not uv.fs_stat(logfile) then
    return
  end

  local ci = M.is_ci()
  local keep = ci and 100 or 10
  local lines = read_tail_lines(logfile, keep) or {}
  local separator = ('-'):rep(78)
  local parts = {
    separator,
    '\n',
    string.format('$NVIM_LOG_FILE: %s\n', logfile),
    #lines > 0 and string.format('(last %d lines)\n', keep) or '(empty)\n',
  }
  for _, line in ipairs(lines) do
    parts[#parts + 1] = line
    parts[#parts + 1] = '\n'
  end
  if ci and ci_rename then
    os.rename(logfile, logfile .. '.displayed')
  end
  parts[#parts + 1] = separator
  parts[#parts + 1] = '\n'
  return table.concat(parts)
end

--- Normalize a path relative to the current working directory.
--- @param path string
--- @return string
local function normalize_path(path)
  return vim.fs.normalize(vim.fs.abspath(path))
end

--- Render a path relative to the current working directory when possible.
--- @param path string
--- @return string
local function display_path(path)
  path = normalize_path(path)
  local relative = vim.fs.relpath('.', path)
  if relative then
    return relative
  end
  return path
end

--- Restore a table to a previously captured shallow snapshot.
--- @generic K, V
--- @param current table<K, V>
--- @param snapshot table<K, V>
--- @param unset? fun(key: K)
--- @param set? fun(key: K, value: V)
local function restore_snapshot(current, snapshot, unset, set)
  unset = unset or function(k)
    rawset(current, k, nil)
  end
  set = set or function(k, v)
    rawset(current, k, v)
  end
  for k in pairs(current) do
    if rawget(snapshot, k) == nil then
      unset(k)
    end
  end
  for k, v in pairs(snapshot) do
    set(k, v)
  end
end

--- Restore the process state to a captured baseline.
--- @param baseline test.harness.RuntimeBaseline
local function restore_runtime_baseline(baseline)
  if uv.cwd() ~= baseline.cwd then
    uv.chdir(baseline.cwd)
  end

  package.path = baseline.package_path
  package.cpath = baseline.package_cpath
  restore_snapshot(package.preload, baseline.package_preload)
  restore_snapshot(package.loaded, baseline.loaded)
  restore_snapshot(_G, baseline.globals)
  restore_snapshot(uv.os_environ(), baseline.env, uv.os_unsetenv, uv.os_setenv)
  _G.arg = vim._copy(baseline.arg)
  state.current_define_suite = nil
  state.current_execution = nil
end

--- Restore the baseline and run GC cleanup.
--- @param baseline test.harness.RuntimeBaseline
local function cleanup_runtime_baseline(baseline)
  restore_runtime_baseline(baseline)
  -- One full cycle may only run __gc/finalizers for dead userdata/cdata.
  -- Those finalizers can release the last references to more uv/mpack objects,
  -- which do not become collectible until the next cycle. Collect twice before
  -- switching files or ending the harness so leak checks see only live state.
  collectgarbage('collect')
  collectgarbage('collect')
end

local harness_source = debug.getinfo(1, 'S').source
local test_assert = require('test.assert')
local assert_source = debug.getinfo(test_assert.eq, 'S').source

--- @param info? debug.Info
--- @return test.harness.Trace
local function trace_from_info(info)
  return {
    short_src = info and vim.fs.normalize(info.short_src or '') or '',
    currentline = info and info.currentline or 0,
  }
end

--- Capture the source location of a caller frame.
--- Walk upward until we find a user Lua frame so Lua 5.1 tail-call elision
--- does not collapse `it()`/hook registrations into `(tail call) @ -1`.
--- @param level? integer
--- @return test.harness.Trace
local function caller_trace(level)
  local frame = level or 3
  local fallback

  while true do
    local info = debug.getinfo(frame, 'Sln')
    if not info then
      return trace_from_info(fallback)
    end

    fallback = fallback or info
    if
      info.what ~= 'C'
      and info.source ~= harness_source
      and info.short_src ~= '(tail call)'
      and info.currentline > 0
    then
      return trace_from_info(info)
    end

    frame = frame + 1
  end
end

--- Register a suite-end callback, deduplicated by callsite.
--- @param callback fun()
--- @return fun()
function M.on_suite_end(callback)
  assert(type(callback) == 'function', 'on_suite_end() expects a function')
  local trace = caller_trace(3)
  local caller_info = debug.getinfo(2, 'S')
  local key_source = caller_info and caller_info.source
  if type(key_source) == 'string' and vim.startswith(key_source, '@') then
    key_source = vim.fs.normalize(key_source:sub(2))
  else
    key_source = trace.short_src
  end
  local key = ('%s:%d'):format(key_source, trace.currentline)
  for _, registration in ipairs(state.suite_end_callbacks) do
    if registration.key == key then
      return registration.fn
    end
  end
  table.insert(state.suite_end_callbacks, {
    fn = callback,
    trace = trace,
    key = key,
  })
  return callback
end

--- Create a suite node for the definition tree.
--- @param name string?
--- @param parent? test.harness.Suite
--- @param trace? test.harness.Trace
--- @param is_file? boolean
--- @return test.harness.Suite
local function create_suite(name, parent, trace, is_file)
  return {
    kind = 'suite',
    name = name or '',
    parent = parent,
    trace = trace,
    is_file = is_file or false,
    hooks = {
      setup = {},
      teardown = {},
      before_each = {},
      after_each = {},
    },
    children = {},
    selected_count = 0,
  }
end

--- Return the suite currently receiving test definitions.
--- @return test.harness.Suite
local function current_suite()
  assert(state.current_define_suite, 'test definition is not active')
  return state.current_define_suite
end

--- Add a test node to the current suite.
--- @param name string
--- @param fn? fun()
--- @param pending_message? string
--- @return test.harness.Test
local function register_test(name, fn, pending_message)
  assert(type(name) == 'string' and name ~= '', 'test name must be a non-empty string')
  if fn ~= nil then
    assert(type(fn) == 'function', 'test body must be a function')
  end

  local suite = current_suite()
  local test = {
    kind = 'test',
    name = name,
    fn = fn,
    parent = suite,
    trace = caller_trace(3),
    pending_message = pending_message,
  }
  table.insert(suite.children, test)
  return test
end

--- Build a hook registrar exposed in the test chunk environment.
--- @param kind test.harness.HookKind
--- @return fun(fn: fun())
local function chunk_hook(kind)
  return function(fn)
    assert(type(fn) == 'function', ('%s expects a function'):format(kind))
    table.insert(current_suite().hooks[kind], {
      fn = fn,
      trace = caller_trace(3),
    })
  end
end

-- Chunk environment
local chunk_env = {
  _G = _G,
  assert = test_assert,
  setup = chunk_hook('setup'),
  teardown = chunk_hook('teardown'),
  before_each = chunk_hook('before_each'),
  after_each = chunk_hook('after_each'),
}

--- Define a nested suite in the chunk environment.
--- @param name string
--- @param fn fun()
--- @return test.harness.Suite
function chunk_env.describe(name, fn)
  assert(type(name) == 'string', 'describe() expects a string')
  assert(type(fn) == 'function', 'describe() expects a function body')

  local parent = current_suite()
  local suite = create_suite(name, parent, caller_trace(3), false)
  table.insert(parent.children, suite)

  local previous_define_suite = state.current_define_suite
  state.current_define_suite = suite
  local ok, err = xpcall(fn, debug.traceback)
  state.current_define_suite = previous_define_suite

  if not ok then
    error(err, 0)
  end

  return suite
end

--- Define a test in the chunk environment.
--- @param name string
--- @param fn? fun()
--- @return test.harness.Test
function chunk_env.it(name, fn)
  return register_test(name, fn, nil)
end

--- Mark the current test as pending or define a pending test.
--- When called while a test or hook is running, this aborts the current
--- execution and reports the current test as pending with `name` as the
--- pending message.
--- When called during file definition, this registers a new pending test in
--- the current suite. In that form, `block` may be a string used as the
--- pending message.
--- @param name? string
--- @param block? fun()|string
--- @return boolean
function chunk_env.pending(name, block)
  if state.current_execution then
    error({
      __harness_pending = true,
      message = name or 'pending',
    }, 0)
  end
  local pending_message = type(block) == 'string' and block or nil
  register_test(name or 'pending', nil, pending_message)
  return false
end

--- Register a finalizer to run after the current test body.
--- @param fn fun()
function chunk_env.finally(fn)
  assert(type(fn) == 'function', 'finally() expects a function')
  assert(
    state.current_execution and state.current_execution.scope == 'test',
    'finally() must be called while a test body is running'
  )
  table.insert(state.current_execution.finalizers, {
    fn = fn,
    trace = caller_trace(3),
  })
end

--- Convert an arbitrary error value into printable text.
--- @param err any
--- @return string
local function format_error_value(err)
  if type(err) == 'string' then
    return err
  end

  local ok, inspected = pcall(vim.inspect, err)
  if ok then
    return inspected
  end

  return tostring(err)
end

--- Parse one traceback line into a source location.
--- @param text? string
--- @return test.harness.Trace?
local function parse_trace_line(text)
  if type(text) ~= 'string' then
    return
  end

  local src, line = text:match('^(.+):(%d+):')
  if not src or not line then
    return
  end

  return {
    short_src = vim.fs.normalize(src),
    currentline = tonumber(line) or 0,
  }
end

--- @param source string
--- @param candidate string
--- @return boolean
local function source_matches(source, candidate)
  if source == candidate then
    return true
  end

  local tail = source:match('^%.%.%.(.+)$')
  return tail ~= nil and vim.endswith(candidate, tail)
end

--- @param left? test.harness.Trace
--- @param right? test.harness.Trace
--- @return boolean
local function same_trace_source(left, right)
  if left == nil or right == nil then
    return false
  end
  return source_matches(left.short_src, right.short_src)
    or source_matches(right.short_src, left.short_src)
end

--- Extract a source location from an error message or traceback.
--- @param message? string
--- @param traceback? string
--- @return test.harness.Trace?
local function parse_error_trace(message, traceback)
  if type(message) == 'string' then
    local first_line = message:match('^[^\n]+')
    local trace = parse_trace_line(first_line)
    if trace then
      return trace
    end

    local load_path = first_line
      and first_line:match("^error loading module .+ from file '([^']+)':$")
    if load_path == nil and first_line then
      load_path = first_line:match('^error loading module .+ from file "([^"]+)":$')
    end
    if load_path then
      local detail_line = message:match('\n([^\n]+)')
      trace = parse_trace_line(detail_line and detail_line:gsub('^%s+', ''))
      local load_trace = {
        short_src = vim.fs.normalize(load_path),
        currentline = 0,
      }
      if trace and same_trace_source(trace, load_trace) then
        return trace
      end
    end
  end

  if type(traceback) == 'string' then
    for line in traceback:gmatch('[^\n]+') do
      local trace = parse_trace_line(line:gsub('^%s+', ''))
      if trace then
        return trace
      end
    end
  end
end

--- Capture only user-visible Lua frames for test and hook failures.
--- Once execution returns to the harness, the rest of the stack is framework
--- noise and should not be printed in verbose failure output.
--- @return string?
local function build_error_traceback()
  local lines = {}

  for level = 3, math.huge do
    local info = debug.getinfo(level, 'Sln')
    if not info then
      break
    end

    if info.source == harness_source then
      break
    end

    if (info.what == 'Lua' or info.what == 'main') and info.source ~= assert_source then
      local trace = trace_from_info(info)
      if trace.currentline > 0 and trace.short_src ~= '' then
        local location = ('%s:%d'):format(trace.short_src, trace.currentline)
        if info.what == 'main' then
          lines[#lines + 1] = ('\t%s: in main chunk'):format(location)
        elseif info.name and info.name ~= '' then
          lines[#lines + 1] = ("\t%s: in function '%s'"):format(location, info.name)
        elseif (info.linedefined or 0) > 0 then
          lines[#lines + 1] = ('\t%s: in function <%s:%d>'):format(
            location,
            trace.short_src,
            info.linedefined
          )
        else
          lines[#lines + 1] = ('\t%s: in function ?'):format(location)
        end
      end
    end
  end

  if #lines == 0 then
    return
  end

  return 'stack traceback:\n' .. table.concat(lines, '\n')
end

--- Normalize thrown values into harness error payloads.
--- @param err any
--- @return test.harness.ErrorPayload
local function exception_handler(err)
  if type(err) == 'table' and err.__harness_pending then
    --- @cast err test.harness.ErrorPayload
    return err
  end

  local message = format_error_value(err)
  local raw_traceback = debug.traceback('', 2)
  return {
    message = message,
    trace = parse_error_trace(message, raw_traceback),
    traceback = build_error_traceback() or raw_traceback,
  }
end

--- Convert a handled error payload into a test result.
--- @param err test.harness.ErrorPayload
--- @param fallback_status? test.harness.ResultStatus
--- @return test.harness.Result
local function decode_error(err, fallback_status)
  return {
    status = err.__harness_pending and 'pending' or fallback_status or 'failure',
    message = err.message,
    traceback = err.traceback,
    trace = err.trace or parse_error_trace(err.message, err.traceback),
  }
end

--- Run a callable under harness error handling and finalizer cleanup.
--- @param scope test.harness.ExecutionScope
--- @param callable test.harness.RegisteredCallback
--- @param fallback_status? test.harness.ResultStatus
--- @return test.harness.Result, test.harness.Trace?
local function run_callable(scope, callable, fallback_status)
  local previous_execution = state.current_execution
  --- @type test.harness.Execution
  local execution = {
    scope = scope,
    finalizers = {},
  }
  state.current_execution = execution

  local ok, err = xpcall(callable.fn, exception_handler)
  local finalizer_err
  local finalizer_trace
  for i = #execution.finalizers, 1, -1 do
    local finalizer = execution.finalizers[i]
    local finalizer_ok, ferr = xpcall(finalizer.fn, exception_handler)
    if not finalizer_ok and not finalizer_err then
      finalizer_err = ferr
      finalizer_trace = finalizer.trace
    end
  end

  state.current_execution = previous_execution

  local result = ok and { status = 'success' } or decode_error(err, fallback_status)
  local report_trace = not ok and callable.trace or nil
  if not finalizer_err then
    return result, report_trace
  end

  local finalizer_result = decode_error(finalizer_err, 'error')
  if result.status == 'success' then
    finalizer_result.status = 'error'
    return finalizer_result, finalizer_trace
  end

  if result.status == 'pending' then
    return {
      status = 'error',
      message = ('finally: %s'):format(finalizer_result.message),
      traceback = finalizer_result.traceback,
      trace = finalizer_result.trace,
    },
      finalizer_trace
  end

  result.message = result.message .. '\n\nfinally: ' .. finalizer_result.message
  if not result.traceback then
    result.traceback = finalizer_result.traceback
  end
  if not result.trace then
    result.trace = finalizer_result.trace
  end
  return result, report_trace
end

--- Prefer the parsed trace only when it points at the same source file as the
--- owning test or callback. Otherwise, fall back to the definition site.
--- @param trace? test.harness.Trace
--- @param fallback? test.harness.Trace
--- @return test.harness.Trace?
local function summary_trace(trace, fallback)
  if same_trace_source(trace, fallback) then
    return trace
  end
  return fallback or trace
end

--- Build the suite and test name parts used for reporting.
--- @param element test.harness.Element?
--- @return string[]
local function full_name_parts(element)
  local parts = {}
  local node = element
  while node do
    if node.kind == 'test' and node.name ~= '' then
      table.insert(parts, 1, node.name)
    elseif node.kind == 'suite' and not node.is_file and node.name ~= '' then
      table.insert(parts, 1, node.name)
    end
    node = node.parent
  end
  return parts
end

--- Return the full hierarchical name for a suite or test.
--- @param element test.harness.Element
--- @return string
function M.get_full_name(element)
  return table.concat(full_name_parts(element), ' ')
end

--- Check whether a test matches the current selection options.
--- @param test test.harness.Test
--- @param opts test.harness.Options
--- @return boolean
local function test_selected(test, opts)
  test.full_name = M.get_full_name(test)

  if #opts.tags > 0 then
    local tagged = false
    for tag in test.full_name:gmatch('#([%w_%-]+)') do
      if vim.list_contains(opts.tags, tag) then
        tagged = true
        break
      end
    end

    if not tagged then
      return false
    end
  end

  if opts.filter and not test.full_name:match(opts.filter) then
    return false
  end

  if opts.filter_out and test.full_name:match(opts.filter_out) then
    return false
  end

  return true
end

--- Mark selected tests in a suite subtree and count them.
--- @param node test.harness.Suite
--- @param opts test.harness.Options
--- @return integer
local function mark_selected(node, opts)
  local selected_count = 0
  for _, child in ipairs(node.children) do
    if child.kind == 'suite' then
      selected_count = selected_count + mark_selected(child, opts)
    else
      --- @cast child test.harness.Test
      child.selected = test_selected(child, opts)
      if child.selected then
        selected_count = selected_count + 1
      end
    end
  end

  node.selected_count = selected_count
  return selected_count
end

--- Collect inherited `before_each` hooks from outermost to innermost.
--- @param suite test.harness.Suite
--- @return test.harness.RegisteredCallback[]
local function gather_before_each(suite)
  local hooks = {}
  if suite.parent then
    vim.list_extend(hooks, gather_before_each(suite.parent))
  end
  for _, hook in ipairs(suite.hooks.before_each) do
    hooks[#hooks + 1] = hook
  end
  return hooks
end

--- Collect inherited `after_each` hooks from innermost to outermost.
--- @param suite test.harness.Suite
--- @return test.harness.RegisteredCallback[]
local function gather_after_each(suite)
  local hooks = {}
  for _, hook in ipairs(suite.hooks.after_each) do
    hooks[#hooks + 1] = hook
  end
  if suite.parent then
    vim.list_extend(hooks, gather_after_each(suite.parent))
  end
  return hooks
end

--- Finalized result record passed to the reporter and stored in summaries.
--- @class test.harness.Record
--- @field name string
--- @field status test.harness.ResultStatus
--- @field trace? test.harness.Trace
--- @field duration number
--- @field message? string
--- @field traceback? string

--- Execution summary accumulated by the harness for one suite iteration.
--- @class test.harness.RunSummary
--- @field file_count integer
--- @field result_count integer
--- @field test_count integer
--- @field success_count integer
--- @field skipped_count integer
--- @field failure_count integer
--- @field error_count integer
--- @field pendings test.harness.Record[]
--- @field failures test.harness.Record[]
--- @field errors test.harness.Record[]

--- Per-file summary accumulated by the harness while one file runs.
--- @class test.harness.FileRunSummary
--- @field test_count integer

--- Build the reporter record for a completed result.
--- @param name string
--- @param result test.harness.Result
--- @param trace? test.harness.Trace
--- @param duration number
--- @return test.harness.Record
local function build_record(name, result, trace, duration)
  return {
    name = name,
    status = result.status,
    trace = trace,
    duration = duration,
    message = result.message,
    traceback = result.traceback,
  }
end

--- Record a completed test or synthetic result into the harness summary.
--- @param summary test.harness.RunSummary
--- @param file_summary? test.harness.FileRunSummary
--- @param record test.harness.Record
--- @param count_as_test? boolean
local function record_result(summary, file_summary, record, count_as_test)
  summary.result_count = summary.result_count + 1
  if count_as_test ~= false then
    summary.test_count = summary.test_count + 1
    if file_summary then
      file_summary.test_count = file_summary.test_count + 1
    end
  end

  if record.status == 'success' then
    summary.success_count = summary.success_count + 1
  elseif record.status == 'pending' then
    summary.skipped_count = summary.skipped_count + 1
    table.insert(summary.pendings, record)
  elseif record.status == 'failure' then
    summary.failure_count = summary.failure_count + 1
    table.insert(summary.failures, record)
  else -- error
    summary.error_count = summary.error_count + 1
    table.insert(summary.errors, record)
  end
end

--- Report a synthetic result as a test-shaped record.
--- @param reporter test.base_reporter
--- @param summary test.harness.RunSummary
--- @param file_summary? test.harness.FileRunSummary
--- @param parent test.harness.Suite
--- @param phase string
--- @param result test.harness.Result
--- @param trace? test.harness.Trace
--- @return test.harness.ResultStatus
local function run_synthetic_result(reporter, summary, file_summary, parent, phase, result, trace)
  local name = M.get_full_name(parent)
  if name == '' then
    name = parent.name ~= '' and parent.name or 'suite'
  end
  name = ('%s [%s]'):format(name, phase)
  local record_trace = trace or result.trace or parent.trace
  local record = build_record(name, result, record_trace, 0)
  reporter:test_start(record.name)
  record_result(summary, file_summary, record, false)
  reporter:test_end(record)
  return record.status
end

--- Run registered suite-end callbacks and report failures.
--- @param reporter test.base_reporter
--- @param summary test.harness.RunSummary
--- @return boolean
local function run_suite_end_callbacks(reporter, summary)
  local suite_end_callbacks = vim._copy(state.suite_end_callbacks)
  local callback_failed = false

  for index, callback in ipairs(suite_end_callbacks) do
    local result, report_trace = run_callable('suite_end', callback, 'error')
    if result.status ~= 'success' then
      callback_failed = true
      result.status = 'error'
      local name = ('[suite_end %d]'):format(index)
      local record_trace = summary_trace(result.trace, report_trace or callback.trace)
      local record = build_record(name, result, record_trace, 0)
      reporter:test_start(record.name)
      record_result(summary, nil, record, false)
      reporter:test_end(record)
    end
  end

  return callback_failed
end

--- Run a single test with its surrounding before and after hooks.
--- @param test test.harness.Test
--- @param reporter test.base_reporter
--- @param summary test.harness.RunSummary
--- @param file_summary test.harness.FileRunSummary
--- @return test.harness.ResultStatus
local function run_test(test, reporter, summary, file_summary)
  local name = test.full_name or M.get_full_name(test)

  local start_time = now_seconds()
  --- @type test.harness.Result
  local result
  local report_trace = test.trace
  if test.fn == nil then
    reporter:test_start(name)
    result = {
      status = 'pending',
      message = test.pending_message,
    }
  else
    result = { status = 'success' }

    for _, hook in ipairs(gather_before_each(test.parent)) do
      result, report_trace = run_callable('before_each', hook, 'failure')
      if result.status ~= 'success' then
        break
      end
    end

    reporter:test_start(name)

    if result.status == 'success' then
      result, report_trace = run_callable('test', { fn = test.fn, trace = test.trace }, 'failure')
    end

    for _, hook in ipairs(gather_after_each(test.parent)) do
      local hook_result, hook_trace = run_callable('after_each', hook, 'failure')
      if result.status == 'success' then
        result = hook_result
        report_trace = hook_trace
      elseif hook_result.status ~= 'success' then
        local hook_report_trace = hook_trace or hook.trace
        result.message = (result.message or '')
          .. (result.message and result.message ~= '' and '\n\n' or '')
          .. 'after_each: '
          .. hook_result.message
        if not result.traceback then
          result.traceback = hook_result.traceback
        end
        if not result.trace then
          result.trace = hook_result.trace
        end
        if result.status == 'pending' then
          result.status = 'error'
          report_trace = hook_report_trace
        elseif not report_trace then
          report_trace = hook_report_trace
        end
      end
    end
  end

  test.duration = now_seconds() - start_time
  local record = build_record(
    name,
    result,
    summary_trace(result.trace, report_trace or test.trace),
    test.duration
  )
  record_result(summary, file_summary, record)
  reporter:test_end(record)
  return record.status
end

--- Run a suite subtree until completion or a stop condition.
--- @param suite test.harness.Suite
--- @param reporter test.base_reporter
--- @param summary test.harness.RunSummary
--- @param file_summary test.harness.FileRunSummary
--- @param opts test.harness.Options
--- @return boolean
local function run_suite(suite, reporter, summary, file_summary, opts)
  if suite.selected_count == 0 then
    return false
  end

  local stop_requested = false
  local run_children = true

  -- Run setup() hooks
  for _, hook in ipairs(suite.hooks.setup) do
    local result = run_callable('setup', hook, 'error')
    if result.status ~= 'success' then
      run_synthetic_result(reporter, summary, file_summary, suite, 'setup', result, hook.trace)
      run_children = false
      if result.status ~= 'pending' and not opts.keep_going then
        stop_requested = true
      end
      break
    end
  end

  if run_children and not stop_requested then
    for _, child in ipairs(suite.children) do
      if child.kind == 'suite' then
        stop_requested = run_suite(child, reporter, summary, file_summary, opts) or stop_requested
      elseif child.selected then
        local status = run_test(child, reporter, summary, file_summary)
        if status ~= 'success' and status ~= 'pending' and not opts.keep_going then
          stop_requested = true
        end
      end

      if stop_requested then
        break
      end
    end
  end

  -- Run teardown() hooks
  for _, hook in ipairs(suite.hooks.teardown) do
    local result = run_callable('teardown', hook, 'error')
    if result.status ~= 'success' then
      run_synthetic_result(reporter, summary, file_summary, suite, 'teardown', result, hook.trace)
      if result.status ~= 'pending' and not opts.keep_going then
        stop_requested = true
      end
    end
  end

  return stop_requested
end

--- Collect test files from a file or directory path.
--- @param path string
--- @param files test.harness.FileEntry[]
--- @param seen_files table<string, boolean>
--- @return boolean?, string?
local function collect_test_files(path, files, seen_files)
  --- @param file string
  local function add_test_file(file)
    local abs_file = normalize_path(file)
    if seen_files[abs_file] then
      return
    end

    seen_files[abs_file] = true
    files[#files + 1] = {
      path = abs_file,
      display_name = display_path(abs_file),
    }
  end

  local abs = normalize_path(path)
  local stat = uv.fs_stat(abs)
  if not stat then
    return nil, ('test path not found: %s'):format(path)
  end

  if stat.type == 'file' then
    add_test_file(abs)
    return true
  end

  if stat.type ~= 'directory' then
    return nil, ('unsupported test path: %s'):format(path)
  end

  for _, file in
    ipairs(vim.fs.find(function(name)
      return name:match('_spec%.lua$') ~= nil
    end, {
      path = abs,
      type = 'file',
      limit = math.huge,
    }))
  do
    add_test_file(file)
  end

  return true
end

--- Parse harness CLI arguments into execution options.
--- @param argv string[]
--- @return test.harness.Options?, string?
local function parse_args(argv)
  --- @type test.harness.Options
  local opts = {
    keep_going = true,
    verbose = false,
    repeat_count = 1,
    summary_file = '-',
    tags = {},
    lpaths = {},
    cpaths = {},
    paths = {},
  }

  --- @type table<string, boolean>
  local seen_tags = {}

  --- @param flag string
  --- @return nil, string
  local function missing_value(flag)
    return nil, 'missing value for ' .. flag
  end

  --- Parse and validate the `--repeat` argument.
  --- @param value? string
  --- @return integer?, string?
  local function parse_repeat_count(value)
    if type(value) ~= 'string' or value == '' then
      return missing_value('--repeat')
    end

    local count = tonumber(value)
    if count == nil or count < 1 or count ~= math.floor(count) then
      return nil, ('invalid value for --repeat: %s'):format(value)
    end
    --- @cast count integer

    return count
  end

  --- @type table<string, fun()>
  local switch_options = {
    ['-v'] = function()
      opts.verbose = true
    end,
    ['--verbose'] = function()
      opts.verbose = true
    end,
    ['--no-keep-going'] = function()
      opts.keep_going = false
    end,
  }

  --- @param flag string
  --- @param value string
  --- @return string?, string?
  local function require_nonempty(flag, value)
    if value == '' then
      return missing_value(flag)
    end
    return value
  end

  --- @param setter fun(value: any)
  --- @return fun(value: any): boolean?, string?
  local function set_value(setter)
    return function(value)
      setter(value)
      return true
    end
  end

  --- @param parse fun(value: string): any?, string?
  --- @param setter fun(value: any)
  --- @return fun(value: string): boolean?, string?
  local function set_parsed_value(parse, setter)
    return function(value)
      local parsed, err = parse(value)
      if parsed == nil then
        return nil, err
      end
      setter(parsed)
      return true
    end
  end

  --- @param flag string
  --- @param setter fun(value: string)
  --- @return fun(value: string): boolean?, string?
  local function set_nonempty_value(flag, setter)
    return set_parsed_value(function(value)
      return require_nonempty(flag, value)
    end, setter)
  end

  --- Validate that a filter option contains a valid Lua pattern.
  --- @param flag string
  --- @param value string
  --- @return string?, string?
  local function validate_pattern(flag, value)
    local ok, err = pcall(string.match, '', value)
    if not ok then
      local message = tostring(err)
      local detail = message:match('malformed pattern.*') or message
      return nil, ('invalid value for %s: %s'):format(flag, detail)
    end
    return value
  end

  --- @param flag string
  --- @param setter fun(value: string)
  --- @return fun(value: string): boolean?, string?
  local function set_pattern_value(flag, setter)
    return set_parsed_value(function(value)
      return validate_pattern(flag, value)
    end, setter)
  end

  --- @param values string[]
  --- @return fun(value: string): boolean?, string?
  local function append_value(values)
    return set_value(function(value)
      table.insert(values, value)
    end)
  end

  --- @type table<string, fun(value: string): boolean?, string?>
  local value_options = {
    ['--repeat'] = set_parsed_value(parse_repeat_count, function(count)
      opts.repeat_count = count
    end),
    ['--helper'] = set_nonempty_value('--helper', function(value)
      opts.helper = value
    end),
    ['--summary-file'] = set_nonempty_value('--summary-file', function(value)
      opts.summary_file = value
    end),
    ['--tags'] = function(value)
      for token in value:gmatch('[^,%s]+') do
        local tag = token:gsub('^#', '')
        if tag ~= '' and not seen_tags[tag] then
          seen_tags[tag] = true
          table.insert(opts.tags, tag)
        end
      end
      return true
    end,
    ['--filter'] = set_pattern_value('--filter', function(pattern)
      opts.filter = pattern
    end),
    ['--filter-out'] = set_pattern_value('--filter-out', function(pattern)
      opts.filter_out = pattern
    end),
    ['--lpath'] = append_value(opts.lpaths),
    ['--cpath'] = append_value(opts.cpaths),
  }

  local i = 1

  --- @param arg string
  --- @return string, string?
  local function split_option(arg)
    local eq = arg:find('=', 1, true)
    if not eq then
      return arg, nil
    end
    return arg:sub(1, eq - 1), arg:sub(eq + 1)
  end

  --- Consume the next argv item as the value for `flag`.
  --- @param flag string
  --- @return string?, string?
  local function take_value(flag)
    i = i + 1
    local value = argv[i]
    if type(value) ~= 'string' then
      return missing_value(flag)
    end
    return value
  end

  --- Parse one named option and apply it to `opts`.
  --- @param arg string
  --- @return boolean, string?
  local function apply_named_option(arg)
    local switch_handler = switch_options[arg]
    if switch_handler then
      switch_handler()
      return true
    end

    local flag, value = split_option(arg)
    local handler = value_options[flag]
    if handler then
      if value == nil then
        local err
        value, err = take_value(flag)
        if not value then
          return false, err
        end
      end
      local ok, handler_err = handler(value)
      if not ok then
        return false, handler_err
      end
      return true
    end

    return false
  end

  while i <= #argv do
    local arg = assert(argv[i])
    local handled, err = apply_named_option(arg)
    if handled then
    elseif err then
      return nil, err
    elseif vim.startswith(arg, '-') then
      return nil, 'unknown test harness option: ' .. arg
    else
      opts.paths[#opts.paths + 1] = arg
    end
    i = i + 1
  end

  if #opts.paths == 0 then
    return nil, 'no test paths provided'
  end

  return opts
end

--- Load a Lua chunk and bind it to a shallow copy of the given environment.
--- @param path string
--- @param env table<any, any>
--- @return function?, string?
local function load_chunk(path, env)
  local chunk, err = loadfile(path)
  if not chunk then
    return nil, err
  end

  return setfenv(chunk, setmetatable(vim._copy(env), { __index = _G }))
end

--- Load a helper file before the test baseline is captured.
--- Helper files are preload-only: they may require modules, set defaults,
--- and register suite-end callbacks, but they do not define tests or hooks.
--- @param path string
--- @return boolean?, string?
local function load_helper(path)
  local helper_path = normalize_path(path)
  local chunk, err = load_chunk(helper_path, {
    _G = _G,
    assert = test_assert,
  })
  if not chunk then
    return nil, err
  end
  local ok, load_err = xpcall(chunk, debug.traceback)
  if not ok then
    return nil, load_err
  end

  return true
end

--- Evaluate a test file into a per-file root suite.
--- @param file test.harness.FileEntry
--- @param root_suite test.harness.Suite
--- @return test.harness.Suite, test.harness.Result?
local function evaluate_test_file(file, root_suite)
  local file_suite = create_suite(file.display_name, root_suite, {
    short_src = file.display_name,
    currentline = 1,
  }, true)
  table.insert(root_suite.children, file_suite)

  state.current_define_suite = file_suite
  local chunk, load_err = load_chunk(file.path, chunk_env)
  if not chunk then
    state.current_define_suite = nil
    return file_suite,
      {
        status = 'error',
        message = load_err,
        trace = parse_error_trace(load_err, nil),
      }
  end

  local ok, runtime_err = xpcall(chunk, exception_handler)
  state.current_define_suite = nil
  if not ok then
    local load_error = decode_error(runtime_err, 'error')
    load_error.status = 'error'
    return file_suite, load_error
  end

  return file_suite
end

--- Run a single file in the current prepared runtime state.
--- @param file test.harness.FileEntry
--- @param reporter test.base_reporter
--- @param summary test.harness.RunSummary
--- @param opts test.harness.Options
--- @return boolean, boolean
local function run_test_file(file, reporter, summary, opts)
  local root_suite = create_suite('')
  local saved_suite_end_callbacks = vim._copy(state.suite_end_callbacks)

  local file_suite, load_error = evaluate_test_file(file, root_suite)

  local selected_count = mark_selected(root_suite, opts)

  if load_error then
    state.suite_end_callbacks = saved_suite_end_callbacks
  elseif selected_count == 0 then
    state.suite_end_callbacks = saved_suite_end_callbacks
    return false, false
  end

  --- @type test.reporter.FileElement
  local file_element = { name = file.display_name, duration = 0 }

  --- @type test.harness.FileRunSummary
  local file_summary = { test_count = 0 }

  reporter:file_start(file_element)

  local start = now_seconds()
  local stop_requested = false
  if load_error then
    local status = run_synthetic_result(
      reporter,
      summary,
      file_summary,
      file_suite,
      'load',
      load_error,
      load_error.trace
    )
    if status ~= 'success' and status ~= 'pending' and not opts.keep_going then
      stop_requested = true
    end
  else
    stop_requested = run_suite(root_suite, reporter, summary, file_summary, opts)
  end

  file_element.duration = now_seconds() - start
  summary.file_count = summary.file_count + 1

  reporter:file_end(file_element, file_summary.test_count)

  return true, stop_requested
end

--- Aggregate outcome from running one suite iteration.
--- @class test.harness.IterationResult
--- @field ran_any boolean
--- @field stop_requested boolean
--- @field summary test.harness.RunSummary

--- Run one full suite iteration across the selected files.
--- @param Reporter test.base_reporter
--- @param opts test.harness.Options
--- @param files test.harness.FileEntry[]
--- @param pre_helper_baseline test.harness.RuntimeBaseline
--- @param repeat_index integer
--- @return test.harness.IterationResult?, string?
local function run_iteration(Reporter, opts, files, pre_helper_baseline, repeat_index)
  local reporter = Reporter.new({
    paths = opts.paths,
    verbose = opts.verbose,
    summary_file = opts.summary_file,
  })
  --- @type test.harness.RunSummary
  local summary = {
    file_count = 0,
    result_count = 0,
    test_count = 0,
    success_count = 0,
    skipped_count = 0,
    failure_count = 0,
    error_count = 0,
    pendings = {},
    failures = {},
    errors = {},
  }
  restore_runtime_baseline(pre_helper_baseline)
  state.suite_end_callbacks = {}
  if opts.helper then
    local ok, err = load_helper(opts.helper)
    if not ok then
      return nil, err
    end
  end
  --- @type test.harness.RuntimeBaseline
  local file_baseline = {
    cwd = assert(uv.cwd()),
    package_path = package.path,
    package_cpath = package.cpath,
    package_preload = vim._copy(package.preload),
    globals = vim._copy(_G),
    loaded = vim._copy(package.loaded),
    env = vim._copy(uv.os_environ()),
    arg = vim._copy(_G.arg or {}),
  }
  reporter:suite_start(repeat_index, opts.repeat_count)

  local start_time = now_seconds()
  local ran_any = false
  local stop_requested = false

  for _, file in ipairs(files) do
    restore_runtime_baseline(file_baseline)
    local ran_file, stop = run_test_file(file, reporter, summary, opts)
    cleanup_runtime_baseline(file_baseline)
    ran_any = ran_any or ran_file
    if stop then
      stop_requested = true
      break
    end
  end

  local duration = now_seconds() - start_time

  run_suite_end_callbacks(reporter, summary)
  cleanup_runtime_baseline(file_baseline)

  state.suite_end_callbacks = {}

  local failure_output
  if summary.failure_count > 0 or summary.error_count > 0 then
    failure_output = M.read_nvim_log(nil, true)
  end

  reporter:suite_end(duration, summary, failure_output)

  return {
    ran_any = ran_any,
    stop_requested = stop_requested,
    summary = summary,
  }
end

--- Run the test harness CLI entrypoint.
--- @param argv string[]
--- @return integer
function M.main(argv)
  if os.getenv('BUSTED_ARGS') ~= nil then
    io.stderr:write('$BUSTED_ARGS is no longer supported; use $TEST_ARGS instead.\n')
    return 1
  end

  local opts, err = parse_args(argv)
  if not opts then
    io.stderr:write(err .. '\n')
    return 1
  end

  if #opts.lpaths > 0 then
    package.path = table.concat(opts.lpaths, ';') .. ';' .. package.path
  end

  if #opts.cpaths > 0 then
    package.cpath = table.concat(opts.cpaths, ';') .. ';' .. package.cpath
  end

  --- @type test.harness.RuntimeBaseline
  local pre_helper_baseline = {
    cwd = assert(uv.cwd()),
    package_path = package.path,
    package_cpath = package.cpath,
    package_preload = vim._copy(package.preload),
    globals = vim._copy(_G),
    loaded = vim._copy(package.loaded),
    env = vim._copy(uv.os_environ()),
    arg = vim._copy(_G.arg or {}),
  }
  local files = {} --- @type test.harness.FileEntry[]
  local seen_files = {} --- @type table<string, boolean>
  for _, path in ipairs(opts.paths) do
    local ok, collect_err = collect_test_files(path, files, seen_files)
    if not ok then
      io.stderr:write(collect_err .. '\n')
      return 1
    end
  end

  table.sort(files, function(a, b)
    return a.display_name < b.display_name
  end)

  if #files == 0 then
    io.stderr:write('No test files found.\n')
    return 1
  end

  local ReporterModule = require('reporter')
  local exit_code = 0
  local ran_any = false
  for repeat_index = 1, opts.repeat_count do
    local result, run_err =
      run_iteration(ReporterModule, opts, files, pre_helper_baseline, repeat_index)
    if not result then
      io.stderr:write(run_err .. '\n')
      return 1
    end

    ran_any = ran_any or result.ran_any

    if not result.ran_any and result.summary.result_count == 0 then
      io.stderr:write('No tests matched the current selection.\n')
      exit_code = 1
      break
    end

    if result.summary.failure_count > 0 or result.summary.error_count > 0 then
      exit_code = 1
    end

    if result.stop_requested then
      break
    end
  end

  if not ran_any then
    exit_code = 1
  end

  return exit_code
end

return M
