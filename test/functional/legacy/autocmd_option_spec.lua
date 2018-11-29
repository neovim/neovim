local helpers = require('test.functional.helpers')(after_each)
local nvim = helpers.meths
local clear, eq, neq = helpers.clear, helpers.eq, helpers.neq
local curbuf, buf = helpers.curbuf, helpers.bufmeths
local curwin = helpers.curwin
local redir_exec = helpers.redir_exec
local source, command = helpers.source, helpers.command

local function declare_hook_function()
  source([[
    fu! AutoCommand(match, bufnr, winnr)
      let l:acc = {
      \   'option' : a:match,
      \   'oldval' : v:option_old,
      \   'newval' : v:option_new,
      \   'scope'  : v:option_type,
      \   'attr'   : {
      \     'bufnr' : a:bufnr,
      \     'winnr' : a:winnr,
      \   }
      \ }
      call add(g:ret, l:acc)
    endfu
  ]])
end

local function set_hook(pattern)
  command(
    'au OptionSet '
    .. pattern ..
    ' :call AutoCommand(expand("<amatch>"), bufnr("%"), winnr())'
  )
end

local function init_var()
  command('let g:ret = []')
end

local function get_result()
  local ret = nvim.get_var('ret')
  init_var()
  return ret
end

local function expected_table(option, oldval, newval, scope, attr)
  return {
    option = option,
    oldval = tostring(oldval),
    newval = tostring(newval),
    scope  = scope,
    attr   = attr,
  }
end

