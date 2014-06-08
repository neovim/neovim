-- a set class for fast union/diff, can always return a table with the lines
-- in the same relative order in which they were added by calling the
-- to_table method. It does this by keeping two lua tables that mirror each
-- other:
-- 1) index => item
-- 2) item => index
class Set
  new: (items) =>
    if type(items) == 'table'
      tempset = Set()
      tempset\union_table(items)
      @tbl = tempset\raw_tbl!
      @items = tempset\raw_items!
      @nelem = tempset\size!
    else
      @tbl = {}
      @items = {}
      @nelem = 0

  -- adds the argument Set to this Set
  union: (other) =>
    for e in other\iterator!
      @add(e)

  -- adds the argument table to this Set
  union_table: (t) =>
    for k,v in pairs(t)
      @add(v)

  -- subtracts the argument Set from this Set
  diff: (other) =>
    if other\size! > @size!
      -- this set is smaller than the other set
      for e in @iterator!
        if other\contains(e)
          @remove(e)
    else
      -- this set is larger than the other set
      for e in other\iterator!
        if @items[e]
          @remove(e)

  add: (it) =>
    if not @contains(it)
      idx = #@tbl + 1
      @tbl[idx] = it
      @items[it] = idx
      @nelem += 1

  remove: (it) =>
    if @contains(it)
      idx = @items[it]
      @tbl[idx] = nil
      @items[it] = nil
      @nelem -= 1

  contains: (it) =>
    @items[it] or false

  size: => @nelem
  raw_tbl: => @tbl
  raw_items: => @items
  iterator: => pairs(@items)

  to_table: =>
    -- there might be gaps in @tbl, so we have to be careful and sort first
    keys = [idx for idx, _ in pairs(@tbl)]
    table.sort(keys)
    copy = [@tbl[idx] for idx in *keys]
    copy

return Set
