-- Helpers shared by the atom-capture specs (mcursor_spec.lua, cmdatom_spec.lua).

local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local m = {}

function m.get_lines()
  return n.buf_lines(0)
end

--- vim.keycode(): |key-notation| => the raw bytes of the CmdAtom event's keys/lhs.
function m.k(s)
  return n.api.nvim_replace_termcodes(s, true, true, true)
end

--- Starts collecting CmdAtom event-data.
function m.atoms_start()
  n.exec_lua([[
    _G.atoms = {}
    vim.api.nvim_create_autocmd('CmdAtom', {
      callback = function(ev)
        table.insert(_G.atoms, ev.data)
      end,
    })
  ]])
end

--- Gets the collected CmdAtom event-data.
function m.atoms()
  n.poke_eventloop() -- CmdAtom is deferred, so drain the event loop first.
  return n.exec_lua('return _G.atoms')
end

--- Gets the last collected CmdAtom event.
function m.atom_last()
  local evs = m.atoms()
  return evs[#evs]
end

--- Gets the last `count` collected CmdAtom events: bare `keys` strings by default, or
--- projections of the named `fields`.
function m.atoms_tail(count, ...)
  local evs = m.atoms()
  local fields = select('#', ...) > 0 and { ... } or nil
  local tail = {}
  for i = #evs - count + 1, #evs do
    table.insert(tail, fields and t.pick(evs[i], unpack(fields)) or evs[i].keys)
  end
  return tail
end

--- Gets `ev`'s subatoms (`CmdAtom.atoms`): bare `keys` strings by default, or projections of the
--- named `fields`.
function m.subatoms(ev, ...)
  local fields = select('#', ...) > 0 and { ... } or nil
  local subs = {}
  for _, c in ipairs(ev.atoms) do
    table.insert(subs, fields and t.pick(c, unpack(fields)) or c.keys)
  end
  return subs
end

--- Minimal vim-surround "ys": an <expr> mapping sets 'operatorfunc' and returns "g@"; the opfunc
--- reads the wrap char with getchar() and wraps the motion region (yank, modify register, paste
--- back).
m.minisurround_vim = [[
  function! MiniSurroundSetup() abort
    set operatorfunc=MiniSurround
    return 'g@'
  endfunction
  function! MiniSurround(type) abort
    let char = nr2char(getchar())
    let save = getreg('"')
    silent exe "norm! v`[o`]y"
    call setreg('"', char .. getreg('"') .. char, 'v')
    silent exe "norm! gvp`["
    call setreg('"', save)
  endfunction
  nnoremap <expr> ys MiniSurroundSetup()
]]

--- Minimal vim-sneak: :omap whose ":call" reads a 2-char getchar() and moves the cursor.
m.minisneak_vim = [[
  function! MiniSneak() abort
    let c1 = nr2char(getchar())
    let c2 = nr2char(getchar())
    call search('\V' . c1 . c2, 'W')
  endfunction
  onoremap <silent> z :<C-U>call MiniSneak()<CR>
]]

--- Minimal vim-surround "ds": a ":call" mapping whose edit runs through :normal inside a
--- function, with a getchar() payload naming the surround to delete.
m.delsurround_vim = [[
  function! DelSurround() abort
    call getchar()
    " cursor is on the "("; delete it and its matching ")".
    normal! mz%x`zx
  endfunction
  nnoremap <silent> ds :<C-U>call DelSurround()<CR>
]]

-- Example from #41657 (without input "caching"): Lua 'operatorfunc' <expr> mapping that reads
-- input() and edits via API.
--
-- - "sd": not a real operator, "g@l" fixes the motion.
-- - "sa": true operator, input is read AFTER the textobject.
m.opfunc_input_lua = [[
  vim.keymap.set('n', 'sd', function()
    vim.o.operatorfunc = function()
      local s = vim.fn.input({ prompt = 'Input: ' })
      local pos = vim.api.nvim_win_get_cursor(0)
      vim.api.nvim_buf_set_text(0, pos[1] - 1, pos[2], pos[1] - 1, pos[2], { s .. s })
    end
    return 'g@l'
  end, { expr = true })
  vim.keymap.set('n', 'sa', function()
    vim.o.operatorfunc = function()
      local s = vim.fn.input({ prompt = 'Input: ' })
      local right = vim.api.nvim_buf_get_mark(0, ']')
      vim.api.nvim_buf_set_text(0, right[1] - 1, right[2] + 1, right[1] - 1, right[2] + 1, { s })
      local left = vim.api.nvim_buf_get_mark(0, '[')
      vim.api.nvim_buf_set_text(0, left[1] - 1, left[2], left[1] - 1, left[2], { s })
    end
    return 'g@'
  end, { expr = true })
]]

return m
