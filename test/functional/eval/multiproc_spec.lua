local helpers = require('test.functional.helpers')(after_each)
local clear, command, eq, eval, next_msg, nvim, source, tbl_flatten =
  helpers.clear, helpers.command, helpers.eq, helpers.eval, helpers.next_msg,
  helpers.nvim, helpers.source, helpers.tbl_flatten

describe('multiproc', function()
  before_each(function()
    clear()
    local channel = nvim('get_api_info')[1]
    nvim('set_var', 'channel', channel)
  end)

  describe('call_async', function()
    it('invokes callback passing it the return value', function()
      source([[
      function! Callback(return_value) abort
        call rpcnotify(g:channel, 'done', a:return_value)
      endfunction
      call call_async('nvim__id', ['multiproc'], {}, 'Callback')
      call call_async('nvim_eval', ['1+2+3'], {}, 'Callback')
      ]])
      eq({'notification', 'done', {'multiproc'}}, next_msg())
      eq({'notification', 'done', {6}}, next_msg())
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
      let jobs = [ call_async('nvim__id', ['first job'], {}),
                 \ call_async('nvim__id', ['second job'], {}),
                 \ call_async('nvim_eval', ['1+2+3'], {}),
                 \ call_async('nvim_eval', ['float2nr(pow(2, 6))'], {}),
                 \ call_async('trim', ['   trim me   '], {}) ]
      ]])
      eq({'first job', 'second job', 6, 64, 'trim me'},
         eval([[map(call_wait(jobs), 'v:val.value')]]))
    end)

    it('returns after callback is invoked', function()
      command(
        [[call call_wait([call_async('nvim__id', [''], {}, 'Callback')])]])
      eq(true, eval('g:callback_done'))
    end)

    it('returns on timeout', function()
      command(
        [[call call_wait([call_async('nvim__id', [''], {}, 'Callback')], 0)]])
      eq(false, eval('g:callback_done'))
    end)
  end)

  describe('call_parallel', function()
    it('works', function()
      source([[
      function! Callback(return_value) abort
        call rpcnotify(g:channel, 'done', sort(a:return_value, 'n'))
      endfunction
      let jobs = call_parallel(4, 'eval',
                             \ [ ['2*1'], ['2*2'], ['2*3'], ['2*4'],
                             \   ['2*5'], ['2*6'], ['2*7'], ['2*8'] ],
                             \ {}, 'Callback')
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
