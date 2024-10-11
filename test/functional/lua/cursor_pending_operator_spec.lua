--- Make sure the basic functionality of cursor-text-object works.

local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local api = n.api
local clear = n.clear
local eq = t.eq
local exec_lua = n.exec_lua
local fn = n.fn

--- Get the lines of `buffer`.
---
---@param buffer number # A 1-or-more identifier for the Vim buffer.
---@return string # The text in `buffer`.
---
local function get_lines(buffer)
  return fn.join(api.nvim_buf_get_lines(buffer, 0, -1, false), '\n')
end

--- Run `keys` from NORMAL mode.
---
---@param keys string Some command to run. e.g. `d]ap`.
---
local function call_command(keys)
  exec_lua(function()
    vim.cmd('normal ' .. keys)
  end)
end

--- Create a new Vim buffer with `text` contents.
---
---@param text string All of the text to add into the buffer.
---@param file_type string? Apply a type to the newly created buffer.
---@return number # A 1-or-more identifier for the Vim buffer.
---@return number # A 1-or-more identifier for the Vim window.
---
local function make_buffer(text, file_type)
  local buffer = api.nvim_create_buf(false, false)
  api.nvim_set_current_buf(buffer)

  if file_type then
    api.nvim_set_option_value('filetype', file_type, {})
  end

  api.nvim_buf_set_lines(buffer, 0, -1, false, fn.split(text, '\n'))

  return buffer, api.nvim_get_current_win()
end

--- Make sure `input` becomes `expected` when `keys` are called.
---
---@param cursor {[1]: number, [2]: number} The row & column position. (row=1-or-more, column=0-or-more).
---@param keys string Some command to run. e.g. `d]ap`.
---@param input string The buffer's original text.
---@param expected string The text that we expect to get after calling `keys`.
---
local function run_simple_test(cursor, keys, input, expected)
  local buffer, window = make_buffer(input)
  api.nvim_win_set_cursor(window, cursor)

  call_command(keys)

  eq(expected, get_lines(buffer))
end

--- Initialize 'commentstring' so `:help gc` related tests work as expected.
---
---@param text string The template for creating comments. e.g. `"# %s"`.
---@param buffer number A 0-or-more Vim buffer ID.
---
local function set_commentstring(text, buffer)
  api.nvim_set_option_value('commentstring', text, { buf = buffer })
end

before_each(function()
  clear({ args_rm = { '--cmd' }, args = { '--clean' } })
end)

describe('basic', function()
  it('works with inner count', function()
    run_simple_test(
      { 2, 0 },
      'd]2ap',
      [[
      some text
          more text <-- NOTE: The cursor will be set here
          even more lines!
      still part of the paragraph

      another paragraph
      with text in it

      last paragraph
      ]],
      [[
      some text
      last paragraph
      ]]
    )
  end)

  it('works with outer count', function()
    run_simple_test(
      { 2, 0 },
      '2d]ap',
      [[
      some text
          more text <-- NOTE: The cursor will be set here
          even more lines!
      still part of the paragraph

      another paragraph
      with text in it

      last paragraph
      ]],
      [[
      some text
      last paragraph
      ]]
    )
  end)
end)

describe(':help c', function()
  describe('down', function()
    it('works cap', function()
      run_simple_test(
        { 2, 0 },
        'c]ap',
        [[
        some text
            more text <-- NOTE: The cursor will be set here
            even more lines!
        still part of the paragraph

        another paragraph
        with text in it
        ]],
        [[
        some text

        another paragraph
        with text in it
        ]]
      )
    end)

    it('works ca}', function()
      run_simple_test(
        { 3, 0 },
        'c]a}',
        [[
        {
            some text
                more text  <-- NOTE: The cursor will be set here
                even more lines!
            still part of the paragraph

            more lines
        }

        {
            another paragraph
            with text in it
        }
        ]],
        [[
        {
            some text


        {
            another paragraph
            with text in it
        }
        ]]
      )
    end)
  end)

  describe('up', function()
    it('works cap', function()
      run_simple_test(
        { 7, 0 },
        'c[ap',
        [[
        some text
            more text
            even more lines!
        still part of the paragraph

        first line, second paragraph
        another paragraph  <-- NOTE: The cursor will be set here
        with text in it
        ]],
        [[
        some text
            more text
            even more lines!
        still part of the paragraph


        with text in it
        ]]
      )
    end)

    it('works ca}', function()
      run_simple_test(
        { 3, 0 },
        'c[a}',
        [[
        {
            some text
                more text  <-- NOTE: The cursor will be set here
                even more lines!
            still part of the paragraph

            more lines
        }

        {
            another paragraph
            with text in it
        }
        ]],
        [[

                more text  <-- NOTE: The cursor will be set here
                even more lines!
            still part of the paragraph

            more lines
        }

        {
            another paragraph
            with text in it
        }
        ]]
      )
    end)
  end)
end)

