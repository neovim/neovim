local helpers = require("test.unit.helpers")(after_each)
local eq = helpers.eq

describe('pairs and ipairs metatable support', function()
  local function collect_iter(t, iter)
    local acc = {}
    for k, v in iter(t) do
      acc[k] = v
    end
    return acc
  end

  local seq = {10, 20, 30}
  local assoc = {dog = "grey", house = "blue", bike = "red"}
  local mixed = {10, 20, dog = "grey"}

  it('behaves normally without any metatable', function()
    eq({10, 20, 30}, collect_iter(seq, ipairs))
    eq({}, collect_iter(assoc, ipairs))
    eq({10, 20}, collect_iter(mixed, ipairs))

    eq({10, 20, 30}, collect_iter(seq, pairs))
    eq({dog = "grey", house = "blue", bike = "red"}, collect_iter(assoc, pairs))
    eq({10, 20, dog = "grey"}, collect_iter(mixed, pairs))
  end)

  it('can override ipairs and pairs', function()
    -- builds a custom __ipairs/__pairs function that doubles the value of each element.
    local function make_double_iter(iter_next_fn, initial_value)
      local function double(val)
        if type(val) == "number" then
          return val * 2
        else
          return val .. val
        end
      end
      return function(t)
        local function custom_next(invariant, state)
          local next_key = iter_next_fn(invariant, state)
          if next_key and invariant[next_key] then
            return next_key, double(invariant[next_key])
          else
            return nil
          end
        end
        return custom_next, t, initial_value
      end
    end

    local mt = {
      __ipairs = make_double_iter(function(_table, index) return index + 1 end, 0),
      __pairs = make_double_iter(next, nil)
    }

    setmetatable(seq, mt)
    setmetatable(assoc, mt)
    setmetatable(mixed, mt)

    eq({20, 40, 60}, collect_iter(seq, ipairs))
    eq({}, collect_iter(assoc, ipairs))
    eq({20, 40}, collect_iter(mixed, ipairs))

    eq({20, 40, 60}, collect_iter(seq, pairs))
    eq({dog = "greygrey", bike = "redred", house = "blueblue"}, collect_iter(assoc, pairs))
    eq({20, 40, dog = "greygrey"}, collect_iter(mixed, pairs))
  end)
end)
