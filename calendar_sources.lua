-- calendar_sources.lua — load the list of ICS sources from the user's config
-- file (calendar_configuration.lua), copied and edited from the shipped
-- .sample. No KOReader deps beyond `require` of the config module.
--
-- The config module returns a table: { calendars = { {label=, url=, enabled=}, ... } }.
local Sources = {}
Sources.__index = Sources

local CONFIG_MODULE = "calendar_configuration"

-- Injectable loader so this module can be exercised without a real config file.
-- loader() -> ok:boolean, config_or_err
local function default_loader()
    return pcall(require, CONFIG_MODULE)
end

function Sources.new(loader)
    local self = setmetatable({}, Sources)
    self.loader = loader or default_loader
    self:reload()
    return self
end

local function deriveLabel(url, i)
    if type(url) ~= "string" then return "Calendar " .. i end
    local host = url:match("^https?://([^/]+)")
    return host or ("Calendar " .. i)
end

-- (Re)read the config file into a normalized list.
function Sources:reload()
    self.items = {}
    self.missing = true
    self.error = nil
    local ok, result = self.loader()
    if not ok then
        -- pcall(require) failed: file absent or has a syntax error.
        self.error = tostring(result)
        return
    end
    if type(result) ~= "table" then
        self.error = "configuration did not return a table"
        return
    end
    self.missing = false
    local cals = result.calendars
    if type(cals) ~= "table" then return end
    for i, c in ipairs(cals) do
        if type(c) == "table" and type(c.url) == "string" and c.url ~= ""
           and not c.url:find("REPLACE_ME", 1, true) then
            self.items[#self.items + 1] = {
                url = c.url,
                label = (type(c.label) == "string" and c.label ~= "") and c.label or deriveLabel(c.url, i),
                enabled = (c.enabled ~= false),  -- default true
            }
        end
    end
end

-- True when calendar_configuration.lua could not be loaded at all.
function Sources:isMissing()
    return self.missing
end

-- Load error string (syntax error / non-table), or nil.
function Sources:loadError()
    return self.error
end

function Sources:list()
    return self.items
end

-- Flip a calendar on/off in the loaded list (persistence is the caller's job;
-- reload() rebuilds from the config file, after which overrides re-apply).
function Sources:setEnabled(url, enabled)
    for _, it in ipairs(self.items) do
        if it.url == url then it.enabled = enabled and true or false end
    end
end

-- Enabled source entries ({url=, label=, enabled=}), not just their URLs.
function Sources:enabledSources()
    local out = {}
    for _, it in ipairs(self.items) do
        if it.enabled then out[#out + 1] = it end
    end
    return out
end

function Sources:enabledUrls()
    local urls = {}
    for _, it in ipairs(self.items) do
        if it.enabled then urls[#urls + 1] = it.url end
    end
    return urls
end

return Sources
