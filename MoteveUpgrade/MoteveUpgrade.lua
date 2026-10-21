-- Moteve Upgrade
-- Scores equippable items with per-class stat weights, compares them with what you wear,
-- and marks upgrades in your bags (glow frame) and in item tooltips.

local ADDON_NAME, ns = ...

local format, floor, max, min, abs = string.format, math.floor, math.max, math.min, math.abs

local DEFAULTS = { threshold = 1, glow = true, badge = true, tooltip = true, weights = {} }

local db, char
local playerClass

---------------------------------------------------------------------------
-- Theme
---------------------------------------------------------------------------
local WHITE   = "Interface\\Buttons\\WHITE8X8"
local ACCENT1 = { 0.20, 0.88, 0.76 }   -- teal
local ACCENT2 = { 0.56, 0.42, 1.00 }   -- violet
local TEAL_HEX, MUTED_HEX, SUB_HEX = "|cff33e0c2", "|cff808796", "|cffb3bac9"

local function Print(msg) print(TEAL_HEX .. "Moteve Upgrade|r: " .. msg) end

---------------------------------------------------------------------------
-- Item API wrappers (modern client first, older globals as fallback)
---------------------------------------------------------------------------
local GetItemInfo         = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local GetItemInfoInstant  = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
local GetItemStatsAPI     = (C_Item and C_Item.GetItemStats) or GetItemStats
local IsEquippableItem    = (C_Item and C_Item.IsEquippableItem) or IsEquippableItem
local GetContainerNumSlots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
local GetContainerItemLink = (C_Container and C_Container.GetContainerItemLink) or GetContainerItemLink

local function RequestItem(link)
    if C_Item and C_Item.RequestLoadItemDataByID then
        local id = GetItemInfoInstant(link)
        if id then C_Item.RequestLoadItemDataByID(id) end
    end
end

