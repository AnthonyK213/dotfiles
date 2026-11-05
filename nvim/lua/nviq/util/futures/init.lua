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
  local co_cur = coroutine.running()

  if task_type == "function" then
    if co_cur then
      func = function()
        task()
        vim.uv.new_async(function()
          coroutine.resume(co_cur)
        end):send()
      end
    else
      func = task
    end
  elseif getmetatable(task) == Future then
    if co_cur then
      func = function()
        task:poll()
        vim.uv.new_async(function()
          coroutine.resume(co_cur)
        end):send()
      end
    else
      func = function() task:poll() end
    end
  else
    error("`task` is invalid.")
  end

  local co_new = coroutine.create(func)
  coroutine.resume(co_new)

  return JoinHandle.new(co_new)
end

M.Job = require("nviq.util.futures.job")

M.Process = require("nviq.util.futures.process")

M.Task = require("nviq.util.futures.task")

M.Terminal = require("nviq.util.futures.terminal")

M.ui = require("nviq.util.futures.ui")

M.uv = require("nviq.util.futures.uv")

return M
