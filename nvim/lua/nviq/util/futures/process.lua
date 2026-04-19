local lib = require("nviq.util.lib")

---@class nviq.futures.ProcessHandle
---@field private m_data uv.uv_process_t Process handle.
---@field private m_pid integer|string Process ID.
---@field private m_exited boolean
local ProcessHandle = {}

---@private
ProcessHandle.__index = ProcessHandle

---Constructor.
---@param data uv.uv_process_t Process handle.
---@param pid integer|string Process ID.
---@return nviq.futures.ProcessHandle
function ProcessHandle.new(data, pid)
  local handle = {
    m_data = data,
    m_pid = pid,
    m_exited = false,
  }
  setmetatable(handle, ProcessHandle)
  return handle
end

---Returns the PID.
function ProcessHandle:pid()
  return self.m_pid
end

---Returns whether the process had already exited or not.
function ProcessHandle:exited()
  return self.m_exited
end

---Closes the handle.
function ProcessHandle:close()
  self.m_data:close()
  self.m_exited = true
end

---Sends the specified signal to the process and kill it.
---@param signum? integer|string Signal, default `SIGTERM`.
---@return integer ok 0 or fail.
function ProcessHandle:kill(signum)
  if self.m_exited then
    return 0
  end
  local code = self.m_data:kill(signum or vim.uv.constants.SIGTERM)
  if code ~= 0 then
    self:close()
  end
  return code
end

---Provides access and control to local processes.
---@class nviq.futures.Process : nviq.futures.Awaitable
---@field private m_path string Path to the system local executable.
---@field private m_opts table See `vim.uv.spawn()`.
---@field private m_cb? fun(proc: nviq.futures.Process, code: integer, signal: integer) Callback invoked when the process exits.
---@field private m_handle? nviq.futures.ProcessHandle Process handle.
---@field private m_cb_q fun(proc: nviq.futures.Process, code: integer, signal: integer)[]
---@field private m_no_cb_q boolean Mark the process that its `m_cb_q` will not be executed.
---@field private m_on_stdout? fun(proc: nviq.futures.Process, data: string) Callback on standard output.
---@field private m_on_stderr? fun(proc: nviq.futures.Process, data: string) Callbakc on standard error.
---@field private m_stdin uv.uv_stream_t Standard input handle.
---@field private m_stdout uv.uv_stream_t Standard output handle.
---@field private m_stderr uv.uv_stream_t Standard error handle.
---@field private m_stdout_buf string[] Standard output buffer.
---@field private m_stderr_buf string[] Standard error buffer.
---@field private m_record boolean If true, `stdout` and `stderr` will be recorded into the buffer.
local Process = {}

---@private
Process.__index = Process

---Constructor.
---@param path string Path to the system local executable.
---@param options? table See `vim.uv.spawn()`.
---@return nviq.futures.Process
function Process.new(path, options)
  local process = {
    m_path = path,
    m_opts = options or {},
    m_handle = nil,
    m_cb_q = {},
    m_stdin = vim.uv.new_pipe(false),
    m_stdout = vim.uv.new_pipe(false),
    m_stderr = vim.uv.new_pipe(false),
    m_stdout_buf = {},
    m_stderr_buf = {},
    m_no_cb_q = false,
    m_record = false,
  }
  setmetatable(process, Process)
  return process
end

---Returns whether the process has exited or not.
---@return boolean
function Process:has_exited()
  if self.m_handle then
    return self.m_handle:exited()
  end
  return false
end

---Returns whether the process is valid.
---@return boolean
function Process:is_valid()
  return lib.has_exe(self.m_path, false)
end

---Sets whether to record stdout and stderr.
---@param to_record boolean Whether to record stdout and stderr.
function Process:set_record(to_record)
  self.m_record = to_record
end

---Sets stdout callback.
---@param callback fun(proc: nviq.futures.Process, data: string)
function Process:on_stdout(callback)
  self.m_on_stdout = callback
end

