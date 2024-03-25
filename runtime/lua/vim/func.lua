local M = {}

-- TODO(lewis6991): Private for now until:
-- - There are other places in the codebase that could benefit from this
--   (e.g. LSP), but might require other changes to accommodate.
-- - Invalidation of the cache needs to be controllable. Using weak tables
--   is an acceptable invalidation policy, but it shouldn't be the only
--   one.
-- - I don't think the story around `hash` is completely thought out. We
--   may be able to have a good default hash by hashing each argument,
--   so basically a better 'concat'.
-- - Need to support multi level caches. Can be done by allow `hash` to
--   return multiple values.
--
--- Memoizes a function {fn} using {hash} to hash the arguments.
---
--- Internally uses a |lua-weaktable| to cache the results of {fn} meaning the
--- cache will be invalidated whenever Lua does garbage collection.
---
--- The memoized function returns shared references so be wary about
--- mutating return values.
---
--- @generic F: function
--- @param hash integer|string|function Hash function to create a hash to use as a key to
---     store results. Possible values:
---     - When integer, refers to the index of an argument of {fn} to hash.
---     This argument can have any type.
---     - When function, is evaluated using the same arguments passed to {fn}.
---     - When `concat`, the hash is determined by string concatenating all the
---     arguments passed to {fn}.
---     - When `concat-n`, the hash is determined by string concatenating the
---     first n arguments passed to {fn}.
---
--- @param fn F Function to memoize.
--- @param strong? boolean Do not use a weak table
--- @return F # Memoized version of {fn}
--- @nodoc
function M._memoize(hash, fn, strong)
  return require('vim.func._memoize')(hash, fn, strong)
end

return M
