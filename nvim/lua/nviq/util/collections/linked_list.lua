---@class nviq.collections.LinkedListNode
---@field private m_data any
---@field private m_list? nviq.collections.LinkedList
---@field private m_prev? nviq.collections.LinkedListNode
---@field private m_next? nviq.collections.LinkedListNode
---@operator call:nviq.collections.LinkedListNode
local LinkedListNode = {}

---@private
LinkedListNode.__index = LinkedListNode

setmetatable(LinkedListNode, {
  __call = function(o, v)
    return o.new(v)
  end
})

---Create a node which contains `value`.
---The created node does not belong to any `LinkedList`.
---@param value any
---@return nviq.collections.LinkedListNode
function LinkedListNode.new(value)
  local node = {
    m_data = value,
  }
  setmetatable(node, LinkedListNode)
  return node
end

---Get the node value it contains.
---@return any
function LinkedListNode:value()
  return self.m_data
end

---Get the `LinkedList` which owns the node.
---@return nviq.collections.LinkedList?
function LinkedListNode:list()
  return self.m_list
end

---Get previous node.
---@return nviq.collections.LinkedListNode?
function LinkedListNode:prev()
  return self.m_prev
end

---Get next node.
---@return nviq.collections.LinkedListNode?
function LinkedListNode:next()
  return self.m_next
end

---@private
---Returns a string that represents the current object.
---@return string
function LinkedListNode:__tostring()
  return string.format("Node(%s)", require("nviq.util.collections.util").to_string(self.m_data))
end

--------------------------------------------------------------------------------

---@class nviq.collections.LinkedList : nviq.collections.Iterable
---@field private m_size integer
---@field private m_first nviq.collections.LinkedListNode?
---@field private m_last nviq.collections.LinkedListNode?
---@operator call:nviq.collections.LinkedList
local LinkedList = {}

---@private
LinkedList.__index = LinkedList

setmetatable(LinkedList, {
  __call = function(o)
    return o.new()
  end
})

---Constructs an empty linked list.
---@return nviq.collections.LinkedList
function LinkedList.new()
  local linked_list = {
    m_size = 0,
  }
  setmetatable(linked_list, LinkedList)
  return linked_list
end

---Returns the number of nodes actually contained in the `LinkedList`.
---@return integer
function LinkedList:count()
  return self.m_size
end

---Returns the first node of the `LinkedList`.
---@return nviq.collections.LinkedListNode?
function LinkedList:first()
  return self.m_first
end

---Returns the first node of the `LinkedList`.
---@return nviq.collections.LinkedListNode?
function LinkedList:last()
  return self.m_last
end

---@private
---@return nviq.collections.LinkedListNode
function LinkedList:_add_check(item)
  local node

  if getmetatable(item) == LinkedListNode then
    if item:list() == self then
      node = item
    elseif item:list() == nil then
      node = item
      rawset(node, "m_list", self)
    else
      error("The node is owned by another `LinkedList`")
    end
  else
    node = LinkedListNode(item)
    rawset(node, "m_list", self)
  end

  return node
end

---@private
function LinkedList:_owns_node(node)
  return getmetatable(node) == LinkedListNode and node:list() == self
end

---@private
function LinkedList:_contains_node(node)
  if not self:_owns_node(node) then
    return false
  end
  local c = self.m_first
  while c do
    if rawequal(c, node) then
      return true
    end
    c = c:next()
  end
  return false
end

---Determines whether any loops in the `LinkedList`
---@return boolean
function LinkedList:has_loop()
  local fast, slow = self.m_first, self.m_first

  while fast and slow do
    slow = slow:next()
    fast = fast:next()
    if not fast then
      return false
    end
    fast = fast:next()
    if fast == slow then
      return true
    end
  end

  return false
end

---Adds the specified new node or value after the specified existing node in the `LinkedList`.
---@param node nviq.collections.LinkedListNode
---@param item any
function LinkedList:add_after(node, item)
  assert(self:_contains_node(node), "LinkedList does not contain the `node`")
  local new_node = self:_add_check(item)
  local next = node:next()
  rawset(new_node, "m_next", next)
  rawset(new_node, "m_prev", node)
  rawset(node, "m_next", new_node)
  if next then
    rawset(next, "m_prev", new_node)
  else
    self.m_last = new_node
  end
  self.m_size = self.m_size + 1
end

