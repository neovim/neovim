-- Tests for adjusting window and contents

local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')

local eval, clear, command = helpers.eval, helpers.clear, helpers.command
local eq, neq = helpers.eq, helpers.neq
local insert = helpers.insert
local redir_exec = helpers.redir_exec

describe('063: Test for ":match", "matchadd()" and related functions', function()
  setup(clear)

  it('is working', function()
    local screen = Screen.new(40, 5)
    screen:attach()
    screen:set_default_attr_ids({
      [0] = {bold = true, foreground = Screen.colors.Blue},
      [1] = {background = Screen.colors.Red},
    })

    -- Check that "matcharg()" returns the correct group and pattern if a match
    -- is defined.
    command("highlight MyGroup1 term=bold ctermbg=red guibg=red")
    command("highlight MyGroup2 term=italic ctermbg=green guibg=green")
    command("highlight MyGroup3 term=underline ctermbg=blue guibg=blue")
    command("match MyGroup1 /TODO/")
    command("2match MyGroup2 /FIXME/")
    command("3match MyGroup3 /XXX/")
    eq({'MyGroup1', 'TODO'}, eval('matcharg(1)'))
    eq({'MyGroup2', 'FIXME'}, eval('matcharg(2)'))
    eq({'MyGroup3', 'XXX'}, eval('matcharg(3)'))

    -- Check that "matcharg()" returns an empty list if the argument is not 1,
    -- 2 or 3 (only 0 and 4 are tested).
    eq({}, eval('matcharg(0)'))
    eq({}, eval('matcharg(4)'))

    -- Check that "matcharg()" returns ['', ''] if a match is not defined.
    command("match")
    command("2match")
    command("3match")
    eq({'', ''}, eval('matcharg(1)'))
    eq({'', ''}, eval('matcharg(2)'))
    eq({'', ''}, eval('matcharg(3)'))

    -- Check that "matchadd()" and "getmatches()" agree on added matches and
    -- that default values apply.
    command("let m1 = matchadd('MyGroup1', 'TODO')")
    command("let m2 = matchadd('MyGroup2', 'FIXME', 42)")
    command("let m3 = matchadd('MyGroup3', 'XXX', 60, 17)")
    eq({{group = 'MyGroup1', pattern = 'TODO', priority = 10, id = 4},
        {group = 'MyGroup2', pattern = 'FIXME', priority = 42, id = 5},
        {group = 'MyGroup3', pattern = 'XXX', priority = 60, id = 17}},
      eval('getmatches()'))

    -- Check that "matchdelete()" deletes the matches defined in the previous
    -- test correctly.
    command("call matchdelete(m1)")
    command("call matchdelete(m2)")
    command("call matchdelete(m3)")
    eq({}, eval('getmatches()'))

    --- Check that "matchdelete()" returns 0 if successful and otherwise -1.
    command("let m = matchadd('MyGroup1', 'TODO')")
    eq(0, eval('matchdelete(m)'))

    -- matchdelete throws error and returns -1 on failure
    neq(true, pcall(function() eval('matchdelete(42)') end))
    eq('\nE803: ID not found: 42',
       redir_exec("let r2 = matchdelete(42)"))
    eq(-1, eval('r2'))

    -- Check that "clearmatches()" clears all matches defined by ":match" and
    -- "matchadd()".
    command("let m1 = matchadd('MyGroup1', 'TODO')")
    command("let m2 = matchadd('MyGroup2', 'FIXME', 42)")
    command("let m3 = matchadd('MyGroup3', 'XXX', 60, 17)")
    command("match MyGroup1 /COFFEE/")
    command("2match MyGroup2 /HUMPPA/")
    command("3match MyGroup3 /VIM/")
    command("call clearmatches()")
    eq({}, eval('getmatches()'))

    -- Check that "setmatches()" restores a list of matches saved by
    -- "getmatches()" without changes. (Matches with equal priority must also
    -- remain in the same order.)
    command("let m1 = matchadd('MyGroup1', 'TODO')")
    command("let m2 = matchadd('MyGroup2', 'FIXME', 42)")
    command("let m3 = matchadd('MyGroup3', 'XXX', 60, 17)")
    command("match MyGroup1 /COFFEE/")
    command("2match MyGroup2 /HUMPPA/")
    command("3match MyGroup3 /VIM/")
    command("let ml = getmatches()")
    local ml = eval("ml")
    command("call clearmatches()")
    command("call setmatches(ml)")
    eq(ml, eval('getmatches()'))

    -- Check that "setmatches()" can correctly restore the matches from matchaddpos()
    command("call clearmatches()")
    command("call setmatches(ml)")
    eq(ml, eval('getmatches()'))

    -- Check that "setmatches()" will not add two matches with the same ID. The
    -- expected behaviour (for now) is to add the first match but not the
    -- second and to return -1.
    eq('\nE801: ID already taken: 1',
       redir_exec("let r1 = setmatches([{'group': 'MyGroup1', 'pattern': 'TODO', 'priority': 10, 'id': 1}, {'group': 'MyGroup2', 'pattern': 'FIXME', 'priority': 10, 'id': 1}])"))
    eq(-1, eval("r1"))
    eq({{group = 'MyGroup1', pattern = 'TODO', priority = 10, id = 1}}, eval('getmatches()'))

    -- Check that "setmatches()" returns 0 if successful and otherwise -1.
    -- (A range of valid and invalid input values are tried out to generate the
    -- return values.)
    eq(0,eval("setmatches([])"))
    eq(0,eval("setmatches([{'group': 'MyGroup1', 'pattern': 'TODO', 'priority': 10, 'id': 1}])"))
    command("call clearmatches()")
    eq('\nE714: List required', redir_exec("let rf1 = setmatches(0)"))
    eq(-1, eval('rf1'))
    eq('\nE474: List item 0 is either not a dictionary or an empty one',
       redir_exec("let rf2 = setmatches([0])"))
    eq(-1, eval('rf2'))
    eq('\nE474: List item 0 is missing one of the required keys',
       redir_exec("let rf3 = setmatches([{'wrong key': 'wrong value'}])"))
    eq(-1, eval('rf3'))

    -- Check that "matchaddpos()" positions matches correctly
    insert('abcdefghijklmnopq')
    command("call matchaddpos('MyGroup1', [[1, 5], [1, 8, 3]], 10, 3)")
    screen:expect([[
      abcd{1:e}fg{1:hij}klmnop^q                       |
      {0:~                                       }|
      {0:~                                       }|
      {0:~                                       }|
                                              |
    ]])

    command("call clearmatches()")
    command("call setline(1, 'abcdΣabcdef')")
    command("call matchaddpos('MyGroup1', [[1, 4, 2], [1, 9, 2]])")
    screen:expect([[
      abc{1:dΣ}ab{1:cd}e^f                             |
      {0:~                                       }|
      {0:~                                       }|
      {0:~                                       }|
                                              |
    ]])
  end)
end)

