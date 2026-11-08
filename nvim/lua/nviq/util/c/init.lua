---@class nviq.util.c.Iterable
---@field iter fun(self:nviq.util.c.Iterable):(fun():...)

return {
  Deque         = require("nviq.util.c.deque"),
  List          = require("nviq.util.c.list"),
  PriorityQueue = require("nviq.util.c.priority_queue"),
  Stack         = require("nviq.util.c.stack"),
}
