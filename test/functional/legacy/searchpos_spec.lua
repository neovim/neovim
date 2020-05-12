local helpers = require('test.functional.helpers')(after_each)
local call = helpers.call
local clear = helpers.clear
local command = helpers.command
local eq = helpers.eq
local eval = helpers.eval
local insert = helpers.insert

describe('searchpos', function()
  before_each(clear)

  it('is working', function()
    insert([[
      1a3
      123xyz]])

    call('cursor', 1, 1)
    eq({1, 1, 2}, eval([[searchpos('\%(\([a-z]\)\|\_.\)\{-}xyz', 'pcW')]]))
    call('cursor', 1, 2)
    eq({2, 1, 1}, eval([[searchpos('\%(\([a-z]\)\|\_.\)\{-}xyz', 'pcW')]]))

    command('set cpo-=c')
    call('cursor', 1, 2)
    eq({1, 2, 2}, eval([[searchpos('\%(\([a-z]\)\|\_.\)\{-}xyz', 'pcW')]]))
    call('cursor', 1, 3)
    eq({1, 3, 1}, eval([[searchpos('\%(\([a-z]\)\|\_.\)\{-}xyz', 'pcW')]]))

    -- Now with \zs, first match is in column 0, "a" is matched.
    call('cursor', 1, 3)
    eq({2, 4, 2}, eval([[searchpos('\%(\([a-z]\)\|\_.\)\{-}\zsxyz', 'pcW')]]))
    -- With z flag start at cursor column, don't see the "a".
    call('cursor', 1, 3)
    eq({2, 4, 1}, eval([[searchpos('\%(\([a-z]\)\|\_.\)\{-}\zsxyz', 'pcWz')]]))
  end)
end)
