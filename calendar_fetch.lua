-- calendar_fetch.lua — HTTPS GET of ICS URLs plus a disk cache with offline fallback.
-- Network and filesystem-time calls are injectable so the cache logic is testable.
local Fetch = {}
Fetch.__index = Fetch

-- djb2 hash -> 8-hex-char filename token.
function Fetch.hash(url)
    local h = 5381
    for i = 1, #url do
        h = (h * 33 + url:byte(i)) % 4294967296
    end
    return string.format("%08x", h)
end

function Fetch.new(cache_dir)
    local self = setmetatable({}, Fetch)
    self.cache_dir = cache_dir
    self.now_fn = os.time
    -- mtime_fn(path) -> epoch|nil. Default via lfs when available.
    self.mtime_fn = function(path)
        local ok, lfs = pcall(require, "libs/libkoreader-lfs")
        if not ok then ok, lfs = pcall(require, "lfs") end
        if not ok then return nil end
        return lfs.attributes(path, "modification")
    end
    -- request_fn(url) -> content|nil, err|nil. Default performs a real HTTPS GET.
    self.request_fn = function(url)
        local https = require("ssl.https")
        local http = require("socket.http")
        local ltn12 = require("ltn12")
        local socketutil = require("socketutil")
        local urlmod = require("socket.url")
        local sink = {}
        socketutil:set_timeout(10, 30)
        local parsed = urlmod.parse(url)
        local requester = (parsed and parsed.scheme == "http") and http or https
        local ok, code = requester.request{
            url = url, method = "GET", sink = ltn12.sink.table(sink),
            headers = { ["User-Agent"] = "KOReader-CalendarPlugin/1.0",
                        ["Accept"] = "text/calendar, */*" },
        }
        socketutil:reset_timeout()
        if not ok then return nil, tostring(code or "network error") end
        if type(code) == "number" and code ~= 200 then
            return nil, string.format("HTTP %d", code)
        end
        local body = table.concat(sink)
        if not body:find("BEGIN:VCALENDAR", 1, true) then
            return nil, "response is not an iCalendar file"
        end
        return body, nil
    end
    return self
end

function Fetch:cachePathFor(url)
    return self.cache_dir .. "/" .. Fetch.hash(url) .. ".ics"
end

function Fetch:writeCache(url, content)
    local fh = io.open(self:cachePathFor(url), "wb")
    if not fh then return end
    fh:write(content)
    fh:close()
end

function Fetch:readCache(url)
    local fh = io.open(self:cachePathFor(url), "rb")
    if not fh then return nil end
    local content = fh:read("*a")
    fh:close()
    return content
end

function Fetch:cacheMtime(url)
    return self.mtime_fn(self:cachePathFor(url))
end

function Fetch:cacheAgeHours(url)
    local mtime = self.mtime_fn(self:cachePathFor(url))
    if not mtime then return nil end
    return (self.now_fn() - mtime) / 3600
end

function Fetch:fetch(url)
    local content, err = self.request_fn(url)
    if content then
        self:writeCache(url, content)
        return content, nil
    end
    return nil, err
end

function Fetch:fetchOrCache(url)
    local content, err = self:fetch(url)
    if content then return content, false, nil end
    local cached = self:readCache(url)
    if cached then return cached, true, err end
    return nil, false, err
end

return Fetch
