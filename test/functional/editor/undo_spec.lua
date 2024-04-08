local t = require('test.functional.testutil')(after_each)

local clear = t.clear
local command = t.command
local eval = t.eval
local expect = t.expect
local eq = t.eq
local feed = t.feed
local feed_command = t.feed_command
local insert = t.insert
local fn = t.fn
local exec = t.exec
local exec_lua = t.exec_lua

local function lastmessage()
  local messages = fn.split(fn.execute('messages'), '\n')
  return messages[#messages]
end

describe('u CTRL-R g- g+', function()
  before_each(clear)

  local function create_history(num_steps)
    if num_steps == 0 then
      return
    end
    insert('1')
    if num_steps == 1 then
      return
    end
    feed('o2<esc>')
    feed('o3<esc>')
    feed('u')
    if num_steps == 2 then
      return
    end
    feed('o4<esc>')
    if num_steps == 3 then
      return
    end
    feed('u')
  end

  local function undo_and_redo(hist_pos, undo, redo, expect_str)
    command('enew!')
    create_history(hist_pos)
    local cur_contents = t.curbuf_contents()
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
    undo_and_redo(
      3,
      'u',
      '<C-r>',
      [[
      1
      2]]
    )
    undo_and_redo(
      3,
      'g-',
      'g+',
      [[
      1
      2
      3]]
    )
  end)
  it('can find the previous sequence after undoing to a branch', function()
    undo_and_redo(4, 'u', '<C-r>', '1')
    undo_and_redo(4, 'g-', 'g+', '1')
  end)

  describe('undo works correctly when writing in Insert mode', function()
    before_each(function()
      exec([[
        edit Xtestfile.txt
        set undolevels=100 undofile
        write
      ]])
    end)

    after_each(function()
      command('bwipe!')
      os.remove('Xtestfile.txt')
      os.remove('Xtestfile.txt.un~')
    end)

    -- oldtest: Test_undo_after_write()
    it('using <Cmd> mapping', function()
      command('imap . <Cmd>write<CR>')
      feed('Otest.<CR>boo!!!<Esc>')
      expect([[
        test
        boo!!!
        ]])

      feed('u')
      expect([[
        test
        ]])

      feed('u')
      expect('')
    end)

    it('using Lua mapping', function()
      exec_lua([[
        vim.api.nvim_set_keymap('i', '.', '', {callback = function()
          vim.cmd('write')
        end})
      ]])
      feed('Otest.<CR>boo!!!<Esc>')
      expect([[
        test
        boo!!!
        ]])

      feed('u')
      expect([[
        test
        ]])

      feed('u')
      expect('')
    end)

    it('using RPC call', function()
      feed('Otest')
      command('write')
      feed('<CR>boo!!!<Esc>')
      expect([[
        test
        boo!!!
        ]])

      feed('u')
      expect([[
        test
        ]])

      feed('u')
      expect('')
    end)
  end)
end)

describe(':undo! command', function()
  before_each(function()
    clear()
    feed('i1 little bug in the code<Esc>')
    feed('o1 little bug in the code<Esc>')
    feed('oTake 1 down, patch it around<Esc>')
    feed('o99 little bugs in the code<Esc>')
  end)
  it('works', function()
    feed_command('undo!')
    expect([[
      1 little bug in the code
      1 little bug in the code
      Take 1 down, patch it around]])
    feed('<C-r>')
    eq('Already at newest change', lastmessage())
  end)
  it('works with arguments', function()
    feed_command('undo! 2')
    expect([[
      1 little bug in the code
      1 little bug in the code]])
    feed('<C-r>')
    eq('Already at newest change', lastmessage())
  end)
  it('correctly sets alternative redo', function()
    feed('uo101 little bugs in the code<Esc>')
    feed_command('undo!')
    feed('<C-r>')
    expect([[
      1 little bug in the code
      1 little bug in the code
      Take 1 down, patch it around
      99 little bugs in the code]])

    feed('uuoTake 2 down, patch them around<Esc>')
    feed('o101 little bugs in the code<Esc>')
    feed_command('undo! 2')
    feed('<C-r><C-r>')
    expect([[
      1 little bug in the code
      1 little bug in the code
      Take 1 down, patch it around
      99 little bugs in the code]])
  end)
  it('fails when attempting to redo or move to different undo branch', function()
    feed_command('undo! 4')
    eq('E5767: Cannot use :undo! to redo or move to a different undo branch', eval('v:errmsg'))
    feed('u')
    feed_command('undo! 4')
    eq('E5767: Cannot use :undo! to redo or move to a different undo branch', eval('v:errmsg'))
    feed('o101 little bugs in the code<Esc>')
    feed('o101 little bugs in the code<Esc>')
    feed_command('undo! 4')
    eq('E5767: Cannot use :undo! to redo or move to a different undo branch', eval('v:errmsg'))
  end)
end)
