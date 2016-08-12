-- Test the good behavior of the live action : substitution

local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, feed, insert = helpers.clear, helpers.feed, helpers.insert
local execute, expect, eval = helpers.execute, helpers.expect, helpers.eval
local neq, source, eq = helpers.neq, helpers.source, helpers.eq
local meths, curbufmeths = helpers.meths, helpers.curbufmeths

local default_text = [[
  Inc substitution on
  two lines
]]

local function common_setup(screen, incsub, text)
  if screen then
    execute("syntax on")
    execute("set nohlsearch")
    execute("hi IncSubstitute guifg=red guibg=yellow")
    screen:attach()
    screen:set_default_attr_ignore( {{bold=true, foreground=Screen.colors.Blue}} )
    screen:set_default_attr_ids({
      [1]  = {foreground = Screen.colors.Fuchsia},
      [2]  = {foreground = Screen.colors.Brown, bold = true},
      [3]  = {foreground = Screen.colors.SlateBlue},
      [4]  = {bold = true, foreground = Screen.colors.SlateBlue},
      [5]  = {foreground = Screen.colors.DarkCyan},
      [6]  = {bold = true},
      [7]  = {underline = true, bold = true, foreground = Screen.colors.SlateBlue},
      [8]  = {foreground = Screen.colors.Slateblue, underline = true},
      [9]  = {background = Screen.colors.Yellow},
      [10] = {reverse = true},
      [11] = {reverse = true, bold=true},
      [12] = {foreground = Screen.colors.Red, background = Screen.colors.Yellow},
      [13] = {bold = true, foreground = Screen.colors.SeaGreen},
      [14] = {foreground = Screen.colors.White, background = Screen.colors.Red},
    })
  end

  if incsub then
    execute("set incsubstitute="..incsub)
  else
    execute("set incsubstitute=")
  end

  if text then
    insert(text)
  end
end

describe('IncSubstitution preserves', function()
  before_each(clear)

  it(':ls functionality', function()
    local screen = Screen.new(30,10)
    common_setup(screen, "split", "ABC")

    execute("%s/AB/BA/")
    execute("ls")

    screen:expect([[
      ~                             |
      ~                             |
      ~                             |
      ~                             |
      ~                             |
      :ls                           |
        1 %a + "[No Name]"          |
                line 1              |
      {13:Press ENTER or type command to}|
      {13: continue}^                     |
    ]])
  end)

  it('substitution with various delimiters', function()
    for _, case in pairs{"", "split", "nosplit"} do
      clear()
      insert(default_text)
      execute("set incsubstitute=" .. case)

      local delims = { '/', '#', ';', '%', ',', '@', '!', ''}
      for _,delim in pairs(delims) do
        execute("%s"..delim.."lines"..delim.."LINES"..delim.."g")
        expect([[
          Inc substitution on
          two LINES
          ]])
        execute("undo")
      end
    end
  end)

  it('the undolevels setting', function()
    for _, case in pairs{"", "split", "nosplit"} do
      clear()
      execute("set undolevels=139")
      execute("setlocal undolevels=34")
      execute("set incsubstitute=" .. case)
      insert("as")
      feed(":%s/as/glork/<enter>")
      eq(meths.get_option('undolevels'), 139)
      eq(curbufmeths.get_option('undolevels'), 34)
    end
  end)

end)

