-- Adapters for `vim.async` callback boundaries and owned resources.

local async = vim.async

---@class nviq.util.a
local M = {
  task = {},
  process = {},
  job = {},
  terminal = {},
  ui = {},
  uv = {},
}

---Options used when cancelling an owned process.
---@class nviq.util.a.process.CancelOpts
---@field signal? integer|string Signal sent first. Defaults to `sigterm`.
---@field force_signal? integer|string Signal sent after the grace period. Defaults to `sigkill`.
---@field grace? integer Grace period in milliseconds. Defaults to 1000.

local function close_timer(timer)
  if timer and not timer:is_closing() then
    timer:stop()
    timer:close()
  end
end

---@param opts? nviq.util.a.process.CancelOpts
---@return integer|string signal
---@return integer|string force_signal
---@return integer grace
local function resolve_cancel_opts(opts)
  if opts ~= nil and type(opts) ~= "table" then
    error("`cancel_opts` must be a table", 3)
  end
  opts = opts or {}

  local grace = opts.grace
  if grace == nil then
    grace = 1000
  elseif type(grace) ~= "number" or grace < 0 or grace % 1 ~= 0 then
    error("`cancel_opts.grace` must be a non-negative integer", 3)
  end

  return opts.signal or "sigterm", opts.force_signal or "sigkill", grace
end

---@class nviq.util.a.Process : vim.async.Closable
---@field private m_process vim.SystemObj
---@field private m_result? vim.SystemCompleted
---@field private m_on_exit? fun(process: nviq.util.a.Process, result: vim.SystemCompleted)
---@field private m_waiters fun(result: vim.SystemCompleted)[]
---@field private m_close_callbacks fun()[]
---@field private m_closing boolean
---@field private m_timer? uv.uv_timer_t
---@field private m_signal integer|string
---@field private m_force_signal integer|string
---@field private m_grace integer
local Process = {}

Process.__index = Process

---@private
function Process:_finish_close()
  local callbacks = self.m_close_callbacks
  self.m_close_callbacks = {}
  for _, callback in ipairs(callbacks) do
    callback()
  end
end

---@param result vim.SystemCompleted
function Process:_finish(result)
  if self.m_result then
    return
  end

  self.m_result = result
  close_timer(self.m_timer)
  self.m_timer = nil

  local callback_error
  if self.m_on_exit then
    local on_exit = assert(self.m_on_exit)
    self.m_on_exit = nil
    local ok, err = xpcall(function()
      on_exit(self, result)
    end, debug.traceback)
    if not ok then
      callback_error = err
    end
  end

  local waiters = self.m_waiters
  self.m_waiters = {}
  for _, waiter in ipairs(waiters) do
    waiter(result)
  end
  self:_finish_close()

  if callback_error then
    error(callback_error, 0)
  end
end

---Waits for the process to exit.
---Closing the current task terminates the process and waits for its resources
---to finish closing.
---@async
---@return vim.SystemCompleted result
function Process:wait()
  ---@param done fun(result: vim.SystemCompleted)
  local function wait(done)
    if self.m_result then
      done(self.m_result)
      return
    end

    table.insert(self.m_waiters, done)

    ---The public handle reports the underlying process state. This private
    ---closable only reports adapter cleanup so cancellation cannot skip pipe
    ---draining when the process handle is already closing.
    ---@type vim.async.Closable
    local closable = {
      is_closing = function()
        return self.m_closing or self.m_result ~= nil
      end,
      close = function(_, callback)
        self:close(callback)
      end,
    }
    return closable
  end

  return async.await(wait)
end

---Writes to standard input. `opts.stdin` must have been set to `true`.
---@param data string|string[]|nil
---@return boolean writable
function Process:write(data)
  if self:is_closing() then
    return false
  end
  self.m_process:write(data)
  return true
end

---Sends a signal to the process.
---@param signal? integer|string Defaults to `sigterm`.
---@return boolean sent
function Process:kill(signal)
  if self.m_result or self.m_process:is_closing() then
    return false
  end
  self.m_process:kill(signal or "sigterm")
  return true
end

---Returns whether the process is exiting, cleaning up, or already finished.
---@return boolean
function Process:is_closing()
  return self.m_closing or self.m_result ~= nil or self.m_process:is_closing()
end

---Terminates the process and invokes `callback` after it has exited and all
---pipes have been drained. Repeated calls are safe.
---@param callback? fun()
function Process:close(callback)
  if callback then
    table.insert(self.m_close_callbacks, callback)
  end

  if self.m_result then
    self:_finish_close()
    return
  elseif self.m_closing then
    return
  end

  self.m_closing = true
  if not self.m_process:is_closing() then
    self.m_process:kill(self.m_signal)
  end

  if self.m_result or self.m_process:is_closing() then
    return
  end

  self.m_timer = assert(vim.uv.new_timer())
  self.m_timer:start(self.m_grace, 0, function()
    close_timer(self.m_timer)
    self.m_timer = nil

    if not self.m_result and not self.m_process:is_closing() then
      self.m_process:kill(self.m_force_signal)
    end
  end)
end

