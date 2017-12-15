local helpers = require('test.functional.helpers')(after_each)
local eq, clear = helpers.eq, helpers.clear
local missing_provider = helpers.missing_provider
local command = helpers.command
local write_file = helpers.write_file
local eval = helpers.eval
local sleep = helpers.sleep
local funcs = helpers.funcs

do
  clear()
  if missing_provider('node') then
    pending(
      "Cannot find the neovim nodejs host. Try :checkhealth",
      function() end)
    return
  end
end

before_each(function()
  clear()
end)

describe('nodejs', function()
  it('can inspect', function()
    eq(1, funcs['provider#node#can_inspect']())
  end)
end)

describe('nodejs host', function()
  it('works', function()
    local fname = 'Xtest-nodejs-hello.js'
    write_file(fname, [[
      const socket = process.env.NVIM_LISTEN_ADDRESS;
      const neovim = require('neovim');
      const nvim = neovim.attach({socket: socket});
      nvim.command('let g:job_out = "hello"');
      nvim.command('call jobstop(g:job_id)');
    ]])
    command('let g:job_id = jobstart(["node", "'..fname..'"])')
    sleep(5000)
    eq('hello', eval('g:job_out'))
    os.remove(fname)
  end)
  it('plugin works', function()
    local fname = 'Xtest-nodejs-hello-plugin.js'
    write_file(fname, [[
      const socket = process.env.NVIM_LISTEN_ADDRESS;
      const neovim = require('neovim');
      const nvim = neovim.attach({socket: socket});

      class TestPlugin {
          hello() {
              this.nvim.command('let g:job_out = "hello-plugin"')
          }
      }

      const PluginClass = neovim.Plugin(TestPlugin);
      const plugin = new PluginClass(nvim);
      plugin.hello();
      nvim.command('call jobstop(g:job_id)');
    ]])
    command('let g:job_id = jobstart(["node", "'..fname..'"])')
    sleep(5000)
    eq('hello-plugin', eval('g:job_out'))
    os.remove(fname)
  end)
end)
