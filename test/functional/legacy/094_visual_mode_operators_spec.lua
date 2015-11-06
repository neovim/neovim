-- Test for Visual mode and operators.
--
-- Tests for the two kinds of operations: Those executed with Visual mode
-- followed by an operator and those executed via Operator-pending mode. Also
-- part of the test are mappings, counts, and repetition with the . command.

local helpers = require('test.functional.helpers')
local feed, insert, source = helpers.feed, helpers.insert, helpers.source
local clear, execute, expect = helpers.clear, helpers.execute, helpers.expect

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
    execute('/^apple')
    feed('lvld.l3vd.')

    -- Same in linewise Visual mode.
    execute('/^line 1')
    feed('Vcnewline<esc>j.j2Vd.')

    -- Same in blockwise Visual mode.
    execute('/^xxxx')
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
    execute('vnoremap W /\\u/s-1<CR>')
    execute('vnoremap iW :<C-U>call SelectInCaps()<CR>')

    -- Do a simple change using the simple vmap, also with count and repeat.
    execute('/^Kiwi')
    feed('vWcNo<esc>l.fD2vd.')

    -- Same, using the vmap that maps to an Ex command.
    execute('/^Jambu')
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
    execute('onoremap W /\\u/<CR>')
    execute('onoremap <Leader>W :<C-U>call MoveToCap()<CR>')
    execute('onoremap iW :<C-U>call SelectInCaps()<CR>')

    -- Do a simple change using the simple omap, also with count and repeat.
    execute('/^Pineapple')
    feed('cW-<esc>l.l2.l.')

    -- Same, using the omap that maps to an Ex command to move the cursor.
    execute('/^Juniper')
    feed('g?\\WfD.')

    -- Same, using the omap that uses Ex and Visual mode (custom text object).
    execute('/^Lemon')
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
    execute('/^zzzz')
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
end)