describe('IncSubstitution preserves g+/g-', function()
  before_each(clear)
  local cases = { "", "split", "nosplit" }

  local substrings = {
    ":%s/1",
    ":%s/1/",
    ":%s/1/<bs>",
    ":%s/1/a",
    ":%s/1/a<bs>",
    ":%s/1/ax",
    ":%s/1/ax<bs>",
    ":%s/1/ax<bs><bs>",
    ":%s/1/ax<bs><bs><bs>",
    ":%s/1/ax/",
    ":%s/1/ax/<bs>",
    ":%s/1/ax/<bs>/",
    ":%s/1/ax/g",
    ":%s/1/ax/g<bs>",
    ":%s/1/ax/g<bs><bs>"
  }

  local function test_notsub(substring, split, redoable)
    clear()
    execute("set incsubstitute=" .. split)

    insert("1")
    feed("o2<esc>")
    execute("undo")
    feed("o3<esc>")
    if redoable then
      feed("o4<esc>")
      feed("u")
    end
    feed(substring .. "<esc>")

    feed("g-")
    expect([[
      1
      2]])

    feed("g+")
    expect([[
      1
      3]])

    if redoable then
      feed("<c-r>")
      expect([[
        1
        3
        4]])
    end
  end

  local function test_sub(substring, split, redoable)
      if redoable then
          pending("vim")
          return
      end
    clear()

    if redoable then
        pending("vim")
        return
    end

    execute("set incsubstitute=" .. split)

    insert("1")
    feed("o2<esc>")
    execute("undo")
    feed("o3<esc>")
    if redoable then
      feed("o4<esc>")
      feed("u")
    end
    feed(substring.. "<enter>")
    feed("u")

    feed("g-")
    expect([[
      1
      2]])

    feed("g+")
    expect([[
      1
      3]])
  end

  local function test_threetree(substring, split)
    clear()

    execute("set incsubstitute=" .. split)

    insert("1")
    feed("o2<esc>")
    feed("o3<esc>")
    feed("uu")
    feed("oa<esc>")
    feed("ob<esc>")
    feed("uu")
    feed("oA<esc>")
    feed("oB<esc>")

    -- This is the undo tree (x-Axis is timeline), we're at B now
    --    ----------------A - B
    --   /
    --  | --------a - b 
    --  |/
    --  1 - 2 - 3

    feed("2u")
    feed(substring .. "<esc>")
    feed("<c-r>")
    expect([[
      1
      A]])

    feed("g-") -- go to b
    feed("2u")
    feed(substring .. "<esc>")
    feed("<c-r>")
    expect([[
      1
      a]])

    feed("g-") -- go to 3
    feed("2u")
    feed(substring .. "<esc>")
    feed("<c-r>")
    expect([[
      1
      2]])
  end


  for _, case in pairs(cases) do
    for _, str in pairs(substrings) do

      for _, redoable in pairs({true,false}) do
        it(", test_sub with "..str..", ics="..case..", redoable="..tostring(redoable),
           function()
            test_sub(str, case, redoable)
          end)

        it(", test_notsub with "..str..", ics="..case..", redoable="..tostring(redoable),
           function()
            test_notsub(str, case, redoable)
          end)
      end

      it(", test_threetree with "..str..", ics="..case,
         function()
          test_threetree(str, case)
        end)
    end

    it('with undolevels=0, ics=' .. case, function()
      clear()
      common_setup(nil, case, default_text)
      execute("set undolevels=0")

      feed("1G0")
      insert("X")
      feed(":%s/tw/MO/<esc>")
      feed("u")
      expect(default_text)
      feed("u")
      expect(string.gsub(default_text, "Inc", "XInc"))
      feed("u")

      execute("%s/tw/MO/g")
      expect(string.gsub(default_text, "tw", "MO"))
      feed("u")
      expect(default_text)
      feed("u")
      expect(string.gsub(default_text, "tw", "MO"))
    end)

    it('with undolevels=1, ics=' .. case, function()
      clear()
      local screen = Screen.new(20,10)
      common_setup(screen, case, default_text)
      execute("set undolevels=1")

      feed("1G0")
      insert("X")
      feed("IY<esc>")
      feed(":%s/tw/MO/<esc>")
      feed("u")
      expect(string.gsub(default_text, "Inc", "XInc"))
      feed("u")
      expect(default_text)

      feed(":%s/tw/MO/g<enter>")
      feed(":%s/MO/GO/g<enter>")
      feed(":%s/GO/NO/g<enter>")
      feed("u")
      expect(string.gsub(default_text, "tw", "GO"))
      feed("u")
      expect(string.gsub(default_text, "tw", "MO"))
      feed("u")

      if case == "split" then
        screen:expect([[
          ^MOo lines           |
                              |
          ~                   |
          ~                   |
          ~                   |
          ~                   |
          ~                   |
          ~                   |
          ~                   |
          Already...st change |
        ]])
      else
        screen:expect([[
          Inc substitution on |
          ^MOo lines           |
                              |
          ~                   |
          ~                   |
          ~                   |
          ~                   |
          ~                   |
          ~                   |
          Already...st change |
        ]])
      end

      screen:detach()
      
      
    end)

    it('with undolevels=2, ics=' .. case, function()
      clear()
      local screen = Screen.new(20,10)
      common_setup(screen, case, default_text)
      execute("set undolevels=2")

      feed("2GAx<esc>")
      feed("Ay<esc>")
      feed("Az<esc>")
      feed(":%s/tw/AR<esc>")
      feed("u")
      expect(string.gsub(default_text, "lines", "linesxy"))
      feed("u")
      expect(string.gsub(default_text, "lines", "linesx"))
      feed("u")
      expect(default_text)
      feed("u")

      if case == "split" then
        screen:expect([[
          two line^s           |
                              |
          ~                   |
          ~                   |
          ~                   |
          ~                   |
          ~                   |
          ~                   |
          ~                   |
          Already...st change |
        ]])
      else
        screen:expect([[
          Inc substitution on |
          two line^s           |
                              |
          ~                   |
          ~                   |
          ~                   |
          ~                   |
          ~                   |
          ~                   |
          Already...st change |
        ]])
      end

      feed(":%s/tw/MO/g<enter>")
      feed(":%s/MO/GO/g<enter>")
      feed(":%s/GO/NO/g<enter>")
      feed(":%s/NO/LO/g<enter>")
      feed("u")
      expect(string.gsub(default_text, "tw", "NO"))
      feed("u")
      expect(string.gsub(default_text, "tw", "GO"))
      feed("u")
      expect(string.gsub(default_text, "tw", "MO"))
      feed("u")

      if case == "split" then
        screen:expect([[
          ^MOo lines           |
                              |
          ~                   |
          ~                   |
          ~                   |
          ~                   |
          ~                   |
          ~                   |
          ~                   |
          Already...st change |
        ]])
      else
        screen:expect([[
          Inc substitution on |
          ^MOo lines           |
                              |
          ~                   |
          ~                   |
          ~                   |
          ~                   |
          ~                   |
          ~                   |
          Already...st change |
        ]])
      end
      screen:detach()
      
    end)

    it('with undolevels=-1, ics=' .. case, function()
      clear()
      local screen = Screen.new(20,10)
      common_setup(screen, case, default_text)

      execute("set undolevels=-1")
      feed(":%s/tw/MO/g<enter>")
      feed("u")
      if case == "split" then
        screen:expect([[
          ^MOo lines           |
                              |
          ~                   |
          ~                   |
          ~                   |
          ~                   |
          ~                   |
          ~                   |
          ~                   |
          Already...st change |
        ]])
      else
        screen:expect([[
          Inc substitution on |
          ^MOo lines           |
                              |
          ~                   |
          ~                   |
          ~                   |
          ~                   |
          ~                   |
          ~                   |
          Already...st change |
        ]])
      end
      
    end)
  end

end)


