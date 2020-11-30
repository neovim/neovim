local helpers = require('test.functional.helpers')(after_each)

local clear, eq = helpers.clear, helpers.eq
local nvim = helpers.nvim
local meths = helpers.meths

describe('nvim_get_autocmds', function()
  before_each(function()
    clear()

    -- Should probably populate with a set of autocmds here...
    nvim('exec', "autocmd BufWritePost * :echo 'hello'", false)
    nvim('exec', "autocmd BufWritePost * ++once :echo 'only once'", false)

    -- Should add some in some different groups, etc.
  end)

  it('should return all autocmds when not filtered', function()
    eq({}, meths.get_autocmds({}))
  end)

  it('should return autocmds for a particular event', function()
  end)

  it('should return autocmds for a particular group', function()
  end)

  it('should return autocmds for both a group and an event', function()
  end)
end)
