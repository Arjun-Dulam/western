local wezterm = require('wezterm')
local plugin_dir = wezterm.home_dir .. '/.local/share/wezterm/plugins/resurrect.wezterm/plugin'
package.path = package.path .. ';' .. plugin_dir .. '/?.lua'
local resurrect = dofile(plugin_dir .. '/init.lua')

local M = {}

--- Track user-set session names per window (window_id -> name)
local session_names = {}

M.setup = function() end

M.save_window = function(window, pane)
   local mux_win = window:mux_window()
   local win_id = mux_win:window_id()
   local saved_name = session_names[win_id]
   local description = saved_name
      and 'Update session "' .. saved_name .. '" (enter to keep name):'
      or 'Name this session:'
   window:perform_action(
      wezterm.action.PromptInputLine({
         description = description,
         action = wezterm.action_callback(function(w, _p, name)
            local mw = w:mux_window()
            local wid = mw:window_id()
            if name and #name > 0 then
               session_names[wid] = name
            elseif not session_names[wid] then
               w:toast_notification('wezterm', 'Session name required', nil, 2000)
               return
            end
            mw:set_title(session_names[wid])
            local win_state = resurrect.window_state.get_window_state(mw)
            resurrect.state_manager.save_state(win_state)
            w:toast_notification('wezterm', 'Session "' .. session_names[wid] .. '" saved', nil, 2000)
         end),
      }),
      pane
   )
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
         opts.close_open_tabs = true
         local mux_win = window:mux_window()
         resurrect.window_state.restore_window(mux_win, state, opts)
         if state.title and state.title ~= '' then
            session_names[mux_win:window_id()] = state.title
         end
      elseif state_type == 'tab' then
         local state = resurrect.state_manager.load_state(state_name, 'tab')
         resurrect.tab_state.restore_tab(window:active_tab(), state, opts)
      end
   end)
end

return M
