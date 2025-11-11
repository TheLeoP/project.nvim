local M = {}

---@class ProjectOptions
---@field manual_mode boolean
---@field detection_methods string[]
---@field patterns string[]
---@field ignore_lsp string[]
---@field exclude_dirs string[]
---@field show_hidden boolean
---@field silent_chdir boolean
---@field scope_chdir  "global"|'tab'|'win'
---@field find_files boolean|fun(prompt_bufnr: number): boolean

---@class ProjectOptionsPartial
---@field manual_mode? boolean
---@field detection_methods? string[]
---@field patterns? string[]
---@field ignore_lsp? string[]
---@field exclude_dirs? string[]
---@field show_hidden? boolean
---@field silent_chdir? boolean
---@field scope_chdir?  "global"|'tab'|'win'
---@field find_files? boolean|fun(prompt_bufnr: number): boolean

---@type ProjectOptions
M.defaults = {
  -- Manual mode doesn't automatically change your root directory, so you have
  -- the option to manually do so using `:ProjectRoot` command.
  manual_mode = false,

  -- Methods of detecting the root directory. **"lsp"** uses the native neovim
  -- lsp, while **"pattern"** uses vim-rooter like glob pattern matching. Here
  -- order matters: if one is not detected, the other is used as fallback. You
  -- can also delete or rearangne the detection methods.
  detection_methods = { "lsp", "pattern" },

  -- All the patterns used to detect root dir, when **"pattern"** is in
  -- detection_methods
  patterns = { ".git", "_darcs", ".hg", ".bzr", ".svn", "Makefile", "package.json" },

  -- Table of lsp clients to ignore by name
  -- eg: { "efm", ... }
  ignore_lsp = {},

  -- Don't calculate root dir on specific directories
  -- Ex: { "~/.cargo/*", ... }
  ---@type string[]
  exclude_dirs = {},

  -- Show hidden files in telescope
  show_hidden = false,

  -- When set to false, you will get a message when project.nvim changes your
  -- directory.
  silent_chdir = true,

  -- What scope to change the directory, valid options are
  -- * global (default)
  -- * tab
  -- * win
  scope_chdir = "global",
  find_files = true,
}

---@type ProjectOptions
M.options = nil

---@param options? ProjectOptionsPartial
M.setup = function(options)
  M.options = vim.tbl_deep_extend("force", M.defaults, options or {})

  local glob = require("project_nvim.utils.globtopattern")
  M.options.exclude_dirs = vim.iter(M.options.exclude_dirs):map(
    ---@param pattern string
    ---@return string
    function(pattern)
      if vim.startswith(pattern, "~/") then pattern = vim.fn.expand(pattern) end
      return glob.globtopattern(pattern)
    end
  ) --[=[@as string[]]=]

  vim.o.autochdir = false
end

return M
