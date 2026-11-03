-- Keymaps. Both presets get Space-leader maps (which-key shows them) and VS Code's F-keys.
-- "standard" adds GUI shortcuts (Ctrl+S/C/X/V/Z/A/P/B/W…), Shift+arrow selection, and
-- opens files ready to type; Esc still drops into Vim's Normal mode.
-- "vim" leaves every Vim key alone.

local function bind(modes, lhs, rhs, desc, opts)
  for _, key in ipairs(type(lhs) == "table" and lhs or { lhs }) do
    vim.keymap.set(modes, key, rhs, vim.tbl_extend("force", { desc = desc }, opts or {}))
  end
end

local function picker(name)
  return function() Snacks.picker[name]() end
end
local function dap(fn)
  return function() require("dap")[fn]() end
end
local function git(fn)
  return function() require("gitsigns")[fn]() end
end
local function debug()
  require("devenv.tooling").debug()
end
local function format()
  vim.lsp.buf.format({ async = true })
end

local function save()
  if vim.api.nvim_buf_get_name(0) ~= "" then
    return vim.cmd("silent! update")
  end
  vim.ui.input({ prompt = "Save as: ", completion = "file" }, function(path)
    if path and path ~= "" then
      vim.cmd.write(vim.fn.fnameescape(path))
    end
  end)
end

-- ── Both presets ──
bind({ "n", "i", "v", "s" }, "<C-s>", save, "Save")
bind("n", "<Esc>", "<Cmd>nohlsearch<CR>", "Clear search highlight")
bind("n", "<C-h>", "<C-w>h", "Window left")
bind("n", "<C-j>", "<C-w>j", "Window down")
bind("n", "<C-k>", "<C-w>k", "Window up")
bind("n", "<C-l>", "<C-w>l", "Window right")
bind("n", "gd", picker("lsp_definitions"), "Go to definition")

for _, m in ipairs({
  { "e", function() Snacks.explorer() end, "File explorer" },
  { "ff", picker("files"), "Find file" },
  { "fg", picker("grep"), "Search in project" },
  { "fb", picker("buffers"), "Open buffers" },
  { "fr", picker("recent"), "Recent files" },
  { "fc", picker("commands"), "Commands" },
  { "fk", picker("keymaps"), "Keymaps" },
  { "fh", picker("help"), "Help pages" },
  { "gg", function() Snacks.lazygit() end, "LazyGit: stage, commit, push" },
  { "gs", picker("git_status"), "Changed files" },
  { "gl", picker("git_log"), "Git log" },
  { "gb", git("blame_line"), "Blame line" },
  { "gh", git("stage_hunk"), "Stage hunk" },
  { "gr", git("reset_hunk"), "Reset hunk" },
  { "gp", git("preview_hunk"), "Preview hunk" },
  { "t", function() Snacks.terminal.toggle() end, "Terminal" },
  { "la", vim.lsp.buf.code_action, "Code action" },
  { "lr", vim.lsp.buf.rename, "Rename symbol" },
  { "lf", format, "Format file" },
  { "ls", picker("lsp_symbols"), "Symbols in file" },
  { "lS", picker("lsp_workspace_symbols"), "Symbols in project" },
  { "ld", picker("diagnostics"), "Problems" },
  { "lm", "<Cmd>Mason<CR>", "Mason: servers & debuggers" },
  { "db", dap("toggle_breakpoint"), "Toggle breakpoint" },
  { "dc", debug, "Start / continue" },
  { "do", dap("step_over"), "Step over" },
  { "di", dap("step_into"), "Step into" },
  { "dO", dap("step_out"), "Step out" },
  { "dq", dap("terminate"), "Stop" },
  { "du", function() require("dapui").toggle() end, "Debugger panels" },
  { "bd", function() Snacks.bufdelete() end, "Close buffer" },
  { "bn", "<Cmd>bnext<CR>", "Next buffer" },
  { "bp", "<Cmd>bprevious<CR>", "Previous buffer" },
  { "q", "<Cmd>confirm qall<CR>", "Quit" },
}) do
  bind("n", "<leader>" .. m[1], m[2], m[3])
end

-- VS Code function keys (Shift+F-keys arrive as F13+ in some terminals).
bind({ "n", "i" }, "<F2>", vim.lsp.buf.rename, "Rename symbol")
bind({ "n", "i" }, "<F12>", picker("lsp_definitions"), "Go to definition")
bind({ "n", "i" }, { "<S-F12>", "<F24>" }, picker("lsp_references"), "Find references")
bind({ "n", "i" }, "<F5>", debug, "Debug: start / continue")
bind({ "n", "i" }, { "<S-F5>", "<F17>" }, dap("terminate"), "Debug: stop")
bind({ "n", "i" }, "<F9>", dap("toggle_breakpoint"), "Toggle breakpoint")
bind({ "n", "i" }, "<F10>", dap("step_over"), "Step over")
bind({ "n", "i" }, "<F11>", dap("step_into"), "Step into")
bind({ "n", "i" }, { "<S-F11>", "<F23>" }, dap("step_out"), "Step out")

