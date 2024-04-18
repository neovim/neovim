local t = require('test.functional.testutil')()
local clear = t.clear
local command = t.command
local eq = t.eq
local eval = t.eval

-- oldtest: Test_missing_attr()
describe('synIDattr()', function()
  setup(clear)

  local bool_attrs = {
    'bold',
    'italic',
    'reverse',
    'standout',
    'underline',
    'undercurl',
    'underdouble',
    'underdotted',
    'underdashed',
    'strikethrough',
    'nocombine',
  }

  describe(':hi Mine cterm=NONE gui=NONE', function()
    setup(function()
      command(':hi Mine cterm=NONE gui=NONE')
    end)

    it('"name"', function()
      eq('Mine', eval([[synIDattr(hlID("Mine"), "name")]]))
    end)

    local function none_test(attr, mode)
      it(('"%s"'):format(attr), function()
        eq('', eval(([[synIDattr(hlID("Mine"), "%s", '%s')]]):format(attr, mode)))
      end)
    end

    for _, mode in ipairs({ 'cterm', 'gui' }) do
      describe(('"%s"'):format(mode), function()
        for _, attr in ipairs(bool_attrs) do
          none_test(attr, mode)
        end
        for _, attr in ipairs({ 'inverse', 'bg', 'fg', 'sp' }) do
          none_test(attr, mode)
        end
      end)
    end
  end)

  local function attr_test(attr1, attr2)
    local cmd = (':hi Mine cterm=%s gui=%s'):format(attr1, attr2)
    it(cmd, function()
      command(cmd)
      eq('1', eval(([[synIDattr("Mine"->hlID(), "%s", 'cterm')]]):format(attr1)))
      eq('', eval(([[synIDattr(hlID("Mine"), "%s", 'cterm')]]):format(attr2)))
      eq('', eval(([[synIDattr("Mine"->hlID(), "%s", 'gui')]]):format(attr1)))
      eq('1', eval(([[synIDattr(hlID("Mine"), "%s", 'gui')]]):format(attr2)))
    end)
  end

  for i, attr1 in ipairs(bool_attrs) do
    local attr2 = bool_attrs[i - 1] or bool_attrs[#bool_attrs]
    attr_test(attr1, attr2)
    attr_test(attr2, attr1)
  end

  it(':hi Mine cterm=reverse gui=inverse', function()
    command(':hi Mine cterm=reverse gui=inverse')
    eq('1', eval([[synIDattr(hlID("Mine"), "reverse", 'cterm')]]))
    eq('1', eval([[synIDattr(hlID("Mine"), "inverse", 'cterm')]]))
    eq('1', eval([[synIDattr(hlID("Mine"), "reverse", 'gui')]]))
    eq('1', eval([[synIDattr(hlID("Mine"), "inverse", 'gui')]]))
  end)
end)
