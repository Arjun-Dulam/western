local wezterm = require('wezterm')
local plugin_dir = wezterm.home_dir .. '/.local/share/wezterm/plugins/resurrect.wezterm/plugin'
package.path = package.path .. ';' .. plugin_dir .. '/?.lua'
local resurrect = dofile(plugin_dir .. '/init.lua')

local M = {}

M.setup = function() end

M.save_workspace = function(window, pane)
   local ws_state = resurrect.workspace_state.get_workspace_state()
   resurrect.state_manager.save_state(ws_state)
   window:toast_notification('wezterm', 'Workspace saved', nil, 2000)
end

M.fuzzy_delete = function(window, pane)
   resurrect.fuzzy_loader.fuzzy_load(window, pane, function(id, _label, _dir)
      resurrect.state_manager.delete_state(id)
   end, { title = 'Delete Session State', description = 'Select state to delete:', fuzzy_description = 'Delete: ' })
end

M.fuzzy_restore = function(window, pane)
   resurrect.fuzzy_loader.fuzzy_load(window, pane, function(id, _label, _dir)
      local state_type = string.match(id, '^([^/]+)')
      local state_name = string.match(id, '([^/]+)$')
      state_name = string.match(state_name, '(.+)%..+$')

      local opts = {
         relative = true,
         restore_text = true,
         on_pane_restore = resurrect.tab_state.default_on_pane_restore,
      }

      if state_type == 'workspace' then
         local state = resurrect.state_manager.load_state(state_name, 'workspace')
         resurrect.workspace_state.restore_workspace(state, opts)
      elseif state_type == 'window' then
         local state = resurrect.state_manager.load_state(state_name, 'window')
         resurrect.window_state.restore_window(window:mux_window(), state, opts)
      elseif state_type == 'tab' then
         local state = resurrect.state_manager.load_state(state_name, 'tab')
         resurrect.tab_state.restore_tab(window:active_tab(), state, opts)
      end
   end)
end

return M
