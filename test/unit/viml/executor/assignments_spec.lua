describe(':let assignments', function()
  local ito, itoe
  do
    local _obj_0 = require('test.unit.viml.executor.helpers')(it)
    ito = _obj_0.ito
    itoe = _obj_0.itoe
  end
  ito('Assigns single value to default scope', [[
    let a = 1
    echo a
    unlet a
  ]], {1})
  ito('Assigns single value to g: (default) scope', [[
    let g:a = 1
    echo a
    unlet g:a
  ]], {1})
  ito('Assigns single value to g: scope', [[
    let g:a = 1
    echo g:a
    unlet g:a
  ]], {1})
  ito('Handles list assignments', [[
    let [a, b, c] = [1, 2, 3]
    echo a
    echo b
    echo c
    unlet a b c
  ]], {1, 2, 3})
  ito('Handles rest list assignments', [[
    let [a, b; c] = [1, 2, 3, 4]
    echo a
    echo b
    echo c
    let [a, b; c] = [1, 2]
    echo c
    let [a, b; c] = [1, 2, 3, 4, 5]
    echo c
    let [a, b; c] = [1, 2, 3]
    echo c
    unlet a b c
  ]], {1, 2, {3, 4}, {_t='list'}, {3, 4, 5}, {3}})
  itoe('Fails to do list assignments for lists of different length', {
    'let [a, b] = [1, 2, 3]',
    'let [a, b] = []',
    'let [a, b] = [1]',
    'let [a; b] = []',
    'echo a',
    'echo b',
  }, {
    'Vim(let):E688: More targets than List items',
    'Vim(let):E687: Less targets than List items',
    'Vim(let):E687: Less targets than List items',
    'Vim(let):E687: Less targets than List items',
    'Vim(echo):E121: Undefined variable: a',
    'Vim(echo):E121: Undefined variable: b',
  })
  -- XXX Incompatible behavior
  ito('Allows changing type of the variable', [[
    let a = 1
    echo a
    let a = []
    echo a
    unlet a
  ]], {1, {_t='list'}})
end)

describe('Curly braces names', function()
  local ito, itoe
  do
    local _obj_0 = require('test.unit.viml.executor.helpers')(it)
    ito = _obj_0.ito
    itoe = _obj_0.itoe
  end
  ito('work with :let', [[
    let {"abc"} = 1
    let g:{"d"}{"e"}{"f"} = 2
    let {"g:"}g{"h"}i = 3
    let j{"kl"} = 4
    let g:m{"no"} = 5
    let s{"t"."u"} = 6
    echo [abc, g:def, g:ghi, jkl, g:mno, stu]
    unlet abc g:def g:ghi jkl g:mno stu
  ]], {{1, 2, 3, 4, 5, 6}})
  ito('work inside expressions', [[
    let abc = 1
    let g:def = 2
    let g:ghi = 3
    let jkl = 4
    let g:mno = 5
    let stu = 6
    echo [{"abc"}, g:{"de"}{"f"}, {"g:"}gh{"i"}, {"j"}{"kl"}, g:m{"no"}, s{"t"."u"}]
    unlet abc g:def g:ghi jkl g:mno stu
  ]], {{1, 2, 3, 4, 5, 6}})
  ito('work with :unlet', [[
    let abc = 1
    let g:def = 2
    let g:ghi = 3
    let jkl = 4
    let g:mno = 5
    let stu = 6
    echo [abc, g:def, g:ghi, jkl, g:mno, stu]
    unlet {"abc"} g:{"de"}{"f"} {"g:"}gh{"i"} {"j"}{"kl"} g:m{"no"} s{"t"."u"}
    for name in ["abc", "g:def", "g:ghi", "jkl", "g:mno", "stu"]
      try
        echo {name}
      catch
        echo v:exception
      endtry
    endfor
    unlet name
  ]], {
    {1, 2, 3, 4, 5, 6},
    'Vim(echo):E121: Undefined variable: abc',
    'Vim(echo):E121: Undefined variable: def',
    'Vim(echo):E121: Undefined variable: ghi',
    'Vim(echo):E121: Undefined variable: jkl',
    'Vim(echo):E121: Undefined variable: mno',
    'Vim(echo):E121: Undefined variable: stu',
  })
  ito('work with :(un)lockvar', [[
    let abc = 1
    let g:def = 2
    let g:ghi = 3
    let jkl = 4
    let g:mno = 5
    let stu = 6
    echo [abc, g:def, g:ghi, jkl, g:mno, stu]
    lockvar {"abc"}
    lockvar g:{"de"}{"f"}
    lockvar {"g:"}gh{"i"}
    lockvar {"j"}{"kl"}
    lockvar g:m{"no"}
    lockvar s{"t"."u"}
    for name in ["abc", "g:def", "g:ghi", "jkl", "g:mno", "stu"]
      try
        let {name} = -1
      catch
        echo v:exception
      endtry
    endfor
    echo [abc, g:def, g:ghi, jkl, g:mno, stu]
    unlockvar {"abc"}
    unlockvar g:{"de"}{"f"}
    unlockvar {"g:"}gh{"i"}
    unlockvar {"j"}{"kl"}
    unlockvar g:m{"no"}
    unlockvar s{"t"."u"}
    for name in ["abc", "g:def", "g:ghi", "jkl", "g:mno", "stu"]
      try
        let {name} = -1
      catch
        echo v:exception
      endtry
    endfor
    echo [abc, g:def, g:ghi, jkl, g:mno, stu]
    unlet abc g:def g:ghi jkl g:mno stu
    unlet name
  ]], {
    {1, 2, 3, 4, 5, 6},
    'Vim(let):E741: Value is locked: abc',
    'Vim(let):E741: Value is locked: def',
    'Vim(let):E741: Value is locked: ghi',
    'Vim(let):E741: Value is locked: jkl',
    'Vim(let):E741: Value is locked: mno',
    'Vim(let):E741: Value is locked: stu',
    {1, 2, 3, 4, 5, 6},
    {-1, -1, -1, -1, -1, -1},
  })
end)

