local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local describe, it, before_each = t.describe, t.it, t.before_each
local clear = n.clear
local exec_lua = n.exec_lua
local eq = t.eq
local pcall_err = t.pcall_err
local matches = t.matches

describe('vim.base64', function()
  before_each(clear)

  local function encode(s)
    return exec_lua([[return vim.base64.encode(...)]], s)
  end

  local function decode(s)
    return exec_lua([[return vim.base64.decode(...)]], s)
  end

  it('works', function()
    local values = {
      '',
      'Many hands make light work.',
      [[
        Call me Ishmael. Some years ago—never mind how long precisely—having little or no money in
        my purse, and nothing particular to interest me on shore, I thought I would sail about a
        little and see the watery part of the world.
      ]],
      [[
        It is a truth universally acknowledged, that a single man in possession of a good fortune,
        must be in want of a wife.
      ]],
      'Happy families are all alike; every unhappy family is unhappy in its own way.',
      'ЁЂЃЄЅІЇЈЉЊЋЌЍЎЏАБВГДЕЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯабвгдежзийклмнопрстуфхцчшщъыьэюя',
      'ÅÍÎÏ˝ÓÔÒÚÆ☃',
      '𐐜 𐐔𐐇𐐝𐐀𐐡𐐇𐐓 𐐙𐐊𐐡𐐝𐐓/𐐝𐐇𐐗𐐊𐐤𐐔 𐐒𐐋𐐗 𐐒𐐌 𐐜 𐐡𐐀𐐖𐐇𐐤𐐓𐐝 𐐱𐑂 𐑄 𐐔𐐇𐐝𐐀𐐡𐐇𐐓 𐐏𐐆𐐅𐐤𐐆𐐚𐐊𐐡𐐝𐐆𐐓𐐆',
      '👨‍👩‍👦 👨‍👩‍👧‍👦 👨‍👨‍👦 👩‍👩‍👧 👨‍👦 👨‍👧‍👦 👩‍👦 👩‍👧‍👦',
      'مُنَاقَشَةُ سُبُلِ اِسْتِخْدَامِ اللُّغَةِ فِي النُّظُمِ الْقَائِمَةِ وَفِيم يَخُصَّ التَّطْبِيقَاتُ الْحاسُوبِيَّةُ،',
      [[
        Ṱ̺̺̕o͞ ̷i̲̬͇̪͙n̝̗͕v̟̜̘̦͟o̶̙̰̠kè͚̮̺̪̹̱̤ ̖t̝͕̳̣̻̪͞h̼͓̲̦̳̘̲e͇̣̰̦̬͎ ̢̼̻̱̘h͚͎͙̜̣̲ͅi̦̲̣̰̤v̻͍e̺̭̳̪̰-m̢iͅn̖̺̞̲̯̰d̵̼̟͙̩̼̘̳ ̞̥̱̳̭r̛̗̘e͙p͠r̼̞̻̭̗e̺̠̣͟s̘͇̳͍̝͉e͉̥̯̞̲͚̬͜ǹ̬͎͎̟̖͇̤t͍̬̤͓̼̭͘ͅi̪̱n͠g̴͉ ͏͉ͅc̬̟h͡a̫̻̯͘o̫̟̖͍̙̝͉s̗̦̲.̨̹͈̣
        ̡͓̞ͅI̗̘̦͝n͇͇͙v̮̫ok̲̫̙͈i̖͙̭̹̠̞n̡̻̮̣̺g̲͈͙̭͙̬͎ ̰t͔̦h̞̲e̢̤ ͍̬̲͖f̴̘͕̣è͖ẹ̥̩l͖͔͚i͓͚̦͠n͖͍̗͓̳̮g͍ ̨o͚̪͡f̘̣̬ ̖̘͖̟͙̮c҉͔̫͖͓͇͖ͅh̵̤̣͚͔á̗̼͕ͅo̼̣̥s̱͈̺̖̦̻͢.̛̖̞̠̫̰
        ̗̺͖̹̯͓Ṯ̤͍̥͇͈h̲́e͏͓̼̗̙̼̣͔ ͇̜̱̠͓͍ͅN͕͠e̗̱z̘̝̜̺͙p̤̺̹͍̯͚e̠̻̠͜r̨̤͍̺̖͔̖̖d̠̟̭̬̝͟i̦͖̩͓͔̤a̠̗̬͉̙n͚͜ ̻̞̰͚ͅh̵͉i̳̞v̢͇ḙ͎͟-҉̭̩̼͔m̤̭̫i͕͇̝̦n̗͙ḍ̟ ̯̲͕͞ǫ̟̯̰̲͙̻̝f ̪̰̰̗̖̭̘͘c̦͍̲̞͍̩̙ḥ͚a̮͎̟̙͜ơ̩̹͎s̤.̝̝ ҉Z̡̖̜͖̰̣͉̜a͖̰͙̬͡l̲̫̳͍̩g̡̟̼̱͚̞̬ͅo̗͜.̟
        ̦H̬̤̗̤͝e͜ ̜̥̝̻͍̟́w̕h̖̯͓o̝͙̖͎̱̮ ҉̺̙̞̟͈W̷̼̭a̺̪͍į͈͕̭͙̯̜t̶̼̮s̘͙͖̕ ̠̫̠B̻͍͙͉̳ͅe̵h̵̬͇̫͙i̹͓̳̳̮͎̫̕n͟d̴̪̜̖ ̰͉̩͇͙̲͞ͅT͖̼͓̪͢h͏͓̮̻e̬̝̟ͅ ̤̹̝W͙̞̝͔͇͝ͅa͏͓͔̹̼̣l̴͔̰̤̟͔ḽ̫.͕
        Z̮̞̠͙͔ͅḀ̗̞͈̻̗Ḷ͙͎̯̹̞͓G̻O̭̗̮
      ]],
      'Hello\0world',
    }

    for _, v in ipairs(values) do
      eq(v, decode(encode(v)))
    end

    -- Explicitly check encoded output
    eq(
      'VGhlIHF1aWNrIGJyb3duIGZveCBqdW1wcyBvdmVyIHRoZSBsYXp5IGRvZwo=',
      encode('The quick brown fox jumps over the lazy dog\n')
    )

    -- Test vectors from rfc4648
    local rfc4648 = {
      { '', '' },
      { 'f', 'Zg==' },
      { 'fo', 'Zm8=' },
      { 'foo', 'Zm9v' },
      { 'foob', 'Zm9vYg==' },
      { 'fooba', 'Zm9vYmE=' },
      { 'foobar', 'Zm9vYmFy' },
    }

    for _, v in ipairs(rfc4648) do
      local input = v[1]
      local output = v[2]
      eq(output, encode(input))
      eq(input, decode(output))
    end
  end)

  it('detects invalid input', function()
    local invalid = {
      'A',
      'AA',
      'AAA',
      'A..A',
      'AA=A',
      'AA/=',
      'A/==',
      'A===',
      '====',
      'Zm9vYmFyZm9vYmFyA..A',
      'Zm9vYmFyZm9vYmFyAA=A',
      'Zm9vYmFyZm9vYmFyAA/=',
      'Zm9vYmFyZm9vYmFyA/==',
      'Zm9vYmFyZm9vYmFyA===',
      'A..AZm9vYmFyZm9vYmFy',
      'Zm9vYmFyZm9vAA=A',
      'Zm9vYmFyZm9vAA/=',
      'Zm9vYmFyZm9vA/==',
      'Zm9vYmFyZm9vA===',
    }

    for _, v in ipairs(invalid) do
      eq('Invalid input', pcall_err(decode, v))
    end

    eq('Expected 1 argument', pcall_err(encode))
    eq('Expected 1 argument', pcall_err(decode))
    matches('expected string', pcall_err(encode, 42))
    matches('expected string', pcall_err(decode, 42))
  end)
end)
