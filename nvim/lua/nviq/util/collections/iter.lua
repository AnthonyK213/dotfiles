---@class nviq.collections.Iterator
---@field private m_next fun():integer?, any
---@operator call(any[]|nviq.collections.Iterable):nviq.collections.Iterator
local Iterator = {}

---@private
Iterator.__index = Iterator

setmetatable(Iterator, {
  __call = function(o, iterable)
    return o.get(iterable)
  end
})

---Get iterator of a iteralble collection.
---@param iterable any[]|nviq.collections.Iterable An iteralble collection.
---@return nviq.collections.Iterator
function Iterator.get(iterable)
  local iter = {}
  if getmetatable(iterable) and type(iterable.iter) == "function" then
    iter.m_next = iterable:iter()
  elseif vim.islist(iterable) then
    local index = 0
    iter.m_next = function()
      index = index + 1
      if index <= #iterable then
        return index, iterable[index]
      end
    end
  else
    error("Failed to get the iterator")
  end
  setmetatable(iter, Iterator)
  return iter
end

---Consume the iterator.
---@return fun():integer?, any
function Iterator:consume()
  return self.m_next
end

---Get the next element of the iterator.
---@return any
function Iterator:next()
  return select(2, self.m_next())
end

---Applies a specified function to the corresponding elements of two sequences,
---producing a sequence of the results.
---@param iterator nviq.collections.Iterator
---@param selector? fun(a: any, b: any):any
---@return nviq.collections.Iterator
function Iterator:zip(iterator, selector)
  local index = 0
  local iter = {
    m_next = function()
      index = index + 1
      local i, v1 = self.m_next()
      local j, v2 = iterator:consume()()
      if not (i and j) then return end
      return index, selector and selector(v1, v2) or { v1, v2 }
    end
  }
  setmetatable(iter, Iterator)
  return iter
end

return Iterator