---Sets stderr callback.
---@param callback fun(proc: nviq.futures.Process, data: string)
function Process:on_stderr(callback)
  self.m_on_stderr = callback
end

---Returns the buffer of stdout.
---@return string[]
function Process:stdout_buf()
  return self.m_stdout_buf
end

---Returns the buffer of stderr.
---@return string[]
function Process:stderr_buf()
  return self.m_stderr_buf
end

---Starts the process.
---@return boolean ok True if process starts successfully.
function Process:start()
  if not lib.has_exe(self.m_path, true) or self:has_exited() then
    return false
  end

  self.m_stdout_buf = {}
  self.m_stderr_buf = {}
  local opt = { stdio = { self.m_stdin, self.m_stdout, self.m_stderr } }
  opt = vim.tbl_extend("keep", opt, self.m_opts)

  local handle, pid = vim.uv.spawn(self.m_path, opt, vim.schedule_wrap(function(code, signal)
    vim.uv.shutdown(self.m_stdin)
    self.m_stdout:read_stop()
    self.m_stderr:read_stop()
    self.m_stdin:close()
    self.m_stdout:close()
    self.m_stderr:close()
    self.m_handle:close()
    if not self.m_no_cb_q then
      for _, cb in ipairs(self.m_cb_q) do
        if type(cb) == "function" then
          cb(self, code, signal)
        end
      end
    end
    if type(self.m_cb) == "function" then
      self.m_cb(self, code, signal)
    end
  end))

  if not handle then return false end

  self.m_handle = ProcessHandle.new(handle, pid)

  self.m_stdout:read_start(vim.schedule_wrap(function(err, data)
    assert(not err, err)
    if data then
      if self.m_record then
        table.insert(self.m_stdout_buf, data)
      end
      if type(self.m_on_stdout) == "function" then
        self.m_on_stdout(self, data)
      end
    end
  end))

  self.m_stderr:read_start(vim.schedule_wrap(function(err, data)
    assert(not err, err)
    if data then
      if self.m_record then
        table.insert(self.m_stderr_buf, data)
      end
      if type(self.m_on_stderr) == "function" then
        self.m_on_stderr(self, data)
      end
    end
  end))

  return true
end

---Continue with a callback function `callback`.
---The process will not start automatically.
---@param callback fun(proc: nviq.futures.Process, code: integer, signal: integer)
---@return nviq.futures.Process self
function Process:continue_with(callback)
  table.insert(self.m_cb_q, callback)
  return self
end

---Await the process.
---@return integer code
---@return integer signal
function Process:await()
  local res_code, res_signal
  local co_cur = coroutine.running()
  if not co_cur then
    error("Process must await in an async block.")
  end
  self.m_cb = function(_, code, signal)
    res_code = code
    res_signal = signal
    assert(coroutine.resume(co_cur))
  end
  if self:start() and not self:has_exited() then
    coroutine.yield()
  end
  return res_code, res_signal
end

---Print `stderr`.
function Process:notify_err()
  if self.m_record and not vim.tbl_isempty(self.m_stderr_buf) then
    lib.warn(table.concat(self.m_stderr_buf))
  end
end

---Write to standard input.
---@param data string|string[] Data to write.
---@return boolean is_writable True if `stdin` is writable.
function Process:write(data)
  if vim.uv.is_writable(self.m_stdin) then
    vim.uv.write(self.m_stdin, data)
    return true
  end
  return false
end

---Write to standard input and wait for the response.
---@param data string|string[] Data to write.
---@return string? err Error message.
function Process:write_and_wait(data)
  local task = require("nviq.util.futures.task")
      .new(vim.uv.write, self.m_stdin, data)
      :set_async(true)
  if coroutine.running() then
    return task:await()
  else
    return task:wait()
  end
end

---Sends te specified signal to the process and kill it.
---@param signum? integer|string Signal, default `SIGTERM`.
---@return integer? ok 0 or fail.
function Process:kill(signum)
  if self.m_handle then
    return self.m_handle:kill(signum)
  end
end

return Process
