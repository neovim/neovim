local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local call = n.call
local clear = n.clear
local command = n.command
local eq = t.eq
local eval = n.eval
local feed = n.feed
local map = vim.tbl_map
local api = n.api
local parse_context = n.parse_context
local exec_capture = n.exec_capture
local source = n.source
local trim = vim.trim
local write_file = t.write_file
local pcall_err = t.pcall_err

describe('context functions', function()
  local fname1 = 'Xtest-functional-eval-ctx1'
  local fname2 = 'Xtest-functional-eval-ctx2'
  local outofbounds = 'Vim:E475: Invalid value for argument index: out of bounds'

  before_each(function()
    clear()
    write_file(fname1, '1\n2\n3')
    write_file(fname2, 'a\nb\nc')
  end)

  after_each(function()
    os.remove(fname1)
    os.remove(fname2)
  end)

  describe('ctxpush/ctxpop', function()
    it('saves and restores registers properly', function()
      local regs = { '1', '2', '3', 'a' }
      local vals = { '1', '2', '3', 'hjkl' }
      feed('i1<cr>2<cr>3<c-[>ddddddqahjklq')
      eq(
        vals,
        map(function(r)
          return trim(call('getreg', r))
        end, regs)
      )
      call('ctxpush')
      call('ctxpush', { 'regs' })

      map(function(r)
        call('setreg', r, {})
      end, regs)
      eq(
        { '', '', '', '' },
        map(function(r)
          return trim(call('getreg', r))
        end, regs)
      )

      call('ctxpop')
      eq(
        vals,
        map(function(r)
          return trim(call('getreg', r))
        end, regs)
      )

      map(function(r)
        call('setreg', r, {})
      end, regs)
      eq(
        { '', '', '', '' },
        map(function(r)
          return trim(call('getreg', r))
        end, regs)
      )

      call('ctxpop')
      eq(
        vals,
        map(function(r)
          return trim(call('getreg', r))
        end, regs)
      )
    end)

    it('saves and restores jumplist properly', function()
      command('edit ' .. fname1)
      feed('G')
      feed('gg')
      command('edit ' .. fname2)
      local jumplist = call('getjumplist')
      call('ctxpush')
      call('ctxpush', { 'jumps' })

      command('clearjumps')
      eq({ {}, 0 }, call('getjumplist'))

      call('ctxpop')
      eq(jumplist, call('getjumplist'))

      command('clearjumps')
      eq({ {}, 0 }, call('getjumplist'))

      call('ctxpop')
      eq(jumplist, call('getjumplist'))
    end)

    it('saves and restores buffer list properly', function()
      command('edit ' .. fname1)
      command('edit ' .. fname2)
      command('edit TEST')
      local bufs = call('map', call('getbufinfo'), 'v:val.name')
      call('ctxpush')
      call('ctxpush', { 'bufs' })

      command('%bwipeout')
      eq({ '' }, call('map', call('getbufinfo'), 'v:val.name'))

      call('ctxpop')
      eq({ '', unpack(bufs) }, call('map', call('getbufinfo'), 'v:val.name'))

      command('%bwipeout')
      eq({ '' }, call('map', call('getbufinfo'), 'v:val.name'))

      call('ctxpop')
      eq({ '', unpack(bufs) }, call('map', call('getbufinfo'), 'v:val.name'))
    end)

    it('saves and restores global variables properly', function()
      api.nvim_set_var('one', 1)
      api.nvim_set_var('Two', 2)
      api.nvim_set_var('THREE', 3)
      eq({ 1, 2, 3 }, eval('[g:one, g:Two, g:THREE]'))
      call('ctxpush')
      call('ctxpush', { 'gvars' })

      api.nvim_del_var('one')
      api.nvim_del_var('Two')
      api.nvim_del_var('THREE')
      eq('Vim:E121: Undefined variable: g:one', pcall_err(eval, 'g:one'))
      eq('Vim:E121: Undefined variable: g:Two', pcall_err(eval, 'g:Two'))
      eq('Vim:E121: Undefined variable: g:THREE', pcall_err(eval, 'g:THREE'))

      call('ctxpop')
      eq({ 1, 2, 3 }, eval('[g:one, g:Two, g:THREE]'))

      api.nvim_del_var('one')
      api.nvim_del_var('Two')
      api.nvim_del_var('THREE')
      eq('Vim:E121: Undefined variable: g:one', pcall_err(eval, 'g:one'))
      eq('Vim:E121: Undefined variable: g:Two', pcall_err(eval, 'g:Two'))
      eq('Vim:E121: Undefined variable: g:THREE', pcall_err(eval, 'g:THREE'))

      call('ctxpop')
      eq({ 1, 2, 3 }, eval('[g:one, g:Two, g:THREE]'))
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

      function SaveSFuncs()
        call ctxpush(['sfuncs'])
      endfunction

      function DeleteSFuncs()
        delfunction s:greet
        delfunction s:greet_all
      endfunction

      function RestoreFuncs()
        call ctxpop()
      endfunction

      let g:sid = expand('<SID>')
      ]])
      local sid = api.nvim_get_var('sid')

      eq('Hello, World!', exec_capture([[call Greet('World')]]))
      eq(
        'Hello, World!' .. '\nHello, One!' .. '\nHello, Two!' .. '\nHello, Three!',
        exec_capture([[call GreetAll('World', 'One', 'Two', 'Three')]])
      )

      call('SaveSFuncs')
      call('DeleteSFuncs')

      eq(
        ('function Greet, line 1: Vim(call):E117: Unknown function: %sgreet'):format(sid),
        pcall_err(command, [[call Greet('World')]])
      )
      eq(
        ('function GreetAll, line 1: Vim(call):E117: Unknown function: %sgreet_all'):format(sid),
        pcall_err(command, [[call GreetAll('World', 'One', 'Two', 'Three')]])
      )

      call('RestoreFuncs')

      eq('Hello, World!', exec_capture([[call Greet('World')]]))
      eq(
        'Hello, World!' .. '\nHello, One!' .. '\nHello, Two!' .. '\nHello, Three!',
        exec_capture([[call GreetAll('World', 'One', 'Two', 'Three')]])
      )
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

      eq('Hello, World!', exec_capture([[call Greet('World')]]))
      eq(
        'Hello, World!' .. '\nHello, One!' .. '\nHello, Two!' .. '\nHello, Three!',
        exec_capture([[call GreetAll('World', 'One', 'Two', 'Three')]])
      )

      call('ctxpush', { 'funcs' })
      command('delfunction Greet')
      command('delfunction GreetAll')

      eq('Vim:E117: Unknown function: Greet', pcall_err(call, 'Greet', 'World'))
      eq(
        'Vim:E117: Unknown function: GreetAll',
        pcall_err(call, 'GreetAll', 'World', 'One', 'Two', 'Three')
      )

      call('ctxpop')

      eq('Hello, World!', exec_capture([[call Greet('World')]]))
      eq(
        'Hello, World!' .. '\nHello, One!' .. '\nHello, Two!' .. '\nHello, Three!',
        exec_capture([[call GreetAll('World', 'One', 'Two', 'Three')]])
      )
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
    it('errors out when index is out of bounds', function()
      eq(outofbounds, pcall_err(call, 'ctxget'))
      call('ctxpush')
      eq(outofbounds, pcall_err(call, 'ctxget', 1))
      call('ctxpop')
      eq(outofbounds, pcall_err(call, 'ctxget', 0))
    end)

    it('returns context dict at index in context stack', function()
      feed('i1<cr>2<cr>3<c-[>ddddddqahjklq')
      command('edit! ' .. fname1)
      feed('G')
      feed('gg')
      command('edit ' .. fname2)
      api.nvim_set_var('one', 1)
      api.nvim_set_var('Two', 2)
      api.nvim_set_var('THREE', 3)

      local with_regs = {
        ['regs'] = {
          { ['rt'] = 1, ['rc'] = { '1' }, ['n'] = 49, ['ru'] = true },
          { ['rt'] = 1, ['rc'] = { '2' }, ['n'] = 50 },
          { ['rt'] = 1, ['rc'] = { '3' }, ['n'] = 51 },
          { ['rc'] = { 'hjkl' }, ['n'] = 97 },
        },
      }

      local with_jumps = {
        ['jumps'] = eval((([[
        filter(map(add(
        getjumplist()[0], { 'bufnr': bufnr('%'), 'lnum': getcurpos()[1] }),
        'filter(
        { "f": expand("#".v:val.bufnr.":p"), "l": v:val.lnum },
        { k, v -> k != "l" || v != 1 })'), '!empty(v:val.f)')
        ]]):gsub('\n', ''))),
      }

      local with_bufs = {
        ['bufs'] = eval([[
        filter(map(getbufinfo(), '{ "f": v:val.name }'), '!empty(v:val.f)')
        ]]),
      }

      local with_gvars = {
        ['gvars'] = { { 'one', 1 }, { 'Two', 2 }, { 'THREE', 3 } },
      }

      local with_all = {
        ['regs'] = with_regs['regs'],
        ['jumps'] = with_jumps['jumps'],
        ['bufs'] = with_bufs['bufs'],
        ['gvars'] = with_gvars['gvars'],
      }

      call('ctxpush')
      eq(with_all, parse_context(call('ctxget')))
      eq(with_all, parse_context(call('ctxget', 0)))

      call('ctxpush', { 'gvars' })
      eq(with_gvars, parse_context(call('ctxget')))
      eq(with_gvars, parse_context(call('ctxget', 0)))
      eq(with_all, parse_context(call('ctxget', 1)))

      call('ctxpush', { 'bufs' })
      eq(with_bufs, parse_context(call('ctxget')))
      eq(with_bufs, parse_context(call('ctxget', 0)))
      eq(with_gvars, parse_context(call('ctxget', 1)))
      eq(with_all, parse_context(call('ctxget', 2)))

      call('ctxpush', { 'jumps' })
      eq(with_jumps, parse_context(call('ctxget')))
      eq(with_jumps, parse_context(call('ctxget', 0)))
      eq(with_bufs, parse_context(call('ctxget', 1)))
      eq(with_gvars, parse_context(call('ctxget', 2)))
      eq(with_all, parse_context(call('ctxget', 3)))

      call('ctxpush', { 'regs' })
      eq(with_regs, parse_context(call('ctxget')))
      eq(with_regs, parse_context(call('ctxget', 0)))
      eq(with_jumps, parse_context(call('ctxget', 1)))
      eq(with_bufs, parse_context(call('ctxget', 2)))
      eq(with_gvars, parse_context(call('ctxget', 3)))
      eq(with_all, parse_context(call('ctxget', 4)))

      call('ctxpop')
      eq(with_jumps, parse_context(call('ctxget')))
      eq(with_jumps, parse_context(call('ctxget', 0)))
      eq(with_bufs, parse_context(call('ctxget', 1)))
      eq(with_gvars, parse_context(call('ctxget', 2)))
      eq(with_all, parse_context(call('ctxget', 3)))

      call('ctxpop')
      eq(with_bufs, parse_context(call('ctxget')))
      eq(with_bufs, parse_context(call('ctxget', 0)))
      eq(with_gvars, parse_context(call('ctxget', 1)))
      eq(with_all, parse_context(call('ctxget', 2)))

      call('ctxpop')
      eq(with_gvars, parse_context(call('ctxget')))
      eq(with_gvars, parse_context(call('ctxget', 0)))
      eq(with_all, parse_context(call('ctxget', 1)))

      call('ctxpop')
      eq(with_all, parse_context(call('ctxget')))
      eq(with_all, parse_context(call('ctxget', 0)))
    end)
  end)

  describe('ctxset()', function()
    it('errors out when index is out of bounds', function()
      eq(outofbounds, pcall_err(call, 'ctxset', { dummy = 1 }))
      call('ctxpush')
      eq(outofbounds, pcall_err(call, 'ctxset', { dummy = 1 }, 1))
      call('ctxpop')
      eq(outofbounds, pcall_err(call, 'ctxset', { dummy = 1 }, 0))
    end)

    it('errors when context dict is invalid', function()
      call('ctxpush')
      eq(
        'Vim:E474: Failed to convert list to msgpack string buffer',
        pcall_err(call, 'ctxset', { regs = { {} }, jumps = { {} } })
      )
    end)

    it('sets context dict at index in context stack', function()
      api.nvim_set_var('one', 1)
      api.nvim_set_var('Two', 2)
      api.nvim_set_var('THREE', 3)
      call('ctxpush')
      local ctx1 = call('ctxget')
      api.nvim_set_var('one', 'a')
      api.nvim_set_var('Two', 'b')
      api.nvim_set_var('THREE', 'c')
      call('ctxpush')
      call('ctxpush')
      local ctx2 = call('ctxget')

      eq({ 'a', 'b', 'c' }, eval('[g:one, g:Two, g:THREE]'))
      call('ctxset', ctx1)
      call('ctxset', ctx2, 2)
      call('ctxpop')
      eq({ 1, 2, 3 }, eval('[g:one, g:Two, g:THREE]'))
      call('ctxpop')
      eq({ 'a', 'b', 'c' }, eval('[g:one, g:Two, g:THREE]'))
      api.nvim_set_var('one', 1.5)
      eq({ 1.5, 'b', 'c' }, eval('[g:one, g:Two, g:THREE]'))
      call('ctxpop')
      eq({ 'a', 'b', 'c' }, eval('[g:one, g:Two, g:THREE]'))
    end)
  end)
end)
