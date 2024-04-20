local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local eq, clear = t.eq, n.clear
local missing_provider = n.missing_provider
local command = n.command
local write_file = t.write_file
local eval = n.eval
local retry = t.retry

do
  clear()
  local reason = missing_provider('node')
  if reason then
    pending(
      string.format('Missing nodejs host, or nodejs version is too old (%s)', reason),
      function() end
    )
    return
  end
end

before_each(function()
  clear()
end)

describe('nodejs host', function()
  teardown(function()
    os.remove('Xtest-nodejs-hello.js')
    os.remove('Xtest-nodejs-hello-plugin.js')
  end)

  it('works', function()
    local fname = 'Xtest-nodejs-hello.js'
    write_file(
      fname,
      [[
      const neovim = require('neovim');
      const nvim = neovim.attach({socket: process.env.NVIM});
      nvim.command('let g:job_out = "hello"');
    ]]
    )
    command('let g:job_id = jobstart(["node", "' .. fname .. '"])')
    retry(nil, 3000, function()
      eq('hello', eval('g:job_out'))
    end)
  end)
  it('plugin works', function()
    local fname = 'Xtest-nodejs-hello-plugin.js'
    write_file(
      fname,
      [[
      const neovim = require('neovim');
      const nvim = neovim.attach({socket: process.env.NVIM});

      class TestPlugin {
        hello() {
          this.nvim.command('let g:job_out = "hello-plugin"');
        }
      }
      const PluginClass = neovim.Plugin(TestPlugin);
      const plugin = new neovim.NvimPlugin(null, PluginClass, nvim);
      plugin.instance.hello();
    ]]
    )
    command('let g:job_id = jobstart(["node", "' .. fname .. '"])')
    retry(nil, 3000, function()
      eq('hello-plugin', eval('g:job_out'))
    end)
  end)
end)
