---@class nviq.futures.Awaitable
---@field m_cb? function Callback invoked when the awaitable object runs to complete.
---@field m_no_cb_q boolean Mark the task that its `m_no_cb_q` will not be executed.
---@field await fun():any
---@field start fun():boolean,...

local Future = require("nviq.util.futures.future")
local JoinHandle = require("nviq.util.futures.join_handle")

local M = {}

---Wrap a function into an asynchronous function.
---@param func function Funtion to wrap.
---@return fun(...):nviq.futures.Future async_func Wrapped asynchronous function.
function M.async(func)
  return function(...)
    return Future.new(func, ...)
  end
end

---Spawns a new asynchronous task.
---@param task function|nviq.futures.Future
function M.spawn(task)
  ---@type function
  local func
  local task_type = type(task)

  if task_type == "function" then
    func = task
  elseif getmetatable(task) == Future then
    func = function() task:poll() end
  else
    error("`task` is invalid.")
  end

  return JoinHandle.new(func)
end

M.Job = require("nviq.util.futures.job")

M.Process = require("nviq.util.futures.process")

M.Task = require("nviq.util.futures.task")

M.Terminal = require("nviq.util.futures.terminal")

M.ui = require("nviq.util.futures.ui")

M.uv = require("nviq.util.futures.uv")

return M
