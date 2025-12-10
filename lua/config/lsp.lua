local fn = vim.fn
local api = vim.api
local keymap = vim.keymap
local lsp = vim.lsp
local diagnostic = vim.diagnostic

local utils = require("utils")

-- set quickfix list from diagnostics in a certain buffer, not the whole workspace
local set_qflist = function(buf_num, severity)
  local diagnostics = nil
  diagnostics = diagnostic.get(buf_num, { severity = severity })

  local qf_items = diagnostic.toqflist(diagnostics)
  vim.fn.setqflist({}, ' ', { title = 'Diagnostics', items = qf_items })

  -- open quickfix by default
  vim.cmd[[copen]]
end

local custom_attach = function(client, bufnr)
  -- Mappings.
  local map = function(mode, l, r, opts)
    opts = opts or {}
    opts.silent = true
    opts.buffer = bufnr
    keymap.set(mode, l, r, opts)
  end

  map("n", "gd", vim.lsp.buf.definition, { desc = "go to definition" })
  map("n", "gD", vim.lsp.buf.declaration, { desc = "go to declaration" })
  map("n", "<C-]>", vim.lsp.buf.definition)
  map("n", "K", vim.lsp.buf.hover)
  map("n", "<C-k>", vim.lsp.buf.signature_help)
  map("n", "<space>rn", vim.lsp.buf.rename, { desc = "varialbe rename" })
  map("n", "gr", vim.lsp.buf.references, { desc = "show references" })
  map("n", "[d", diagnostic.goto_prev, { desc = "previous diagnostic" })
  map("n", "]d", diagnostic.goto_next, { desc = "next diagnostic" })
  -- this puts diagnostics from opened files to quickfix
  map("n", "<space>qw", diagnostic.setqflist, { desc = "put window diagnostics to qf" })
  -- this puts diagnostics from current buffer to quickfix
  map("n", "<space>qb", function() set_qflist(bufnr) end, { desc = "put buffer diagnostics to qf" })
  map("n", "<space>ca", vim.lsp.buf.code_action, { desc = "LSP code action" })
  map("n", "<space>wa", vim.lsp.buf.add_workspace_folder, { desc = "add workspace folder" })
  map("n", "<space>wr", vim.lsp.buf.remove_workspace_folder, { desc = "remove workspace folder" })
  map("n", "<space>wl", function()
    inspect(vim.lsp.buf.list_workspace_folders())
  end, { desc = "list workspace folder" })

  -- Set some key bindings conditional on server capabilities
  if client.server_capabilities.documentFormattingProvider then
    map("n", "<space>f", vim.lsp.buf.format, { desc = "format code" })
  end

  api.nvim_create_autocmd("CursorHold", {
    buffer = bufnr,
    callback = function()
      local float_opts = {
        focusable = false,
        close_events = { "BufLeave", "CursorMoved", "InsertEnter", "FocusLost" },
        border = "rounded",
        source = "always", -- show source in diagnostic popup window
        prefix = " ",
      }

      if not vim.b.diagnostics_pos then
        vim.b.diagnostics_pos = { nil, nil }
      end

      local cursor_pos = api.nvim_win_get_cursor(0)
      if (cursor_pos[1] ~= vim.b.diagnostics_pos[1] or cursor_pos[2] ~= vim.b.diagnostics_pos[2])
          and #diagnostic.get() > 0
      then
        diagnostic.open_float(nil, float_opts)
      end

      vim.b.diagnostics_pos = cursor_pos
    end,
  })

  -- The blow command will highlight the current variable and its usages in the buffer.
  if client.server_capabilities.documentHighlightProvider then
    vim.cmd([[
      hi! link LspReferenceRead Visual
      hi! link LspReferenceText Visual
      hi! link LspReferenceWrite Visual
    ]])

    local gid = api.nvim_create_augroup("lsp_document_highlight", { clear = true })
    api.nvim_create_autocmd("CursorHold" , {
      group = gid,
      buffer = bufnr,
      callback = function ()
        lsp.buf.document_highlight()
      end
    })

    api.nvim_create_autocmd("CursorMoved" , {
      group = gid,
      buffer = bufnr,
      callback = function ()
        lsp.buf.clear_references()
      end
    })
  end

  if vim.g.logging_level == "debug" then
    local msg = string.format("Language server %s started!", client.name)
    vim.notify(msg, vim.log.levels.DEBUG, { title = "Nvim-config" })
  end