---------------------------------------------------------------------------
-- Tooltip lines (for usability = red text, and for "Equip:" stat parsing)
---------------------------------------------------------------------------
local scanTip
local function ScanLines(link)
    if C_TooltipInfo and C_TooltipInfo.GetHyperlink then
        local ok, data = pcall(C_TooltipInfo.GetHyperlink, link)
        if ok and data and data.lines then return data.lines end
    end
    -- fallback: hidden scanning tooltip
    if not scanTip then
        scanTip = CreateFrame("GameTooltip", "MoteveUpgradeScanTip", nil, "GameTooltipTemplate")
    end
    scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
    scanTip:ClearLines()
    scanTip:SetHyperlink(link)
    local lines = {}
    for i = 1, scanTip:NumLines() do
        local L, R = _G["MoteveUpgradeScanTipTextLeft" .. i], _G["MoteveUpgradeScanTipTextRight" .. i]
        local line = {}
        if L then
            line.leftText = L:GetText()
            local r, g, b = L:GetTextColor(); line.leftColor = { r = r, g = g, b = b }
        end
        if R and R:IsShown() then
            line.rightText = R:GetText()
            local r, g, b = R:GetTextColor(); line.rightColor = { r = r, g = g, b = b }
        end
        lines[#lines + 1] = line
    end
    scanTip:Hide()
    return lines
end

local function IsRed(c)
    return c and c.r and c.r > 0.95 and c.g < 0.2 and c.b < 0.2
end

-- red tooltip text = the game says you cannot use it (class, armor/weapon skill, level)
local function CanUse(lines)
    if not lines then return true end
    for i = 2, #lines do
        local l = lines[i]
        if (l.leftText and IsRed(l.leftColor)) or (l.rightText and IsRed(l.rightColor)) then
            return false
        end
    end
    return true
end

---------------------------------------------------------------------------
-- Stats
---------------------------------------------------------------------------
local STAT_KEYS = {
    ITEM_MOD_STRENGTH_SHORT = "str", ITEM_MOD_AGILITY_SHORT = "agi", ITEM_MOD_STAMINA_SHORT = "sta",
    ITEM_MOD_INTELLECT_SHORT = "int", ITEM_MOD_SPIRIT_SHORT = "spi",
    RESISTANCE0_NAME = "armor",
    ITEM_MOD_ATTACK_POWER_SHORT = "ap", ITEM_MOD_RANGED_ATTACK_POWER_SHORT = "rap",
    ITEM_MOD_FERAL_ATTACK_POWER_SHORT = "feralap",
    ITEM_MOD_SPELL_POWER_SHORT = "sp", ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = "sp",
    ITEM_MOD_SPELL_HEALING_DONE_SHORT = "heal",
    ITEM_MOD_HASTE_RATING_SHORT = "haste",
    ITEM_MOD_MANA_REGENERATION_SHORT = "mp5", ITEM_MOD_POWER_REGEN0_SHORT = "mp5",
    ITEM_MOD_HEALTH_REGENERATION_SHORT = "hp5", ITEM_MOD_HEALTH_REGEN_SHORT = "hp5",
    ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = "def", ITEM_MOD_DODGE_RATING_SHORT = "dodge",
    ITEM_MOD_PARRY_RATING_SHORT = "parry", ITEM_MOD_BLOCK_RATING_SHORT = "block",
    ITEM_MOD_BLOCK_VALUE_SHORT = "blockvalue",
    ITEM_MOD_DAMAGE_PER_SECOND_SHORT = "dps",
}
-- hit / crit exist as several keys on older data; WoW Forever merges them into one stat each,
-- so the highest value is taken instead of summing duplicates.
local MAX_KEYS = {
    ITEM_MOD_HIT_RATING_SHORT = "hit", ITEM_MOD_HIT_SPELL_RATING_SHORT = "hit",
    ITEM_MOD_HIT_MELEE_RATING_SHORT = "hit", ITEM_MOD_HIT_RANGED_RATING_SHORT = "hit",
    ITEM_MOD_CRIT_RATING_SHORT = "crit", ITEM_MOD_CRIT_SPELL_RATING_SHORT = "crit",
    ITEM_MOD_CRIT_MELEE_RATING_SHORT = "crit", ITEM_MOD_CRIT_RANGED_RATING_SHORT = "crit",
}

-- English "Equip:" lines, used only for stats the stat API did not return
local EQUIP_PATTERNS = {
    { "hit",        "chance to hit.- by (%d+)%%" },
    { "crit",       "critical strike.- by (%d+)%%" },
    { "sp",         "damage and healing done by magical spells and effects by up to (%d+)" },
    { "sp",         "increases spell power by (%d+)" },
    { "heal",       "healing done by spells and effects by up to (%d+)" },
    { "rap",        "%+(%d+) ranged attack power" },
    { "ap",         "%+(%d+) attack power" },
    { "mp5",        "(%d+) mana per 5 sec" },
    { "hp5",        "(%d+) health per 5 sec" },
    { "def",        "increased defense %+(%d+)" },
    { "dodge",      "chance to dodge an attack by (%d+)%%" },
    { "parry",      "chance to parry an attack by (%d+)%%" },
    { "block",      "chance to block attacks with a shield by (%d+)%%" },
    { "blockvalue", "block value of your shield by (%d+)" },
}

local RANGED_LOC = { INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true, INVTYPE_THROWN = true }

local statCache = {}

-- returns a stat table, or nil if the item is not loaded yet
local function ItemStats(link)
    local cached = statCache[link]
    if cached then return cached end

    -- Item data arrives asynchronously. Until both the item info and its stats are loaded the
    -- item is "not ready" (nil), and nothing is cached, so it is scored again once the data is in.
    -- (Caching an empty result here used to leave freshly looted items without a glow until /reload.)
    if not GetItemInfo(link) then RequestItem(link); return nil end
    local raw = GetItemStatsAPI and GetItemStatsAPI(link)
    local complete = raw ~= nil
    raw = raw or {}

    local s = {}
    for k, v in pairs(raw) do
        local key = STAT_KEYS[k]
        if key then
            s[key] = (s[key] or 0) + v
        else
            key = MAX_KEYS[k]
            if key then s[key] = max(s[key] or 0, v) end
        end
    end

    -- fill gaps from the tooltip text
    local lines = ScanLines(link)
    for i = 2, #lines do
        local text = lines[i].leftText
        if text then
            local lower = text:lower()
            if lower:find("^equip:") then
                for _, p in ipairs(EQUIP_PATTERNS) do
                    if not s[p[1]] then
                        local n = lower:match(p[2])
                        if n then s[p[1]] = tonumber(n); break end
                    end
                end
            else
                if not s.dps then
                    local d = lower:match("%(([%d%.]+) damage per second%)")
                    if d then s.dps = tonumber(d) end
                end
                if not s.armor then
                    local a = lower:match("^(%d+) armor$")
                    if a then s.armor = tonumber(a) end
                end
            end
        end
    end

    local _, _, _, equipLoc = GetItemInfoInstant(link)
    if s.dps and RANGED_LOC[equipLoc] then
        s.rangedDps, s.dps = s.dps, nil
    end

    if complete and #lines > 0 then statCache[link] = s end
    return s
end

---------------------------------------------------------------------------
-- Profiles & scoring
---------------------------------------------------------------------------
local function Profiles() return ns.PROFILES[playerClass] or ns.PROFILES.WARRIOR end

local function CurrentProfile()
    local list = Profiles()
    return list[char.profile] or list[1]
end

local function Weights()
    local p = CurrentProfile()
    local over = db.weights[playerClass] and db.weights[playerClass][p.key]
    if not over then return p.w end
    local w = {}
    for k, v in pairs(p.w) do w[k] = v end
    for k, v in pairs(over) do w[k] = v end
    return w
end

local function Score(link)
    if not link then return 0 end
    local s = ItemStats(link)
    if not s then return nil end
    local w, total = Weights(), 0
    for k, v in pairs(s) do
        total = total + (w[k] or 0) * v
    end
    return total
end

---------------------------------------------------------------------------
-- Comparison with equipped gear
---------------------------------------------------------------------------
local SLOTS = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 },
    INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 },
    INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 },
    INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 },
    INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_2HWEAPON = { 16 },
    INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_SHIELD = { 17 }, INVTYPE_HOLDABLE = { 17 },
    INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 }, INVTYPE_RELIC = { 18 },
    INVTYPE_WEAPON = { 16, 17 },
}

