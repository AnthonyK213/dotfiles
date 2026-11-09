local M = {}

---Receives a value of any type and converts it to a string in a human-readable format.
---@param v any
---@return string
function M.to_string(v)
  if type(v) == "string" or not getmetatable(v) then
    return vim.inspect(v)
  end
  return tostring(v)
end

---Returns a human-readable representation of the given iterable collection.
---@param iterable nviq.util.c.Iterable
---@param meta table
---@param name string
---@param separator? string
---@return string
function M.iter_inspect(iterable, meta, name, separator)
  local visited = {}
  separator = separator or ", "
  ---
  ---@param obj nviq.util.c.Iterable
  ---@return string
  local function str(obj)
    if getmetatable(obj) == meta then
      local index = visited[obj]
      if index then
        return string.format("%s<%p>", name, obj)
      else
        visited[obj] = 0
        local result = string.format("%s<%p>{ ", name, obj)
        for i, v in obj:iter() do
          result = result .. str(v)
          if i ~= obj:count() then
            result = result .. separator
          end
        end
        return result .. " }"
      end
    else
      return M.to_string(obj)
    end
  end
  return str(iterable)
end

return M