describe('IncSubstitution with incsubstitute=split', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(30,15)
    common_setup(screen, "split", default_text .. default_text)
  end)

  after_each(function()
    if screen then screen:detach() end
  end)


  it('shows split window when typing the pattern', function()
    feed(":%s/tw")
    screen:expect([[
      Inc substitution on           |
      two lines                     |
                                    |
      ~                             |
      ~                             |
      {11:[No Name] [+]                 }|
       [2]two lines                 |
       [4]two lines                 |
                                    |
      ~                             |
      ~                             |
      ~                             |
      ~                             |
      {10:[inc_sub]                     }|
      :%s/tw^                        |
    ]])
  end)

  it('shows split window with empty replacement', function()
    feed(":%s/tw/")
    screen:expect([[
      Inc substitution on           |
      o lines                       |
                                    |
      ~                             |
      ~                             |
      {11:[No Name] [+]                 }|
       [2]o lines                   |
       [4]o lines                   |
                                    |
      ~                             |
      ~                             |
      ~                             |
      ~                             |
      {10:[inc_sub]                     }|
      :%s/tw/^                       |
    ]])

    feed("x<del>")
    screen:expect([[
      Inc substitution on           |
      o lines                       |
                                    |
      ~                             |
      ~                             |
      {11:[No Name] [+]                 }|
       [2]o lines                   |
       [4]o lines                   |
                                    |
      ~                             |
      ~                             |
      ~                             |
      ~                             |
      {10:[inc_sub]                     }|
      :%s/tw/^                       |
    ]])

  end)

  it('shows split window when typing replacement', function()
    feed(":%s/tw/XX")
    screen:expect([[
      Inc substitution on           |
      XXo lines                     |
                                    |
      ~                             |
      ~                             |
      {11:[No Name] [+]                 }|
       [2]{12:XX}o lines                 |
       [4]{12:XX}o lines                 |
                                    |
      ~                             |
      ~                             |
      ~                             |
      ~                             |
      {10:[inc_sub]                     }|
      :%s/tw/XX^                     |
    ]])
  end)

  it('does not show split window for :s/', function()
    feed("2gg")
    feed(":s/tw")
    screen:expect([[
      Inc substitution on           |
      two lines                     |
      Inc substitution on           |
      two lines                     |
                                    |
      ~                             |
      ~                             |
      ~                             |
      ~                             |
      ~                             |
      ~                             |
      ~                             |
      ~                             |
      ~                             |
      :s/tw^                         |
    ]])
  end)

  it('highlights the pattern with :set hlsearch', function()
    execute("set hlsearch")
    feed(":%s/tw")
    screen:expect([[
      Inc substitution on           |
      {9:tw}o lines                     |
                                    |
      ~                             |
      ~                             |
      {11:[No Name] [+]                 }|
       [2]{9:tw}o lines                 |
       [4]{9:tw}o lines                 |
                                    |
      ~                             |
      ~                             |
      ~                             |
      ~                             |
      {10:[inc_sub]                     }|
      :%s/tw^                        |
    ]])
  end)

  it('actually replaces text', function()
    feed(":%s/tw/XX/g<enter>")

    screen:expect([[
      XXo lines                     |
      Inc substitution on           |
      ^XXo lines                     |
                                    |
      ~                             |
      ~                             |
      ~                             |
      ~                             |
      ~                             |
      ~                             |
      ~                             |
      ~                             |
      ~                             |
      ~                             |
      :%s/tw/XX/g                   |
    ]])
  end)

  it('shows correct line numbers with many lines', function()
    feed("gg")
    feed("2yy")
    feed("1000p")
    execute("1,1000s/tw/BB/g")

    feed(":%s/tw/X")
    screen:expect([[
      Inc substitution on           |
      Xo lines                      |
      Xo lines                      |
      Inc substitution on           |
      Xo lines                      |
      {11:[No Name] [+]                 }|
       [1001]{12:X}o lines               |
       [1003]{12:X}o lines               |
       [1005]{12:X}o lines               |
       [1007]{12:X}o lines               |
       [1009]{12:X}o lines               |
       [1011]{12:X}o lines               |
       [1013]{12:X}o lines               |
      {10:[inc_sub]                     }|
      :%s/tw/X^                      |
    ]])
  end)

