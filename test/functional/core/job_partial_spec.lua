local helpers = require('test.functional.helpers')(after_each)
local clear, eq, next_msg, nvim, source = helpers.clear, helpers.eq,
  helpers.next_message, helpers.nvim, helpers.source

describe('jobs with partials', function()
  local channel

  before_each(function()
    clear()
    if helpers.os_name() == 'windows' then
      helpers.set_shell_powershell()
    end
    channel = nvim('get_api_info')[1]
    nvim('set_var', 'channel', channel)
  end)

  it('works correctly', function()
    source([[
    function PrintArgs(a1, a2, id, data, event)
      " Windows: Remove ^M char.
      let normalized = map(a:data, 'substitute(v:val, "\r", "", "g")')
      call rpcnotify(g:channel, '1', a:a1,  a:a2, normalized, a:event)
    endfunction
    let Callback = function('PrintArgs', ["foo", "bar"])
    let g:job_opts = {'on_stdout': Callback}
    call jobstart('echo "some text"', g:job_opts)
    ]])
    eq({'notification', '1', {'foo', 'bar', {'some text', ''}, 'stdout'}}, next_msg())
  end)
end)
