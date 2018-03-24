local helpers = require('test.functional.helpers')(after_each)
local shada_helpers = require('test.functional.shada.helpers')

local feed = helpers.feed
local eq = helpers.eq
local getreg = helpers.funcs.getreg
local reset, clear = shada_helpers.reset, shada_helpers.clear

-- 'smalldeletethreshold' configures the number of characters 
--  whose yank or deletion causes push into the "1.."9 registers stack.
--  Possible values:
--  * 0 - default behavior (deletions larger than 1 line are considered big)
--  * 1 - any deletion (including x) appears in the "1.."9 registers
--  * N - deletions of N or more characters are considered big
describe("'smalldeletethreshold' option", function()
  before_each(reset)
  after_each(clear)

  it("default behavior", function()
    -- Add some text
    feed('iaaa bbb ccc\nd<Esc>k')

    -- Delete a word, a line and a char
    feed('2dwddx')

    -- Check the registers
    eq(getreg('"'), 'd')
    eq(getreg('1'), 'ccc\n')
    eq(getreg('2'), '')

    -- As you see, 'aaa bbb' is completely lost, which is not good...
  end)
end)
