expose('require uv once to prevent segfault', function()
  require('luv')
end)

local neovim = require('neovim')
local plugin = require('plugin')

describe('plugin host', function()
  local nvim
  local p1_path = 'testdata/rplugin/lua/p1.lua'
  local p2_path = 'testdata/rplugin/lua/p2.lua'

  setup(function()
    nvim = neovim.new_child('nvim', {'--embed', '-u', 'NONE', '-i', 'NONE'})
  end)

  teardown(function()
    if nvim then
      nvim:close()
    end
  end)

  it('can load scripts', function()
    local host = plugin.new_host(nvim)
    local specs, handlers = host:get_plugin(p1_path):load_script(p1_path)
    assert.are.same({
      {
        name = 'Hello',
        type = 'command',
        sync = true,
        opts = {x = 0},
      },
      {
        name = 'Add',
        type = 'function',
        sync = true,
        opts = {x = 0},
      },
    }, specs)
    assert.is.equal('function', type(handlers[':command:Hello']))
    assert.is.equal('function', type(handlers[':function:Add']))
  end)

  it('works with nvim', function()
    local host = plugin.new_host(nvim)
    for _, p in pairs{p1_path, p2_path} do
      local specs, _ = host:get_plugin(p):load_script(p)
      nvim:call('remote#host#RegisterPlugin', 'luaX', p, specs)
    end

    local channel = nvim:get_api_info()[1]
    nvim:call('remote#host#Register', 'luaX', '*.lua', channel)

    assert.is.equal(3, nvim:call('Add', 1, 2))
    assert.is.equal(-3, nvim:call('Sub', 2, 1))

  end)

  it('isolates global variables to plugin', function()
    local host = plugin.new_host(nvim)
    local p1 = host:get_plugin(p1_path)
    p1:load_script(p1_path)

    -- p1 creates the global
    assert.is.equal('global', p1.env.example_globar_var)

    local p2 = host:get_plugin(p2_path)
    p2:load_script(p2_path)

    -- p2 should see global created by p1
    assert.is.equal('global', p1.env.example_globar_var)
  end)

end)
