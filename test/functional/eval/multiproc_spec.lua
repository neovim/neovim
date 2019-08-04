local helpers = require('test.functional.helpers')(after_each)
local call = helpers.call
local clear = helpers.clear
local command = helpers.command
local eq = helpers.eq
local eval = helpers.eval
local expect_err = helpers.expect_err
local expect_msg_seq = helpers.expect_msg_seq
local feed = helpers.feed
local feed_command = helpers.feed_command
local matches = helpers.matches
local next_msg = helpers.next_msg
local nvim = helpers.nvim
local parse_context = helpers.parse_context
local source = helpers.source
local tbl_flatten = helpers.tbl_flatten

describe('multiproc', function()
  before_each(function()
    clear()
    local channel = nvim('get_api_info')[1]
    nvim('set_var', 'channel', channel)
  end)

  describe('call_async', function()
    before_each(function()
      source([[
      function! Callback(return_value) abort
        call rpcnotify(g:channel, 'done', a:return_value)
      endfunction
      ]])
    end)

    it('does not work in sandbox', function()
      expect_err('Failed to spawn job for async call',
                 command, [[sandbox call call_async('nvim__id', [1])]])
    end)

    it('invokes callback passing it the return value', function()
      call('call_async', 'nvim__id', {'multiproc'}, {done = 'Callback'})
      call('call_async', 'nvim_eval', {'1+2+3'}, {done = 'Callback'})
      expect_msg_seq(
        { {'notification', 'done', {'multiproc'}},
          {'notification', 'done', {6}} },
        { {'notification', 'done', {6}},
          {'notification', 'done', {'multiproc'}} }
      )
    end)

    it('reports errors from children', function()
      expect_err('multiproc: job 3: Vim:E117: Unknown function: foo',
                 call, 'call_wait', {call('call_async', 'foo', {})})
    end)

    it('loads passed context properly', function()
      feed('i1<cr>2<cr>3<c-[>ddddddqahjklquuu')
      feed('gg')
      feed('G')
      command('edit! BUF1')
      command('edit BUF2')
      nvim('set_var', 'one', 1)
      nvim('set_var', 'Two', 2)
      nvim('set_var', 'THREE', 3)

      local ctx_items = {'regs', 'jumps', 'buflist', 'gvars'}
      local sent_ctx = nvim('get_context', ctx_items)
      call('call_async', 'nvim_get_context', {ctx_items},
           {done = 'Callback', context = sent_ctx})
      local msg = next_msg()
      msg[3][1] = parse_context(msg[3][1])
      eq({'notification', 'done', {parse_context(sent_ctx)}}, msg)
    end)
  end)

  describe('call_wait', function()
    before_each(function()
      source([[
      let g:callback_done = v:false
      function! Callback(return_value) abort
        sleep 250m
        let g:callback_done = v:true
      endfunction
      ]])
    end)

    it('returns async call results', function()
      source([[
      let jobs = [ call_async('nvim__id', ['first job']),
                 \ call_async('nvim__id', ['second job']),
                 \ call_async('nvim_eval', ['1+2+3']),
                 \ call_async('nvim_eval', ['float2nr(pow(2, 6))']),
                 \ call_async('trim', ['   trim me   ']) ]
      ]])
      eq({'first job', 'second job', 6, 64, 'trim me'},
         eval([[map(call_wait(jobs), 'v:val.value')]]))
    end)

    it('returns after callback is invoked', function()
      call('call_wait', {call('call_async', 'nvim__id', {''}, {done = 'Callback'})})
      eq(true, eval('g:callback_done'))
    end)

    it('returns on timeout', function()
      call('call_wait', {call('call_async', 'nvim_command', {'5sleep'},
           {done = 'Callback'})}, 0)
      eq(false, eval('g:callback_done'))
    end)
  end)

  describe('call_parallel', function()
    it('works', function()
      source([[
      function! Callback(return_value) abort
        call rpcnotify(g:channel, 'done', sort(a:return_value, 'n'))
      endfunction
      let jobs = call_parallel('eval',
                             \ [ ['2*1'], ['2*2'], ['2*3'], ['2*4'],
                             \   ['2*5'], ['2*6'], ['2*7'], ['2*8'] ],
                             \ {'done': 'Callback', 'count': 4})
      ]])
      local wait_result = tbl_flatten(eval([[map(call_wait(jobs), 'v:val.value')]]))
      table.sort(wait_result)
      local expected = {2, 4, 6, 8, 10, 12, 14, 16}
      eq({3, 4, 5, 6}, eval('jobs'))
      eq({'notification', 'done', {expected}}, next_msg())
      eq(expected, wait_result)
    end)

    it('reports errors from children', function()
      feed_command([=[call call_wait(call_parallel('foo', [[], []]))]=])
      feed('<CR>')
      matches('multiproc: job [3-4]: Vim:E117: Unknown function: foo\n'..
              'multiproc: job [3-4]: Vim:E117: Unknown function: foo',
              nvim('command_output', 'messages'))
    end)

    it('errors out on invalid opt values', function()
      feed_command([=[call call_parallel('foo', [[], []], {'done':{}})]=])
      feed('<CR>')
      eq('E921: Invalid callback argument\n'..
         'E475: Invalid value for argument opts: '..
         "value of 'done' should be a function",
         nvim('command_output', 'messages'))
      expect_err('E475: Invalid value for argument opts: '..
                 "value of 'context' should be a dictionary",
                 call, 'call_parallel', 'nvim__id', {'Neovim'}, {context = 1})
      expect_err('E475: Invalid value for argument opts: '..
                 "value of 'count' should be a positive number",
                 call, 'call_parallel', 'nvim__id', {'Neovim'}, {count = 'foo'})
      expect_err('E475: Invalid value for argument opts: '..
                 "value of 'count' should be a positive number",
                 call, 'call_parallel', 'nvim__id', {'Neovim'}, {count = 0})
      expect_err('E475: Invalid value for argument opts: '..
                 "value of 'count' should be a positive number",
                 call, 'call_parallel', 'nvim__id', {'Neovim'}, {count = -1})
    end)
  end)

  it('supports user-defined functions', function()
    nvim('set_var', 'A',  { { -1,  0,  0,  0 },
                            {  0, -1,  0,  0 },
                            {  0,  0, -1,  0 },
                            {  0,  0,  0, -1 } })

    nvim('set_var', 'B', { { 1, 2, 3, 4 },
                           { 5, 6, 7, 8 },
                           { 1, 2, 3, 4 },
                           { 5, 6, 7, 8 } })

    source([[
    function CalculateElement(i, j)
      let value = 0
      let b_idx = 0
      for a in g:A[a:i]
        let value += a * g:B[b_idx][a:j]
        let b_idx += 1
      endfor
      return [a:i, a:j, value]
    endfunction
    ]])

    -- Prepare arguments and result (all zeros)
    local result = {}
    local indices = {}
    for i = 0,3 do
      table.insert(result, {})
      for j = 0,3 do
        table.insert(result[i+1], 0)
        table.insert(indices, {i, j})
      end
    end
    nvim('set_var', 'Result', result)

    source([[
    function Retrieve(r)
      for e in a:r
        let g:Result[ e[0] ][ e[1] ] = e[2]
      endfor
    endfunction
    ]])

    local jobs = call('call_parallel', 'CalculateElement', indices,
                      { count = 2,
                        done = 'Retrieve',
                        context = nvim('get_context', {'gvars'})})
    call('call_wait', jobs)
    eq({ { -1, -2, -3, -4 },
         { -5, -6, -7, -8 },
         { -1, -2, -3, -4 },
         { -5, -6, -7, -8 } }, nvim('get_var', 'Result'))
  end)

  it('supports script functions', function()
    source([[
    function s:greet(name)
      return 'Hello, '.a:name.'!'
    endfunction

    function s:retrieve(r)
      let g:r = a:r
    endfunction

    call call_wait(
    \ [call_async('s:greet', ['Neovim'], { 'done': 's:retrieve' })])
    ]])

    eq('Hello, Neovim!', nvim('get_var', 'r'))
  end)

  it('supports Funcrefs', function()
    source([[
    function s:greet(name)
      return 'Hello, '.a:name.'!'
    endfunction

    function Greet(name)
      return 'Hello, '.a:name.'!'
    endfunction

    function s:retrieve(r)
      call add(g:r, a:r)
    endfunction

    let g:r = []

    call call_wait([
    \ call_async(funcref('s:greet'), ['Neovim'], { 'done': 's:retrieve' }),
    \ call_async(funcref('Greet'),   ['Neovim'], { 'done': 's:retrieve' })])
    ]])

    eq({'Hello, Neovim!', 'Hello, Neovim!'}, nvim('get_var', 'r'))
  end)

  it('supports lambda expressions', function()
    source([[
    let g:r = call_wait([call_async({ name -> 'Hi, '.name.'!' }, ['Neovim'])])
    ]])
    eq('Hi, Neovim!', nvim('get_var', 'r')[1].value)
  end)
end)