describe(':help d', function()
  describe('down', function()
    it('works with da)', function()
      run_simple_test(
        { 3, 0 },
        'd]a)',
        [[
        (
            some text
                more text  <-- NOTE: The cursor will be set here
                even more lines!
            still part of the paragraph

            more lines
        )

        (
            another paragraph
            with text in it
        )
        ]],
        [[
        (
            some text


        (
            another paragraph
            with text in it
        )
        ]]
      )
    end)

    it('works with da]', function()
      run_simple_test(
        { 3, 0 },
        'd]a]',
        [[
        [
            some text
                more text  <-- NOTE: The cursor will be set here
                even more lines!
            still part of the paragraph

            more lines
        ]

        [
            another paragraph
            with text in it
        ]
        ]],
        [[
        [
            some text


        [
            another paragraph
            with text in it
        ]
        ]]
      )
    end)

    it('works with da}', function()
      run_simple_test(
        { 3, 0 },
        'd]a}',
        [[
        {
            some text
                more text  <-- NOTE: The cursor will be set here
                even more lines!
            still part of the paragraph

            more lines
        }

        {
            another paragraph
            with text in it
        }
        ]],
        [[
        {
            some text


        {
            another paragraph
            with text in it
        }
        ]]
      )
    end)

    it('works with dap - 3 paragraphs', function()
      run_simple_test(
        { 4, 0 },
        'd]ap',
        [[
        first first

        second 1
        second 2  <-- NOTE: The cursor will be set here
        second 3

        third paragraph
        ]],
        [[
        first first

        second 1
        third paragraph
        ]]
      )
    end)

    it('works with dap', function()
      run_simple_test(
        { 2, 0 },
        'd]ap',
        [[
        some text
            more text <-- NOTE: The cursor will be set here
            even more lines!
        still part of the paragraph

        another paragraph
        with text in it
        ]],
        [[
        some text
        another paragraph
        with text in it
        ]]
      )
    end)

    it('works with das', function()
      run_simple_test(
        { 1, 28 },
        'd]as',
        [[
        some sentences. With text and stuff
        multiple lines.
        other code
        ]],
        [[
        some sentences. Withother code
        ]]
      )
    end)

    it('works with dat', function()
      run_simple_test(
        { 3, 0 },
        'd]at',
        [[
        <foo>
            some text
                more text <-- NOTE: The cursor will be set here
                even more lines!
            still part of the paragraph
        </foo>
        ]],
        [[
        <foo>
            some text

        ]]
      )
    end)

    it('works with di)', function()
      run_simple_test(
        { 3, 0 },
        'd]i)',
        [[
        (
            some lines
            and more things  <-- NOTE: The cursor will be set here
            last in the paragraph

            last bits
        )

        (
            another one
        )
        ]],
        [[
        (
            some lines
        )

        (
            another one
        )
        ]]
      )
    end)

    it('works with di]', function()
      run_simple_test(
        { 3, 0 },
        'd]i]',
        [[
        [
            some lines
            and more things  <-- NOTE: The cursor will be set here
            last in the paragraph

            last bits
        ]

        [
            another one
        ]
        ]],
        [[
        [
            some lines
        ]

        [
            another one
        ]
        ]]
      )
    end)

    it('works with di}', function()
      run_simple_test(
        { 3, 0 },
        'd]i}',
        [[
        {
            some lines
            and more things  <-- NOTE: The cursor will be set here
            last in the paragraph

            last bits
        }

        {
            another one
        }
        ]],
        [[
        {
            some lines
        }

        {
            another one
        }
        ]]
      )
    end)

    it('works with dip', function()
      run_simple_test(
        { 2, 0 },
        'd]ip',
        [[
        some text
            more text  <-- NOTE: The cursor will be set here
            even more lines!
        still part of the paragraph

        another paragraph
        with text in it
        ]],
        [[
        some text

        another paragraph
        with text in it
        ]]
      )
    end)

    it('works with dis', function()
      run_simple_test(
        { 1, 22 },
        'd]is',
        'some sentences. With text and stuff\nmultiple lines\nother code',
        'some sentences. With t'
      )
    end)

    it('works with dit', function()
      run_simple_test(
        { 3, 0 },
        'd]it',
        [[
        <foo>
            some text
                more text  <-- NOTE: The cursor will be set here
                even more lines!
            still part of the paragraph
        </foo>
        ]],
        [[
        <foo>
            some text
</foo>
        ]]
      )
    end)
  end)

  describe('single-line', function()
    describe('left', function()
      it('works with daW', function()
        run_simple_test({ 1, 11 }, 'd[aW', 'sometext.morethings', 'rethings')
      end)

      it('works with das', function()
        run_simple_test(
          { 1, 19 },
          'd[as',
          'some sentences. With text and stuff. other code',
          'some sentences. h text and stuff. other code'
        )
      end)

      it('works with daw', function()
        run_simple_test({ 1, 2 }, 'd[aw', 'sometext.morethings', 'metext.morethings')
      end)

      it('works with da[', function()
        run_simple_test({ 1, 15 }, 'd[a[', 'some text [ inner text ] t', 'some text er text ] t')
      end)

      it('works with da{', function()
        run_simple_test({ 1, 15 }, 'd[a{', 'some text { inner text }   ', 'some text er text }   ')
      end)

      it('works with dis', function()
        run_simple_test(
          { 1, 23 },
          'd[is',
          'some sentences. With text and stuff. other code',
          'some sentences. xt and stuff. other code'
        )
      end)

      it('works with di[', function()
        run_simple_test({ 1, 15 }, 'd[i[', 'some text [ inner text ]   ', 'some text [er text ]   ')
      end)

      it('works with di{', function()
        run_simple_test({ 1, 15 }, 'd[i{', 'some text { inner text }   ', 'some text {er text }   ')
      end)
    end)

    describe('right', function()
      it('works with daW', function()
        run_simple_test({ 1, 2 }, 'd]aW', 'sometext.morethings', 'so')
      end)

      it('works with daw', function()
        run_simple_test({ 1, 2 }, 'd]aw', 'sometext.morethings', 'so.morethings')
      end)

      it('works with da]', function()
        run_simple_test({ 1, 15 }, 'd]a]', 'some text [ inner text ]   ', 'some text [ inn   ')
      end)

      it('works with da}', function()
        run_simple_test({ 1, 15 }, 'd]a}', 'some text { inner text }   ', 'some text { inn   ')
      end)

      it('works with di]', function()
        run_simple_test({ 1, 15 }, 'd]i]', 'some text [ inner text ]   ', 'some text [ inn]   ')
      end)

      it('works with di}', function()
        run_simple_test({ 1, 15 }, 'd[i}', 'some text { inner text }   ', 'some text {er text }   ')
      end)
    end)
  end)

  describe('up', function()
    it('works with da)', function()
      run_simple_test(
        { 7, 0 },
        'd[a)',
        [[
        (
            some text
                more text
                even more lines!
            still part of the paragraph

            more lines  <-- NOTE: The cursor will be set here
            last line
        )

        (
            another paragraph
            with text in it
        )
        ]],
        [[
            more lines  <-- NOTE: The cursor will be set here
            last line
        )

        (
            another paragraph
            with text in it
        )
        ]]
      )
    end)

    it('works with da]', function()
      run_simple_test(
        { 3, 22 },
        'd[a]',
        [[
        [
            some text
                more text  <-- NOTE: The cursor will be set here
                even more lines!
            still part of the paragraph

            more lines
        ]

        [
            another paragraph
            with text in it
        ]
        ]],
        [[
        ext  <-- NOTE: The cursor will be set here
                even more lines!
            still part of the paragraph

            more lines
        ]

        [
            another paragraph
            with text in it
        ]
        ]]
      )
    end)

    it('works with da}', function()
      run_simple_test(
        { 3, 24 },
        'd[a}',
        [[
        {
            some text
                more text  <-- NOTE: The cursor will be set here
                even more lines!
            still part of the paragraph

            more lines
        }

        {
            another paragraph
            with text in it
        }
        ]],
        [[
        t  <-- NOTE: The cursor will be set here
                even more lines!
            still part of the paragraph

            more lines
        }

        {
            another paragraph
            with text in it
        }
        ]]
      )
    end)

    it('works with dat', function()
      run_simple_test(
        { 3, 0 },
        'd[at',
        [[
        <foo>
            some text
                more text <-- NOTE: The cursor will be set here
                even more lines!
            still part of the paragraph
        </foo>
        ]],
        [[
                more text <-- NOTE: The cursor will be set here
                even more lines!
            still part of the paragraph
        </foo>
        ]]
      )
    end)

    it('works with dap', function()
      run_simple_test(
        { 7, 0 },
        'd[ap',
        [[
        some text
            more text
            even more lines!
        still part of the paragraph

        first line, second paragraph
        another paragraph  <-- NOTE: The cursor will be set here
        with text in it
        ]],
        [[
        some text
            more text
            even more lines!
        still part of the paragraph

        with text in it
        ]]
      )
    end)

    it('works with di)', function()
      run_simple_test(
        { 3, 0 },
        'd[i)',
        [[
        (
            some text
                more text  <-- NOTE: The cursor will be set here
                even more lines!
            still part of the paragraph

            more lines
        )

        (
            another paragraph
            with text in it
        )
        ]],
        [[
        (
                even more lines!
            still part of the paragraph

            more lines
        )

        (
            another paragraph
            with text in it
        )
        ]]
      )
    end)

    it('works with di]', function()
      run_simple_test(
        { 3, 0 },
        'd[i]',
        [[
        [
            some text
                more text  <-- NOTE: The cursor will be set here
                even more lines!
            still part of the paragraph

            more lines
        ]

        [
            another paragraph
            with text in it
        ]
        ]],
        [[
        [
                even more lines!
            still part of the paragraph

            more lines
        ]

        [
            another paragraph
            with text in it
        ]
        ]]
      )
    end)

    it('works with di}', function()
      run_simple_test(
        { 3, 0 },
        'd[i}',
        [[
        {
            some text
                more text  <-- NOTE: The cursor will be set here
                even more lines!
            still part of the paragraph

            more lines
        }

        {
            another paragraph
            with text in it
        }
        ]],
        [[
        {
                even more lines!
            still part of the paragraph

            more lines
        }

        {
            another paragraph
            with text in it
        }
        ]]
      )
    end)

    it('works with dip', function()
      run_simple_test(
        { 2, 23 },
        'd[ip',
        [[
        some text
            more text <-- NOTE: The cursor will be set here
            even more lines!
        still part of the paragraph

        another paragraph
        with text in it
        ]],
        [[
            even more lines!
        still part of the paragraph

        another paragraph
        with text in it
        ]]
      )
    end)

    it('works with dis', function()
      run_simple_test(
        { 1, 19 },
        'd[is',
        'some sentences. With text and stuff. other code',
        'some sentences. h text and stuff. other code'
      )
    end)

    it('works with dit - 001', function()
      run_simple_test(
        { 3, 0 },
        'd[it',
        [[
        <foo>
            some text
                more text <-- NOTE: The cursor will be set here
                even more lines!
            still part of the paragraph
        </foo>
        ]],
        [[
        <foo>
                more text <-- NOTE: The cursor will be set here
                even more lines!
            still part of the paragraph
        </foo>
        ]]
      )
    end)

    it('works with dit - 002 - Include characters', function()
      run_simple_test(
        { 3, 23 },
        'd[it',
        [[
        <foo>  some text
            some text
                more text <-- NOTE: The cursor will be set here
                even more lines!
            still part of the paragraph
        </foo>
        ]],
        [[
        <foo>xt <-- NOTE: The cursor will be set here
                even more lines!
            still part of the paragraph
        </foo>
        ]]
      )
    end)
  end)
end)

