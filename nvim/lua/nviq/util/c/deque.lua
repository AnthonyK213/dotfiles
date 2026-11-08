---Represents a double-ended queue.
---@class nviq.util.c.Deque<T> : nviq.util.c.Iterable
---@field private m_data T[]
---@field private m_front integer
---@field private m_back integer
---@operator call:nviq.util.c.Deque
local Deque = {}

---@private
Deque.__index = Deque

setmetatable(Deque, {
  __call = function(o, ...)
    return o.new(...)
  end
})

---Constructor.
---@return nviq.util.c.Deque
function Deque.new(...)
  local count = select("#", ...)
  local front = -bit.rshift(count, 1)
  local deque = {
    m_data  = {},
    m_front = front,
    m_back  = front + count - 1,
  }
  for i = 1, count, 1 do
    deque.m_data[i + front - 1] = select(i, ...)
  end
  setmetatable(deque, Deque)
  return deque
end

---@private
---@param index? integer
---@param min? integer
---@param max? integer
function Deque:boundary_check(index, min, max)
  if self.m_front > self.m_back then
    error("Deque is empty")
  end
  if index and (index > (max or self.m_back) or index < (min or self.m_front)) then
    error("Index out of bounds")
  end
end

---@private
---Convert one-based `index` into the index of `data`.
---@param index integer The one-based index.
---@return integer
function Deque:data_index(index)
  return index + self.m_front - 1
end

---Get the element at the given one-based index.
---@param index integer The one-based index.
---@return T
function Deque:get(index)
  index = self:data_index(index)
  self:boundary_check(index)
  return self.m_data[index]
end

---Get the back element.
---@return T
function Deque:get_back()
  self:boundary_check()
  return self.m_data[self.m_back]
end

---Get the front element.
---@return T
function Deque:get_front()
  self:boundary_check()
  return self.m_data[self.m_front]
end

---Removes the last element from the deque and returns it.
---@return T
function Deque:pop_back()
  self:boundary_check()
  local item = self.m_data[self.m_back]
  self.m_data[self.m_back] = nil
  self.m_back = self.m_back - 1
  return item
end

---Removes the first element and returns it.
---@return T
function Deque:pop_front()
  self:boundary_check()
  local item = self.m_data[self.m_front]
  self.m_data[self.m_front] = nil
  self.m_front = self.m_front + 1
  return item
end

---Appends an element to the back of the `Deque`.
---@param item T
function Deque:push_back(item)
  self.m_back = self.m_back + 1
  self.m_data[self.m_back] = item
end

---Prepends an element to the `Deque`.
---@param item T
function Deque:push_front(item)
  self.m_front = self.m_front - 1
  self.m_data[self.m_front] = item
end

---Returns the number of the elements in the `Deque`.
---@return integer
function Deque:count()
  return self.m_back - self.m_front + 1
end

---Clears the deque, removing all values.
function Deque:clear()
  for i = self.m_front, self.m_back, 1 do
    self.m_data[i] = nil
  end
  self.m_front = 0
  self.m_back = -1
end

---Inserts an element at one-based `index` within the deque, shifting all elements
---with indices greater than or equal to `index` towards the back.
---@param index integer The one-based index at which item should be inserted.
---@param item T The object to insert.
function Deque:insert(index, item)
  index = self:data_index(index)
  self:boundary_check(index, nil, self.m_back + 1)
  for i = self.m_back, index, -1 do
    self.m_data[i + 1] = self.m_data[i]
  end
  self.m_data[index] = item
  self.m_back = self.m_back + 1
end

---Removes and returns the element at one-based `index` from the `Deque`.
---@param index integer The one-based index of the element to remove.
---@return T item The removed item.
function Deque:remove_at(index)
  index = self:data_index(index)
  self:boundary_check(index)
  local item = self.m_data[index]
  for i = index, self.m_back - 1, 1 do
    self.m_data[i] = self.m_data[i + 1]
  end
  self.m_data[self.m_back] = nil
  self.m_back = self.m_back - 1
  return item
end

---Get the iterator of the `Deque`.
---@return fun():(integer?, T?) iterator
function Deque:iter()
  local index = self.m_front - 1
  return function()
    index = index + 1
    if index <= self.m_back then
      return index + 1 - self.m_front, self.m_data[index]
    end
  end
end

---Rotates the deque `mid` places to the left.
---@param mid integer
function Deque:rotate_left(mid)
  mid = mid % self:count()
  for _ = 1, mid, 1 do
    self:push_back(self:pop_front())
  end
end

---Rotates the deque `mid` places to the right.
---@param mid integer
function Deque:rotate_right(mid)
  mid = mid % self:count()
  for _ = 1, mid, 1 do
    self:push_front(self:pop_back())
  end
end

---@private
---Returns a string that represents the current object.
---@return string
function Deque:__tostring()
  return require("nviq.util.c.util").iter_inspect(self, Deque, "Deque")
end

return Deque
