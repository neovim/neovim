-- Test for :execute, :while and :if

local n = require('test.functional.testnvim')()

local clear = n.clear
local expect = n.expect
local source = n.source
local command = n.command

describe(':execute, :while and :if', function()
  setup(clear)

  it('is working', function()
    source([[
      let i = 0
      while i < 12
        let i = i + 1
        execute "normal o" . i . "\033"
        if i % 2
          normal Ax
          if i == 9
            break
          endif
          if i == 5
            continue
          else
            let j = 9
            while j > 0
              execute "normal" j . "a" . j . "\x1b"
              let j = j - 1
            endwhile
          endif
        endif
        if i == 9
          execute "normal Az\033"
        endif
      endwhile
      unlet i j
    ]])

    -- Remove empty line
    command('1d')

    -- Assert buffer contents.
    expect([[
      1x999999999888888887777777666666555554444333221
      2
      3x999999999888888887777777666666555554444333221
      4
      5x
      6
      7x999999999888888887777777666666555554444333221
      8
      9x]])
  end)
end)
