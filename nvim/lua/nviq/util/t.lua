-- Table utilities.

local M = {}

---@class nviq.util.t.Pack : any[]
---@field n integer

---Finds the first item with the value `val`.
---@generic T
---@param tbl T[] The list-like table.
---@param val T The value to find.
---@return integer index The first index of value `val`, 0 for not found.
function M.find_first(tbl, val)
  if vim.islist(tbl) then
    for i, v in ipairs(tbl) do
      if v == val then
        return i
      end
    end
  end
  return 0
end

---Finds the last item with the value `val`.
---@generic T
---@param tbl T[] The list-like table.
---@param val T The value to find.
---@return integer index The last index of value `val`, 0 for not found.
function M.find_last(tbl, val)
  if vim.islist(tbl) then
    for i = #tbl, 1, -1 do
      if tbl[i] == val then
        return i
      end
    end
  end
  return 0
end

---Inserts element `value` at position `pos` in the packed table `pack`.
---@param pack nviq.util.t.Pack
---@param pos integer
---@param value any
function M.insert(pack, pos, value)
  for i = pack.n, pos, -1 do
    pack[i + 1] = pack[i]
  end
  pack[pos] = value
  pack.n = pack.n + 1
end

---@see table.pack https://www.lua.org/manual/5.4/manual.html#pdf-table.pack
---@param ... any
---@return nviq.util.t.Pack
function M.pack(...)
  return { n = select("#", ...), ... }
end

---Reverses a list-like table.
---@generic T
---@param tbl T[] Table to reverse.
---@return T[] result Reversed table if reversible.
function M.reverse(tbl)
  if vim.islist(tbl) then
    local tmp = {}
    for i = #tbl, 1, -1 do
      table.insert(tmp, tbl[i])
    end
    return tmp
  end
  return tbl
end

---Unpacks a packed table.
---@param pack nviq.util.t.Pack Packed table.
---@param i? integer
---@return ... Unpacked args.
function M.unpack(pack, i)
  return unpack(pack, i or 1, pack.n)
end

return M
