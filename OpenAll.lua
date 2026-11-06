local deletedelay, t = 0.5, 0
local takingOnlyCash = false
local clearAfterLoot = false
local button, button2, waitForMail, doNothing, openAll, openAllCash, openMail, lastopened, stopOpening, mail_checker, needsToWait, copper_to_pretty_money, total_cash
local baseInboxFrame_OnClick
function doNothing() end

local function MailIsEmpty(index)
    local _, _, _, _, money, COD, _, numItems = GetInboxHeaderInfo(index)
    if COD and COD > 0 then
        return false
    end
    if money and money > 0 then
        return false
    end
    if numItems and numItems > 0 then
        return false
    end
    return true
end

local function DeleteEmptyMail(index)
    GetInboxText(index)
    DeleteInboxItem(index)
end

function openAll()
    if GetInboxNumItems() == 0 then return end
    button:SetScript("OnClick", nil)
    button2:SetScript("OnClick", nil)
    baseInboxFrame_OnClick = InboxFrame_OnClick
    InboxFrame_OnClick = doNothing
    button:RegisterEvent("UI_ERROR_MESSAGE")
    openMail(GetInboxNumItems())
end

function openAllCash()
    takingOnlyCash = true
    openAll()
end

local function continueAfterDelay(nextIndex)
    t = 0
    needsToWait = true
    button:SetScript("OnUpdate", function(self, elapsed)
        t = t + elapsed
        if t > deletedelay then
            t = 0
            needsToWait = false
            button:SetScript("OnUpdate", nil)
            if not InboxFrame:IsVisible() then return end
            openMail(nextIndex)
        end
    end)
end

function openMail(index)
    if not InboxFrame:IsVisible() then return end
    if index == 0 then return stopOpening("Reached the end.") end
    if clearAfterLoot and MailIsEmpty(index) then
        DeleteEmptyMail(index)
        lastopened = index
        continueAfterDelay(index - 1)
        return
    end
    local _, _, _, _, money, COD, _, numItems = GetInboxHeaderInfo(index)
    if not takingOnlyCash then
        if money > 0 or (numItems and numItems > 0) and COD <= 0 then
            AutoLootMailItem(index)
            needsToWait = true
        end
    elseif money > 0 then
        TakeInboxMoney(index)
        needsToWait = true
        if total_cash then total_cash = total_cash - money end
    end
    local items = GetInboxNumItems()
    if (numItems and numItems > 0) or (items > 1 and index <= items) then
        lastopened = index
        button:SetScript("OnUpdate", waitForMail)
    else
        stopOpening("All done.")
    end
end

function waitForMail(self, elapsed)
    t = t + elapsed
    if (not needsToWait) or (t > deletedelay) then
        if not InboxFrame:IsVisible() then return end
        t = 0
        needsToWait = false
        button:SetScript("OnUpdate", nil)
        
        local _, _, _, _, money, COD, _, numItems = GetInboxHeaderInfo(lastopened)
        if money > 0 or ((not takingOnlyCash) and COD <= 0 and numItems and (numItems > 0)) then
            -- The lastopened index inbox item still contains stuff we want
            openMail(lastopened)
        else
            if clearAfterLoot and MailIsEmpty(lastopened) then
                DeleteEmptyMail(lastopened)
                continueAfterDelay(lastopened - 1)
                return
            end
            openMail(lastopened - 1)
        end
    end
end

function stopOpening(msg, ...)
    button:SetScript("OnUpdate", nil)
    button:SetScript("OnClick", openAll)
    button2:SetScript("OnClick", openAllCash)
    if baseInboxFrame_OnClick then
        InboxFrame_OnClick = baseInboxFrame_OnClick
    end
    button:UnregisterEvent("UI_ERROR_MESSAGE")
    takingOnlyCash = false
    total_cash = nil
    needsToWait = false
    if msg then DEFAULT_CHAT_FRAME:AddMessage("OpenAll: "..msg, ...) end

    mail_checker:Show()
end

local function makeButton(id, text, w, h, x, y)
    local btn = CreateFrame("Button", id, InboxFrame, "UIPanelButtonTemplate")
    btn:SetWidth(w)
    btn:SetHeight(h)
    btn:SetPoint("CENTER", InboxFrame, "TOP", x, y)
    btn:SetText(text)
    return btn
end