describe(':help gU', function()
  describe('down', function()
    it('works with gUip', function()
      run_simple_test(
        { 5, 0 },
        'gU]ip',
        [[
        aaaa
        bbbbb

        ccccc
        ddddddddddd  <-- NOTE: The cursor will be set here
        eeeeeeeee

        fffff
        ]],
        [[
        aaaa
        bbbbb

        ccccc
        DDDDDDDDDDD  <-- NOTE: THE CURSOR WILL BE SET HERE
        EEEEEEEEE

        fffff
        ]]
      )
    end)
  end)

  describe('up', function()
    it('works with gUip', function()
      run_simple_test(
        { 5, 0 },
        'gU[ip',
        [[
        aaaa
        bbbbb

        ccccc
        ddddddddddd  <-- NOTE: The cursor will be set here
        eeeeeeeee

        fffff
        ]],
        [[
        aaaa
        bbbbb

        CCCCC
        DDDDDDDDDDD  <-- NOTE: THE CURSOR WILL BE SET HERE
        eeeeeeeee

        fffff
        ]]
      )
    end)
  end)
end)

describe(':help gc', function()
  describe('down', function()
    it('works with gcip', function()
      local buffer, window = make_buffer(
        [[
                def foo() -> None:
                    """Some function."""  <-- NOTE: The cursor will be set here
                    print("do stuff")

                    for _ in range(10):
                        print("stuff")
                ]],
        'python'
      )
      api.nvim_win_set_cursor(window, { 2, 0 })
      set_commentstring('# %s')

      call_command('gc]ip')

      eq(
        [[
                def foo() -> None:
                    # """Some function."""  <-- NOTE: The cursor will be set here
                    # print("do stuff")

                    for _ in range(10):
                        print("stuff")
                ]],
        get_lines(buffer)
      )
    end)
  end)

  describe('up', function()
    it('works with gcip', function()
      local buffer, window = make_buffer(
        [[
                def foo() -> None:
                    """Some function."""  <-- NOTE: The cursor will be set here
                    print("do stuff")

                    for _ in range(10):
                        print("stuff")
                ]],
        'python'
      )
      api.nvim_win_set_cursor(window, { 2, 0 })
      set_commentstring('# %s', buffer)

      call_command('gc[ip')

      eq(
        [[
                # def foo() -> None:
                #     """Some function."""  <-- NOTE: The cursor will be set here
                    print("do stuff")

                    for _ in range(10):
                        print("stuff")
                ]],
        get_lines(buffer)
      )
    end)
  end)
end)

