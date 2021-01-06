local tohex, bor, lshift, rshift, band = bit.tohex, bit.bor, bit.lshift, bit.rshift, bit.band
local validate, api = vim.validate, vim.api

local M = {}

--- Returns a table containing the RGB values produced by applying the alpha in
--- @rgba with the background in @bg_rgb.
---
--@param rgba (table) with keys 'r', 'g', 'b' in [0,255] and key 'a' in [0,1]
--@param bg_rgb (table) with keys 'r', 'g', 'b' in in [0,255] to use as the
--       background color when applying the alpha
--@returns (table) with keys 'r', 'g', 'b' in [0,255]
function M.rgba_to_rgb(rgba, bg_rgb)
  validate {
    rgba = {rgba, 't', true},
    bg_rgb = {bg_rgb, 't', false},
    r = {rgba.r, 'n', true},
    g = {rgba.g, 'n', true},
    b = {rgba.b, 'n', true},
    a = {rgba.a, 'n', true},
  }

  bg_rgb = bg_rgb or M.decode_24bit_rgb(api.nvim_get_hl_by_name('Normal', true)['background'])
  validate {
    bg_r = {bg_rgb.r, 'n', true},
    bg_g = {bg_rgb.g, 'n', true},
    bg_b = {bg_rgb.b, 'n', true},
  }

  local r = rgba.r * rgba.a + bg_rgb.r * (1 - rgba.a)
  local g = rgba.g * rgba.a + bg_rgb.g * (1 - rgba.a)
  local b = rgba.b * rgba.a + bg_rgb.b * (1 - rgba.a)

  return {r=r, g=g, b=b}
end

--- Returns a string containing the 6 digit hex value for a given RGB.
---
--@param rgb (table) with keys 'r', 'g', 'b' in [0,255]
--@returns (string) 6 digit hex representing the rgb params
function M.rgb_to_hex(rgb)
  validate {
    r = {rgb.r, 'n', false};
    g = {rgb.g, 'n', false};
    b = {rgb.b, 'n', false};
  }
  return tohex(bor(lshift(rgb.r, 16), lshift(rgb.g, 8), rgb.b), 6)
end

--- Returns a string containing the 6 digit hex value produced by applying the alpha in
--- the @rgba with the background @bg_rgb.
---
--@param rgba (table) with keys 'r', 'g', 'b' in [0,255] and key 'a' in [0,1]
--@returns (string) 6 digit hex
function M.rgba_to_hex(rgba, bg_rgb)
  return M.rgb_to_hex(M.rgba_to_rgb(rgba, bg_rgb))
end

--- Returns a table containing the RGB values encoded inside 24 least
--- significant bits of the number @rgb_24bit
---
--@param rgb_24bit (number) 24-bit RGB value
--@returns (table) with keys 'r', 'g', 'b' in [0,255]
function M.decode_24bit_rgb(rgb_24bit)
  validate { rgb_24bit = {rgb_24bit, 'n', true} }
  local r = rshift(rgb_24bit, 16)
  local g = band(rshift(rgb_24bit, 8), 255)
  local b = band(rgb_24bit, 255)
  return {r=r, g=g, b=b}
end

--- Returns the perceived lightness of the rgb value. Calculated using
--- the formula from https://stackoverflow.com/a/56678483. Can be used to
--- determine which colors have similar lightness.
---
--@param rgb (table) with keys 'r', 'g', 'b' in [0,255]
--@returns (number) lightness in the range [0,100]
function M.perceived_lightness(rgb)
  local function gamma_encode(v)
    return v / 255
  end
  local function linearize(v)
    return v <= 0.04045 and v / 12.92 or math.pow((v + 0.055) / 1.055, 2.4)
  end

  -- convert from sRGB to linear values
  local r = linearize(gamma_encode(rgb.r))
  local g = linearize(gamma_encode(rgb.g))
  local b = linearize(gamma_encode(rgb.b))

  -- calculate luminance
  local L = 0.2126 * r + 0.7152 * g + 0.0722 * b

  -- calculate Y* (perceived lightness) from luminance
  return L <= (216/24389) and L * (24389/27) or math.pow(L, 1/3)*116-16
end

return M
