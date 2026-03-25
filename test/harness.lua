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

--- Source location recorded for defined suites, tests, and hooks.
--- @class test.harness.Trace
--- @field short_src string
--- @field currentline integer

--- Structured error payload used internally by the harness.
--- @class test.harness.ErrorPayload
--- @field __harness_pending? boolean
--- @field message string
--- @field traceback? string

--- Base node shared by suite and test definitions.
--- @class test.harness.Element
--- @field kind 'suite'|'test'
--- @field name string
--- @field parent? test.harness.Suite
--- @field trace? test.harness.Trace
--- @field duration? number
--- @field full_name? string

--- Hook callback plus the location where it was registered.
--- @class test.harness.Hook
--- @field fn fun()
--- @field trace test.harness.Trace

--- Suite node containing hooks and nested children.
--- @class test.harness.Suite : test.harness.Element
--- @field kind 'suite'
--- @field is_file boolean
--- @field display_name? string
--- @field children test.harness.Element[]
--- @field selected_count integer
---
--- @field setup test.harness.Hook[]
--- @field teardown test.harness.Hook[]
--- @field before_each test.harness.Hook[]
--- @field after_each test.harness.Hook[]

--- Test node containing an optional runnable body.
--- @class test.harness.Test : test.harness.Element
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

--- Collected test file path plus its display label.
--- @class test.harness.FileEntry
--- @field path string
--- @field display_name string

--- Shallow process baseline restored between test files.
--- @class test.harness.Baseline
--- @field cwd string
--- @field package_path string
--- @field package_cpath string
--- @field package_preload table<string, any>
--- @field globals table<any, any>
--- @field loaded table<string, any>
--- @field env table<string, string>
--- @field arg table<integer, string>
--- @field suite_end_callbacks test.harness.SuiteEndRegistration[]

--- Parsed CLI options controlling one harness run.
--- @class test.harness.Options
--- @field keep_going boolean
--- @field verbose boolean
--- @field repeat_count integer
--- @field summary_file string
--- @field test_path_label? string
--- @field helper? string
--- @field tags string[]
--- @field filter? string
--- @field filter_out? string
--- @field lpaths string[]
--- @field cpaths string[]
--- @field paths string[]

--- Callback invoked after each suite iteration finishes.
--- @alias test.harness.SuiteEndCallback fun()

--- Stored suite-end callback together with its registration site.
--- @class test.harness.SuiteEndRegistration
--- @field fn test.harness.SuiteEndCallback
--- @field trace test.harness.Trace
--- @field key string

--- Active execution context for one running hook or test.
--- @class test.harness.Execution
--- @field test? test.harness.Test
--- @field finalizers fun()[]

--- Mutable harness state shared across definition and execution.
--- @class test.harness.State
--- @field suite_end_callbacks test.harness.SuiteEndRegistration[]
--- @field current_define_suite? test.harness.Suite
--- @field current_execution? test.harness.Execution

local uv = vim.uv

--- Public test harness module surface.
--- @class test.harness
--- @field is_ci fun(name?: 'cirrus'|'github'): boolean
--- @field on_suite_end fun(callback: test.harness.SuiteEndCallback): test.harness.SuiteEndCallback
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
--- @param name? 'cirrus'|'github'
--- @return boolean
function M.is_ci(name)
  local any = (name == nil)
  assert(any or name == 'github' or name == 'cirrus')
  local gh = ((any or name == 'github') and nil ~= os.getenv('GITHUB_ACTIONS'))
  local cirrus = ((any or name == 'cirrus') and nil ~= os.getenv('CIRRUS_CI'))
  return gh or cirrus
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
    return nil
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

--- Check whether a path is already absolute.
--- @param path string
--- @return boolean
local function is_absolute_path(path)
  return path:sub(1, 1) == '/' or path:match('^%a:[/\\]') ~= nil or path:match('^[/\\][/\\]') ~= nil
end

