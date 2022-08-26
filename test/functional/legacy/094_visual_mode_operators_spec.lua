-- Test for Visual mode and operators.
--
-- Tests for the two kinds of operations: Those executed with Visual mode
-- followed by an operator and those executed via Operator-pending mode. Also
-- part of the test are mappings, counts, and repetition with the . command.

local helpers = require('test.functional.helpers')(after_each)
local feed, insert, source = helpers.feed, helpers.insert, helpers.source
local clear, feed_command, expect = helpers.clear, helpers.feed_command, helpers.expect

-- Vim script user functions needed for some of the test cases.
local function source_user_functions()
  source([[
    function MoveToCap()
      call search('\u', 'W')
    endfunction
    function SelectInCaps()
      let [line1, col1] = searchpos('\u', 'bcnW')
      let [line2, col2] = searchpos('.\u', 'nW')
      call setpos("'<", [0, line1, col1, 0])
      call setpos("'>", [0, line2, col2, 0])
      normal! gv
    endfunction
  ]])
end

local function put_abc()
  source([[
    $put ='a'
    $put ='b'
    $put ='c']])
end

local function put_aaabbbccc()
  source([[
    $put ='aaa'
    $put ='bbb'
    $put ='ccc']])
end

local function define_select_mode_maps()
  source([[
    snoremap <lt>End> <End>
    snoremap <lt>Down> <Down>
    snoremap <lt>Del> <Del>]])
end