describe(':let modifying assignments', function()
  local ito, itoe
  do
    local _obj_0 = require('test.unit.viml.executor.helpers')(it)
    ito = _obj_0.ito
    itoe = _obj_0.itoe
  end
  ito('Increments single value from default scope', [[
    let a = 1
    echo a
    let a += 1
    echo a
    unlet a
  ]], {1, 2})
  ito('Increments single value from g: scope', [[
    let g:a = 1
    echo g:a
    let g:a += 1
    echo g:a
    unlet g:a
  ]], {1, 2})
  ito('Decrements single value from default scope', [[
    let a = 1
    echo a
    let a -= 1
    echo a
    unlet a
  ]], {1, 0})
  ito('Decrements single value from g: scope', [[
    let g:a = 1
    echo g:a
    let g:a -= 1
    echo g:a
    unlet g:a
  ]], {1, 0})
  ito('List :let modifying assignments', [[
    let a = 1
    let b = 2
    let l = []
    echo [a, b, string(l)]
    let [a, b] += [3, 5]
    echo [a, b, string(l)]
    let [a; l] += [3, 7]
    echo [a, b, string(l)]
    unlet a b l
  ]], {
    {1, 2, '[]'},
    {4, 7, '[]'},
    {7, 7, '[7]'},
  })
  ito('List :let modifying assignment does not create new variables', [[
    try
      let [a, b] += [1, 2]
    catch
      echo v:exception
    endtry
    let [a, b] += [1, 2]
    try
      echo [a, b]
    catch
      echo v:exception
    endtry
  ]], {
    'Vim(let):E121: Undefined variable: a',
    'Vim(echo):E121: Undefined variable: a',
  })
end)

describe('Slice assignment', function()
  local ito, itoe
  do
    local _obj_0 = require('test.unit.viml.executor.helpers')(it)
    ito = _obj_0.ito
    itoe = _obj_0.itoe
  end
  itoe('Fails to assign to non-List', {
    'let [d, s, n, f, F] = [{}, "", 1, 1.0, function("string")]',
    'let d[1:2] = [1, 2]',
    'let s[1:2] = [1, 2]',
    'let n[1:2] = [1, 2]',
    'let f[1:2] = [1, 2]',
    'let F[1:2] = [1, 2]',
    'unlet d s n f F'
  }, {
    'Vim(let):E719: Cannot use [:] with a Dictionary',
    'Vim(let):E689: Can only index a List or Dictionary',
    'Vim(let):E689: Can only index a List or Dictionary',
    'Vim(let):E689: Can only index a List or Dictionary',
    'Vim(let):E689: Can only index a List or Dictionary',
  })
  itoe('Fails to assign non-List to List slice', {
    'let l = [1, 2, 3]',
    'let l[1:2] = 10',
    'let l[1:2] = "ab"',
    'let l[1:2] = 0.0',
    'let l[1:2] = function("string")',
    'let l[1:2] = {}',
    'unlet l',
  }, {
    'Vim(let):E709: [:] requires a List value',
    'Vim(let):E709: [:] requires a List value',
    'Vim(let):E709: [:] requires a List value',
    'Vim(let):E709: [:] requires a List value',
    'Vim(let):E709: [:] requires a List value',
  })
  itoe('Fails to assign lists with different length', {
    'let l = [1, 2, 3]',
    'let l[1:2] = [2]',
    'let l[1:2] = [2, 3, 4]',
    'unlet l'
  }, {
    'Vim(let):E711: List value has not enough items',
    'Vim(let):E710: List value has too many items',
  })
  ito('Performs slice assignment', [[
    let l = [1, 2, 3, 4, 5]
    echo l
    let l[1:2] = ["2", "3"]
    echo l
    let l[-4:2] = ["-4", "-3"]
    echo l
    unlet l
  ]], {
    {1, 2, 3, 4, 5},
    {1, '2', '3', 4, 5},
    {1, '-4', '-3', 4, 5},
  })
end)

