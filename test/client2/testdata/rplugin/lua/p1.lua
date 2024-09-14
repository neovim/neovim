-- Test import local to the plugin
local math = require('helpers.math')

-- Test global variable scope
example_globar_var = 'global'

plugin.command {
  name = 'Hello',
  func = function() nvim.command('echo "World"') end
}

plugin.func {
  name = 'Add',
  func = function(args) 
    return math.add(unpack(args)) 
  end
}
