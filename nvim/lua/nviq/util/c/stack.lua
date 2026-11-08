---@class nviq.util.c.Stack<T> : nviq.util.c.Iterable
---@field private m_data T[]
---@field private m_top integer
---@operator call:nviq.util.c.Stack
local Stack = {}

---@private
Stack.__index = Stack

setmetatable(Stack, { __call = function(o) return o.new() end })

---Create an empty stack.
---@return nviq.util.c.Stack
function Stack.new()
  local stack = {
    m_top = 0,
    m_data = {},
  }
  setmetatable(stack, Stack)
  return stack
end

---Removes all objects from the `Stack`.
function Stack:clear()
  for i = 1, self.m_top, 1 do
    self.m_data[i] = nil
  end
  self.m_top = 0
end

---Gets the number of elements contained in the `Stack`.
---@return integer
function Stack:count()
  return self.m_top
end

---Returns the object at the top of the Stack without removing it.
---@return T
function Stack:peek()
  if self.m_top == 0 then
    error("Stack is empty")
  end
  return self.m_data[self.m_top]
end

---Removes and returns the object at the top of the `Stack`.
---@return T
function Stack:pop()
  if self.m_top == 0 then
    error("Stack is empty")
  end
  local item = self.m_data[self.m_top]
  self.m_data[self.m_top] = nil
  self.m_top = self.m_top - 1
  return item
end

---Inserts an object at the top of the `Stack`.
---@param item T
function Stack:push(item)
  self.m_top = self.m_top + 1
  self.m_data[self.m_top] = item
end

---Get the iterator of the `Stack`.
---@return fun():(integer?, T?) iterator
function Stack:iter()
  local index = 0
  return function()
    index = index + 1
    if index <= self.m_top then
      return index, self.m_data[index]
    end
  end
end

---@private
---Returns a string that represents the current object.
---@return string
function Stack:__tostring()
  return require("nviq.util.c.util").iter_inspect(self, Stack, "Stack")
end

return Stack