describe(':unlet support', function()
  local ito, itoe
  do
    local _obj_0 = require('test.unit.viml.executor.helpers')(it)
    ito = _obj_0.ito
    itoe = _obj_0.itoe
  end
  ito('Unlets a variable', [[
    let a = 1
    echo a
    unlet a
    try
      echo a
    catch
      echo v:exception
    endtry
  ]], {1, 'Vim(echo):E121: Undefined variable: a'})
  ito('Fails to unlet unexisting variable', [[
    try
      unlet a
    catch
      echo v:exception
    endtry
  ]], {'Vim(unlet):E108: No such variable: a'})
  ito('Succeeds to unlet unexisting variable with bang', [[
    try
      unlet! a
    catch
      echo v:exception
    endtry
  ]], {})
  ito('Unlets a slice', [[
    let l = [1, 2, 3, 4, 5, 6]
    unlet l[1:3]
    echo l
    let l = [1, 2, 3, 4, 5, 6]
    unlet l[1:1]
    echo l
    let l = [1, 2, 3, 4, 5, 6]
    unlet l[0:0]
    echo l
    let l = [1, 2, 3, 4, 5, 6]
    unlet l[-1:]
    echo l
    unlet l
  ]], {
    {1, 5, 6},
    {1, 3, 4, 5, 6},
    {2, 3, 4, 5, 6},
    {1, 2, 3, 4, 5},
  })
end)