--- Normalize a path relative to the current working directory.
--- @param path string
--- @return string
local function normalize_path(path)
  if is_absolute_path(path) then
    return vim.fs.normalize(path)
  end

  return vim.fs.normalize(uv.cwd() .. '/' .. path)
end

--- Render a path relative to the current working directory when possible.
--- @param path string
--- @return string
local function display_path(path)
  local cwd = vim.fs.normalize(uv.cwd())
  local prefix = cwd .. '/'
  if vim.startswith(path, prefix) then
    return path:sub(#prefix + 1)
  end

  return path
end

--- Create a shallow key/value copy of a table.
--- @generic T: table
--- @param tbl T
--- @return T
local function shallow_copy(tbl)
  local ret = {}
  for k, v in pairs(tbl) do
    ret[k] = v
  end
  return ret
end

--- Force two full GC cycles so finalizers can settle before the next file.
local function full_gc()
  -- One full cycle may only run __gc/finalizers for dead userdata/cdata.
  -- Those finalizers can release the last references to more uv/mpack objects,
  -- which do not become collectible until the next cycle. Collect twice before
  -- switching files or ending the harness so leak checks see only live state.
  collectgarbage('collect')
  collectgarbage('collect')
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

--- Capture the shallow process baseline used between test files.
--- @return test.harness.Baseline
local function capture_baseline()
  --- @type test.harness.Baseline
  local baseline = {
    cwd = assert(uv.cwd()),
    package_path = package.path,
    package_cpath = package.cpath,
    package_preload = shallow_copy(package.preload),
    globals = shallow_copy(_G),
    loaded = shallow_copy(package.loaded),
    env = shallow_copy(uv.os_environ()),
    arg = shallow_copy(_G.arg or {}),
    suite_end_callbacks = shallow_copy(state.suite_end_callbacks),
  }
  return baseline
end

--- Restore the harness state to a captured baseline.
--- @param baseline test.harness.Baseline
--- @param reset_suite_end_callbacks? boolean
local function restore_baseline(baseline, reset_suite_end_callbacks)
  if uv.cwd() ~= baseline.cwd then
    uv.chdir(baseline.cwd)
  end

  package.path = baseline.package_path
  package.cpath = baseline.package_cpath
  restore_snapshot(package.preload, baseline.package_preload)
  restore_snapshot(package.loaded, baseline.loaded)
  restore_snapshot(_G, baseline.globals)
  restore_snapshot(uv.os_environ(), baseline.env, uv.os_unsetenv, uv.os_setenv)
  _G.arg = shallow_copy(baseline.arg)
  state.current_define_suite = nil
  state.current_execution = nil
  if reset_suite_end_callbacks then
    state.suite_end_callbacks = shallow_copy(baseline.suite_end_callbacks)
  end
end

--- Restore the baseline and run GC cleanup.
--- @param baseline test.harness.Baseline
--- @param reset_suite_end_callbacks? boolean
local function cleanup_to_baseline(baseline, reset_suite_end_callbacks)
  restore_baseline(baseline, reset_suite_end_callbacks)
  full_gc()
end

--- Capture the source location of a caller frame.
--- @param level? integer
--- @return test.harness.Trace
local function caller_trace(level)
  local info = debug.getinfo(level or 3, 'Sl')
  return {
    short_src = info and vim.fs.normalize(info.short_src or '') or '',
    currentline = info and info.currentline or 0,
  }
end

--- Register a suite-end callback, deduplicated by callsite.
--- @param callback test.harness.SuiteEndCallback
--- @return test.harness.SuiteEndCallback
function M.on_suite_end(callback)
  assert(type(callback) == 'function', 'on_suite_end() expects a function')
  local trace = caller_trace(3)
  local key = ('%s:%d'):format(trace.short_src, trace.currentline)
  for _, registration in ipairs(state.suite_end_callbacks) do
    if registration.key == key then
      return registration.fn
    end
  end
  state.suite_end_callbacks[#state.suite_end_callbacks + 1] = {
    fn = callback,
    trace = trace,
    key = key,
  }
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
    display_name = is_file and name or nil,
    setup = {},
    teardown = {},
    before_each = {},
    after_each = {},
    children = {},
    selected_count = 0,
  }
