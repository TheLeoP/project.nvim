local config = require("project_nvim.config")
local history = require("project_nvim.utils.history")
local M = {}

M.setup = config.setup
M.get_recent = history.get_recent

return M
