
local helpers = require 'test.unit.helpers'
local main = helpers.cimport(
  './src/nvim/main.h',
  './src/nvim/os/event.h',
  './src/nvim/term.h'
)

helpers.vim_init()
-- termcapinit requires event_early init
main.event_early_init()

describe('termcapinit', function()

  it('works with ansi', function()
    main.termcapinit(helpers.to_cstr('ansi'))
  end)

  it('works with unknown type', function()
    main.termcapinit(helpers.to_cstr('XXX'))
  end)
end)
