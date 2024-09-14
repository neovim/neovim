local math = require('helpers.math')

plugin.func {
  name = 'Sub',
  func = function(args) 
    return math.sub(unpack(args)) 
  end
}
