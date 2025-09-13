local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local NIL = vim.NIL
local feed = n.feed
local command = n.command
local clear = n.clear
local api = n.api
local eq = t.eq
local eval = n.eval
local exec = n.exec
local exec_lua = n.exec_lua
local fn = n.fn
local matches = t.matches
local mkdir_p = n.mkdir_p
local pcall_err = t.pcall_err
local rmdir = n.rmdir
local write_file = t.write_file

local function eq_exec_lua(expected, f)
  eq(expected, exec_lua(f))
end

describe('lua stdlib', function()
  before_each(clear)

  describe('variables', function()
    it('vim.g', function()
      exec_lua(function()
        vim.api.nvim_set_var('testing', 'hi')
        vim.api.nvim_set_var('other', 123)
        vim.api.nvim_set_var('floaty', 5120.1)
        vim.api.nvim_set_var('nullvar', vim.NIL)
        vim.api.nvim_set_var('to_delete', { hello = 'world' })
      end)

      eq('hi', fn.luaeval 'vim.g.testing')
      eq(123, fn.luaeval 'vim.g.other')
      eq(5120.1, fn.luaeval 'vim.g.floaty')
      eq(NIL, fn.luaeval 'vim.g.nonexistent')
      eq(NIL, fn.luaeval 'vim.g.nullvar')
      -- lost over RPC, so test locally:
      eq_exec_lua({ false, true }, function()
        return { vim.g.nonexistent == vim.NIL, vim.g.nullvar == vim.NIL }
      end)

      eq({ hello = 'world' }, fn.luaeval 'vim.g.to_delete')
      exec_lua [[
      vim.g.to_delete = nil
      ]]
      eq(NIL, fn.luaeval 'vim.g.to_delete')

      matches([[attempt to index .* nil value]], pcall_err(exec_lua, 'return vim.g[0].testing'))

      exec_lua(function()
        local counter = 0
        local function add_counter()
          counter = counter + 1
        end
        local function get_counter()
          return counter
        end
        vim.g.AddCounter = add_counter
        vim.g.GetCounter = get_counter
        vim.g.fn = { add = add_counter, get = get_counter }
        vim.g.AddParens = function(s)
          return '(' .. s .. ')'
        end
      end)

      eq(0, eval('g:GetCounter()'))
      eval('g:AddCounter()')
      eq(1, eval('g:GetCounter()'))
      eval('g:AddCounter()')
      eq(2, eval('g:GetCounter()'))
      exec_lua([[vim.g.AddCounter()]])
      eq(3, exec_lua([[return vim.g.GetCounter()]]))
      exec_lua([[vim.api.nvim_get_var('AddCounter')()]])
      eq(4, exec_lua([[return vim.api.nvim_get_var('GetCounter')()]]))
      exec_lua([[vim.g.fn.add()]])
      eq(5, exec_lua([[return vim.g.fn.get()]]))
      exec_lua([[vim.api.nvim_get_var('fn').add()]])
      eq(6, exec_lua([[return vim.api.nvim_get_var('fn').get()]]))
      eq('((foo))', eval([['foo'->AddParens()->AddParens()]]))

      exec_lua(function()
        local counter = 0
        local function add_counter()
          counter = counter + 1
        end
        local function get_counter()
          return counter
        end
        vim.api.nvim_set_var('AddCounter', add_counter)
        vim.api.nvim_set_var('GetCounter', get_counter)
        vim.api.nvim_set_var('fn', { add = add_counter, get = get_counter })
        vim.api.nvim_set_var('AddParens', function(s)
          return '(' .. s .. ')'
        end)
      end)

      eq(0, eval('g:GetCounter()'))
      eval('g:AddCounter()')
      eq(1, eval('g:GetCounter()'))
      eval('g:AddCounter()')
      eq(2, eval('g:GetCounter()'))
      exec_lua([[vim.g.AddCounter()]])
      eq(3, exec_lua([[return vim.g.GetCounter()]]))
      exec_lua([[vim.api.nvim_get_var('AddCounter')()]])
      eq(4, exec_lua([[return vim.api.nvim_get_var('GetCounter')()]]))
      exec_lua([[vim.g.fn.add()]])
      eq(5, exec_lua([[return vim.g.fn.get()]]))
      exec_lua([[vim.api.nvim_get_var('fn').add()]])
      eq(6, exec_lua([[return vim.api.nvim_get_var('fn').get()]]))
      eq('((foo))', eval([['foo'->AddParens()->AddParens()]]))

      exec([[
        function Test()
        endfunction
        function s:Test()
        endfunction
        let g:Unknown_func = function('Test')
        let g:Unknown_script_func = function('s:Test')
      ]])
      eq(NIL, exec_lua([[return vim.g.Unknown_func]]))
      eq(NIL, exec_lua([[return vim.g.Unknown_script_func]]))

      -- Check if autoload works properly
      local pathsep = n.get_pathsep()
      local xconfig = 'Xhome' .. pathsep .. 'Xconfig'
      local xdata = 'Xhome' .. pathsep .. 'Xdata'
      local autoload_folder = table.concat({ xconfig, 'nvim', 'autoload' }, pathsep)
      local autoload_file = table.concat({ autoload_folder, 'testload.vim' }, pathsep)
      mkdir_p(autoload_folder)
      write_file(autoload_file, [[let testload#value = 2]])

      clear { args_rm = { '-u' }, env = { XDG_CONFIG_HOME = xconfig, XDG_DATA_HOME = xdata } }

      eq(2, exec_lua("return vim.g['testload#value']"))
      rmdir('Xhome')
    end)

    it('vim.b', function()
      exec_lua(function()
        vim.api.nvim_buf_set_var(0, 'testing', 'hi')
        vim.api.nvim_buf_set_var(0, 'other', 123)
        vim.api.nvim_buf_set_var(0, 'floaty', 5120.1)
        vim.api.nvim_buf_set_var(0, 'nullvar', vim.NIL)
        vim.api.nvim_buf_set_var(0, 'to_delete', { hello = 'world' })
        _G.BUF = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_var(_G.BUF, 'testing', 'bye')
      end)

      eq('hi', fn.luaeval 'vim.b.testing')
      eq('bye', fn.luaeval 'vim.b[BUF].testing')
      eq(123, fn.luaeval 'vim.b.other')
      eq(5120.1, fn.luaeval 'vim.b.floaty')
      eq(NIL, fn.luaeval 'vim.b.nonexistent')
      eq(NIL, fn.luaeval 'vim.b[BUF].nonexistent')
      eq(NIL, fn.luaeval 'vim.b.nullvar')
      -- lost over RPC, so test locally:
      eq_exec_lua({ false, true }, function()
        return { vim.b.nonexistent == vim.NIL, vim.b.nullvar == vim.NIL }
      end)

      matches(
        [[attempt to index .* nil value]],
        pcall_err(exec_lua, 'return vim.b[BUF][0].testing')
      )

      eq({ hello = 'world' }, fn.luaeval 'vim.b.to_delete')
      exec_lua [[
      vim.b.to_delete = nil
      ]]
      eq(NIL, fn.luaeval 'vim.b.to_delete')

      exec_lua(function()
        local counter = 0
        local function add_counter()
          counter = counter + 1
        end
        local function get_counter()
          return counter
        end
        vim.b.AddCounter = add_counter
        vim.b.GetCounter = get_counter
        vim.b.fn = { add = add_counter, get = get_counter }
        vim.b.AddParens = function(s)
          return '(' .. s .. ')'
        end
      end)

      eq(0, eval('b:GetCounter()'))
      eval('b:AddCounter()')
      eq(1, eval('b:GetCounter()'))
      eval('b:AddCounter()')
      eq(2, eval('b:GetCounter()'))
      exec_lua([[vim.b.AddCounter()]])
      eq(3, exec_lua([[return vim.b.GetCounter()]]))
      exec_lua([[vim.api.nvim_buf_get_var(0, 'AddCounter')()]])
      eq(4, exec_lua([[return vim.api.nvim_buf_get_var(0, 'GetCounter')()]]))
      exec_lua([[vim.b.fn.add()]])
      eq(5, exec_lua([[return vim.b.fn.get()]]))
      exec_lua([[vim.api.nvim_buf_get_var(0, 'fn').add()]])
      eq(6, exec_lua([[return vim.api.nvim_buf_get_var(0, 'fn').get()]]))
      eq('((foo))', eval([['foo'->b:AddParens()->b:AddParens()]]))

      exec_lua(function()
        local counter = 0
        local function add_counter()
          counter = counter + 1
        end
        local function get_counter()
          return counter
        end
        vim.api.nvim_buf_set_var(0, 'AddCounter', add_counter)
        vim.api.nvim_buf_set_var(0, 'GetCounter', get_counter)
        vim.api.nvim_buf_set_var(0, 'fn', { add = add_counter, get = get_counter })
        vim.api.nvim_buf_set_var(0, 'AddParens', function(s)
          return '(' .. s .. ')'
        end)
      end)

      eq(0, eval('b:GetCounter()'))
      eval('b:AddCounter()')
      eq(1, eval('b:GetCounter()'))
      eval('b:AddCounter()')
      eq(2, eval('b:GetCounter()'))
      exec_lua([[vim.b.AddCounter()]])
      eq(3, exec_lua([[return vim.b.GetCounter()]]))
      exec_lua([[vim.api.nvim_buf_get_var(0, 'AddCounter')()]])
      eq(4, exec_lua([[return vim.api.nvim_buf_get_var(0, 'GetCounter')()]]))
      exec_lua([[vim.b.fn.add()]])
      eq(5, exec_lua([[return vim.b.fn.get()]]))
      exec_lua([[vim.api.nvim_buf_get_var(0, 'fn').add()]])
      eq(6, exec_lua([[return vim.api.nvim_buf_get_var(0, 'fn').get()]]))
      eq('((foo))', eval([['foo'->b:AddParens()->b:AddParens()]]))

      exec([[
        function Test()
        endfunction
        function s:Test()
        endfunction
        let b:Unknown_func = function('Test')
        let b:Unknown_script_func = function('s:Test')
      ]])
      eq(NIL, exec_lua([[return vim.b.Unknown_func]]))
      eq(NIL, exec_lua([[return vim.b.Unknown_script_func]]))

      exec_lua [[
      vim.cmd "vnew"
      ]]

      eq(NIL, fn.luaeval 'vim.b.testing')
      eq(NIL, fn.luaeval 'vim.b.other')
      eq(NIL, fn.luaeval 'vim.b.nonexistent')
    end)

    it('vim.w', function()
      exec_lua [[
      vim.api.nvim_win_set_var(0, "testing", "hi")
      vim.api.nvim_win_set_var(0, "other", 123)
      vim.api.nvim_win_set_var(0, "to_delete", {hello="world"})
      BUF = vim.api.nvim_create_buf(false, true)
      WIN = vim.api.nvim_open_win(BUF, false, {
        width=10, height=10,
        relative='win', row=0, col=0
      })
      vim.api.nvim_win_set_var(WIN, "testing", "bye")
      ]]

      eq('hi', fn.luaeval 'vim.w.testing')
      eq('bye', fn.luaeval 'vim.w[WIN].testing')
      eq(123, fn.luaeval 'vim.w.other')
      eq(NIL, fn.luaeval 'vim.w.nonexistent')
      eq(NIL, fn.luaeval 'vim.w[WIN].nonexistent')

      matches(
        [[attempt to index .* nil value]],
        pcall_err(exec_lua, 'return vim.w[WIN][0].testing')
      )

      eq({ hello = 'world' }, fn.luaeval 'vim.w.to_delete')
      exec_lua [[
      vim.w.to_delete = nil
      ]]
      eq(NIL, fn.luaeval 'vim.w.to_delete')

      exec_lua [[
        local counter = 0
        local function add_counter() counter = counter + 1 end
        local function get_counter() return counter end
        vim.w.AddCounter = add_counter
        vim.w.GetCounter = get_counter
        vim.w.fn = {add = add_counter, get = get_counter}
        vim.w.AddParens = function(s) return '(' .. s .. ')' end
      ]]

      eq(0, eval('w:GetCounter()'))
      eval('w:AddCounter()')
      eq(1, eval('w:GetCounter()'))
      eval('w:AddCounter()')
      eq(2, eval('w:GetCounter()'))
      exec_lua([[vim.w.AddCounter()]])
      eq(3, exec_lua([[return vim.w.GetCounter()]]))
      exec_lua([[vim.api.nvim_win_get_var(0, 'AddCounter')()]])
      eq(4, exec_lua([[return vim.api.nvim_win_get_var(0, 'GetCounter')()]]))
      exec_lua([[vim.w.fn.add()]])
      eq(5, exec_lua([[return vim.w.fn.get()]]))
      exec_lua([[vim.api.nvim_win_get_var(0, 'fn').add()]])
      eq(6, exec_lua([[return vim.api.nvim_win_get_var(0, 'fn').get()]]))
      eq('((foo))', eval([['foo'->w:AddParens()->w:AddParens()]]))

      exec_lua [[
        local counter = 0
        local function add_counter() counter = counter + 1 end
        local function get_counter() return counter end
        vim.api.nvim_win_set_var(0, 'AddCounter', add_counter)
        vim.api.nvim_win_set_var(0, 'GetCounter', get_counter)
        vim.api.nvim_win_set_var(0, 'fn', {add = add_counter, get = get_counter})
        vim.api.nvim_win_set_var(0, 'AddParens', function(s) return '(' .. s .. ')' end)
      ]]

      eq(0, eval('w:GetCounter()'))
      eval('w:AddCounter()')
      eq(1, eval('w:GetCounter()'))
      eval('w:AddCounter()')
      eq(2, eval('w:GetCounter()'))
      exec_lua([[vim.w.AddCounter()]])
      eq(3, exec_lua([[return vim.w.GetCounter()]]))
      exec_lua([[vim.api.nvim_win_get_var(0, 'AddCounter')()]])
      eq(4, exec_lua([[return vim.api.nvim_win_get_var(0, 'GetCounter')()]]))
      exec_lua([[vim.w.fn.add()]])
      eq(5, exec_lua([[return vim.w.fn.get()]]))
      exec_lua([[vim.api.nvim_win_get_var(0, 'fn').add()]])
      eq(6, exec_lua([[return vim.api.nvim_win_get_var(0, 'fn').get()]]))
      eq('((foo))', eval([['foo'->w:AddParens()->w:AddParens()]]))

      exec([[
        function Test()
        endfunction
        function s:Test()
        endfunction
        let w:Unknown_func = function('Test')
        let w:Unknown_script_func = function('s:Test')
      ]])
      eq(NIL, exec_lua([[return vim.w.Unknown_func]]))
      eq(NIL, exec_lua([[return vim.w.Unknown_script_func]]))

      exec_lua [[
      vim.cmd "vnew"
      ]]

      eq(NIL, fn.luaeval 'vim.w.testing')
      eq(NIL, fn.luaeval 'vim.w.other')
      eq(NIL, fn.luaeval 'vim.w.nonexistent')
    end)

    it('vim.t', function()
      exec_lua [[
      vim.api.nvim_tabpage_set_var(0, "testing", "hi")
      vim.api.nvim_tabpage_set_var(0, "other", 123)
      vim.api.nvim_tabpage_set_var(0, "to_delete", {hello="world"})
      ]]

      eq('hi', fn.luaeval 'vim.t.testing')
      eq(123, fn.luaeval 'vim.t.other')
      eq(NIL, fn.luaeval 'vim.t.nonexistent')
      eq('hi', fn.luaeval 'vim.t[0].testing')
      eq(123, fn.luaeval 'vim.t[0].other')
      eq(NIL, fn.luaeval 'vim.t[0].nonexistent')

      matches([[attempt to index .* nil value]], pcall_err(exec_lua, 'return vim.t[0][0].testing'))

      eq({ hello = 'world' }, fn.luaeval 'vim.t.to_delete')
      exec_lua [[
      vim.t.to_delete = nil
      ]]
      eq(NIL, fn.luaeval 'vim.t.to_delete')

      exec_lua [[
        local counter = 0
        local function add_counter() counter = counter + 1 end
        local function get_counter() return counter end
        vim.t.AddCounter = add_counter
        vim.t.GetCounter = get_counter
        vim.t.fn = {add = add_counter, get = get_counter}
        vim.t.AddParens = function(s) return '(' .. s .. ')' end
      ]]

      eq(0, eval('t:GetCounter()'))
      eval('t:AddCounter()')
      eq(1, eval('t:GetCounter()'))
      eval('t:AddCounter()')
      eq(2, eval('t:GetCounter()'))
      exec_lua([[vim.t.AddCounter()]])
      eq(3, exec_lua([[return vim.t.GetCounter()]]))
      exec_lua([[vim.api.nvim_tabpage_get_var(0, 'AddCounter')()]])
      eq(4, exec_lua([[return vim.api.nvim_tabpage_get_var(0, 'GetCounter')()]]))
      exec_lua([[vim.t.fn.add()]])
      eq(5, exec_lua([[return vim.t.fn.get()]]))
      exec_lua([[vim.api.nvim_tabpage_get_var(0, 'fn').add()]])
      eq(6, exec_lua([[return vim.api.nvim_tabpage_get_var(0, 'fn').get()]]))
      eq('((foo))', eval([['foo'->t:AddParens()->t:AddParens()]]))

      exec_lua [[
        local counter = 0
        local function add_counter() counter = counter + 1 end
        local function get_counter() return counter end
        vim.api.nvim_tabpage_set_var(0, 'AddCounter', add_counter)
        vim.api.nvim_tabpage_set_var(0, 'GetCounter', get_counter)
        vim.api.nvim_tabpage_set_var(0, 'fn', {add = add_counter, get = get_counter})
        vim.api.nvim_tabpage_set_var(0, 'AddParens', function(s) return '(' .. s .. ')' end)
      ]]

      eq(0, eval('t:GetCounter()'))
      eval('t:AddCounter()')
      eq(1, eval('t:GetCounter()'))
      eval('t:AddCounter()')
      eq(2, eval('t:GetCounter()'))
      exec_lua([[vim.t.AddCounter()]])
      eq(3, exec_lua([[return vim.t.GetCounter()]]))
      exec_lua([[vim.api.nvim_tabpage_get_var(0, 'AddCounter')()]])
      eq(4, exec_lua([[return vim.api.nvim_tabpage_get_var(0, 'GetCounter')()]]))
      exec_lua([[vim.t.fn.add()]])
      eq(5, exec_lua([[return vim.t.fn.get()]]))
      exec_lua([[vim.api.nvim_tabpage_get_var(0, 'fn').add()]])
      eq(6, exec_lua([[return vim.api.nvim_tabpage_get_var(0, 'fn').get()]]))
      eq('((foo))', eval([['foo'->t:AddParens()->t:AddParens()]]))

      exec_lua [[
      vim.cmd "tabnew"
      ]]

      eq(NIL, fn.luaeval 'vim.t.testing')
      eq(NIL, fn.luaeval 'vim.t.other')
      eq(NIL, fn.luaeval 'vim.t.nonexistent')
    end)

    it('vim.env', function()
      exec_lua([[vim.fn.setenv('A', 123)]])
      eq('123', fn.luaeval('vim.env.A'))
      exec_lua([[vim.env.A = 456]])
      eq('456', fn.luaeval('vim.env.A'))
      exec_lua([[vim.env.A = nil]])
      eq(NIL, fn.luaeval('vim.env.A'))

      eq(true, fn.luaeval('vim.env.B == nil'))

      command([[let $HOME = 'foo']])
      eq('foo', fn.expand('~'))
      eq('foo', fn.luaeval('vim.env.HOME'))
      exec_lua([[vim.env.HOME = nil]])
      eq('foo', fn.expand('~'))
      exec_lua([[vim.env.HOME = 'bar']])
      eq('bar', fn.expand('~'))
      eq('bar', fn.luaeval('vim.env.HOME'))
    end)

    it('vim.v', function()
      eq(fn.luaeval "vim.api.nvim_get_vvar('progpath')", fn.luaeval 'vim.v.progpath')
      eq(false, fn.luaeval "vim.v['false']")
      eq(NIL, fn.luaeval 'vim.v.null')
      matches([[attempt to index .* nil value]], pcall_err(exec_lua, 'return vim.v[0].progpath'))
      eq('Key is read-only: count', pcall_err(exec_lua, [[vim.v.count = 42]]))
      eq('Dict is locked', pcall_err(exec_lua, [[vim.v.nosuchvar = 42]]))
      eq('Key is fixed: errmsg', pcall_err(exec_lua, [[vim.v.errmsg = nil]]))
      exec_lua([[vim.v.errmsg = 'set by Lua']])
      eq('set by Lua', eval('v:errmsg'))
      exec_lua([[vim.v.errmsg = 42]])
      eq('42', eval('v:errmsg'))
      exec_lua([[vim.v.oldfiles = { 'one', 'two' }]])
      eq({ 'one', 'two' }, eval('v:oldfiles'))
      exec_lua([[vim.v.oldfiles = {}]])
      eq({}, eval('v:oldfiles'))
      eq(
        'Setting v:oldfiles to value with wrong type',
        pcall_err(exec_lua, [[vim.v.oldfiles = 'a']])
      )
      eq({}, eval('v:oldfiles'))

      feed('i foo foo foo<Esc>0/foo<CR>')
      eq({ 1, 1 }, api.nvim_win_get_cursor(0))
      eq(1, eval('v:searchforward'))
      feed('n')
      eq({ 1, 5 }, api.nvim_win_get_cursor(0))
      exec_lua([[vim.v.searchforward = 0]])
      eq(0, eval('v:searchforward'))
      feed('n')
      eq({ 1, 1 }, api.nvim_win_get_cursor(0))
      exec_lua([[vim.v.searchforward = 1]])
      eq(1, eval('v:searchforward'))
      feed('n')
      eq({ 1, 5 }, api.nvim_win_get_cursor(0))

      local screen = Screen.new(60, 3)
      eq(1, eval('v:hlsearch'))
      screen:expect {
        grid = [[
         {10:foo} {10:^foo} {10:foo}                                                |
        {1:~                                                           }|
                                                                    |
      ]],
      }
      exec_lua([[vim.v.hlsearch = 0]])
      eq(0, eval('v:hlsearch'))
      screen:expect {
        grid = [[
         foo ^foo foo                                                |
        {1:~                                                           }|
                                                                    |
      ]],
      }
      exec_lua([[vim.v.hlsearch = 1]])
      eq(1, eval('v:hlsearch'))
      screen:expect {
        grid = [[
         {10:foo} {10:^foo} {10:foo}                                                |
        {1:~                                                           }|
                                                                    |
      ]],
      }
    end)
  end)

  describe('options', function()
    describe('vim.bo', function()
      it('can get and set options', function()
        eq('', fn.luaeval 'vim.bo.filetype')
        exec_lua(function()
          _G.BUF = vim.api.nvim_create_buf(false, true)
          vim.api.nvim_set_option_value('filetype', 'markdown', {})
          vim.api.nvim_set_option_value('modifiable', false, { buf = _G.BUF })
        end)
        eq(false, fn.luaeval 'vim.bo.modified')
        eq('markdown', fn.luaeval 'vim.bo.filetype')
        eq(false, fn.luaeval 'vim.bo[BUF].modifiable')
        exec_lua(function()
          vim.bo.filetype = ''
          vim.bo[_G.BUF].modifiable = true
        end)
        eq('', fn.luaeval 'vim.bo.filetype')
        eq(true, fn.luaeval 'vim.bo[BUF].modifiable')
      end)

      it('errors', function()
        matches("Unknown option 'nosuchopt'$", pcall_err(exec_lua, 'return vim.bo.nosuchopt'))
        matches('Expected Lua string$', pcall_err(exec_lua, 'return vim.bo[0][0].autoread'))
        matches('Invalid buffer id: %-1$', pcall_err(exec_lua, 'return vim.bo[-1].filetype'))
      end)
    end)

    describe('vim.wo', function()
      it('can get and set options', function()
        exec_lua(function()
          vim.api.nvim_set_option_value('cole', 2, {})
          vim.cmd 'split'
          vim.api.nvim_set_option_value('cole', 2, {})
        end)
        eq(2, fn.luaeval 'vim.wo.cole')
        exec_lua(function()
          vim.wo.conceallevel = 0
        end)
        eq(0, fn.luaeval 'vim.wo.cole')
        eq(0, fn.luaeval 'vim.wo[0].cole')
        eq(0, fn.luaeval 'vim.wo[1001].cole')
        matches("Unknown option 'notanopt'$", pcall_err(exec_lua, 'return vim.wo.notanopt'))
        matches('Invalid window id: %-1$', pcall_err(exec_lua, 'return vim.wo[-1].list'))
        eq(2, fn.luaeval 'vim.wo[1000].cole')
        exec_lua(function()
          vim.wo[1000].cole = 0
        end)
        eq(0, fn.luaeval 'vim.wo[1000].cole')

        -- Can handle global-local values
        exec_lua [[vim.o.scrolloff = 100]]
        exec_lua [[vim.wo.scrolloff = 200]]
        eq(200, fn.luaeval 'vim.wo.scrolloff')
        exec_lua [[vim.wo.scrolloff = -1]]
        eq(100, fn.luaeval 'vim.wo.scrolloff')
        exec_lua(function()
          vim.wo[0][0].scrolloff = 200
          vim.cmd 'enew'
        end)
        eq(100, fn.luaeval 'vim.wo.scrolloff')
      end)

      it('errors', function()
        matches('only bufnr=0 is supported', pcall_err(exec_lua, 'vim.wo[0][10].signcolumn = "no"'))
        matches(
          'only bufnr=0 is supported',
          pcall_err(exec_lua, 'local a = vim.wo[0][10].signcolumn')
        )
      end)
    end)

    describe('vim.opt', function()
      -- TODO: We still need to write some tests for optlocal, opt and then getting the options
      --  Probably could also do some stuff with getting things from viml side as well to confirm behavior is the same.

      it('allows setting number values', function()
        local scrolloff = exec_lua [[
          vim.opt.scrolloff = 10
          return vim.o.scrolloff
        ]]
        eq(10, scrolloff)
      end)

      pending('handles STUPID window things', function()
        eq_exec_lua({}, function()
          return {
            vim.api.nvim_get_option_value('scrolloff', { scope = 'global' }),
            vim.api.nvim_get_option_value('scrolloff', { win = 0 }),
          }
        end)
      end)

      it('allows setting tables', function()
        eq_exec_lua('hello,world', function()
          vim.opt.wildignore = { 'hello', 'world' }
          return vim.o.wildignore
        end)
      end)

      it('allows setting tables with shortnames', function()
        eq_exec_lua('hello,world', function()
          vim.opt.wig = { 'hello', 'world' }
          return vim.o.wildignore
        end)
      end)

      it('errors when you attempt to set string values to numeric options', function()
        eq_exec_lua(false, function()
          return ({
            pcall(function()
              vim.opt.textwidth = 'hello world'
            end),
          })[1]
        end)
      end)

      it('errors when you attempt to setlocal a global value', function()
        eq_exec_lua(false, function()
          return pcall(function()
            vim.opt_local.clipboard = 'hello'
          end)
        end)
      end)

      it('allows you to set boolean values', function()
        eq_exec_lua({ true, false, true }, function()
          local results = {}

          vim.opt.autoindent = true
          table.insert(results, vim.bo.autoindent)

          vim.opt.autoindent = false
          table.insert(results, vim.bo.autoindent)

          vim.opt.autoindent = not vim.opt.autoindent:get()
          table.insert(results, vim.bo.autoindent)

          return results
        end)
      end)

      it('changes current buffer values and defaults for global local values', function()
        local result = exec_lua(function()
          local result = {}

          vim.opt.makeprg = 'global-local'
          table.insert(result, vim.go.makeprg)
          table.insert(result, vim.api.nvim_get_option_value('makeprg', { buf = 0 }))

          vim.opt_local.mp = 'only-local'
          table.insert(result, vim.go.makeprg)
          table.insert(result, vim.api.nvim_get_option_value('makeprg', { buf = 0 }))

          vim.opt_global.makeprg = 'only-global'
          table.insert(result, vim.go.makeprg)
          table.insert(result, vim.api.nvim_get_option_value('makeprg', { buf = 0 }))

          vim.opt.makeprg = 'global-local'
          table.insert(result, vim.go.makeprg)
          table.insert(result, vim.api.nvim_get_option_value('makeprg', { buf = 0 }))
          return result
        end)

        -- Set -> global & local
        eq('global-local', result[1])
        eq('', result[2])

        -- Setlocal -> only local
        eq('global-local', result[3])
        eq('only-local', result[4])

        -- Setglobal -> only global
        eq('only-global', result[5])
        eq('only-local', result[6])

        -- Set -> sets global value and resets local value
        eq('global-local', result[7])
        eq('', result[8])
      end)

      it('allows you to retrieve window opts even if they have not been set', function()
        eq_exec_lua({ false, false, true, true }, function()
          local result = {}
          table.insert(result, vim.opt.number:get())
          table.insert(result, vim.opt_local.number:get())

          vim.opt_local.number = true
          table.insert(result, vim.opt.number:get())
          table.insert(result, vim.opt_local.number:get())

          return result
        end)
      end)

      it('allows all sorts of string manipulation', function()
        eq_exec_lua({ 'hello', 'hello world', 'start hello world' }, function()
          local results = {}

          vim.opt.makeprg = 'hello'
          table.insert(results, vim.o.makeprg)

          vim.opt.makeprg = vim.opt.makeprg + ' world'
          table.insert(results, vim.o.makeprg)

          vim.opt.makeprg = vim.opt.makeprg ^ 'start '
          table.insert(results, vim.o.makeprg)

          return results
        end)
      end)

      describe('option:get()', function()
        it('works for boolean values', function()
          eq_exec_lua(false, function()
            vim.opt.number = false
            return vim.opt.number:get()
          end)
        end)

        it('works for number values', function()
          eq_exec_lua(10, function()
            vim.opt.tabstop = 10
            return vim.opt.tabstop:get()
          end)
        end)

        it('works for string values', function()
          eq_exec_lua('hello world', function()
            vim.opt.makeprg = 'hello world'
            return vim.opt.makeprg:get()
          end)
        end)

        it('works for set type flaglists', function()
          local formatoptions = exec_lua(function()
            vim.opt.formatoptions = 'tcro'
            return vim.opt.formatoptions:get()
          end)

          eq(true, formatoptions.t)
          eq(true, not formatoptions.q)
        end)

        it('works for set type flaglists', function()
          local formatoptions = exec_lua(function()
            vim.opt.formatoptions = { t = true, c = true, r = true, o = true }
            return vim.opt.formatoptions:get()
          end)

          eq(true, formatoptions.t)
          eq(true, not formatoptions.q)
        end)

        it('works for array list type options', function()
          local wildignore = exec_lua(function()
            vim.opt.wildignore = '*.c,*.o,__pycache__'
            return vim.opt.wildignore:get()
          end)

          eq(3, #wildignore)
          eq('*.c', wildignore[1])
        end)

        it('works for options that are both commalist and flaglist', function()
          eq_exec_lua({ b = true, s = true }, function()
            vim.opt.whichwrap = 'b,s'
            return vim.opt.whichwrap:get()
          end)

          eq_exec_lua({ b = true, h = true }, function()
            vim.opt.whichwrap = { b = true, s = false, h = true }
            return vim.opt.whichwrap:get()
          end)
        end)

        it('works for key-value pair options', function()
          eq_exec_lua({ tab = '> ', space = '_' }, function()
            vim.opt.listchars = 'tab:> ,space:_'
            return vim.opt.listchars:get()
          end)
        end)

        it('allows you to add numeric options', function()
          eq_exec_lua(16, function()
            vim.opt.tabstop = 12
            vim.opt.tabstop = vim.opt.tabstop + 4
            return vim.bo.tabstop
          end)
        end)

        it('allows you to subtract numeric options', function()
          eq_exec_lua(2, function()
            vim.opt.tabstop = 4
            vim.opt.tabstop = vim.opt.tabstop - 2
            return vim.bo.tabstop
          end)
        end)
      end)

      describe('key:value style options', function()
        it('handles dict style', function()
          eq_exec_lua('eol:~,space:.', function()
            vim.opt.listchars = { eol = '~', space = '.' }
            return vim.o.listchars
          end)
        end)

        it('allows adding dict style', function()
          eq_exec_lua('eol:~,space:-', function()
            vim.opt.listchars = { eol = '~', space = '.' }
            vim.opt.listchars = vim.opt.listchars + { space = '-' }
            return vim.o.listchars
          end)
        end)

        it('allows adding dict style', function()
          eq_exec_lua('eol:~,space:_', function()
            vim.opt.listchars = { eol = '~', space = '.' }
            vim.opt.listchars = vim.opt.listchars + { space = '-' } + { space = '_' }
            return vim.o.listchars
          end)
        end)

        it('allows completely new keys', function()
          eq_exec_lua('eol:~,space:.,tab:>>>', function()
            vim.opt.listchars = { eol = '~', space = '.' }
            vim.opt.listchars = vim.opt.listchars + { tab = '>>>' }
            return vim.o.listchars
          end)
        end)

        it('allows subtracting dict style', function()
          eq_exec_lua('eol:~', function()
            vim.opt.listchars = { eol = '~', space = '.' }
            vim.opt.listchars = vim.opt.listchars - 'space'
            return vim.o.listchars
          end)
        end)

        it('allows subtracting dict style', function()
          eq_exec_lua('', function()
            vim.opt.listchars = { eol = '~', space = '.' }
            vim.opt.listchars = vim.opt.listchars - 'space' - 'eol'
            return vim.o.listchars
          end)
        end)

        it('allows subtracting dict style multiple times', function()
          eq_exec_lua('eol:~', function()
            vim.opt.listchars = { eol = '~', space = '.' }
            vim.opt.listchars = vim.opt.listchars - 'space' - 'space'
            return vim.o.listchars
          end)
        end)

        it('allows adding a key:value string to a listchars', function()
          eq_exec_lua('eol:~,space:.,tab:>~', function()
            vim.opt.listchars = { eol = '~', space = '.' }
            vim.opt.listchars = vim.opt.listchars + 'tab:>~'
            return vim.o.listchars
          end)
        end)

        it('allows prepending a key:value string to a listchars', function()
          eq_exec_lua('eol:~,space:.,tab:>~', function()
            vim.opt.listchars = { eol = '~', space = '.' }
            vim.opt.listchars = vim.opt.listchars ^ 'tab:>~'
            return vim.o.listchars
          end)
        end)
      end)

      it('automatically sets when calling remove', function()
        eq_exec_lua('foo,baz', function()
          vim.opt.wildignore = 'foo,bar,baz'
          vim.opt.wildignore:remove('bar')
          return vim.o.wildignore
        end)
      end)

      it('automatically sets when calling remove with a table', function()
        eq_exec_lua('foo', function()
          vim.opt.wildignore = 'foo,bar,baz'
          vim.opt.wildignore:remove { 'bar', 'baz' }
          return vim.o.wildignore
        end)
      end)

      it('automatically sets when calling append', function()
        eq_exec_lua('foo,bar,baz,bing', function()
          vim.opt.wildignore = 'foo,bar,baz'
          vim.opt.wildignore:append('bing')
          return vim.o.wildignore
        end)
      end)

      it('automatically sets when calling append with a table', function()
        eq_exec_lua('foo,bar,baz,bing,zap', function()
          vim.opt.wildignore = 'foo,bar,baz'
          vim.opt.wildignore:append { 'bing', 'zap' }
          return vim.o.wildignore
        end)
      end)

      it('allows adding tables', function()
        eq_exec_lua('foo', function()
          vim.opt.wildignore = 'foo'
          return vim.o.wildignore
        end)

        eq_exec_lua('foo,bar,baz', function()
          vim.opt.wildignore = vim.opt.wildignore + { 'bar', 'baz' }
          return vim.o.wildignore
        end)
      end)

      it('handles adding duplicates', function()
        eq_exec_lua('foo', function()
          vim.opt.wildignore = 'foo'
          return vim.o.wildignore
        end)

        eq_exec_lua('foo,bar,baz', function()
          vim.opt.wildignore = vim.opt.wildignore + { 'bar', 'baz' }
          return vim.o.wildignore
        end)

        eq_exec_lua('foo,bar,baz', function()
          vim.opt.wildignore = vim.opt.wildignore + { 'bar', 'baz' }
          return vim.o.wildignore
        end)
      end)

      it('allows adding multiple times', function()
        eq_exec_lua('foo,bar,baz', function()
          vim.opt.wildignore = 'foo'
          vim.opt.wildignore = vim.opt.wildignore + 'bar' + 'baz'
          return vim.o.wildignore
        end)
      end)

      it('removes values when you use minus', function()
        eq_exec_lua('foo', function()
          vim.opt.wildignore = 'foo'
          return vim.o.wildignore
        end)

        eq_exec_lua('foo,bar,baz', function()
          vim.opt.wildignore = vim.opt.wildignore + { 'bar', 'baz' }
          return vim.o.wildignore
        end)

        eq_exec_lua('foo,baz', function()
          vim.opt.wildignore = vim.opt.wildignore - 'bar'
          return vim.o.wildignore
        end)
      end)

      it('prepends values when using ^', function()
        eq_exec_lua('first,foo', function()
          vim.opt.wildignore = 'foo'
          vim.opt.wildignore = vim.opt.wildignore ^ 'first'
          return vim.o.wildignore
        end)

        eq_exec_lua('super_first,first,foo', function()
          vim.opt.wildignore = vim.opt.wildignore ^ 'super_first'
          return vim.o.wildignore
        end)
      end)

      it('does not remove duplicates from wildmode: #14708', function()
        eq_exec_lua('full,list,full', function()
          vim.opt.wildmode = { 'full', 'list', 'full' }
          return vim.o.wildmode
        end)
      end)

      describe('option types', function()
        it('allows to set option with numeric value', function()
          eq_exec_lua(4, function()
            vim.opt.tabstop = 4
            return vim.bo.tabstop
          end)

          matches(
            "Invalid option type 'string' for 'tabstop'",
            pcall_err(exec_lua, [[vim.opt.tabstop = '4']])
          )
          matches(
            "Invalid option type 'boolean' for 'tabstop'",
            pcall_err(exec_lua, [[vim.opt.tabstop = true]])
          )
          matches(
            "Invalid option type 'table' for 'tabstop'",
            pcall_err(exec_lua, [[vim.opt.tabstop = {4, 2}]])
          )
          matches(
            "Invalid option type 'function' for 'tabstop'",
            pcall_err(exec_lua, [[vim.opt.tabstop = function() return 4 end]])
          )
        end)

        it('allows to set option with boolean value', function()
          eq_exec_lua(true, function()
            vim.opt.undofile = true
            return vim.bo.undofile
          end)

          matches(
            "Invalid option type 'number' for 'undofile'",
            pcall_err(exec_lua, [[vim.opt.undofile = 0]])
          )
          matches(
            "Invalid option type 'table' for 'undofile'",
            pcall_err(exec_lua, [[vim.opt.undofile = {true}]])
          )
          matches(
            "Invalid option type 'string' for 'undofile'",
            pcall_err(exec_lua, [[vim.opt.undofile = 'true']])
          )
          matches(
            "Invalid option type 'function' for 'undofile'",
            pcall_err(exec_lua, [[vim.opt.undofile = function() return true end]])
          )
        end)

        it('allows to set option with array or string value', function()
          eq_exec_lua('indent,eol,start', function()
            vim.opt.backspace = { 'indent', 'eol', 'start' }
            return vim.go.backspace
          end)

          eq_exec_lua('indent,eol,start', function()
            vim.opt.backspace = 'indent,eol,start'
            return vim.go.backspace
          end)

          matches(
            "Invalid option type 'boolean' for 'backspace'",
            pcall_err(exec_lua, [[vim.opt.backspace = true]])
          )
          matches(
            "Invalid option type 'number' for 'backspace'",
            pcall_err(exec_lua, [[vim.opt.backspace = 2]])
          )
          matches(
            "Invalid option type 'function' for 'backspace'",
            pcall_err(exec_lua, [[vim.opt.backspace = function() return 'indent,eol,start' end]])
          )
        end)

        it('allows set option with map or string value', function()
          eq_exec_lua('eol:~,space:.', function()
            vim.opt.listchars = { eol = '~', space = '.' }
            return vim.o.listchars
          end)

          eq_exec_lua('eol:~,space:.,tab:>~', function()
            vim.opt.listchars = 'eol:~,space:.,tab:>~'
            return vim.o.listchars
          end)

          matches(
            "Invalid option type 'boolean' for 'listchars'",
            pcall_err(exec_lua, [[vim.opt.listchars = true]])
          )
          matches(
            "Invalid option type 'number' for 'listchars'",
            pcall_err(exec_lua, [[vim.opt.listchars = 2]])
          )
          matches(
            "Invalid option type 'function' for 'listchars'",
            pcall_err(
              exec_lua,
              [[vim.opt.listchars = function() return "eol:~,space:.,tab:>~" end]]
            )
          )
        end)

        it('allows set option with set or string value', function()
          eq_exec_lua('b,s', function()
            vim.opt.whichwrap = { b = true, s = 1 }
            return vim.go.whichwrap
          end)

          eq_exec_lua('b,s,<,>,[,]', function()
            vim.opt.whichwrap = 'b,s,<,>,[,]'
            return vim.go.whichwrap
          end)

          matches(
            "Invalid option type 'boolean' for 'whichwrap'",
            pcall_err(exec_lua, [[vim.opt.whichwrap = true]])
          )
          matches(
            "Invalid option type 'number' for 'whichwrap'",
            pcall_err(exec_lua, [[vim.opt.whichwrap = 2]])
          )
          matches(
            "Invalid option type 'function' for 'whichwrap'",
            pcall_err(exec_lua, [[vim.opt.whichwrap = function() return "b,s,<,>,[,]" end]])
          )
        end)
      end)

      -- isfname=a,b,c,,,d,e,f
      it('can handle isfname ,,,', function()
        eq_exec_lua({ { ',', 'a', 'b', 'c' }, 'a,b,,,c' }, function()
          vim.opt.isfname = 'a,b,,,c'
          return { vim.opt.isfname:get(), vim.go.isfname }
        end)
      end)

      -- isfname=a,b,c,^,,def
      it('can handle isfname ,^,,', function()
        eq_exec_lua({ { '^,', 'a', 'b', 'c' }, 'a,b,^,,c' }, function()
          vim.opt.isfname = 'a,b,^,,c'
          return { vim.opt.isfname:get(), vim.go.isfname }
        end)
      end)

      describe('https://github.com/neovim/neovim/issues/14828', function()
        it('gives empty list when item is empty:array', function()
          eq_exec_lua({}, function()
            vim.cmd('set wildignore=')
            return vim.opt.wildignore:get()
          end)

          eq_exec_lua({}, function()
            vim.opt.wildignore = {}
            return vim.opt.wildignore:get()
          end)
        end)

        it('gives empty list when item is empty:set', function()
          eq_exec_lua({}, function()
            vim.cmd('set formatoptions=')
            return vim.opt.formatoptions:get()
          end)

          eq_exec_lua({}, function()
            vim.opt.formatoptions = {}
            return vim.opt.formatoptions:get()
          end)
        end)

        it('does not append to empty item', function()
          eq_exec_lua({ '*.foo', '*.bar' }, function()
            vim.opt.wildignore = {}
            vim.opt.wildignore:append { '*.foo', '*.bar' }
            return vim.opt.wildignore:get()
          end)
        end)

        it('does not prepend to empty item', function()
          eq_exec_lua({ '*.foo', '*.bar' }, function()
            vim.opt.wildignore = {}
            vim.opt.wildignore:prepend { '*.foo', '*.bar' }
            return vim.opt.wildignore:get()
          end)
        end)

        it('append to empty set', function()
          eq_exec_lua({ t = true }, function()
            vim.opt.formatoptions = {}
            vim.opt.formatoptions:append('t')
            return vim.opt.formatoptions:get()
          end)
        end)

        it('prepend to empty set', function()
          eq_exec_lua({ t = true }, function()
            vim.opt.formatoptions = {}
            vim.opt.formatoptions:prepend('t')
            return vim.opt.formatoptions:get()
          end)
        end)
      end)
    end) -- vim.opt

    describe('vim.opt_local', function()
      it('appends into global value when changing local option value', function()
        eq_exec_lua('foo,bar,baz,qux', function()
          vim.opt.tags = 'foo,bar'
          vim.opt_local.tags:append('baz')
          vim.opt_local.tags:append('qux')
          return vim.bo.tags
        end)
      end)
    end)

    describe('vim.opt_global', function()
      it('gets current global option value', function()
        eq_exec_lua({ 'yes' }, function()
          vim.cmd 'setglobal signcolumn=yes'
          return { vim.opt_global.signcolumn:get() }
        end)
      end)
    end)
  end)
end)