local function EquipLocOf(link)
    if not link then return nil end
    local _, _, _, loc = GetItemInfoInstant(link)
    return loc
end

local function ArmorOf(link)
    if not link then return 0 end
    local st = ItemStats(link)
    if not st then return nil end   -- not loaded yet
    return st.armor or 0
end

-- returns: result table or nil (not comparable / not loaded)
--   { pct, upgrade, empty, armorOnly, replaces, newScore, oldScore }
-- Rules:
--   * empty slot: anything you can wear there is an upgrade ("NEW")
--   * otherwise the weighted stat score decides
--   * when the stat scores are equal (typical at low level: items with armor only), more armor wins
local function Compare(link)
    if not link or not IsEquippableItem(link) then return nil end
    local loc = EquipLocOf(link)
    local slots = loc and SLOTS[loc]
    if not slots then return nil end

    local newScore = Score(link)
    local newArmor = ArmorOf(link)
    if newScore == nil or newArmor == nil then return nil end

    local mhLink = GetInventoryItemLink("player", 16)
    local mhIs2H = EquipLocOf(mhLink) == "INVTYPE_2HWEAPON"

    local oldScore, oldArmor, replaces, empty
    if loc == "INVTYPE_2HWEAPON" then
        -- a two-hander replaces main hand + off hand together
        local oh = GetInventoryItemLink("player", 17)
        local a, b = Score(mhLink), Score(oh)
        local aa, ba = ArmorOf(mhLink), ArmorOf(oh)
        if a == nil or b == nil or aa == nil or ba == nil then return nil end
        oldScore, oldArmor, replaces = a + b, aa + ba, mhLink
        empty = (mhLink == nil and oh == nil)
    elseif (slots[1] == 17 or loc == "INVTYPE_WEAPON" or loc == "INVTYPE_WEAPONMAINHAND") and mhIs2H then
        return nil -- one-hand vs two-hand is not a fair item-vs-item comparison
    else
        local candidates = slots
        if loc == "INVTYPE_WEAPON" then
            local ohLoc = EquipLocOf(GetInventoryItemLink("player", 17))
            local dualWield = ohLoc == "INVTYPE_WEAPON" or ohLoc == "INVTYPE_WEAPONOFFHAND"
            if not dualWield then candidates = { 16 } end
        end
        -- compare against the weakest item in the candidate slots (rings, trinkets, dual wield);
        -- an empty candidate slot wins straight away
        for _, slot in ipairs(candidates) do
            local eq = GetInventoryItemLink("player", slot)
            if eq == link then return nil end -- this exact item is equipped
            if not eq then
                oldScore, oldArmor, replaces, empty = 0, 0, nil, true
                break
            end
            local sc, ar = Score(eq), ArmorOf(eq)
            if sc == nil or ar == nil then return nil end
            if oldScore == nil or sc < oldScore or (sc == oldScore and ar < oldArmor) then
                oldScore, oldArmor, replaces = sc, ar, eq
            end
        end
    end

    local r = { newScore = newScore, oldScore = oldScore, replaces = replaces }
    if empty then
        r.empty, r.pct, r.upgrade = true, 100, true
        return r
    end
    local diff = newScore - oldScore
    if abs(diff) < 0.001 then
        -- same stat value: armor decides
        if newArmor > oldArmor then
            r.armorOnly = true
            r.pct = oldArmor > 0 and (newArmor - oldArmor) / oldArmor * 100 or 100
            r.upgrade = r.pct >= db.threshold
        else
            r.pct = 0
            r.upgrade = false
        end
        return r
    end
    r.pct = oldScore > 0 and diff / oldScore * 100 or (diff > 0 and 100 or -100)
    r.upgrade = diff > 0 and r.pct >= db.threshold
    return r
