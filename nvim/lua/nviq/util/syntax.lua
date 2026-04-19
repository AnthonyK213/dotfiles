local collections = require("nviq.util.collections")
local List = collections.List
local Deque = collections.Deque

local M = {}

-------------------------------------Syntax-------------------------------------

---@class nviq.util.syntax.Syntax
---@field private m_data { treesitter: table[], syntax: table[], extmarks: table[], semantic_tokens: table[] }
local Syntax = {}

---@private
Syntax.__index = Syntax

---
---@param bufnr? integer Buffer number.
---@param row? integer 0-based row number.
---@param col? integer 0-based column number.
---@return nviq.util.syntax.Syntax
function Syntax.get(bufnr, row, col)
  local syntax = { m_data = vim.inspect_pos(bufnr, row, col) }
  setmetatable(syntax, Syntax)
  return syntax
end

---Returns the buffer number.
---@return integer
function Syntax:buffer()
  return rawget(self.m_data, "buffer")
end

---Returns the row number (0-based).
---@return integer
function Syntax:row()
  return rawget(self.m_data, "row")
end

---Returns the column number (0-based).
---@return integer
function Syntax:col()
  return rawget(self.m_data, "col")
end

---Matches syntax name with vim regex.
---@param pattern string|{ syntax: string?, treesitter: string?, semantic_tokens: string? }
---@return boolean matched True if matched.
function Syntax:match(pattern)
  local target_map = {
    syntax          = "hl_group",
    treesitter      = "capture",
    semantic_tokens = "type"
  }

  ---The matcher.
  ---@param field string
  ---@param regex vim.regex
  ---@return boolean
  local matcher = function(field, regex)
    if regex and self.m_data[field] then
      for _, spec in ipairs(self.m_data[field]) do
        if regex:match_str(spec[target_map[field]]) then
          return true
        end
      end
    end
    return false
  end

  for field, _ in pairs(target_map) do
    local pat = type(pattern) == "string" and pattern or pattern[field]
    if pat then
      if matcher(field, vim.regex(pat)) then
        return true
      end
    end
  end

  return false
end

-------------------------------------TSNode-------------------------------------

---@class nviq.util.syntax.TSNode
---@field private m_node TSNode
local TSNode = {}

---@private
TSNode.__index = TSNode

---Constructor.
---@param node? TSNode
---@return nviq.util.syntax.TSNode
function TSNode.new(node)
  local o = {
    m_node = node,
  }
  setmetatable(o, TSNode)
  return o
end

function TSNode:is_nil()
  return self.m_node == nil
end

---@private
---Make sure the predicate is a function, except for `string` which means the
---predicate is to find the exact `type`.
---@param predicate string|string[]|fun(node: TSNode):boolean The predicate.
---@return nil|fun(node: TSNode):boolean
local function _check_predicate(predicate)
  if type(predicate) == "function" then
    return predicate
  elseif type(predicate) == "string" then
    return function(item)
      return item:type() == predicate
    end
  elseif vim.islist(predicate) then
    return function(item)
      return vim.list_contains(predicate, item:type())
    end
  end
end

---@private
local function _check_limit(limit)
  return (type(limit) == "number" and limit > 0) and limit or 1 / 0
end

---@private
---BFS.
---Include the root node.
---@param node TSNode
---@param predicate fun(node: TSNode):boolean
---@param option { limit: integer, recursive: boolean, type: "bfs"|"dfs" }
---@return nviq.collections.List
local function _find_children_bfs(node, predicate, option)
  local result = List.new()
  local deque = Deque(node)
  local depth = 0
  local last = node
  local limit = _check_limit(option.limit)
  while deque:count() > 0 do
    if option.recursive and depth > 1 then
      break
    end
    local node_cur = deque:pop_front() --[[@as TSNode]]
    if predicate(node_cur) then
      if result:count() >= limit then
        break
      end
      result:add(TSNode.new(node_cur))
    end
    for child in node_cur:iter_children() do
      deque:push_back(child)
    end
    if node_cur == last then
      depth = depth + 1
      if deque:count() > 0 then
        last = deque:get_back()
      end
    end
  end
  return result
end

---@private
---DFS
---Exclude the root node.
---@param node TSNode
---@param predicate fun(node: TSNode):boolean
---@param option { limit: integer, recursive: boolean, type: "bfs"|"dfs" }
---@return nviq.collections.List
local function _find_children_dfs(node, predicate, option)
  ---
  ---@param node_ TSNode
  ---@param predicate_ fun(node: TSNode):boolean
  ---@param result_ nviq.collections.List
  ---@param option_ { limit: integer, recursive: boolean, type: "bfs"|"dfs" }
  local function dfs_(node_, predicate_, result_, option_)
    if not node_ then return end
    for child, _ in node_:iter_children() do
      if predicate_(child) then
        if result_:count() >= option_.limit then
          return
        end
        result_:add(TSNode.new(child))
      end
      if option.recursive then
        dfs_(child, predicate_, result_, option_)
      end
    end
  end
  local result = List.new()
  local opt = vim.deepcopy(option)
  opt.limit = _check_limit(option.limit)
  dfs_(node, predicate, result, opt)
  return result
end

---Find the first child node by a predicate.
---@param predicate string|string[]|fun(node: TSNode):boolean The predicate.
---@param option? { limit: integer, recursive: boolean, type: "bfs"|"dfs" }
---@return nviq.util.syntax.TSNode
function TSNode:find_first_child(predicate, option)
  local p = _check_predicate(predicate)
  if p then
    local option_ = vim.deepcopy(option or {})
    option_.limit = 1
    local list = self:find_children(p, option_)
    if list:any() then
      return list[1]
    end
  end
  return TSNode.new()
end

---Find all child node by a predicate.
---@param predicate string|string[]|fun(node: TSNode):boolean The predicate.
---@param option? { limit: integer, recursive: boolean, type: "bfs"|"dfs" }
---@return nviq.collections.List
function TSNode:find_children(predicate, option)
  option = option or {}
  local p = _check_predicate(predicate)
  if self:is_nil() or not p then return List.new() end
  return (option.type == "bfs"
    and _find_children_bfs
    or _find_children_dfs)(self.m_node, p, option)
end

---Find the first appeared ancestor by `predicate`.
---@param predicate string|string[]|fun(node: TSNode):boolean The predicate.
---@return nviq.util.syntax.TSNode
function TSNode:find_ancestor(predicate)
  local p = _check_predicate(predicate)
  if not self:is_nil() and p then
    local current = self.m_node:parent()
    while current do
      if p(current) then
        return TSNode.new(current)
      end
      current = current:parent()
    end
  end
  return TSNode.new()
end

---Get reverse lookup table for query.
---@param query vim.treesitter.Query
---@return table
function M.captures_reverse_lookup(query)
  local captures = {}
  for k, v in pairs(query.captures) do
    captures[v] = k
  end
  return captures
end

M.Syntax = Syntax
M.TSNode = TSNode

return M
