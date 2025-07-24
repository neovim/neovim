local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local t_pack = require('test.functional.pack.testutil')

local eq = t.eq
local exec_lua = n.exec_lua

local get_test_src = t_pack.get_test_src
local get_pack_dir = t_pack.get_pack_dir

describe('vim.pack', function()
  describe('add()', function()
    before_each(function()
      n.clear()
      t_pack.setup_plug_basic()
    end)

    after_each(function()
      t_pack.clean_repos()
    end)

    it('makes plugin available immediately', function()
      local plug_basic_src = get_test_src('plug_basic')
      local out = exec_lua(function()
        vim.pack.add({ { src = plug_basic_src, version = 'feat-branch' } })
        return require('plug_basic').get()
      end)

      eq('basic feat branch', out)
    end)

    pending('reports errors after loading', function()
      -- TODO
      -- Should handle (not let it terminate the function) and report errors from pack_add()
    end)

    pending('respects after/', function()
      -- TODO
      -- Should source 'after/plugin/' directory (even nested files) after
      -- all 'plugin/' files are sourced in all plugins from input.
      --
      -- Should add 'after/' directory (if present) to 'runtimepath'
    end)

    pending('normalizes each spec', function()
      -- TODO

      -- TODO: Should properly infer `name` from `src` (as its basename
      -- minus '.git' suffix) but allow '.git' suffix in explicit `name`
    end)

    pending('normalizes spec array', function()
      -- TODO
      -- Should silently ignore full duplicates (same `src`+`version`)
      -- and error on conflicts.
    end)

    pending('installs', function()
      -- TODO

      -- TODO: Should block code flow until all plugins are available on disk
      -- and `:packadd` all of them (even just now installed) as a result.
    end)
  end)

  describe('update()', function()
    pending('works', function()
      -- TODO

      -- TODO: Should work with both added and not added plugins
    end)

    pending('suggests newer tags if there are no updates', function()
      -- TODO

      -- TODO: Should not suggest tags that point to the current state.
      -- Even if there is one/several and located at start/middle/end.
    end)
  end)

  describe('get()', function()
    local plug_basic_spec =
      { name = 'plug_basic', src = get_test_src('plug_basic'), version = 'feat-branch' }
    local plug_dummy_spec =
      { name = 'plug_dummy', src = get_test_src('plug_dummy'), version = 'main' }

    -- TODO: It would be better to use `setup()` / `teardown()` for test plugins.
    -- The issue is that there is no tested Nvim session at that point.
    -- Modifying 'pack/testutil.lua' to work not in tested Nvim session also
    -- has issues (like `vim.system` is not recognized).

    before_each(function()
      n.clear()
      t_pack.setup_plug_basic()
      t_pack.setup_plug_dummy()

      -- Ensure tested plugins are installed
      exec_lua(function()
        vim.pack.add({ plug_dummy_spec, plug_basic_spec })
      end)
      n.clear()
    end)

    after_each(function()
      t_pack.clean_repos()
    end)

    it('returns list of available plugins', function()
      exec_lua(function()
        vim.pack.add({ plug_basic_spec })
      end)

      -- Should first return active plugins followed by non-active
      local expected = {
        { active = true, path = get_pack_dir('plug_basic'), spec = plug_basic_spec },
        { active = false, path = get_pack_dir('plug_dummy'), spec = plug_dummy_spec },
      }
      local actual = exec_lua(function()
        return vim.pack.get()
      end)
      eq(expected, actual)
    end)

    pending('works after `del()`', function()
      -- TODO: Should not include removed plugins and still return list

      -- TODO: Should return corrent list inside `PackChanged` "delete" event
    end)
  end)

  describe('del()', function()
    pending('works', function()
      -- TODO
    end)
  end)
end)