end)

describe('Incsubstitution with incsubstitute=nosplit', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(20,10)
    common_setup(screen, "nosplit", default_text .. default_text)
  end)

  after_each(function()
    if screen then screen:detach() end
  end)

  it('does not show a split window anytime', function()
    execute("set hlsearch")

    feed(":%s/tw")
    screen:expect([[
      Inc substitution on |
      {9:tw}o lines           |
      Inc substitution on |
      {9:tw}o lines           |
                          |
      ~                   |
      ~                   |
      ~                   |
      ~                   |
      :%s/tw^              |
    ]])

    feed("/BM")
    screen:expect([[
      Inc substitution on |
      BMo lines           |
      Inc substitution on |
      BMo lines           |
                          |
      ~                   |
      ~                   |
      ~                   |
      ~                   |
      :%s/tw/BM^           |
    ]])

    feed("/")
    screen:expect([[
      Inc substitution on |
      BMo lines           |
      Inc substitution on |
      BMo lines           |
                          |
      ~                   |
      ~                   |
      ~                   |
      ~                   |
      :%s/tw/BM/^          |
    ]])

    feed("<enter>")
    screen:expect([[
      Inc substitution on |
      BMo lines           |
      Inc substitution on |
      ^BMo lines           |
                          |
      ~                   |
      ~                   |
      ~                   |
      ~                   |
      :%s/tw/BM/          |
    ]])

  end)