---@private
---@param cmd string[]
---@param opts? vim.SystemOpts
---@param on_exit? fun(process: nviq.util.a.Process, result: vim.SystemCompleted)
---@param signal integer|string
---@param force_signal integer|string
---@param grace integer
---@return nviq.util.a.Process
function Process.new(cmd, opts, on_exit, signal, force_signal, grace)
  ---@type nviq.util.a.Process
  local process = setmetatable({
    m_on_exit = on_exit,
    m_waiters = {},
    m_close_callbacks = {},
    m_closing = false,
    m_signal = signal,
    m_force_signal = force_signal,
    m_grace = grace,
  }, Process)

  process.m_process = vim.system(cmd, opts, vim.schedule_wrap(function(result)
    process:_finish(result)
  end))

  return process
end

---@class nviq.util.a.JobResult
---@field id integer
---@field code integer
---@field event string

---@class nviq.util.a.Job : vim.async.Closable
---@field private m_cmd string[]
---@field private m_opts table
---@field private m_id integer
---@field private m_result? nviq.util.a.JobResult
---@field private m_on_exit? fun(job_id: integer, code: integer, event: string)
---@field private m_waiters fun(result: nviq.util.a.JobResult)[]
---@field private m_close_callbacks fun()[]
---@field private m_closing boolean
local Job = {}

Job.__index = Job

---@private
function Job:_finish_close()
  local callbacks = self.m_close_callbacks
  self.m_close_callbacks = {}
  for _, callback in ipairs(callbacks) do
    callback()
  end
end

---@param code integer
---@param event string
function Job:_finish(code, event)
  if self.m_result then
    return
  end

  local result = {
    id = self.m_id,
    code = code,
    event = event,
  }
  self.m_result = result

  local callback_error
  if self.m_on_exit then
    local on_exit = assert(self.m_on_exit)
    self.m_on_exit = nil
    local ok, err = xpcall(function()
      on_exit(self.m_id, code, event)
    end, debug.traceback)
    if not ok then
      callback_error = err
    end
  end

  local waiters = self.m_waiters
  self.m_waiters = {}
  for _, waiter in ipairs(waiters) do
    waiter(result)
  end
  self:_finish_close()

  if callback_error then
    error(callback_error, 0)
  end
end

---Returns the command used to start the job.
---@return string[]
function Job:cmd()
  return self.m_cmd
end

---Returns the job/channel id.
---@return integer
function Job:id()
  return self.m_id
end

---Waits for the job to exit.
---Closing the current task stops the job and waits for `on_exit`.
---@async
---@return nviq.util.a.JobResult result
function Job:wait()
  ---@param done fun(result: nviq.util.a.JobResult)
  local function wait(done)
    if self.m_result then
      done(self.m_result)
      return
    end

    table.insert(self.m_waiters, done)

    local closing = false
    ---@type vim.async.Closable
    local closable = {
      is_closing = function()
        return closing or self.m_result ~= nil
      end,
      close = function(_, callback)
        closing = true
        self:close(callback)
      end,
    }
    return closable
  end

  return async.await(wait)
end

---Sends data to the job's stdin channel.
---@param data string|string[]
---@return integer sent Number of bytes written, or zero when unavailable.
function Job:send(data)
  if self.m_opts.rpc or self:is_closing() then
    return 0
  end
  return vim.fn.chansend(self.m_id, data)
end

---Returns whether the job is stopping or has exited.
---@return boolean
function Job:is_closing()
  return self.m_closing or self.m_result ~= nil
end

---Stops the job. Repeated calls are safe.
---@return boolean stopped
function Job:stop()
  if self.m_result or self.m_closing then
    return false
  end
  self.m_closing = true
  return vim.fn.jobstop(self.m_id) == 1
end

---Stops the job and invokes `callback` after `on_exit` has completed.
---@param callback? fun()
function Job:close(callback)
  if callback then
    table.insert(self.m_close_callbacks, callback)
  end

  if self.m_result then
    self:_finish_close()
    return
  end

  self:stop()
end

---@private
---@param cmd string[]
---@param options? table See `jobstart-options`.
---@param class? table
---@return nviq.util.a.Job
function Job.new(cmd, options, class)
  local opts = vim.tbl_extend("force", {}, options or {})
  local on_exit = opts.on_exit
  local on_stdout = opts.on_stdout
  local on_stderr = opts.on_stderr

  ---@type nviq.util.a.Job
  local job = setmetatable({
    m_cmd = cmd,
    m_opts = opts,
    m_id = -1,
    m_on_exit = on_exit,
    m_waiters = {},
    m_close_callbacks = {},
    m_closing = false,
  }, class or Job)

  if on_stdout then
    opts.on_stdout = vim.schedule_wrap(on_stdout)
  end
  if on_stderr then
    opts.on_stderr = vim.schedule_wrap(on_stderr)
  end
  opts.on_exit = vim.schedule_wrap(function(job_id, code, event)
    if job_id == job:id() then
      job:_finish(code, event)
    end
  end)

  job.m_id = vim.fn.jobstart(cmd, opts)
  if job.m_id == 0 then
    error("jobstart() received invalid arguments", 3)
  elseif job.m_id == -1 then
    error("Executable was not found: " .. tostring(cmd[1]), 3)
  end

  return job
