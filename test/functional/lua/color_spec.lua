local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local exec_lua = helpers.exec_lua
local eq = helpers.eq

describe('color methods', function()
  before_each(function()
    clear()
  end)

  describe('rgba_to_rgb', function()
    it('has no effect when using alpha of 1', function()
      exec_lua [[
        rgba = {r=100,g=100,b=100,a=1}
        bg_rgb = {r=0,g=0,b=0}
      ]]

      eq({r=100,g=100,b=100}, exec_lua('return vim.color.rgba_to_rgb(rgba, bg_rgb)'))
    end)

    it('becomes background rgb when using alpha of 0', function()
      exec_lua [[
        rgba = {r=100,g=100,b=100,a=0}
        bg_rgb = {r=0,g=0,b=0}
      ]]

      eq({r=0,g=0,b=0}, exec_lua('return vim.color.rgba_to_rgb(rgba, bg_rgb)'))
    end)

    it('has the correct rgb when using decimal alpha', function()
      exec_lua [[
        rgba = {r=100,g=100,b=100,a=0.5}
        bg_rgb = {r=0,g=0,b=0}
      ]]

      eq({r=50,g=50,b=50}, exec_lua('return vim.color.rgba_to_rgb(rgba, bg_rgb)'))
    end)
  end)

  describe('rgb_to_hex', function()
    it('has the correct hex', function()
      exec_lua('rgb = {r=100,g=100,b=100}')

      eq('646464', exec_lua('return vim.color.rgb_to_hex(rgb)'))
    end)

    it('produces hex values and not base 10', function()
      exec_lua('rgb = {r=250,g=250,b=250}')

      eq('fafafa', exec_lua('return vim.color.rgb_to_hex(rgb)'))
    end)
  end)

  describe('rgba_to_hex', function()
    it('has no effect when using alpha of 1', function()
      exec_lua [[
        rgba = {r=100,g=100,b=100,a=1}
        bg_rgb = {r=0,g=0,b=0}
      ]]

      eq('646464', exec_lua('return vim.color.rgba_to_hex(rgba, bg_rgb)'))
    end)

    it('becomes background rgb when using alpha of 0', function()
      exec_lua [[
        rgba = {r=100,g=100,b=100,a=0}
        bg_rgb = {r=0,g=0,b=0}
      ]]

      eq('000000', exec_lua('return vim.color.rgba_to_hex(rgba, bg_rgb)'))
    end)

    it('has the correct rgb when using decimal alpha', function()
      exec_lua [[
        rgba = {r=100,g=100,b=100,a=0.5}
        bg_rgb = {r=0,g=0,b=0}
      ]]

      eq('323232', exec_lua('return vim.color.rgba_to_hex(rgba, bg_rgb)'))
    end)
  end)

  describe('decode_24bit_rgb', function()
    it('looks at the 24 least significant bits', function()
      exec_lua [[
        r = 255
        g = 255
        b = 255
        bit25 = 1
        rgb_24bit = bit.bor(bit.lshift(bit25, 24), bit.lshift(r, 16), bit.lshift(g, 8), b)
      ]]

      eq({r=255,g=255,b=255}, exec_lua('return vim.color.decode_24bit_rgb(rgb_24bit)'))
    end)

    it('decodes each of rgb individually', function()
      exec_lua [[
        r = 120 -- 11110000
        g = 170 -- 10101010
        b = 204 -- 11001100
        rgb_24bit = bit.bor(bit.lshift(r, 16), bit.lshift(g, 8), b)
      ]]

      eq({r=120,g=170,b=204}, exec_lua('return vim.color.decode_24bit_rgb(rgb_24bit)'))
    end)
  end)

  describe('perceived_lightness', function()
    it('assigns a lightness of 0 to black', function()
      exec_lua('rgb = {r=0,g=0,b=0}')

      eq(0, exec_lua('return vim.color.perceived_lightness(rgb)'))
    end)

    it('assigns a lightness of 100 to white', function()
      exec_lua('rgb = {r=255,g=255,b=255}')

      eq(100, exec_lua('return vim.color.perceived_lightness(rgb)'))
    end)

    it('assigns correct lightness to blue', function()
      exec_lua('rgb = {r=0,g=0,b=255}')

      eq(32, exec_lua('return math.floor(vim.color.perceived_lightness(rgb))'))
    end)

    it('assigns correct lightness to lime', function()
      exec_lua('rgb = {r=0,g=255,b=0}')

      eq(87, exec_lua('return math.floor(vim.color.perceived_lightness(rgb))'))
    end)
  end)
end)
