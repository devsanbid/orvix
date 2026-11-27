-- AstroCommunity: import any community modules here
-- We import this file in `lazy_setup.lua` before the `plugins/` folder.
-- This guarantees that the specs are processed before any user plugins.

---@type LazySpec
return {
  "AstroNvim/astrocommunity",
  { import = "astrocommunity.color.transparent-nvim" },
  { import = "astrocommunity.pack.java" },
  { import = "astrocommunity.pack.dart" },
  { import = "astrocommunity.pack.python" },
  { import = "astrocommunity.editing-support.wildfire-nvim" },
  { import = "astrocommunity.terminal-integration.vim-tmux-navigator" },
  {import = "astrocommunity.editing-support.mini-splitjoin"}
}
