-- Keymap utilities.

local _dir_keys = {
  l = "<C-G>U<Left>",
  r = "<C-G>U<Right>",
  u = "<C-G>U<Up>",
  d = "<C-G>U<Down>",
}

local M = {}

---
---@param mode string Mode short-name.
---@param lhs string Left-hand-side of the mapping.
---@param opts vim.keymap.set.Opts Optional parameters map.
---@return vim.api.keyset.get_keymap?
local function get_keymap(mode, lhs, opts)
  local keymaps
  local bufnr = opts.buf

  if type(bufnr) == "number" then
    if not vim.api.nvim_buf_is_valid(bufnr) then return end
    keymaps = vim.api.nvim_buf_get_keymap(bufnr, mode)
  elseif type(bufnr) == "boolean" and bufnr then
    keymaps = vim.api.nvim_buf_get_keymap(0, mode)
  else
    keymaps = vim.api.nvim_get_keymap(mode)
  end

  for _, maparg in ipairs(keymaps) do
    if maparg.lhs == lhs then
      return maparg
    end
  end
end

---
---@param maparg? vim.api.keyset.get_keymap
---@return function?
local function resolve_fallback(maparg)
  if not maparg then
    return
  end

  local mode = (maparg.noremap == 1) and "in" or "im"
  local rhs

  if maparg.expr == 1 then
    if maparg.rhs then
      rhs = maparg.rhs --[[@as string]]
      return function()
        -- FIXME: Annoying escapes...
        M.feedkeys(vim.api.nvim_eval(rhs), mode)
      end
    elseif maparg.callback then
      rhs = maparg.callback --[[@as function]]
      return function()
        M.feedkeys(rhs(), mode)
      end
    end
  else
    if maparg.rhs then
      rhs = maparg.rhs --[[@as string]]
      return function()
        M.feedkeys(rhs, mode)
      end
    elseif maparg.callback then
      return maparg.callback
    end
  end
end

---Returns the key code of direction that won't break the history.
---@param dir "l"|"r"|"u"|"d" Left/Right/Up/Down.
---@return string key_code
function M.dir_key(dir)
  return _dir_keys[dir]
end

---Escapes the terminal codes, feeds them to nvim.
---@see vim.api.nvim_feedkeys
---@param keys string To be typed.
---@param mode string Behavior flags, see **feedkeys()**.
function M.feedkeys(keys, mode)
  local k = vim.api.nvim_replace_termcodes(keys, true, false, true)
  vim.api.nvim_feedkeys(k, mode, false)
end

---Switches mode to NORMAL.
function M.to_normal()
  M.feedkeys("<C-\\><C-N>", "nx")
end

---Creates new mapping with fallback.
---@param mode string Mode short-name.
---@param lhs string Left-hand-side of the mapping.
---@param new_rhs fun(fallback: function) New `rhs`.
---@param opts? vim.keymap.set.Opts Optional parameters map.
function M.new_keymap(mode, lhs, new_rhs, opts)
  opts = vim.deepcopy(opts or {})

  local maparg = get_keymap(mode, lhs, opts)
  local fallback = resolve_fallback(maparg) or function()
    M.feedkeys(lhs, "in")
  end

  -- TODO: Handle `expr`
  opts.expr = false
  vim.keymap.set(mode, lhs, function() new_rhs(fallback) end, opts)
end

return M
