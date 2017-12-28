local helpers = require('test.functional.helpers')(after_each)
local setpos = helpers.funcs.setpos
local getpos = helpers.funcs.getpos
local insert = helpers.insert
local clear = helpers.clear
local command = helpers.command

local funcs = helpers.funcs
local eq = helpers.eq
local dedent = helpers.dedent

describe('structures.lua', function()
  local old_file = dedent([[
  First line of text
  Second line of text
  Third line of text
  Fourth line of text
  ]])

  local current_file = dedent([[
    Line of text 1
    Line of text 2
    Line of text 3]])

  before_each(function()
    clear()
    funcs.eval('let g:structure_test = v:null')
    insert(old_file)
    command('new')
    insert(current_file)
  end)

  local require_string = "require('lsp.structures')"
  local simple_structure_eval = function(func_name, args)
    local arg_string = ''
    if args ~= nil then
      if type(args) == 'string' then
        arg_string = '"' .. args .. '"'
      end

      if type(args) == 'number' then
        arg_string = args
      end
    end

    return funcs.luaeval(require_string .. '.' .. func_name .. '(' .. arg_string .. ')')
  end

  describe('DocumentUri()', function()
    it('should respect arguments', function()
      local test_name = 'hello_world.txt'
      eq(test_name,
         simple_structure_eval('DocumentUri', test_name))
    end)

    it('should provide default information', function()
      local test_name = 'hello_world.txt'
      funcs.nvim_buf_set_name(0, test_name)
      eq('file://' .. funcs.nvim_buf_get_name(0),
         simple_structure_eval('DocumentUri'))
    end)
  end)

  describe('languageId()', function()
  end)

  describe('text()', function()
    it('should respect arguments', function()
      eq('hello world', simple_structure_eval('text', 'hello world'))
    end)

    it('should return all the lines', function()
      eq(current_file,
         simple_structure_eval('text'))
    end)
  end)

  describe('TextDocumentIdentifier()', function()
    it('should respect arguments', function()
      eq({uri='foobar'},
         funcs.luaeval(require_string .. ".TextDocumentIdentifier(_A)", {uri='foobar'}))
    end)

    it('should return a proper uri', function()
      local test_name = 'hello_world.txt'
      funcs.nvim_buf_set_name(0, test_name)

      eq({uri='file://' .. funcs.nvim_buf_get_name(0)},
         simple_structure_eval('TextDocumentIdentifier'))
    end)
  end)

  describe('TextDocumentItem()', function()
    it('should respect partial arguments', function()
      local test_table = {
        uri = 'test_item.txt',
        languageId = 'test',
        version = 7,
      }

      local result_table = {
        uri = test_table.uri,
        languageId = test_table.languageId,
        version = test_table.version,
        text = simple_structure_eval('text'),
      }
      eq(result_table,
          funcs.luaeval(require_string .. ".TextDocumentItem(_A)", test_table))
    end)

    it('should return a proper default structure', function()
      -- TODO(tjdevries): Figure out a good way to test version
      funcs.nvim_buf_set_option(0, 'filetype', 'text')

      eq({
          uri = simple_structure_eval('DocumentUri'),
          languageId = simple_structure_eval('languageId'),
          version = 1,
          text = simple_structure_eval('text'),
        }, simple_structure_eval('TextDocumentItem'))
    end)
  end)

  describe('line()', function()
    it('should return the argument', function()
      eq(1, simple_structure_eval('line', 1))
      eq(2, simple_structure_eval('line', 2))
    end)

    it('should return a zero-relative line number', function()
      command('normal! gg')
      eq(0, simple_structure_eval('line'))

      command('normal! j')
      eq(1, simple_structure_eval('line'))
    end)
  end)

  describe('character()', function()
    it('should return the argument', function()
      eq(1, simple_structure_eval('character', 1))
      eq(2, simple_structure_eval('character', 2))
    end)

    it('should return a zero-relative column (character) number', function()
      command('normal! gg')
      eq(0, simple_structure_eval('character'))

      command('normal! l')
      eq(1, simple_structure_eval('character'))

      command('normal! l')
      eq(2, simple_structure_eval('character'))
    end)
  end)

  describe('Position()', function()
    it('returns the correct position, zero-relative position', function()
      -- [bufnum, lnum, col, off, curswant]
      setpos(".", {0, 2, 1, 0})

      local check_1 = simple_structure_eval('Position')
      eq(getpos('.'), {0, 2, 1, 0})
      eq({line=1, character=0}, check_1)

      command('normal! k^l')

      local check_2 = simple_structure_eval('Position')
      eq(getpos('.'), {0, 1, 2, 0})
      eq({line=0, character=1}, check_2)
    end)
  end)

end)
