---@class nviq.futures.JoinHandle
---@field private m_co thread
local JoinHandle = {}

---@private
JoinHandle.__index = JoinHandle

---Constructor.
---@param co thread
---@return nviq.futures.JoinHandle
function JoinHandle.new(co)
  local handle = {
    m_co = co,
  }
  setmetatable(handle, JoinHandle)
  return handle
end

---Wait for the associated thread to finish.
function JoinHandle:join()
  if not coroutine.running() then
    vim.wait(1e8, function()
      return coroutine.status(self.m_co) == "dead"
    end)
    self.m_co = nil
  else
    self:await()
  end
end

---@private
---Await the spawned task.
function JoinHandle:await()
  if not coroutine.running() then
    print("Not in any asynchronous block")
    return
  end
  while coroutine.status(self.m_co) ~= "dead" do
    coroutine.yield()
  end
  self.m_co = nil
end

return JoinHandle
