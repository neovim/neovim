local helpers = require('test.functional.helpers')(after_each)
local call = helpers.call
local clear = helpers.clear
local command = helpers.command
local eq = helpers.eq
local eval = helpers.eval
local expect_msg_seq = helpers.expect_msg_seq
local next_msg = helpers.next_msg
local nvim = helpers.nvim
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
  end)
end)
