-- From [snacks.nvim](https://github.com/folke/snacks.nvim/blob/main/lua/snacks/bigfile.lua)

local lib = require("nviq.util.lib")

local M = {}

---@class nviq.appl.bigfile.Config
---@field max_size integer
---@field max_line_length integer

---Determines whether the file is big file or not.
---@param path string
---@param bufnr integer
---@param config nviq.appl.bigfile.Config
---@return boolean
local function is_bigfile(path, bufnr, config)
  if not path or not bufnr or vim.bo[bufnr].filetype == "bigfile" then
    return false
  end

  path = vim.fs.normalize(path)
  if path ~= vim.fs.normalize(vim.api.nvim_buf_get_name(bufnr)) then
    return false
  end

  local size = vim.fn.getfsize(path)
  if size <= 0 then
    return false
  end

  if size > config.max_size then
    return true
  end

  local lines = vim.api.nvim_buf_line_count(bufnr)
  return (size - lines) / lines > config.max_line_length
end

---Disables some functions when big file detected.
---@param ctx {bufnr:integer}
local function bigfile_setup(ctx)
  if vim.fn.exists(":NoMatchParen") ~= 0 then
    vim.cmd [[NoMatchParen]]
  end

  vim.wo.foldmethod = "manual"
  vim.wo.statuscolumn = ""
  vim.wo.conceallevel = 0

  vim.schedule(function()
    if vim.api.nvim_buf_is_valid(ctx.bufnr) then
      vim.bo[ctx.bufnr].syntax = ""
    end
  end)
end

---
---@param config nviq.appl.bigfile.Config
function M.setup(config)
  vim.filetype.add {
    pattern = {
      [".*"] = {
        function(path, bufnr)
          return is_bigfile(path, bufnr, config) and "bigfile" or nil
        end
      }
    }
  }

  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("nviq.appl.bigfile", { clear = true }),
    pattern = "bigfile",
    callback = function(event)
      lib.warn("Big file detected.")
      lib.warn("Some functions have been disabled.")
      vim.api.nvim_buf_call(event.buf, function()
        bigfile_setup { bufnr = event.buf }
      end)
    end,
  })
end

return M
