-- ---------------------------------------------------------------------------
-- LEGACY NAMES (Lyne -> Orvix)
-- ---------------------------------------------------------------------------
-- Files generated before the Orvix rename still call the old globals
-- (local/settings.lua, local/monitors.lua, local/gpus.lua). Keep them working
-- for one release, then delete this file. New code uses the orvix_* names.
-- ---------------------------------------------------------------------------

lyne_apps = orvix_apps
lyne_specials = orvix_specials
lyne_specials_fallback = orvix_specials_fallback
lyne_workspaces = orvix_workspaces
lyne_workspace_step = orvix_workspace_step
lyne_workspaces_swap = orvix_workspaces_swap
lyne_workspaces_forget = orvix_workspaces_forget
lyne_lid_rules = orvix_lid_rules
lyne_autostart = orvix_autostart
lyne_autostart_import = orvix_autostart_import
lyne_rebind = orvix_rebind
lyne_bind_preset = orvix_bind_preset
lyne_keyboard_import = orvix_keyboard_import
lyne_set_blur_ignore_alpha = orvix_set_blur_ignore_alpha
