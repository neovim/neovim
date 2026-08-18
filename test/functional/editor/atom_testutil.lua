-- Helpers shared by the atom-capture specs (mcursor_spec.lua, cmdatom_spec.lua).

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

--- Projects only the named fields of `ev` (a nil field stays absent, so `eq` still asserts
--- omission when the expected table lacks it).
function m.pick(ev, ...)
  local r = {}
  for _, f in ipairs({ ... }) do
    r[f] = ev[f]
  end
  return r
end

--- Gets the last `count` collected CmdAtom events: bare `keys` strings by default, or
--- projections of the named `fields`.
function m.atoms_tail(count, ...)
  local evs = m.atoms()
  local fields = select('#', ...) > 0 and { ... } or nil
  local tail = {}
  for i = #evs - count + 1, #evs do
    table.insert(tail, fields and m.pick(evs[i], unpack(fields)) or evs[i].keys)
  end
  return tail
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

return m
