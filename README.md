# project.nvim

**project.nvim** is a Neovim plugin that provides project management.

## Requirements

- Neovim >= 0.11.0

## Features

- Automatically persist "projects" (cwd's)
- Manage (add/delete) "projects"

## Installation

Install the plugin with your favorite package manager:

### `vim.pack`

```lua
vim.pack.add({'https://github.com/TheLeoP/project.nvim'})
```

### [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'TheLeoP/project.nvim'
```

## API

Get a list of recent projects:

```lua
require("project").get_recent()
```

Add a project

```lua
require("project").add()
```

Delete a project

```lua
require("project").delete()
```
