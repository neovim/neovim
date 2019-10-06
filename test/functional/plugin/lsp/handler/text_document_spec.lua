local helpers = require('test.functional.helpers')(after_each)
local eq = helpers.eq
local exec_lua = helpers.exec_lua
local dedent = helpers.dedent
local source = helpers.source
local clear = helpers.clear

describe('LSP handler/text_document', function()
  before_each(function()
    clear()
  end)

  describe('CompletionList_to_matches', function()
    it('returns vim complete-item match objects', function()
      source(dedent([[
        lua << EOF
          result = {
            isIncomplete = false,
            items = {
              { label = 'label1', kind = 1, detail = 'detail1', documentation = 'documentation1' },
              { label = 'label2', kind = 2, detail = 'detail2', documentation = 'documentation2' },
              { label = 'label3', kind = 3, detail = 'detail3', documentation = { language = 'txt', value = 'documentation3' } },
              { label = 'label4'}
            }
          }
        EOF
      ]]))

      local expected = {
        { word = 'label1', kind = 'Text', menue = 'detail1', info = 'documentation1', icase = 1, dup = 0 },
        { word = 'label2', kind = 'Method', menue = 'detail2', info = 'documentation2', icase = 1, dup = 0 },
        { word = 'label3', kind = 'Function', menue = 'detail3', info = 'documentation3', icase = 1, dup = 0 },
        { word = 'label4', kind = '', menue = '', info = '', icase = 1, dup = 0 }
      }

      eq(expected, exec_lua("return require('vim.lsp.handler').text_document.CompletionList_to_matches(result)"))
    end)
  end)

  describe('SignatureHelp_to_preview_contents', function()
    describe('When result has the activeSignature key', function()
      it('should return activeSignature number object in the list', function()
        source(dedent([[
          lua << EOF
            result = {
              signatures = {
                { label = 'label1', documentation = 'documentation1', parameters = { { label = 'label1', documentation = 'documentation1' } } },
                { label = 'label2', documentation = 'documentation2', parameters = { { label = 'label2', documentation = 'documentation2' } } },
              },
              activeSignature = 1
            }
          EOF
        ]]))

        local expected = { 'label2', 'documentation2', 'documentation2' }

        eq(expected, exec_lua("return require('vim.lsp.handler').text_document.SignatureHelp_to_preview_contents(result)"))
      end)
    end)

    describe('When result does not have the activeSignature key', function()
      it('should return first object in the list', function()
        source(dedent([[
          lua << EOF
            result = {
              signatures = {
                { label = 'label1', documentation = 'documentation1', parameters = { { label = 'label1', documentation = 'documentation1' } } },
                { label = 'label2', documentation = 'documentation2', parameters = { { label = 'label2', documentation = 'documentation2' } } },
              }
            }
          EOF
        ]]))

        local expected = { 'label1', 'documentation1', 'documentation1' }

        eq(expected, exec_lua("return require('vim.lsp.handler').text_document.SignatureHelp_to_preview_contents(result)"))
      end)
    end)
  end)

  describe('HoverContents_to_preview_contents', function()
    describe('When content type is MarkedString[]', function()
      it('should equal to expected', function()
        source(dedent([[
          lua << EOF
            result = {
              contents = {
                { language = 'txt', value = 'hover contents1' },
                { language = 'txt', value = 'hover contents2' },
              }
            }
          EOF
        ]]))

        local expected = {
          '```txt',
          'hover contents1',
          '```',
          '```txt',
          'hover contents2',
          '```',
        }

        eq(expected, exec_lua("return require('vim.lsp.handler').text_document.HoverContents_to_preview_contents(result)"))
      end)
    end)

    describe('When content type is MarkedString(object)', function()
      it('should equal to expected', function()
        source(dedent([[
          lua << EOF
            result = { contents = { language = 'txt', value = 'hover contents' } }
          EOF
        ]]))

        local expected = {
          '```txt',
          'hover contents',
          '```'
        }

        eq(expected, exec_lua("return require('vim.lsp.handler').text_document.HoverContents_to_preview_contents(result)"))
      end)
    end)

    describe('When content type is MarkedString(string)', function()
      it('should equal to expected', function()
        source(dedent([[
          lua << EOF
            result = { contents = 'hover contents' }
          EOF
        ]]))

        local expected = { 'hover contents' }

        eq(expected, exec_lua("return require('vim.lsp.handler').text_document.HoverContents_to_preview_contents(result)"))
      end)
    end)

    describe('When content type is MarkupContent', function()
      it('should equal to expected', function()
        source(dedent([[
          lua << EOF
            result = { contents = { kind = 'plaintext', value = 'contents' } }
          EOF
        ]]))

        local expected = { 'contents' }

        eq(expected, exec_lua("return require('vim.lsp.handler').text_document.HoverContents_to_preview_contents(result)"))
      end)
    end)
  end)
end)
