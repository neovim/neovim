local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear = n.clear
local eq = t.eq
local exec = n.exec
local api = n.api
local dedent = t.dedent

---@param reverse_tree {[integer]:integer}
local function generate_undo_tree_from_rev(reverse_tree)
  for k, v in ipairs(reverse_tree) do
    exec('undo ' .. v)
    api.nvim_buf_set_lines(0, 0, -1, true, { tostring(k) })
  end
end
---@param buf integer
---@return string
local function buf_get_lines_and_extmark(buf)
  local lines = api.nvim_buf_get_lines(buf, 0, -1, true)
  local ns = api.nvim_create_namespace('nvim.undotree')
  local extmarks = api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })
  for i = #extmarks, 1, -1 do
    local extmark = extmarks[i]
    ---@type nil,integer,nil,vim.api.keyset.extmark_details
    local _, row, _, opts = unpack(extmark)
    local virt_lines = assert(opts.virt_lines)
    for _, v in ipairs(virt_lines) do
      local virt_line = v[1][1]
      table.insert(lines, row + 2, virt_line)
    end
  end
  return table.concat(lines, '\n')
end

local function strip_time(text)
  return text:gsub('%s-%(.-%)', '')
end

describe(':Undotree', function()
  before_each(function()
    clear({ args = { '--clean' } })
    exec 'packadd nvim.undotree'
  end)

  it('works', function()
    api.nvim_set_current_line('foo')
    exec 'Undotree'
    local buf = api.nvim_get_current_buf()
    local win = api.nvim_get_current_win()
    eq(
      dedent [[
    *    0
    *    1]],
      strip_time(buf_get_lines_and_extmark(buf))
    )
    eq(2, api.nvim_win_get_cursor(win)[1])
    exec 'wincmd w'

    -- Doing changes moves cursor in undotree
    exec 'undo'
    eq(1, api.nvim_win_get_cursor(win)[1])
    api.nvim_set_current_line('bar')
    eq(3, api.nvim_win_get_cursor(win)[1])

    eq(
      dedent [[
    *    0
    |\
    | *    1
    *    2]],
      strip_time(buf_get_lines_and_extmark(buf))
    )

    -- Moving the cursor in undotree changes the buffer
    eq('bar', api.nvim_get_current_line())
    exec 'wincmd w'
    exec '2'
    exec 'wincmd w'
    eq('foo', api.nvim_get_current_line())
  end)

  describe('branch+remove is correctly graphed', function()
    it('when branching left', function()
      generate_undo_tree_from_rev({ 0, 1, 2, 3, 1, 3, 4, 3, 2, 0 })
      exec 'Undotree'
      eq(
        dedent([[
        *    0
        |\
        | *    1
        | |\
        | | *    2
        | | |\
        | | | *    3
        | | | |\
        | | | | *    4
        | * | | |    5
        |  / /| |]] --[[This is the line being tested, e.g. remove&branch left]] .. '\n' .. [[
        | | | * |    6
        | | |  /
        | | | *    7
        | | *    8
        | *    9
        *    10]]),
        strip_time(buf_get_lines_and_extmark(0))
      )
    end)

    it('when branching right', function()
      generate_undo_tree_from_rev({ 0, 1, 2, 3, 3, 1, 4, 2, 1, 0 })
      exec 'Undotree'
      eq(
        dedent([[
        *    0
        |\
        | *    1
        | |\
        | | *    2
        | | |\
        | | | *    3
        | | | |\
        | | | | *    4
        | | | * |    5
        | |\ \  |]] --[[This is the line being tested, e.g. remove&branch right]] .. '\n' .. [[
        | | * | |    6
        | |  / /
        | | | *    7
        | | *    8
        | *    9
        *    10]]),
        strip_time(buf_get_lines_and_extmark(0))
      )
    end)
  end)
end)
