local helpers = require('test.functional.helpers')
local clear, nvim, eq = helpers.clear, helpers.nvim, helpers.eq
local source, execute = helpers.source, helpers.execute

describe('au OptionSet', function()
  setup(clear)

  describe('with * as <amatch>', function()
    describe('matches when being set any option', function()

      local function expected_str(option, oldval, newval, scope)
        return ''
          .. string.format('Autocmd Option: <%s>,', option)
          .. string.format(' OldVal: <%s>,', oldval)
          .. string.format(' NewVal: <%s>,', newval)
          .. string.format(' Scope: <%s>', scope)
      end

      local function get_result()
        return nvim('get_var', 'ret')
      end

      local function expected_combination(option, oldval, newval, scope)
        eq(expected_str(option, oldval, newval, scope), get_result())
      end

      local function expected_empty()
        eq('', get_result())
      end

      setup(function()

        source([[
          fu! AutoCommand(match)
            let g:ret.=printf('Autocmd Option: <%s>,', a:match)
            let g:ret.=printf(' OldVal: <%s>,', v:option_old)
            let g:ret.=printf(' NewVal: <%s>,', v:option_new)
            let g:ret.=printf(' Scope: <%s>', v:option_type)
          endfu
          
          au OptionSet * :call AutoCommand(expand("<amatch>"))
        ]])
      end)

      before_each(function()
        execute([[let g:ret = '']])
      end)

      it('should set number option', function()
        execute('set nu')
        expected_combination('number', 0, 1, 'global')
      end)

      it('should set local nonumber option',function()
        execute('setlocal nonu')
        expected_combination('number', 1, 0, 'local')
      end)

      it('should set global nonumber option',function()
        execute('setglobal nonu')
        expected_combination('number', 1, 0, 'global')
      end)

      it('should set local autoindent option',function()
        execute('setlocal ai')
        expected_combination('autoindent', 0, 1, 'local')
      end)

      it('should set global autoindent option',function()
        execute('setglobal ai')
        expected_combination('autoindent', 0, 1, 'global')
      end)

      it('should invert global autoindent option',function()
        execute('set ai!')
        expected_combination('autoindent', 1, 0, 'global')
      end)

      it('should set several global list and number option',function()
        execute('set list nu')
        eq(expected_str('list', 0, 1, 'global') .. expected_str('number', 0, 1, 'global'),
          get_result())
      end)

      it('should not print anything, use :noa.', function()
        execute('noa set nolist nonu')
        expected_empty()
      end)

      it('should set global acd', function()
        execute('setlocal acd')
        expected_combination('autochdir', 0, 1, 'local')
      end)

      it('should set global noautoread', function()
        execute('set noar')
        expected_combination('autoread', 1, 0, 'global')
      end)

      it('should set local autoread', function()
        execute('setlocal ar')
        expected_combination('autoread', 0, 1, 'local')
      end)

      it('should invert global autoread', function()
        execute('setglobal invar')
        expected_combination('autoread', 0, 1, 'global')
      end)

      it('should set option backspace through :let', function()
        execute('let &bs=""')
        expected_combination('backspace', 'indent,eol,start', '', 'global')
      end)

      describe('setting option through setbufvar()', function()
        it('shouldn\'t trigger because option name is invalid', function()
          execute('call setbufvar(1, "&l:bk", 1)')
          expected_empty()
        end)

        it('should trigger, use correct option name.', function()
          execute('call setbufvar(1, "&backup", 1)')
          expected_combination('backup', 0, 1, 'local')
        end)
      end)
    end)
  end)
end)
