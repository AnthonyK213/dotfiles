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
---@param iterable any
---@param meta table
---@param name string
---@param separator? string
---@return string
function M.iter_inspect(iterable, meta, name, separator)
  local visited = {}
  separator = separator or ", "
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

---Returns `contains` method of `iterable`.
---@param iterable any[]|nviq.collections.Iterable
---@return (fun(iterable: any[]|nviq.collections.Iterable, item: any):boolean)?
function M.get_contains(iterable)
  if getmetatable(iterable) and type(iterable.contains) == "function" then
    return iterable.contains
  elseif vim.islist(iterable) then
    return vim.list_contains
  else
    return
  end
end

---Returns `count` method of `iterable`.
---@param iterable any[]|nviq.collections.Iterable
---@return (fun(iterable: any[]|nviq.collections.Iterable):integer)?
function M.get_count(iterable)
  if getmetatable(iterable) and type(iterable.count) == "function" then
    return iterable.count
  elseif vim.islist(iterable) then
    return function(x)
      return #x
    end
  else
    return
  end
end

return M
