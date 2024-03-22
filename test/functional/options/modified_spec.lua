local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local eq = helpers.eq
local api = helpers.api

describe("'modified'", function()
  before_each(function()
    clear()
  end)

  it("can be unset after changing 'fileformat'", function()
    for _, ff in ipairs({ 'unix', 'dos', 'mac' }) do
      api.nvim_set_option_value('fileformat', ff, {})
      api.nvim_set_option_value('modified', false, {})
      eq(false, api.nvim_get_option_value('modified', {}), 'fileformat=' .. ff)
    end
  end)
end)