---Adds a new node or value before an existing node in the `LinkedList`.
---@param node nviq.collections.LinkedListNode
---@param item any
function LinkedList:add_before(node, item)
  assert(self:_contains_node(node), "LinkedList does not contain the `node`")
  local new_node = self:_add_check(item)
  local prev = node:prev()
  rawset(new_node, "m_prev", prev)
  rawset(new_node, "m_next", node)
  rawset(node, "m_prev", new_node)
  if prev then
    rawset(prev, "m_next", new_node)
  else
    self.m_first = new_node
  end
  self.m_size = self.m_size + 1
end

---Adds a new node or value at the start of the `LinkedList`.
---@param item any
function LinkedList:add_first(item)
  local node = self:_add_check(item)
  local first = self.m_first
  rawset(node, "m_next", first)
  rawset(node, "m_prev", nil)
  if first then
    rawset(first, "m_prev", node)
  else
    self.m_last = node
  end
  self.m_first = node
  self.m_size = self.m_size + 1
end

---Adds a new node at the end of the `LinkedList`.
---@param item any
function LinkedList:add_last(item)
  local node = self:_add_check(item)
  local last = self.m_last
  rawset(node, "m_prev", last)
  rawset(node, "m_next", nil)
  if last then
    rawset(last, "m_next", node)
  else
    self.m_first = node
  end
  self.m_last = node
  self.m_size = self.m_size + 1
end

---Removes all nodes from the `LinkedList`.
function LinkedList:clear()
  local node = self.m_first
  while node do
    local node_next = node:next()
    rawset(node, "m_prev", nil)
    rawset(node, "m_next", nil)
    node = node_next
  end
  self.m_first = nil
  self.m_last = nil
  self.m_size = 0
end

---Determines whether a value is in the `LinkedList`.
---@param value any
---@return boolean
function LinkedList:contains(value)
  for _, v in self:iter() do
    if v == value then
      return true
    end
  end
  return false
end

---Get the iterator of the `LinkedList`.
---@return fun():integer?, any iterator
function LinkedList:iter()
  local index = 0
  local node = self.m_first
  return function()
    index = index + 1
    if node then
      local value = node:value()
      node = node:next()
      return index, value
    end
  end
end

---Removes the specified node from the `LinkedList`.
---@param node nviq.collections.LinkedListNode
function LinkedList:remove(node)
  assert(self:_contains_node(node), "LinkedList does not contain the `node`")
  local prev = node:prev()
  local next = node:next()
  if prev then
    rawset(prev, "m_next", next)
  else
    self.m_first = next
  end
  if next then
    rawset(next, "m_prev", prev)
  else
    self.m_last = prev
  end
  rawset(node, "m_prev", nil)
  rawset(node, "m_next", nil)
  self.m_size = self.m_size - 1
end

---Removes the node at the start of the `LinkedList`.
function LinkedList:remove_first()
  local first = self.m_first
  if not first then
    return
  end
  local next = first:next()
  self.m_first = next
  if next then
    rawset(next, "m_prev", nil)
  else
    self.m_last = nil
  end
  rawset(first, "m_next", nil)
  self.m_size = self.m_size - 1
end

---Removes the node at the end of the `LinkedList`.
function LinkedList:remove_last()
  local last = self.m_last
  if not last then
    return
  end
  local prev = last:prev()
  if prev then
    rawset(prev, "m_next", nil)
  else
    self.m_first = nil
  end
  self.m_last = prev
  rawset(last, "m_prev", nil)
  self.m_size = self.m_size - 1
end

---Finds the first node that contains the specified value.
---@param value any
---@return nviq.collections.LinkedListNode?
function LinkedList:find(value)
  local node = self.m_first
  while node do
    if node:value() == value then
      return node
    end
    node = node:next()
  end
end

---Finds the last node that contains the specified value.
---@param value any
---@return nviq.collections.LinkedListNode?
function LinkedList:find_last(value)
  local node = self.m_last
  while node do
    if node:value() == value then
      return node
    end
    node = node:prev()
  end
end

---@private
---Returns a string that represents the current object.
---@return string
function LinkedList:__tostring()
  assert(not self:has_loop(), "Loop found")
  return require("nviq.util.collections.util").iter_inspect(self, LinkedList, "LinkedList")
end

return {
  LinkedList = LinkedList,
  LinkedListNode = LinkedListNode,
}
