local tutil = require("nviq.util.t")

---Represents an asynchronous operation.
---@class nviq.futures.Task : nviq.futures.Awaitable
---@field private m_action function Function that represents the code to execute in the task.
---@field private m_varargs nviq.util.t.Pack Arguments for `action`.
---@field private m_async boolean|integer Whether `m_action` is asynchronous or not, default `false`.
---@field private m_cb? function Callback invoked when the task runs to complete.
---@field private m_cb_q function[]
---@field private m_no_cb_q boolean Mark the task that its `m_no_cb_q` will not be executed.
---@field private m_handle? uv.luv_work_ctx_t Task handle.
---@field private m_result table Result of the task, stored in a packed table.
---@field private m_status 0|-1|-2 Task status, 0: Created; -1: Running; -2: RanToCompletion
local Task = {}

---@private
Task.__index = Task

---Constructor.
---@param action function Function that represents the code to execute in the task.
---@param ... any Arguments.
---  - `hash_table`: "is_async", "args", "callback"
---  - `list_like_table` | `not nil`: varargs
---@return nviq.futures.Task
function Task.new(action, ...)
  local task = {
    m_action = action,
    m_async = false,
    m_cb_q = {},
    m_no_cb_q = false,
    m_status = 0,
    m_varargs = tutil.pack(...),
  }
  setmetatable(task, Task)
  return task
end

---If set `true`, regard `action` as an asynchronous function;
---if set an integer `n`, regard it as an asynchronous function with the nth
---argument to be the callback function.
---@param is_async boolean|integer
---@return nviq.futures.Task
function Task:set_async(is_async)
  self.m_async = is_async
  return self
end

---Start the task.
---@return boolean ok True if the thread starts successfully.
function Task:start()
  if self.m_status ~= 0 then return false end
  local cb = vim.schedule_wrap(function(...)
    self.m_status = -2
    if not self.m_no_cb_q then
      for _, f in ipairs(self.m_cb_q) do
        if type(f) == "function" then
          f(...)
        end
      end
    end
    if type(self.m_cb) == "function" then
      self.m_cb(...)
    end
  end)
  self.m_status = -1
  if self.m_async then
    -- Avoid modifying the structure of table `self.varargs`.
    local args = tutil.pack(tutil.unpack(self.m_varargs))
    if type(self.m_async) == "number" then
      if self.m_async > 0 and self.m_async <= args.n then
        tutil.insert(args, self.m_async + 0, cb)
      else
        error("Invalid `is_async`.")
      end
    else
      args[args.n + 1] = cb
      args.n = args.n + 1
    end
    self.m_handle = self.m_action(tutil.unpack(args))
    return true
  end
  self.m_handle = vim.uv.new_work(self.m_action, cb)
  return self.m_handle:queue(tutil.unpack(self.m_varargs)) or false
end

---Continue with a callback function `callback`.
---The task will not start automatically.
---@param callback function
---@return nviq.futures.Task self
function Task:continue_with(callback)
  if self.m_status == 0 then
    table.insert(self.m_cb_q, callback)
  end
  return self
end

---Await the task.
---@return any
function Task:await()
  local co_cur = coroutine.running()
  if not co_cur or coroutine.status(co_cur) == "dead" then
    error("Task must await in an active async block.")
  end
  if self.m_status == 0 then
    self.m_cb = function(...)
      self.m_result = tutil.pack(...)
      assert(coroutine.resume(co_cur))
    end
    if self:start() then
      if self.m_status == -1 then
        coroutine.yield()
      end
      return tutil.unpack(self.m_result)
    end
  end
end

---Blocking wait for the task.
---@param timeout? integer Timeout.
function Task:wait(timeout)
  if self.m_status == 0 then
    self.m_cb = function(...)
      self.m_result = tutil.pack(...)
    end
    if self:start() then
      vim.wait(timeout or 1e8, function()
        return self.m_status == -2
      end)
      return tutil.unpack(self.m_result)
    end
  end
end

---Creates a task that will complete after a time delay (ms).
---@param delay integer Delay in milliseconds.
---@return nviq.futures.Task task
function Task.delay(delay)
  return Task.new(vim.defer_fn, delay):set_async(1)
end

---Reset the task.
function Task:reset()
  self.m_status = 0
  self.m_cb = nil
  self.m_cb_q = {}
  self.m_no_cb_q = false
  self.m_result = nil
  self.m_handle = nil
end

return Task
