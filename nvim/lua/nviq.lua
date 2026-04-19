require("nviq.core")
require("nviq.appl")

if vim.g.vscode then
  require("nviq.appl.vscode")
elseif _G.NVIQ.settings.general.offline then
  require("nviq.appl.optional")
  require("nviq.appl.offline")
else
  require("nviq.appl.optional")
  require("nviq.pack")
end