end)

describe('Incsubstitution with a failing expression', function()
  local screen = Screen.new(20,10)
  local cases = { "", "split", "nosplit" }

  for _, case in pairs(cases) do

    before_each(function()
      clear()
      common_setup(screen, case, default_text)
    end)

    it('in the pattern does nothing for, ics=' .. case, function()
      execute("set incsubstitute=" .. case)
      feed(":silent! %s/tw\\(/LARD/<enter>")
      expect(default_text)
    end)

    it('in the replacement deletes the matches, ics=' .. case, function()
      local replacements = { "\\='LARD", "\\=xx_novar__xx" }

      for _, repl in pairs(replacements) do
        execute("set incsubstitute=" .. case)
        feed(":silent! %s/tw/" .. repl .. "/<enter>")
        expect(string.gsub(default_text, "tw", ""))
        execute("undo")
      end
    end)

  end
end)

describe('Incsubstitution and cnoremap', function()
  local cases = { "",  "split", "nosplit" }

  for _, case in pairs(cases) do

    before_each(function()
      clear()
      common_setup(nil, case, default_text)
    end)

    it('work with remapped characters, ics=' .. case, function()
      local command = "%s/lines/LINES/g"

      for i = 1, string.len(command) do
        local c = string.sub(command, i, i)
        execute("cnoremap ".. c .. " " .. c)
      end

      execute(command)
      expect([[
        Inc substitution on
        two LINES
        ]])
    end)

    it('work then mappings move the cursor, ics=' .. case, function()
      execute("cnoremap ,S LINES/<left><left><left><left><left><left>")

      feed(":%s/lines/,Sor three <enter>")
      expect([[
        Inc substitution on
        two or three LINES
        ]])

      execute("cnoremap ;S /X/<left><left><left>")
      feed(":%s/;SI<enter>")
      expect([[
        Xnc substitution on
        two or three LXNES
        ]])

      execute("cnoremap ,T //Y/<left><left><left>")
      feed(":%s,TX<enter>")
      expect([[
        Ync substitution on
        two or three LYNES
        ]])

      execute("cnoremap ;T s//Z/<left><left><left>")
      feed(":%;TY<enter>")
      expect([[
        Znc substitution on
        two or three LZNES
        ]])
    end)

    it('work with a failing mapping, ics=' .. case, function()

      execute("cnoremap <expr> x execute('bwipeout!')[-1].'x'")
      source([[
        func! DoIt()
          bwipeout!
        endfunc]])
      --execute("cnoremap <expr> x DoIt()[-1].'x'")

      feed(":%s/tw/tox<enter>")

      -- error thrown b/c of the mapping, substitution works anyways
      neq(nil, string.find(eval('v:errmsg'), '^E523:'))
      expect(string.gsub(default_text, "tw", "tox"))
    end)

    it('work when temporarily moving the cursor, ics=' .. case, function()
      execute("cnoremap <expr> x cursor(1, 1)[-1].'x'")

      feed(":%s/tw/tox/g<enter>")
      expect(string.gsub(default_text, "tw", "tox"))
    end)

    it('work when a mapping disables incsub, ics=' .. case, function()
      execute("cnoremap <expr> x execute('set incsubstitute=')[-1]")

      feed(":%s/tw/toxa/g<enter>")
      expect(string.gsub(default_text, "tw", "toa"))
    end)

    it('work with a complex mapping, ics=' .. case, function()
      source([[cnoremap x <C-\>eextend(g:, {'fo': getcmdline()})
      \.fo<CR><C-c>:new<CR>:bw!<CR>:<C-r>=remove(g:, 'fo')<CR>x]])

      feed(":%s/tw/tox")
      feed("/<enter>")
      expect(string.gsub(default_text, "tw", "tox"))
    end)

  end
end)

