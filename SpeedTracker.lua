--[[
    SpeedTracker v2.2.0
    by morphe#11766
    Lightweight movement speed display. No libs, no bloat.
]]

local ADDON_NAME  = "SpeedTracker"
local BASE_SPEED  = 7.0
local UPDATE_RATE = 0.15
local FRAME_W     = 110
local FRAME_H     = 44
local PCT_EPSILON = 0.5

local DEFAULTS = {
    x         = 200,
    y         = -200,
    locked    = false,
    scale     = 1.0,
    visible   = true,
    showLabel = true,
    colorize  = true,
}

local db

local function ApplyDefaults()
    for k, v in pairs(DEFAULTS) do
        if db[k] == nil then db[k] = v end
    end
end

------------------------------------------------------------------------
-- Speed tracker frame
------------------------------------------------------------------------
local tracker = CreateFrame("Frame", "SpeedTrackerFrame", UIParent, "BackdropTemplate")
tracker:SetSize(FRAME_W, FRAME_H)
tracker:SetFrameStrata("MEDIUM")
tracker:SetClampedToScreen(true)
tracker:SetBackdrop({
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile     = true, tileSize = 16, edgeSize = 12,
    insets   = { left=3, right=3, top=3, bottom=3 },
})
tracker:SetBackdropColor(0, 0, 0, 0.65)
tracker:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.9)

local header = tracker:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
header:SetPoint("TOP", tracker, "TOP", 0, -5)
header:SetTextColor(0.8, 0.8, 0.8, 1)
header:SetText("SPEED")

local speedText = tracker:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
speedText:SetPoint("CENTER", tracker, "CENTER", 0, -2)
speedText:SetTextColor(1, 1, 1, 1)
speedText:SetText("100%")

local lockIcon = tracker:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
lockIcon:SetPoint("BOTTOMRIGHT", tracker, "BOTTOMRIGHT", -3, 3)
lockIcon:SetTextColor(0.5, 0.5, 0.5, 0.7)
lockIcon:SetText("")

local function RefreshHeader()
    if not db then return end
    header:SetShown(db.showLabel)
    speedText:SetPoint("CENTER", tracker, "CENTER", 0, db.showLabel and -2 or 4)
end

tracker:SetMovable(true)
tracker:EnableMouse(true)
tracker:RegisterForDrag("LeftButton")
tracker:SetScript("OnDragStart", function(self)
    if db and not db.locked then self:StartMoving() end
end)
tracker:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    if not db then return end
    local _, _, _, x, y = self:GetPoint()
    db.x, db.y = x, y
end)
tracker:SetScript("OnMouseDown", function(self, button)
    if not db then return end
    if button == "RightButton" then
        db.locked = not db.locked
        lockIcon:SetText(db.locked and "||" or "")
        print("|cff00ff00[SpeedTracker]|r Frame " .. (db.locked and "locked." or "unlocked."))
    end
end)

------------------------------------------------------------------------
-- Speed display — percentage only, pcall protects against combat taint
------------------------------------------------------------------------
local lastKnownPct = 100.0

local function UpdateSpeed()
    if not db then return end
    local current = GetUnitSpeed("player")
    local ok, result = pcall(function() return current / BASE_SPEED * 100 end)
    if ok then lastKnownPct = result end
    local pct = lastKnownPct
    local color = "ffffff"
    if db.colorize then
        if pct > 100 + PCT_EPSILON then
            color = "00ff88"
        elseif pct < 100 - PCT_EPSILON then
            color = "ff6644"
        end
    end
    speedText:SetText(string.format("|cff%s%.0f%%|r", color, pct))
end

local ticker = CreateFrame("Frame")
local elapsed_acc = 0

------------------------------------------------------------------------
-- Options panel
------------------------------------------------------------------------
local optionsCBs = {}

local function MakeCB(parent, label, tip, y, getter, setter)
    local cb = CreateFrame("CheckButton", nil, parent)
    cb:SetSize(24, 24)
    cb:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    cb:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    cb:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
    cb:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, y)
    local text = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    text:SetText(label)
    cb:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(tip, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
    cb:SetScript("OnClick", function(self)
        setter(self:GetChecked() and true or false)
    end)
    cb.Refresh = function(self)
        self:SetChecked(getter() and true or false)
    end
    table.insert(optionsCBs, cb)
    return cb
end

local function MakeHeader(parent, text, y)
    local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, y)
    fs:SetText(text)
    fs:SetTextColor(1, 0.82, 0, 1)
end

local function MakeLine(parent, y)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetSize(540, 1)
    t:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, y)
    t:SetColorTexture(0.25, 0.25, 0.25, 0.8)
end

