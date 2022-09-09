vim.o.spelloptions = ""
vim.o.spelllang = "en"
vim.o.spell = true

local spell_time = 0
local sugg_time = 0
local ITERATIONS = 10

local function time(func, ...)
  local start_time = vim.loop.hrtime()
  local res = func(...)
  return vim.loop.hrtime() - start_time, res
end

local spell_errors = 0
local sugg_errors = 0
for i = 1, ITERATIONS do
  local file = io.open("words", "r")
  if not file then
    error "Could not open wordlist"
  end

  print(i)
  spell_errors = 0
  for line in function() return file:read "*l" end do
    local bad, suggs_plain = unpack(vim.split(line, "\t", { plain = true }))
    print(bad)

    local suggs = vim.split(suggs_plain, ', ', { plain = true, trimempty = true })

    local stime, bad_spell = time(vim.spell.check, bad)
    spell_time = spell_time + stime
    bad_spell = bad_spell[1]

    if bad_spell and bad ~= bad_spell[1] then
      if #suggs > 0 then
        spell_errors = spell_errors + 1
      end
    end

    local sug_dtime, ret_suggs = time(vim.fn.spellsuggest, bad)
    sugg_time = sugg_time + sug_dtime

    for _, s in ipairs(suggs) do
      if not vim.tbl_contains(ret_suggs, s) then
        sugg_errors = spell_errors + 1
      end
    end
  end
end

-- nr iterations + conversion from nanos to millis
local factor = ITERATIONS * 1000 * 1000
print(spell_errors, spell_time / factor)
print(sugg_errors, sugg_time / factor)

vim.cmd.quit()
