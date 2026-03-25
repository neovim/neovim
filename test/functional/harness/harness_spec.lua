-- Black-box tests for the local Lua harness itself. These spawn a separate
-- low-level Nvim process instead of driving an embedded instance via testnvim.
local t = require('test.testutil')
local uv = vim.uv

local eq = t.eq

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
  eq(true, output:find('PASSED', 1, true) ~= nil)
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
    eq(true, not not output:find('[suite_end 1]', 1, true))
    eq(true, not not output:find('suite_end', 1, true))
    eq(true, not not output:find('boom from suite_end', 1, true))
    eq(true, not not output:find('ERROR', 1, true))
    eq(true, not not output:find('Global test environment teardown.', 1, true))
  end)
end)