local function expected_combination(...)
  local args = {...}
  local ret = get_result()

  if not (#args == #ret) then
    local expecteds = {}
    for _, v in pairs(args) do
      table.insert(expecteds, expected_table(unpack(v)))
    end
    eq(expecteds, ret)
    return
  end

  for i, v in ipairs(args) do
    local attr = v[5]
    if not attr then
      -- remove attr entries
      ret[i].attr = nil
    else
      -- remove attr entries which are not required
      for k in pairs(ret[i].attr) do
        if not attr[k] then
          ret[i].attr[k] = nil
        end
      end
    end
    eq(expected_table(unpack(v)), ret[i])
  end
end

local function expected_empty()
  eq({}, get_result())
end

local function make_buffer()
  local old_buf = curbuf()
  command('botright new')
  local new_buf = curbuf()
  command('wincmd p') -- move previous window

  neq(old_buf, new_buf)
  eq(old_buf, curbuf())

  return new_buf
end

local function get_new_window_number()
  local old_win = curwin()
  command('botright new')
  local new_win = curwin()
  local new_winnr = redir_exec('echo winnr()')
  command('wincmd p') -- move previous window

  neq(old_win, new_win)
  eq(old_win, curwin())

  return new_winnr:gsub('\n', '')
end

describe('au OptionSet', function()
  describe('with any opton (*)', function()

    before_each(function()
      clear()
      declare_hook_function()
      init_var()
      set_hook('*')
    end)

    it('should be called in setting number option', function()
      command('set nu')
      expected_combination({'number', 0, 1, 'global'})

      command('setlocal nonu')
      expected_combination({'number', 1, 0, 'local'})

      command('setglobal nonu')
      expected_combination({'number', 1, 0, 'global'})
    end)

    it('should be called in setting autoindent option',function()
      command('setlocal ai')
      expected_combination({'autoindent', 0, 1, 'local'})

      command('setglobal ai')
      expected_combination({'autoindent', 0, 1, 'global'})

      command('set noai')
      expected_combination({'autoindent', 1, 0, 'global'})
    end)

    it('should be called in inverting global autoindent option',function()
      command('set ai!')
      expected_combination({'autoindent', 0, 1, 'global'})
    end)

    it('should be called in being unset local autoindent option',function()
      command('setlocal ai')
      expected_combination({'autoindent', 0, 1, 'local'})

      command('setlocal ai<')
      expected_combination({'autoindent', 1, 0, 'local'})
    end)

    it('should be called in setting global list and number option at the same time',function()
      command('set list nu')
      expected_combination(
        {'list', 0, 1, 'global'},
        {'number', 0, 1, 'global'}
      )
    end)

    it('should not print anything, use :noa', function()
      command('noa set nolist nonu')
      expected_empty()
    end)

    it('should be called in setting local acd', function()
      command('setlocal acd')
      expected_combination({'autochdir', 0, 1, 'local'})
    end)

    it('should be called in setting autoread', function()
      command('set noar')
      expected_combination({'autoread', 1, 0, 'global'})

      command('setlocal ar')
      expected_combination({'autoread', 0, 1, 'local'})
    end)

    it('should be called in inverting global autoread', function()
      command('setglobal invar')
      expected_combination({'autoread', 1, 0, 'global'})
    end)

    it('should be called in setting backspace option through :let', function()
      command('let &bs=""')
      expected_combination({'backspace', 'indent,eol,start', '', 'global'})
    end)

    describe('being set by setbufvar()', function()
      it('should not trigger because option name is invalid', function()
        command('silent! call setbufvar(1, "&l:bk", 1)')
        expected_empty()
      end)

      it('should trigger using correct option name', function()
        command('call setbufvar(1, "&backup", 1)')
        expected_combination({'backup', 0, 1, 'local'})
      end)

      it('should trigger if the current buffer is different from the targetted buffer', function()
        local new_buffer = make_buffer()
        local new_bufnr = buf.get_number(new_buffer)

        command('call setbufvar(' .. new_bufnr .. ', "&buftype", "nofile")')
        expected_combination({'buftype', '', 'nofile', 'local', {bufnr = new_bufnr}})
      end)
    end)
  end)

  describe('with specific option', function()

    before_each(function()
      clear()
      declare_hook_function()
      init_var()
    end)

    it('should be called iff setting readonly', function()
      set_hook('readonly')

      command('set nu')
      expected_empty()

      command('setlocal ro')
      expected_combination({'readonly', 0, 1, 'local'})

      command('setglobal ro')
      expected_combination({'readonly', 0, 1, 'global'})

      command('set noro')
      expected_combination({'readonly', 1, 0, 'global'})
    end)

    describe('being set by setbufvar()', function()
      it('should not trigger because option name does not match with backup', function()
        set_hook('backup')

        command('silent! call setbufvar(1, "&l:bk", 1)')
        expected_empty()
      end)

      it('should trigger, use correct option name backup', function()
        set_hook('backup')

        command('call setbufvar(1, "&backup", 1)')
        expected_combination({'backup', 0, 1, 'local'})
      end)

      it('should trigger if the current buffer is different from the targetted buffer', function()
        set_hook('buftype')

        local new_buffer = make_buffer()
        local new_bufnr = buf.get_number(new_buffer)

        command('call setbufvar(' .. new_bufnr .. ', "&buftype", "nofile")')
        expected_combination({'buftype', '', 'nofile', 'local', {bufnr = new_bufnr}})
      end)
    end)

    describe('being set by setwinvar()', function()
      it('should not trigger because option name does not match with backup', function()
        set_hook('backup')

        command('silent! call setwinvar(1, "&l:bk", 1)')
        expected_empty()
      end)

      it('should trigger, use correct option name backup', function()
        set_hook('backup')

        command('call setwinvar(1, "&backup", 1)')
        expected_combination({'backup', 0, 1, 'local'})
      end)

      it('should not trigger if the current window is different from the targetted window', function()
        set_hook('cursorcolumn')

        local new_winnr = get_new_window_number()

        command('call setwinvar(' .. new_winnr .. ', "&cursorcolumn", 1)')
        -- expected_combination({'cursorcolumn', 0, 1, 'local', {winnr = new_winnr}})
        expected_empty()
      end)
    end)

    describe('being set by neovim api', function()
      it('should trigger if a boolean option be set globally', function()
        set_hook('autochdir')

        nvim.set_option('autochdir', true)
        eq(true, nvim.get_option('autochdir'))
        expected_combination({'autochdir', '0', '1', 'global'})
      end)

      it('should trigger if a number option be set globally', function()
        set_hook('cmdheight')

        nvim.set_option('cmdheight', 5)
        eq(5, nvim.get_option('cmdheight'))
        expected_combination({'cmdheight', 1, 5, 'global'})
      end)

      it('should trigger if a string option be set globally', function()
        set_hook('ambiwidth')

        nvim.set_option('ambiwidth', 'double')
        eq('double', nvim.get_option('ambiwidth'))
        expected_combination({'ambiwidth', 'single', 'double', 'global'})
      end)
    end)
  end)
end)
