-- Plugin specs. Everything but the colour scheme, snacks and treesitter loads on demand,
-- which keeps startup well under 30 ms.

local header = [[
██████╗ ███████╗██╗   ██╗███████╗███╗   ██╗██╗   ██╗
██╔══██╗██╔════╝██║   ██║██╔════╝████╗  ██║██║   ██║
██║  ██║█████╗  ██║   ██║█████╗  ██╔██╗ ██║██║   ██║
██║  ██║██╔══╝  ╚██╗ ██╔╝██╔══╝  ██║╚██╗██║╚██╗ ██╔╝
██████╔╝███████╗ ╚████╔╝ ███████╗██║ ╚████║ ╚████╔╝
╚═════╝ ╚══════╝  ╚═══╝  ╚══════╝╚═╝  ╚═══╝  ╚═══╝
                 divineOS terminal IDE]]

local standard = vim.g.devenv_keys ~= "vim"

return {
  -- Transparent background: kitty's translucency plus Hyprland's blur make the editor glass.
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    opts = { style = "night", transparent = true, styles = { sidebars = "transparent", floats = "dark" } },
    config = function(_, opts)
      require("tokyonight").setup(opts)
      vim.cmd.colorscheme("tokyonight")
    end,
  },

  -- Picker (quick open, grep, command palette), file explorer, floating terminal,
  -- LazyGit, dashboard, notifications, indent guides.
  {
    "folke/snacks.nvim",
    lazy = false,
    priority = 900,
    opts = {
      bigfile = { enabled = true },
      quickfile = { enabled = true },
      dashboard = { enabled = true, preset = { header = header } },
      explorer = { enabled = true, replace_netrw = true },
      picker = { enabled = true },
      indent = { enabled = true },
      input = { enabled = true },
      notifier = { enabled = true },
      terminal = { enabled = true },
      lazygit = { enabled = true },
      words = { enabled = true },
    },
  },

  -- Parsers install on demand (see devenv.tooling); this plugin doesn't lazy-load.
  { "nvim-treesitter/nvim-treesitter", lazy = false, build = ":TSUpdate" },

  { "nvim-tree/nvim-web-devicons", lazy = true },

  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      preset = "modern",
      spec = {
        { "<leader>f", group = "find" },
        { "<leader>g", group = "git" },
        { "<leader>l", group = "code" },
        { "<leader>d", group = "debug" },
        { "<leader>b", group = "buffer" },
      },
    },
  },

  -- Editor tabs and status line.
  {
    "akinsho/bufferline.nvim",
    event = "VeryLazy",
    opts = {
      options = {
        diagnostics = "nvim_lsp",
        always_show_bufferline = true,
        close_command = function(n) Snacks.bufdelete(n) end,
        offsets = { { filetype = "snacks_layout_box", text = "Explorer", highlight = "Directory" } },
      },
    },
  },
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    opts = {
      -- rounded powerline caps from the Nerd Font
      options = { theme = "tokyonight", globalstatus = true, component_separators = "", section_separators = { left = "\u{E0B4}", right = "\u{E0B6}" } },
    },
  },

  -- Git gutter and hunk staging; LazyGit (snacks) is the full staging UI.
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = { signs = { add = { text = "▎" }, change = { text = "▎" }, delete = { text = "▁" } } },
  },

  -- Language servers: Mason installs them (on demand, see devenv.tooling) and
  -- mason-lspconfig enables every installed one.
  {
    "mason-org/mason-lspconfig.nvim",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = { "mason-org/mason.nvim", "neovim/nvim-lspconfig", "saghen/blink.cmp" },
    config = function()
      vim.lsp.config("*", { capabilities = require("blink.cmp").get_lsp_capabilities() })
      require("mason-lspconfig").setup()
    end,
  },
  { "mason-org/mason.nvim", cmd = "Mason", opts = {} },

  -- Completion with docs and signature help.
  {
    "saghen/blink.cmp",
    version = "1.*",
    event = { "InsertEnter", "CmdlineEnter" },
    opts = {
      -- standard: Tab or Enter accepts, like VS Code. vim: Ctrl+Y accepts.
      keymap = standard and { preset = "super-tab", ["<CR>"] = { "accept", "fallback" } } or { preset = "default" },
      appearance = { nerd_font_variant = "mono" },
      completion = { documentation = { auto_show = true, auto_show_delay_ms = 200 } },
      signature = { enabled = true },
      fuzzy = { implementation = "prefer_rust" }, -- falls back to Lua when offline
    },
  },

  -- Debugging: adapters come from Mason on the first F5 (see devenv.tooling).
  {
    "mfussenegger/nvim-dap",
    lazy = true,
    dependencies = {
      "mason-org/mason.nvim",
      "jay-babu/mason-nvim-dap.nvim",
      { "rcarriga/nvim-dap-ui", dependencies = { "nvim-neotest/nvim-nio" }, opts = {} },
    },
    config = function()
      local dap, ui = require("dap"), require("dapui")
      require("mason-nvim-dap").setup({ handlers = {} })
      dap.listeners.after.event_initialized.devenv = function() ui.open() end
      dap.listeners.before.event_terminated.devenv = function() ui.close() end
      dap.listeners.before.event_exited.devenv = function() ui.close() end
      vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DiagnosticError" })
      vim.fn.sign_define("DapStopped", { text = "▶", texthl = "DiagnosticWarn", linehl = "Visual" })
    end,
  },

  { "nvim-mini/mini.pairs", event = "InsertEnter", opts = {} },
}