local function BuildPanel(panel)
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("SpeedTracker")
    title:SetTextColor(1, 0.82, 0, 1)

    local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
    sub:SetText("Lightweight movement speed display  |  v2.2.0  |  morphe#11766")
    sub:SetTextColor(0.55, 0.55, 0.55, 1)

    -- Display
    MakeLine(panel, -56)
    MakeHeader(panel, "Display", -66)
    MakeCB(panel, "Show speed tracker",
        "Toggle the tracker frame on/off.",
        -86,
        function() return db and db.visible end,
        function(v) if db then db.visible = v; tracker:SetShown(v) end end)
    MakeCB(panel, 'Show "SPEED" label',
        "Show/hide the SPEED header text.",
        -108,
        function() return db and db.showLabel end,
        function(v) if db then db.showLabel = v; RefreshHeader() end end)
    MakeCB(panel, "Color-code speed values",
        "Green = above base, white = base, orange = slowed.",
        -130,
        function() return db and db.colorize end,
        function(v) if db then db.colorize = v end end)

    -- Frame
    MakeLine(panel, -160)
    MakeHeader(panel, "Frame", -170)
    MakeCB(panel, "Lock frame position",
        "Prevent dragging. Right-click the tracker to toggle too.",
        -190,
        function() return db and db.locked end,
        function(v)
            if db then
                db.locked = v
                lockIcon:SetText(v and "||" or "")
            end
        end)

    local resetBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetBtn:SetSize(140, 24)
    resetBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -220)
    resetBtn:SetText("Reset Position")
    resetBtn:SetScript("OnClick", function()
        tracker:ClearAllPoints()
        tracker:SetPoint("TOPLEFT", UIParent, "TOPLEFT", DEFAULTS.x, DEFAULTS.y)
        if db then db.x, db.y = DEFAULTS.x, DEFAULTS.y end
        print("|cff00ff00[SpeedTracker]|r Position reset.")
    end)
end

local function RefreshPanel()
    if not db then return end
    for _, cb in ipairs(optionsCBs) do cb:Refresh() end
end

local function RegisterOptions()
    local panel = CreateFrame("Frame", "SpeedTrackerOptionsPanel")
    panel.name  = ADDON_NAME
    BuildPanel(panel)

    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, ADDON_NAME)
        panel:SetScript("OnShow", RefreshPanel)
        Settings.RegisterAddOnCategory(category)
        SpeedTracker_OpenOptions = function()
            Settings.OpenToCategory(ADDON_NAME)
        end
    else
        InterfaceOptions_AddCategory(panel)
        panel:SetScript("OnShow", RefreshPanel)
        SpeedTracker_OpenOptions = function()
            InterfaceOptionsFrame_OpenToCategory(panel)
            InterfaceOptionsFrame_OpenToCategory(panel)
        end
    end
end

------------------------------------------------------------------------
-- Slash commands
------------------------------------------------------------------------
SLASH_SPEEDTRACKER1 = "/speed"
SLASH_SPEEDTRACKER2 = "/speedtracker"

SlashCmdList["SPEEDTRACKER"] = function(msg)
    msg = strtrim(msg or ""):lower()
    if msg == "lock" then
        if db then db.locked = true; lockIcon:SetText("||") end
        print("|cff00ff00[SpeedTracker]|r Frame locked.")
    elseif msg == "unlock" then
        if db then db.locked = false; lockIcon:SetText("") end
        print("|cff00ff00[SpeedTracker]|r Frame unlocked.")
    elseif msg == "toggle" then
        if db then
            db.visible = not tracker:IsShown()
            tracker:SetShown(db.visible)
        end
    elseif msg == "reset" then
        tracker:ClearAllPoints()
        tracker:SetPoint("TOPLEFT", UIParent, "TOPLEFT", DEFAULTS.x, DEFAULTS.y)
        if db then db.x, db.y = DEFAULTS.x, DEFAULTS.y end
        print("|cff00ff00[SpeedTracker]|r Position reset.")
    elseif msg == "options" or msg == "config" or msg == "opt" then
        if SpeedTracker_OpenOptions then SpeedTracker_OpenOptions() end
    else
        print("|cff00ff00[SpeedTracker]|r  /speed options||lock||unlock||toggle||reset")
    end
end

------------------------------------------------------------------------
-- Init
------------------------------------------------------------------------
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGOUT")
initFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        if type(SpeedTrackerDB) ~= "table" then SpeedTrackerDB = {} end
        db = SpeedTrackerDB
        ApplyDefaults()

        tracker:SetScale(db.scale)
        tracker:ClearAllPoints()
        tracker:SetPoint("TOPLEFT", UIParent, "TOPLEFT", db.x, db.y)
        tracker:SetShown(db.visible)
        if db.locked then lockIcon:SetText("||") end
        RefreshHeader()

        RegisterOptions()
        RefreshPanel()

        ticker:SetScript("OnUpdate", function(self, elapsed)
            elapsed_acc = elapsed_acc + elapsed
            if elapsed_acc < UPDATE_RATE then return end
            elapsed_acc = 0
            UpdateSpeed()
        end)

        print("|cff00ff00[SpeedTracker]|r v2.2.0 loaded.  /speed options to configure.")
        self:UnregisterEvent("ADDON_LOADED")

    elseif event == "PLAYER_LOGOUT" then
        if db then db.scale = tracker:GetScale() end
    end
end)
