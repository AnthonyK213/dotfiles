local Stack = require("nviq.util.collections").Stack

local M = {}

local function add(args)
  local result = 0
  for _, arg in ipairs(args) do
    result = result + arg
  end
  return result
end

local function sub(args)
  local result = args[1]
  if #args == 0 then
    error("Wrong number of arguments.")
  elseif #args == 1 then
    return -result
  else
    for i = 2, #args, 1 do
      result = result - args[i]
    end
    return result
  end
end

local function mult(args)
  local result = 1
  for _, arg in ipairs(args) do
    result = result * arg
  end
  return result
end

local function div(args)
  local result = args[1]
  if #args == 0 then
    error("Wrong number of arguments.")
  elseif #args == 1 then
    return 1 / result
  else
    for i = 2, #args, 1 do
      result = result / args[i]
    end
    return result
  end
end

local function exp(args)
  if #args == 0 then
    return math.exp(1)
  elseif #args == 1 then
    return math.exp(args[1])
  else
    error("Wrong number of arguments.")
  end
end

local function log(args)
  if #args == 1 then
    return math.log(args[1])
  elseif #args == 2 then
    return math.log(args[1], args[2])
  else
    error("Wrong number of arguments.")
  end
end

local function pow(args)
  local pow_res = 1
  for i = 2, #args, 1 do
    pow_res = pow_res * args[i]
  end
  return math.pow(args[1], pow_res)
end

local function fact(args)
  local x = args[1]
  assert(x >= 0, "Input number must be positive or 0.")
  assert(math.floor(x) == x, "Input number must be an integer.")
  local result = 1
  if x == 0 then
    return result
  end
  for i = 1, x, 1 do
    result = result * i
  end
  return result
end

---@type table<string, fun(args:number[]):number>
local _lisp_func_map = {
  ["+"] = add,
  ["-"] = sub,
  ["*"] = mult,
  ["/"] = div,
  abs   = function(args) return math.abs(args[1]) end,
  acos  = function(args) return math.acos(args[1]) end,
  asin  = function(args) return math.asin(args[1]) end,
  atan  = function(args) return math.atan(args[1]) end,
  atan2 = function(args) return math.atan2(args[1], args[2]) end,
  ceil  = function(args) return math.ceil(args[1]) end,
  cos   = function(args) return math.cos(args[1]) end,
  deg   = function(args) return math.deg(args[1]) end,
  exp   = exp,
  fact  = fact,
  floor = function(args) return math.floor(args[1]) end,
  log   = log,
  log10 = function(args) return math.log10(args[1]) end,
  pow   = pow,
  pi    = function(args) return math.pi * mult(args) end,
  rad   = function(args) return math.rad(args[1]) end,
  sin   = function(args) return math.sin(args[1]) end,
  sqrt  = function(args) return math.sqrt(args[1]) end,
  tan   = function(args) return math.tan(args[1]) end,
}

---@class nviq.appl.evaluate.AstNode
---@field m_value string
---@field m_child nviq.appl.evaluate.AstNode[]
local AstNode = {}

AstNode.__index = AstNode

---Constructs a node with value.
---@param value string
---@return nviq.appl.evaluate.AstNode
function AstNode.new(value)
  local node = {
    m_value = value,
    m_child = {},
  }
  setmetatable(node, AstNode)
  return node
end

---Returns whether this node is a leaf node.
---@return boolean
function AstNode:is_leaf()
  return #self.m_child == 0
end

---Inserts a child node to this node.
---@param child nviq.appl.evaluate.AstNode
function AstNode:insert_child(child)
  table.insert(self.m_child, child)
end

---Evaluates the node.
---@return number
function AstNode:eval()
  if self:is_leaf() then
    local value = tonumber(self.m_value)
    if value then
      return value
    end
  end

  local func = _lisp_func_map[self.m_value]
  if not func then
    error("Invalid function")
  end
  local args = {}
  for i, child in ipairs(self.m_child) do
    args[i] = child:eval()
  end
  return func(args)
end

---@class nviq.appl.evaluate.Ast
---@field private m_root nviq.appl.evaluate.AstNode
local Ast = {}

Ast.__index = Ast

---Parses the lisp expression into AST.
---@param str string
---@return nviq.appl.evaluate.Ast
function Ast.parse(str)
  local pre_parse = str:gsub("[%(%)]", function(s) return " " .. s .. " " end)
  local seg_arr = vim.split(vim.trim(pre_parse), "%s+")
  local frame_stack = Stack()
  local node_stack = Stack()

  for _, seg in ipairs(seg_arr) do
    if seg == "(" then
      -- New frame.
      frame_stack:push(node_stack:count() + 1)
    elseif seg == ")" then
      -- Merge current frame, pop the frame_stack.
      local top = frame_stack:pop()
      local child = Stack()
      while node_stack:count() > top do
        child:push(node_stack:pop())
      end
      local frame_node = node_stack:peek()
      while child:count() > 0 do
        frame_node:insert_child(child:pop())
      end
    else
      -- Push the node to node_stack.
      node_stack:push(AstNode.new(seg))
    end
  end

  if node_stack:count() ~= 1 then
    error("Imbalanced parenthesis")
  end

  local ast = { m_root = node_stack:pop() }
  setmetatable(ast, Ast)
  return ast
end

---Evaluates the AST.
---@return number
function Ast:eval()
  return self.m_root:eval()
end

---Evaluates the lisp expression.
---@param str string
---@return number
function M.eval(str)
  local ast = Ast.parse(str)
  return ast:eval()
end

return M
