local config = require("project_nvim.config")
local history = require("project_nvim.utils.history")
local glob = require("project_nvim.utils.globtopattern")
local path = require("project_nvim.utils.path")
local uv = vim.loop
local M = {}

-- Internal states
M.attached_lsp = false
M.last_project = nil

--- Tries to return the root of the project using LSP
---@return string|nil root_dir
---@return string|nil method
function M.find_lsp_root()
  -- Returns nil or string
  local filetype = vim.api.nvim_buf_get_option(0, "filetype")
  local clients = vim.lsp.get_active_clients({ bufnr = 0 })
  if next(clients) == nil then
    return nil
  end

  for _, client in pairs(clients) do
    local filetypes = client.config.filetypes
    if
      filetypes
      and vim.tbl_contains(filetypes, filetype)
      and not vim.tbl_contains(config.options.ignore_lsp, client.name)
    then
      return client.config.root_dir, string.format('"%s" lsp', client.name)
    end
  end

  return nil
end

--- Tries to return the root of the project using pattern matching
---@return string|nil root_dir
---@return string|nil method
function M.find_pattern_root()
  local search_dir = vim.fn.expand("%:p:h", true)
  if vim.fn.has("win32") > 0 then
    search_dir = search_dir:gsub("\\", "/")
  end

  local last_dir_cache = ""
  local curr_dir_cache = {}

  local function get_parent(path)
    if path:match("%a:") then
      return path
    end
    path = path:match("^(.*)/")
    if path == "" then
      path = "/"
    end
    return path
  end

  local function get_files(file_dir)
    last_dir_cache = file_dir
    curr_dir_cache = {}

    local dir = uv.fs_scandir(file_dir)
    if dir == nil then
      return
    end

    while true do
      local file = uv.fs_scandir_next(dir)
      if file == nil then
        return
      end

      table.insert(curr_dir_cache, file)
    end
  end

  local function is(dir, identifier)
    dir = dir:match(".*/(.*)")
    return dir == identifier
  end

  local function sub(dir, identifier)
    local path = get_parent(dir)
    while true do
      if is(path, identifier) then
        return true
      end
      local current = path
      path = get_parent(path)
      if current == path then
        return false
      end
    end
  end

  local function child(dir, identifier)
    local path = get_parent(dir)
    return is(path, identifier)
  end

  local function has(dir, identifier)
    if last_dir_cache ~= dir then
      get_files(dir)
    end
    local pattern = glob.globtopattern(identifier)
    for _, file in ipairs(curr_dir_cache) do
      if file:match(pattern) ~= nil then
        return true
      end
    end
    return false
  end

  local function match(dir, pattern)
    local first_char = pattern:sub(1, 1)
    if first_char == "=" then
      return is(dir, pattern:sub(2))
    elseif first_char == "^" then
      return sub(dir, pattern:sub(2))
    elseif first_char == ">" then
      return child(dir, pattern:sub(2))
    else
      return has(dir, pattern)
    end
  end

  -- breadth-first search
  while true do
    for _, pattern in ipairs(config.options.patterns) do
      local exclude = false
      if pattern:sub(1, 1) == "!" then
        exclude = true
        pattern = pattern:sub(2)
      end
      if match(search_dir, pattern) then
        if exclude then
          break
        else
          return search_dir, "pattern " .. pattern
        end
      end
    end

    local parent = get_parent(search_dir)
    if parent == search_dir or parent == nil then
      return nil
    end

    search_dir = parent
  end
end

local on_attach_lsp = function()
  M.on_buf_enter() -- Recalculate root dir after lsp attaches
end

function M.attach_to_lsp()
  if M.attached_lsp then
    return
  end

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
  if dir == nil then
    return false
  end

  M.last_project = dir
  table.insert(history.session_projects, dir)

  if uv.cwd() ~= dir then
    if config.options.scope_chdir == "global" then
      vim.api.nvim_set_current_dir(dir)
    elseif config.options.scope_chdir == "tab" then
      vim.cmd.tcd(dir)
    elseif config.options.scope_chdir == "win" then
      vim.cmd.lcd(dir)
    else
      return false
    end

    if not config.options.silent_chdir then
      vim.notify(string.format("Set CWD to %s using %s", dir, method))
    end
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
  -- returns project root, as well as method
  for _, detection_method in ipairs(config.options.detection_methods) do
    local root, method = find_root[detection_method]()
    if root == nil then
      return nil
    end
    return root, method
  end
end

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
  if not is_in_whitelist then
    return false
  end

  return true
end

function M.on_buf_enter()
  if vim.v.vim_did_enter == 0 then
    return
  end

  if not M.is_file() then
    return
  end

  local current_dir = vim.fn.expand("%:p:h", true)
  if path.is_excluded(current_dir) then
    return
  end

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

    if vim.tbl_contains(config.options.detection_methods, "lsp") then
      M.attach_to_lsp()
    end
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
