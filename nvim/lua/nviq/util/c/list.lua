---Represents a list of objects that can be accessed by index. Provides methods
---to search, sort, and manipulate lists.
---@class nviq.util.c.List<T> : { [integer]: T }, nviq.util.c.Iterable
---@field private m_data T[]
---@field private m_size integer
---@operator call:nviq.util.c.List
local List = {}

---@private
List.__index = function(list, index)
  if type(index) == "number" then
    list:boundary_check(index)
    return list.m_data[index]
  end
  return List[index]
end

setmetatable(List, {
  __call = function(o, ...)
    return o.new(...)
  end
})

---Constructor.
---@param ... any List elements.
---@return nviq.util.c.List
function List.new(...)
  local list = {
    m_data = { ... },
    m_size = select("#", ...),
  }
  setmetatable(list, List)
  return list
end

---@private
---Boundary check.
---@param index integer
---@param count? integer
---@param min? integer
---@param max? integer
---@param backward? boolean
function List:boundary_check(index, count, min, max, backward)
  if math.floor(index) ~= index then
    error("Index must be an integer")
  end
  if count then
    if math.floor(count) ~= count then
      error("Count must be an integer")
    elseif count < 0
        or (backward and index < count or index + count > self.m_size + 1) then
      error("Count out of bounds")
    end
  end
  if index < (min or 1) or index > (max or self.m_size) then
    error("Index out of bounds")
  end
end

---Returns the number of elements contained in the `List`.
---@return integer
function List:count()
  return self.m_size
end

---Adds an object to the end of the `List`.
---@param item T The object to be added to the end of the `List`.
function List:add(item)
  self.m_size = self.m_size + 1
  self.m_data[self.m_size] = item
end

---Inserts an element into the `List` at the specified index.
---@param index integer The one-based index at which item should be inserted.
---@param item T The object to insert.
function List:insert(index, item)
  self:boundary_check(index, nil, 1, self.m_size + 1)
  for i = self.m_size, index, -1 do
    self.m_data[i + 1] = self.m_data[i]
  end
  self.m_data[index] = item
  self.m_size = self.m_size + 1
end

---Removes and returns the element at the specified index of the `List`.
---@param index integer The one-based index of the element to remove.
---@return T item The removed item.
function List:remove_at(index)
  self:boundary_check(index)
  local item = self.m_data[index]
  for i = index, self.m_size - 1, 1 do
    self.m_data[i] = self.m_data[i + 1]
  end
  self.m_data[self.m_size] = nil
  self.m_size = self.m_size - 1
  return item
end

---Removes all elements from the `List`.
function List:clear()
  for i = 1, self.m_size, 1 do
    self.m_data[i] = nil
  end
  self.m_size = 0
end

---Returns the elements from the given `List`.
---@param i? integer
---@param j? integer
---@return ...
function List:unpack(i, j)
  return unpack(self.m_data, i or 1, j or self.m_size)
end

---Sort the elements in the entire `List` using the specified `comparison`.
---@generic T
---@param comparer? fun(a: T, b: T):boolean The function to use when comparing elements.
function List:sort(comparer)
  table.sort(self.m_data, comparer)
end

---Get the iterator of the `List`.
---@return fun():(integer?, T?) iterator
function List:iter()
  local index = 0
  return function()
    index = index + 1
    if index <= self.m_size then
      return index, self.m_data[index]
    end
  end
end

---Reverses the order of the elements in the `List` or a portion of it.
---@param index? integer The one-based starting index of the range to reverse.
---@param count? integer The number of elements in the range to reverse.
function List:reverse(index, count)
  if index and not count then
    error("Count should be specified")
  end

  index = index or 1
  count = count or self.m_size

  self:boundary_check(index, count)
  if count < 2 then return end

  local sum = index * 2 + count - 1

  for i = index, index + bit.rshift(count, 1) - 1, 1 do
    self[i], self[sum - i] = self[sum - i], self[i]
  end
end

---@private
---Equality test.
---@param list nviq.util.c.List
---@return boolean
function List:__eq(list)
  if rawequal(self, list) then
    return true
  end
  if getmetatable(list) ~= List or self:count() ~= list:count() then
    return false
  end
  for i, v in self:iter() do
    if v ~= list[i] then
      return false
    end
  end
  return true
end

---@private
---Returns the number of elements contained in the `List`.
---Only available with 5.2+ :(
---@return integer
function List:__len()
  return self.m_size
end

---@private
---Set the element at the specified index of the `List`.
---@param index integer
---@param value any
function List:__newindex(index, value)
  self:boundary_check(index)
  self.m_data[index] = value
end

---@private
---Returns a string that represents the current object.
---@return string
function List:__tostring()
  return require("nviq.util.c.util").iter_inspect(self, List, "List")
end

return List
