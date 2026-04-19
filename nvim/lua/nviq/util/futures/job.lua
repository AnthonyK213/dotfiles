local lib = require("nviq.util.lib")

---Represents a neovim job.
---@class nviq.futures.Job : nviq.futures.Awaitable
---@field private m_cmd string[] Command with arguments.
---@field private m_opts table See `jobstart-options`.
---@field private m_cb? fun(job: nviq.futures.Job, data: integer) Callback invoked when the job ends.
---@field private m_id integer The job id.
---@field private m_exited boolean
---@field private m_cb_q fun(job: nviq.futures.Job, data: integer)[]
---@field private m_no_cb_q boolean Mark the job that its `m_cb_q` will not be executed.
---@field private m_on_stdout? fun(job: nviq.futures.Job, data: string[]) Callback on standard output.
---@field private m_on_stderr? fun(job: nviq.futures.Job, data: string[]) Callbakc on standard error.
---@field private m_stdout_buf string[] Standard output buffer.
---@field private m_stderr_buf string[] Standard error buffer.
---@field private m_record boolean If true, `stdout` and `stderr` will be recorded into the buffer.
local Job = {}

---@private
Job.__index = Job

---Constructor.
---@param cmd string[] Command with arguments.
---@param options? table See `jobstart-options`.
---@return nviq.futures.Job
function Job.new(cmd, options)
  local job = {
    m_cmd = cmd,
    m_opts = options or {},
    m_id = -1,
    m_exited = false,
    m_cb_q = {},
    m_stdout_buf = {},
    m_stderr_buf = {},
    m_no_cb_q = false,
    m_record = false,
  }
  setmetatable(job, Job)
  return job
end

---Returns the cmd of the job.
---@return string[]
function Job:cmd()
  return self.m_cmd
end

---Returns whether the job has exited.
---@return boolean
function Job:has_exited()
  return self.m_exited
end

---Returns whether the job is valid.
---@param to_warn? boolean
---@return boolean
function Job:is_valid(to_warn)
  return lib.has_exe(self.m_cmd[1], to_warn)
end

---Sets whether to record stdout and stderr.
---@param to_record boolean Whether to record stdout and stderr.
function Job:set_record(to_record)
  self.m_record = to_record
end

---Sets stdout callback.
---@param callback fun(job: nviq.futures.Job, data: string[])
function Job:on_stdout(callback)
  self.m_on_stdout = callback
end

---Sets stderr callback.
---@param callback fun(job: nviq.futures.Job, data: string[])
function Job:on_stderr(callback)
  self.m_on_stderr = callback
end

---Returns the buffer of stdout.
---@return string[]
function Job:stdout_buf()
  return self.m_stdout_buf
end

---Returns the buffer of stderr.
---@return string[]
function Job:stderr_buf()
  return self.m_stderr_buf
end

---Starts the job.
---@return boolean
function Job:start()
  if not self:is_valid() or self:has_exited() then
    return false
  end

  self.m_opts.on_exit = vim.schedule_wrap(function(job_id, data, event)
    if self.m_id ~= job_id or event ~= "exit" then
      return
    end
    self.m_exited = true
    if not self.m_no_cb_q then
      for _, f in ipairs(self.m_cb_q) do
        if type(f) == "function" then
          f(self, data)
        end
      end
    end
    if type(self.m_cb) == "function" then
      self.m_cb(self, data)
    end
  end)

  self.m_opts.on_stdout = vim.schedule_wrap(function(_, data, _)
    if self.m_record then
      for _, d in ipairs(data) do
        table.insert(self.m_stdout_buf, d)
      end
    end
    if type(self.m_on_stdout) == "function" then
      self.m_on_stdout(self, data)
    end
  end)

  self.m_opts.on_stderr = vim.schedule_wrap(function(_, data, _)
    if self.m_record then
      for _, d in ipairs(data) do
        table.insert(self.m_stderr_buf, d)
      end
    end
    if type(self.m_on_stderr) == "function" then
      self.m_on_stderr(self, data)
    end
  end)

  self.m_id = vim.fn.jobstart(self.m_cmd, self.m_opts)
  if self.m_id == 0 then
    print("Invalid arguments.")
    return false
  elseif self.m_id == -1 then
    print("Invalid executable.")
    return false
  end

  return true
end

---Continue with a callback function `callback`.
---The job will not start automatically.
---@param callback fun(job: nviq.futures.Job, data: integer)
function Job:continue_with(callback)
  table.insert(self.m_cb_q, callback)
  return self
end

---Await the job.
---@return integer data
function Job:await()
  local res_data
  local co_cur = coroutine.running()
  if not co_cur then
    error("Job must await in an async block.")
  end
  self.m_cb = function(_, data)
    res_data = data
    assert(coroutine.resume(co_cur))
  end
  if self:start() and not self:has_exited() then
    coroutine.yield()
  end
  return res_data
end

---Sends data to the job.
---@param data string|string[]
---@return 0|1
function Job:send(data)
  if not self.m_opts.rpc then
    return vim.fn.chansend(self.m_id, data)
  end
  return 0
end

---Stops the job.
---@return integer
function Job:stop()
  return vim.fn.jobstop(self.m_id)
end

return Job