end

---@class nviq.util.a.Terminal : nviq.util.a.Job
---@field private m_bufnr integer
local Terminal = {}

Terminal.__index = Terminal
setmetatable(Terminal, { __index = Job })

---Returns the terminal buffer number.
---@return integer
function Terminal:bufnr()
  return self.m_bufnr
end

---@private
---@param cmd string[]
---@param options? table See `jobstart-options`.
---@return nviq.util.a.Terminal
function Terminal.new(cmd, options)
  local winid = vim.api.nvim_get_current_win()
  local previous_buf = vim.api.nvim_win_get_buf(winid)
  local bufnr = vim.api.nvim_create_buf(false, false)
  if bufnr == 0 then
    error("Failed to create a terminal buffer", 3)
  end

  local ok, err = pcall(vim.api.nvim_win_set_buf, winid, bufnr)
  if not ok then
    vim.api.nvim_buf_delete(bufnr, { force = true })
    error(err, 3)
  end

  local opts = vim.tbl_extend("force", {}, options or {}, { term = true })
  local started, terminal = pcall(Job.new, cmd, opts, Terminal)
  if not started then
    if vim.api.nvim_win_is_valid(winid)
        and vim.api.nvim_buf_is_valid(previous_buf)
        and vim.api.nvim_win_get_buf(winid) == bufnr then
      vim.api.nvim_win_set_buf(winid, previous_buf)
    end
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
    error(terminal, 3)
  end

  terminal = terminal --[[@as nviq.util.a.Terminal]]
  terminal.m_bufnr = bufnr
  vim.api.nvim_buf_attach(bufnr, false, {
    on_detach = function()
      terminal:stop()
    end,
  })

  return terminal
end

---Starts a top-level task and reports an unobserved error.
---Only use this at a synchronous entry point. Use `vim.async.run()` for an
---attached child task inside an asynchronous context.
---@param ... any See `vim.async.run()`.
---@return vim.async.Task
function M.task.start(...)
  return async.run(...):raise_on_error()
end

---Starts a long-lived process and returns its resource handle immediately.
---The caller owns the handle and must terminate it when its buffer or module
---session ends. Call `process:wait()` when task cancellation should own it.
---@param cmd string[]
---@param opts? vim.SystemOpts
---@param on_exit? fun(process: nviq.util.a.Process, result: vim.SystemCompleted)
---@param cancel_opts? nviq.util.a.process.CancelOpts
---@return nviq.util.a.Process process
function M.process.start(cmd, opts, on_exit, cancel_opts)
  local signal, force_signal, grace = resolve_cancel_opts(cancel_opts)
  return Process.new(cmd, opts, on_exit, signal, force_signal, grace)
end

---Runs an owned process and waits for it to exit.
---
---Closing the current task sends a termination signal to the process and waits
---for `vim.system()` to finish draining and closing its pipes. If the process
---does not exit during the grace period, it is sent the force signal.
---@async
---@param cmd string[]
---@param opts? vim.SystemOpts
---@param cancel_opts? nviq.util.a.process.CancelOpts
---@return vim.SystemCompleted result
function M.process.run(cmd, opts, cancel_opts)
  return M.process.start(cmd, opts, nil, cancel_opts):wait()
end

---Starts a channel, PTY, or RPC job and returns its handle immediately.
---@param cmd string[]
---@param opts? table See `jobstart-options`.
---@return nviq.util.a.Job job
function M.job.start(cmd, opts)
  return Job.new(cmd, opts)
end

---Starts an owned job and waits for it to exit.
---@async
---@param cmd string[]
---@param opts? table See `jobstart-options`.
---@return nviq.util.a.JobResult result
function M.job.run(cmd, opts)
  return M.job.start(cmd, opts):wait()
end

---Starts a terminal job in a new buffer in the current window.
---@param cmd string[]
---@param opts? table See `jobstart-options`.
---@return nviq.util.a.Terminal terminal
function M.terminal.start(cmd, opts)
  return Terminal.new(cmd, opts)
end

---Starts an owned terminal job and waits for it to exit.
---@async
---@param cmd string[]
---@param opts? table See `jobstart-options`.
---@return nviq.util.a.JobResult result
function M.terminal.run(cmd, opts)
  return M.terminal.start(cmd, opts):wait()
end

---Prompts the user for input.
---@async
---@param opts vim.ui.input.Opts
---@return string? input
function M.ui.input(opts)
  return async.await(2, vim.ui.input, opts)
end

---Prompts the user to select an item.
---@async
---@generic T
---@param items T[]
---@param opts vim.ui.select.Opts
---@return T? item
---@return integer? index
function M.ui.select(items, opts)
  return async.await(3, vim.ui.select, items, opts)
end

---Creates a directory asynchronously.
---@async
---@param path string
---@param mode integer
---@return string? err
---@return boolean? ok
function M.uv.fs_mkdir(path, mode)
  return async.await(3, vim.uv.fs_mkdir, path, mode)
end

return M