describe(':lockvar/:unlockvar', function()
  local ito, itoe
  do
    local _obj_0 = require('test.unit.viml.executor.helpers')(it)
    ito = _obj_0.ito
    itoe = _obj_0.itoe
  end
  itoe('Fails to lock scalars', {
    'let [F, s, n, f] = [function("function"), "", 1, 1.0]',
    'lockvar F[0]',
    'lockvar s[0]',
    'lockvar n[0]',
    'lockvar f[0]',
    'unlet F s n f'
  }, {
    'Vim(lockvar):E689: Can only index a List or Dictionary',
    'Vim(lockvar):E689: Can only index a List or Dictionary',
    'Vim(lockvar):E689: Can only index a List or Dictionary',
    'Vim(lockvar):E689: Can only index a List or Dictionary',
  })
  itoe('Locks scope (depth = 1)', {
    'let g:a = 1',
    'lockvar 1 g:',
    'echo g:a',
    'let g:a = 2',
    'echo g:a',
    'let g:b = 1',
    'unlet g:a',
    'let g:a = 3',
    'echo g:a',
    'unlockvar 1 g:'
  }, {
    1, 2,
    'Vim(let):E741: Value is locked: b',
    'Vim(let):E741: Value is locked: a',
    'Vim(echo):E121: Undefined variable: a',
  })
  itoe('Locks dictionaries (depth = 1)', {
    'let d = {"a": 1}',
    'lockvar 1 d',
    'echo d.a',
    'let d.a = 2',
    'echo d.a',
    'let d.b = 3',
    'unlet d.a',
    'let d.a = 4',
    'echo d.b',
    'echo d.a',
    'unlet d'
  }, {
    1, 2,
    'Vim(let):E741: Value is locked: b',
    'Vim(let):E741: Value is locked: a',
    'Vim(echo):E716: Key not present in Dictionary: b',
    'Vim(echo):E716: Key not present in Dictionary: a',
  })
  itoe('Locks scope (depth = 2)', {
    'let g:d1 = {"d2": {"d3": {"d4": {}}}}',
    'let g:a = 1',
    'lockvar 2 g:',
    'echo string(g:d1)',
    'let g:d1.d2.d3.d4 = {}',
    'echo string(g:d1)',
    'let g:d1.d2.d3 = {}',
    'echo string(g:d1)',
    'let g:d1.d2 = {}',
    'echo string(g:d1)',
    'let g:d1 = {}',
    'echo g:a',
    'let g:a = 2',
    'echo g:a',
    'let g:b = 3',
    'unlet g:a',
    'unlet g:d1',
    'unlockvar 1 g:'
  }, {
    '{\'d2\': {\'d3\': {\'d4\': {}}}}',
    '{\'d2\': {\'d3\': {\'d4\': {}}}}',
    '{\'d2\': {\'d3\': {}}}',
    '{\'d2\': {}}',
    'Vim(let):E741: Value is locked: d1',
    1,
    'Vim(let):E741: Value is locked: a',
    1,
    'Vim(let):E741: Value is locked: b',
  })
  itoe('Locks scope (unlimited depth)', {
    'let g:d1 = {"d2": {"d3": {"d4": {}}}}',
    'let g:a = 1',
    'lockvar! g:',
    'echo string(g:d1)',
    'let g:d1.d2.d3.d4 = {}',
    'echo string(g:d1)',
    'let g:d1.d2.d3 = {}',
    'echo string(g:d1)',
    'let g:d1.d2 = {}',
    'echo string(g:d1)',
    'let g:d1 = {}',
    'echo g:a',
    'let g:a = 2',
    'echo g:a',
    'let g:b = 3',
    'unlet g:a',
    'unlet g:d1.d2.d3',
    'unlet g:d1.d2',
    'unlet g:d1',
    'unlockvar 1 g:'
  }, {
    '{\'d2\': {\'d3\': {\'d4\': {}}}}',
    'Vim(let):E741: Value is locked: d4',
    '{\'d2\': {\'d3\': {\'d4\': {}}}}',
    'Vim(let):E741: Value is locked: d3',
    '{\'d2\': {\'d3\': {\'d4\': {}}}}',
    'Vim(let):E741: Value is locked: d2',
    '{\'d2\': {\'d3\': {\'d4\': {}}}}',
    'Vim(let):E741: Value is locked: d1',
    1,
    'Vim(let):E741: Value is locked: a',
    1,
    'Vim(let):E741: Value is locked: b',
    'Vim(unlet):E741: Value is locked: d3',
    'Vim(unlet):E741: Value is locked: d2',
  })
  itoe('Locks lists (depth = 1)', {
    'let g:l = [1, 2, 3, 4, [5], [[6], 7]]',
    'lockvar 1 g:l',
    'echo g:l',
    'let g:l[0] = -1',
    'echo g:l',
    'let g:l[4][0] = -2',
    'echo g:l',
    'let g:l[5][0][0] = -3',
    'echo g:l',
    'let g:l += [1]',
    'echo g:l',
    'let g:l = []',
    'echo g:l',
    'unlet g:l'
  }, {
    {1, 2, 3, 4, {5}, {{6}, 7}},
    {-1, 2, 3, 4, {5}, {{6}, 7}},
    {-1, 2, 3, 4, {-2}, {{6}, 7}},
    {-1, 2, 3, 4, {-2}, {{-3}, 7}},
    'Vim(let):E741: Value is locked: nil',
    {-1, 2, 3, 4, {-2}, {{-3}, 7}},
    'Vim(let):E741: Value is locked: l',
    {-1, 2, 3, 4, {-2}, {{-3}, 7}},
  })
  itoe('Locks lists (unlimited depth)', {
    'let g:l = [1, 2, 3, 4, [5], [[6], 7]]',
    'lockvar! g:l',
    'echo g:l',
    'let g:l[0] = -1',
    'echo g:l',
    'let g:l[4][0] = -2',
    'echo g:l',
    'let g:l[5][0][0] = -3',
    'echo g:l',
    'let g:l += [1]',
    'echo g:l',
    'let g:l = []',
    'echo g:l',
    'unlet g:l'
  }, {
    {1, 2, 3, 4, {5}, {{6}, 7}},
    'Vim(let):E741: Value is locked: 0',
    {1, 2, 3, 4, {5}, {{6}, 7}},
    'Vim(let):E741: Value is locked: 0',
    {1, 2, 3, 4, {5}, {{6}, 7}},
    'Vim(let):E741: Value is locked: 0',
    {1, 2, 3, 4, {5}, {{6}, 7}},
    'Vim(let):E741: Value is locked: nil',
    {1, 2, 3, 4, {5}, {{6}, 7}},
    'Vim(let):E741: Value is locked: l',
    {1, 2, 3, 4, {5}, {{6}, 7}},
  })
  itoe('Locks slices (depth = 1)', {
    'let l = [[1], [2], [3], [4], [5]]',
    'lockvar 1 l[1:3]',
    'echo l',
    'let l[1] = 0',
    'echo l',
    'let l[0] = [0]',
    'echo l',
    'lockvar 1 l[-100:100]',
    'let l[0] = [-1]',
    'echo l',
    'unlet l'
  }, {
    {{1}, {2}, {3}, {4}, {5}},
    'Vim(let):E741: Value is locked: 1',
    {{1}, {2}, {3}, {4}, {5}},
    {{0}, {2}, {3}, {4}, {5}},
    'Vim(let):E741: Value is locked: 0',
    {{0}, {2}, {3}, {4}, {5}},
  })
end)