end

-- full check for a bag item: comparable, usable by you, and better
local function BagUpgrade(link)
    local r = Compare(link)
    if not r or not r.upgrade then return nil end
    if not CanUse(ScanLines(link)) then return nil end
    return r
end

---------------------------------------------------------------------------
-- Glow overlay on bag buttons
---------------------------------------------------------------------------
local function CreateGlow(button)
    local g = CreateFrame("Frame", nil, button)
    g:SetAllPoints()
    g:SetFrameLevel(button:GetFrameLevel() + 6)
    g:Hide()

    local function Solid(parent, layer, sub, c, a)
        local t = parent:CreateTexture(nil, layer, nil, sub)
        t:SetTexture(WHITE)
        t:SetVertexColor(c[1], c[2], c[3], a or 1)
        return t
    end
    local function Fade(parent, sub, orient, alphaMin, alphaMax)
        local t = parent:CreateTexture(nil, "OVERLAY", nil, sub)
        t:SetTexture(WHITE)
        t:SetGradient(orient,
            CreateColor(ACCENT1[1], ACCENT1[2], ACCENT1[3], alphaMin),
            CreateColor(ACCENT1[1], ACCENT1[2], ACCENT1[3], alphaMax))
        return t
    end

    -- pulsing layer: outer halo + inner glow + light tint
    local pulse = CreateFrame("Frame", nil, g)
    pulse:SetAllPoints()
    local HALO, INNER = 6, 13

    local top = Fade(pulse, 1, "VERTICAL", 0.75, 0)      -- above the slot, strong at the edge
    top:SetPoint("BOTTOMLEFT", g, "TOPLEFT", 0, 0); top:SetPoint("BOTTOMRIGHT", g, "TOPRIGHT", 0, 0); top:SetHeight(HALO)
    local bot = Fade(pulse, 1, "VERTICAL", 0, 0.75)
    bot:SetPoint("TOPLEFT", g, "BOTTOMLEFT", 0, 0); bot:SetPoint("TOPRIGHT", g, "BOTTOMRIGHT", 0, 0); bot:SetHeight(HALO)
    local lft = Fade(pulse, 1, "HORIZONTAL", 0, 0.75)
    lft:SetPoint("TOPRIGHT", g, "TOPLEFT", 0, 0); lft:SetPoint("BOTTOMRIGHT", g, "BOTTOMLEFT", 0, 0); lft:SetWidth(HALO)
    local rgt = Fade(pulse, 1, "HORIZONTAL", 0.75, 0)
    rgt:SetPoint("TOPLEFT", g, "TOPRIGHT", 0, 0); rgt:SetPoint("BOTTOMLEFT", g, "BOTTOMRIGHT", 0, 0); rgt:SetWidth(HALO)

    local itop = Fade(pulse, 1, "VERTICAL", 0, 0.6)
    itop:SetPoint("TOPLEFT"); itop:SetPoint("TOPRIGHT"); itop:SetHeight(INNER)
    local ibot = Fade(pulse, 1, "VERTICAL", 0.6, 0)
    ibot:SetPoint("BOTTOMLEFT"); ibot:SetPoint("BOTTOMRIGHT"); ibot:SetHeight(INNER)
    local ilft = Fade(pulse, 1, "HORIZONTAL", 0.6, 0)
    ilft:SetPoint("TOPLEFT"); ilft:SetPoint("BOTTOMLEFT"); ilft:SetWidth(INNER)
    local irgt = Fade(pulse, 1, "HORIZONTAL", 0, 0.6)
    irgt:SetPoint("TOPRIGHT"); irgt:SetPoint("BOTTOMRIGHT"); irgt:SetWidth(INNER)

    local tint = Solid(pulse, "OVERLAY", 0, ACCENT1, 0.12)
    tint:SetAllPoints()

    local ag = pulse:CreateAnimationGroup()
    ag:SetLooping("BOUNCE")
    local a = ag:CreateAnimation("Alpha")
    a:SetFromAlpha(1); a:SetToAlpha(0.35); a:SetDuration(0.8)
    g.anim = ag

    -- solid 2px border, always fully visible
    local B = 2
    local e1 = Solid(g, "OVERLAY", 3, ACCENT1); e1:SetPoint("TOPLEFT"); e1:SetPoint("TOPRIGHT"); e1:SetHeight(B)
    local e2 = Solid(g, "OVERLAY", 3, ACCENT1); e2:SetPoint("BOTTOMLEFT"); e2:SetPoint("BOTTOMRIGHT"); e2:SetHeight(B)
    local e3 = Solid(g, "OVERLAY", 3, ACCENT1); e3:SetPoint("TOPLEFT"); e3:SetPoint("BOTTOMLEFT"); e3:SetWidth(B)
    local e4 = Solid(g, "OVERLAY", 3, ACCENT1); e4:SetPoint("TOPRIGHT"); e4:SetPoint("BOTTOMRIGHT"); e4:SetWidth(B)

    -- badge in the top-left corner: up chevron + percentage
    local badge = CreateFrame("Frame", nil, g)
    badge:SetFrameLevel(g:GetFrameLevel() + 2)
    badge:SetHeight(12)
    badge:SetPoint("TOPLEFT", 1, -1)
    local bbg = badge:CreateTexture(nil, "BACKGROUND")
    bbg:SetTexture(WHITE); bbg:SetAllPoints()
    bbg:SetGradient("HORIZONTAL", CreateColor(0.03, 0.16, 0.14, 0.95), CreateColor(0.10, 0.07, 0.20, 0.95))
    local bline = Solid(badge, "BORDER", 0, ACCENT1); bline:SetPoint("BOTTOMLEFT"); bline:SetPoint("BOTTOMRIGHT"); bline:SetHeight(1)

    local c1 = Solid(badge, "OVERLAY", 0, ACCENT1); c1:SetSize(5, 1.5); c1:SetPoint("LEFT", 2, 0); c1:SetRotation(math.pi / 4)
    local c2 = Solid(badge, "OVERLAY", 0, ACCENT1); c2:SetSize(5, 1.5); c2:SetPoint("LEFT", 5.2, 0); c2:SetRotation(-math.pi / 4)

    local txt = badge:CreateFontString(nil, "OVERLAY")
    txt:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    txt:SetTextColor(ACCENT1[1], ACCENT1[2], ACCENT1[3])
    txt:SetPoint("LEFT", 11, 0)
    g.badge, g.badgeText = badge, txt

    button.MoteveGlow = g
    return g
