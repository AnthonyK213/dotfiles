local lib = require("nviq.util.lib")
local sutil = require("nviq.util.s")
local tutil = require("nviq.util.t")

local M = {}

local _pairs = {
  ["("] = ")",
  ["["] = "]",
  ["{"] = "}",
  ["<"] = ">",
  [" "] = " ",
  ["（"] = "）",
  ["【"] = "】",
  ["「"] = "」",
  ["〈"] = "〉",
  ["《"] = "》",
  ["‘"] = "’",
  ["“"] = "”",
}

---Returns the right side of the surrounding pair according to the `left`.
---@param left string
local function get_right(left)
  if vim.regex([[\v^[\(\[{< （【「〈《‘“]+$]]):match_str(left) then
    return table.concat(vim.tbl_map(function(x)
      return _pairs[x]
    end, tutil.reverse(sutil.chars(left))))
  elseif vim.regex([[\v^(\<\w{-}\>)+$]]):match_str(left) then
    return "</" .. table.concat(tutil.reverse(vim.tbl_filter(function(str)
      return str ~= ""
    end, vim.split(left, "<"))), "</")
  else
    return left
  end
end

---Extracts surrounding pair from the input.
---@param pair string|string[] Left|Both side(s) of the surrounding pair.
---@return string? left
---@return string? right
local function extract_pair(pair)
  local left, right

  if type(pair) == "table" then
    left, right = unpack(pair)
  elseif type(pair) == "string" then
    left = pair
    right = get_right(left)
  end

  return left, right
end

---Inserts the input surrounding to the ends of <cword>.
---@param mode nviq.util.lib.Mode The mode.
---@param pair string|string[] The surrounding pair.
---@param get_word? fun():string,integer,integer Function to get <cword>.
function M.insert(mode, pair, get_word)
  if not pair then return end

  local left, right = extract_pair(pair)
  if not left or not right then return end

  if mode == lib.Mode.Normal then
    local _, s, e = (get_word or lib.get_word)()
    local lin, col = unpack(vim.api.nvim_win_get_cursor(0))
    vim.api.nvim_buf_set_text(0, lin - 1, e, lin - 1, e, { right })
    vim.api.nvim_buf_set_text(0, lin - 1, s, lin - 1, s, { left })
    vim.api.nvim_win_set_cursor(0, { lin, col + #left })
  elseif mode == lib.Mode.Visual then
    local s_lin, s_col, e_lin, e_col = lib.get_gv_mark()
    vim.api.nvim_buf_set_text(0, e_lin, e_col, e_lin, e_col, { right })
    vim.api.nvim_buf_set_text(0, s_lin, s_col, s_lin, s_col, { left })
  end
end

---Deletes the input surrounding around the cursor.
---@param pair string|string[] The surrounding pair.
function M.delete(pair)
  if not pair then return end

  local left, right = extract_pair(pair)
  if not left or not right then return end

  local l_lin, l_col, r_lin, r_col = lib.search_pair_pos(left, right)
  if l_lin < 0 or l_col < 0 or r_lin < 0 or r_col < 0 then
    vim.notify("Surrounding not found")
    return
  end

  vim.api.nvim_buf_set_text(0, r_lin, r_col, r_lin, r_col + #right, {})
  vim.api.nvim_buf_set_text(0, l_lin, l_col, l_lin, l_col + #left, {})
end

---Changes surrounding around the cursor.
---@param pair_old string|string[] The surrounding pair to be changed.
---@param pair_new string|string[] The new surrounding pairs.
function M.change(pair_old, pair_new)
  if not pair_old or not pair_new then return end

  local left_old, right_old = extract_pair(pair_old)
  if not left_old or not right_old then return end

  local left_new, right_new = extract_pair(pair_new)
  if not left_new or not right_new then return end

  local l_lin, l_col, r_lin, r_col = lib.search_pair_pos(left_old, right_old)
  if l_lin < 0 or l_col < 0 or r_lin < 0 or r_col < 0 then
    vim.notify("Surrounding not found")
    return
  end

  vim.api.nvim_buf_set_text(0, r_lin, r_col, r_lin, r_col + #right_old, { right_new })
  vim.api.nvim_buf_set_text(0, l_lin, l_col, l_lin, l_col + #left_old, { left_new })
end

return M
