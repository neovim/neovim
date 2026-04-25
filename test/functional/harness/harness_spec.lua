-- Black-box tests for the local Lua harness itself. These spawn a separate
-- low-level Nvim process instead of driving an embedded instance via testnvim.
local t = require('test.testutil')
local uv = vim.uv

local eq = t.eq
local matches = t.matches
local not_matches = t.not_matches

local root = t.paths.test_source_path
local build_dir = t.paths.test_build_dir
local nvim_prog = build_dir .. '/bin/nvim'
local runner = root .. '/test/runner.lua'

---@param path string
local function mkdir(path)
  assert(t.mkdir(path), ('failed to create directory: %s'):format(path))
end

---@param suite_files table<string, string>
---@return string
local function write_suite(suite_files)
  local dir = t.tmpname(false)
  mkdir(dir)

  for name, contents in pairs(suite_files) do
    t.write_file(dir .. '/' .. name, contents)
  end

  return dir
end

---@param overrides table<string, string?>
---@return string[]
local function make_env(overrides)
  local env = uv.os_environ()
  for k, v in pairs(overrides) do
    env[k] = v
  end

  local items = {}
  for k, v in pairs(env) do
    if v ~= nil then
      items[#items + 1] = k .. '=' .. v
    end
  end

  return items
end

---@param suite_dir string
---@param extra_args? string[]
---@return integer, string
local function run_harness(suite_dir, extra_args)
  local env_root = t.tmpname(false)
  mkdir(env_root)
  mkdir(env_root .. '/config')
  mkdir(env_root .. '/share')
  mkdir(env_root .. '/state')
  mkdir(env_root .. '/tmp')

  local stdout = assert(uv.new_pipe(false))
  local stderr = assert(uv.new_pipe(false))
  local out = {}
  local err = {}
  local exit_code --- @type integer?

  local args = {
    '-ll',
    runner,
    '-v',
    '--lpath=' .. build_dir .. '/?.lua',
    '--lpath=' .. root .. '/src/?.lua',
    '--lpath=' .. root .. '/runtime/lua/?.lua',
    '--lpath=' .. suite_dir .. '/?.lua',
    '--lpath=?.lua',
  }
  for _, arg in ipairs(extra_args or {}) do
    args[#args + 1] = arg
  end
  args[#args + 1] = suite_dir

  local handle = assert(uv.spawn(nvim_prog, {
    args = args,
    env = make_env({
      NVIM_TEST = '1',
      TEST_COLORS = '0',
      VIMRUNTIME = root .. '/runtime',
      XDG_CONFIG_HOME = env_root .. '/config',
      XDG_DATA_HOME = env_root .. '/share',
      XDG_STATE_HOME = env_root .. '/state',
      NVIM_RPLUGIN_MANIFEST = env_root .. '/rplugin_manifest',
      NVIM_LOG_FILE = env_root .. '/nvim.log',
      TMPDIR = env_root .. '/tmp',
      SYSTEM_NAME = os.getenv('SYSTEM_NAME') or uv.os_uname().sysname,
      SHELL = os.getenv('SHELL') or 'sh',
    }),
    stdio = { nil, stdout, stderr },
    hide = true,
  }, function(code, _signal)
    exit_code = code
  end))

  local function read_all(pipe, chunks)
    pipe:read_start(function(read_err, chunk)
      assert(not read_err, read_err)
      if chunk == nil then
        pipe:read_stop()
        pipe:close()
      else
        chunks[#chunks + 1] = chunk
      end
    end)
  end

  read_all(stdout, out)
  read_all(stderr, err)

  while exit_code == nil or not stdout:is_closing() or not stderr:is_closing() do
    uv.run('once')
  end

  handle:close()
  while not handle:is_closing() do
    uv.run('once')
  end

  return exit_code, table.concat(out) .. table.concat(err)
end

---@param suite_dir string
---@param extra_args? string[]
local function assert_harness_passes(suite_dir, extra_args)
  local code, output = run_harness(suite_dir, extra_args)
  eq(0, code)
  matches('PASSED', output, true)
end

describe('test harness', function()
  it('restores package.preload between files', function()
    local suite_dir = write_suite({
      ['one_spec.lua'] = [[
        package.preload.leak_mod = function()
          return 'leak'
        end

        describe('one', function()
          it('defines a preload entry', function()
            assert.Equal('leak', require('leak_mod'))
          end)
        end)
      ]],
      ['two_spec.lua'] = [[
        describe('two', function()
          it('does not see the preload entry from another file', function()
            local ok = pcall(require, 'leak_mod')
            assert.False(ok)
          end)
        end)
      ]],
    })

    assert_harness_passes(suite_dir)
  end)

  it('restores package.loaded between files', function()
    local suite_dir = write_suite({
      ['loaded_mod.lua'] = [[
        return { source = 'file' }
      ]],
      ['one_spec.lua'] = [[
        describe('one', function()
          it('mutates package.loaded', function()
            assert.Equal('file', require('loaded_mod').source)
            package.loaded.loaded_mod = 'leak'
            assert.Equal('leak', require('loaded_mod'))
          end)
        end)
      ]],
      ['two_spec.lua'] = [[
        describe('two', function()
          it('does not see package.loaded leaks from another file', function()
            local mod = require('loaded_mod')
            assert.Equal('file', mod.source)
          end)
        end)
      ]],
    })

    assert_harness_passes(suite_dir)
  end)

  it('restores environment variables between files', function()
    local env_name = '__NVIM_HARNESS_TEST_ENV__'
    local suite_dir = write_suite({
      ['one_spec.lua'] = string.format(
        [[
        describe('one', function()
          it('mutates the environment', function()
            vim.uv.os_setenv(%q, 'leak')
            assert.Equal('leak', vim.uv.os_getenv(%q))
          end)
        end)
      ]],
        env_name,
        env_name
      ),
      ['two_spec.lua'] = string.format(
        [[
        describe('two', function()
          it('does not see environment leaks from another file', function()
            assert.Equal(nil, vim.uv.os_getenv(%q))
          end)
        end)
      ]],
        env_name
      ),
    })

    assert_harness_passes(suite_dir)
  end)

  it('restores globals between files', function()
    local suite_dir = write_suite({
      ['one_spec.lua'] = [[
        describe('one', function()
          it('mutates a global', function()
            _G.__harness_leak = 'leak'
            assert.Equal('leak', _G.__harness_leak)
          end)
        end)
      ]],
      ['two_spec.lua'] = [[
        describe('two', function()
          it('does not see global leaks from another file', function()
            assert.Equal(nil, _G.__harness_leak)
          end)
        end)
      ]],
    })

    assert_harness_passes(suite_dir)
  end)

  it('restores arg between files', function()
    local suite_dir = write_suite({
      ['one_spec.lua'] = [[
        describe('one', function()
          it('mutates arg', function()
            _G.arg.__leak = 'leak'
            assert.Equal('leak', _G.arg.__leak)
          end)
        end)
      ]],
      ['two_spec.lua'] = [[
        describe('two', function()
          it('does not see arg leaks from another file', function()
            assert.Equal(nil, _G.arg.__leak)
          end)
        end)
      ]],
    })

    assert_harness_passes(suite_dir)
  end)

  it('restores helper-provided globals to their baseline between files', function()
    local suite_dir = write_suite({
      ['helper.lua'] = [[
        _G.helper_value = 'baseline'
      ]],
      ['one_spec.lua'] = [[
        describe('one', function()
          it('mutates a helper-provided global', function()
            assert.Equal('baseline', _G.helper_value)
            _G.helper_value = 'leak'
            assert.Equal('leak', _G.helper_value)
          end)
        end)
      ]],
      ['two_spec.lua'] = [[
        describe('two', function()
          it('restores the helper baseline between files', function()
            assert.Equal('baseline', _G.helper_value)
          end)
        end)
      ]],
    })

    assert_harness_passes(suite_dir, {
      '--helper=' .. suite_dir .. '/helper.lua',
    })
  end)

  it('restores helper-provided globals shallowly between files', function()
    local suite_dir = write_suite({
      ['helper.lua'] = [[
        _G.helper_value = { nested = 'baseline' }
      ]],
      ['one_spec.lua'] = [[
        describe('one', function()
          it('mutates nested helper state in place', function()
            assert.Equal('baseline', _G.helper_value.nested)
            _G.helper_value.nested = 'leak'
            assert.Equal('leak', _G.helper_value.nested)
          end)
        end)
      ]],
      ['two_spec.lua'] = [[
        describe('two', function()
          it('keeps the same nested helper table', function()
            assert.Equal('leak', _G.helper_value.nested)
          end)
        end)
      ]],
    })

    assert_harness_passes(suite_dir, {
      '--helper=' .. suite_dir .. '/helper.lua',
    })
  end)

  it('keeps helper-loaded modules across files', function()
    local suite_dir = write_suite({
      ['helper_mod.lua'] = [[
        _G.helper_module_loads = (_G.helper_module_loads or 0) + 1
        return { loads = _G.helper_module_loads }
      ]],
      ['helper.lua'] = [[
        require('helper_mod')
      ]],
      ['one_spec.lua'] = [[
        describe('one', function()
          it('uses the helper-loaded module', function()
            assert.Equal(1, require('helper_mod').loads)
          end)
        end)
      ]],
      ['two_spec.lua'] = [[
        describe('two', function()
          it('does not reload the helper module', function()
            assert.Equal(1, require('helper_mod').loads)
          end)
        end)
      ]],
    })

    assert_harness_passes(suite_dir, {
      '--helper=' .. suite_dir .. '/helper.lua',
    })
  end)

  it('rejects helpers that register hooks', function()
    local suite_dir = write_suite({
      ['helper.lua'] = [[
        before_each(function() end)
      ]],
      ['one_spec.lua'] = [[
        describe('real', function()
          it('passes', function() end)
        end)
      ]],
    })

    local code, output = run_harness(suite_dir, {
      '--helper=' .. suite_dir .. '/helper.lua',
    })

    eq(1, code)
    matches("attempt to call global 'before_each'", output, true)
  end)

  it('rejects helpers that define suites or tests', function()
    local suite_dir = write_suite({
      ['helper.lua'] = [[
        describe('helper suite', function()
          it('should fail', function() end)
        end)
      ]],
      ['one_spec.lua'] = [[
        describe('real', function()
          it('passes', function() end)
        end)
      ]],
    })

    local code, output = run_harness(suite_dir, {
      '--helper=' .. suite_dir .. '/helper.lua',
    })

    eq(1, code)
    matches("attempt to call global 'describe'", output, true)
  end)

  it('deduplicates suite-end callbacks registered from the same module', function()
    local marker = t.tmpname(false)
    local suite_dir = write_suite({
      ['cbmod.lua'] = string.format(
        [[
        local harness = require('test.harness')

        harness.on_suite_end(function()
          local file = assert(io.open(%q, 'ab'))
          file:write('hit\n')
          file:close()
        end)

        return true
      ]],
        marker
      ),
      ['one_spec.lua'] = [[
        require('cbmod')

        describe('one', function()
          it('works', function()
            assert.True(true)
          end)
        end)
      ]],
      ['two_spec.lua'] = [[
        require('cbmod')

        describe('two', function()
          it('works', function()
            assert.True(true)
          end)
        end)
      ]],
    })

    assert_harness_passes(suite_dir)
    eq('hit\n', t.read_file(marker))
  end)

  it(
    'keeps distinct suite-end callbacks from long paths with the same truncated short_src tail',
    function()
      local marker = t.tmpname(false)
      local suite_dir = t.tmpname(false)
      local left = suite_dir
        .. '/'
        .. string.rep('L', 100)
        .. '/common/common/common/common/common/same_suffix'
      local right = suite_dir
        .. '/'
        .. string.rep('R', 100)
        .. '/common/common/common/common/common/same_suffix'

      mkdir(suite_dir)
      for _, path in ipairs({ left, right }) do
        local parents = {}
        local dir = path
        while dir ~= suite_dir and not uv.fs_stat(dir) do
          table.insert(parents, 1, dir)
          dir = vim.fs.dirname(dir)
        end
        for _, parent in ipairs(parents) do
          if not uv.fs_stat(parent) then
            mkdir(parent)
          end
        end
      end

      t.write_file(
        left .. '/same_spec.lua',
        string.format(
          [[
        local harness = require('test.harness')

        harness.on_suite_end(function()
          local file = assert(io.open(%q, 'ab'))
          file:write('left\n')
          file:close()
        end)

        describe('left', function()
          it('works', function() end)
        end)
      ]],
          marker
        )
      )
      t.write_file(
        right .. '/same_spec.lua',
        string.format(
          [[
        local harness = require('test.harness')

        harness.on_suite_end(function()
          local file = assert(io.open(%q, 'ab'))
          file:write('right\n')
          file:close()
        end)

        describe('right', function()
          it('works', function() end)
        end)
      ]],
          marker
        )
      )

      assert_harness_passes(suite_dir)
      eq('left\nright\n', t.read_file(marker))
    end
  )

  it('reports suite-end callback failures without crashing the runner', function()
    local suite_dir = write_suite({
      ['cbmod.lua'] = [[
        local harness = require('test.harness')

        harness.on_suite_end(function()
          error('boom from suite_end')
        end)

        return true
      ]],
      ['one_spec.lua'] = [[
        require('cbmod')

        describe('one', function()
          it('works', function()
            assert.True(true)
          end)
        end)
      ]],
    })

    local code, output = run_harness(suite_dir)

    eq(1, code)
    matches('[suite_end 1]', output, true)
    matches('suite_end', output, true)
    matches('boom from suite_end', output, true)
    matches('ERROR   ', output, true)
    not_matches('FAILED  ', output, true)
    matches('1 test from 1 test file of ' .. suite_dir .. ' ran.', output, true)
    matches('Global test environment teardown.', output, true)
  end)

  it('reports wrapped suite-end callback failures at the callback definition line', function()
    local suite_dir = write_suite({
      ['wrapper.lua'] = [[
        local M = {}

        function M.fail()
          error('boom from wrapper')
        end

        return M
      ]],
      ['cbmod.lua'] = [[
        local harness = require('test.harness')
        local wrapper = require('wrapper')

        harness.on_suite_end(function()
          wrapper.fail()
        end)

        return true
      ]],
      ['one_spec.lua'] = [[
        require('cbmod')

        describe('one', function()
          it('works', function()
            assert.True(true)
          end)
        end)
      ]],
    })

    local code, output = run_harness(suite_dir)

    eq(1, code)
    matches('cbmod.lua @ 4: [suite_end 1]', output, true)
    not_matches('wrapper.lua @ 4:', output, true)
  end)

  it('reloads helper suite-end callbacks between repeats', function()
    local marker = t.tmpname(false)
    local suite_dir = write_suite({
      ['helper.lua'] = string.format(
        [[
        local harness = require('test.harness')
        local hits = 0

        harness.on_suite_end(function()
          hits = hits + 1
          local file = assert(io.open(%q, 'ab'))
          file:write(hits .. '\n')
          file:close()
        end)
      ]],
        marker
      ),
      ['one_spec.lua'] = [[
        describe('one', function()
          it('works', function()
            assert.True(true)
          end)
        end)
      ]],
    })

    assert_harness_passes(suite_dir, {
      '--helper=' .. suite_dir .. '/helper.lua',
      '--repeat=2',
    })
    eq('1\n1\n', t.read_file(marker))
  end)

  it('restores process state before each repeat', function()
    local suite_dir = write_suite({
      ['one_spec.lua'] = [[
        local harness = require('test.harness')

        harness.on_suite_end(function()
          _G.__repeat_leak = 'leak'
        end)

        describe('one', function()
          it('starts clean', function()
            assert.Equal(nil, _G.__repeat_leak)
          end)
        end)
      ]],
    })

    assert_harness_passes(suite_dir, {
      '--repeat=2',
    })
  end)

  it('filters tests by tags across files', function()
    local suite_dir = write_suite({
      ['one_spec.lua'] = [[
        describe('one', function()
          it('fast #fast', function() end)
        end)
      ]],
      ['two_spec.lua'] = [[
        describe('two', function()
          it('slow #slow', function() end)
        end)
      ]],
    })

    local code, output = run_harness(suite_dir, {
      '--tags=fast',
    })

    eq(0, code)
    matches('1 test from 1 test file of ' .. suite_dir .. ' ran.', output, true)
    matches('one fast #fast', output, true)
    not_matches('two slow #slow', output, true)
  end)

  it('filters tests by suite tags across files', function()
    local suite_dir = write_suite({
      ['one_spec.lua'] = [[
        describe('one #fast', function()
          it('works', function() end)
        end)
      ]],
      ['two_spec.lua'] = [[
        describe('two #slow', function()
          it('works', function() end)
        end)
      ]],
    })

    local code, output = run_harness(suite_dir, {
      '--tags=fast',
    })

    eq(0, code)
    matches('1 test from 1 test file of ' .. suite_dir .. ' ran.', output, true)
    matches('one #fast works', output, true)
    not_matches('two #slow works', output, true)
  end)

  it('filters tests by name across files', function()
    local suite_dir = write_suite({
      ['one_spec.lua'] = [[
        describe('one', function()
          it('chosen', function() end)
        end)
      ]],
      ['two_spec.lua'] = [[
        describe('two', function()
          it('skipped', function() end)
        end)
      ]],
    })

    local code, output = run_harness(suite_dir, {
      '--filter=chosen',
    })

    eq(0, code)
    matches('1 test from 1 test file of ' .. suite_dir .. ' ran.', output, true)
    matches('one chosen', output, true)
    not_matches('two skipped', output, true)
  end)

  it('filters tests by suite name across files', function()
    local suite_dir = write_suite({
      ['one_spec.lua'] = [[
        describe('chosen suite', function()
          it('works', function() end)
        end)
      ]],
      ['two_spec.lua'] = [[
        describe('skipped suite', function()
          it('works', function() end)
        end)
      ]],
    })

    local code, output = run_harness(suite_dir, {
      '--filter',
      'chosen suite',
    })

    eq(0, code)
    matches('1 test from 1 test file of ' .. suite_dir .. ' ran.', output, true)
    matches('chosen suite works', output, true)
    not_matches('skipped suite works', output, true)
  end)

  it('does not keep suite-end callbacks from filtered-out files', function()
    local marker = t.tmpname(false)
    local suite_dir = write_suite({
      ['one_spec.lua'] = string.format(
        [[
        local harness = require('test.harness')

        harness.on_suite_end(function()
          local file = assert(io.open(%q, 'ab'))
          file:write('filtered\n')
          file:close()
        end)

        describe('one', function()
          it('skipped', function()
            assert.True(true)
          end)
        end)
      ]],
        marker
      ),
      ['two_spec.lua'] = [[
        describe('two', function()
          it('chosen', function()
            assert.True(true)
          end)
        end)
      ]],
    })

    local code, output = run_harness(suite_dir, {
      '--filter=chosen',
    })

    eq(0, code)
    eq(nil, uv.fs_stat(marker))
    matches('1 test from 1 test file of ' .. suite_dir .. ' ran.', output, true)
  end)

  it('filters tests out by name across files', function()
    local suite_dir = write_suite({
      ['one_spec.lua'] = [[
        describe('one', function()
          it('chosen', function() end)
        end)
      ]],
      ['two_spec.lua'] = [[
        describe('two', function()
          it('skipped', function() end)
        end)
      ]],
    })

    local code, output = run_harness(suite_dir, {
      '--filter-out=skipped',
    })

    eq(0, code)
    matches('1 test from 1 test file of ' .. suite_dir .. ' ran.', output, true)
    matches('one chosen', output, true)
    not_matches('two skipped', output, true)
  end)

  it('filters tests out by suite name across files', function()
    local suite_dir = write_suite({
      ['one_spec.lua'] = [[
        describe('chosen suite', function()
          it('works', function() end)
        end)
      ]],
      ['two_spec.lua'] = [[
        describe('skipped suite', function()
          it('works', function() end)
        end)
      ]],
    })

    local code, output = run_harness(suite_dir, {
      '--filter-out',
      'skipped suite',
    })

    eq(0, code)
    matches('1 test from 1 test file of ' .. suite_dir .. ' ran.', output, true)
    matches('chosen suite works', output, true)
    not_matches('skipped suite works', output, true)
  end)

  it('reports when filters exclude all tests', function()
    local suite_dir = write_suite({
      ['one_spec.lua'] = [[
        describe('one', function()
          it('skipped', function() end)
        end)
      ]],
    })

    local code, output = run_harness(suite_dir, {
      '--filter-out=.',
    })

    eq(1, code)
    matches('No tests matched the current selection.', output, true)
    not_matches('Running tests from', output, true)
  end)

  it('reports malformed filter patterns clearly before selection runs', function()
    local suite_dir = write_suite({
      ['one_spec.lua'] = [[
        describe('one', function()
          it('works', function() end)
        end)
      ]],
    })

    for _, case in ipairs({
      { '--filter=[', 'invalid value for --filter: malformed pattern' },
      { '--filter-out=[', 'invalid value for --filter-out: malformed pattern' },
    }) do
      local code, output = run_harness(suite_dir, { case[1] })

      eq(1, code)
      matches(case[2], output, true)
      not_matches('test_selected', output, true)
      not_matches('Running tests from', output, true)
      not_matches('test harness failed with exit code', output, true)
    end
  end)

  it('skips unreadable test directories and keeps running readable files', function()
    if t.is_os('win') then
      pending('N/A: permission denied directory scan depends on POSIX chmod')
    end

    local suite_dir = t.tmpname(false)
    mkdir(suite_dir)
    t.write_file(
      suite_dir .. '/one_spec.lua',
      [[
        describe('one', function()
          it('works', function() end)
        end)
      ]]
    )
    local blocked = suite_dir .. '/blocked'

    mkdir(blocked)
    t.write_file(
      blocked .. '/two_spec.lua',
      [[
        describe('two', function()
          it('is hidden behind permissions', function() end)
        end)
      ]]
    )
    finally(function()
      assert(uv.fs_chmod(blocked, 448))
    end)
    assert(uv.fs_chmod(blocked, 0))

    local code, output = run_harness(suite_dir)

    eq(0, code)
    matches('Running tests from', output, true)
    matches('one works', output, true)
    not_matches('two is hidden behind permissions', output, true)
    matches('1 test from 1 test file of ' .. suite_dir .. ' ran.', output, true)
  end)

  it('reports missing test paths clearly before loading suites', function()
    local suite_dir = write_suite({
      ['one_spec.lua'] = [[
        describe('one', function()
          it('works', function() end)
        end)
      ]],
    })
    local missing = suite_dir .. '/missing'

    local code, output = run_harness(suite_dir, { missing })

    eq(1, code)
    matches('test path not found: ' .. missing, output, true)
    not_matches('collect_test_files', output, true)
    not_matches('Running tests from', output, true)
    not_matches('test harness failed with exit code', output, true)
  end)

  it('reports missing helpers clearly before running suites', function()
    local suite_dir = write_suite({
      ['one_spec.lua'] = [[
        describe('one', function()
          it('works', function() end)
        end)
      ]],
    })
    local missing = suite_dir .. '/missing.lua'

    local code, output = run_harness(suite_dir, {
      '--helper=' .. missing,
    })

    eq(1, code)
    matches('cannot open ' .. missing, output, true)
    not_matches('load_helper', output, true)
    not_matches('Running tests from', output, true)
    not_matches('test harness failed with exit code', output, true)
  end)

  it('reports empty value options before running suites', function()
    local suite_dir = write_suite({
      ['one_spec.lua'] = [[
        describe('one', function()
          it('works', function() end)
        end)
      ]],
    })

    for _, case in ipairs({
      { '--helper=', 'missing value for --helper' },
      { '--summary-file=', 'missing value for --summary-file' },
    }) do
      local code, output = run_harness(suite_dir, {
        case[1],
      })

      eq(1, code)
      matches(case[2], output, true)
      not_matches('open_summary_file', output, true)
      not_matches('Running tests from', output, true)
      not_matches('test harness failed with exit code', output, true)
    end
  end)

  it('treats the next argv item as the value even when it starts with dashes', function()
    local suite_dir = write_suite({
      ['one_spec.lua'] = [[
        describe('one', function()
          it('works', function() end)
        end)
      ]],
    })

    local code, output = run_harness(suite_dir, { '--filter', '--verbose' })

    eq(1, code)
    matches('No tests matched the current selection.', output, true)
    not_matches('missing value for --filter', output, true)

    code, output = run_harness(suite_dir, { '--repeat', '-1' })

    eq(1, code)
    matches('invalid value for --repeat: -1', output, true)
    not_matches('missing value for --repeat', output, true)
  end)

  it('reports test-body errors as failures', function()
    local suite_dir = write_suite({
      ['one_spec.lua'] = [[
        describe('one', function()
          it('fails', function()
            error('boom from test')
          end)
        end)
      ]],
    })

    local code, output = run_harness(suite_dir)

    eq(1, code)
    matches('boom from test', output, true)
    matches('FAILED  ', output, true)
    not_matches('ERROR   ', output, true)
  end)

  it('reports test-body failures at the failing line', function()
    local suite_dir = write_suite({
      ['one_spec.lua'] = [[
        describe('one', function()
          it('fails', function()
            error('boom from test')
          end)
        end)
      ]],
    })

    local code, output = run_harness(suite_dir)

    eq(1, code)
    matches('one_spec.lua @ 3: one fails', output, true)
  end)

  it('ignores fake trace lines embedded in multiline error messages', function()
    local suite_dir = write_suite({
      ['one_spec.lua'] = [[
        describe('one', function()
          it('fake trace', function()
            error('boom\n' .. debug.getinfo(1, 'S').source:sub(2) .. ':999: fake trace', 0)
          end)
        end)
      ]],
    })

    local code, output = run_harness(suite_dir)

    eq(1, code)
    matches('one_spec.lua @ 3: one fake trace', output, true)
    not_matches('one_spec.lua @ 999: one fake trace', output, true)
  end)

  it('reports wrapped assertion failures at the test definition line', function()
    local suite_dir = write_suite({
      ['one_spec.lua'] = [[
        describe('one', function()
          it('equal fail', function()
            assert.Equal(1, 2)
          end)
        end)
      ]],
    })

    local code, output = run_harness(suite_dir)

    eq(1, code)
    matches('one_spec.lua @ 2: one equal fail', output, true)
    not_matches(root .. '/test/assert.lua @', output, true)
  end)

  it('reports local wrapper failures at the test definition line', function()
    local suite_dir = write_suite({
      ['wrapper.lua'] = [[
        local M = {}

        function M.fail()
          error('boom from wrapper')
        end

        return M
      ]],
      ['one_spec.lua'] = [[
        local wrapper = require('wrapper')

        describe('one', function()
          it('wrapper fail', function()
            wrapper.fail()
          end)
        end)
      ]],
    })

    local code, output = run_harness(suite_dir)

    eq(1, code)
    matches('one_spec.lua @ 4: one wrapper fail', output, true)
    not_matches('wrapper.lua @ 4:', output, true)
  end)

  it('reports failing finally cleanup at the cleanup line', function()
    local suite_dir = write_suite({
      ['one_spec.lua'] = [[
        describe('one', function()
          it('finfail', function()
            finally(function()
              error('boom fin')
            end)
            pending('later')
          end)
        end)
      ]],
    })

    local code, output = run_harness(suite_dir)

    eq(1, code)
    matches('one_spec.lua @ 4: one finfail', output, true)
  end)

  it('rejects finally in setup hooks', function()
    local suite_dir = write_suite({
      ['one_spec.lua'] = [[
        describe('one', function()
          setup(function()
            finally(function() end)
          end)

          it('works', function() end)
        end)
      ]],
    })

    local code, output = run_harness(suite_dir)

    eq(1, code)
    matches('one_spec.lua @ 2: one [setup]', output, true)
    matches('finally() must be called while a test body is running', output, true)
  end)

  it('rejects finally in teardown hooks', function()
    local suite_dir = write_suite({
      ['one_spec.lua'] = [[
        describe('one', function()
          teardown(function()
            finally(function() end)
          end)

          it('works', function() end)
        end)
      ]],
    })

    local code, output = run_harness(suite_dir)

    eq(1, code)
    matches('one_spec.lua @ 2: one [teardown]', output, true)
    matches('finally() must be called while a test body is running', output, true)
  end)

  it('reports failing after_each cleanup at the cleanup line', function()
    local suite_dir = write_suite({
      ['one_spec.lua'] = [[
        describe('one', function()
          after_each(function()
            error('boom after')
          end)

          it('afterfail', function()
            pending('later')
          end)
        end)
      ]],
    })

    local code, output = run_harness(suite_dir)

    eq(1, code)
    matches('one_spec.lua @ 3: one afterfail', output, true)
  end)

  it('reports cross-file after_each wrapper failures at the hook definition line', function()
    local suite_dir = write_suite({
      ['wrapper.lua'] = [[
        local M = {}

        function M.fail()
          error('boom from wrapper')
        end

        return M
      ]],
      ['one_spec.lua'] = [[
        local wrapper = require('wrapper')

        describe('one', function()
          after_each(function()
            wrapper.fail()
          end)

          it('afterwrap', function()
            assert.True(true)
          end)
        end)
      ]],
    })

    local code, output = run_harness(suite_dir)

    eq(1, code)
    matches('one_spec.lua @ 4: one afterwrap', output, true)
    not_matches('one_spec.lua @ 8: one afterwrap', output, true)
    not_matches('wrapper.lua @ 4:', output, true)
  end)

  it(
    'reports pending cross-file after_each wrapper failures at the hook definition line',
    function()
      local suite_dir = write_suite({
        ['wrapper.lua'] = [[
        local M = {}

        function M.fail()
          error('boom from wrapper')
        end

        return M
      ]],
        ['one_spec.lua'] = [[
        local wrapper = require('wrapper')

        describe('one', function()
          after_each(function()
            wrapper.fail()
          end)

          it('afterwrap pending', function()
            pending('later')
          end)
        end)
      ]],
      })

      local code, output = run_harness(suite_dir)

      eq(1, code)
      matches('one_spec.lua @ 4: one afterwrap pending', output, true)
      not_matches('one_spec.lua @ 8: one afterwrap pending', output, true)
      not_matches('wrapper.lua @ 4:', output, true)
    end
  )

  it('reports cross-file finally wrapper failures at the cleanup definition line', function()
    local suite_dir = write_suite({
      ['wrapper.lua'] = [[
        local M = {}

        function M.fail()
          error('boom from wrapper')
        end

        return M
      ]],
      ['one_spec.lua'] = [[
        local wrapper = require('wrapper')

        describe('one', function()
          it('finwrap', function()
            finally(function()
              wrapper.fail()
            end)
          end)
        end)
      ]],
    })

    local code, output = run_harness(suite_dir)

    eq(1, code)
    matches('one_spec.lua @ 5: one finwrap', output, true)
    not_matches('one_spec.lua @ 4: one finwrap', output, true)
    not_matches('wrapper.lua @ 4:', output, true)
  end)

  it('does not count synthetic hook failures as executed tests', function()
    local suite_dir = write_suite({
      ['one_spec.lua'] = [[
        describe('trace', function()
          setup(function()
            error('boom setup')
          end)

          it('passes', function() end)
        end)
      ]],
    })

    local code, output = run_harness(suite_dir)

    eq(1, code)
    matches('0 tests from 1 test file of ' .. suite_dir .. ' ran.', output, true)
    matches('1 ERROR', output, true)
  end)

  it('reports setup failures at the hook definition site', function()
    local suite_dir = write_suite({
      ['one_spec.lua'] = [[
        describe('trace', function()
          setup(function()
            error('boom setup')
          end)

          it('passes', function() end)
        end)
      ]],
    })

    local code, output = run_harness(suite_dir)

    eq(1, code)
    matches('one_spec.lua @ 2: trace [setup]', output, true)
  end)

  it('does not keep suite-end callbacks from load-error files', function()
    local marker = t.tmpname(false)
    local suite_dir = write_suite({
      ['one_spec.lua'] = string.format(
        [[
        local harness = require('test.harness')

        harness.on_suite_end(function()
          local file = assert(io.open(%q, 'ab'))
          file:write('load\n')
          file:close()
        end)

        error('boom during load')
      ]],
        marker
      ),
    })

    local code, output = run_harness(suite_dir)

    eq(1, code)
    eq(nil, uv.fs_stat(marker))
    matches('boom during load', output, true)
  end)

  it('reports load failures at the failing line', function()
    local suite_dir = write_suite({
      ['one_spec.lua'] = [[
        local ok = true

        local broken = )
      ]],
    })

    local code, output = run_harness(suite_dir)

    eq(1, code)
    matches('one_spec%.lua @ 3: .-one_spec%.lua %[load%]', output)
  end)

  it('reports required-module syntax errors at the real module line', function()
    local suite_dir = write_suite({
      ['broken.lua'] = [[
        local ok = true

        local broken = )
      ]],
      ['one_spec.lua'] = [[
        require('broken')

        describe('one', function()
          it('works', function() end)
        end)
      ]],
    })

    local code, output = run_harness(suite_dir)

    eq(1, code)
    matches('broken%.lua @ 3: .-one_spec%.lua %[load%]', output)
  end)
end)
