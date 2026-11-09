---@class nviq.util.c.Iterable
---@field count fun(self: nviq.util.c.Iterable): integer
---@field iter fun(self: nviq.util.c.Iterable): vim.Iter

return {
  Deque         = require("nviq.util.c.deque"),
  List          = require("nviq.util.c.list"),
  PriorityQueue = require("nviq.util.c.priority_queue"),
  Stack         = require("nviq.util.c.stack"),
}