describe(':help gu', function()
  describe('down', function()
    it('works with guip', function()
      run_simple_test(
        { 5, 0 },
        'gu]ip',
        [[
        aaaa
        bbbbb

        ccccc
        ddDddDddDdd  <-- NOTE: The cursor will be set here
        eeeEeEEee

        fffff
        ]],
        [[
        aaaa
        bbbbb

        ccccc
        ddddddddddd  <-- note: the cursor will be set here
        eeeeeeeee

        fffff
        ]]
      )
    end)
  end)

  describe('up', function()
    it('works with guip', function()
      run_simple_test(
        { 5, 0 },
        'gu[ip',
        [[
        aaaa
        bbbbb

        cCCcc
        ddDddDddDdd  <-- NOTE: The cursor will be set here
        eeeEeEEee

        fffff
        ]],
        [[
        aaaa
        bbbbb

        ccccc
        ddddddddddd  <-- note: the cursor will be set here
        eeeEeEEee

        fffff
        ]]
      )
    end)
  end)
end)

describe(':help g~', function()
  describe('down', function()
    it('works with g~ip', function()
      run_simple_test(
        { 5, 0 },
        'g~]ip',
        [[
        aaaa
        bbbbb

        cCCcc
        ddDddDddDdd  <-- NOTE: The cursor will be set here
        eeeEeEEee

        fffff
        ]],
        [[
        aaaa
        bbbbb

        cCCcc
        DDdDDdDDdDD  <-- note: tHE CURSOR WILL BE SET HERE
        EEEeEeeEE

        fffff
        ]]
      )
    end)
  end)

  describe('up', function()
    it('works with g~ip', function()
      run_simple_test(
        { 5, 0 },
        'g~[ip',
        [[
        aaaa
        bbbbb

        cCCcc
        ddDddDddDdd  <-- NOTE: The cursor will be set here
        eeeEeEEee

        fffff
        ]],
        [[
        aaaa
        bbbbb

        CccCC
        DDdDDdDDdDD  <-- note: tHE CURSOR WILL BE SET HERE
        eeeEeEEee

        fffff
        ]]
      )
    end)
  end)
end)

