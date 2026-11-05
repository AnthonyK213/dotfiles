---@class nviq.futures.JoinHandle
---@field private m_co thread
---@field private m_waiter? thread
local JoinHandle = {}

---@private
JoinHandle.__index = JoinHandle

---Constructor.
---@param action function
---@return nviq.futures.JoinHandle
function JoinHandle.new(action)
  local handle = {}
  setmetatable(handle, JoinHandle)

  handle.m_co = coroutine.create(function()
    action()
    local waiter = handle.m_waiter
    if waiter then
      handle.m_waiter = nil
      vim.schedule(function()
        assert(coroutine.resume(waiter))
      end)
    end
  end)

  coroutine.resume(handle.m_co)

  return handle
end

---Wait for the associated thread to finish.
function JoinHandle:join()
  if coroutine.running() then
    return self:await()
  end

  vim.wait(1e8, function()
    return coroutine.status(self.m_co) == "dead"
  end)
end

---Await the spawned task.
function JoinHandle:await()
  local co_cur = coroutine.running()
  if not co_cur then
    error("JoinHandle must await in an asynchronous block.")
  end

  if coroutine.status(self.m_co) ~= "dead" then
    self.m_waiter = co_cur
    coroutine.yield()
  end
end

return JoinHandle
