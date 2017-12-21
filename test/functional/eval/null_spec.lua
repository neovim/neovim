local helpers = require('test.functional.helpers')(after_each)

local curbufmeths = helpers.curbufmeths
local redir_exec = helpers.redir_exec
local exc_exec = helpers.exc_exec
local command = helpers.command
local clear = helpers.clear
local meths = helpers.meths
local funcs = helpers.funcs
local eq = helpers.eq

describe('NULL', function()
  before_each(function()
    clear()
    command('let L = v:_null_list')
    command('let D = v:_null_dict')
    command('let S = $XXX_NONEXISTENT_VAR_XXX')
  end)
  local tmpfname = 'Xtest-functional-viml-null'
  after_each(function()
    os.remove(tmpfname)
  end)
  local null_test = function(name, cmd, err)
    it(name, function()
      eq(err, exc_exec(cmd))
    end)
  end
  local null_expr_test = function(name, expr, err, val, after)
    it(name, function()
      eq((err == 0) and ('') or ('\n' .. err),
         redir_exec('let g:_var = ' .. expr))
      if val == nil then
        eq(0, funcs.exists('g:_var'))
      else
        eq(val, meths.get_var('_var'))
      end
      if after ~= nil then
        after()
      end
    end)
  end
  describe('list', function()
    -- Incorrect behaviour

    -- FIXME add() should not return 1 at all
    null_expr_test('does not crash add()', 'add(L, 0)', 0, 1)
    null_expr_test('does not crash extend()', 'extend(L, [1])', 'E742: Cannot change value of extend() argument', 0)
    null_expr_test('does not crash extend() (second position)', 'extend([1], L)', 0, {1})
    -- FIXME should be accepted by inputlist()
    null_expr_test('is accepted as an empty list by inputlist()',
                        '[feedkeys("\\n"), inputlist(L)]', 'E686: Argument of inputlist() must be a List', {0, 0})
    -- FIXME should be accepted by writefile(), return {0, {}}
    null_expr_test('is accepted as an empty list by writefile()',
                        ('[writefile(L, "%s"), readfile("%s")]'):format(tmpfname, tmpfname),
                        'E484: Can\'t open file ' .. tmpfname, {0, {}})
    -- FIXME should give error message
    null_expr_test('does not crash remove()', 'remove(L, 0)', 0, 0)
    -- FIXME should return 0
    null_expr_test('is accepted by setqflist()', 'setqflist(L)', 0, -1)
    -- FIXME should return 0
    null_expr_test('is accepted by setloclist()', 'setloclist(1, L)', 0, -1)
    -- FIXME should return 0
    null_expr_test('is accepted by setmatches()', 'setmatches(L)', 0, -1)
    -- FIXME should return empty list or error out
    null_expr_test('is accepted by sort()', 'sort(L)', 0, 0)
    -- FIXME Should return 1
    null_expr_test('is accepted by sort()', 'sort(L) is L', 0, 0)
    -- FIXME should not error out
    null_test('is accepted by :cexpr', 'cexpr L', 'Vim(cexpr):E777: String or List expected')
    -- FIXME should not error out
    null_test('is accepted by :lexpr', 'lexpr L', 'Vim(lexpr):E777: String or List expected')
    null_test('is accepted by :for', 'for x in L|throw x|endfor', 0)

    -- Subjectable behaviour

    -- FIXME Should return 1
    null_expr_test('is equal to empty list', 'L == []', 0, 0)
    -- FIXME Should return 1
    null_expr_test('is equal to empty list (reverse order)', '[] == L', 0, 0)
    -- FIXME Should return 1
    null_expr_test('is not locked', 'islocked("v:_null_list")', 0, 0)

    -- Crashes

    -- null_expr_test('does not crash setreg', 'setreg("x", L)', 0, 0)
    -- null_expr_test('does not crash setline', 'setline(1, L)', 0, 0)
    -- null_expr_test('does not crash system()', 'system("cat", L)', 0, '')
    -- null_expr_test('does not crash systemlist()', 'systemlist("cat", L)', 0, {})

    -- Correct behaviour
    null_expr_test('does not crash append()', 'append(1, L)', 0, 0, function()
      eq({''}, curbufmeths.get_lines(0, -1, false))
    end)
    null_expr_test('is identical to itself', 'L is L', 0, 1)
    null_expr_test('can be sliced', 'L[:]', 0, {})
    null_expr_test('can be copied', 'copy(L)', 0, {})
    null_expr_test('can be deepcopied', 'deepcopy(L)', 0, {})
    null_expr_test('does not crash when indexed', 'L[1]',
                        'E684: list index out of range: 1\nE15: Invalid expression: L[1]', nil)
    null_expr_test('does not crash call()', 'call("arglistid", L)', 0, 0)
    null_expr_test('does not crash col()', 'col(L)', 0, 0)
    null_expr_test('does not crash virtcol()', 'virtcol(L)', 0, 0)
    null_expr_test('does not crash line()', 'line(L)', 0, 0)
    null_expr_test('does not crash count()', 'count(L, 1)', 0, 0)
    null_expr_test('does not crash cursor()', 'cursor(L)', 'E474: Invalid argument', -1)
    null_expr_test('does not crash map()', 'map(L, "v:val")', 0, {})
    null_expr_test('does not crash filter()', 'filter(L, "1")', 0, {})
    null_expr_test('is empty', 'empty(L)', 0, 1)
    null_expr_test('does not crash get()', 'get(L, 1, 10)', 0, 10)
    null_expr_test('has zero length', 'len(L)', 0, 0)
    null_expr_test('is accepted as an empty list by max()', 'max(L)', 0, 0)
    null_expr_test('is accepted as an empty list by min()', 'min(L)', 0, 0)
    null_expr_test('is stringified correctly', 'string(L)', 0, '[]')
    null_expr_test('is JSON encoded correctly', 'json_encode(L)', 0, '[]')
    null_test('does not crash lockvar', 'lockvar! L', 0)
    null_expr_test('can be added to itself', '(L + L)', 0, {})
    null_expr_test('can be added to itself', '(L + L) is L', 0, 1)
    null_expr_test('can be added to non-empty list', '([1] + L)', 0, {1})
    null_expr_test('can be added to non-empty list (reversed)', '(L + [1])', 0, {1})
    null_expr_test('is equal to itself', 'L == L', 0, 1)
    null_expr_test('is not not equal to itself', 'L != L', 0, 0)
    null_expr_test('counts correctly', 'count([L], L)', 0, 1)
    null_expr_test('makes map() return v:_null_list', 'map(L, "v:val") is# L', 0, 1)
    null_expr_test('makes filter() return v:_null_list', 'filter(L, "1") is# L', 0, 1)
  end)
  describe('dict', function()
    it('does not crash when indexing NULL dict', function()
      eq('\nE716: Key not present in Dictionary: test\nE15: Invalid expression: v:_null_dict.test',
         redir_exec('echo v:_null_dict.test'))
    end)
    null_expr_test('makes extend error out', 'extend(D, {})', 'E742: Cannot change value of extend() argument', 0)
    null_expr_test('makes extend do nothing', 'extend({1: 2}, D)', 0, {['1']=2})
    null_expr_test('does not crash map()', 'map(D, "v:val")', 0, {})
    null_expr_test('does not crash filter()', 'filter(D, "1")', 0, {})
    null_expr_test('makes map() return v:_null_dict', 'map(D, "v:val") is# D', 0, 1)
    null_expr_test('makes filter() return v:_null_dict', 'filter(D, "1") is# D', 0, 1)
  end)
end)
