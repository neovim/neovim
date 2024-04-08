local t = require('test.functional.testutil')(after_each)

local exc_exec = t.exc_exec
local command = t.command
local clear = t.clear
local api = t.api
local fn = t.fn
local eq = t.eq

local function redir_exec(cmd)
  api.nvim_set_var('__redir_exec_cmd', cmd)
  command([[
    redir => g:__redir_exec_output
      silent! execute g:__redir_exec_cmd
    redir END
  ]])
  local ret = api.nvim_get_var('__redir_exec_output')
  api.nvim_del_var('__redir_exec_output')
  api.nvim_del_var('__redir_exec_cmd')
  return ret
end

describe('NULL', function()
  before_each(function()
    clear()
    command('let L = v:_null_list')
    command('let D = v:_null_dict')
    command('let S = v:_null_string')
    command('let V = $XXX_NONEXISTENT_VAR_XXX')
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
      eq((err == 0) and '' or ('\n' .. err), redir_exec('let g:_var = ' .. expr))
      if val == nil then
        eq(0, fn.exists('g:_var'))
      else
        eq(val, api.nvim_get_var('_var'))
      end
      if after ~= nil then
        after()
      end
    end)
  end
  describe('list', function()
    -- Subjectable behaviour
    null_expr_test('is equal to empty list', 'L == []', 0, 1)
    null_expr_test('is equal to empty list (reverse order)', '[] == L', 0, 1)

    -- Correct behaviour
    null_test(
      'can be :unlet item with error message for empty list',
      ':unlet L[0]',
      'Vim(unlet):E684: List index out of range: 0'
    )
    null_expr_test(
      'can be indexed with error message for empty list',
      'L[0]',
      'E684: List index out of range: 0',
      nil
    )
    null_expr_test('can be splice-indexed', 'L[:]', 0, {})
    null_expr_test('is not locked', 'islocked("v:_null_list")', 0, 0)
    null_test('is accepted by :for', 'for x in L|throw x|endfor', 0)
    null_expr_test('does not crash append()', 'append(0, L)', 0, 0, function()
      eq({ '' }, api.nvim_buf_get_lines(0, 0, -1, false))
    end)
    null_expr_test('does not crash setline()', 'setline(1, L)', 0, 0, function()
      eq({ '' }, api.nvim_buf_get_lines(0, 0, -1, false))
    end)
    null_expr_test('is identical to itself', 'L is L', 0, 1)
    null_expr_test('can be sliced', 'L[:]', 0, {})
    null_expr_test('can be copied', 'copy(L)', 0, {})
    null_expr_test('can be deepcopied', 'deepcopy(L)', 0, {})
    null_expr_test('does not crash when indexed', 'L[1]', 'E684: List index out of range: 1', nil)
    null_expr_test('does not crash call()', 'call("arglistid", L)', 0, 0)
    null_expr_test('does not crash col()', 'col(L)', 0, 0)
    null_expr_test('does not crash virtcol()', 'virtcol(L)', 0, 0)
    null_expr_test('does not crash line()', 'line(L)', 0, 0)
    null_expr_test('does not crash line() with window id', 'line(L, 1000)', 0, 0)
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
    null_expr_test('can be added to non-empty list', '([1] + L)', 0, { 1 })
    null_expr_test('can be added to non-empty list (reversed)', '(L + [1])', 0, { 1 })
    null_expr_test('is equal to itself', 'L == L', 0, 1)
    null_expr_test('is not not equal to itself', 'L != L', 0, 0)
    null_expr_test('counts correctly', 'count([L], L)', 0, 1)
    null_expr_test('makes map() return v:_null_list', 'map(L, "v:val") is# L', 0, 1)
    null_expr_test('makes filter() return v:_null_list', 'filter(L, "1") is# L', 0, 1)
    null_test(
      'is treated by :let as empty list',
      ':let [l] = L',
      'Vim(let):E688: More targets than List items'
    )
    null_expr_test(
      'is accepted as an empty list by inputlist()',
      '[feedkeys("\\n"), inputlist(L)]',
      'Type number and <Enter> or click with the mouse (q or empty cancels): ',
      { 0, 0 }
    )
    null_expr_test(
      'is accepted as an empty list by writefile()',
      ('[writefile(L, "%s"), readfile("%s")]'):format(tmpfname, tmpfname),
      0,
      { 0, {} }
    )
    null_expr_test(
      'makes add() error out',
      'add(L, 0)',
      'E742: Cannot change value of add() argument',
      1
    )
    null_expr_test(
      'makes insert() error out',
      'insert(L, 1)',
      'E742: Cannot change value of insert() argument',
      0
    )
    null_expr_test(
      'does not crash remove()',
      'remove(L, 0)',
      'E742: Cannot change value of remove() argument',
      0
    )
    null_expr_test(
      'makes reverse() error out',
      'reverse(L)',
      'E742: Cannot change value of reverse() argument',
      0
    )
    null_expr_test(
      'makes sort() error out',
      'sort(L)',
      'E742: Cannot change value of sort() argument',
      0
    )
    null_expr_test(
      'makes uniq() error out',
      'uniq(L)',
      'E742: Cannot change value of uniq() argument',
      0
    )
    null_expr_test(
      'does not crash extend()',
      'extend(L, [1])',
      'E742: Cannot change value of extend() argument',
      0
    )
    null_expr_test('does not crash extend() (second position)', 'extend([1], L)', 0, { 1 })
    null_expr_test('makes join() return empty string', 'join(L, "")', 0, '')
    null_expr_test('makes msgpackdump() return empty list', 'msgpackdump(L)', 0, {})
    null_expr_test('does not crash system()', 'system("cat", L)', 0, '')
    null_expr_test('does not crash setreg', 'setreg("x", L)', 0, 0)
    null_expr_test('does not crash systemlist()', 'systemlist("cat", L)', 0, {})
    null_test(
      'does not make Neovim crash when v:oldfiles gets assigned to that',
      ':let v:oldfiles = L|oldfiles',
      0
    )
    null_expr_test(
      'does not make complete() crash or error out',
      'execute(":normal i\\<C-r>=complete(1, L)[-1]\\n")',
      0,
      '',
      function()
        eq({ '' }, api.nvim_buf_get_lines(0, 0, -1, false))
      end
    )
    null_expr_test('is accepted by setmatches()', 'setmatches(L)', 0, 0)
    null_expr_test('is accepted by setqflist()', 'setqflist(L)', 0, 0)
    null_expr_test('is accepted by setloclist()', 'setloclist(1, L)', 0, 0)
    null_test('is accepted by :cexpr', 'cexpr L', 0)
    null_test('is accepted by :lexpr', 'lexpr L', 0)
    null_expr_test('does not crash execute()', 'execute(L)', 0, '')
  end)
  describe('dict', function()
    it('does not crash when indexing NULL dict', function()
      eq('\nE716: Key not present in Dictionary: "test"', redir_exec('echo v:_null_dict.test'))
    end)
    null_expr_test(
      'makes extend error out',
      'extend(D, {})',
      'E742: Cannot change value of extend() argument',
      0
    )
    null_expr_test('makes extend do nothing', 'extend({1: 2}, D)', 0, { ['1'] = 2 })
    null_expr_test('does not crash map()', 'map(D, "v:val")', 0, {})
    null_expr_test('does not crash filter()', 'filter(D, "1")', 0, {})
    null_expr_test('makes map() return v:_null_dict', 'map(D, "v:val") is# D', 0, 1)
    null_expr_test('makes filter() return v:_null_dict', 'filter(D, "1") is# D', 0, 1)
  end)
  describe('string', function()
    null_test('does not crash :echomsg', 'echomsg S', 0)
    null_test('does not crash :execute', 'execute S', 0)
    null_expr_test('does not crash execute()', 'execute(S)', 0, '')
    null_expr_test('does not crash executable()', 'executable(S)', 0, 0)
    null_expr_test(
      'makes timer_start() error out',
      'timer_start(0, S)',
      'E921: Invalid callback argument',
      -1
    )
    null_expr_test('does not crash filereadable()', 'filereadable(S)', 0, 0)
    null_expr_test('does not crash filewritable()', 'filewritable(S)', 0, 0)
    null_expr_test('does not crash fnamemodify()', 'fnamemodify(S, S)', 0, '')
    null_expr_test('does not crash getfperm()', 'getfperm(S)', 0, '')
    null_expr_test('does not crash getfsize()', 'getfsize(S)', 0, -1)
    null_expr_test('does not crash getftime()', 'getftime(S)', 0, -1)
    null_expr_test('does not crash getftype()', 'getftype(S)', 0, '')
    null_expr_test('does not crash glob()', 'glob(S)', 0, '')
    null_expr_test('does not crash globpath()', 'globpath(S, S)', 0, '')
    null_expr_test('does not crash mkdir()', 'mkdir(S)', 0, 0)
    null_expr_test('does not crash sort()', 'sort(["b", S, "a"])', 0, { '', 'a', 'b' })
    null_expr_test('does not crash split()', 'split(S)', 0, {})
    null_test('can be used to set an option', 'let &grepprg = S', 0)

    null_expr_test('is equal to non-existent variable', 'S == V', 0, 1)
  end)
end)
