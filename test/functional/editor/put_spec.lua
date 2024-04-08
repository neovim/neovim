local Screen = require('test.functional.ui.screen')
local t = require('test.functional.testutil')(after_each)

local clear = t.clear
local insert = t.insert
local feed = t.feed
local expect = t.expect
local eq = t.eq
local map = vim.tbl_map
local filter = vim.tbl_filter
local feed_command = t.feed_command
local command = t.command
local curbuf_contents = t.curbuf_contents
local fn = t.fn
local dedent = t.dedent

local function reset()
  command('bwipe! | new')
  insert([[
  Line of words 1
  Line of words 2]])
  command('goto 1')
  feed('itest_string.<esc>u')
  fn.setreg('a', 'test_stringa', 'V')
  fn.setreg('b', 'test_stringb\ntest_stringb\ntest_stringb', 'b')
  fn.setreg('"', 'test_string"', 'v')
end

-- We check the last inserted register ". in each of these tests because it is
-- implemented completely differently in do_put().
-- It is implemented differently so that control characters and imap'ped
-- characters work in the same manner when pasted as when inserted.
describe('put command', function()
  clear()
  before_each(reset)

  local function visual_marks_zero()
    for _, v in pairs(fn.getpos("'<")) do
      if v ~= 0 then
        return false
      end
    end
    for _, v in pairs(fn.getpos("'>")) do
      if v ~= 0 then
        return false
      end
    end
    return true
  end

  -- {{{ Where test definitions are run
  local function run_test_variations(test_variations, extra_setup)
    reset()
    if extra_setup then
      extra_setup()
    end
    local init_contents = curbuf_contents()
    local init_cursorpos = fn.getcurpos()
    local assert_no_change = function(exception_table, after_undo)
      expect(init_contents)
      -- When putting the ". register forwards, undo doesn't move
      -- the cursor back to where it was before.
      -- This is because it uses the command character 'a' to
      -- start the insert, and undo after that leaves the cursor
      -- one place to the right (unless we were at the end of the
      -- line when we pasted).
      if not (exception_table.undo_position and after_undo) then
        eq(init_cursorpos, fn.getcurpos())
      end
    end

    for _, test in pairs(test_variations) do
      it(test.description, function()
        if extra_setup then
          extra_setup()
        end
        local orig_dotstr = fn.getreg('.')
        t.ok(visual_marks_zero())
        -- Make sure every test starts from the same conditions
        assert_no_change(test.exception_table, false)
        local was_cli = test.test_action()
        test.test_assertions(test.exception_table, false)
        -- Check that undo twice puts us back to the original conditions
        -- (i.e. puts the cursor and text back to before)
        feed('u')
        assert_no_change(test.exception_table, true)

        -- Should not have changed the ". register
        -- If we paste the ". register with a count we can't avoid
        -- changing this register, hence avoid this check.
        if not test.exception_table.dot_reg_changed then
          eq(orig_dotstr, fn.getreg('.'))
        end

        -- Doing something, undoing it, and then redoing it should
        -- leave us in the same state as just doing it once.
        -- For :ex actions we want '@:', for normal actions we want '.'

        -- The '.' redo doesn't work for visual put so just exit if
        -- it was tested.
        -- We check that visual put was used by checking if the '< and
        -- '> marks were changed.
        if not visual_marks_zero() then
          return
        end

        if test.exception_table.undo_position then
          fn.setpos('.', init_cursorpos)
        end
        if was_cli then
          feed('@:')
        else
          feed('.')
        end

        test.test_assertions(test.exception_table, true)
      end)
    end
  end -- run_test_variations()
  -- }}}

  local function create_test_defs(
    test_defs,
    command_base,
    command_creator, -- {{{
    expect_base,
    expect_creator
  )
    local rettab = {}
    local exceptions
    for _, v in pairs(test_defs) do
      if v[4] then
        exceptions = v[4]
      else
        exceptions = {}
      end
      table.insert(rettab, {
        test_action = command_creator(command_base, v[1]),
        test_assertions = expect_creator(expect_base, v[2]),
        description = v[3],
        exception_table = exceptions,
      })
    end
    return rettab
  end -- create_test_defs() }}}

  local function find_cursor_position(expect_string) -- {{{
    -- There must only be one occurrence of the character 'x' in
    -- expect_string.
    -- This function removes that occurrence, and returns the position that
    -- it was in.
    -- This returns the cursor position that would leave the 'x' in that
    -- place if we feed 'ix<esc>' and the string existed before it.
    for linenum, line in pairs(fn.split(expect_string, '\n', 1)) do
      local column = line:find('x')
      if column then
        return { linenum, column }, expect_string:gsub('x', '')
      end
    end
  end -- find_cursor_position() }}}

  -- Action function creators {{{
  local function create_p_action(test_map, substitution)
    local temp_val = test_map:gsub('p', substitution)
    return function()
      feed(temp_val)
      return false
    end
  end

  local function create_put_action(command_base, substitution)
    local temp_val = command_base:gsub('put', substitution)
    return function()
      feed_command(temp_val)
      return true
    end
  end
  -- }}}

  -- Expect function creator {{{
  local function expect_creator(conversion_function, expect_base, conversion_table)
    local temp_expect_string = conversion_function(expect_base, conversion_table)
    local cursor_position, expect_string = find_cursor_position(temp_expect_string)
    return function(exception_table, after_redo)
      expect(expect_string)

      -- Have to use getcurpos() instead of api.nvim_win_get_cursor(0) in
      -- order to account for virtualedit.
      -- We always want the curswant element in getcurpos(), which is
      -- sometimes different to the column element in
      -- api.nvim_win_get_cursor(0).
      -- NOTE: The ".gp command leaves the cursor after the pasted text
      -- when running, but does not when the command is redone with the
      -- '.' command.
      if not (exception_table.redo_position and after_redo) then
        local actual_position = fn.getcurpos()
        eq(cursor_position, { actual_position[2], actual_position[5] })
      end
    end
  end -- expect_creator() }}}

  -- Test definitions {{{
  local function copy_def(def)
    local rettab = { '', {}, '', nil }
    rettab[1] = def[1]
    for k, v in pairs(def[2]) do
      rettab[2][k] = v
    end
    rettab[3] = def[3]
    if def[4] then
      rettab[4] = {}
      for k, v in pairs(def[4]) do
        rettab[4][k] = v
      end
    end
    return rettab
  end

  local normal_command_defs = {
    {
      'p',
      { cursor_after = false, put_backwards = false, dot_register = false },
      'pastes after cursor with p',
    },
    {
      'gp',
      { cursor_after = true, put_backwards = false, dot_register = false },
      'leaves cursor after text with gp',
    },
    {
      '".p',
      { cursor_after = false, put_backwards = false, dot_register = true },
      'works with the ". register',
    },
    {
      '".gp',
      { cursor_after = true, put_backwards = false, dot_register = true },
      'gp works with the ". register',
      { redo_position = true },
    },
    {
      'P',
      { cursor_after = false, put_backwards = true, dot_register = false },
      'pastes before cursor with P',
    },
    {
      'gP',
      { cursor_after = true, put_backwards = true, dot_register = false },
      'gP pastes before cursor and leaves cursor after text',
    },
    {
      '".P',
      { cursor_after = false, put_backwards = true, dot_register = true },
      'P works with ". register',
    },
    {
      '".gP',
      { cursor_after = true, put_backwards = true, dot_register = true },
      'gP works with ". register',
      { redo_position = true },
    },
  }

  -- Add a definition applying a count for each definition above.
  -- Could do this for each transformation (p -> P, p -> gp etc), but I think
  -- it's neater this way (balance between being explicit and too verbose).
  for i = 1, #normal_command_defs do
    local cur = normal_command_defs[i]

    -- Make modified copy of current definition that includes a count.
    local newdef = copy_def(cur)
    newdef[2].count = 2
    cur[2].count = 1
    newdef[1] = '2' .. newdef[1]
    newdef[3] = 'double ' .. newdef[3]

    if cur[2].dot_register then
      if not cur[4] then
        newdef[4] = {}
      end
      newdef[4].dot_reg_changed = true
    end

    normal_command_defs[#normal_command_defs + 1] = newdef
  end

  local ex_command_defs = {
    {
      'put',
      { put_backwards = false, dot_register = false },
      'pastes linewise forwards with :put',
    },
    {
      'put!',
      { put_backwards = true, dot_register = false },
      'pastes linewise backwards with :put!',
    },
    {
      'put .',
      { put_backwards = false, dot_register = true },
      'pastes linewise with the dot register',
    },
    {
      'put! .',
      { put_backwards = true, dot_register = true },
      'pastes linewise backwards with the dot register',
    },
  }

  local function non_dotdefs(def_table)
    return filter(function(d)
      return not d[2].dot_register
    end, def_table)
  end

  -- }}}

  -- Conversion functions {{{
  local function convert_charwise(expect_base, conversion_table, virtualedit_end, visual_put)
    expect_base = dedent(expect_base)
    -- There is no difference between 'P' and 'p' when VIsual_active
    if not visual_put then
      if conversion_table.put_backwards then
        -- Special case for virtualedit at the end of a line.
        local replace_string
        if not virtualedit_end then
          replace_string = 'test_stringx"%1'
        else
          replace_string = 'test_stringx"'
        end
        expect_base = expect_base:gsub('(.)test_stringx"', replace_string)
      end
    end
    if conversion_table.count > 1 then
      local rep_string = 'test_string"'
      local extra_puts = rep_string:rep(conversion_table.count - 1)
      expect_base = expect_base:gsub('test_stringx"', extra_puts .. 'test_stringx"')
    end
    if conversion_table.cursor_after then
      expect_base = expect_base:gsub('test_stringx"', 'test_string"x')
    end
    if conversion_table.dot_register then
      expect_base = expect_base:gsub('(test_stringx?)"', '%1.')
    end
    return expect_base
  end -- convert_charwise()

  local function make_back(string)
    local prev_line
    local rettab = {}
    local string_found = false
    for _, line in pairs(fn.split(string, '\n', 1)) do
      if line:find('test_string') then
        string_found = true
        table.insert(rettab, line)
      else
        if string_found then
          if prev_line then
            table.insert(rettab, prev_line)
            prev_line = nil
          end
          table.insert(rettab, line)
        else
          table.insert(rettab, prev_line)
          prev_line = line
        end
      end
    end
    -- In case there are no lines after the text that was put.
    if prev_line and string_found then
      table.insert(rettab, prev_line)
    end
    return table.concat(rettab, '\n')
  end -- make_back()

  local function convert_linewise(expect_base, conversion_table, _, use_a, indent)
    expect_base = dedent(expect_base)
    if conversion_table.put_backwards then
      expect_base = make_back(expect_base)
    end
    local p_str = 'test_string"'
    if use_a then
      p_str = 'test_stringa'
    end

    if conversion_table.dot_register then
      expect_base = expect_base:gsub('x' .. p_str, 'xtest_string.')
      p_str = 'test_string.'
    end

    if conversion_table.cursor_after then
      expect_base = expect_base:gsub('x' .. p_str .. '\n', p_str .. '\nx')
    end

    -- The 'indent' argument is only used here because a single put with an
    -- indent doesn't require special handling. It doesn't require special
    -- handling because the cursor is never put before the indent, hence
    -- the modification of 'test_stringx"' gives the same overall answer as
    -- modifying '    test_stringx"'.

    -- Only happens when using normal mode command actions.
    if conversion_table.count and conversion_table.count > 1 then
      if not indent then
        indent = ''
      end
      local rep_string = indent .. p_str .. '\n'
      local extra_puts = rep_string:rep(conversion_table.count - 1)
      local orig_string, new_string
      if conversion_table.cursor_after then
        orig_string = indent .. p_str .. '\nx'
        new_string = extra_puts .. orig_string
      else
        orig_string = indent .. 'x' .. p_str .. '\n'
        new_string = orig_string .. extra_puts
      end
      expect_base = expect_base:gsub(orig_string, new_string)
    end
    return expect_base
  end

  local function put_x_last(orig_line, p_str)
    local prev_end, cur_end, cur_start = 0, 0, 0
    while cur_start do
      prev_end = cur_end
      cur_start, cur_end = orig_line:find(p_str, prev_end)
    end
    -- Assume (because that is the only way I call it) that p_str matches
    -- the pattern 'test_string.'
    return orig_line:sub(1, prev_end - 1) .. 'x' .. orig_line:sub(prev_end)
  end

  local function convert_blockwise(
    expect_base,
    conversion_table,
    visual,
    use_b,
    trailing_whitespace
  )
    expect_base = dedent(expect_base)
    local p_str = 'test_string"'
    if use_b then
      p_str = 'test_stringb'
    end

    if conversion_table.dot_register then
      expect_base = expect_base:gsub('(x?)' .. p_str, '%1test_string.')
      -- Looks strange, but the dot is a special character in the pattern
      -- and a literal character in the replacement.
      expect_base = expect_base:gsub('test_stringx.', 'test_stringx.')
      p_str = 'test_string.'
    end

    -- No difference between 'p' and 'P' in visual mode.
    if not visual then
      if conversion_table.put_backwards then
        -- One for the line where the cursor is left, one for all other
        -- lines.
        expect_base = expect_base:gsub('([^x])' .. p_str, p_str .. '%1')
        expect_base = expect_base:gsub('([^x])x' .. p_str, 'x' .. p_str .. '%1')
        if not trailing_whitespace then
          expect_base = expect_base:gsub(' \n', '\n')
          expect_base = expect_base:gsub(' $', '')
        end
      end
    end

    if conversion_table.count and conversion_table.count > 1 then
      local p_pattern = p_str:gsub('%.', '%%.')
      expect_base = expect_base:gsub(p_pattern, p_str:rep(conversion_table.count))
      expect_base =
        expect_base:gsub('test_stringx([b".])', p_str:rep(conversion_table.count - 1) .. '%0')
    end

    if conversion_table.cursor_after then
      if not visual then
        local prev_line
        local rettab = {}
        local prev_in_block = false
        for _, line in pairs(fn.split(expect_base, '\n', 1)) do
          if line:find('test_string') then
            if prev_line then
              prev_line = prev_line:gsub('x', '')
              table.insert(rettab, prev_line)
            end
            prev_line = line
            prev_in_block = true
          else
            if prev_in_block then
              prev_line = put_x_last(prev_line, p_str)
              table.insert(rettab, prev_line)
              prev_in_block = false
            end
            table.insert(rettab, line)
          end
        end
        if prev_line and prev_in_block then
          table.insert(rettab, put_x_last(prev_line, p_str))
        end

        expect_base = table.concat(rettab, '\n')
      else
        expect_base = expect_base:gsub('x(.)', '%1x')
      end
    end

    return expect_base
  end
  -- }}}

  -- Convenience functions {{{
  local function run_normal_mode_tests(
    test_string,
    base_map,
    extra_setup,
    virtualedit_end,
    selection_string
  )
    local function convert_closure(e, c)
      return convert_charwise(e, c, virtualedit_end, selection_string)
    end
    local function expect_normal_creator(expect_base, conversion_table)
      local test_expect = expect_creator(convert_closure, expect_base, conversion_table)
      return function(exception_table, after_redo)
        test_expect(exception_table, after_redo)
        if selection_string then
          if not conversion_table.put_backwards then
            eq(selection_string, fn.getreg('"'))
          end
        else
          eq('test_string"', fn.getreg('"'))
        end
      end
    end
    run_test_variations(
      create_test_defs(
        normal_command_defs,
        base_map,
        create_p_action,
        test_string,
        expect_normal_creator
      ),
      extra_setup
    )
  end -- run_normal_mode_tests()

  local function convert_linewiseer(expect_base, conversion_table)
    return expect_creator(convert_linewise, expect_base, conversion_table)
  end

  local function run_linewise_tests(expect_base, base_command, extra_setup)
    local linewise_test_defs = create_test_defs(
      ex_command_defs,
      base_command,
      create_put_action,
      expect_base,
      convert_linewiseer
    )
    run_test_variations(linewise_test_defs, extra_setup)
  end -- run_linewise_tests()
  -- }}}

  -- Actual tests
  describe('default pasting', function()
    local expect_string = [[
    Ltest_stringx"ine of words 1
    Line of words 2]]
    run_normal_mode_tests(expect_string, 'p')

    run_linewise_tests(
      [[
      Line of words 1
      xtest_string"
      Line of words 2]],
      'put'
    )
  end)

  describe('linewise register', function()
    -- put with 'p'
    local local_ex_command_defs = non_dotdefs(normal_command_defs)
    local base_expect_string = [[
    Line of words 1
    xtest_stringa
    Line of words 2]]
    local function local_convert_linewise(expect_base, conversion_table)
      return convert_linewise(expect_base, conversion_table, nil, true)
    end
    local function expect_lineput(expect_base, conversion_table)
      return expect_creator(local_convert_linewise, expect_base, conversion_table)
    end
    run_test_variations(
      create_test_defs(
        local_ex_command_defs,
        '"ap',
        create_p_action,
        base_expect_string,
        expect_lineput
      )
    )

    -- put with :put
    local linewise_put_defs = non_dotdefs(ex_command_defs)
    base_expect_string = [[
    Line of words 1
    xtest_stringa
    Line of words 2]]
    run_test_variations(
      create_test_defs(
        linewise_put_defs,
        'put a',
        create_put_action,
        base_expect_string,
        convert_linewiseer
      )
    )
  end)

  describe('blockwise register', function()
    local blockwise_put_defs = non_dotdefs(normal_command_defs)
    local test_base = [[
    Lxtest_stringbine of words 1
    Ltest_stringbine of words 2
     test_stringb]]

    local function expect_block_creator(expect_base, conversion_table)
      return expect_creator(function(e, c)
        return convert_blockwise(e, c, nil, true)
      end, expect_base, conversion_table)
    end

    run_test_variations(
      create_test_defs(blockwise_put_defs, '"bp', create_p_action, test_base, expect_block_creator)
    )
  end)

  it('adds correct indentation when put with [p and ]p', function()
    feed('G>>"a]pix<esc>')
    -- luacheck: ignore
    expect([[
    Line of words 1
    	Line of words 2
    	xtest_stringa]])
    feed('uu"a[pix<esc>')
    -- luacheck: ignore
    expect([[
    Line of words 1
    	xtest_stringa
    	Line of words 2]])
  end)

  describe('linewise paste with autoindent', function()
    -- luacheck: ignore
    run_linewise_tests(
      [[
        Line of words 1
        	Line of words 2
        xtest_string"]],
      'put',
      function()
        fn.setline('$', '	Line of words 2')
        -- Set curswant to '8' to be at the end of the tab character
        -- This is where the cursor is put back after the 'u' command.
        fn.setpos('.', { 0, 2, 1, 0, 8 })
        command('set autoindent')
      end
    )
  end)

  describe('put inside tabs with virtualedit', function()
    local test_string = [[
    Line of words 1
       test_stringx"     Line of words 2]]
    run_normal_mode_tests(test_string, 'p', function()
      fn.setline('$', '	Line of words 2')
      command('setlocal virtualedit=all')
      fn.setpos('.', { 0, 2, 1, 2, 3 })
    end)
  end)

  describe('put after the line with virtualedit', function()
    -- luacheck: ignore 621
    local test_string = [[
    Line of words 1  test_stringx"
    	Line of words 2]]
    run_normal_mode_tests(test_string, 'p', function()
      fn.setline('$', '	Line of words 2')
      command('setlocal virtualedit=all')
      fn.setpos('.', { 0, 1, 16, 1, 17 })
    end, true)
  end)

  describe('Visual put', function()
    describe('basic put', function()
      local test_string = [[
      test_stringx" words 1
      Line of words 2]]
      run_normal_mode_tests(test_string, 'v2ep', nil, nil, 'Line of')
    end)
    describe('over trailing newline', function()
      local test_string = 'Line of test_stringx"Line of words 2'
      run_normal_mode_tests(test_string, 'v$p', function()
        fn.setpos('.', { 0, 1, 9, 0, 9 })
      end, nil, 'words 1\n')
    end)
    describe('linewise mode', function()
      local test_string = [[
      xtest_string"
      Line of words 2]]
      local function expect_vis_linewise(expect_base, conversion_table)
        return expect_creator(function(e, c)
          return convert_linewise(e, c, nil, nil)
        end, expect_base, conversion_table)
      end
      run_test_variations(
        create_test_defs(
          normal_command_defs,
          'Vp',
          create_p_action,
          test_string,
          expect_vis_linewise
        ),
        function()
          fn.setpos('.', { 0, 1, 1, 0, 1 })
        end
      )

      describe('with whitespace at bol', function()
        local function expect_vis_lineindented(expect_base, conversion_table)
          local test_expect = expect_creator(function(e, c)
            return convert_linewise(e, c, nil, nil, '    ')
          end, expect_base, conversion_table)
          return function(exception_table, after_redo)
            test_expect(exception_table, after_redo)
            if not conversion_table.put_backwards then
              eq('Line of words 1\n', fn.getreg('"'))
            end
          end
        end
        local base_expect_string = [[
            xtest_string"
        Line of words 2]]
        run_test_variations(
          create_test_defs(
            normal_command_defs,
            'Vp',
            create_p_action,
            base_expect_string,
            expect_vis_lineindented
          ),
          function()
            feed('i    test_string.<esc>u')
            fn.setreg('"', '    test_string"', 'v')
          end
        )
      end)
    end)

    describe('blockwise visual mode', function()
      local test_base = [[
        test_stringx"e of words 1
        test_string"e of words 2]]

      local function expect_block_creator(expect_base, conversion_table)
        local test_expect = expect_creator(function(e, c)
          return convert_blockwise(e, c, true)
        end, expect_base, conversion_table)
        return function(e, c)
          test_expect(e, c)
          if not conversion_table.put_backwards then
            eq('Lin\nLin', fn.getreg('"'))
          end
        end
      end

      local select_down_test_defs = create_test_defs(
        normal_command_defs,
        '<C-v>jllp',
        create_p_action,
        test_base,
        expect_block_creator
      )
      run_test_variations(select_down_test_defs)

      -- Undo and redo of a visual block put leave the cursor in the top
      -- left of the visual block area no matter where the cursor was
      -- when it started.
      local undo_redo_no = map(function(table)
        local rettab = copy_def(table)
        if not rettab[4] then
          rettab[4] = {}
        end
        rettab[4].undo_position = true
        rettab[4].redo_position = true
        return rettab
      end, normal_command_defs)

      -- Selection direction doesn't matter
      run_test_variations(
        create_test_defs(
          undo_redo_no,
          '<C-v>kllp',
          create_p_action,
          test_base,
          expect_block_creator
        ),
        function()
          fn.setpos('.', { 0, 2, 1, 0, 1 })
        end
      )

      describe('blockwise cursor after undo', function()
        -- A bit of a hack of the reset above.
        -- In the tests that selection direction doesn't matter, we
        -- don't check the undo/redo position because it doesn't fit
        -- the same pattern as everything else.
        -- Here we fix this by directly checking the undo/redo position
        -- in the test_assertions of our test definitions.
        local function assertion_creator(_, _)
          return function(_, _)
            feed('u')
            -- Have to use feed('u') here to set curswant, because
            -- ex_undo() doesn't do that.
            eq({ 0, 1, 1, 0, 1 }, fn.getcurpos())
            feed('<C-r>')
            eq({ 0, 1, 1, 0, 1 }, fn.getcurpos())
          end
        end

        run_test_variations(
          create_test_defs(undo_redo_no, '<C-v>kllp', create_p_action, test_base, assertion_creator),
          function()
            fn.setpos('.', { 0, 2, 1, 0, 1 })
          end
        )
      end)
    end)

    describe("with 'virtualedit'", function()
      describe('splitting a tab character', function()
        local base_expect_string = [[
        Line of words 1
          test_stringx"     Line of words 2]]
        run_normal_mode_tests(base_expect_string, 'vp', function()
          fn.setline('$', '	Line of words 2')
          command('setlocal virtualedit=all')
          fn.setpos('.', { 0, 2, 1, 2, 3 })
        end, nil, ' ')
      end)
      describe('after end of line', function()
        local base_expect_string = [[
        Line of words 1  test_stringx"
        Line of words 2]]
        run_normal_mode_tests(base_expect_string, 'vp', function()
          command('setlocal virtualedit=all')
          fn.setpos('.', { 0, 1, 16, 2, 18 })
        end, true, ' ')
      end)
    end)
  end)

  describe('. register special tests', function()
    -- luacheck: ignore 621
    before_each(reset)
    it('applies control character actions', function()
      feed('i<C-t><esc>u')
      expect([[
      Line of words 1
      Line of words 2]])
      feed('".p')
      expect([[
      	Line of words 1
      Line of words 2]])
      feed('u1go<C-v>j".p')
      eq(
        [[
	ine of words 1
	ine of words 2]],
        curbuf_contents()
      )
    end)

    local screen
    setup(function()
      screen = Screen.new()
      screen:attach()
    end)

    local function bell_test(actions, should_ring)
      if should_ring then
        -- check bell is not set by nvim before the action
        screen:sleep(50)
      end
      t.ok(not screen.bell and not screen.visualbell)
      actions()
      screen:expect {
        condition = function()
          if should_ring then
            if not screen.bell and not screen.visualbell then
              error('Bell was not rung after action')
            end
          else
            if screen.bell or screen.visualbell then
              error('Bell was rung after action')
            end
          end
        end,
        unchanged = not should_ring,
      }
      screen.bell = false
      screen.visualbell = false
    end

    it('should not ring the bell with gp at end of line', function()
      bell_test(function()
        feed('$".gp')
      end)

      -- Even if the last character is a multibyte character.
      reset()
      fn.setline(1, 'helloม')
      bell_test(function()
        feed('$".gp')
      end)
    end)

    it('should not ring the bell with gp and end of file', function()
      fn.setpos('.', { 0, 2, 1, 0 })
      bell_test(function()
        feed('$vl".gp')
      end)
    end)

    it('should ring the bell when deleting if not appropriate', function()
      command('goto 2')
      feed('i<bs><esc>')
      expect([[
      ine of words 1
      Line of words 2]])
      bell_test(function()
        feed('".P')
      end, true)
    end)

    it('should restore cursor position after undo of ".p', function()
      local origpos = fn.getcurpos()
      feed('".pu')
      eq(origpos, fn.getcurpos())
    end)

    it("should be unaffected by 'autoindent' with V\".2p", function()
      command('set autoindent')
      feed('i test_string.<esc>u')
      feed('V".2p')
      expect([[
       test_string.
       test_string.
      Line of words 2]])
    end)
  end)
end)
