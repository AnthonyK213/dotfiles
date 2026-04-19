local lib = require("nviq.util.lib")
local rsmod = require("nviq.appl.rsmod")

local _augroup = vim.api.nvim_create_augroup("nviq.appl.mdp", { clear = true })

---The active nviq-mdp process.
---@type integer
local _nviq_mdp = 0

---Buffers to preview.
---@type table<integer, boolean>
local _active_bufs = {}

---Returns whether nviq-mdp is active.
---@return boolean
local function mdp_is_active()
  return _nviq_mdp > 0
end

---
local function update()
  if mdp_is_active() then
    vim.rpcrequest(_nviq_mdp, "update")
  end
end

---
local function scroll()
  if mdp_is_active() then
    local line = vim.fn.line(".")
    vim.rpcrequest(_nviq_mdp, "scroll", line)
  end
end

local M = {}

---@private
function M.start()
  local bufnr = vim.api.nvim_get_current_buf()
  if _active_bufs[bufnr] then return end

  if not lib.has_filetype("markdown") then return end

  if not mdp_is_active() then
    local mdp = rsmod.get_bin_path("nviq-mdp")
    if not mdp then return end

    _nviq_mdp = vim.fn.jobstart({ mdp }, {
      rpc = true,
      on_exit = function()
        _nviq_mdp = 0
        for k, _ in pairs(_active_bufs) do
          _active_bufs[k] = nil
        end
        vim.api.nvim_clear_autocmds { group = _augroup }
      end
    })

    if not mdp_is_active() then
      lib.warn("Mdp: Failed to start")
      return
    end
  end

  vim.api.nvim_clear_autocmds { group = _augroup, buffer = bufnr }

  vim.api.nvim_create_autocmd({ "BufEnter", "TextChanged", "TextChangedI" }, {
    group = _augroup,
    buffer = bufnr,
    callback = update
  })

  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
    group = _augroup,
    buffer = bufnr,
    callback = scroll
  })

  _active_bufs[bufnr] = true

  update()
end

---@private
function M.stop()
  local bufnr = vim.api.nvim_get_current_buf()
  if not _active_bufs[bufnr] then return end

  if mdp_is_active() then
    vim.fn.jobstop(_nviq_mdp)
  end
end

---Toggle markdown previewer.
function M.toggle()
  local bufnr = vim.api.nvim_get_current_buf()
  if _active_bufs[bufnr] then
    M.stop()
  else
    M.start()
  end
end

return M
