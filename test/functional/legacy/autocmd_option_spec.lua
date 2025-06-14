local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear, eq, neq, eval = n.clear, t.eq, t.neq, n.eval
local api = n.api
local curbuf = n.api.nvim_get_current_buf
local curwin = n.api.nvim_get_current_win
local exec_capture = n.exec_capture
local source, command = n.source, n.command

local function declare_hook_function()
  source([[
    fu! AutoCommand(match, bufnr, winnr)
      let l:acc = {
      \   'option'   : a:match,
      \   'oldval'   : v:option_old,
      \   'oldval_l' : v:option_oldlocal,
      \   'oldval_g' : v:option_oldglobal,
      \   'newval'   : v:option_new,
      \   'scope'    : v:option_type,
      \   'cmd'      : v:option_command,
      \   'attr'     : {
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
    'au OptionSet ' .. pattern .. ' :call AutoCommand(expand("<amatch>"), bufnr("%"), winnr())'
  )
end

local function init_var()
  command('let g:ret = []')
end

local function get_result()
  local ret = api.nvim_get_var('ret')
  init_var()
  return ret
end

local function expected_table(option, oldval, oldval_l, oldval_g, newval, scope, cmd, attr)
  return {
    option = option,
    oldval = oldval,
    oldval_l = oldval_l,
    oldval_g = oldval_g,
    newval = newval,
    scope = scope,
    cmd = cmd,
    attr = attr,
  }
end

local function expected_combination(...)
  local args = { ... }
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
    local attr = v[8]
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
  local new_winnr = exec_capture('echo winnr()')
  command('wincmd p') -- move previous window

  neq(old_win, new_win)
  eq(old_win, curwin())

  return new_winnr
end

describe('au OptionSet', function()
  describe('with any option (*)', function()
    before_each(function()
      clear()
      declare_hook_function()
      init_var()
      set_hook('*')
    end)

    it('should be called in setting number option', function()
      command('set nu')
      expected_combination({ 'number', false, false, false, true, 'global', 'set' })

      command('setlocal nonu')
      expected_combination({ 'number', true, true, '', false, 'local', 'setlocal' })

      command('setglobal nonu')
      expected_combination({ 'number', true, '', true, false, 'global', 'setglobal' })
    end)

    it('should be called in setting autoindent option', function()
      command('setlocal ai')
      expected_combination({ 'autoindent', false, false, '', true, 'local', 'setlocal' })

      command('setglobal ai')
      expected_combination({ 'autoindent', false, '', false, true, 'global', 'setglobal' })

      command('set noai')
      expected_combination({ 'autoindent', true, true, true, false, 'global', 'set' })
    end)

    it('should be called in inverting global autoindent option', function()
      command('set ai!')
      expected_combination({ 'autoindent', false, false, false, true, 'global', 'set' })
    end)

    it('should be called in being unset local autoindent option', function()
      command('setlocal ai')
      expected_combination({ 'autoindent', false, false, '', true, 'local', 'setlocal' })

      command('setlocal ai<')
      expected_combination({ 'autoindent', true, true, '', false, 'local', 'setlocal' })
    end)

    it('should be called in setting global list and number option at the same time', function()
      command('set list nu')
      expected_combination(
        { 'list', false, false, false, true, 'global', 'set' },
        { 'number', false, false, false, true, 'global', 'set' }
      )
    end)

    it('should not print anything, use :noa', function()
      command('noa set nolist nonu')
      expected_empty()
    end)

    it('should be called in setting local acd', function()
      command('setlocal acd')
      expected_combination({ 'autochdir', false, false, '', true, 'local', 'setlocal' })
    end)

    it('should be called in setting autoread', function()
      command('set noar')
      expected_combination({ 'autoread', true, true, true, false, 'global', 'set' })

      command('setlocal ar')
      expected_combination({ 'autoread', false, false, '', true, 'local', 'setlocal' })
    end)

    it('should be called in inverting global autoread', function()
      command('setglobal invar')
      expected_combination({ 'autoread', true, '', true, false, 'global', 'setglobal' })
    end)

    it('should be called in setting backspace option through :let', function()
      local oldval = eval('&backspace')

      command('let &bs=""')
      expected_combination({ 'backspace', oldval, oldval, oldval, '', 'global', 'set' })
    end)

    describe('being set by setbufvar()', function()
      it('should not trigger because option name is invalid', function()
        command('silent! call setbufvar(1, "&l:bk", 1)')
        expected_empty()
      end)

      it('should trigger using correct option name', function()
        command('call setbufvar(1, "&backup", 1)')
        expected_combination({ 'backup', false, false, '', true, 'local', 'setlocal' })
      end)

      it('should trigger if the current buffer is different from the targeted buffer', function()
        local new_buffer = make_buffer()
        local new_bufnr = api.nvim_buf_get_number(new_buffer)

        command('call setbufvar(' .. new_bufnr .. ', "&buftype", "nofile")')
        expected_combination({
          'buftype',
          '',
          '',
          '',
          'nofile',
          'local',
          'setlocal',
          { bufnr = new_bufnr },
        })
      end)
    end)

    it('with string global option', function()
      local oldval = eval('&backupext')

      command('set backupext=foo')
      expected_combination({ 'backupext', oldval, oldval, oldval, 'foo', 'global', 'set' })

      command('set backupext&')
      expected_combination({ 'backupext', 'foo', 'foo', 'foo', oldval, 'global', 'set' })

      command('setglobal backupext=bar')
      expected_combination({ 'backupext', oldval, '', oldval, 'bar', 'global', 'setglobal' })

      command('noa set backupext&')
      -- As this is a global option this sets the global value even though :setlocal is used!
      command('setlocal backupext=baz')
      expected_combination({ 'backupext', oldval, oldval, '', 'baz', 'local', 'setlocal' })

      command('noa setglobal backupext=ext_global')
      command('noa setlocal backupext=ext_local') -- Sets the global(!) value
      command('set backupext=foo')
      expected_combination({
        'backupext',
        'ext_local',
        'ext_local',
        'ext_local',
        'foo',
        'global',
        'set',
      })
    end)

    it('with string global-local (to buffer) option', function()
      local oldval = eval('&tags')

      command('set tags=tagpath')
      expected_combination({ 'tags', oldval, oldval, oldval, 'tagpath', 'global', 'set' })

      command('set tags&')
      expected_combination({ 'tags', 'tagpath', 'tagpath', 'tagpath', oldval, 'global', 'set' })

      command('setglobal tags=tagpath1')
      expected_combination({ 'tags', oldval, '', oldval, 'tagpath1', 'global', 'setglobal' })

      command('setlocal tags=tagpath2')
      expected_combination({ 'tags', 'tagpath1', 'tagpath1', '', 'tagpath2', 'local', 'setlocal' })

      -- Note: v:option_old is the old global value for global-local options.
      -- but the old local value for all other kinds of options.
      command('noa setglobal tags=tag_global')
      command('noa setlocal tags=tag_local')
      command('set tags=tagpath')
      expected_combination({
        'tags',
        'tag_global',
        'tag_local',
        'tag_global',
        'tagpath',
        'global',
        'set',
      })

      -- Note: v:option_old is the old global value for global-local options.
      -- but the old local value for all other kinds of options.
      command('noa set tags=tag_global')
      command('noa setlocal tags=')
      command('set tags=tagpath')
      expected_combination({
        'tags',
        'tag_global',
        'tag_global',
        'tag_global',
        'tagpath',
        'global',
        'set',
      })
    end)

    it('with string local (to buffer) option', function()
      local oldval = eval('&spelllang')

      command('set spelllang=elvish,klingon')
      expected_combination({
        'spelllang',
        oldval,
        oldval,
        oldval,
        'elvish,klingon',
        'global',
        'set',
      })

      command('set spelllang&')
      expected_combination({
        'spelllang',
        'elvish,klingon',
        'elvish,klingon',
        'elvish,klingon',
        oldval,
        'global',
        'set',
      })

      command('setglobal spelllang=elvish')
      expected_combination({ 'spelllang', oldval, '', oldval, 'elvish', 'global', 'setglobal' })

      command('noa set spelllang&')
      command('setlocal spelllang=klingon')
      expected_combination({ 'spelllang', oldval, oldval, '', 'klingon', 'local', 'setlocal' })

      -- Note: v:option_old is the old global value for global-local options.
      -- but the old local value for all other kinds of options.
      command('noa setglobal spelllang=spellglobal')
      command('noa setlocal spelllang=spelllocal')
      command('set spelllang=foo')
      expected_combination({
        'spelllang',
        'spelllocal',
        'spelllocal',
        'spellglobal',
        'foo',
        'global',
        'set',
      })
    end)

    it('with string global-local (to window) option', function()
      local oldval = eval('&statusline')
      local default_statusline = api.nvim_get_option_info2('statusline', {}).default

      command('set statusline=foo')
      expected_combination({
        'statusline',
        oldval,
        oldval,
        oldval,
        'foo',
        'global',
        'set',
      })

      -- Note: v:option_old is the old global value for global-local options.
      -- but the old local value for all other kinds of options.
      command('set statusline&')
      expected_combination({
        'statusline',
        'foo',
        'foo',
        'foo',
        default_statusline,
        'global',
        'set',
      })

      command('setglobal statusline=bar')
      expected_combination({
        'statusline',
        default_statusline,
        '',
        default_statusline,
        'bar',
        'global',
        'setglobal',
      })

      command('noa set statusline&')
      command('setlocal statusline=baz')
      expected_combination({
        'statusline',
        default_statusline,
        default_statusline,
        '',
        'baz',
        'local',
        'setlocal',
      })

      -- Note: v:option_old is the old global value for global-local options.
      -- but the old local value for all other kinds of options.
      command('noa setglobal statusline=bar')
      command('noa setlocal statusline=baz')
      command('set statusline=foo')
      expected_combination({ 'statusline', 'bar', 'baz', 'bar', 'foo', 'global', 'set' })
    end)

    it('with string local (to window) option', function()
      local oldval = eval('&foldignore')

      command('set foldignore=fo')
      expected_combination({ 'foldignore', oldval, oldval, oldval, 'fo', 'global', 'set' })

      command('set foldignore&')
      expected_combination({ 'foldignore', 'fo', 'fo', 'fo', oldval, 'global', 'set' })

      command('setglobal foldignore=bar')
      expected_combination({ 'foldignore', oldval, '', oldval, 'bar', 'global', 'setglobal' })

      command('noa set foldignore&')
      command('setlocal foldignore=baz')
      expected_combination({ 'foldignore', oldval, oldval, '', 'baz', 'local', 'setlocal' })

      command('noa setglobal foldignore=glob')
      command('noa setlocal foldignore=loc')
      command('set foldignore=fo')
      expected_combination({ 'foldignore', 'loc', 'loc', 'glob', 'fo', 'global', 'set' })
    end)

    it('with number global option', function()
      command('noa setglobal cmdheight=8')
      command('noa setlocal cmdheight=1') -- Sets the global(!) value
      command('setglobal cmdheight=2')
      expected_combination({ 'cmdheight', 1, '', 1, 2, 'global', 'setglobal' })

      command('noa setglobal cmdheight=8')
      command('noa setlocal cmdheight=1') -- Sets the global(!) value
      command('setlocal cmdheight=2')
      expected_combination({ 'cmdheight', 1, 1, '', 2, 'local', 'setlocal' })

      -- Note: v:option_old is the old global value for global-local options.
      -- but the old local value for all other kinds of options.
      command('noa setglobal cmdheight=8')
      command('noa setlocal cmdheight=1') -- Sets the global(!) value
      command('set cmdheight=2')
      expected_combination({ 'cmdheight', 1, 1, 1, 2, 'global', 'set' })

      -- Note: v:option_old is the old global value for global-local options.
      -- but the old local value for all other kinds of options.
      command('noa set cmdheight=8')
      command('set cmdheight=2')
      expected_combination({ 'cmdheight', 8, 8, 8, 2, 'global', 'set' })
    end)

    it('with number global-local (to buffer) option', function()
      command('noa setglobal undolevels=8')
      command('noa setlocal undolevels=1')
      command('setglobal undolevels=2')
      expected_combination({ 'undolevels', 8, '', 8, 2, 'global', 'setglobal' })

      command('noa setglobal undolevels=8')
      command('noa setlocal undolevels=1')
      command('setlocal undolevels=2')
      expected_combination({ 'undolevels', 1, 1, '', 2, 'local', 'setlocal' })

      -- Note: v:option_old is the old global value for global-local options.
      -- but the old local value for all other kinds of options.
      command('noa setglobal undolevels=8')
      command('noa setlocal undolevels=1')
      command('set undolevels=2')
      expected_combination({ 'undolevels', 8, 1, 8, 2, 'global', 'set' })

      -- Note: v:option_old is the old global value for global-local options.
      -- but the old local value for all other kinds of options.
      command('noa set undolevels=8')
      command('set undolevels=2')
      expected_combination({ 'undolevels', 8, 8, 8, 2, 'global', 'set' })
    end)

    it('with number local (to buffer) option', function()
      command('noa setglobal wrapmargin=8')
      command('noa setlocal wrapmargin=1')
      command('setglobal wrapmargin=2')
      expected_combination({ 'wrapmargin', 8, '', 8, 2, 'global', 'setglobal' })

      command('noa setglobal wrapmargin=8')
      command('noa setlocal wrapmargin=1')
      command('setlocal wrapmargin=2')
      expected_combination({ 'wrapmargin', 1, 1, '', 2, 'local', 'setlocal' })

      command('noa setglobal wrapmargin=8')
      command('noa setlocal wrapmargin=1')
      command('set wrapmargin=2')
      expected_combination({ 'wrapmargin', 1, 1, 8, 2, 'global', 'set' })

      command('noa set wrapmargin=8')
      command('set wrapmargin=2')
      expected_combination({ 'wrapmargin', 8, 8, 8, 2, 'global', 'set' })
    end)

    it('with number global-local (to window) option', function()
      command('noa setglobal scrolloff=8')
      command('noa setlocal scrolloff=1')
      command('setglobal scrolloff=2')
      expected_combination({ 'scrolloff', 8, '', 8, 2, 'global', 'setglobal' })

      command('noa setglobal scrolloff=8')
      command('noa setlocal scrolloff=1')
      command('setlocal scrolloff=2')
      expected_combination({ 'scrolloff', 1, 1, '', 2, 'local', 'setlocal' })

      -- Note: v:option_old is the old global value for global-local options.
      -- but the old local value for all other kinds of options.
      command('noa setglobal scrolloff=8')
      command('noa setlocal scrolloff=1')
      command('set scrolloff=2')
      expected_combination({ 'scrolloff', 8, 1, 8, 2, 'global', 'set' })

      -- Note: v:option_old is the old global value for global-local options.
      -- but the old local value for all other kinds of options.
      command('noa set scrolloff=8')
      command('set scrolloff=2')
      expected_combination({ 'scrolloff', 8, 8, 8, 2, 'global', 'set' })
    end)

    it('with number local (to window) option', function()
      command('noa setglobal foldcolumn=8')
      command('noa setlocal foldcolumn=1')
      command('setglobal foldcolumn=2')
      expected_combination({ 'foldcolumn', '8', '', '8', '2', 'global', 'setglobal' })

      command('noa setglobal foldcolumn=8')
      command('noa setlocal foldcolumn=1')
      command('setlocal foldcolumn=2')
      expected_combination({ 'foldcolumn', '1', '1', '', '2', 'local', 'setlocal' })

      command('noa setglobal foldcolumn=8')
      command('noa setlocal foldcolumn=1')
      command('set foldcolumn=2')
      expected_combination({ 'foldcolumn', '1', '1', '8', '2', 'global', 'set' })

      command('noa set foldcolumn=8')
      command('set foldcolumn=2')
      expected_combination({ 'foldcolumn', '8', '8', '8', '2', 'global', 'set' })
    end)

    it('with boolean global option', function()
      command('noa setglobal nowrapscan')
      command('noa setlocal wrapscan') -- Sets the global(!) value
      command('setglobal nowrapscan')
      expected_combination({ 'wrapscan', true, '', true, false, 'global', 'setglobal' })

      command('noa setglobal nowrapscan')
      command('noa setlocal wrapscan') -- Sets the global(!) value
      command('setlocal nowrapscan')
      expected_combination({ 'wrapscan', true, true, '', false, 'local', 'setlocal' })

      command('noa setglobal nowrapscan')
      command('noa setlocal wrapscan') -- Sets the global(!) value
      command('set nowrapscan')
      expected_combination({ 'wrapscan', true, true, true, false, 'global', 'set' })

      command('noa set nowrapscan')
      command('set wrapscan')
      expected_combination({ 'wrapscan', false, false, false, true, 'global', 'set' })
    end)

    it('with boolean global-local (to buffer) option', function()
      command('noa setglobal noautoread')
      command('noa setlocal autoread')
      command('setglobal autoread')
      expected_combination({ 'autoread', false, '', false, true, 'global', 'setglobal' })

      command('noa setglobal noautoread')
      command('noa setlocal autoread')
      command('setlocal noautoread')
      expected_combination({ 'autoread', true, true, '', false, 'local', 'setlocal' })

      -- Note: v:option_old is the old global value for global-local options.
      -- but the old local value for all other kinds of options.
      command('noa setglobal noautoread')
      command('noa setlocal autoread')
      command('set autoread')
      expected_combination({ 'autoread', false, true, false, true, 'global', 'set' })

      -- Note: v:option_old is the old global value for global-local options.
      -- but the old local value for all other kinds of options.
      command('noa set noautoread')
      command('set autoread')
      expected_combination({ 'autoread', false, false, false, true, 'global', 'set' })
    end)

    it('with boolean local (to buffer) option', function()
      command('noa setglobal nocindent')
      command('noa setlocal cindent')
      command('setglobal cindent')
      expected_combination({ 'cindent', false, '', false, true, 'global', 'setglobal' })

      command('noa setglobal nocindent')
      command('noa setlocal cindent')
      command('setlocal nocindent')
      expected_combination({ 'cindent', true, true, '', false, 'local', 'setlocal' })

      command('noa setglobal nocindent')
      command('noa setlocal cindent')
      command('set cindent')
      expected_combination({ 'cindent', true, true, false, true, 'global', 'set' })

      command('noa set nocindent')
      command('set cindent')
      expected_combination({ 'cindent', false, false, false, true, 'global', 'set' })
    end)

    it('with boolean local (to window) option', function()
      command('noa setglobal nocursorcolumn')
      command('noa setlocal cursorcolumn')
      command('setglobal cursorcolumn')
      expected_combination({ 'cursorcolumn', false, '', false, true, 'global', 'setglobal' })

      command('noa setglobal nocursorcolumn')
      command('noa setlocal cursorcolumn')
      command('setlocal nocursorcolumn')
      expected_combination({ 'cursorcolumn', true, true, '', false, 'local', 'setlocal' })

      command('noa setglobal nocursorcolumn')
      command('noa setlocal cursorcolumn')
      command('set cursorcolumn')
      expected_combination({ 'cursorcolumn', true, true, false, true, 'global', 'set' })

      command('noa set nocursorcolumn')
      command('set cursorcolumn')
      expected_combination({ 'cursorcolumn', false, false, false, true, 'global', 'set' })
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
      expected_combination({ 'readonly', false, false, '', true, 'local', 'setlocal' })

      command('setglobal ro')
      expected_combination({ 'readonly', false, '', false, true, 'global', 'setglobal' })

      command('set noro')
      expected_combination({ 'readonly', true, true, true, false, 'global', 'set' })
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
        expected_combination({ 'backup', false, false, '', true, 'local', 'setlocal' })
      end)

      it('should trigger if the current buffer is different from the targeted buffer', function()
        set_hook('buftype')

        local new_buffer = make_buffer()
        local new_bufnr = api.nvim_buf_get_number(new_buffer)

        command('call setbufvar(' .. new_bufnr .. ', "&buftype", "nofile")')
        expected_combination({
          'buftype',
          '',
          '',
          '',
          'nofile',
          'local',
          'setlocal',
          { bufnr = new_bufnr },
        })
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
        expected_combination({ 'backup', false, false, '', true, 'local', 'setlocal' })
      end)

      it(
        'should not trigger if the current window is different from the targeted window',
        function()
          set_hook('cursorcolumn')

          local new_winnr = get_new_window_number()

          command('call setwinvar(' .. new_winnr .. ', "&cursorcolumn", 1)')
          -- expected_combination({'cursorcolumn', false, true, 'local', {winnr = new_winnr}})
          expected_empty()
        end
      )
    end)

    describe('being set by neovim api', function()
      it('should trigger if a boolean option be set globally', function()
        set_hook('autochdir')

        api.nvim_set_option_value('autochdir', true, { scope = 'global' })
        eq(true, api.nvim_get_option_value('autochdir', { scope = 'global' }))
        expected_combination({ 'autochdir', false, '', false, true, 'global', 'setglobal' })
      end)

      it('should trigger if a number option be set globally', function()
        set_hook('cmdheight')

        api.nvim_set_option_value('cmdheight', 5, { scope = 'global' })
        eq(5, api.nvim_get_option_value('cmdheight', { scope = 'global' }))
        expected_combination({ 'cmdheight', 1, '', 1, 5, 'global', 'setglobal' })
      end)

      it('should trigger if a string option be set globally', function()
        set_hook('ambiwidth')

        api.nvim_set_option_value('ambiwidth', 'double', { scope = 'global' })
        eq('double', api.nvim_get_option_value('ambiwidth', { scope = 'global' }))
        expected_combination({
          'ambiwidth',
          'single',
          '',
          'single',
          'double',
          'global',
          'setglobal',
        })
      end)
    end)
  end)
end)
