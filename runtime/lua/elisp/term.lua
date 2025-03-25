local M = {}
M.tty_cap = {
  inverse = 0x01,
  underline = 0x02,
  bold = 0x04,
  dim = 0x08,
  italic = 0x10,
  strike_through = 0x20,
}
function M.tty_capable_p(f, caps)
  return true
end
return M
