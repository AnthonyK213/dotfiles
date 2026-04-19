local tutil = require("nviq.util.t")

---Represents an operation which will produce values in the future.
---@class nviq.futures.Future
---@field private m_action function Function that represents the code to execute.
---@field private m_varargs table Arguments for `action`.
---@field private m_result any[] Result of the `Future`, stored in a list.
local Future = {}

---@private
Future.__index = Future

---Constructor.
---@param action function Function that represents the code to execute.
---@param ... any Arguments for `action`.
---@return nviq.futures.Future
function Future.new(action, ...)
  local future = {
    m_action = action,
    m_varargs = tutil.pack(...)
  }
  setmetatable(future, Future)
  return future
end

---Poll the future.
function Future:poll()
  self.m_result = tutil.pack(self.m_action(tutil.unpack(self.m_varargs)))
  return tutil.unpack(self.m_result)
end

return Future
