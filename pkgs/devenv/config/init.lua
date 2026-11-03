-- devenv: the divineOS terminal IDE, a Neovim distribution.
-- Launched as `devenv` (NVIM_APPNAME=devenv), so its plugins, state and config live in
-- ~/.config/devenv, ~/.local/share/devenv, … and never touch a personal Neovim setup.
-- Personal overrides go in ~/.config/devenv/user.lua, which runs last.

local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h")
vim.opt.rtp:prepend(root)

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Keymap preset: "standard" (GUI shortcuts, opens files in insert mode) or "vim".
local keys_file = vim.fn.stdpath("config") .. "/keys"
vim.g.devenv_keys = vim.fn.filereadable(keys_file) == 1 and vim.fn.readfile(keys_file)[1] or "standard"

vim.api.nvim_create_user_command("DevenvKeys", function(cmd)
  vim.fn.mkdir(vim.fn.stdpath("config"), "p")
  vim.fn.writefile({ cmd.args }, keys_file)
  vim.notify("Keymap preset set to " .. cmd.args .. "; restart devenv to apply", vim.log.levels.INFO, { title = "devenv" })
end, { nargs = 1, complete = function() return { "standard", "vim" } end, desc = "Choose the standard or vim keymap preset" })

-- ── Editor behaviour ──
local o = vim.opt
o.number = true
o.mouse = "a"
o.mousemodel = "popup_setpos"
o.clipboard = "unnamedplus" -- system clipboard (wl-clipboard)
o.termguicolors = true
o.signcolumn = "yes"
o.cursorline = true
o.scrolloff = 6
o.sidescrolloff = 8
o.wrap = false
o.splitright = true
o.splitbelow = true
o.ignorecase = true
o.smartcase = true
o.expandtab = true
o.shiftwidth = 4
o.tabstop = 4
o.smartindent = true
o.undofile = true
o.updatetime = 250
o.timeoutlen = 400
o.laststatus = 3
o.showmode = false
o.confirm = true
o.pumheight = 12
o.virtualedit = "block"
o.winborder = "rounded"
o.fillchars = { eob = " " }

vim.diagnostic.config({
  virtual_text = { spacing = 2, prefix = "●" },
  severity_sort = true,
  float = { border = "rounded" },
})

-- ── Plugins (lazy.nvim, pinned by lazy-lock.json) ──
local data = vim.fn.stdpath("data")
local lazyroot = data .. "/lazy"
-- The package ships every plugin pre-fetched, so the first launch works offline.
if not vim.uv.fs_stat(lazyroot) and vim.uv.fs_stat(root .. "/plugins") then
  vim.fn.mkdir(data, "p")
  vim.fn.system({ "cp", "-r", root .. "/plugins", lazyroot })
end
local lockfile = vim.fn.stdpath("config") .. "/lazy-lock.json"
if not vim.uv.fs_stat(lockfile) then
  vim.fn.mkdir(vim.fn.stdpath("config"), "p")
  vim.uv.fs_copyfile(root .. "/lazy-lock.json", lockfile)
end

local lazypath = lazyroot .. "/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", "https://github.com/folke/lazy.nvim.git", lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({ { "devenv: couldn't fetch plugins, starting without them\n" .. out, "WarningMsg" } }, true, {})
    lazypath = nil
  end
end

if lazypath then
  vim.opt.rtp:prepend(lazypath)
  require("lazy").setup(require("devenv.plugins"), {
    lockfile = lockfile,
    install = { colorscheme = { "tokyonight" } },
    change_detection = { enabled = false },
    ui = { border = "rounded" },
    performance = {
      rtp = {
        paths = { root }, -- lazy resets the runtimepath; keep devenv's own modules on it
        disabled_plugins = { "gzip", "netrwPlugin", "tarPlugin", "tohtml", "tutor", "zipPlugin" },
      },
    },
  })
  require("devenv.tooling").setup()
end

require("devenv.keys")

local user = vim.fn.stdpath("config") .. "/user.lua"
if vim.uv.fs_stat(user) then
  dofile(user)
end
