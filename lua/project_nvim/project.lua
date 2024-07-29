local config = require("project_nvim.config")
local history = require("project_nvim.utils.history")
local glob = require("project_nvim.utils.globtopattern")
local path = require("project_nvim.utils.path")
local uv = vim.uv
local M = {}

-- Internal states
M.attached_lsp = false
M.last_project = nil ---@type string?

--- Tries to return the root of the project using LSP
---@return string|nil root_dir
---@return string|nil method
function M.find_lsp_root()
  ---@type string
  local workspace_root = vim
    .iter(vim.lsp.get_clients({ bufnr = 0 }))
    :filter(function(client) return not vim.tbl_contains(config.options.ignore_lsp, client.name) end)
    :map(function(client) return client.workspace_folders end)
    :flatten(1)
    :map(function(workspace_folder) return workspace_folder.name end)
    :find(function(root)
      root = path.normalize(root) .. "/"
      local current_file = vim.api.nvim_buf_get_name(0)
      current_file = path.normalize(current_file)
      return current_file:find(vim.pesc(root))
    end)

  if not workspace_root then return end

  return workspace_root, "lsp"
end

--- Tries to return the root of the project using pattern matching
---@return string|nil root_dir
---@return string|nil method
function M.find_pattern_root()
  local search_dir = vim.fn.expand("%:p:h", true)
  search_dir = path.normalize(search_dir)

  local last_dir_cache = ""
  local curr_dir_cache = {}

  local function get_files(file_dir)
    last_dir_cache = file_dir
    curr_dir_cache = {}

    for file_name in vim.fs.dir(file_dir) do
      table.insert(curr_dir_cache, file_name)
    end
  end

  local function is_equal(dir, identifier) return vim.fs.basename(dir) == identifier end

  local function is_descendant(dir, identifier)
    for name in vim.fs.parents(dir) do
      if is_equal(name, identifier) then return true end
    end
    return false
  end

  local function is_direct_descendant(dir, identifier)
    local parent = vim.fs.dirname(dir)
    return is_equal(parent, identifier)
  end

  local function has(dir, identifier)
    if last_dir_cache ~= dir then get_files(dir) end
    local pattern = glob.globtopattern(identifier)
    for _, file in ipairs(curr_dir_cache) do
      if file:match(pattern) ~= nil then return true end
    end
    return false
  end

  local match_func = {
    ["="] = is_equal,
    ["^"] = is_descendant,
    [">"] = is_direct_descendant,
    ["default"] = has,
  }

  local function match(dir, pattern)
    local modifier = pattern:sub(1, 1)
    local identifier = pattern:sub(2)

    if match_func[modifier] then
      return match_func[modifier](dir, identifier)
    else
      return match_func["default"](dir, pattern)
    end
  end

  local paths = {
    search_dir,
  }
  for name in vim.fs.parents(search_dir) do
    table.insert(paths, name)
  end

  for _, name in ipairs(paths) do
    for _, pattern in ipairs(config.options.patterns) do
      local modifier = pattern:sub(1, 1)
      if modifier == "!" then pattern = pattern:sub(2) end
      if match(name, pattern) then
        if modifier == "!" then
          break
        else
          return name, ("pattern %s"):format(pattern)
        end
      end
    end
  end

  return nil, nil
end

local on_attach_lsp = function()
  -- Recalculate root dir after lsp attaches
  M.on_buf_enter()
end

function M.attach_to_lsp()
  if M.attached_lsp then return end

  local autocmd_group = vim.api.nvim_create_augroup("project_nvim_lsp_attach", { clear = true })
  vim.api.nvim_create_autocmd("LspAttach", {
    group = autocmd_group,
    pattern = "*",
    callback = on_attach_lsp,
    desc = "Change cwd to project root using LSP",
    nested = true,
  })

  M.attached_lsp = true
end

function M.set_cwd(dir, method)
  if dir == nil then return false end

  local chdir = {
    global = function() vim.api.nvim_set_current_dir(dir) end,
    tab = function() vim.cmd.tcd(dir) end,
    win = function() vim.cmd.lcd(dir) end,
  }
  if chdir[config.options.scope_chdir] == nil then return false end

  M.last_project = dir
  table.insert(history.session_projects, dir)

  if uv.cwd() ~= dir then
    chdir[config.options.scope_chdir]()

    if not config.options.silent_chdir then vim.notify(("Set CWD to %s using %s"):format(dir, method)) end
  end
  return true
end

--- Tries to return the root of the project
---@return string|nil root_dir
---@return string|nil method
function M.get_project_root()
  local find_root = {
    lsp = M.find_lsp_root,
    pattern = M.find_pattern_root,
  }
  for _, detection_method in ipairs(config.options.detection_methods) do
    local root, method = find_root[detection_method]()
    if not root then return end
    return root, method
  end
end

---@return boolean
function M.is_file()
  local buf_type = vim.api.nvim_buf_get_option(0, "buftype")

  local whitelisted_buf_type = { "", "acwrite" }
  local is_in_whitelist = false
  for _, wtype in ipairs(whitelisted_buf_type) do
    if buf_type == wtype then
      is_in_whitelist = true
      break
    end
  end
  if not is_in_whitelist then return false end

  return true
end

function M.on_buf_enter()
  if vim.v.vim_did_enter == 0 or not M.is_file() then return end

  local current_dir = vim.fn.expand("%:p:h", true)
  if not path.exists(current_dir) or path.is_excluded(current_dir) then return end

  local root, method = M.get_project_root()
  M.set_cwd(root, method)
end

function M.init()
  local autocmd_group = vim.api.nvim_create_augroup("project_nvim", { clear = true })

  if not config.options.manual_mode then
    vim.api.nvim_create_autocmd({ "VimEnter", "BufEnter" }, {
      group = autocmd_group,
      pattern = "*",
      callback = M.on_buf_enter,
      desc = "Change cwd to project root using patterns",
      nested = true,
    })

    if vim.tbl_contains(config.options.detection_methods, "lsp") then M.attach_to_lsp() end
  end

  vim.api.nvim_create_user_command("ProjectRoot", M.on_buf_enter, {
    bang = true,
  })

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = autocmd_group,
    pattern = "*",
    callback = history.write_projects_to_history,
    desc = "Write project.nvim history to file before closing Neovim",
  })

  history.read_projects_from_history()
end

return M
