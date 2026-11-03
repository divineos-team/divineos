-- Language tooling on demand. The first time a filetype is opened, devenv fetches its
-- treesitter parser and language server; the first F5 fetches its debugger.

local M = {}

-- filetype → Mason packages
M.tools = {
  lua = { lsp = "lua-language-server" },
  python = { lsp = "basedpyright", dap = "debugpy" },
  rust = { lsp = "rust-analyzer", dap = "codelldb" },
  go = { lsp = "gopls", dap = "delve" },
  c = { lsp = "clangd", dap = "codelldb" },
  cpp = { lsp = "clangd", dap = "codelldb" },
  javascript = { lsp = "typescript-language-server", dap = "js-debug-adapter" },
  typescript = { lsp = "typescript-language-server", dap = "js-debug-adapter" },
  javascriptreact = { lsp = "typescript-language-server" },
  typescriptreact = { lsp = "typescript-language-server" },
  json = { lsp = "json-lsp" },
  yaml = { lsp = "yaml-language-server" },
  toml = { lsp = "taplo" },
  sh = { lsp = "bash-language-server" },
  bash = { lsp = "bash-language-server" },
  html = { lsp = "html-lsp" },
  css = { lsp = "css-lsp" },
  markdown = { lsp = "marksman" },
  zig = { lsp = "zls" },
}

local pending = {}

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "devenv" })
end

--- Make sure Mason package `name` is installed, then call `on_ready(fresh)`, where
--- `fresh` says whether it was installed just now.
function M.mason(name, on_ready)
  local registry = require("mason-registry")
  registry.refresh(vim.schedule_wrap(function()
    local ok, pkg = pcall(registry.get_package, name)
    if not ok then
      return notify("Mason has no package " .. name, vim.log.levels.WARN)
    end
    if pkg:is_installed() then
      return on_ready(false)
    end
    if pending[name] then
      return
    end
    pending[name] = true
    notify("Installing " .. name .. "…")
    pkg:install({}, vim.schedule_wrap(function(success, err)
      pending[name] = nil
      if success then
        notify(name .. " installed")
        on_ready(true)
      else
        notify(name .. " failed to install: " .. tostring(err), vim.log.levels.ERROR)
      end
    end))
  end))
end

local function on_filetype(ev)
  local buf, ft = ev.buf, ev.match
  if vim.bo[buf].buftype ~= "" then
    return
  end

  -- Highlighting: start treesitter, fetching the parser first if it's missing.
  local lang = vim.treesitter.language.get_lang(ft)
  if lang and not pcall(vim.treesitter.start, buf, lang) then
    local ts = require("nvim-treesitter")
    if vim.list_contains(ts.get_available(), lang) then
      ts.install(lang):await(vim.schedule_wrap(function(err)
        if not err and vim.api.nvim_buf_is_valid(buf) then
          pcall(vim.treesitter.start, buf, lang)
        end
      end))
    end
  end

  -- Language server. Already-installed ones are enabled by mason-lspconfig; a fresh
  -- install is enabled here, which also attaches it to the buffers already open.
  local server = M.tools[ft] and M.tools[ft].lsp
  if server then
    M.mason(server, function(fresh)
      local name = fresh and require("mason-lspconfig").get_mappings().package_to_lspconfig[server]
      if name then
        vim.lsp.enable(name)
      end
    end)
  end
end

function M.setup()
  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("devenv.tooling", {}),
    callback = on_filetype,
  })
end

--- F5: continue the session, or start one, installing the debugger on first use.
function M.debug()
  local dap = require("dap")
  local ft = vim.bo.filetype
  if dap.session() or dap.configurations[ft] then
    return dap.continue()
  end
  local adapter = M.tools[ft] and M.tools[ft].dap
  if not adapter then
    return notify("No debugger known for " .. (ft ~= "" and ft or "this buffer"), vim.log.levels.WARN)
  end
  M.mason(adapter, function()
    require("mason-nvim-dap").setup({ handlers = {} })
    if dap.configurations[ft] then
      dap.continue()
    else
      notify(adapter .. " is installed but has no launch configuration for " .. ft, vim.log.levels.WARN)
    end
  end)
end

return M
