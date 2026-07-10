local DataStorage  = require("datastorage")
local Dispatcher   = require("dispatcher")
local InfoMessage  = require("ui/widget/infomessage")
local NetworkMgr   = require("ui/network/manager")
local SpinWidget   = require("ui/widget/spinwidget")
local UIManager    = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local lfs          = require("libs/libkoreader-lfs")
local T            = require("ffi/util").template
local _            = require("calendar_l10n")

local Sources = require("calendar_sources")
local Fetch   = require("calendar_fetch")
local ICS     = require("calendar_ics")
local Recur   = require("calendar_recur")
local Store   = require("calendar_store")
local Viewer  = require("calendar_viewer")
local CalendarScreensaver = require("calendar_screensaver")

local Calendar = WidgetContainer:extend{
    name = "calendar",
    is_doc_only = false,
}

-- ---- Settings helpers (view prefs live in G_reader_settings) --------------
local function getMode()      return G_reader_settings:readSetting("calendar_screensaver_mode") or "week" end
local function getMaxAge()    return G_reader_settings:readSetting("calendar_refresh_max_age_h") or 12 end
local function getWeekStart() return G_reader_settings:readSetting("calendar_week_start") or 1 end
-- The viewer remembers its own last mode (saved by the viewer on mode change),
-- independent of the sleep-screen mode.
local function getViewerMode() return G_reader_settings:readSetting("calendar_viewer_mode") or getMode() end

-- Per-calendar enabled/disabled overrides toggled from the menu; they survive
-- config reloads and take precedence over the config file's `enabled` field.
local function getEnabledOverrides()
    return G_reader_settings:readSetting("calendar_enabled_overrides") or {}
end
local function setEnabledOverride(url, enabled)
    local o = getEnabledOverrides()
    o[url] = enabled
    G_reader_settings:saveSetting("calendar_enabled_overrides", o)
end

function Calendar:onDispatcherRegisterActions()
    Dispatcher:registerAction("calendar_open_viewer",
        {category="none", event="CalendarOpenViewer", title=_("Open calendar"), general=true})
    Dispatcher:registerAction("calendar_refresh",
        {category="none", event="CalendarRefresh", title=_("Refresh calendar"), general=true})
end

function Calendar:init()
    self:onDispatcherRegisterActions()
    self.ui.menu:registerToMainMenu(self)
    self:_ensureStore()
    CalendarScreensaver.apply(function()
        return self.store, getMode(), getMaxAge(), getWeekStart()
    end)
end

function Calendar:_ensureStore()
    if self.store then return end
    local cache_dir = DataStorage:getDataDir() .. "/calendar"
    pcall(function() lfs.mkdir(cache_dir) end)
    self.csources = Sources.new()
    self:_applyEnabledOverrides()
    self.cfetch   = Fetch.new(cache_dir)
    self.store    = Store.new{ sources=self.csources, fetch=self.cfetch, ics=ICS, recur=Recur }
end

function Calendar:_applyEnabledOverrides()
    local o = getEnabledOverrides()
    for _, src in ipairs(self.csources:list()) do
        if o[src.url] ~= nil then src.enabled = o[src.url] end
    end
end

function Calendar:_configPath()
    -- self.path is the plugin directory, set by the plugin loader.
    return (self.path or "plugins/calendar.koplugin") .. "/calendar_configuration.lua"
end

function Calendar:_samplePath()
    return (self.path or "plugins/calendar.koplugin") .. "/calendar_configuration.sample.lua"
end

-- ---- Viewer / refresh -----------------------------------------------------
function Calendar:_openViewer()
    self:_ensureStore()
    if self.csources:isMissing() then return self:_showConfigHelp() end
    UIManager:show(Viewer:new{
        store = self.store,
        mode = getViewerMode(),
        week_start = getWeekStart(),
        refresh_max_age_h = getMaxAge(),
    })
end

function Calendar:onCalendarOpenViewer()
    self:_openViewer()
    return true
end