describe('Incsubstitute: autocommands', function()
  before_each(clear)

  -- keys are events to be tested
  -- values are arrays like 
  --    { open = { 1 }, close = { 2, 3} } 
  -- which would mean that during the test below the event fires for 
  -- buffer 1 when opening an incsub window, and for buffers 2 and 3
  -- when closing an incsub window
  local eventsExpected = {
    BufAdd = {},
    BufDelete = { open = {2, 3} },
    BufEnter = { open = {1, 1} },
    BufFilePost = {},
    BufFilePre = {},
    BufHidden = { open = {2, 3} },
    BufLeave = { open = {2, 3} },
    BufNew = {},
    BufNewFile = {},
    BufRead = {},
    BufReadCmd = {},
    BufReadPre = {},
    BufUnload = { open = {2, 3} },
    BufWinEnter = {},
    BufWinLeave = { open = {2, 3} },
    BufWipeout = { open = {2, 3} },
    BufWrite = {},
    BufWriteCmd = {},
    BufWritePost = {},
    Syntax = {},
    FileType = {},
    WinEnter = { open = {1, 1} },
    WinLeave = { open = {2, 3} },
    CmdwinEnter = {},
    CmdwinLeave = { open = {1, 1} },
  }

  local function bufferlist(t)
    local s = ""
    for _, buffer in pairs(t) do
      s = s .. ", " .. tostring(buffer)
    end
    return s
  end

  -- fill the table with default values
  for event, _ in pairs(eventsExpected) do
    eventsExpected[event].open = eventsExpected[event].open or {}
    eventsExpected[event].close = eventsExpected[event].close or {}
  end


  local function register_autocmd(event)
    execute("let g:" .. event .. "_fired=[]")
    execute("autocmd " .. event .. " * call add(g:" .. event .. "_fired, expand('<abuf>'))")
  end

  it('are run properly when splitting', function()
    common_setup(nil, "split", default_text)

    local eventsObserved = {}
    for event, _ in pairs(eventsExpected) do
      eventsObserved[event] = {}
      register_autocmd(event)
    end

    feed(":%s/tw")

    for event, _ in pairs(eventsExpected) do
      eventsObserved[event].open = eval("g:" .. event .. "_fired")
      execute("let g:" .. event .. "_fired=[]")
    end

    feed("/<enter>")

    for event, _ in pairs(eventsExpected) do
        eventsObserved[event].close = eval("g:" .. event .. "_fired") 
    end

    for event, _ in pairs(eventsExpected) do
      eq(event .. " " .. bufferlist(eventsExpected[event].open),
         event .. " " .. bufferlist(eventsObserved[event].open))
      eq(event .. " " .. bufferlist(eventsExpected[event].close),
         event .. " " .. bufferlist(eventsObserved[event].close))
    end

  end)

  it('that close the incsub window', function()
    local openEvents = {}

    for event, _ in pairs(eventsExpected) do
      if #eventsExpected[event].open > 0 then
        openEvents[event] = true
      end
    end

    local errorEvents = {
      BufWipeout = "444",
      BufDelete = "444",
      BufUnload = "444",
      BufWinLeave = "444",
    }


    local screen = Screen.new(50,10)

    for event,_ in pairs(openEvents) do
      clear()
      common_setup(screen, "split", default_text)

      execute("autocmd " .. event .. " * close!")
      feed(":%s/.")

      if errorEvents[event] then
        feed("<enter>")
        local err = errorEvents[event]
        local errstr = string.find(eval('v:errmsg'), '^E' .. err .. ':')
        neq(event .. "nil", event .. tostring(errstr))
      else
        screen:expect([[
          two lines                                         |
          {11:[No Name] [+]                                     }|
           [1]Inc substitution on                           |
           [2]two lines                                     |
                                                            |
          ~                                                 |
          ~                                                 |
          ~                                                 |
          {10:[inc_sub]                                         }|
          :%s/.^                                             |
        ]])
      end
    end
  end)

  it('that close the window of the original buffer', function()
    local openEvents = {}

    for event, _ in pairs(eventsExpected) do
      if #eventsExpected[event].open > 0 then
        openEvents[event] = true
      end
    end

    local errorEvents = {
      BufWipeout = "444",
      BufDelete = "444",
      BufUnload = "444",
      BufWinLeave = "444",
    }


    local screen = Screen.new(50,10)

    for event,_ in pairs(openEvents) do
      clear()
      common_setup(screen, "split", default_text)

      execute("autocmd " .. event .. " * close! 1")
      feed(":%s/.")

      if errorEvents[event] then
        feed("<enter>")
        local err = errorEvents[event]
        local errstr = string.find(eval('v:errmsg'), '^E' .. err .. ':')
        neq(event .. "nil", event .. tostring(errstr))
      else
        screen:expect([[
          two lines                                         |
          {11:[No Name] [+]                                     }|
           [1]Inc substitution on                           |
           [2]two lines                                     |
                                                            |
          ~                                                 |
          ~                                                 |
          ~                                                 |
          {10:[inc_sub]                                         }|
          :%s/.^                                             |
        ]])
      end
    end
  end)

  it('that wipe the incsub buffer', function()
    local openEvents = {}

    for event, _ in pairs(eventsExpected) do
      if #eventsExpected[event].open > 0 then
        openEvents[event] = true
      end
    end

    local screen = Screen.new(50,10)

    for event,_ in pairs(openEvents) do
      clear()
      common_setup(screen, "split", default_text)

      execute("autocmd " .. event .. " * bwipeout!")
      feed(":%s/.")

      if event == "BufWinLeave" then
        screen:expect([[
           [1]Inc substitution on                           |
           [2]two lines                                     |
                                                            |
          ~                                                 |
          ~                                                 |
          ~                                                 |
          {10:[inc_sub]                                         }|
          {14:E855: Autocommands caused command to abort}        |
          {14:E855: Autocommands caused command to abort}        |
          {13:Press ENTER or type command to continue}^           |
        ]])
      else
        screen:expect([[
          two lines                                         |
          {11:[No Name] [+]                                     }|
           [1]Inc substitution on                           |
           [2]two lines                                     |
                                                            |
          ~                                                 |
          ~                                                 |
          ~                                                 |
          {10:[inc_sub]                                         }|
          :%s/.^                                             |
        ]])
     end

    end
  end)

  it('that wipe the original buffer', function()
    local openEvents = {}

    for event, _ in pairs(eventsExpected) do
      if #eventsExpected[event].open > 0 then
        openEvents[event] = true
      end
    end

    local screen = Screen.new(50,10)

    for event,_ in pairs(openEvents) do
      clear()
      common_setup(screen, "split", default_text)

      execute("autocmd " .. event .. " * bwipeout! 1")
      feed(":%s/.")

      if event == "BufWinLeave" then
        screen:expect([[
                                                            |
          ~                                                 |
          ~                                                 |
          ~                                                 |
          {10:[inc_sub]                                         }|
          {14:E855: Autocommands caused command to abort}        |
          {14:Error detected while processing BufWinLeave Auto c}|
          {14:ommands for "*":}                                  |
          {14:E517: No buffers were wiped out: bwipeout! 1}      |
          {13:Press ENTER or type command to continue}^           |
        ]])
      else
        screen:expect([[
          two lines                                         |
          {11:[No Name] [+]                                     }|
           [1]Inc substitution on                           |
           [2]two lines                                     |
                                                            |
          ~                                                 |
          ~                                                 |
          ~                                                 |
          {10:[inc_sub]                                         }|
          :%s/.^                                             |
        ]])
     end
    end
  end)

  it('that change to another buffer', function()
    local openEvents = {}

    for event, _ in pairs(eventsExpected) do
      if #eventsExpected[event].open > 0 then
        openEvents[event] = true
      end
    end

    local screen = Screen.new(50,10)

    for event,_ in pairs(openEvents) do
      clear()
      common_setup(screen, "split", default_text)

      execute("autocmd " .. event .. " * buffer! 1")
      feed(":%s/.")

      screen:expect([[
        two lines                                         |
        {11:[No Name] [+]                                     }|
         [1]Inc substitution on                           |
         [2]two lines                                     |
                                                          |
        ~                                                 |
        ~                                                 |
        ~                                                 |
        {10:[inc_sub]                                         }|
        :%s/.^                                             |
      ]])

    end
  end)

end)