end

local function SetGlow(button, result)
    local g = button.MoteveGlow
    if not result then
        if g then g.anim:Stop(); g:Hide() end
        return
    end
    g = g or CreateGlow(button)
    if db.badge then
        local pct = result.pct or 0
        if result.empty then g.badgeText:SetText("ÚJ")
        elseif result.armorOnly then g.badgeText:SetText(format("+%d%% ARM", min(999, floor(pct + 0.5))))
        else g.badgeText:SetText(format("+%d%%", min(999, floor(pct + 0.5)))) end
        g.badge:SetWidth(g.badgeText:GetStringWidth() + 14)
        g.badge:Show()
    else
        g.badge:Hide()
    end
    g:Show()
    if not g.anim:IsPlaying() then g.anim:Play() end
end

local function ButtonBagSlot(button)
    local bag = button.GetBagID and button:GetBagID()
    if bag == nil then
        local parent = button:GetParent()
        bag = parent and parent:GetID()
    end
    return bag, button:GetID()
end

local function ForEachBagButton(fn)
    local frames = {}
    if ContainerFrameCombinedBags then frames[#frames + 1] = ContainerFrameCombinedBags end
    for i = 1, (NUM_CONTAINER_FRAMES or 13) do
        local f = _G["ContainerFrame" .. i]
        if f then frames[#frames + 1] = f end
    end
    for _, f in ipairs(frames) do
        if f:IsShown() then
            if f.EnumerateValidItems then
                for _, button in f:EnumerateValidItems() do fn(button) end
            else
                local name = f:GetName()
                for j = 1, 40 do
                    local b = name and _G[name .. "Item" .. j]
                    if b and b:IsShown() then fn(b) end
                end
            end
        end
    end
end

local pendingRefresh = false
local diag = { buttons = 0, items = 0, upgrades = 0, lastError = nil }
local function RefreshBags()
    pendingRefresh = false
    if not db then return end
    diag.buttons, diag.items, diag.upgrades = 0, 0, 0
    ForEachBagButton(function(button)
        diag.buttons = diag.buttons + 1
        local on = nil
        if db.glow then
            local bag, slot = ButtonBagSlot(button)
            local link = bag and slot and GetContainerItemLink(bag, slot)
            if link then
                diag.items = diag.items + 1
                local ok, r = pcall(BagUpgrade, link)
                if ok then on = r else diag.lastError = r end
                if on then diag.upgrades = diag.upgrades + 1 end
            end
        end
        local ok, err = pcall(SetGlow, button, on)
        if not ok then diag.lastError = err end
    end)
end

local function QueueRefresh()
    if pendingRefresh then return end
    pendingRefresh = true
    C_Timer.After(0.15, RefreshBags)
end

---------------------------------------------------------------------------
-- Tooltip line
---------------------------------------------------------------------------
local function ItemName(link)
    local name = link and GetItemInfo(link)
    if not name then return "üres hely" end
    local color = link:match("|c(%x%x%x%x%x%x%x%x)")
    return color and ("|c" .. color .. name .. "|r") or name
end

local function AddTooltipLine(tooltip, link, lines)
    if not db or not db.tooltip or not link then return end
    local ok, r = pcall(Compare, link)
    if not ok or not r then return end
    if not CanUse(lines or ScanLines(link)) then return end

    local p = CurrentProfile()
    local left = TEAL_HEX .. "Moteve|r  " .. SUB_HEX .. p.label .. "|r"
    local right
    if r.upgrade and r.empty then
        right = TEAL_HEX .. "upgrade (üres hely)|r"
    elseif r.upgrade and r.armorOnly then
        right = TEAL_HEX .. format("+%.0f%% armor", min(r.pct, 999)) .. "|r"
    elseif r.upgrade then
        right = TEAL_HEX .. format("+%.1f%% upgrade", min(r.pct, 999)) .. "|r"
    elseif abs(r.pct) < 0.05 then
        right = MUTED_HEX .. "same|r"
    else
        right = MUTED_HEX .. format("%+.1f%%", r.pct) .. "|r"
    end
    tooltip:AddLine(" ")
    tooltip:AddDoubleLine(left, right)
    if not r.empty then tooltip:AddLine(MUTED_HEX .. "vs.|r " .. ItemName(r.replaces)) end
    tooltip:Show()
end

local function HookTooltips()
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
            if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then return end
            local link
            if TooltipUtil and TooltipUtil.GetDisplayedItem then
                link = select(2, TooltipUtil.GetDisplayedItem(tooltip))
            elseif tooltip.GetItem then
                link = select(2, tooltip:GetItem())
            end
            AddTooltipLine(tooltip, link, data and data.lines)
        end)
    else
        for _, tt in ipairs({ GameTooltip, ItemRefTooltip }) do
            tt:HookScript("OnTooltipSetItem", function(self)
                local _, link = self:GetItem()
                AddTooltipLine(self, link)
            end)
        end
    end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local f = CreateFrame("Frame")

local function HookBagFrames()
    local function hookShow(frame)
        if frame and not frame.MoteveHooked then
            frame:HookScript("OnShow", QueueRefresh)
            frame.MoteveHooked = true
        end
    end
    hookShow(ContainerFrameCombinedBags)
    for i = 1, (NUM_CONTAINER_FRAMES or 13) do hookShow(_G["ContainerFrame" .. i]) end
    if ContainerFrame_GenerateFrame then hooksecurefunc("ContainerFrame_GenerateFrame", QueueRefresh) end
    if ContainerFrame_Update then hooksecurefunc("ContainerFrame_Update", QueueRefresh) end
end

f:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON_NAME then return end
        MoteveUpgradeDB = MoteveUpgradeDB or {}
        for k, v in pairs(DEFAULTS) do
            if MoteveUpgradeDB[k] == nil then MoteveUpgradeDB[k] = v end
        end
        MoteveUpgradeChar = MoteveUpgradeChar or {}
        db, char = MoteveUpgradeDB, MoteveUpgradeChar
        playerClass = select(2, UnitClass("player"))
        HookTooltips()
        HookBagFrames()
        self:UnregisterEvent("ADDON_LOADED")
        return
    elseif event == "PLAYER_LOGIN" then
        if not char.profile then
            char.profile = 1
            Print("profile: " .. CurrentProfile().label .. "  (change: /mup profile)")
        end
    elseif event == "PLAYER_EQUIPMENT_CHANGED" or event == "GET_ITEM_INFO_RECEIVED" or event == "ITEM_DATA_LOAD_RESULT" then
        -- nothing cached depends on equipment, but scores of newly loaded items may now be available
    end
    QueueRefresh()
end)

