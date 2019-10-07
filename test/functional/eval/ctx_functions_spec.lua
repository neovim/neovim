local helpers = require('test.functional.helpers')(after_each)

local call = helpers.call
local clear = helpers.clear
local command = helpers.command
local eq = helpers.eq
local eval = helpers.eval
local feed = helpers.feed
local map = helpers.map
local matches = helpers.matches
local nvim = helpers.nvim
local redir_exec = helpers.redir_exec
local source = helpers.source
local trim = helpers.trim
local write_file = helpers.write_file
local pcall_err = helpers.pcall_err

local NIL = helpers.NIL

describe('context functions', function()
  local fname1 = 'Xtest-functional-eval-ctx1'
  local fname2 = 'Xtest-functional-eval-ctx2'

  before_each(function()
    clear()
    write_file(fname1, "1\n2\n3")
    write_file(fname2, "a\nb\nc")
  end)

  after_each(function()
    os.remove(fname1)
    os.remove(fname2)
  end)

  it('frees context stack on exit', function()
    call('ctxpush')
    call('ctxpush')
    eq(2, eval('ctxsize()'))
  end)

  describe('ctxpush/ctxpop', function()
    it('errors out on invalid arguments', function()
      matches('Invalid argument', pcall_err(call, 'ctxpush', 1))
    end)

    it('saves and restores registers properly', function()
      local regs = {'1', '2', '3', 'a'}
      local vals = {'1', '2', '3', 'hjkl'}
      feed('i1<cr>2<cr>3<c-[>ddddddqahjklq')
      eq(vals, map(function(r) return trim(call('getreg', r)) end, regs))
      call('ctxpush')
      call('ctxpush', {'regs'})

      map(function(r) call('setreg', r, {}) end, regs)
      eq({'', '', '', ''},
         map(function(r) return trim(call('getreg', r)) end, regs))

      call('ctxpop')
      eq(vals, map(function(r) return trim(call('getreg', r)) end, regs))

      map(function(r) call('setreg', r, {}) end, regs)
      eq({'', '', '', ''},
         map(function(r) return trim(call('getreg', r)) end, regs))

      call('ctxpop')
      eq(vals, map(function(r) return trim(call('getreg', r)) end, regs))
    end)

    it('saves and restores jumplist properly', function()
      command('edit '..fname1)
      feed('G')
      feed('gg')
      command('edit '..fname2)
      local jumplist = call('getjumplist')
      call('ctxpush')
      call('ctxpush', {'jumps'})

      command('clearjumps')
      eq({{}, 0}, call('getjumplist'))

      call('ctxpop')
      eq(jumplist, call('getjumplist'))

      command('clearjumps')
      eq({{}, 0}, call('getjumplist'))

      call('ctxpop')
      eq(jumplist, call('getjumplist'))
    end)

    it('saves and restores buffer list properly', function()
      command('edit '..fname1)
      command('edit '..fname2)
      command('edit TEST')
      local bufs = call('map', call('getbufinfo'), 'v:val.name')
      call('ctxpush')
      call('ctxpush', {'bufs'})

      command('%bwipeout')
      eq({''}, call('map', call('getbufinfo'), 'v:val.name'))

      call('ctxpop')
      eq({'', unpack(bufs)}, call('map', call('getbufinfo'), 'v:val.name'))

      command('%bwipeout')
      eq({''}, call('map', call('getbufinfo'), 'v:val.name'))

      call('ctxpop')
      eq({'', unpack(bufs)}, call('map', call('getbufinfo'), 'v:val.name'))
    end)

    it('saves and restores script-local variables properly', function()
      source([[
      function SEval(name)
        return eval(a:name)
      endfunction

      function SExec(cmd)
        return execute(a:cmd)
      endfunction

      let s:one = 1
      let s:Two = 2
      let s:THREE = 3
      ]])

      eq({1, 2 ,3},
         eval([[map(['s:one', 's:Two', 's:THREE'], 'SEval(v:val)')]]))

      call('SEval', [[ctxpush()]])
      call('SEval', [[ctxpush(['svars'])]])

      call('SExec', [[unlet s:one]])
      call('SExec', [[unlet s:Two]])
      call('SExec', [[unlet s:THREE]])
      matches('E121: Undefined variable: s:one',
              pcall_err(eval, [[SEval('s:one')]]))
      matches('E121: Undefined variable: s:Two',
              pcall_err(eval, [[SEval('s:Two')]]))
      matches('E121: Undefined variable: s:THREE',
              pcall_err(eval, [[SEval('s:THREE')]]))

      call('SEval', [[ctxpop()]])
      eq({1, 2 ,3},
         eval([[map(['s:one', 's:Two', 's:THREE'], 'SEval(v:val)')]]))

      call('SExec', [[unlet s:one]])
      call('SExec', [[unlet s:Two]])
      call('SExec', [[unlet s:THREE]])
      matches('E121: Undefined variable: s:one',
              pcall_err(eval, [[SEval('s:one')]]))
      matches('E121: Undefined variable: s:Two',
              pcall_err(eval, [[SEval('s:Two')]]))
      matches('E121: Undefined variable: s:THREE',
              pcall_err(eval, [[SEval('s:THREE')]]))

      call('SEval', [[timer_start(0, { -> ctxpop() })]])
      eq({1, 2 ,3},
         eval([[map(['s:one', 's:Two', 's:THREE'], 'SEval(v:val)')]]))
    end)

    it('saves and restores global variables properly', function()
      nvim('set_var', 'one', 1)
      nvim('set_var', 'Two', 2)
      nvim('set_var', 'THREE', 3)
      eq({1, 2 ,3}, eval('[g:one, g:Two, g:THREE]'))
      call('ctxpush')
      call('ctxpush', {'gvars'})

      nvim('del_var', 'one')
      nvim('del_var', 'Two')
      nvim('del_var', 'THREE')
      eq('Vim:E121: Undefined variable: g:one', pcall_err(eval, 'g:one'))
      eq('Vim:E121: Undefined variable: g:Two', pcall_err(eval, 'g:Two'))
      eq('Vim:E121: Undefined variable: g:THREE', pcall_err(eval, 'g:THREE'))

      call('ctxpop')
      eq({1, 2 ,3}, eval('[g:one, g:Two, g:THREE]'))

      nvim('del_var', 'one')
      nvim('del_var', 'Two')
      nvim('del_var', 'THREE')
      eq('Vim:E121: Undefined variable: g:one', pcall_err(eval, 'g:one'))
      eq('Vim:E121: Undefined variable: g:Two', pcall_err(eval, 'g:Two'))
      eq('Vim:E121: Undefined variable: g:THREE', pcall_err(eval, 'g:THREE'))

      call('ctxpop')
      eq({1, 2 ,3}, eval('[g:one, g:Two, g:THREE]'))
    end)

    it('saves and restores b:, w:, and t: variables properly', function()
      command('let [b:one, w:Two, t:THREE] = [1, 2, 3]')
      eq({1, 2 ,3}, eval('[b:one, w:Two, t:THREE]'))
      call('ctxpush')
      call('ctxpush', {'bvars', 'wvars', 'tvars'})

      command('unlet b:one w:Two t:THREE')
      matches('E121: Undefined variable: b:one', pcall_err(eval, 'b:one'))
      matches('E121: Undefined variable: w:Two', pcall_err(eval, 'w:Two'))
      matches('E121: Undefined variable: t:THREE', pcall_err(eval, 't:THREE'))

      call('ctxpop')
      eq({1, 2 ,3}, eval('[b:one, w:Two, t:THREE]'))

      command('unlet b:one w:Two t:THREE')
      matches('E121: Undefined variable: b:one', pcall_err(eval, 'b:one'))
      matches('E121: Undefined variable: w:Two', pcall_err(eval, 'w:Two'))
      matches('E121: Undefined variable: t:THREE', pcall_err(eval, 't:THREE'))

      call('ctxpop')
      eq({1, 2 ,3}, eval('[b:one, w:Two, t:THREE]'))
    end)

    it('saves and restores function-local variables properly', function()
      source([[
      function Test()
        let l:one = 1
        let l:Two = 2
        let THREE = 3

        let g:vars1 = [l:one, l:Two, l:THREE]
        call ctxpush()
        call ctxset(filter(ctxget(), 'v:key != "funcs"'))
        call ctxpush(['lvars'])

        unlet l:one l:Two l:THREE
        let g:vars2 =
         \ map(['l:one', 'l:Two', 'l:THREE'], 'exists(v:val) ? {v:val} : 0')

        call ctxpop()
        let g:vars3 = [l:one, l:Two, l:THREE]

        unlet l:one l:Two l:THREE
        let g:vars4 =
         \ map(['l:one', 'l:Two', 'l:THREE'], 'exists(v:val) ? {v:val} : 0')

        call ctxpop()
        let g:vars5 = [l:one, l:Two, l:THREE]
      endfunction
      call Test()
      ]])

      eq({1, 2, 3}, eval('g:vars1'))
      eq({0, 0, 0}, eval('g:vars2'))
      eq({1, 2, 3}, eval('g:vars3'))
      eq({0, 0, 0}, eval('g:vars4'))
      eq({1, 2, 3}, eval('g:vars5'))
    end)

    it('saves and restores parent-scope variables for closures', function()
      source([[
      let g:states = []

      function Parent()
        function! PushState(...) closure
          call add(g:states, map(deepcopy(a:000),
           \                     'exists(v:val) ? eval(v:val) : v:null'))
        endfunction

        let name = 'Parent'
        let parent_data = 'Parent data'
        call ctxpush(['lvars'])
        call PushState('l:name', 'l:parent_data')

        unlet l:name l:parent_data
        call PushState('l:name', 'l:parent_data')

        call ctxpop()
        call PushState('l:name', 'l:parent_data')

        function! NotClosure()
          function! PushState(...) closure
            call add(g:states, map(deepcopy(a:000),
             \                     'exists(v:val) ? eval(v:val) : v:null'))
          endfunction

          let name = 'NotClosure'
          call ctxpush(['lvars'])
          call PushState('l:name', 'l:parent_data')

          unlet l:name
          call PushState('l:name', 'l:parent_data')

          call ctxpop()
          call PushState('l:name', 'l:parent_data')
        endfunction

        function! Closure1() closure
          function! PushState(...) closure
            call add(g:states, map(deepcopy(a:000),
             \                     'exists(v:val) ? eval(v:val) : v:null'))
          endfunction

          let name = 'Closure1'
          let closure1_data = 'Closure1 data'
          call ctxpush(['lvars'])
          call PushState('l:name', 'l:parent_data', 'l:closure1_data')

          unlet l:name l:parent_data l:closure1_data
          call PushState('l:name', 'l:parent_data', 'l:closure1_data')

          call ctxpop()
          call PushState('l:name', 'l:parent_data', 'l:closure1_data')

          function! Closure2() closure
            function! PushState(...) closure
              call add(g:states, map(deepcopy(a:000),
               \                     'exists(v:val) ? eval(v:val) : v:null'))
            endfunction

            let name = 'Closure2'
            let closure2_data = 'Closure2 data'
            call ctxpush(['lvars'])
            call PushState('l:name', 'l:parent_data', 'l:closure1_data',
             \             'l:closure2_data')

            unlet l:name l:parent_data l:closure1_data l:closure2_data
            call PushState('l:name', 'l:parent_data', 'l:closure1_data',
             \             'l:closure2_data')

            call ctxpop()
            call PushState('l:name', 'l:parent_data', 'l:closure1_data',
             \             'l:closure2_data')
          endfunction
        endfunction
      endfunction

      call Parent()
      call NotClosure()
      call Closure1()
      call Closure2()
      ]])

      eq({{'Parent', 'Parent data'},
          {NIL, NIL},
          {'Parent', 'Parent data'},
          {'NotClosure', NIL},
          {NIL, NIL},
          {'NotClosure', NIL},
          {'Closure1', 'Parent data', 'Closure1 data'},
          {NIL, NIL, NIL},
          {'Closure1', 'Parent data', 'Closure1 data'},
          {'Closure2', 'Parent data', 'Closure1 data', 'Closure2 data'},
          {NIL, NIL, NIL, NIL},
          {'Closure2', 'Parent data', 'Closure1 data', 'Closure2 data'}},
         eval('g:states'))
    end)

    it('saves and restores all variables properly', function()
      source([[
      let g:var = 'g:varval'
      let s:var = 's:varval'
      let b:var = 'b:varval'
      let w:var = 'w:varval'
      let t:var = 't:varval'

      function Parent()
        let l:var1 = 'l:var1val'
        function Child() closure
          let l:var2 = 'l:var2val'
          function Grandchild(expr, type, ...) closure
            if a:type == 0
              return eval(a:expr)
            elseif a:type == 1
              return execute(a:expr)
            elseif a:type == 2
              return call(a:expr, a:000)
            endif
          endfunction
        endfunction
        call Child()
      endfunction
      call Parent()

      function PopAndMap(expr1, expr2)
        call ctxpop()
        return map(a:expr1, a:expr2)
      endfunction
      ]])

      local vars = { 'g:var', 's:var', 'b:var', 'w:var', 't:var', 'l:var1',
                     'l:var2' }

      eq(call('map', vars, [[v:val.'val']]),
         call('map', vars, 'Grandchild(v:val, 0)'))
      call('Grandchild', [[ctxpush(['vars'])]], 0)

      call('map', vars, [[Grandchild('unlet '.v:val, 1)]])
      eq(call('repeat', {0}, #vars),
         call('map', vars, [[Grandchild('exists("'.v:val.'")', 0)]]))

      eq(call('map', vars, [[v:val.'val']]),
         call('Grandchild', 'PopAndMap', 2, vars, 'eval(v:val)'))
    end)

    it('saves and restores script functions properly', function()
      source([[
      function s:greet(name)
        echom 'Hello, '.a:name.'!'
      endfunction

      function s:greet_all(name, ...)
        echom 'Hello, '.a:name.'!'
        for more in a:000
          echom 'Hello, '.more.'!'
        endfor
      endfunction

      function Greet(name)
        call call('s:greet', [a:name])
      endfunction

      function GreetAll(name, ...)
        call call('s:greet_all', extend([a:name], a:000))
      endfunction

      function DeleteSFuncs()
        delfunction s:greet
        delfunction s:greet_all
      endfunction
      ]])

      eq('\nHello, World!', redir_exec([[call Greet('World')]]))
      eq('\nHello, World!'..
         '\nHello, One!'..
         '\nHello, Two!'..
         '\nHello, Three!',
         redir_exec([[call GreetAll('World', 'One', 'Two', 'Three')]]))

      call('ctxpush', {'sfuncs'})
      call('DeleteSFuncs')

      eq('\nError detected while processing function Greet:'..
         '\nline    1:'..
         '\nE117: Unknown function: s:greet',
         redir_exec([[call Greet('World')]]))
      eq('\nError detected while processing function GreetAll:'..
         '\nline    1:'..
         '\nE117: Unknown function: s:greet_all',
         redir_exec([[call GreetAll('World', 'One', 'Two', 'Three')]]))

      call('ctxpop')

      eq('\nHello, World!', redir_exec([[call Greet('World')]]))
      eq('\nHello, World!'..
         '\nHello, One!'..
         '\nHello, Two!'..
         '\nHello, Three!',
         redir_exec([[call GreetAll('World', 'One', 'Two', 'Three')]]))
    end)

    it('saves and restores functions properly', function()
      source([[
      function Greet(name)
        echom 'Hello, '.a:name.'!'
      endfunction

      function GreetAll(name, ...)
        echom 'Hello, '.a:name.'!'
        for more in a:000
          echom 'Hello, '.more.'!'
        endfor
      endfunction
      ]])

      eq('\nHello, World!', redir_exec([[call Greet('World')]]))
      eq('\nHello, World!'..
         '\nHello, One!'..
         '\nHello, Two!'..
         '\nHello, Three!',
         redir_exec([[call GreetAll('World', 'One', 'Two', 'Three')]]))

      call('ctxpush', {'funcs'})
      command('delfunction Greet')
      command('delfunction GreetAll')

      eq('Vim:E117: Unknown function: Greet', pcall_err(call, 'Greet', 'World'))
      eq('Vim:E117: Unknown function: GreetAll',
        pcall_err(call, 'GreetAll', 'World', 'One', 'Two', 'Three'))

      call('ctxpop')

      eq('\nHello, World!', redir_exec([[call Greet('World')]]))
      eq('\nHello, World!'..
         '\nHello, One!'..
         '\nHello, Two!'..
         '\nHello, Three!',
         redir_exec([[call GreetAll('World', 'One', 'Two', 'Three')]]))
    end)

    it('saves and restores sandboxed functions', function()
      source([[
      sandbox function SandboxedFunction()
        edit foo
      endfunction
      ]])

      matches('Not allowed in sandbox', pcall_err(call, 'SandboxedFunction'))
      call('ctxpush')
      command([[delfunction SandboxedFunction]])
      matches('Unknown function', pcall_err(call, 'SandboxedFunction'))
      call('ctxpop')
      matches('Not allowed in sandbox', pcall_err(call, 'SandboxedFunction'))
    end)

    it('ignores refcounted functions', function()
      source([[
      let g:foo = {'name': 'Neovim'}
      function g:foo.greet()
        return 'Hello, '.self.name.'!'
      endfunction
      let g:Foo = { -> 'bar' }
      ]])
      eq('Hello, Neovim!', eval('foo.greet()'))
      eq('bar', eval('Foo()'))
      eq({}, eval([[nvim_get_context({'types': ['funcs']})]]))
    end)

    it('saves and restores options properly', function()
      local opts = {
        '&g:autochdir', '&g:statusline', '&g:equalprg', -- global
        '&l:arabic', '&l:statusline', -- win
        '&l:autoindent', '&l:equalprg', -- buf
      }

      local defaults = { 0, '', '', 0, '', 1, '' }
      local custom = { 1, 'foo', 'fizz', 1, 'bar', 0, 'buzz' }

      local get_opts = function()
        return map(function(opt) return eval(opt) end, opts)
      end

      local set_opts = function(vals)
        for i, v in pairs(opts) do
          command('let '..v..' = "'..vals[i]..'"')
        end
      end

      command('set all&')
      eq(defaults, get_opts())

      call('ctxpush')
      set_opts(custom)
      eq(custom, get_opts())

      call('ctxpop')
      eq(defaults, get_opts())

      set_opts(custom)
      eq(custom, get_opts())

      call('ctxpush', {'bopts'})
      call('ctxpush', {'wopts'})
      call('ctxpush', {'gopts'})
      call('ctxpush', {'opts'})

      command('set all&')
      eq(defaults, get_opts())
      call('ctxpop')
      eq(custom, get_opts())

      command('set all&')
      eq(defaults, get_opts())
      call('ctxpop')
      eq({ 1, 'foo', 'fizz', 0, '', 1, '' }, get_opts())

      command('set all&')
      eq(defaults, get_opts())
      call('ctxpop')
      eq({ 0, '', '', 1, 'bar', 1, '' }, get_opts())

      command('set all&')
      eq(defaults, get_opts())
      call('ctxpop')
      eq({ 0, '', '', 0, '', 0, 'buzz' }, get_opts())
    end)

    it('errors out when context stack is empty', function()
      local err = 'Vim:Context stack is empty'
      eq(err, pcall_err(call, 'ctxpop'))
      eq(err, pcall_err(call, 'ctxpop'))
      call('ctxpush')
      call('ctxpush')
      call('ctxpop')
      call('ctxpop')
      eq(err, pcall_err(call, 'ctxpop'))
    end)

    it('errors out on malformed context dictionary', function()
      call('ctxpush')
      call('ctxset', {vars = {{'1', '2'}}})
      matches('Vim:E461: Illegal variable name: 1',
         pcall_err(call, 'ctxpop'))
    end)
  end)

  describe('ctxsize()', function()
    it('returns context stack size', function()
      eq(0, call('ctxsize'))
      call('ctxpush')
      eq(1, call('ctxsize'))
      call('ctxpush')
      eq(2, call('ctxsize'))
      call('ctxpush')
      eq(3, call('ctxsize'))
      call('ctxpop')
      eq(2, call('ctxsize'))
      call('ctxpop')
      eq(1, call('ctxsize'))
      call('ctxpop')
      eq(0, call('ctxsize'))
    end)
  end)

  describe('ctxget()', function()
    it('errors out on invalid arguments', function()
      matches('Invalid argument', pcall_err(call, 'ctxget', ''))
      matches('out of bounds', pcall_err(call, 'ctxget'))
      matches('out of bounds', pcall_err(call, 'ctxget'))
      call('ctxpush')
      matches('out of bounds', pcall_err(call, 'ctxget', 1))
      call('ctxpop')
      matches('out of bounds', pcall_err(call, 'ctxget', 0))
    end)

    it('returns context dictionary at index in context stack', function()
      feed('i1<cr>2<cr>3<c-[>ddddddqahjklq')
      command('edit! '..fname1)
      feed('G')
      feed('gg')
      command('edit '..fname2)
      nvim('set_var', 'one', 1)
      nvim('set_var', 'Two', 2)
      nvim('set_var', 'THREE', 3)

      local with_regs = {
        ['regs'] = {
          {['type'] = 1, ['content'] = {'1'},
           ['name'] = '1', ['unnamed'] = true},
          {['type'] = 1, ['content'] = {'2'}, ['name'] = '2'},
          {['type'] = 1, ['content'] = {'3'}, ['name'] = '3'},
          {['content'] = {'hjkl'}, ['name'] = 'a'},
        }
      }

      local with_jumps = {
        ['jumps'] = eval(([[
        filter(map(getjumplist()[0], 'filter(
          { "file": expand("#".v:val.bufnr.":p"), "line": v:val.lnum },
          { k, v -> k != "line" || v != 1 })'), '!empty(v:val.file)')
        ]]):gsub('\n', ''))
      }

      local with_bufs = {
        ['bufs'] = eval(([[
        filter(map(getbufinfo(), '{ "file": v:val.name }'),
               '!empty(v:val.file)')
        ]]):gsub('\n', '')),
      }

      local with_vars = {
        ['vars'] = {{'g:one', 1}, {'g:Two', 2}, {'g:THREE', 3}}
      }

      local with_all = {
        ['regs'] = with_regs['regs'],
        ['jumps'] = with_jumps['jumps'],
        ['bufs'] = with_bufs['bufs'],
        ['vars'] = with_vars['vars'],
      }

      local ctxget = function(...)
        local ctx = call('ctxget', ...)
        ctx['opts'] = nil
        return ctx
      end

      call('ctxpush')
      eq(with_all, ctxget())
      eq(with_all, ctxget(0))

      call('ctxpush', {'gvars'})
      eq(with_vars, ctxget())
      eq(with_vars, ctxget(0))
      eq(with_all, ctxget(1))

      call('ctxpush', {'bufs'})
      eq(with_bufs, ctxget())
      eq(with_bufs, ctxget(0))
      eq(with_vars, ctxget(1))
      eq(with_all, ctxget(2))

      call('ctxpush', {'jumps'})
      eq(with_jumps, ctxget())
      eq(with_jumps, ctxget(0))
      eq(with_bufs, ctxget(1))
      eq(with_vars, ctxget(2))
      eq(with_all, ctxget(3))

      call('ctxpush', {'regs'})
      eq(with_regs, ctxget())
      eq(with_regs, ctxget(0))
      eq(with_jumps, ctxget(1))
      eq(with_bufs, ctxget(2))
      eq(with_vars, ctxget(3))
      eq(with_all, ctxget(4))

      call('ctxpop')
      eq(with_jumps, ctxget())
      eq(with_jumps, ctxget(0))
      eq(with_bufs, ctxget(1))
      eq(with_vars, ctxget(2))
      eq(with_all, ctxget(3))

      call('ctxpop')
      eq(with_bufs, ctxget())
      eq(with_bufs, ctxget(0))
      eq(with_vars, ctxget(1))
      eq(with_all, ctxget(2))

      call('ctxpop')
      eq(with_vars, ctxget())
      eq(with_vars, ctxget(0))
      eq(with_all, ctxget(1))

      call('ctxpop')
      eq(with_all, ctxget())
      eq(with_all, ctxget(0))
    end)
  end)

  describe('ctxset()', function()
    it('errors out on invalid arguments', function()
      matches('Invalid argument', pcall_err(call, 'ctxset', 1))
      matches('Invalid argument', pcall_err(call, 'ctxset', {}, ''))
      matches('out of bounds', pcall_err(call, 'ctxset', {dummy = 1}))
      call('ctxpush')
      matches('out of bounds', pcall_err(call, 'ctxset', {dummy = 1}, 1))
      call('ctxpop')
      matches('out of bounds', pcall_err(call, 'ctxset', {dummy = 1}, 0))
    end)

    it('errors out on malformed context dictionary', function()
      call('ctxpush')
      matches("Invalid type for 'regs'",
              pcall_err(call, 'ctxset', {regs = 1}))
      matches('Invalid key: foo',
              pcall_err(call, 'ctxset', {foo = {}}))
    end)

    it('sets context dictionary at index in context stack', function()
      nvim('set_var', 'one', 1)
      nvim('set_var', 'Two', 2)
      nvim('set_var', 'THREE', 3)
      call('ctxpush')
      local ctx1 = call('ctxget')
      nvim('set_var', 'one', 'a')
      nvim('set_var', 'Two', 'b')
      nvim('set_var', 'THREE', 'c')
      call('ctxpush')
      call('ctxpush')
      local ctx2 = call('ctxget')

      eq({'a', 'b' ,'c'}, eval('[g:one, g:Two, g:THREE]'))
      call('ctxset', ctx1)
      call('ctxset', ctx2, 2)
      call('ctxpop')
      eq({1, 2 ,3}, eval('[g:one, g:Two, g:THREE]'))
      call('ctxpop')
      eq({'a', 'b' ,'c'}, eval('[g:one, g:Two, g:THREE]'))
      nvim('set_var', 'one', 1.5)
      eq({1.5, 'b' ,'c'}, eval('[g:one, g:Two, g:THREE]'))
      call('ctxpop')
      eq({'a', 'b' ,'c'}, eval('[g:one, g:Two, g:THREE]'))
    end)
  end)

  it('frees context stack on exit', function()
    call('ctxpush')
  end)
end)