end

--- Create a test node for the definition tree.
--- @param name string
--- @param fn? fun()
--- @param parent test.harness.Suite
--- @param trace? test.harness.Trace
--- @param pending_message? string
--- @return test.harness.Test
local function create_test(name, fn, parent, trace, pending_message)
  return {
    kind = 'test',
    name = name,
    fn = fn,
    parent = parent,
    trace = trace,
    pending_message = pending_message,
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

  local test = create_test(name, fn, current_suite(), caller_trace(3), pending_message)
  current_suite().children[#current_suite().children + 1] = test
  return test
end

--- Build a chunk-environment hook registrar for the given phase.
--- @param kind test.harness.HookKind
--- @return fun(fn: fun())
local function chunk_hook(kind)
  return function(fn)
    assert(type(fn) == 'function', ('%s expects a function'):format(kind))
    local suite = current_suite()
    local hooks = suite[kind]
    hooks[#hooks + 1] = {
      fn = fn,
      trace = caller_trace(3),
    }
  end
end

local luassert = require('luassert')

-- Chunk env
local C = {
  _G = _G,
  assert = luassert,
  setup = chunk_hook('setup'),
  teardown = chunk_hook('teardown'),
  before_each = chunk_hook('before_each'),
  after_each = chunk_hook('after_each'),
}

--- Define a nested suite in the chunk environment.
--- @param name string
--- @param fn fun()
--- @return test.harness.Suite
function C.describe(name, fn)
  assert(type(name) == 'string', 'describe() expects a string')
  assert(type(fn) == 'function', 'describe() expects a function body')

  local parent = current_suite()
  local suite = create_suite(name, parent, caller_trace(3), false)
  parent.children[#parent.children + 1] = suite

  local previous = state.current_define_suite
  state.current_define_suite = suite
  local ok, err = xpcall(fn, debug.traceback)
  state.current_define_suite = previous

  if not ok then
    error(err, 0)
  end

  return suite
end

--- Define a test in the chunk environment.
--- @param name string
--- @param fn? fun()
--- @return test.harness.Test
function C.it(name, fn)
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
function C.pending(name, block)
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
function C.finally(fn)
  assert(type(fn) == 'function', 'finally() expects a function')
  assert(state.current_execution, 'finally() must be called while a test is running')
  state.current_execution.finalizers[#state.current_execution.finalizers + 1] = fn
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

--- Normalize thrown values into harness error payloads.
--- @param err any
--- @return test.harness.ErrorPayload
local function exception_handler(err)
  if type(err) == 'table' and err.__harness_pending then
    --- @cast err test.harness.ErrorPayload
    return err
  end

  return {
    message = format_error_value(err),
    traceback = debug.traceback('', 2),
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
  }
end

--- Run a callable under harness error handling and finalizer cleanup.
--- @param fn fun()
--- @param current_test? test.harness.Test
--- @param fallback_status? test.harness.ResultStatus
--- @return test.harness.Result
local function run_callable(fn, current_test, fallback_status)
  local previous = state.current_execution
  --- @type test.harness.Execution
  local execution = {
    test = current_test,
    finalizers = {},
  }
  state.current_execution = execution

  local ok, err = xpcall(fn, exception_handler)
  local finalizer_err
  for i = #execution.finalizers, 1, -1 do
    local finalizer_ok, ferr = xpcall(execution.finalizers[i], exception_handler)
    if not finalizer_ok and not finalizer_err then
      finalizer_err = ferr
    end
  end

  state.current_execution = previous

  local result = ok and { status = 'success' } or decode_error(err, fallback_status)
  if not finalizer_err then
    return result
  end

  local finalizer_result = decode_error(finalizer_err, 'error')
  if result.status == 'success' then
    finalizer_result.status = 'error'
    return finalizer_result
  end

  if result.status == 'pending' then
    return {
      status = 'error',
      message = ('finally: %s'):format(finalizer_result.message),
      traceback = finalizer_result.traceback,
    }
  end

  result.message = result.message .. '\n\nfinally: ' .. finalizer_result.message
  if not result.traceback then
    result.traceback = finalizer_result.traceback
  end
  return result
end

--- Build the suite and test name parts used for reporting.
--- @param element test.harness.Element
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
  local count = 0
  for _, child in ipairs(node.children) do
    if child.kind == 'suite' then
      count = count + mark_selected(child, opts)
    else
      --- @cast child test.harness.Test
      child.selected = test_selected(child, opts)
      if child.selected then
        count = count + 1
      end
    end
  end

  node.selected_count = count
  return count
end

--- Collect inherited `before_each` hooks from outermost to innermost.
--- @param suite test.harness.Suite
--- @param hooks test.harness.Hook[]
local function gather_before_each(suite, hooks)
  if suite.parent then
    gather_before_each(suite.parent, hooks)
  end
  for _, hook in ipairs(suite.before_each) do
    hooks[#hooks + 1] = hook
  end
end

--- Collect inherited `after_each` hooks from innermost to outermost.
--- @param suite test.harness.Suite
--- @param hooks test.harness.Hook[]
local function gather_after_each(suite, hooks)
  for _, hook in ipairs(suite.after_each) do
    hooks[#hooks + 1] = hook
  end
  if suite.parent then
    gather_after_each(suite.parent, hooks)
  end
end

--- Reporter record passed to `test_end`.
--- @class test.harness.Record
--- @field name string?
--- @field element test.harness.Element
--- @field message? string
--- @field traceback? string

--- Build the reporter record for a completed result.
--- @param element test.harness.Element
--- @param result test.harness.Result
--- @return test.harness.Record
local function build_record(element, result)
  return {
    name = element.full_name,
    element = element,
    message = result.message,
    traceback = result.traceback,
  }
end

--- Build the synthetic name used for setup, teardown, and load failures.
--- @param parent test.harness.Suite
--- @param phase string
--- @return string
local function synthetic_name(parent, phase)
  local name = M.get_full_name(parent)
  if name == '' then
    name = parent.display_name or parent.name or 'suite'
  end
  return ('%s [%s]'):format(name, phase)
end

--- Report a synthetic result as a test-shaped record.
--- @param reporter test.reporter
--- @param parent test.harness.Suite
--- @param phase string
--- @param result test.harness.Result
--- @return test.harness.ResultStatus
local function run_synthetic_result(reporter, parent, phase, result)
  --- @type test.harness.Element
  local element = {
    kind = 'test',
    name = synthetic_name(parent, phase),
    full_name = synthetic_name(parent, phase),
    parent = parent,
    trace = parent.trace,
    duration = 0,
  }

  reporter:test_start(element)
  local record = build_record(element, result)
  reporter:test_end(element, result.status, record)
  return result.status
end

--- Run registered suite-end callbacks and report failures.
--- @param reporter test.reporter
--- @return boolean
local function run_suite_end_callbacks(reporter)
  local callbacks = shallow_copy(state.suite_end_callbacks)
  local failed = false

  for index, callback in ipairs(callbacks) do
    local result = run_callable(callback.fn, nil, 'error')
    if result.status ~= 'success' then
      failed = true
      result.status = 'error'

      --- @type test.harness.Element
      local element = {
        kind = 'test',
        name = ('[suite_end %d]'):format(index),
        full_name = ('[suite_end %d]'):format(index),
        trace = callback.trace,
        duration = 0,
      }

      reporter:test_start(element)
      reporter:test_end(element, result.status, build_record(element, result))
    end
  end

  return failed
end

--- Run a single test with its surrounding before and after hooks.
--- @param test test.harness.Test
--- @param reporter test.reporter
--- @return test.harness.ResultStatus
local function run_test(test, reporter)
  reporter:test_start(test)

  local start = now_seconds()
  --- @type test.harness.Result
  local result
  if test.fn == nil then
    result = {
      status = 'pending',
      message = test.pending_message,
    }
  else
    result = { status = 'success' }

    local before_hooks = {}
    gather_before_each(test.parent, before_hooks)
    for _, hook in ipairs(before_hooks) do
      result = run_callable(hook.fn, test, 'failure')
      if result.status ~= 'success' then
        break
      end
    end

    if result.status == 'success' then
      result = run_callable(test.fn, test, 'failure')
    end

    local after_hooks = {}
    gather_after_each(test.parent, after_hooks)
    for _, hook in ipairs(after_hooks) do
      local hook_result = run_callable(hook.fn, test, 'failure')
      if result.status == 'success' then
        result = hook_result
      elseif hook_result.status ~= 'success' then
        result.message = (result.message or '')
          .. (result.message and result.message ~= '' and '\n\n' or '')
          .. 'after_each: '
          .. hook_result.message
        if not result.traceback then
          result.traceback = hook_result.traceback
        end
        if result.status == 'pending' then
          result.status = 'error'
        end
      end
    end
  end

  test.duration = now_seconds() - start
  local record = build_record(test, result)
  reporter:test_end(test, result.status, record)
  return result.status
end

--- Run a suite subtree until completion or a stop condition.
--- @param suite test.harness.Suite
--- @param reporter test.reporter
--- @param opts test.harness.Options
--- @return boolean
local function run_suite(suite, reporter, opts)
  if suite.selected_count == 0 then
    return false
  end

  local stop_requested = false
  local run_children = true

  for _, hook in ipairs(suite.setup) do
    local result = run_callable(hook.fn, nil, 'error')
    if result.status ~= 'success' then
      run_synthetic_result(reporter, suite, 'setup', result)
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
        stop_requested = run_suite(child, reporter, opts) or stop_requested
      elseif child.selected then
        local status = run_test(child, reporter)
        if status ~= 'success' and status ~= 'pending' and not opts.keep_going then
          stop_requested = true
        end
      end

      if stop_requested then
        break
      end
    end
  end

  for _, hook in ipairs(suite.teardown) do
    local result = run_callable(hook.fn, nil, 'error')
    if result.status ~= 'success' then
      run_synthetic_result(reporter, suite, 'teardown', result)
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
--- @param seen table<string, boolean>
local function collect_test_files(path, files, seen)
  local abs = normalize_path(path)
  local stat = uv.fs_stat(abs)
  assert(stat, ('test path not found: %s'):format(path))

  if stat.type == 'file' then
    if not seen[abs] then
      seen[abs] = true
      files[#files + 1] = {
        path = abs,
        display_name = display_path(abs),
      }
    end
    return
  end

  assert(stat.type == 'directory', ('unsupported test path: %s'):format(path))

  local handle = assert(uv.fs_scandir(abs))
  while true do
    local name, kind = uv.fs_scandir_next(handle)
    if not name then
      break
    end

    local child = abs .. '/' .. name
    if kind == 'directory' then
      collect_test_files(child, files, seen)
    elseif kind == 'file' and name:match('_spec%.lua$') and not seen[child] then
      seen[child] = true
      files[#files + 1] = {
        path = child,
        display_name = display_path(child),
      }
    end
  end
end

--- Parse harness CLI arguments into execution options.
--- @param argv string[]
--- @return test.harness.Options
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

  --- Parse and deduplicate tag filters.
  --- @param value? string
  local function add_tags(value)
    if type(value) ~= 'string' then
      error('missing value for --tags')
    end

    for token in value:gmatch('[^,%s]+') do
      local tag = token:gsub('^#', '')
      if tag ~= '' and not seen_tags[tag] then
        seen_tags[tag] = true
        opts.tags[#opts.tags + 1] = tag
      end
    end
  end

  --- Parse and validate the `--repeat` argument.
  --- @param value? string
  --- @return integer
  local function parse_repeat_count(value)
    if type(value) ~= 'string' or value == '' then
      error('missing value for --repeat')
    end

    local count = tonumber(value)
    if count == nil or count < 1 or count ~= math.floor(count) then
      error(('invalid value for --repeat: %s'):format(value))
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

  --- @type table<string, fun(value: string)>
  local value_options = {
    ['--repeat'] = function(value)
      opts.repeat_count = parse_repeat_count(value)
    end,
    ['--helper'] = function(value)
      opts.helper = value
    end,
    ['--summary-file'] = function(value)
      opts.summary_file = value
    end,
    ['--test-path-label'] = function(value)
      opts.test_path_label = value
    end,
    ['--tags'] = add_tags,
    ['--filter'] = function(value)
      opts.filter = value
    end,
    ['--filter-out'] = function(value)
      opts.filter_out = value
    end,
    ['--lpath'] = function(value)
      opts.lpaths[#opts.lpaths + 1] = value
    end,
    ['--cpath'] = function(value)
      opts.cpaths[#opts.cpaths + 1] = value
    end,
  }

  local i = 1

  --- Consume the next argv item as the value for `flag`.
  --- @param flag string
  --- @return string
  local function take_value(flag)
    i = i + 1
    local value = argv[i]
    if type(value) ~= 'string' then
      error('missing value for ' .. flag)
    end
    return value
  end

  --- Parse one named option and apply it to `opts`.
  --- @param arg string
  --- @return boolean
  local function apply_named_option(arg)
    local switch = switch_options[arg]
    if switch then
      switch()
      return true
    end

    local eq = arg:find('=', 1, true)
    if eq then
      local handler = value_options[arg:sub(1, eq - 1)]
      if handler then
        handler(arg:sub(eq + 1))
        return true
      end
    end

    local handler = value_options[arg]
    if handler then
      handler(take_value(arg))
      return true
    end

    return false
  end

  while i <= #argv do
    local arg = assert(argv[i])
    if apply_named_option(arg) then
    elseif vim.startswith(arg, '-') then
      error('unknown test harness option: ' .. arg)
    else
      opts.paths[#opts.paths + 1] = arg
    end
    i = i + 1
  end

  if #opts.paths == 0 then
    error('no test paths provided')
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

  return setfenv(chunk, setmetatable(shallow_copy(env), { __index = _G }))
end

--- Load a helper file before the test baseline is captured.
--- @param path string
local function load_helper(path)
  local helper = normalize_path(path)
  -- Helper files are preload-only. They can require modules and register
  -- suite-end callbacks, but they do not participate in test definition.
  local chunk = assert(load_chunk(helper, { _G = _G, assert = luassert }))
  local ok, load_err = xpcall(chunk, debug.traceback)
  if not ok then
    error(load_err, 0)
  end
end

--- Load a test file into a per-file root suite.
--- @param file test.harness.FileEntry
--- @param root_suite test.harness.Suite
--- @return test.harness.Suite, test.harness.Result?
local function load_test_file(file, root_suite)
  local file_suite = create_suite(file.display_name, root_suite, {
    short_src = file.display_name,
    currentline = 1,
  }, true)
  root_suite.children[#root_suite.children + 1] = file_suite

  state.current_define_suite = file_suite
  local chunk, err = load_chunk(file.path, C)
  if not chunk then
    state.current_define_suite = nil
    return file_suite, { status = 'error', message = err }
  end

  local ok, load_err = xpcall(chunk, exception_handler)
  state.current_define_suite = nil
  if not ok then
    local result = decode_error(load_err, 'error')
    result.status = 'error'
    return file_suite, result
  end

  return file_suite, nil
end

--- Run a single file with a fresh shallow harness baseline.
--- @param file test.harness.FileEntry
--- @param reporter test.reporter
--- @param opts test.harness.Options
--- @param baseline test.harness.Baseline
--- @return boolean, boolean
local function run_file(file, reporter, opts, baseline)
  restore_baseline(baseline)

  local root_suite = create_suite('')

  local file_suite, load_result = load_test_file(file, root_suite)
  local selected = mark_selected(file_suite, opts)
  if selected == 0 and not load_result then
    cleanup_to_baseline(baseline)
    return false, false
  end

  --- @type test.reporter.FileElement
  local file_element = { name = file.display_name, duration = 0 }

  reporter:file_start(file_element)

  local start = now_seconds()
  local stop_requested = false
  if load_result then
    local status = run_synthetic_result(reporter, file_suite, 'load', load_result)
    if status ~= 'success' and status ~= 'pending' and not opts.keep_going then
      stop_requested = true
    end
  else
    root_suite.selected_count = selected
    stop_requested = run_suite(root_suite, reporter, opts)
  end

  file_element.duration = now_seconds() - start
  reporter:file_end(file_element)
  cleanup_to_baseline(baseline)
  return true, stop_requested
end

--- Aggregate outcome from running one suite iteration.
--- @class test.harness.IterationResult
--- @field ran_any boolean
--- @field stop_requested boolean
--- @field test_count integer
--- @field has_failures boolean

--- Run one full suite iteration across the selected files.
--- @param Reporter test.reporter
--- @param opts test.harness.Options
--- @param files test.harness.FileEntry[]
--- @param baseline test.harness.Baseline
--- @param repeat_index integer
--- @return test.harness.IterationResult
local function run_iteration(Reporter, opts, files, baseline, repeat_index)
  local reporter = Reporter.new({
    verbose = opts.verbose,
    summary_file = opts.summary_file,
    test_path_label = opts.test_path_label,
    get_failure_output = function()
      return M.read_nvim_log(nil, true)
    end,
  })
  restore_baseline(baseline, true)
  reporter:suite_start(repeat_index, opts.repeat_count)

  local start = now_seconds()
  local ran_any = false
  local stop_requested = false
  for _, file in ipairs(files) do
    local ran_file, stop = run_file(file, reporter, opts, baseline)
    ran_any = ran_any or ran_file
    if stop then
      stop_requested = true
      break
    end
  end

  local duration = now_seconds() - start
  cleanup_to_baseline(baseline)
  run_suite_end_callbacks(reporter)
  cleanup_to_baseline(baseline, true)
  reporter:suite_end(duration)
  return {
    ran_any = ran_any,
    stop_requested = stop_requested,
    test_count = reporter.test_count,
    has_failures = reporter:has_failures(),
  }
end

--- Run the test harness CLI entrypoint.
--- @param argv string[]
--- @return integer
function M.main(argv)
  local opts = parse_args(argv)

  if #opts.lpaths > 0 then
    package.path = table.concat(opts.lpaths, ';') .. ';' .. package.path
  end

  if #opts.cpaths > 0 then
    package.cpath = table.concat(opts.cpaths, ';') .. ';' .. package.cpath
  end

  if opts.helper then
    load_helper(opts.helper)
  end

  local baseline = capture_baseline()
  local files = {} --- @type test.harness.FileEntry[]
  local seen = {} --- @type table<string, boolean>
  for _, path in ipairs(opts.paths) do
    collect_test_files(path, files, seen)
  end

  table.sort(files, function(a, b)
    return a.display_name < b.display_name
  end)

  if #files == 0 then
    io.stderr:write('No test files found.\n')
    return 1
  end

  local Reporter = require('reporter')
  local exit_code = 0
  local ran_any = false
  for repeat_index = 1, opts.repeat_count do
    local result = run_iteration(Reporter, opts, files, baseline, repeat_index)
    ran_any = ran_any or result.ran_any

    if not result.ran_any or result.test_count == 0 then
      io.stderr:write('No tests matched the current selection.\n')
      exit_code = 1
      break
    end

    if result.has_failures then
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
