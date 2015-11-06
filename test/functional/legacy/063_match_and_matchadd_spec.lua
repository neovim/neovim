-- Tests for adjusting window and contents

local helpers = require('test.functional.helpers')
local Screen = require('test.functional.ui.screen')
local feed, insert, source = helpers.feed, helpers.insert, helpers.source
local eval, clear, execute, expect = helpers.eval, helpers.clear, helpers.execute
local expect, eq, neq = helpers.expect, helpers.eq, helpers.neq
local command = helpers.command

describe('063: Test for ":match", "matchadd()" and related functions', function()
  setup(clear)

  it('is working', function()
    local screen = Screen.new(40, 5)
    screen:attach()

    -- Check that "matcharg()" returns the correct group and pattern if a match
    -- is defined.
    execute("highlight MyGroup1 term=bold ctermbg=red guibg=red")
    execute("highlight MyGroup2 term=italic ctermbg=green guibg=green")
    execute("highlight MyGroup3 term=underline ctermbg=blue guibg=blue")
    execute("match MyGroup1 /TODO/")
    execute("2match MyGroup2 /FIXME/")
    execute("3match MyGroup3 /XXX/")
    eq({'MyGroup1', 'TODO'}, eval('matcharg(1)'))
    eq({'MyGroup2', 'FIXME'}, eval('matcharg(2)'))
    eq({'MyGroup3', 'XXX'}, eval('matcharg(3)'))

    -- Check that "matcharg()" returns an empty list if the argument is not 1,
    -- 2 or 3 (only 0 and 4 are tested).
    eq({}, eval('matcharg(0)'))
    eq({}, eval('matcharg(4)'))

    -- Check that "matcharg()" returns ['', ''] if a match is not defined.
    execute("match")
    execute("2match")
    execute("3match")
    eq({'', ''}, eval('matcharg(1)'))
    eq({'', ''}, eval('matcharg(2)'))
    eq({'', ''}, eval('matcharg(3)'))

    -- Check that "matchadd()" and "getmatches()" agree on added matches and
    -- that default values apply.
    execute("let m1 = matchadd('MyGroup1', 'TODO')")
    execute("let m2 = matchadd('MyGroup2', 'FIXME', 42)")
    execute("let m3 = matchadd('MyGroup3', 'XXX', 60, 17)")
    eq({{group = 'MyGroup1', pattern = 'TODO', priority = 10, id = 4},
        {group = 'MyGroup2', pattern = 'FIXME', priority = 42, id = 5},
        {group = 'MyGroup3', pattern = 'XXX', priority = 60, id = 17}},
      eval('getmatches()'))

    -- Check that "matchdelete()" deletes the matches defined in the previous
    -- test correctly.
    execute("call matchdelete(m1)")
    execute("call matchdelete(m2)")
    execute("call matchdelete(m3)")
    eq({}, eval('getmatches()'))

    --- Check that "matchdelete()" returns 0 if successful and otherwise -1.
    execute("let m = matchadd('MyGroup1', 'TODO')")
    eq(0, eval('matchdelete(m)'))

    -- matchdelete throws error and returns -1 on failure
    neq(true, pcall(function() eval('matchdelete(42)') end))
    execute("let r2 = matchdelete(42)")
    eq(-1, eval('r2'))

    -- Check that "clearmatches()" clears all matches defined by ":match" and
    -- "matchadd()".
    execute("let m1 = matchadd('MyGroup1', 'TODO')")
    execute("let m2 = matchadd('MyGroup2', 'FIXME', 42)")
    execute("let m3 = matchadd('MyGroup3', 'XXX', 60, 17)")
    execute("match MyGroup1 /COFFEE/")
    execute("2match MyGroup2 /HUMPPA/")
    execute("3match MyGroup3 /VIM/")
    execute("call clearmatches()")
    eq({}, eval('getmatches()'))

    -- Check that "setmatches()" restores a list of matches saved by
    -- "getmatches()" without changes. (Matches with equal priority must also
    -- remain in the same order.)
    execute("let m1 = matchadd('MyGroup1', 'TODO')")
    execute("let m2 = matchadd('MyGroup2', 'FIXME', 42)")
    execute("let m3 = matchadd('MyGroup3', 'XXX', 60, 17)")
    execute("match MyGroup1 /COFFEE/")
    execute("2match MyGroup2 /HUMPPA/")
    execute("3match MyGroup3 /VIM/")
    execute("let ml = getmatches()")
    ml = eval("ml")
    execute("call clearmatches()")
    execute("call setmatches(ml)")
    eq(ml, eval('getmatches()'))
    execute("call clearmatches()")

    -- Check that "setmatches()" will not add two matches with the same ID. The
    -- expected behaviour (for now) is to add the first match but not the
    -- second and to return 0 (even though it is a matter of debate whether
    -- this can be considered successful behaviour).
    execute("let r1 = setmatches([{'group': 'MyGroup1', 'pattern': 'TODO', 'priority': 10, 'id': 1}, {'group': 'MyGroup2', 'pattern': 'FIXME', 'priority': 10, 'id': 1}])")
    feed("<cr>")
    eq(0, eval("r1"))
    eq({{group = 'MyGroup1', pattern = 'TODO', priority = 10, id = 1}}, eval('getmatches()'))

    -- Check that "setmatches()" returns 0 if successful and otherwise -1.
    -- (A range of valid and invalid input values are tried out to generate the
    -- return values.)
    eq(0,eval("setmatches([])"))
    eq(0,eval("setmatches([{'group': 'MyGroup1', 'pattern': 'TODO', 'priority': 10, 'id': 1}])"))
    execute("call clearmatches()")
    execute("let rf1 = setmatches(0)")
    eq(-1, eval('rf1'))
    execute("let rf2 = setmatches([0])")
    eq(-1, eval('rf2'))
    execute("let rf3 = setmatches([{'wrong key': 'wrong value'}])")
    feed("<cr>")
    eq(-1, eval('rf3'))

    -- Check that "matchaddpos()" positions matches correctly
    insert('abcdefghijklmnopq')
    execute("call matchaddpos('MyGroup1', [[1, 5], [1, 8, 3]], 10, 3)")
    screen:expect([[
      abcd{1:e}fg{1:hij}klmnop^q                       |
      ~                                       |
      ~                                       |
      ~                                       |
                                              |
    ]], {[1] = {background = Screen.colors.Red}}, {{bold = true, foreground = Screen.colors.Blue}})

    execute("call clearmatches()")
    execute("call setline(1, 'abcdΣabcdef')")
    execute("call matchaddpos('MyGroup1', [[1, 4, 2], [1, 9, 2]])")
    screen:expect([[
      abc{1:dΣ}ab{1:cd}e^f                             |
      ~                                       |
      ~                                       |
      ~                                       |
                                              |
    ]],{[1] = {background = Screen.colors.Red}}, {{bold = true, foreground = Screen.colors.Blue}})
  end)
end)

