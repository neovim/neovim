--- @meta

--- @param name string
--- @param fn? fun()
function it(name, fn) end

--- @param name string
--- @param fn fun()
function describe(name, fn) end

--- @param name? string
--- @param block? fun()|string
function pending(name, block) end

--- @param fn fun()
function setup(fn) end

--- @param fn fun()
function before_each(fn) end

--- @param fn fun()
function after_each(fn) end

--- @param fn fun()
function teardown(fn) end

--- @param fn fun()
function finally(fn) end
