local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local dedent = helpers.dedent
local eq = helpers.eq
local funcs = helpers.funcs
local source = helpers.source


before_each(clear)

describe('callbacks for textDocument', function()
  clear()
  describe('textDocument/references', function()
    it('should set nothing with an empty location list', function()
      source(dedent([[
        lua << EOF
          local callbacks = require('runtime.lua.lsp.callbacks').callbacks
          callbacks.textDocument.references({})
        EOF
      ]]))
      eq({}, funcs.getloclist(0))
    end)

    it('should set the location list with one item', function()
      source(dedent([[
        lua << EOF
          local callbacks = require('runtime.lua.lsp.callbacks').callbacks
          callbacks.textDocument.references({
            {uri = 'test.file', range = {start = {line=1, character=1}, ["end"] = {line=1, character=2}}}
          })
        EOF
      ]]))
      eq(2, funcs.getloclist(0)[1].col)
      -- TODO: More testing
    end)
  end)
end)

describe('getting a default textDocument callback', function()
  it('should return the hover function', function()
    local f = require('runtime.lua.lsp.callbacks').get_callback_function('textDocument/hover')
    eq(require('runtime.lua.lsp.callbacks').callbacks.textDocument.hover, f)

    local f_table = require('runtime.lua.lsp.callbacks').get_callback_function({'textDocument', 'hover'})
    eq(require('runtime.lua.lsp.callbacks').callbacks.textDocument.hover, f_table)
  end)
end)