describe(':help y', function()
  describe('down', function()
    it('works with yap', function()
      local _, window = make_buffer([[
                aaaa
                bbbb  <-- NOTE: The cursor will be set here
                    cccc

                next
                lines
                    blah

                ]])
      api.nvim_win_set_cursor(window, { 2, 0 })

      call_command('y]ap')

      eq(
        [[
                bbbb  <-- NOTE: The cursor will be set here
                    cccc

]],
        fn.getreg('')
      )
    end)
  end)

  describe('up', function()
    it('works with yap', function()
      local _, window = make_buffer([[
                aaaa
                bbbb  <-- NOTE: The cursor will be set here
                    cccc

                next
                lines
                    blah

                ]])
      api.nvim_win_set_cursor(window, { 2, 0 })

      call_command('y[ap')

      eq(
        '                aaaa\n                bbbb  <-- NOTE: The cursor will be set here\n',
        fn.getreg('')
      )
    end)
  end)
end)

describe('marks', function()
  describe("marks - '", function()
    describe('down', function()
      it('works with yank', function()
        local buffer, window = make_buffer([[
                    aaaa
                    bbbb  <-- NOTE: The cursor will be set here
                        cccc

                    next
                    lines
                        blah

                    ]])
        api.nvim_win_set_cursor(window, { 2, 0 })

        api.nvim_buf_set_mark(buffer, 'b', 6, 18, {})

        call_command("y]'b")

        eq(
          [[
                    bbbb  <-- NOTE: The cursor will be set here
                        cccc

                    next
                    lines
]],
          fn.getreg('')
        )
      end)
    end)

    describe('up', function()
      it('works with yank', function()
        local buffer, window = make_buffer([[
                    aaaa
                    bbbb
                        cccc

                    next
                    lines <-- NOTE: The cursor will be set here
                        blah

                    ]])
        api.nvim_win_set_cursor(window, { 6, 19 })

        api.nvim_buf_set_mark(buffer, 'b', 2, 19, {})

        call_command("y['b")

        eq(
          [[
                    bbbb
                        cccc

                    next
                    lines <-- NOTE: The cursor will be set here
]],
          fn.getreg('')
        )
      end)
    end)
  end)

  describe('marks - `', function()
    describe('down', function()
      it('works with yank', function()
        local buffer, window = make_buffer([[
                    aaaa
                    bbbb  <-- NOTE: The cursor will be set here
                        cccc

                    next
                    lines
                        blah

                    ]])
        api.nvim_win_set_cursor(window, { 2, 22 })

        api.nvim_buf_set_mark(buffer, 'b', 6, 22, {})

        call_command('y]`b')

        eq(
          [[bb  <-- NOTE: The cursor will be set here
                        cccc

                    next
                    li]],
          fn.getreg('')
        )
      end)
    end)

    describe('up', function()
      it('works with yank', function()
        local buffer, window = make_buffer([[
                    aaaa
                    bbbb
                        cccc

                    next
                    lines <-- NOTE: The cursor will be set here
                        blah

                    ]])
        api.nvim_win_set_cursor(window, { 6, 23 })

        api.nvim_buf_set_mark(buffer, 'b', 2, 23, {})

        call_command('y[`b')

        eq(
          [[b
                        cccc

                    next
                    lin]],
          fn.getreg('')
        )
      end)
    end)
  end)
end)

describe('scenario', function()
  it('works with a curly function - da{', function()
    run_simple_test(
      { 3, 0 },
      'd[a{',
      fn.join({
        'void main() {',
        '  something',
        '  ttttt <-- NOTE: The cursor will be set here',
        '  fffff',
        '}',
      }, '\n'),
      fn.join(
        { 'void main() ', '  ttttt <-- NOTE: The cursor will be set here', '  fffff', '}' },
        '\n'
      )
    )
  end)

  it('works with a curly function - di{', function()
    run_simple_test(
      { 3, 0 },
      'd[i{',
      [[
      void main() {
        something
        ttttt <-- NOTE: The cursor will be set here
        fffff
      }
      ]],
      [[
      void main() {
        fffff
      }
      ]]
    )
  end)
end)
