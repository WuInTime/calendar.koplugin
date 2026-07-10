-- calendar_configuration.sample.lua
--
-- HOW TO USE
--   1. Copy this file to `calendar_configuration.lua` (same folder), i.e. remove
--      the ".sample" from the name.
--   2. Edit the `calendars` list below: paste your Google Calendar secret iCal
--      URL(s). Do this on a computer — it is far easier than typing the long URL
--      on the device.
--   3. Copy the edited `calendar_configuration.lua` back onto the device (into
--      koreader/plugins/calendar.koplugin/), then restart KOReader or use
--      Tools → Calendar → "Reload configuration".
--
-- WHERE TO GET THE URL
--   Google Calendar (web) → Settings → click your calendar under
--   "Settings for my calendars" → "Integrate calendar" →
--   "Secret address in iCal format" → copy the URL (ends with /basic.ics).
--   Each calendar has its own secret URL; add one entry per calendar.
--
-- PRIVACY
--   This file contains PRIVATE, unguessable URLs that grant read access to your
--   calendar. `calendar_configuration.lua` is git-ignored so it is never
--   committed. Do not share it.
--
-- NOTE
--   View preferences (sleep-screen mode, refresh interval, week start) are set
--   from the KOReader menus (Tools → Calendar and the sleep-screen Wallpaper
--   settings), NOT in this file — so there is a single place for each setting.

return {
    calendars = {
        {
            label   = "Personal",
            url     = "https://calendar.google.com/calendar/ical/REPLACE_ME/private-REPLACE_ME/basic.ics",
            enabled = true,
        },
        -- Add more calendars by copying the block above, for example:
        -- {
        --     label   = "Work",
        --     url     = "https://calendar.google.com/calendar/ical/xxxx/private-yyyy/basic.ics",
        --     enabled = true,
        -- },
    },
}
