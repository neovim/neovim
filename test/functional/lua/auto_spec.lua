local helpers = require('test.functional.helpers')(after_each)
local exec_lua = helpers.exec_lua
local meths = helpers.meths
local clear = helpers.clear
local eq = helpers.eq

before_each(clear)

describe('vim.autocmd', function()
  describe('vim.autocmd:get()', function()
    pending('behaves like nvim_get_autocmds')
  end)

  describe('vim.autocmd:clear()', function()
    pending('behaves like nvim_clear_autocmds')
  end)

  describe('vim.autocmd.buf', function()
    pending('manages buflocal autocommands')

    it('can create an autocommand for the current buffer', function()
      exec_lua [[ vim.autocmd.buf.InsertEnter(':echo "Coding!"') ]]
      eq(1, #meths.get_autocmds({ buffer = 0 }))
    end)

    it('can get all autocommands attached to the current buffer', function()
      meths.create_autocmd('InsertEnter', {
        buffer = 0,
        command = 'echo "Coding!"'
      })
      meths.create_autocmd('InsertLeave', {
        buffer = 0,
        command = 'echo "Done!"'
      })
      local aus = exec_lua [[ return vim.autocmd.buf:get() ]]
      eq(2, #aus)
    end)

    it('can clear all autocommands attached to the current buffer', function()
      meths.create_autocmd('InsertEnter', {
        buffer = 0,
        command = 'echo "Coding!"'
      })
      meths.create_autocmd('InsertLeave', {
        buffer = 0,
        command = 'echo "Done!"'
      })
      eq(2, #meths.get_autocmds({ buffer = 0 }))
      exec_lua [[ vim.autocmd.buf:clear() ]]
      eq(0, #meths.get_autocmds({ buffer = 0 }))
    end)

    pending('can be indexed with a bufnr')
  end)

  it('can create an autocommand', function()
    local id = exec_lua([[
      return vim.autocmd.UIEnter(':echo "Hello!"')
    ]])
    assert.number(id)
    local cmds = meths.get_autocmds({ event = 'UIEnter' })
    eq(1, #cmds)
    eq(id, cmds[1].id)
    eq('echo "Hello!"', cmds[1].command)
  end)

  it('can create an autocommand with options', function()
    local id = exec_lua([[
      return vim.autocmd.UIEnter(':echo "Hello!"', {
        desc = 'greeting',
        once = true,
      })
    ]])
    assert.number(id)
    local cmds = meths.get_autocmds({ event = 'UIEnter' })
    eq(id, cmds[1].id)
    eq('greeting', cmds[1].desc)
  end)

  it('can create an autocommand for multiple events', function()
    local id = exec_lua([[
      return vim.autocmd[{ 'UIEnter', 'VimEnter', 'WinEnter' }](':echo "Hello!"')
    ]])
    assert.number(id)
    eq(id, meths.get_autocmds({ event = 'UIEnter' })[1].id)
    eq(id, meths.get_autocmds({ event = 'VimEnter' })[1].id)
    eq(id, meths.get_autocmds({ event = 'WinEnter' })[1].id)
  end)

  it('can create an autocommand for an event and pattern', function()
    local id = exec_lua([[
      return vim.autocmd.User.CustomEvent(':echo "Hello!"')
    ]])
    assert.number(id)
    eq(id, meths.get_autocmds({ event = 'User', pattern = 'CustomEvent' })[1].id)
  end)

  it('can create an autocommand and specify multiple patterns', function()
    local id = exec_lua([[
      return vim.autocmd.Filetype[{ 'lua', 'vim', 'sh' }](':echo "Hello!"')
    ]])
    assert.number(id)
    eq(3, #meths.get_autocmds({ event = 'Filetype' }))
  end)

  it('can get autocommands for an event', function()
    meths.create_autocmd('UIEnter', {
      command = 'echo "Hello!"',
    })
    local cmds = exec_lua([[
      return vim.autocmd.UIEnter:get()
    ]])
    eq(1, #cmds)
  end)

  it('can get autocommands for an event and pattern', function()
    meths.create_autocmd('User', {
      pattern = 'foo',
      command = 'echo "Hello!"',
    })
    meths.create_autocmd('User', {
      pattern = 'bar',
      command = 'echo "Hello!"',
    })
    local cmds = exec_lua([[
      return vim.autocmd.User.foo:get()
    ]])
    eq(1, #cmds)
  end)

  it('can clear autocommands for an event', function()
    meths.create_autocmd('UIEnter', {
      command = 'echo "Hello!"',
    })
    exec_lua([[
      vim.autocmd.UIEnter:clear()
    ]])
    eq(0, #meths.get_autocmds({ event = 'UIEnter' }))
  end)

  it('can execute autocommands', function()
    meths.set_var("some_condition", false)

    exec_lua [[
      vim.api.nvim_create_autocmd("User", {
        pattern = "Test",
        desc = "A test autocommand",
        callback = function()
          return vim.g.some_condition
        end,
      })
    ]]

    exec_lua [[ vim.autocmd.User.Test:exec() ]]

    local aus = meths.get_autocmds({ event = 'User', pattern = 'Test' })
    local first = aus[1]
    eq(first.id, 1)

    meths.set_var("some_condition", true)
    exec_lua [[ vim.autocmd.User.Test:exec() ]]
    eq({}, meths.get_autocmds({event = "User", pattern = "Test"}))
  end)

end)

describe('vim.augroup', function()
  it('can delete an existing group', function()
    local id = meths.create_augroup('nvim_test_augroup', { clear = true })
    meths.create_autocmd('User', {
      group = id,
      pattern = "Test",
      desc = "A test autocommand",
      command = 'echo "Test!"',
    })
    local aus = meths.get_autocmds({ group = 'nvim_test_augroup' })
    eq(1, #aus)
    exec_lua [[ vim.augroup.nvim_test_augroup:del() ]]
    local success = exec_lua [[
      return pcall(vim.api.nvim_get_autocmds, { group = 'nvim_test_augroup' })
    ]]
    eq(false, success)
  end)

  describe('Augroup:create()', function()
    it('can create a group and return its id', function()
      local id = exec_lua [[ return vim.augroup.nvim_test_augroup:create() ]]
      meths.create_autocmd('User', {
        group = id,
        pattern = "Test",
        desc = "A test autocommand",
        command = 'echo "Test!"',
      })
      local aus = meths.get_autocmds({ group = id })
      eq(1, #aus)
    end)

    pending('can return the id of an existing group')
    pending('does not clear an existing group')
  end)

  describe('Augroup:clear()', function()
    pending('clears autocommands in the group')
    pending('can be called with a dictionary of autocommand options')
    pending('can create the group when called without arguments')
  end)

  describe('Augroup:get()', function()
    pending('can return a list of autocommands in the group')
    pending('can be called with a dictionary of autocommand options')
    pending('returns nil when called without arguments on a nonexistant group')
  end)

  describe('Augroup:__call()', function()
    it('can create a group and define its autocommands', function()
      exec_lua [[
        vim.augroup.nvim_test_augroup(function(au)
          au.UIEnter(":echo 'Hello!'")
          au.User.Test(":echo 'Test!'")
          au.InsertEnter['*'](":echo 'Test!'")
        end)
      ]]
      local aus = meths.get_autocmds({ group = 'nvim_test_augroup' })
      eq(3, #aus)
    end)

    pending('can add autocommands to an existing group')
    pending('returns the group id and any values returned from the function')
  end)
end)
