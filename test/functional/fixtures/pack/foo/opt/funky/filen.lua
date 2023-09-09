table.insert(_G.test_loadorder, "funky!")

if not _G.nesty then
  _G.nesty = true
  local save_order = _G.test_loadorder
  _G.test_loadorder = {}
  _G.vim.o.pp = "" -- funky!
  vim.cmd [[runtime! filen.lua ]]
  _G.nested_order = _G.test_loadorder
  _G.test_loadorder = save_order
  _G.nesty = nil
end
