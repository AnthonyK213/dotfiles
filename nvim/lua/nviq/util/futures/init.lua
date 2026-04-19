local tutil = require("nviq.util.t")

---@class nviq.futures.Awaitable
---@field m_cb? function Callback invoked when the awaitable object runs to complete.
---@field m_no_cb_q boolean Mark the task that its `m_no_cb_q` will not be executed.
---@field await fun():any
---@field start fun():boolean,...

local Future = require("nviq.util.futures.future")
local JoinHandle = require("nviq.util.futures.join_handle")

local M = {}

---Check `fut_list` for `futures.join` & `futures.select`.
---@param fut_list nviq.futures.Awaitable[]
---@return boolean
local function check_fut_list(fut_list)
  if not vim.islist(fut_list) or vim.tbl_isempty(fut_list) then
    print("fut_list should be a list-like table which is not empty.")
    return false
  end
  return true
end

---Wrap a function into an asynchronous function.
---@param func function Funtion to wrap.
---@return fun(...):nviq.futures.Future async_func Wrapped asynchronous function.
function M.async(func)
  return function(...)
    return Future.new(func, ...)
  end
end

---Await an asynchronous method or an awaitable object.
---@param awaitable nviq.futures.Awaitable Awaitable object to await.
---@return any
function M.await(awaitable)
  return awaitable:await()
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

---Polls multiple futures simultaneously.
---@param fut_list nviq.futures.Awaitable[]
---@param timeout? integer Number of milliseconds to wait, default no timeout.
---@return table result List of results once complete.
function M.join(fut_list, timeout)
  local result = {}
  local count = 0
  if not check_fut_list(fut_list) then return result end
  if type(timeout) == "number" and timeout < 0 then
    print("Invalid value for timeout.")
    return result
  end
  local fut_count = #fut_list
  local co_cur = coroutine.running()
  if co_cur and coroutine.status(co_cur) ~= "dead" then
    for i, fut in ipairs(fut_list) do
      fut.m_cb = function(...)
        result[i] = tutil.pack(...)
        count = count + 1
        if count == fut_count then
          assert(coroutine.resume(co_cur))
        end
      end
      fut:start()
    end
    if count ~= fut_count then
      if timeout then
        local timer = vim.uv.new_timer()
        assert(timer, "Failed to create timer.")
        timer:start(timeout, 0, vim.schedule_wrap(function()
          timer:stop()
          timer:close()
          if coroutine.status(co_cur) == "suspended" then
            if count ~= fut_count then
              print("Time out")
            end
            assert(coroutine.resume(co_cur))
          end
        end))
      end
      coroutine.yield()
    end
  else
    for i, fut in ipairs(fut_list) do
      fut.m_cb = function(...)
        result[i] = tutil.pack(...)
        count = count + 1
      end
      fut:start()
    end
    local ok, code = vim.wait(timeout or 1e8, function()
      return count == fut_count
    end, 10)
    if not ok then
      if code == -1 then
        print("Time out.")
      else
        print("Interrupted.")
      end
    end
  end
  return tutil.unpack(result)
end

---Polls multiple futures simultaneously,
---returns once the first future is complete.
---Callbacks of each future will be ignored.
---@param fut_list nviq.futures.Awaitable[]
function M.select(fut_list)
  local result
  if not check_fut_list(fut_list) then return result end
  local done = false
  local co_cur = coroutine.running()
  if co_cur and coroutine.status(co_cur) ~= "dead" then
    for _, fut in ipairs(fut_list) do
      fut.m_no_cb_q = true
      fut.m_cb = function(...)
        if not done then
          result = tutil.pack(...)
          done = true
          assert(coroutine.resume(co_cur))
        end
      end
      fut:start()
    end
    if not done then
      coroutine.yield()
    end
  else
    for _, fut in ipairs(fut_list) do
      fut.m_no_cb_q = true
      fut.m_cb = function(...)
        if not done then
          result = tutil.pack(...)
          done = true
        end
      end
      fut:start()
    end
    local ok, code = vim.wait(1e8, function() return done end, 10)
    if not ok then
      if code == -1 then
        print("Time out.")
      else
        print("Interrupted.")
      end
    end
  end
  return result
end

M.Job = require("nviq.util.futures.job")

M.Process = require("nviq.util.futures.process")

M.Task = require("nviq.util.futures.task")

M.Terminal = require("nviq.util.futures.terminal")

M.fs = require("nviq.util.futures.fs")

M.ui = require("nviq.util.futures.ui")

M.uv = require("nviq.util.futures.uv")

return M