function Calendar:_refresh(force, on_done)
    self:_ensureStore()
    if self.csources:isMissing() then
        self:_showConfigHelp()
        if on_done then on_done(false) end
        return
    end
    NetworkMgr:runWhenOnline(function()
        -- The fetch blocks the UI thread (timeouts up to 30 s); paint a
        -- message first so the user sees the device is working, not frozen.
        local info = InfoMessage:new{ text = _("Refreshing calendars…") }
        UIManager:show(info)
        UIManager:forceRePaint()
        local ok = self.store:refresh(force, getMaxAge())
        UIManager:close(info)
        if on_done then on_done(ok) end
    end)
end

function Calendar:onCalendarRefresh()
    self:_refresh(true, function(ok)
        UIManager:show(InfoMessage:new{
            text = ok and _("Calendar refreshed.") or _("Could not refresh calendar.") })
    end)
    return true
end

-- ---- Configuration handling ----------------------------------------------
function Calendar:_showConfigHelp()
    UIManager:show(InfoMessage:new{
        text = T(_([[No calendar configuration found.

To add your Google Calendar(s):
1. Copy this file:
%1
   to (remove ".sample"):
%2
2. Edit it and paste your calendar's "Secret address in iCal format" URL
   (Google Calendar → Settings → your calendar → Integrate calendar).
   Editing on a computer is easiest.
3. Then use "Reload configuration".

You can also tap "Create configuration file from sample" to create the file now.]]),
            self:_samplePath(), self:_configPath()),
    })
end

function Calendar:_createConfigFromSample()
    if lfs.attributes(self:_configPath(), "mode") then
        UIManager:show(InfoMessage:new{ text = _("Configuration file already exists.") })
        return
    end
    local src = io.open(self:_samplePath(), "rb")
    if not src then
        UIManager:show(InfoMessage:new{ text = _("Sample configuration not found.") })
        return
    end
    local content = src:read("*a"); src:close()
    local dst = io.open(self:_configPath(), "wb")
    if not dst then
        UIManager:show(InfoMessage:new{ text = _("Could not write configuration file.") })
        return
    end
    dst:write(content); dst:close()
    UIManager:show(InfoMessage:new{
        text = T(_("Created:\n%1\n\nEdit it (paste your calendar URL), then Reload configuration."),
            self:_configPath()) })
end

function Calendar:_reloadConfig()
    self:_ensureStore()
    self.csources:reload()
    self:_applyEnabledOverrides()
    if self.csources:isMissing() then
        self:_showConfigHelp()
    else
        local n = #self.csources:list()
        UIManager:show(InfoMessage:new{
            text = T(_("Configuration reloaded. %1 calendar(s) enabled/listed."), n) })
    end
end

function Calendar:_calendarsSubmenu()
    self:_ensureStore()
    local items = {}
    if self.csources:isMissing() then
        items[#items+1] = { text = _("No configuration - tap for help"),
            keep_menu_open = true, callback = function() self:_showConfigHelp() end }
    elseif self.csources:loadError() then
        items[#items+1] = { text = _("Configuration error - tap for details"),
            keep_menu_open = true, callback = function()
                UIManager:show(InfoMessage:new{ text = T(_("Configuration error:\n%1"), self.csources:loadError()) })
            end }
    else
        for _, src in ipairs(self.csources:list()) do
            items[#items+1] = {
                text = src.label,
                checked_func = function() return src.enabled end,
                keep_menu_open = true,
                callback = function()
                    src.enabled = not src.enabled
                    setEnabledOverride(src.url, src.enabled)
                end,
            }
        end
        if #self.csources:list() == 0 then
            items[#items+1] = { text = _("(no calendars in configuration)"),
                enabled_func = function() return false end }
        end
    end
    items[#items+1] = { text = _("Reload configuration"), separator = true,
        keep_menu_open = true, callback = function() self:_reloadConfig() end }
    items[#items+1] = { text = _("Create configuration file from sample"),
        keep_menu_open = true, callback = function() self:_createConfigFromSample() end }
    items[#items+1] = { text = _("Show configuration file path"),
        keep_menu_open = true, callback = function()
            UIManager:show(InfoMessage:new{ text = self:_configPath() })
        end }
    return items