if vim.g.devenv_keys == "vim" then
  return
end

-- ── Standard preset ──
vim.opt.keymodel = "startsel,stopsel" -- Shift+arrows start a selection…
vim.opt.selectmode = "mouse,key" -- …and typing replaces it, as in a GUI editor

bind({ "n", "i", "v", "s" }, "<C-z>", "<Cmd>undo<CR>", "Undo")
bind({ "n", "i", "v", "s" }, "<C-y>", "<Cmd>redo<CR>", "Redo")
bind({ "n", "i" }, "<C-a>", "<Esc>gg0vG$<C-g>", "Select all")
-- Copy / cut take the selection, or the whole line when nothing is selected.
bind({ "v", "s" }, "<C-c>", '"+y', "Copy")
bind("n", "<C-c>", '"+yy', "Copy line")
bind("i", "<C-c>", '<Cmd>normal! "+yy<CR>', "Copy line")
bind({ "v", "s" }, "<C-x>", '"+d', "Cut")
bind("n", "<C-x>", '"+dd', "Cut line")
bind("i", "<C-x>", '<Cmd>normal! "+dd<CR>', "Cut line")
bind({ "n", "v", "s" }, "<C-v>", '"+P', "Paste") -- Ctrl+Q still starts a block selection
bind("i", "<C-v>", "<C-r><C-o>+", "Paste")
bind("c", "<C-v>", "<C-r>+", "Paste")

bind({ "n", "i" }, "<C-p>", picker("files"), "Quick open")
bind({ "n", "i" }, { "<C-S-p>", "<F1>" }, picker("commands"), "Command palette")
bind({ "n", "i" }, "<C-f>", picker("lines"), "Find in file")
bind({ "n", "i" }, "<C-S-f>", picker("grep"), "Search in project")
bind({ "n", "i" }, "<C-b>", function() Snacks.explorer() end, "Toggle explorer")
bind({ "n", "i", "t" }, "<C-`>", function() Snacks.terminal.toggle() end, "Toggle terminal")
bind({ "n", "i" }, "<C-\\>", function() Snacks.terminal.toggle() end, "Toggle terminal")
bind({ "n", "i" }, "<C-w>", function() Snacks.bufdelete() end, "Close editor")
bind({ "n", "i" }, { "<C-PageDown>", "<C-Tab>" }, "<Cmd>bnext<CR>", "Next editor")
bind({ "n", "i" }, { "<C-PageUp>", "<C-S-Tab>" }, "<Cmd>bprevious<CR>", "Previous editor")
bind({ "n", "i" }, "<C-.>", vim.lsp.buf.code_action, "Quick fix")
bind({ "n", "i", "v" }, "<S-A-f>", format, "Format")
bind({ "n", "i" }, "<C-g>", function()
  vim.ui.input({ prompt = "Go to line: " }, function(n)
    if tonumber(n) then
      vim.api.nvim_win_set_cursor(0, { math.min(tonumber(n), vim.api.nvim_buf_line_count(0)), 0 })
    end
  end)
end, "Go to line")

bind("n", "<A-Up>", "<Cmd>move .-2<CR>==", "Move line up")
bind("n", "<A-Down>", "<Cmd>move .+1<CR>==", "Move line down")
bind("i", "<A-Up>", "<Esc><Cmd>move .-2<CR>==gi", "Move line up")
bind("i", "<A-Down>", "<Esc><Cmd>move .+1<CR>==gi", "Move line down")
bind("v", "<A-Up>", ":move '<-2<CR>gv=gv", "Move selection up", { silent = true })
bind("v", "<A-Down>", ":move '>+1<CR>gv=gv", "Move selection down", { silent = true })

-- Terminals send Ctrl+/ as Ctrl+_.
bind("n", { "<C-/>", "<C-_>" }, "gcc", "Toggle comment", { remap = true })
bind("v", { "<C-/>", "<C-_>" }, "gc", "Toggle comment", { remap = true })
bind("i", { "<C-/>", "<C-_>" }, "<Cmd>normal gcc<CR>", "Toggle comment")

-- Open files ready to type, like a GUI editor.
vim.api.nvim_create_autocmd("BufEnter", {
  group = vim.api.nvim_create_augroup("devenv.insert", {}),
  callback = function(ev)
    local bo = vim.bo[ev.buf]
    if bo.buftype == "" and bo.modifiable and vim.api.nvim_buf_get_name(ev.buf) ~= "" and vim.fn.mode() == "n" then
      vim.schedule(function() vim.cmd.startinsert() end)
    end
  end,
})
