local helpers = require('test.functional.helpers')(after_each)

local call = helpers.call
local clear = helpers.clear
local command = helpers.command
local eq = helpers.eq
local eval = helpers.eval
local funcs = helpers.funcs
local matches = helpers.matches
local nvim = helpers.nvim
local pcall_err = helpers.pcall_err
local source = helpers.source
local write_file = helpers.write_file

describe('async handlers', function()
  before_each(clear)

  describe('default handler', function()
    it('runs command in child process', function()
      command('&:let child_chans = nvim_list_chans()')
      call('call_wait', {3})
      eq({id = 1, client = {}, mode = 'rpc', stream = 'stdio'},
         eval('child_chans[0]'))
    end)

    it('escapes quotes and backslashes properly', function()
      command([[&:let msg = "Someone's friend said: \"Hello, World!\".\n"]]..
              [[.'""World"?!". The world''s mean.']])
      call('call_wait', {3})
      eq([[Someone's friend said: "Hello, World!".]]..'\n'..
         [[""World"?!". The world's mean.]], eval('msg'))
    end)

    it('sends and receives context properly', function()
      nvim('set_var', 'name', 'Neovi')
      command([[&:let name = name.'m']])
      call('call_wait', {3})
      eq('Neovim', eval('name'))

      call('setreg', 0, 'abc')
      command([[&:call setreg(0, getreg(0).'123')]])
      call('call_wait', {4})
      eq('abc123', eval('getreg(0)'))

      nvim('set_var', 'done', {})

      source([[
      let s:counter = 1
      function s:do_interesting_stuff()
        call add(g:done, s:counter)
        let s:counter += 1
      endfunction

      function DoInterestingStuff()
        call s:do_interesting_stuff()
      endfunction

      &:call s:do_interesting_stuff()
      call call_wait([5])
      &:call DoInterestingStuff()
      call call_wait([6])
      ]])

      eq({1,2}, eval('done'))
    end)
  end)

  describe('vimgrep handler', function()
    local files = {
      ['async_vimgrep_spec_file1'] = [[ Lorem ipsum dolor sit amet,
                                    consectetur adipiscing elit... ]],
      ['async_vimgrep_spec_file2'] = [[ Lorem ipsum dolor sit amet,
                                    consectetur adipiscing elit... ]],
      ['async_vimgrep_spec_file3'] = [[ Lorem ipsum dolor sit amet,
                                    consectetur adipiscing elit... ]],
    }

    before_each(function()
      for fname, content in pairs(files) do
        write_file(fname, content:gsub('^%s+', ''):gsub('([\n\r]+)%s+', '%1'))
      end
    end)

    after_each(function()
      for fname, _ in pairs(files) do
        os.remove(fname)
      end
    end)

    local function wait_all()
      call('call_wait',
           eval([[filter(map(nvim_list_chans(), 'v:val.id'), 'v:val >= 3')]]))
    end

    local function tidy_results(results)
      results = funcs.map(results, ({([[
       { 'fname': fnamemodify(bufname(v:val.bufnr), ':t'),
         'lnum': v:val.lnum, 'col': v:val.col, 'text': v:val.text }
      ]]):gsub('\n', '')})[1])
      table.sort(results, function(r1, r2) return r1.fname < r2.fname end)
      return results
    end

    it('works', function()
      local expected = {
        { fname = 'async_vimgrep_spec_file1',
          lnum = 1,
          col = 7,
          text = 'Lorem ipsum dolor sit amet,', },
        { fname = 'async_vimgrep_spec_file2',
          lnum = 1,
          col = 7,
          text = 'Lorem ipsum dolor sit amet,', },
        { fname = 'async_vimgrep_spec_file3',
          lnum = 1,
          col = 7,
          text = 'Lorem ipsum dolor sit amet,', },
      }

      command([[&:vimgrep ipsum async_vimgrep_spec_file*]])
      wait_all()
      eq(expected, tidy_results(eval('getqflist()')))

      command([[&:lvimgrep /ipsum/g async_vimgrep_spec_file*]])
      wait_all()
      eq(expected, tidy_results(eval('getloclist(0)')))
    end)

    it('uses last used pattern when empty', function()
      command([[silent! /ipsum]])
      command([[&:vimgrep // async_vimgrep_spec_file1]])
      wait_all()
      eq({{ fname = 'async_vimgrep_spec_file1',
            lnum = 1,
            col = 7,
            text = 'Lorem ipsum dolor sit amet,' }},
         tidy_results(eval('getqflist()')))
    end)

    it('reports pattern and path errors', function()
      matches('E35: No previous regular expression',
              pcall_err(command, [[&:vimgrep // async_vimgrep_spec_file1]]))
      matches('Path missing or invalid pattern',
              pcall_err(command, [[&:vimgrep /foo/]]))
    end)
  end)
end)
