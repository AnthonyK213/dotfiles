---Adapters for `vim.async` callback boundaries and owned resources.
---
---Do not call `nviq.util.futures.*:await()` inside a `vim.async` task, and do
---not call `vim.async.await()` inside `futures.spawn()`. Complete call chains
---must use one coroutine scheduler.
local async = vim.async

---@class nviq.util.a
local M = {
  task = {},
  ui = {},
  process = {},
  job = {},
  terminal = {},
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

---Starts a top-level task and reports an unobserved error.
---Only use this at a synchronous entry point. Use `vim.async.run()` for an
---attached child task inside an asynchronous context.
---@param ... any See `vim.async.run()`.
---@return vim.async.Task
function M.task.start(...)
  return async.run(...):raise_on_error()
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
  local signal, force_signal, grace = resolve_cancel_opts(cancel_opts)

  return async.await(function(done)
    ---@type vim.SystemObj?
    local process
    ---@type uv.uv_timer_t?
    local timer
    local finished = false
    local closing = false
    local close_callbacks = {}

    local function finish_close()
      local callbacks = close_callbacks
      close_callbacks = {}
      for _, callback in ipairs(callbacks) do
        callback()
      end
    end

    local function finish(result)
      if finished then
        return
      end

      finished = true
      close_timer(timer)
      timer = nil

      done(result)
      finish_close()
    end

    process = vim.system(cmd, opts, vim.schedule_wrap(finish))

    ---@type vim.async.Closable
    local closable = {
      is_closing = function()
        -- Do not forward `process:is_closing()` here. Its process handle can be
        -- closing while stdout and stderr are still being drained.
        return closing or finished
      end,

      close = function(_, callback)
        if callback then
          table.insert(close_callbacks, callback)
        end

        if finished then
          finish_close()
          return
        elseif closing then
          return
        end

        closing = true

        if not process:is_closing() then
          process:kill(signal)
        end

        if finished or process:is_closing() then
          return
        end

        timer = assert(vim.uv.new_timer())
        timer:start(grace, 0, function()
          close_timer(timer)
          timer = nil

          if not finished and not process:is_closing() then
            process:kill(force_signal)
          end
        end)
      end,
    }

    return closable
  end)
end

return M
