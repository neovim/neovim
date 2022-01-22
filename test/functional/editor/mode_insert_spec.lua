-- Insert-mode tests.

local helpers = require('test.functional.helpers')(after_each)
local clear, feed, insert = helpers.clear, helpers.feed, helpers.insert
local expect = helpers.expect
local command = helpers.command
local eq = helpers.eq
local eval = helpers.eval

describe('insert-mode', function()
  before_each(function()
    clear()
  end)

  it('CTRL-@', function()
    -- Inserts last-inserted text, leaves insert-mode.
    insert('hello')
    feed('i<C-@>x')
    expect('hellhello')

    -- C-Space is the same as C-@.
    -- CTRL-SPC inserts last-inserted text, leaves insert-mode.
    feed('i<C-Space>x')
    expect('hellhellhello')

    -- CTRL-A inserts last inserted text
    feed('i<C-A>x')
    expect('hellhellhellhelloxo')
  end)

  describe('Ctrl-R', function()
    it('works', function()
      command("let @@ = 'test'")
      feed('i<C-r>"')
      expect('test')
    end)

    it('works with multi-byte text', function()
      command("let @@ = 'påskägg'")
      feed('i<C-r>"')
      expect('påskägg')
    end)
  end)

  describe('Ctrl-O', function()
    it('enters command mode for one command', function()
      feed('ihello world<C-o>')
      feed(':let ctrlo = "test"<CR>')
      feed('iii')
      expect('hello worldiii')
      eq(1, eval('ctrlo ==# "test"'))
    end)

    it('re-enters insert mode at the end of the line when running startinsert', function()
      -- #6962
      feed('ihello world<C-o>')
      feed(':startinsert<CR>')
      feed('iii')
      expect('hello worldiii')
    end)

    it('re-enters insert mode at the beginning of the line when running startinsert', function()
      insert('hello world')
      feed('0<C-o>')
      feed(':startinsert<CR>')
      feed('aaa')
      expect('aaahello world')
    end)

    it('re-enters insert mode in the middle of the line when running startinsert', function()
      insert('hello world')
      feed('bi<C-o>')
      feed(':startinsert<CR>')
      feed('ooo')
      expect('hello oooworld')
    end)
  end)

  describe('Ctrl-V', function()
    it('shows o, O, u, U, x, X, and digits with META/CMD modifiers', function()
      feed('i<C-V><M-o><C-V><D-o><C-V><M-O><C-V><D-O><Esc>')
      expect('<M-o><D-o><M-O><D-O>')
      feed('cc<C-V><M-u><C-V><D-u><C-V><M-U><C-V><D-U><Esc>')
      expect('<M-u><D-u><M-U><D-U>')
      feed('cc<C-V><M-x><C-V><D-x><C-V><M-X><C-V><D-X><Esc>')
      expect('<M-x><D-x><M-X><D-X>')
      feed('cc<C-V><M-1><C-V><D-2><C-V><M-7><C-V><D-8><Esc>')
      expect('<M-1><D-2><M-7><D-8>')
    end)
  end)
end)