button = makeButton("OpenAllButton", "Take All", 60, 25, -50, -410)
button:SetScript("OnClick", openAll)
button:SetScript("OnEvent", function(self, event, error_msg)
    -- WotLK provides error text strings globally inside UI_ERROR_MESSAGE event
    if event == "UI_ERROR_MESSAGE" and error_msg == ERR_INV_FULL then
        stopOpening("Stopped, inventory is full.")
    end
end)
button:SetScript("OnHide", function(self)
    if needsToWait then
        stopOpening("Need a mailbox.")
    end
end)

button2 = makeButton("OpenAllButton2", "Take Cash", 60, 25, 20, -410)
button2:SetScript("OnClick", openAllCash)

button:SetScript("OnEnter", function()
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:AddLine(string.format("%d messages", GetInboxNumItems()), 1, 1, 1)
    if clearAfterLoot then
        GameTooltip:AddLine("Clear empty mail: ON  (/openall clear)", 0.2, 1, 0.2)
    else
        GameTooltip:AddLine("Clear empty mail: OFF  (/openall clear)", 0.6, 0.6, 0.6)
    end
    GameTooltip:Show()
end)
button:SetScript("OnLeave", function() GameTooltip:Hide() end)

function copper_to_pretty_money(c)
    if c > 10000 then
        return ("%d|cffffd700g|r%d|cffc7c7cfs|r%d|cffeda55fc|r"):format(c/10000, (c/100)%100, c%100)
    elseif c > 100 then
        return ("%d|cffc7c7cfs|r%d|cffeda55fc|r"):format((c/100)%100, c%100)
    else
        return ("%d|cffeda55fc|r"):format(c%100)
    end
end

button2:SetScript("OnEnter", function()
    if not total_cash then
        total_cash = 0
        -- FIXED: WotLK Inbox headers index from 1 to GetInboxNumItems(). Index 0 throws a fatal Lua error.
        local totalItems = GetInboxNumItems()
        if totalItems > 0 then
            for index = 1, totalItems do
                local _, _, _, _, money = GetInboxHeaderInfo(index)
                if money then
                    total_cash = total_cash + money
                end
            end
        end
    end
    GameTooltip:SetOwner(button2, "ANCHOR_RIGHT")
    GameTooltip:AddLine(copper_to_pretty_money(total_cash), 1, 1, 1)
    GameTooltip:Show()
end)
button2:SetScript("OnLeave", function() GameTooltip:Hide() end)

mail_checker = CreateFrame("Frame")
mail_checker:Hide()
mail_checker:SetScript("OnShow", function(self)
    self:RegisterEvent("MAIL_INBOX_UPDATE")
    CheckInbox()
end)
mail_checker:SetScript("OnHide", function(self)
    -- FIXED: Avoid using select(2, GetInboxNumItems()) since return indices change between game expansions
    if GetInboxNumItems() > 0 then
        MiniMapMailFrame:Show()
    else
        MiniMapMailFrame:Hide()
  end
end)
mail_checker:SetScript("OnEvent", function(self, event, ...)
    if event == "MAIL_INBOX_UPDATE" then
        self:Hide()
        self:UnregisterEvent("MAIL_INBOX_UPDATE")
    end
end)

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, event, name)
    if name ~= "OpenAll" then
        return
    end
    OpenAllDB = OpenAllDB or {}
    if OpenAllDB.clear == nil then
        OpenAllDB.clear = false
    end
    clearAfterLoot = OpenAllDB.clear and true or false
    self:UnregisterEvent("ADDON_LOADED")
end)

SLASH_OPENALL1 = "/openall"
SlashCmdList["OPENALL"] = function(msg)
    msg = strlower(strtrim(msg or ""))
    if msg ~= "clear" then
        DEFAULT_CHAT_FRAME:AddMessage("OpenAll: /openall clear — toggle deleting mail after attachments and gold are taken.")
        DEFAULT_CHAT_FRAME:AddMessage("OpenAll: Clear empty mail is currently "..(clearAfterLoot and "ON" or "OFF")..".")
        return
    end
    clearAfterLoot = not clearAfterLoot
    OpenAllDB = OpenAllDB or {}
    OpenAllDB.clear = clearAfterLoot
    DEFAULT_CHAT_FRAME:AddMessage("OpenAll: Clear empty mail "..(clearAfterLoot and "ON" or "OFF")..".")
end