end

local capabilities = require('cmp_nvim_lsp').default_capabilities()
-- required by nvim-ufo
capabilities.textDocument.foldingRange = {
    dynamicRegistration = false,
    lineFoldingOnly = true
}

-- ============================================================================
-- LSP Server Configurations (New API - Neovim 0.11+)
-- ============================================================================

-- Python LSP (pylsp)
if utils.executable("pylsp") then
  local venv_path = os.getenv('VIRTUAL_ENV')
  local py_path = nil
  
  if venv_path ~= nil then
    py_path = venv_path .. "/bin/python3"
  else
    py_path = vim.g.python3_host_prog
  end

  vim.lsp.config.pylsp = {
    cmd = { 'pylsp' },
    filetypes = { 'python' },
    root_markers = { 'pyproject.toml', 'setup.py', 'setup.cfg', '.git' },
    capabilities = capabilities,
    settings = {
      pylsp = {
        plugins = {
          -- formatter options
          black = { enabled = true },
          autopep8 = { enabled = false },
          yapf = { enabled = false },
          -- linter options
          pylint = { enabled = true, executable = "pylint" },
          ruff = { enabled = false },
          pyflakes = { enabled = false },
          pycodestyle = { enabled = false },
          -- type checker
          pylsp_mypy = {
            enabled = false,
            overrides = { "--python-executable", py_path, true },
            report_progress = true,
            live_mode = false
          },
          -- auto-completion options
          jedi_completion = { fuzzy = true },
          -- import sorting
          isort = { enabled = true },
          -- jedi for arcadia
          jedi = { extra_paths = {
              '/Users/h0tmi/arcadia',
              '/Users/h0tmi/arcadia/yt/python',
              '/Users/h0tmi/arcadia/contrib/libs/protobuf/python',
              '/Users/h0tmi/arcadia/contrib/python',
              '/Users/h0tmi/arcadia/saas',
          } },
        },
      },
    },
  }
  
  vim.lsp.enable('pylsp')
else
  vim.notify("pylsp not found!", vim.log.levels.WARN, { title = "Nvim-config" })
end

-- LaTeX LSP (ltex)
if utils.executable("ltex-ls") then
  vim.lsp.config.ltex = {
    cmd = { "ltex-ls" },
    filetypes = { "text", "plaintex", "tex", "markdown" },
    root_markers = { '.git' },
    capabilities = capabilities,
    settings = {
      ltex = {
        language = "en"
      },
    },
  }
  
  vim.lsp.enable('ltex')
else
  vim.notify("ltex-ls not found!", vim.log.levels.WARN, { title = "Nvim-config" })
end

-- Rust LSP (rust-analyzer)
if utils.executable("rust-analyzer") then
  vim.lsp.config.rust_analyzer = {
    cmd = { 'rust-analyzer' },
    filetypes = { 'rust' },
    root_markers = { 'Cargo.toml', 'rust-project.json' },
    capabilities = capabilities,
    settings = {
      ["rust-analyzer"] = {
        lens = {
          enable = true,
        },
        checkOnSave = {
          enable = true,
          command = "clippy",
        },
        diagnostics = {
          enable = true,
        },
        cargo = {
          allFeatures = true,
        },
        inlayHints = {
          parameterHints = {
            enable = true,
          },
          typeHints = {
            enable = true,
          },
        },
      },
    },
  }
  
  vim.lsp.enable('rust_analyzer')
else
  vim.notify("rust-analyzer not found!", vim.log.levels.WARN, { title = "Nvim-config" })
end

-- Go LSP (gopls)
if utils.executable("gopls") then
  vim.lsp.config.gopls = {
    cmd = { 'gopls' },
    filetypes = { "go", "gomod", "gowork", "gotmpl" },
    root_markers = { 'go.work', 'go.mod', '.git' },
    capabilities = capabilities,
    settings = {
      gopls = {
        analyses = {
          unusedparams = true,
        },
        staticcheck = true,
      },
    },
  }
  
  vim.lsp.enable('gopls')
else
  vim.notify("gopls not found!", vim.log.levels.WARN, { title = "Nvim-config" })
end

