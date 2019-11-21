local helpers = require('test.functional.helpers')(after_each)
local eq = helpers.eq
local exec_lua = helpers.exec_lua
local dedent = helpers.dedent
local insert = helpers.insert
local clear = helpers.clear

describe('LSP util', function()
  local test_text = dedent([[
  First line of text
  Second line of text
  Third line of text
  Fourth line of text]])

  local function reset()
    clear()
    insert(test_text)
  end

  before_each(reset)

  local function make_edit(y_0, x_0, y_1, x_1, text)
    return {
      range = {
        start = { line = y_0, character = x_0 };
        ["end"] = { line = y_1, character = x_1 };
      };
      newText = type(text) == 'table' and table.concat(text, '\n') or (text or "");
    }
  end

  local function buf_lines(bufnr)
    return exec_lua("return vim.api.nvim_buf_get_lines((...), 0, -1, false)", bufnr)
  end

  describe('apply_edits', function()
    it('should apply simple edits', function()
      local edits = {
        make_edit(0, 0, 0, 0, {"123"});
        make_edit(1, 0, 1, 1, {"2"});
        make_edit(2, 0, 2, 2, {"3"});
      }
      exec_lua('vim.lsp.util.apply_text_edits(...)', edits, 1)
      eq({
        '123First line of text';
        '2econd line of text';
        '3ird line of text';
        'Fourth line of text';
      }, buf_lines(1))
    end)

    it('should apply complex edits', function()
      local edits = {
        make_edit(0, 0, 0, 0, {"", "12"});
        make_edit(0, 0, 0, 0, {"3", "foo"});
        make_edit(0, 1, 0, 1, {"bar", "123"});
        make_edit(0, #"First ", 0, #"First line of text", {"guy"});
        make_edit(1, 0, 1, #'Second', {"baz"});
        make_edit(2, #'Th', 2, #"Third", {"e next"});
        make_edit(3, #'', 3, #"Fourth", {"another line of text", "before this"});
        make_edit(3, #'Fourth', 3, #"Fourth line of text", {"!"});
      }
      exec_lua('vim.lsp.util.apply_text_edits(...)', edits, 1)
      eq({
        '';
        '123';
        'fooFbar';
        '123irst guy';
        'baz line of text';
        'The next line of text';
        'another line of text';
        'before this!';
      }, buf_lines(1))
    end)
  end)
end)
