local Iterator = require("nviq.util.collections.iter")

local function _max(a, b) return a > b end
local function _min(a, b) return a < b end
local function _swap(list, i, j) list[i], list[j] = list[j], list[i] end

---@param comparer? "max"|"min"|fun(a: any, b: any):boolean
---@return fun(a: any, b: any):boolean
local function _get_comparer(comparer)
  if not comparer or comparer == "max" then
    return _max
  elseif comparer == "min" then
    return _min
  elseif not vim.is_callable(comparer) then
    error("Invalid comparer")
  else
    return comparer
  end
end

---@class nviq.collections.PriorityQueue
---@field private m_data any[]
---@field private m_size integer
---@field private m_comp fun(a: any, b: any):boolean
---@operator call:nviq.collections.PriorityQueue
local PriorityQueue = {}

---@private
PriorityQueue.__index = PriorityQueue

setmetatable(PriorityQueue, {
  __call = function(o, ...)
    return o.new(...)
  end
})

---Initializes a new instance of the `PriorityQueue` with the specified custom
---priority comparer.
---@param comparer? "max"|"min"|fun(a: any, b: any):boolean Custom comparer dictating the ordering of elements. Uses "max" if the argument is `nil`.
---@return nviq.collections.PriorityQueue
function PriorityQueue.new(comparer)
  local pq = {
    m_data = {},
    m_size = 0,
    m_comp = _get_comparer(comparer),
  }
  setmetatable(pq, PriorityQueue)
  return pq
end

---Initializes a new instance of the `PriorityQueue` with the specified elements
---and custom priority comparer.
---@param iterable nviq.collections.Iterable
---@param comparer? "max"|"min"|fun(a: any, b: any):boolean Custom comparer dictating the ordering of elements. Uses "max" if the argument is `nil`.
---@return nviq.collections.PriorityQueue
function PriorityQueue.from(iterable, comparer)
  local data = {}
  local size = 0
  for i, v in Iterator(iterable):consume() do
    data[i] = v
    size = size + 1
  end

  ---@type nviq.collections.PriorityQueue
  local pq = {
    m_data = data,
    m_size = size,
    m_comp = _get_comparer(comparer),
  }
  setmetatable(pq, PriorityQueue)

  for i = bit.rshift(size, 1), 1, -1 do
    pq:_heapify(i)
  end

  return pq
end

---@private
function PriorityQueue:_parent(i)
  return bit.rshift(i, 1)
end

---@private
function PriorityQueue:_left(i)
  return bit.lshift(i, 1)
end

---@private
function PriorityQueue:_right(i)
  return bit.lshift(i, 1) + 1
end

---@private
function PriorityQueue:_heapify(i)
  local l = self:_left(i)
  local r = self:_right(i)
  local w = l <= self.m_size and self.m_comp(self.m_data[l], self.m_data[i]) and l or i
  if r <= self.m_size and self.m_comp(self.m_data[r], self.m_data[w]) then
    w = r
  end
  if w ~= i then
    _swap(self.m_data, i, w)
    self:_heapify(w)
  end
end

---Returns the priority comparer used by the `PriorityQueue`.
---@return fun(a: any, b: any):boolean
function PriorityQueue:comparer()
  return self.m_comp
end

---Returns the number of elements contained in the `PriorityQueue`.
---@return integer
function PriorityQueue:count()
  return self.m_size
end

---Removes all items from the `PriorityQueue`.
function PriorityQueue:clear()
  self.m_size = 0
end

---Removes and returns the minimal element from the `PriorityQueue` - that is,
---the element with the lowest priority value.
function PriorityQueue:dequeue()
  if self.m_size < 1 then
    error("Heap underflow")
  end
  local peek = self.m_data[1]
  self.m_data[1] = self.m_data[self.m_size]
  self.m_size = self.m_size - 1
  self:_heapify(1)
  return peek
end

---Adds the specified element to the `PriorityQueue`.
---@param item any
function PriorityQueue:enqueue(item)
  self.m_size = self.m_size + 1
  local i = self.m_size
  self.m_data[i] = item
  local p = self:_parent(i)
  while i > 1 and self.m_comp(self.m_data[i], self.m_data[p]) do
    _swap(self.m_data, i, p)
    i = p
    p = self:_parent(i)
  end
end

---Adds the specified element to the `PriorityQueue`, and immediately removes
---the minimal element, returning the result.
---@param item any
---@return any
function PriorityQueue:enqueue_dequeue(item)
  self:enqueue(item)
  return self:dequeue()
end

---Enqueues a sequence of elements pairs to the `PriorityQueue`.
---@param iterable nviq.collections.Iterable
function PriorityQueue:enqueue_range(iterable)
  for _, v in Iterator(iterable):consume() do
    self:enqueue(v)
  end
end

---Returns the minimal element from the `PriorityQueue` without removing it.
---@return any
function PriorityQueue:peek()
  if self.m_size > 0 then
    return self.m_data[1]
  end
end

---Returns a string that represents the current object.
---@return string
function PriorityQueue:__tostring()
  return string.format("PriorityQueue<%p>", self)
end

return PriorityQueue
