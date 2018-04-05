local helpers = require('test.functional.helpers')(after_each)
local clear, wait, eq, feed, nvim = helpers.clear, helpers.wait, helpers.eq, helpers.feed, helpers.nvim

describe("writedelay option changes", function()

  before_each(function()
    clear()
  end)

  it('wd sets to 0 on <C-C><C-C>', function()
    nvim('set_option', 'writedelay', 10)
    feed('<C-C><C-C>')
    wait()
    eq(0, nvim('get_option','writedelay'))
  end)
end)
