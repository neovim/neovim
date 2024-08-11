--- @meta

do -- Mark block as optional
  ---Mark a test as placeholder.
  ---
  ---This will not fail or pass, it will simply be marked as "pending".
  ---@param name string
  ---@param block? fun()
  function pending(name, block) end
end
