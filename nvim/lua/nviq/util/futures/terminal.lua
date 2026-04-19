local Job = require("nviq.util.futures.job")

---Represents a neovim terminal.
---@class nviq.futures.Terminal : nviq.futures.Job
---@field private m_bufnr integer Buffer number.
local Terminal = {}

---@private
Terminal.__index = Terminal

setmetatable(Terminal, { __index = Job })

---Constructor.
---@param cmd string[] Command with arguments.
---@param options? table See `jobstart-options`.
---@return nviq.futures.Terminal
function Terminal.new(cmd, options)
  local terminal = {
    m_cmd = cmd,
    m_opts = options or {},
    m_id = -1,
    m_exited = false,
    m_cb_q = {},
    m_no_cb_q = false,
    m_bufnr = -1,
  }
  terminal.m_opts.term = true
  setmetatable(terminal, Terminal)
  return terminal
end

---Returns the buffer number.
---@return integer bufnr
function Terminal:bufnr()
  return self.m_bufnr
end

---Run the terminal process.
---@return boolean ok True if terminal started successfully.
function Terminal:start()
  if not self:is_valid() or self:has_exited() then
    return false
  end

  local winid = vim.api.nvim_get_current_win()
  local bufnr = vim.api.nvim_create_buf(false, false)
  if bufnr == 0 then
    return false
  end

  local ok = pcall(vim.api.nvim_win_set_buf, winid, bufnr)
  if not ok then
    vim.api.nvim_buf_delete(bufnr, {})
    vim.notify("Failed to set buffer", vim.log.levels.WARN)
    return false
  end

  self.m_bufnr = bufnr

  return Job.start(self)
end

return Terminal
