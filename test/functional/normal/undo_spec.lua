local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local command = helpers.command
local expect = helpers.expect
local feed = helpers.feed
local insert = helpers.insert

describe('u CTRL-R g- g+', function()
  before_each(clear)

  local function create_history(num_steps)
    if num_steps == 0 then return end
    insert('1')
    if num_steps == 1 then return end
    feed('o2<esc>')
    feed('o3<esc>')
    feed('u')
    if num_steps == 2 then return end
    feed('o4<esc>')
    if num_steps == 3 then return end
    feed('u')
  end

  local function undo_and_redo(hist_pos, undo, redo, expect_str)
    command('enew!')
    create_history(hist_pos)
    local cur_contents = helpers.curbuf_contents()
    feed(undo)
    expect(expect_str)
    feed(redo)
    expect(cur_contents)
  end

  -- TODO Look for message saying 'Already at oldest change'
  it('does nothing when no changes have happened', function()
    undo_and_redo(0, 'u', '<C-r>', '')
    undo_and_redo(0, 'g-', 'g+', '')
  end)
  it('undoes a change when at a leaf', function()
    undo_and_redo(1, 'u', '<C-r>', '')
    undo_and_redo(1, 'g-', 'g+', '')
  end)
  it('undoes a change when in a non-leaf', function()
    undo_and_redo(2, 'u', '<C-r>', '1')
    undo_and_redo(2, 'g-', 'g+', '1')
  end)
  it('undoes properly around a branch point', function()
    undo_and_redo(3, 'u', '<C-r>', [[
      1
      2]])
    undo_and_redo(3, 'g-', 'g+', [[
      1
      2
      3]])
  end)
  it('can find the previous sequence after undoing to a branch', function()
    undo_and_redo(4, 'u', '<C-r>', '1')
    undo_and_redo(4, 'g-', 'g+', '1')
  end)
end)