describe('Incsubstitute splits', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(40,30)
    common_setup(screen, "split", default_text)
  end)

  after_each(function()
    screen:detach()
  end)

  it('work after other splittings', function()
    execute("vsplit")
    execute("split")

    feed(":%s/tw")
    screen:expect([[
      two lines           {10:|}two lines          |
                          {10:|}                   |
      ~                   {10:|}~                  |
      ~                   {10:|}~                  |
      ~                   {10:|}~                  |
      ~                   {10:|}~                  |
      ~                   {10:|}~                  |
      ~                   {10:|}~                  |
      ~                   {10:|}~                  |
      ~                   {10:|}~                  |
      ~                   {10:|}~                  |
      ~                   {10:|}~                  |
      ~                   {10:|}~                  |
      ~                   {10:|}~                  |
      {11:[No Name] [+]       }{10:|}~                  |
      two lines           {10:|}~                  |
                          {10:|}~                  |
      ~                   {10:|}~                  |
      ~                   {10:|}~                  |
      ~                   {10:|}~                  |
      {10:[No Name] [+]        [No Name] [+]      }|
       [2]two lines                           |
                                              |
      ~                                       |
      ~                                       |
      ~                                       |
      ~                                       |
      ~                                       |
      {10:[inc_sub]                               }|
      :%s/tw^                                  |
    ]])

    feed("<esc>")
    execute("only")
    execute("split")
    execute("vsplit")

    feed(":%s/tw")
    screen:expect([[
      Inc substitution on {10:|}Inc substitution on|
      two lines           {10:|}two lines          |
                          {10:|}                   |
      ~                   {10:|}~                  |
      ~                   {10:|}~                  |
      ~                   {10:|}~                  |
      ~                   {10:|}~                  |
      ~                   {10:|}~                  |
      ~                   {10:|}~                  |
      ~                   {10:|}~                  |
      ~                   {10:|}~                  |
      ~                   {10:|}~                  |
      ~                   {10:|}~                  |
      ~                   {10:|}~                  |
      {11:[No Name] [+]        }{10:[No Name] [+]      }|
      Inc substitution on                     |
      two lines                               |
                                              |
      ~                                       |
      ~                                       |
      {10:[No Name] [+]                           }|
       [2]two lines                           |
                                              |
      ~                                       |
      ~                                       |
      ~                                       |
      ~                                       |
      ~                                       |
      {10:[inc_sub]                               }|
      :%s/tw^                                  |
    ]])
  end)

  local settings = {
  "splitbelow",
  "splitright",
  "noequalalways",
  "equalalways eadirection=ver",
  "equalalways eadirection=hor",
  "equalalways eadirection=both",
  }

  for _, setting in pairs(settings) do
    it("are not affected by " .. setting, function()

      execute("set " .. setting)

      feed(":%s/tw")
      screen:expect([[
        Inc substitution on                     |
        two lines                               |
                                                |
        ~                                       |
        ~                                       |
        ~                                       |
        ~                                       |
        ~                                       |
        ~                                       |
        ~                                       |
        ~                                       |
        ~                                       |
        ~                                       |
        ~                                       |
        ~                                       |
        ~                                       |
        ~                                       |
        ~                                       |
        ~                                       |
        ~                                       |
        {11:[No Name] [+]                           }|
         [2]two lines                           |
                                                |
        ~                                       |
        ~                                       |
        ~                                       |
        ~                                       |
        ~                                       |
        {10:[inc_sub]                               }|
        :%s/tw^                                  |
      ]])
    end)
  end

end)
