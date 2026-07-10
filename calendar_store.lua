-- calendar_store.lua — merge parsed+expanded events from all enabled sources. No KOReader deps.
local Store = {}
Store.__index = Store

function Store.new(deps)
    local self = setmetatable({}, Store)
    self.sources = deps.sources
    self.fetch   = deps.fetch
    self.ics     = deps.ics
    self.recur   = deps.recur
    self.last_sync = nil
    self._parsed = {}  -- url -> { mtime=, events= } parse cache
    return self
end

-- Apply RECURRENCE-ID overrides: a VEVENT carrying RECURRENCE-ID replaces that
-- one occurrence of the recurring event sharing its UID. The override is a
-- plain event (emitted as-is); here the master gets the overridden timestamps
-- appended to its EXDATEs so the original occurrence is suppressed.
local function applyRecurrenceOverrides(events)
    local overridden = {}
    for _, ev in ipairs(events) do
        if ev.recurrence_id and ev.uid then
            local list = overridden[ev.uid] or {}
            list[#list + 1] = ev.recurrence_id
            overridden[ev.uid] = list
        end
    end
    for _, ev in ipairs(events) do
        if ev.rrule and overridden[ev.uid] then
            ev.exdates = ev.exdates or {}
            for _, ts in ipairs(overridden[ev.uid]) do
                ev.exdates[#ev.exdates + 1] = ts
            end
        end
    end
    return events
end

-- Parsed events for one source, reusing the previous parse while the cache
-- file's mtime is unchanged (parsing a big ICS on every view change is the
-- slow part on e-ink hardware).
function Store:_parsedEvents(url)
    local mtime = self.fetch.cacheMtime and self.fetch:cacheMtime(url) or nil
    local hit = self._parsed[url]
    if hit and mtime and hit.mtime == mtime then return hit.events end
    local content = self.fetch:readCache(url)
    if not content then return nil end
    local events = applyRecurrenceOverrides(self.ics.parse(content))
    self._parsed[url] = { mtime = mtime, events = events }
    return events
end

-- Pure: flatten, sort by dtstart, de-dupe on (uid .. "@" .. dtstart).
function Store._mergeSorted(lists)
    local seen, out = {}, {}
    for _, list in ipairs(lists) do
        for _, inst in ipairs(list) do
            local key = tostring(inst.uid) .. "@" .. tostring(inst.dtstart)
            if not seen[key] then
                seen[key] = true
                out[#out + 1] = inst
            end
        end
    end
    table.sort(out, function(x, y) return x.dtstart < y.dtstart end)
    return out
end

function Store:refresh(force, max_age_h)
    local any, synced = false, false
    for _, url in ipairs(self.sources:enabledUrls()) do
        local age = self.fetch:cacheAgeHours(url)
        local content
        if force or age == nil or age > (max_age_h or 12) then
            -- fetchOrCache falls back to stale disk cache when the network
            -- request fails; from_cache tells them apart so last_sync only
            -- moves on an actual successful fetch, not a fallback read.
            local from_cache
            content, from_cache = self.fetch:fetchOrCache(url)
            if content and not from_cache then
                synced = true
                self._parsed[url] = nil  -- fresh download; drop stale parse
            end
        else
            content = self.fetch:readCache(url)
        end
        if content then any = true end
    end
    if synced then self.last_sync = os.time() end
    return any, any and nil or "no calendar data available"
end

-- True when any enabled source's cache is missing or older than max_age_h,
-- i.e. refresh() would actually hit the network.
function Store:isStale(max_age_h)
    for _, url in ipairs(self.sources:enabledUrls()) do
        local age = self.fetch:cacheAgeHours(url)
        if age == nil or age > (max_age_h or 12) then return true end
    end
    return false
end

function Store:eventsInWindow(win_start, win_end)
    local lists = {}
    for _, src in ipairs(self.sources:enabledSources()) do
        local events = self:_parsedEvents(src.url)
        if events then
            local expanded = {}
            for _, ev in ipairs(events) do
                for _, inst in ipairs(self.recur.expand(ev, win_start, win_end)) do
                    inst.source = src.label
                    expanded[#expanded + 1] = inst
                end
            end
            lists[#lists + 1] = expanded
        end
    end
    return Store._mergeSorted(lists)
end

function Store:lastSync()
    return self.last_sync
end

return Store
