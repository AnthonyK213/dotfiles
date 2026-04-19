-- String utilities.

local M = {}

local _default_encoding = "utf-32"

---Returns number value of the first char in `str`.
---@param str string The string.
---@return integer result The number value.
function M.char2nr(str)
  if #str == 0 then return 0 end
  local char = M.sub(str, 1, 1)
  local result
  ---@type integer?
  local seq = 0

  for i = 1, #char do
    local c = string.byte(char, i)
    if seq == 0 then
      seq = c < 0x80 and 1 or c < 0xE0 and 2 or c < 0xF0 and 3 or
          c < 0xF8 and 4 or --c < 0xFC and 5 or c < 0xFE and 6 or
          error("invalid UTF-8 character.")
      result = bit.band(c, 2 ^ (8 - seq) - 1)
    else
      result = bit.bor(bit.lshift(result, 6), bit.band(c, 0x3F))
    end
    seq = seq - 1
  end

  return result
end

---Splits `str` into an array of unicode characters.
---@param str string String to split.
---@return string[] result Array of unicode characters.
function M.chars(str)
  local str_len = #str
  local result = {}
  local utf_end = 1

  while utf_end <= str_len do
    local step = vim.str_utf_end(str, utf_end)
    table.insert(result, str:sub(utf_end, utf_end + step))
    utf_end = utf_end + step + 1
  end

  return result
end

---Splits `str` into an iterator of unicode characters.
---@param str string String to split.
---@return fun():string|nil result Iterator of unicode characters.
function M.chars_iter(str)
  local str_len = #str
  local utf_end = 1

  return function()
    if utf_end <= str_len then
      local step = vim.str_utf_end(str, utf_end)
      local result = str:sub(utf_end, utf_end + step)
      utf_end = utf_end + step + 1
      return result
    end
  end
end

---Returns default encoding of string.
---@return "utf-8"|"utf-16"|"utf-32"
function M.denc()
  return _default_encoding
end

---Returns the length of `str` in `encoding`.
---@param str string The string.
---@param encoding? "utf-8"|"utf-16"|"utf-32" Default "utf-32"
---@return integer length The length of `str`.
function M.len(str, encoding)
  return vim.str_utfindex(str, encoding or _default_encoding)
end

---Replaces chars in `str` according to `mapping`.
---@param str string The string to replace.
---@param mapping table<string, string> The char mapping.
---@return string result The replaced string.
function M.replace(str, mapping)
  local char_array = M.chars(str)

  for i, char in ipairs(char_array) do
    if mapping[char] then
      char_array[i] = mapping[char]
    end
  end

  return table.concat(char_array)
end

---Returns the substring of the string that starts at `i` and continues until `j` with `encoding`.
---@see string.sub
---@param str string The string.
---@param i integer The start position (inclusive).
---@param j? integer The end position (inclusive). If nil, this would be the end of `str`.
---@param encoding? "utf-8"|"utf-16"|"utf-32" Default "utf-32"
---@return string The substring.
function M.sub(str, i, j, encoding)
  local enc = encoding or _default_encoding
  local length = M.len(str, enc)

  if i < 0 then
    i = i + length + 1
  end

  if j and j < 0 then
    j = j + length + 1
  end

  local u = (i > 0) and i or 1
  local v = (j and j <= length) and j or length
  if u > v then
    return ""
  end

  local s = vim.str_byteindex(str, enc, u - 1)
  local e = vim.str_byteindex(str, enc, v)

  return str:sub(s + 1, e)
end

---Adds zeros (0) at the beginning of the string, until it reaches the specified
---length.
---@param str string The string.
---@param len integer The length.
---@return string
function M.zfill(str, len)
  if #str >= len then
    return str
  end
  return string.rep("0", len - #str) .. str
end

return M
