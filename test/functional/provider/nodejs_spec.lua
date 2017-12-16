local helpers = require('test.functional.helpers')(after_each)
local eq, clear = helpers.eq, helpers.clear
local missing_provider = helpers.missing_provider
local command = helpers.command
local write_file = helpers.write_file
local eval = helpers.eval
local sleep = helpers.sleep
local funcs = helpers.funcs
local retry = helpers.retry

do
  clear()
  if missing_provider('node') then
    pending(
      "Cannot find the neovim nodejs host. Try :checkhealth",
      function() end)
    return
  end
end

local rplugin_clear_args = {
  env = {NVIM_RPLUGIN_MANIFEST = './rplugin.vim'},
  args = {'--cmd', 'set runtimepath+=test/functional/fixtures'}
}

before_each(function()
  clear(rplugin_clear_args)
end)

after_each(function()
  os.remove('rplugin.vim')
end)

describe('nodejs', function()
  it('can inspect', function()
    eq(1, funcs['provider#node#can_inspect']())
  end)
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
    retry(nil, 1000, function() eq('hello', eval('g:job_out')) end)
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
    retry(nil, 1000, function() eq('hello-plugin', eval('g:job_out')) end)
  end)

  it('rplugin works', function()
    if helpers.pending_win32(pending) then return end
    command('UpdateRemotePlugins')
    clear(rplugin_clear_args)
    command('SetFooBar')
    retry(nil, 1000, function() eq('foobar', eval('g:foobar')) end)
  end)
end)
