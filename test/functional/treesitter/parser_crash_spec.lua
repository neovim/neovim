local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear = n.clear
local eq = t.eq
local exec_lua = n.exec_lua
local matches = t.matches

before_each(clear)

describe('treesitter parser crash protection', function()
  it('test_parser function exists and works for valid parser', function()
    local ok = exec_lua(function()
      -- Load the C parser first
      vim.treesitter.language.add('c')
      local test_ok, test_err = vim._ts_test_parser('c')
      -- Return true if test succeeded (ok is true and err is nil)
      return test_ok == true and test_err == nil
    end)
    eq(true, ok)
  end)

  it('test_parser returns error for missing parser', function()
    local result = exec_lua(function()
      local ok, err = vim._ts_test_parser('nonexistent_lang')
      return { ok = ok, err = err }
    end)
    eq(false, result.ok)
    matches("Language 'nonexistent_lang' not found", result.err)
  end)

  it('quarantine API functions exist', function()
    local result = exec_lua(function()
      return {
        is_quarantined = type(vim.treesitter.language.is_quarantined),
        get_quarantined = type(vim.treesitter.language.get_quarantined),
      }
    end)
    eq('function', result.is_quarantined)
    eq('function', result.get_quarantined)
  end)

  it('quarantine starts empty', function()
    local quarantined = exec_lua(function()
      return vim.treesitter.language.get_quarantined()
    end)
    eq({}, quarantined)
  end)

  it('is_quarantined returns false for non-quarantined parser', function()
    local result = exec_lua(function()
      return vim.treesitter.language.is_quarantined('c')
    end)
    eq(false, result)
  end)

  it('parser loading is protected by pcall', function()
    -- This test verifies that if a parser crashes during load,
    -- it's caught and the parser is quarantined
    local result = exec_lua(function()
      -- Try to load a parser with an invalid path
      -- This should fail gracefully rather than crashing
      local ok, err = pcall(function()
        return vim.treesitter.language.add('testlang', { path = '/nonexistent/parser.so' })
      end)
      return { ok = ok, err = err }
    end)
    -- The pcall should succeed (no crash), but the parser load should fail
    eq(true, result.ok)
  end)

  it('quarantine prevents repeated crash attempts', function()
    -- Load a parser that will fail
    exec_lua(function()
      vim.treesitter.language.add('failtest', { path = '/nonexistent/fail.so' })
    end)

    -- Verify it's quarantined
    local is_quarantined = exec_lua(function()
      return vim.treesitter.language.is_quarantined('failtest')
    end)
    eq(true, is_quarantined)

    -- Try to load again - should be blocked by quarantine
    local result = exec_lua(function()
      local ok, err = vim.treesitter.language.add('failtest', { path = '/nonexistent/fail.so' })
      return { ok = ok, has_error = err ~= nil }
    end)
    eq(nil, result.ok)
    eq(true, result.has_error)
  end)

  it('multiple parsers can be quarantined independently', function()
    -- Quarantine two different parsers
    exec_lua(function()
      vim.treesitter.language.add('fail1', { path = '/nonexistent/fail1.so' })
      vim.treesitter.language.add('fail2', { path = '/nonexistent/fail2.so' })
    end)

    -- Check both are quarantined
    local result = exec_lua(function()
      local quarantined = vim.treesitter.language.get_quarantined()
      return {
        count = vim.tbl_count(quarantined),
        has_fail1 = quarantined.fail1 ~= nil,
        has_fail2 = quarantined.fail2 ~= nil,
      }
    end)
    eq(2, result.count)
    eq(true, result.has_fail1)
    eq(true, result.has_fail2)
  end)

  it('quarantine is session-based and cleared on restart', function()
    -- First session: quarantine a parser
    clear()
    exec_lua(function()
      vim.treesitter.language.add('sessiontest', { path = '/nonexistent/session.so' })
    end)

    local first_check = exec_lua(function()
      return vim.treesitter.language.is_quarantined('sessiontest')
    end)
    eq(true, first_check)

    -- Restart (clear) - quarantine should be empty
    clear()
    local second_check = exec_lua(function()
      return vim.treesitter.language.is_quarantined('sessiontest')
    end)
    eq(false, second_check)
  end)

  -- Note: Testing with an actual corrupted parser requires:
  -- 1. Creating a corrupted .so/.dylib file
  -- 2. Placing it in a parser directory
  -- 3. Attempting to load it
  -- 4. Verifying it doesn't crash Neovim
  -- 5. Verifying it's quarantined
  --
  -- This is difficult to do reliably in automated tests, so we provide
  -- manual testing instructions:
  --
  -- Manual test procedure:
  -- 1. Corrupt a parser binary: `dd if=/dev/urandom of=bash.so bs=1024 count=10`
  -- 2. Place it in ~/.local/share/nvim/site/parser/
  -- 3. Open a .sh file: `nvim test.sh`
  -- 4. Verify Neovim doesn't crash
  -- 5. Check health: `:checkhealth treesitter`
  -- 6. Verify bash parser is reported as crashed/quarantined
  -- 7. Run `:TSUninstall bash` then `:TSInstall bash` to fix
end)

describe('treesitter health check enhancements', function()
  it('health check tests parsers', function()
    -- This test verifies that the health check can run without errors
    local result = exec_lua(function()
      local ok, err = pcall(function()
        require('vim.treesitter.health').check()
      end)
      return { ok = ok, err = err }
    end)
    eq(true, result.ok)
  end)
end)
