-- calendar_screensaver.lua — first-class "Calendar" sleep-screen type, applied at
-- runtime from the plugin's init(). Never edits core files. Idempotent.
local logger = require("logger")
local _ = require("calendar_l10n")

local M = { _applied = false }

local TYPE_VALUE = "calendar"
local SK_TYPE    = "screensaver_type"
local SK_MODE    = "calendar_screensaver_mode"
local SK_WIFI     = "calendar_sleep_wifi"           -- opt-in: turn Wi-Fi on at sleep
local SK_WIFI_AGE = "calendar_sleep_wifi_max_age_h" -- ...only when cache older than this
local WIFI_WAIT_S = 30                              -- max wait for a connection
local MODES = { "day", "week", "month", "agenda" }
local MODE_LABEL = { day=_("Day"), week=_("Week"), month=_("Month"), agenda=_("Agenda") }

function M.apply(store_provider)
    if M._applied then return end
    M._applied = true
    M.store_provider = store_provider

    -- 1. Inject the Wallpaper menu radio + mode selector via dofile interception.
    local function injectMenu(tbl)
        if type(tbl) ~= "table" or type(tbl[1]) ~= "table"
           or type(tbl[1].sub_item_table) ~= "table" then return end
        local sub = tbl[1].sub_item_table
        local at = #sub + 1
        for i, item in ipairs(sub) do
            if item.radio and item.separator then at = i; break end
        end
        table.insert(sub, at, {
            text = _("Show calendar on sleep screen"),
            checked_func = function() return G_reader_settings:readSetting(SK_TYPE) == TYPE_VALUE end,
            callback = function() G_reader_settings:saveSetting(SK_TYPE, TYPE_VALUE) end,
            radio = true,
        })
        table.insert(sub, at + 1, {
            text_func = function()
                local m = G_reader_settings:readSetting(SK_MODE) or "week"
                return _("Calendar view mode: ") .. (MODE_LABEL[m] or m)
            end,
            enabled_func = function() return G_reader_settings:readSetting(SK_TYPE) == TYPE_VALUE end,
            keep_menu_open = true,
            sub_item_table_func = function()
                local items = {}
                for _, m in ipairs(MODES) do
                    items[#items+1] = {
                        text = MODE_LABEL[m],
                        checked_func = function() return (G_reader_settings:readSetting(SK_MODE) or "week") == m end,
                        radio = true,
                        callback = function() G_reader_settings:saveSetting(SK_MODE, m) end,
                    }
                end
                return items
            end,
        })
    end

    local _orig_dofile = _G.dofile
    _G.dofile = function(path, ...)
        local result = _orig_dofile(path, ...)
        if type(path) == "string" and path:find("screensaver_menu%.lua$") then
            pcall(injectMenu, result)
        end
        return result
    end

    -- 2. Monkey-patch Screensaver.show for screensaver_type == "calendar".
    local Device          = require("device")
    local Screen          = Device.screen
    local Blitbuffer      = require("ffi/blitbuffer")
    local Geom            = require("ui/geometry")
    local FrameContainer  = require("ui/widget/container/framecontainer")
    local VerticalGroup   = require("ui/widget/verticalgroup")
    local UIManager       = require("ui/uimanager")
    local ScreenSaverWidget = require("ui/widget/screensaverwidget")
    local View            = require("calendar_view")

    local _last_snap = nil

    local function whiteWidget(w, h)
        return FrameContainer:new{ bordersize=0, padding=0,
            dimen=Geom:new{ w=w, h=h }, background=Blitbuffer.COLOR_WHITE, VerticalGroup:new{} }
    end

    -- Opt-in path: radio is off but the cache is older than the user's
    -- threshold — turn Wi-Fi on, wait (bounded) for a connection, refresh,
    -- then restore the radio to its previous state so sleep power draw is
    -- unchanged.
    local function refreshViaWifi(NetworkMgr, store, max_age)
        local was_on = false
        pcall(function() was_on = NetworkMgr:isWifiOn() end)
        local turned = pcall(function() NetworkMgr:turnOnWifi() end)
        if turned then
            local ok_socket, socket = pcall(require, "socket")
            local deadline = os.time() + WIFI_WAIT_S
            while os.time() < deadline do
                if NetworkMgr:isConnected() then
                    pcall(function() store:refresh(false, max_age or 12) end)
                    break
                end
                if not ok_socket then break end
                socket.sleep(1)
            end
        else
            logger.warn("calendar screensaver: could not turn on Wi-Fi")
        end
        if not was_on then pcall(function() NetworkMgr:turnOffWifi() end) end
    end

    local function buildSnapshot(w, h)
        local store, mode, max_age, week_start = M.store_provider()
        if not store then return whiteWidget(w, h) end
        -- Only refetch when already online: a blocking network attempt here
        -- (Wi-Fi radio typically off at sleep) would delay entering sleep by
        -- up to the fetch timeout. Offline, the disk cache is used as-is —
        -- unless the opt-in "turn on Wi-Fi on sleep" setting is enabled and
        -- the cache is older than its threshold.
        local ok_nm, NetworkMgr = pcall(require, "ui/network/manager")
        if ok_nm and NetworkMgr then
            if NetworkMgr:isConnected() then
                pcall(function() store:refresh(false, max_age or 12) end)
            elseif G_reader_settings:isTrue(SK_WIFI)
                   and Device.hasWifiToggle and Device:hasWifiToggle() then
                local wifi_age = G_reader_settings:readSetting(SK_WIFI_AGE) or 24
                local stale = false
                pcall(function() stale = store:isStale(wifi_age) end)
                if stale then refreshViaWifi(NetworkMgr, store, max_age) end
            end
        end
        local win_start, win_end = View.windowFor(mode or "week", os.time(), week_start or 1)
        local events = {}
        pcall(function() events = store:eventsInWindow(win_start, win_end) end)
        local ok, widget = pcall(View.build, mode or "week", os.time(), events, w, h, {
            week_start = week_start or 1, last_sync = store:lastSync(), empty_text = _("No events"),
        })
        if not ok or not widget then return whiteWidget(w, h) end

        local ok_bb, bb = pcall(Blitbuffer.new, w, h, Screen.bb:getType())
        if not ok_bb or not bb then return whiteWidget(w, h) end
        pcall(function() bb:paintRect(0, 0, w, h, Blitbuffer.COLOR_WHITE) end)
        local painted = pcall(function() widget:paintTo(bb, 0, 0) end)
        pcall(function() if widget.free then widget:free() end end)
        if not painted then pcall(function() bb:free() end); return whiteWidget(w, h) end

        local snap = whiteWidget(w, h)
        function snap:paintTo(dst, x, y) if bb then dst:blitFrom(bb, x, y, 0, 0, w, h) end end
        function snap:free() if bb then pcall(function() bb:free() end); bb = nil end end
        return snap
    end

    local function patchShow(Screensaver)
        if Screensaver._calendar_show_patched then return end
        local orig_show = Screensaver.show
        Screensaver._calendar_show_patched = true
        Screensaver.show = function(self)
            if self.screensaver_type ~= TYPE_VALUE then return orig_show(self) end
            Device.screen_saver_mode = true
            local w, h = Screen:getWidth(), Screen:getHeight()
            if Device:hasEinkScreen() then
                Screen:clear(); Screen:refreshFull(0, 0, w, h)
            end
            if _last_snap then pcall(function() if _last_snap.free then _last_snap:free() end end); _last_snap = nil end
            local snap = buildSnapshot(w, h)
            _last_snap = snap
            local ok, sw = pcall(ScreenSaverWidget.new, ScreenSaverWidget, {
                widget = snap, background = Blitbuffer.COLOR_WHITE, covers_fullscreen = true })
            if not ok then
                logger.err("calendar screensaver: widget build failed:", sw)
                Device.screen_saver_mode = false
                return orig_show(self)
            end
            self.screensaver_widget = sw
            sw.modal = true; sw.dithered = true
            local shown = pcall(UIManager.show, UIManager, sw, "full")
            if not shown then Device.screen_saver_mode = false; return orig_show(self) end
        end
    end

    local cached = package.loaded["ui/screensaver"]
    if type(cached) == "table" and cached.show then
        patchShow(cached)
    else
        local _orig_require = _G.require
        _G.require = function(name, ...)
            local res = _orig_require(name, ...)
            if name == "ui/screensaver" and type(res) == "table" and res.show then
                pcall(patchShow, res); _G.require = _orig_require
            end
            return res
        end
    end
end

return M
