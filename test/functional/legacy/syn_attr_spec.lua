local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local command = helpers.command
local eq = helpers.eq
local eval = helpers.eval

before_each(clear)

-- oldtest: Test_missing_attr()
it('synIDattr() works', function()
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

  command('hi Mine cterm=NONE gui=NONE')
  eq('Mine', eval([[synIDattr(hlID("Mine"), "name")]]))
  for _, mode in ipairs({'cterm', 'gui'}) do
    eq('', eval(([[synIDattr("Mine"->hlID(), "bg", '%s')]]):format(mode)))
    eq('', eval(([[synIDattr("Mine"->hlID(), "fg", '%s')]]):format(mode)))
    eq('', eval(([[synIDattr("Mine"->hlID(), "sp", '%s')]]):format(mode)))
    for _, attr in ipairs(bool_attrs) do
      eq('', eval(([[synIDattr(hlID("Mine"), "%s", '%s')]]):format(attr, mode)))
      eq('', eval(([[synIDattr(hlID("Mine"), "%s", '%s')]]):format(attr, mode)))
      eq('', eval(([[synIDattr(hlID("Mine"), "%s", '%s')]]):format(attr, mode)))
    end
    eq('', eval(([[synIDattr(hlID("Mine"), "inverse", '%s')]]):format(mode)))
  end

  for i, attr1 in ipairs(bool_attrs) do
    local attr2 = bool_attrs[i - 1] or bool_attrs[#bool_attrs]

    command(('hi Mine cterm=%s gui=%s'):format(attr1, attr2))
    eq('1', eval(([[synIDattr(hlID("Mine"), "%s", 'cterm')]]):format(attr1)))
    eq('', eval(([[synIDattr(hlID("Mine"), "%s", 'cterm')]]):format(attr2)))
    eq('', eval(([[synIDattr("Mine"->hlID(), "%s", 'gui')]]):format(attr1)))
    eq('1', eval(([[synIDattr("Mine"->hlID(), "%s", 'gui')]]):format(attr2)))

    command(('hi Mine cterm=%s gui=%s'):format(attr2, attr1))
    eq('', eval(([[synIDattr("Mine"->hlID(), "%s", 'cterm')]]):format(attr1)))
    eq('1', eval(([[synIDattr("Mine"->hlID(), "%s", 'cterm')]]):format(attr2)))
    eq('1', eval(([[synIDattr(hlID("Mine"), "%s", 'gui')]]):format(attr1)))
    eq('', eval(([[synIDattr(hlID("Mine"), "%s", 'gui')]]):format(attr2)))
  end

  command('hi Mine cterm=reverse gui=inverse')
  eq('1', eval([[synIDattr(hlID("Mine"), "reverse", 'cterm')]]))
  eq('1', eval([[synIDattr(hlID("Mine"), "inverse", 'cterm')]]))
  eq('1', eval([[synIDattr(hlID("Mine"), "reverse", 'gui')]]))
  eq('1', eval([[synIDattr(hlID("Mine"), "inverse", 'gui')]]))
end)