describe('Visual mode and operator', function()
  before_each(function()
    clear()
    source_user_functions()
  end)

  it('simple change in Visual mode', function()
    insert([[
      apple banana cherry

      line 1 line 1
      line 2 line 2
      line 3 line 3
      line 4 line 4
      line 5 line 5
      line 6 line 6

      xxxxxxxxxxxxx
      xxxxxxxxxxxxx
      xxxxxxxxxxxxx
      xxxxxxxxxxxxx]])

    -- Exercise characterwise Visual mode plus operator, with count and repeat.
    feed_command('/^apple')
    feed('lvld.l3vd.')

    -- Same in linewise Visual mode.
    feed_command('/^line 1')
    feed('Vcnewline<esc>j.j2Vd.')

    -- Same in blockwise Visual mode.
    feed_command('/^xxxx')
    feed('<c-v>jlc  <esc>l.l2<c-v>c----<esc>l.')

    -- Assert buffer contents.
    expect([[
      a y

      newline
      newline

          --------x
          --------x
      xxxx--------x
      xxxx--------x]])
  end)

  it('Visual mode mapping', function()
    insert([[
      KiwiRaspberryDateWatermelonPeach
      JambuRambutanBananaTangerineMango]])

    -- Set up Visual mode mappings.
    feed_command('vnoremap W /\\u/s-1<CR>')
    feed_command('vnoremap iW :<C-U>call SelectInCaps()<CR>')

    -- Do a simple change using the simple vmap, also with count and repeat.
    feed_command('/^Kiwi')
    feed('vWcNo<esc>l.fD2vd.')

    -- Same, using the vmap that maps to an Ex command.
    feed_command('/^Jambu')
    feed('llviWc-<esc>l.l2vdl.')

    -- Assert buffer contents.
    expect([[
      NoNoberryach
      --ago]])
  end)

  it('Operator-pending mode mapping', function()
    insert([[
      PineappleQuinceLoganberryOrangeGrapefruitKiwiZ
      JuniperDurianZ
      LemonNectarineZ]])

    -- Set up Operator-pending mode mappings.
    feed_command('onoremap W /\\u/<CR>')
    feed_command('onoremap <Leader>W :<C-U>call MoveToCap()<CR>')
    feed_command('onoremap iW :<C-U>call SelectInCaps()<CR>')

    -- Do a simple change using the simple omap, also with count and repeat.
    feed_command('/^Pineapple')
    feed('cW-<esc>l.l2.l.')

    -- Same, using the omap that maps to an Ex command to move the cursor.
    feed_command('/^Juniper')
    feed('g?\\WfD.')

    -- Same, using the omap that uses Ex and Visual mode (custom text object).
    feed_command('/^Lemon')
    feed('yiWPlciWNew<esc>fr.')

    -- Assert buffer contents.
    expect([[
      ----Z
      WhavcreQhevnaZ
      LemonNewNewZ]])
  end)

  -- Vim patch 7.3.879 addressed a bug where typing ":" (the start of an Ex
  -- command) in Operator-pending mode couldn't be aborted with Escape, the
  -- change operation implied by the operator was always executed.
  it('patch 7.3.879', function()
    insert([[
      zzzz
      zzzz]])

    -- Start a change operation consisting of operator plus Ex command, like
    -- "dV:..." etc., then either
    -- - complete the operation by pressing Enter: as a result the buffer is
    --   changed, taking into account the v/V/<c-v> modifier given; or
    -- - abort the operation by pressing Escape: no change to the buffer is
    --   carried out.
    feed_command('/^zzzz')
    feed([[dV:<cr>dv:<cr>:set noma | let v:errmsg = ''<cr>]])
    feed([[d:<cr>:set ma | put = v:errmsg =~# '^E21' ? 'ok' : 'failed'<cr>]])
    feed([[dv:<esc>dV:<esc>:set noma | let v:errmsg = ''<cr>]])
    feed([[d:<esc>:set ma | put = v:errmsg =~# '^E21' ? 'failed' : 'ok'<cr>]])

    -- Assert buffer contents.
    expect([[
      zzz
      ok
      ok]])
  end)

  describe('characterwise visual mode:', function()
    it('replace last line', function()
      source([[
        $put ='a'
        let @" = 'x']])
      feed('v$p')

      expect([[

        x]])
    end)

    it('delete middle line', function()
      put_abc()
      feed('kkv$d')

      expect([[

        b
        c]])
    end)

    it('delete middle two line', function()
      put_abc()
      feed('kkvj$d')

      expect([[

        c]])
    end)

    it('delete last line', function()
      put_abc()
      feed('v$d')

      expect([[

        a
        b
        ]])
    end)

    it('delete last two line', function()
      put_abc()
      feed('kvj$d')

      expect([[

        a
        ]])
    end)
  end)

  describe('characterwise select mode:', function()
    before_each(function()
      define_select_mode_maps()
    end)

    it('delete middle line', function()
      put_abc()
      feed('kkgh<End><Del>')

      expect([[

        b
        c]])
    end)

    it('delete middle two line', function()
      put_abc()
      feed('kkgh<Down><End><Del>')

      expect([[

        c]])
    end)

    it('delete last line', function()
      put_abc()
      feed('gh<End><Del>')

      expect([[

        a
        b
        ]])
    end)

    it('delete last two line', function()
      put_abc()
      feed('kgh<Down><End><Del>')

      expect([[

        a
        ]])
    end)
  end)

  describe('linewise select mode:', function()
    before_each(function()
      define_select_mode_maps()
    end)

    it('delete middle line', function()
      put_abc()
      feed(' kkgH<Del> ')

      expect([[

        b
        c]])
    end)

    it('delete middle two line', function()
      put_abc()
      feed('kkgH<Down><Del>')

      expect([[

        c]])
    end)

    it('delete last line', function()
      put_abc()
      feed('gH<Del>')

      expect([[

        a
        b]])
    end)

    it('delete last two line', function()
      put_abc()
      feed('kgH<Down><Del>')

      expect([[

        a]])
    end)
  end)

  describe('v_p:', function()
    it('replace last character with line register at middle line', function()
      put_aaabbbccc()
      feed_command('-2yank')
      feed('k$vp')

      expect([[

        aaa
        bb
        aaa

        ccc]])
    end)

    it('replace last character with line register at middle line selecting newline', function()
      put_aaabbbccc()
      feed_command('-2yank')
      feed('k$v$p')

      expect([[

        aaa
        bb
        aaa
        ccc]])
    end)

    it('replace last character with line register at last line', function()
      put_aaabbbccc()
      feed_command('-2yank')
      feed('$vp')

      expect([[

        aaa
        bbb
        cc
        aaa
        ]])
    end)

    it('replace last character with line register at last line selecting newline', function()
      put_aaabbbccc()
      feed_command('-2yank')
      feed('$v$p')

      expect([[

        aaa
        bbb
        cc
        aaa
        ]])
    end)
  end)

  -- luacheck: ignore 613 (Trailing whitespace in a string)
  it('gv in exclusive select mode after operation', function()
    source([[
      $put ='zzz '
      $put ='Ã¤Ã '
      set selection=exclusive]])
    feed('kv3lyjv3lpgvcxxx<Esc>')

    expect([[

      zzz 
      xxx ]])
  end)

  it('gv in exclusive select mode without operation', function()
    source([[
      $put ='zzz '
      set selection=exclusive]])
    feed('0v3l<Esc>gvcxxx<Esc>')

    expect([[

      xxx ]])
  end)
end)