end

-- ---- View preference dialogs ---------------------------------------------
local function getSleepWifi()    return G_reader_settings:isTrue("calendar_sleep_wifi") end
local function getSleepWifiAge() return G_reader_settings:readSetting("calendar_sleep_wifi_max_age_h") or 24 end

function Calendar:_showSleepWifiAge()
    UIManager:show(SpinWidget:new{
        title_text = _("Wi-Fi refresh threshold (hours)"),
        info_text = _("On sleep with Wi-Fi off, turn it on and refresh only when the calendar cache is older than this. Wi-Fi is turned off again afterwards."),
        value = getSleepWifiAge(), value_min = 1, value_max = 168, value_step = 1,
        value_hold_step = 6, default_value = 24,
        callback = function(w) G_reader_settings:saveSetting("calendar_sleep_wifi_max_age_h", w.value) end,
    })
end

function Calendar:_showRefreshInterval()
    UIManager:show(SpinWidget:new{
        title_text = _("Refresh interval (hours)"),
        info_text = _("On sleep, refetch calendars whose cache is older than this."),
        value = getMaxAge(), value_min = 1, value_max = 168, value_step = 1,
        value_hold_step = 6, default_value = 12,
        callback = function(w) G_reader_settings:saveSetting("calendar_refresh_max_age_h", w.value) end,
    })
end

function Calendar:_modeSubmenu()
    local out = {}
    for _, m in ipairs({ "day", "week", "month", "agenda" }) do
        out[#out+1] = {
            text = m,
            checked_func = function() return getMode() == m end,
            radio = true,
            callback = function() G_reader_settings:saveSetting("calendar_screensaver_mode", m) end,
        }
    end
    return out
end

function Calendar:_weekStartSubmenu()
    local out = {}
    local labels = { [1] = _("Monday"), [7] = _("Sunday") }
    for _, ws in ipairs({ 1, 7 }) do
        out[#out+1] = {
            text = labels[ws],
            checked_func = function() return getWeekStart() == ws end,
            radio = true,
            callback = function() G_reader_settings:saveSetting("calendar_week_start", ws) end,
        }
    end
    return out
end

function Calendar:addToMainMenu(menu_items)
    menu_items.calendar = {
        text = _("Calendar"),
        sorting_hint = "tools",
        sub_item_table = {
            { text = _("Open viewer"), callback = function() self:_openViewer() end },
            { text = _("Refresh now"), keep_menu_open = true, callback = function() self:onCalendarRefresh() end },
            { text = _("Calendars"), sub_item_table_func = function() return self:_calendarsSubmenu() end, separator = true },
            {
                text_func = function() return T(_("Sleep-screen mode: %1"), getMode()) end,
                sub_item_table_func = function() return self:_modeSubmenu() end,
            },
            {
                text_func = function()
                    return T(_("Week starts on: %1"), getWeekStart() == 7 and _("Sunday") or _("Monday"))
                end,
                sub_item_table_func = function() return self:_weekStartSubmenu() end,
            },
            { text = _("Refresh interval"), keep_menu_open = true, callback = function() self:_showRefreshInterval() end },
            {
                text = _("Turn on Wi-Fi on sleep if outdated"),
                help_text = _("When entering sleep with Wi-Fi off and a calendar cache older than the threshold below, briefly turn Wi-Fi on to refresh, then turn it off again. Can delay entering sleep and uses some battery."),
                checked_func = getSleepWifi,
                callback = function()
                    G_reader_settings:saveSetting("calendar_sleep_wifi", not getSleepWifi())
                end,
            },
            {
                text_func = function() return T(_("Wi-Fi refresh threshold: %1 h"), getSleepWifiAge()) end,
                enabled_func = getSleepWifi,
                keep_menu_open = true,
                callback = function() self:_showSleepWifiAge() end,
            },
        },
    }
end

return Calendar
