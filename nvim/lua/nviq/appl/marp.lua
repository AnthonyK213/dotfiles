local lib = require("nviq.util.lib")
local autil = require("nviq.util.a")

local M = {}

---@class nviq.appl.marp.Session
---@field process nviq.util.a.Process
---@field stderr_tail string
---@field connected boolean

---@private
---@type table<integer, nviq.appl.marp.Session>
M.tbl = {}

---@param bufnr integer
---@param session nviq.appl.marp.Session
---@param data string
local function read_stderr(bufnr, session, data)
  if session.connected then
    return
  end

  session.stderr_tail = session.stderr_tail .. data
  local url = session.stderr_tail:match("Start server listened at (http://localhost:%d+/)")
  if not url then
    if #session.stderr_tail > 8192 then
      session.stderr_tail = session.stderr_tail:sub(-8192)
    end
    return
  end

  session.connected = true
  vim.schedule(function()
    if M.tbl[bufnr] ~= session then
      return
    end
    local _, err = vim.ui.open(url)
    if not err then
      vim.notify("Marp: Connected")
    else
      lib.warn("Marp: Failed to connect")
    end
  end)
end

---@private
---@param bufnr integer
---@return boolean
function M.is_alive(bufnr)
  local session = M.tbl[bufnr]
  return session ~= nil and not session.process:is_closing()
end

---Check if current file requires marp.
---@param bufnr? integer
---@return boolean
function M.is_marp(bufnr)
  bufnr = lib.bufnr(bufnr)
  local line_count = vim.api.nvim_buf_line_count(bufnr)

  if line_count < 3
      or not lib.has_filetype("markdown", vim.bo[bufnr].filetype)
      or vim.trim(vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1]) ~= "---" then
    return false
  end

  local sep = vim.regex [[\v^\-{3,}\s*$]]
  local m = vim.regex [[\v^marp:\s*true\s*$]]

  for i = 1, line_count - 1, 1 do
    if m:match_line(bufnr, i) then
      return true
    elseif sep:match_line(bufnr, i) then
      return false
    end
  end

  return false
end

---@private
function M.start(bufnr)
  bufnr = lib.bufnr(bufnr)

  if M.is_alive(bufnr) then
    vim.notify("marp is already running")
    return
  end

  if not lib.has_exe("marp", true) then
    return
  end

  local buf_dir = lib.buf_dir(bufnr)
  local session = {
    stderr_tail = "",
    connected = false,
  }
  session.process = autil.process.start({ "marp", "--html", "--server", buf_dir }, {
    cwd = buf_dir,
    text = true,
    stderr = function(err, data)
      if err then
        vim.schedule(function()
          if M.tbl[bufnr] == session then
            lib.warn("Marp: " .. err)
          end
        end)
      elseif data then
        read_stderr(bufnr, session, data)
      end
    end,
  }, function(_, result)
    if M.tbl[bufnr] == session then
      M.tbl[bufnr] = nil
      if result.code == 0 then
        vim.notify("Marp: Exited")
      else
        lib.warn("Marp: Exited with code " .. result.code)
      end
    end
  end)

  M.tbl[bufnr] = session
  vim.api.nvim_buf_attach(bufnr, false, {
    on_detach = function(_, h) M.stop(h) end
  })
  vim.notify("Marp: Started")
end

---@private
function M.stop(bufnr)
  bufnr = lib.bufnr(bufnr)
  local session = M.tbl[bufnr]
  if session then
    M.tbl[bufnr] = nil
    session.process:close()
  end
end

---Toggle marp server.
function M.toggle()
  local bufnr = vim.api.nvim_get_current_buf()
  if M.is_alive(bufnr) then
    M.stop(bufnr)
  else
    M.start(bufnr)
  end
end

return M