for _, ev in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED",
                      "GET_ITEM_INFO_RECEIVED", "ITEM_DATA_LOAD_RESULT", "PLAYER_LEVEL_UP",
                      "SKILL_LINES_CHANGED" }) do
    pcall(f.RegisterEvent, f, ev)
end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
local function PrintWeights()
    local w, keys = Weights(), {}
    for k in pairs(w) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return w[a] > w[b] end)
    Print("weights for " .. CurrentProfile().label .. ":")
    for _, k in ipairs(keys) do
        print(format("   %s%-10s|r %s  %s(%s)|r", SUB_HEX, k, tostring(w[k]), MUTED_HEX, ns.STAT_NAMES[k] or k))
    end
end

local function Changed() QueueRefresh() end -- item stats stay cached; only weights changed

SLASH_MOTEVEUPGRADE1, SLASH_MOTEVEUPGRADE2 = "/mup", "/moteveupgrade"
SlashCmdList.MOTEVEUPGRADE = function(input)
    local cmd, a, b = (input or ""):lower():match("^(%S*)%s*(%S*)%s*(%S*)")
    if cmd == "profile" then
        local list = Profiles()
        local n = tonumber(a)
        if n and list[n] then
            char.profile = n
            Print("profile set to " .. list[n].label)
            Changed()
        else
            Print("profiles for your class:")
            for i, p in ipairs(list) do
                print(format("   %s%d|r  %s%s", TEAL_HEX, i, p.label, (i == (char.profile or 1)) and (MUTED_HEX .. "  (active)|r") or ""))
            end
            print("   " .. MUTED_HEX .. "/mup profile <number>|r")
        end
    elseif cmd == "diag" then
        RefreshBags()
        local unloaded = 0
        for slot = 1, 18 do
            local l = GetInventoryItemLink("player", slot)
            if l and not statCache[l] then unloaded = unloaded + 1 end
        end
        Print("diag")
        print(format("   profil: %s   küszöb: %s%%   glow: %s   tooltip: %s", CurrentProfile().label, tostring(db.threshold), tostring(db.glow), tostring(db.tooltip)))
        print(format("   táska-gombok: %d   tárgyak: %d   upgrade: %d", diag.buttons, diag.items, diag.upgrades))
        print(format("   felszerelt, még be nem töltött tárgy: %d", unloaded))
        print("   hiba: " .. tostring(diag.lastError or "nincs"))
        if diag.buttons == 0 then print("   " .. MUTED_HEX .. "Nyisd ki a táskát, és futtasd újra. Ha így is 0, egy másik táska-addon (pl. Bagnon) kezeli a táskát.|r") end
    elseif cmd == "weights" then
        PrintWeights()
    elseif cmd == "weight" then
        local v = tonumber(b)
        if not ns.STAT_NAMES[a] or not v then
            Print("usage: /mup weight <stat> <value>   e.g. /mup weight hit 15")
            return
        end
        local key = CurrentProfile().key
        db.weights[playerClass] = db.weights[playerClass] or {}
        db.weights[playerClass][key] = db.weights[playerClass][key] or {}
        db.weights[playerClass][key][a] = v
        Print(format("%s = %s for %s", a, tostring(v), CurrentProfile().label))
        Changed()
    elseif cmd == "resetweights" then
        if db.weights[playerClass] then db.weights[playerClass][CurrentProfile().key] = nil end
        Print("weights reset to defaults for " .. CurrentProfile().label)
        Changed()
    elseif cmd == "threshold" then
        local v = tonumber(a)
        if v and v >= 0 and v <= 100 then
            db.threshold = v; Print(format("upgrade threshold: %.1f%%", v)); Changed()
        else
            Print("usage: /mup threshold <0-100>")
        end
    elseif cmd == "glow" then
        db.glow = (a ~= "off"); Print("bag glow " .. (db.glow and "on" or "off")); Changed()
    elseif cmd == "badge" then
        db.badge = (a ~= "off"); Print("percent badge " .. (db.badge and "on" or "off")); Changed()
    elseif cmd == "tooltip" then
        db.tooltip = (a ~= "off"); Print("tooltip line " .. (db.tooltip and "on" or "off"))
    else
        Print("active profile: " .. CurrentProfile().label)
        print("   /mup profile [n]          choose class role")
        print("   /mup weights              show stat weights")
        print("   /mup weight <stat> <v>    change a weight")
        print("   /mup resetweights         default weights")
        print("   /mup threshold <pct>      minimum % to count as upgrade (now " .. db.threshold .. ")")
        print("   /mup glow on|off   /mup badge on|off   /mup tooltip on|off")
        print("   /mup diag                 állapot-ellenőrzés")
    end
end
