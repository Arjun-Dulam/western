local wezterm = require('wezterm')
local umath = require('utils.math')
local Cells = require('utils.cells')
local OptsValidator = require('utils.opts-validator')

---@alias Event.RightStatusOptions { date_format?: string }

---Setup options for the right status bar
local EVENT_OPTS = {}

---@type OptsSchema
EVENT_OPTS.schema = {
   {
      name = 'date_format',
      type = 'string',
      default = '%a %H:%M:%S',
   },
}
EVENT_OPTS.validator = OptsValidator:new(EVENT_OPTS.schema)

local nf = wezterm.nerdfonts
local attr = Cells.attr

local M = {}

local ICON_SEPARATOR = nf.oct_dash
local ICON_DATE = nf.fa_calendar
local GLYPH_SEMI_CIRCLE_LEFT = nf.ple_left_half_circle_thick
local GLYPH_SEMI_CIRCLE_RIGHT = nf.ple_right_half_circle_thick
local GLYPH_KEY_TABLE = nf.md_table_key
local GLYPH_KEY = nf.md_key

---@type string[]
local discharging_icons = {
   nf.md_battery_10,
   nf.md_battery_20,
   nf.md_battery_30,
   nf.md_battery_40,
   nf.md_battery_50,
   nf.md_battery_60,
   nf.md_battery_70,
   nf.md_battery_80,
   nf.md_battery_90,
   nf.md_battery,
}
---@type string[]
local charging_icons = {
   nf.md_battery_charging_10,
   nf.md_battery_charging_20,
   nf.md_battery_charging_30,
   nf.md_battery_charging_40,
   nf.md_battery_charging_50,
   nf.md_battery_charging_60,
   nf.md_battery_charging_70,
   nf.md_battery_charging_80,
   nf.md_battery_charging_90,
   nf.md_battery_charging,
}

---@type table<string, Cells.SegmentColors>
-- stylua: ignore
local colors = {
   date      = { fg = '#fab387', bg = 'rgba(0, 0, 0, 0.4)' },
   battery   = { fg = '#f9e2af', bg = 'rgba(0, 0, 0, 0.4)' },
   separator = { fg = '#74c7ec', bg = 'rgba(0, 0, 0, 0.4)' },
   mode_pill = { bg = '#fab387', fg = '#1c1b19' },
   scircle   = { bg = 'rgba(0, 0, 0, 0.4)', fg = '#fab387' },
   hints     = { bg = 'rgba(0, 0, 0, 0)', fg = '#6c7086' },
}

-- stylua: ignore
local hints = {
   leader      = '  f: resize font   p: resize pane   q: session  ',
   resize_font = '  k: bigger   j: smaller   r: reset   ESC/q: exit  ',
   resize_pane = '  k: up   j: down   h: left   l: right   ESC/q: exit  ',
   session     = '  s: save   r: restore   d: delete   ESC: exit  ',
}

local date_cells = Cells:new()

date_cells
   :add_segment('date_icon', ICON_DATE .. '  ', colors.date, attr(attr.intensity('Bold')))
   :add_segment('date_text', '', colors.date, attr(attr.intensity('Bold')))
   :add_segment('separator', ' ' .. ICON_SEPARATOR .. '  ', colors.separator)
   :add_segment('battery_icon', '', colors.battery)
   :add_segment('battery_text', '', colors.battery, attr(attr.intensity('Bold')))

local mode_cells = Cells:new()

mode_cells
   :add_segment('scircle_l', GLYPH_SEMI_CIRCLE_LEFT, colors.scircle, attr(attr.intensity('Bold')))
   :add_segment('mode_icon', ' ', colors.mode_pill, attr(attr.intensity('Bold')))
   :add_segment('mode_name', ' ', colors.mode_pill, attr(attr.intensity('Bold')))
   :add_segment('scircle_r', GLYPH_SEMI_CIRCLE_RIGHT, colors.scircle, attr(attr.intensity('Bold')))
   :add_segment('hints', '', colors.hints)
   :add_segment('gap', '  ', colors.hints)

---@return string, string
local function battery_info()
   local charge = ''
   local icon = ''

   for _, b in ipairs(wezterm.battery_info()) do
      local idx = umath.clamp(umath.round(b.state_of_charge * 10), 1, 10)
      charge = string.format('%.0f%%', b.state_of_charge * 100)

      if b.state == 'Charging' then
         icon = charging_icons[idx]
      else
         icon = discharging_icons[idx]
      end
   end

   return charge, icon .. ' '
end

---@param opts? Event.RightStatusOptions Default: {date_format = '%a %H:%M:%S'}
M.setup = function(opts)
   local valid_opts, err = EVENT_OPTS.validator:validate(opts or {})

   if err then
      wezterm.log_error(err)
   end

   wezterm.on('update-right-status', function(window, _pane)
      local battery_text, battery_icon = battery_info()

      date_cells
         :update_segment_text('date_text', wezterm.strftime(valid_opts.date_format))
         :update_segment_text('battery_icon', battery_icon)
         :update_segment_text('battery_text', battery_text)

      local date_fmt = date_cells:render({ 'date_icon', 'date_text', 'separator', 'battery_icon', 'battery_text' })

      local name = window:active_key_table()
      local mode_fmt = {}

      if name then
         mode_cells
            :update_segment_text('mode_icon', GLYPH_KEY_TABLE)
            :update_segment_text('mode_name', ' ' .. string.upper(name))
            :update_segment_text('hints', hints[name] or '')
         mode_fmt = mode_cells:render({ 'scircle_l', 'mode_icon', 'mode_name', 'scircle_r', 'hints', 'gap' })
      elseif window:leader_is_active() then
         mode_cells
            :update_segment_text('mode_icon', GLYPH_KEY)
            :update_segment_text('mode_name', ' LEADER')
            :update_segment_text('hints', hints.leader)
         mode_fmt = mode_cells:render({ 'scircle_l', 'mode_icon', 'mode_name', 'scircle_r', 'hints', 'gap' })
      end

      local combined = {}
      for _, item in ipairs(mode_fmt) do table.insert(combined, item) end
      for _, item in ipairs(date_fmt) do table.insert(combined, item) end

      window:set_right_status(wezterm.format(combined))
   end)
end

return M
