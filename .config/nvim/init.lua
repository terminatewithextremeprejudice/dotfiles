-- Disable matchit.vim and matchparen right at the start to prevent loading
vim.g.loaded_matchit = 1
vim.g.loaded_matchparen = 1

-- Set notification level to show only important messages
vim.notify_level = vim.log.levels.INFO

vim.python3_host_prog = '/usr/bin/python'

-- Utility function for error handling
local function with_error_handling(func, msg)
  local ok, err = pcall(func)
  if not ok then
    vim.notify("Error in " .. msg .. ": " .. tostring(err), vim.log.levels.ERROR)
    return false
  end
  return true
end

-- Clean up any tree-sitter tmp directories that might cause conflicts
local function cleanup_tmp_dirs()
  return with_error_handling(function()
    local tmp_dirs = vim.fn.glob(vim.fn.expand("~") .. "/tree-sitter-*-tmp", true, true)
    for _, dir in ipairs(tmp_dirs) do
      vim.fn.delete(dir, "rf")
    end
  end, "cleanup of temporary tree-sitter directories")
end

-- Suppress specific error messages that are known and harmless
local original_notify = vim.notify
vim.notify = function(msg, level, opts)
  -- Suppress stylua LSP errors (NixOS compatibility issue)
  if msg and type(msg) == "string" and
     (msg:match("Client stylua quit with exit code") or
      msg:match("stylua.*stderr") or
      msg:match("Could not start dynamically linked executable: stylua")) then
    return
  end

  -- Suppress lspconfig deprecation warning (we're handling the migration)
  if msg and type(msg) == "string" and
     (msg:match("framework.*deprecated") or
      msg:match("vim.lsp.config")) then
    return
  end

  -- Suppress firenvim and wezterm-integration plugin load errors (intentionally removed/deprecated)
  if msg and type(msg) == "string" and
     (msg:match("Failed to load plugin module:.*firenvim") or
      msg:match("Failed to load plugin module:.*wezterm%-integration")) then
    return
  end

  return original_notify(msg, level, opts)
end

-- Set leader key BEFORE loading lazy or any other plugins
-- This is critical and must happen first
vim.g.mapleader = " " -- Space as leader key
vim.g.maplocalleader = "," -- Comma as local leader for filetype-specific mappings (e.g., Lean)

-- Use the Nix-installed MCP-Hub binary if available
local mcp_hub_path = os.getenv("MCP_HUB_PATH")
if mcp_hub_path then
  vim.g.mcp_hub_path = mcp_hub_path
end

-- Load configuration with improved error handling
local config_ok, config = pcall(require, "neotex.config")
local bootstrap_ok, bootstrap = pcall(require, "neotex.bootstrap")

-- Make sure bootstrap exists before trying to use it
if bootstrap_ok and type(bootstrap) == "table" and type(bootstrap.init) == "function" then
  bootstrap.init()
end

-- Global function to ensure MCPHub is loaded and available
_G.ensure_mcphub_loaded = function()
  -- First trigger the event to lazy-load MCPHub
  vim.api.nvim_exec_autocmds("User", { pattern = "AvantePreLoad" })
  
  -- Check if the MCPHub command exists
  if vim.fn.exists(":MCPHub") == 0 then
    -- MCPHub command doesn't exist yet, try to load it directly
    
    -- First, check if Lazy has the plugin loaded
    local stats = require("lazy").stats()
    if not stats.loaded["mcphub.nvim"] then
      -- Try to explicitly load the plugin via Lazy
      pcall(function() vim.cmd("Lazy load mcphub.nvim") end)
      
      -- Wait a bit for the load to complete
      vim.defer_fn(function()
        -- Check again if the command exists
        if vim.fn.exists(":MCPHub") == 0 then
          -- Still doesn't exist, try to register it manually
          vim.api.nvim_create_user_command("MCPHub", function()
            -- Ensure the module is loaded when the command is called
            local ensure_mcphub = require("neotex.util.ensure_mcphub")
            
            -- Start the server directly using our helper function
            ensure_mcphub.start_mcphub_server()
          end, {})
          
          vim.notify("Manually registered MCPHub command", vim.log.levels.INFO)
        end
      end, 100)
    end
  end
  
  return true
end

-- Track MCPHub server state to prevent multiple startups
_G.mcphub_server_started = false

-- Create command for loading MCPHub
vim.api.nvim_create_user_command("MCPHubLoad", function()
  -- Ensure the module is loaded first
  local ensure_mcphub = require("neotex.util.ensure_mcphub")
  
  -- Load the plugin
  _G.ensure_mcphub_loaded()
  
  -- Start the server directly using our helper function
  ensure_mcphub.start_mcphub_server()
end, { desc = "Force load MCPHub plugin and start server" })


-- If bootstrap fails, set up minimal fallback
if not bootstrap_ok then
  vim.notify("Error loading bootstrap: " .. tostring(bootstrap) .. ". Using minimal fallback.", vim.log.levels.WARN)
  -- Ensure minimal plugin management functionality
  local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
  if vim.loop.fs_stat(lazypath) then
    vim.opt.rtp:prepend(lazypath)
    pcall(require, "lazy")
  end
end