-- C/C++ LSP (clangd)
if utils.executable("clangd") then
  vim.lsp.config.clangd = {
    cmd = {
      "clangd",
      "--background-index",
      "-j=15",
      "--header-insertion=never",
      "--completion-style=detailed",
    },
    filetypes = { "c", "cpp", "hpp", "objc", "objcpp", "cuda", "proto" },
    root_markers = { 
      '.clangd', 
      '.clang-tidy', 
      '.clang-format', 
      'compile_commands.json', 
      'compile_flags.txt', 
      'configure.ac', 
      '.git' 
    },
    capabilities = capabilities,
  }
  
  vim.lsp.enable('clangd')
else
  vim.notify("clangd not found!", vim.log.levels.WARN, { title = "Nvim-config" })
end

-- Vim LSP (vimls)
if utils.executable("vim-language-server") then
  vim.lsp.config.vimls = {
    cmd = { 'vim-language-server', '--stdio' },
    filetypes = { 'vim' },
    root_markers = { '.git' },
    capabilities = capabilities,
  }
  
  vim.lsp.enable('vimls')
else
  vim.notify("vim-language-server not found!", vim.log.levels.WARN, { title = "Nvim-config" })
end

-- Bash LSP (bashls)
if utils.executable("bash-language-server") then
  vim.lsp.config.bashls = {
    cmd = { 'bash-language-server', 'start' },
    filetypes = { 'sh', 'bash' },
    root_markers = { '.git' },
    capabilities = capabilities,
  }
  
  vim.lsp.enable('bashls')
else
  vim.notify("bash-language-server not found!", vim.log.levels.WARN, { title = "Nvim-config" })
end

-- Lua LSP (lua_ls)
if utils.executable("lua-language-server") then
  vim.lsp.config.lua_ls = {
    cmd = { 'lua-language-server' },
    filetypes = { 'lua' },
    root_markers = { 
      '.luarc.json', 
      '.luarc.jsonc', 
      '.luacheckrc', 
      '.stylua.toml', 
      'stylua.toml', 
      'selene.toml', 
      'selene.yml', 
      '.git' 
    },
    capabilities = capabilities,
    settings = {
      Lua = {
        runtime = {
          -- Tell the language server which version of Lua you're using
          version = "LuaJIT",
        },
        diagnostics = {
          -- Get the language server to recognize the `vim` global
          globals = { "vim" },
        },
        workspace = {
          -- Make the server aware of Neovim runtime files
          library = {
            vim.env.VIMRUNTIME,
            fn.stdpath("config"),
            -- make lua_ls aware of functions under vim.uv
            "${3rd}/luv/library"
          },
          maxPreload = 2000,
          preloadFileSize = 50000,
        },
        telemetry = {
          enable = false,
        },
      },
    },
  }
  
  vim.lsp.enable('lua_ls')
else
  vim.notify("lua-language-server not found!", vim.log.levels.WARN, { title = "Nvim-config" })
end

-- ============================================================================
-- Global LSP Attach Handler
-- ============================================================================

-- Single LspAttach autocmd for all servers
vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    custom_attach(client, args.buf)
  end,
})

-- ============================================================================
-- Diagnostic Configuration
-- ============================================================================

-- Change diagnostic signs
fn.sign_define("DiagnosticSignError", { text = '🆇', texthl = "DiagnosticSignError" })
fn.sign_define("DiagnosticSignWarn", { text = '⚠️', texthl = "DiagnosticSignWarn" })
fn.sign_define("DiagnosticSignInfo", { text = 'ℹ️', texthl = "DiagnosticSignInfo" })
fn.sign_define("DiagnosticSignHint", { text = '', texthl = "DiagnosticSignHint" })

-- Global config for diagnostic
diagnostic.config {
  underline = false,
  virtual_text = true,
  signs = true,
  severity_sort = true,
}

-- Configure diagnostic display
lsp.handlers["textDocument/publishDiagnostics"] = lsp.with(lsp.diagnostic.on_publish_diagnostics, {
  underline = false,
  virtual_text = false,
  signs = true,
  update_in_insert = false,
})

-- Change border of documentation hover window
lsp.handlers["textDocument/hover"] = lsp.with(vim.lsp.handlers.hover, {
  border = "rounded",
})

-- Change border of signature help window
lsp.handlers["textDocument/signatureHelp"] = lsp.with(vim.lsp.handlers.signature_help, {
  border = "rounded",
})
