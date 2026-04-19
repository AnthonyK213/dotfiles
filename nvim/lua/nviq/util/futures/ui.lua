local Task = require("nviq.util.futures.task")

---Async wrapper of `vim.ui`.
local M = {}

---Prompts the user for input.
---@async
---@param opts table Additional options. See `input()`.
---@return string? input Content the user typed.
function M.input(opts)
  return Task.new(vim.ui.input, opts):set_async(true):await()
end

---Prompts the user to pick a single item from a collection of entries.
---@async
---@generic T
---@param items T[] Arbitrary items.
---@param opts table Additional options. See `select()`.
---@return T? item The chosen item.
---@return integer? idx The 1-based index of `item` within `items`.
function M.select(items, opts)
  return Task.new(vim.ui.select, items, opts):set_async(true):await()
end

return M
