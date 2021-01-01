local validate = vim.validate
local get_hl_by_name = vim.api.nvim_get_hl_by_name
local rshift, band = bit.rshift, bit.band

local M = {}

-- TODO(RRethy) Documentation
function M.rgb_with_alpha(r, g, b, a)
  validate {
    r = {r, 'n', false};
    g = {g, 'n', false};
    b = {b, 'n', false};
    a = {a, 'n', true};
  }
  if not a then a = 1 end

  local bg_rgb = get_hl_by_name('Normal', true)['background']

  local bg_r = rshift(bg_rgb, 16)
  local bg_g = band(rshift(bg_rgb, 8), 255)
  local bg_b = band(bg_rgb, 255)

  r = (r % 256) * a + bg_r * (1 - a)
  g = (g % 256) * a + bg_g * (1 - a)
  b = (b % 256) * a + bg_b * (1 - a)

  return r, g, b
end

function M.rgb_to_hex(r, g, b)
  validate {
    r = {r, 'n', false};
    g = {g, 'n', false};
    b = {b, 'n', false};
  }
  return bit.tohex(bit.bor(bit.lshift(r, 16), bit.lshift(g, 8), b), 6)
end

function M.rgba_to_hex(r, g, b, a)
  validate {
    r = {r, 'n', false};
    g = {g, 'n', false};
    b = {b, 'n', false};
    a = {a, 'n', true};
  }

  return M.rgb_to_hex(M.rgb_with_alpha(r, g, b, a))
end

return M
