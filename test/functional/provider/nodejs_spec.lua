local helpers = require('test.functional.helpers')(after_each)
local eq, clear = helpers.eq, helpers.clear
local missing_provider = helpers.missing_provider
local command = helpers.command
local write_file = helpers.write_file
local eval = helpers.eval
local retry = helpers.retry

do
  clear()
  if missing_provider('node') then
    pending("Missing nodejs host, or nodejs version is too old.", function()end)
    return
  end
end

before_each(function()
  clear()
  command([[let $NODE_PATH = get(split(system('npm root -g'), "\n"), 0, '')]])
end)

describe('nodejs host', function()
  teardown(function ()
    os.remove('Xtest-nodejs-hello.js')
    os.remove('Xtest-nodejs-hello-plugin.js')
  end)

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
    retry(nil, 2000, function() eq('hello', eval('g:job_out')) end)
  end)
  it('plugin works', function()
    local fname = 'Xtest-nodejs-hello-plugin.js'
    write_file(fname, [[
      const socket = process.env.NVIM_LISTEN_ADDRESS;
      const neovim = require('neovim');
      const nvim = neovim.attach({socket: socket});

      class TestPlugin {
        hello() {
          this.nvim.command('let g:job_out = "hello-plugin"');
        }
      }
      const PluginClass = neovim.Plugin(TestPlugin);
      const plugin = new neovim.NvimPlugin(null, PluginClass, nvim);
      plugin.instance.hello();
    ]])
    command('let g:job_id = jobstart(["node", "'..fname..'"])')
    retry(nil, 2000, function() eq('hello-plugin', eval('g:job_out')) end)
  end)
end)
