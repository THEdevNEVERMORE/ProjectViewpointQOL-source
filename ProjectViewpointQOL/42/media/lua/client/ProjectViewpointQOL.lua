-- Project Viewpoint QOL
-- Companion mod for Project Viewpoint (Build 42)
-- 1. Automatically unlocks mouse on inventory open, and auto-locks back to camera on close.
-- 2. In-world Container Equip: Displays [G] Equip hint in Viewpoint container menu and allows 1-key equipping.
-- 3. Radial / Wheel Menu Mouse Unlock: Automatically unlocks mouse cursor when opening radial menus (V, Q, R, F, etc.)
-- 4. Device & Interaction Windows: Automatically unlocks mouse on ovens, stoves, microwaves, TVs, radios, context menus, and vehicle mechanics.
-- 5. Optional Lock-to-Close: Pressing the lock key (middle mouse) while unlocked closes all open popup windows (off by default).

require "ISUI/ISInventoryPage"
require "ISUI/ISRadialMenu"
require "ISUI/ISContextMenu"
require "ISUI/Fireplace/ISOvenUI"
require "ISUI/Fireplace/ISMicrowaveUI"
require "TimedActions/ISApplyBandage"
require "TimedActions/ISDisinfect"
require "TimedActions/ISStitch"
require "TimedActions/ISEquipWeaponAction"
require "TimedActions/ISUnequipAction"
require "TimedActions/ISInventoryTransferAction"

ProjectViewpointQOL = ProjectViewpointQOL or {}

local unlockedByMod = false
local wasInventoryOpen = false
local wasRadialOpen = false
local wasDeviceOrMenuOpen = false
local activeRadialMenus = {}
local activeInteractiveWindows = {}
local isHarvestingContextMenu = false
local suppressMouseUpdates = false
local wasMiddleDown = false
local lastCursorUnlocked = false
local manualLockOverride = false
local activeChooserMenu = nil
local lootDestContainer = nil
local lastHintSuffix = nil
local lastTargetedItem = nil
local lastTargetedItemEquippable = false
local lastTargetedItemEquipKind = nil
local lastTargetedItemHasExtras = false
local lastTargetedItemEdible = false
local lastTargetedItemDrinkable = false

-- Forward declarations (defined later, first used by executeAmmoTargetedItem)
local closeCharacterInfoIfOpen
local closeCraftingWindowIfOpen
local lastTargetedItemPill = false
local lastTargetedItemSmokable = false
local lastTargetedItemReadable = false
local cachedEquipSuffix = nil
local cachedEquipSuffixKey = nil
local cachedEquipSuffixKind = nil
local cachedEquipSuffixExtras = nil
local cachedEatAllSuffix = nil
local cachedEatAllSuffixKey = nil
local cachedDrinkAllSuffix = nil
local cachedDrinkAllSuffixKey = nil
local cachedPillSuffix = nil
local cachedPillSuffixKey = nil
local cachedSmokeSuffix = nil
local cachedSmokeSuffixKey = nil
local cachedReadSuffix = nil
local cachedReadSuffixKey = nil
local lastTargetedItemFirstAid = false
local lastTargetedItemFirstAidType = nil
local lastTargetedItemFirstAidPart = nil
local lastTargetedItemFirstAidExtra = nil
local cachedFirstAidSuffix = nil
local cachedFirstAidSuffixKey = nil
local cachedFirstAidSuffixType = nil
local cachedFirstAidSuffixItem = nil

local lastTargetedItemAmmo = false
local lastTargetedItemAmmoAction = nil
local lastTargetedItemAmmoCount = 0
local lastTargetedItemAmmoSubType = nil
local cachedAmmoSuffix = nil
local cachedAmmoSuffixKey = nil
local cachedAmmoSuffixAction = nil
local cachedAmmoSuffixCount = nil
local cachedAmmoSuffixItem = nil

local lastTargetedItemCraftable = false
local cachedCraftSuffix = nil
local cachedCraftSuffixKey = nil

local autoWalkActive = false
local autoWalkLastX = 0
local autoWalkLastY = 0
local autoWalkStuckTicks = 0
local autoWalkLastHealth = 100
local autoWalkZombieSlowed = false

local cachedBridge = nil
local function bridge()
    if not cachedBridge then
        cachedBridge = ViewpointQOL
    end
    return cachedBridge
end

-- Project Viewpoint's team asks addons to pin to one version and disable
-- themselves with clear feedback on a mismatch (their internals change between
-- builds). The Java side checks viewpoint.platform.Build.VERSION; when the API
-- is missing we fall back to the old behaviour (per-feature soft-fails).
function ProjectViewpointQOL.isViewpointVersionSupported()
    local api = ViewpointQOLVersion
    if api and api.isSupported then
        local ok, supported = pcall(api.isSupported)
        if ok then return supported == true end
    end
    return true
end

local function isViewpointActive()
    if not ProjectViewpointQOL.isViewpointVersionSupported() then return false end
    local b = bridge()
    return b and b.isAvailable and b.isAvailable() and b.isViewpointActive and b.isViewpointActive()
end

local function isCursorUnlocked()
    local b = bridge()
    if b and b.isCursorMode then
        return b.isCursorMode()
    end
    return false
end

-- Single entry point for popup messages so the "On-screen notifications"
-- option can silence them all. Console logging stays outside this helper.
function ProjectViewpointQOL.notify(player, text, kind)
    local options = ProjectViewpointQOLOptions or {}
    if options.enableNotifications == false then return end
    if not (player and HaloTextHelper) then return end
    pcall(function()
        if kind == "good" and HaloTextHelper.addGoodText then
            HaloTextHelper.addGoodText(player, text)
        elseif kind == "arrow" and HaloTextHelper.addTextWithArrow then
            HaloTextHelper.addTextWithArrow(player, text, true, 0.35, 0.95, 0.45)
        elseif HaloTextHelper.addBadText then
            HaloTextHelper.addBadText(player, text)
        elseif HaloTextHelper.addText then
            HaloTextHelper.addText(player, text)
        end
    end)
end

-- One-time environment/bridge report so multiplayer problems are diagnosable:
-- silently doing nothing was the worst part of a missing Java bridge.
function ProjectViewpointQOL.checkBridgeStatus(player, now)
    -- Version pin first: on an unsupported Project Viewpoint the features are
    -- disabled with one clear message instead of a pile of soft-fail warnings.
    if not ProjectViewpointQOL.isViewpointVersionSupported() then
        if ProjectViewpointQOL.bridgeStatus ~= "unsupported" then
            ProjectViewpointQOL.bridgeStatus = "unsupported"
            local api = ViewpointQOLVersion
            local found = ""
            if api and api.getVersion then
                local ok, value = pcall(api.getVersion)
                if ok and value then found = tostring(value) end
            end
            local needed = ""
            if api and api.getSupported then
                local ok, value = pcall(api.getSupported)
                if ok and value then needed = tostring(value) end
            end
            if found == "" then found = "unknown" end
            if needed == "" then needed = "0.1.6.1" end
            print("[ProjectViewpointQOL] Project Viewpoint " .. found .. " is not supported: this mod is pinned to " .. needed .. " only.")
            print("[ProjectViewpointQOL] QOL features are disabled. Update Project Viewpoint QOL for the new version, or use Project Viewpoint " .. needed .. ".")
            ProjectViewpointQOL.notify(player, "Project Viewpoint QOL disabled: needs Viewpoint " .. needed .. " (found " .. found .. ")", "bad")
        end
        return
    end

    if ProjectViewpointQOL.bridgeStatus == "ready" then return end
    local b = bridge()
    local available = (b and b.isAvailable and b.isAvailable()) and true or false

    -- The bridge resolves Viewpoint's fields once when its Java class first
    -- loads, which can happen before Viewpoint's JAR is on the classpath
    -- (ZombieBuddy loads Java mods in mod-list order). Retry it here so a
    -- load-order mix-up heals itself instead of disabling features until a
    -- restart. By the time Lua runs all JARs are loaded, so this normally
    -- succeeds on the first attempt.
    if not available and ViewpointQOLSettings and ViewpointQOLSettings.retryBridgeInit
        and now - (ProjectViewpointQOL.bridgeRetryAt or 0) >= 5000 then
        ProjectViewpointQOL.bridgeRetryAt = now
        pcall(ViewpointQOLSettings.retryBridgeInit)
        available = (b and b.isAvailable and b.isAvailable()) and true or false
    end

    if available then
        ProjectViewpointQOL.bridgeStatus = "ready"
        print("[ProjectViewpointQOL] Java bridge ready (client=" .. tostring(isClient and isClient()) ..
            " server=" .. tostring(isServer and isServer()) .. ").")
        if ProjectViewpointQOL.bridgeWarnedAt then
            print("[ProjectViewpointQOL] Java bridge recovered after retry (mod load order).")
        end
        return
    end

    if ProjectViewpointQOL.bridgeStatus == "warned" then return end
    if not ProjectViewpointQOL.bridgeCheckAt then
        -- Give a late-loading bridge (approval/mod load order) a chance first
        ProjectViewpointQOL.bridgeCheckAt = now + 10000
        return
    end
    if now < ProjectViewpointQOL.bridgeCheckAt then return end
    ProjectViewpointQOL.bridgeCheckAt = now + 5000
    ProjectViewpointQOL.bridgeWarnedAt = now
    ProjectViewpointQOL.bridgeStatus = "warned"
    print("[ProjectViewpointQOL] WARNING: Java bridge not loaded - QOL features are disabled.")
    print("[ProjectViewpointQOL] Fix: run ZombieBuddy's one-time setup and approve the 'Project Viewpoint QOL' JAR (tick Allow); re-approve after mod updates.")
    print("[ProjectViewpointQOL] If it persists, load Project Viewpoint QOL AFTER Viewpoint in the mod list; the mod retries automatically and recovers without a restart.")
    print("[ProjectViewpointQOL] Multiplayer: every player needs ZombieBuddy set up; servers must enable: Mods=ZombieBuddy;Viewpoint;ProjectViewpointQOL")
    if isClient and isClient() then
        print("[ProjectViewpointQOL] MP hint: when joining a server, approve this mod's JAR in ZombieBuddy's dialog (hold Shift while the game loads to force it), and keep ZombieBuddy first, then Viewpoint, then ProjectViewpointQOL in the server's mod list.")
    end
    print("[ProjectViewpointQOL] env: client=" .. tostring(isClient and isClient()) ..
        " server=" .. tostring(isServer and isServer()) ..
        " viewpointLoaded=" .. tostring(Viewpoint ~= nil) .. " bridge=" .. tostring(b ~= nil))
    ProjectViewpointQOL.notify(player, "Project Viewpoint QOL: Java bridge not loaded - check console for setup steps", "bad")
end

-- True while the configured modifier is held. Left/right variants of Alt, Ctrl
-- and Shift are treated as the same key so either side works for left-side
-- binds. Right-side binds match exactly, so Right Alt can be used for the
-- Auto-Walk shortcut while Left Alt belongs to another mod (free look).
local function isModifierKeyDown(modKey)
    if not isKeyDown or not modKey or modKey == 0 then return false end
    if isKeyDown(modKey) then return true end

    local lmenu = (Keyboard and Keyboard.KEY_LMENU) or 56
    local rmenu = (Keyboard and Keyboard.KEY_RMENU) or 184
    local lctrl = (Keyboard and Keyboard.KEY_LCONTROL) or 29
    local rctrl = (Keyboard and Keyboard.KEY_RCONTROL) or 157
    local lshift = (Keyboard and Keyboard.KEY_LSHIFT) or 42
    local rshift = (Keyboard and Keyboard.KEY_RSHIFT) or 54

    if modKey == rmenu or modKey == rctrl or modKey == rshift then return false end

    if modKey == lmenu then return isKeyDown(rmenu) end
    if modKey == lctrl then return isKeyDown(rctrl) end
    if modKey == lshift then return isKeyDown(rshift) end
    return false
end

local function getPlayerInv()
    if getPlayerInventory then
        return getPlayerInventory(0)
    end
    return nil
end

local function getLootInv()
    if getPlayerLoot then
        return getPlayerLoot(0)
    end
    return nil
end

local function expandInventory(inv)
    if not inv then return end
    inv.isCollapsed = false
    if inv.clearMaxDrawHeight then
        inv:clearMaxDrawHeight()
    end
    inv.collapseCounter = 0
end

local function isInventoryOpen()
    local player = getSpecificPlayer(0)
    if not player or player:isDead() then return false end

    local playerInv = getPlayerInv()
    local lootInv = getLootInv()

    local playerOpen = playerInv and playerInv:getIsVisible() and not playerInv.isCollapsed
    local lootOpen = false

    local options = ProjectViewpointQOLOptions or {}
    if options.watchLoot ~= false then
        lootOpen = lootInv and lootInv:getIsVisible() and not lootInv.isCollapsed
    end

    return playerOpen or lootOpen
end

local function isRadialMenuOpenRaw()
    local player = getSpecificPlayer(0)
    if not player or player:isDead() then return false end

    local radial = getPlayerRadialMenu(0)
    if radial and radial:isReallyVisible() then
        return true
    end

    for menu, _ in pairs(activeRadialMenus) do
        if menu and menu:isReallyVisible() then
            return true
        else
            activeRadialMenus[menu] = nil
        end
    end

    return false
end

local function isRadialMenuOpen()
    -- Viewpoint's interaction gatherer swaps in a stand-in radial while it
    -- collects vehicle actions; it reports itself visible, so during a gather
    -- keep the last real state instead of trusting the stand-in.
    if isHarvestingContextMenu then
        return ProjectViewpointQOL.radialMenuWasOpen == true
    end
    local open = isRadialMenuOpenRaw()
    ProjectViewpointQOL.radialMenuWasOpen = open
    return open
end

local function isOvenOpen()
    if ISOvenUI and ISOvenUI.instance then
        local player = getSpecificPlayer(0)
        local pNum = player and player:getPlayerNum() or 0
        local ui = ISOvenUI.instance[pNum + 1]
        if ui and ui:getIsVisible() then
            if UIManager and UIManager.getUI and ui.javaObject then
                return UIManager.getUI():contains(ui.javaObject)
            end
            return true
        end
    end
    return false
end

local function isMicrowaveOpen()
    if ISMicrowaveUI and ISMicrowaveUI.instance then
        local player = getSpecificPlayer(0)
        local pNum = player and player:getPlayerNum() or 0
        local ui = ISMicrowaveUI.instance[pNum + 1]
        if ui and ui:getIsVisible() then
            if UIManager and UIManager.getUI and ui.javaObject then
                return UIManager.getUI():contains(ui.javaObject)
            end
            return true
        end
    end
    return false
end

local function isRadioWindowOpen()
    if not ISRadioWindow then return false end
    if ISRadioWindow.instances then
        for _, win in pairs(ISRadioWindow.instances) do
            if win and win:getIsVisible() and not win.isCollapsed then
                return true
            end
        end
    end
    if ISRadioWindow.instancesIso then
        for _, win in pairs(ISRadioWindow.instancesIso) do
            if win and win:getIsVisible() and not win.isCollapsed then
                return true
            end
        end
    end
    return false
end

local function isContextMenuOpen()
    if not ISContextMenu then return false end
    local cm = getPlayerContextMenu and getPlayerContextMenu(0)
    local raw = (cm and cm:getIsVisible()) and true or false
    -- During Viewpoint's gather a menu is briefly built and hidden; keep the
    -- last real state so the transient menu cannot free the cursor, and a real
    -- open menu is not mistaken for closed.
    if isHarvestingContextMenu then
        return ProjectViewpointQOL.contextMenuWasOpen == true
    end
    ProjectViewpointQOL.contextMenuWasOpen = raw
    return raw
end

local function isVehicleMechanicsOpen()
    if not getPlayerMechanicsUI then return false end
    local ui = getPlayerMechanicsUI(0)
    if not ui then return false end
    if ui.isReallyVisible then
        return ui:isReallyVisible() == true
    end
    return ui:getIsVisible() == true and not ui.isCollapsed
end

local function isVehicleSeatUIOpen()
    if not ISVehicleMenu or not ISVehicleMenu.seatUI then return false end
    local ui = ISVehicleMenu.seatUI[0]
    if not ui then return false end
    if ui.isReallyVisible then
        return ui:isReallyVisible() == true
    end
    return ui:getIsVisible() == true
end

local function isWorldMapOpen()
    if ISWorldMap and ISWorldMap.instance and ISWorldMap.instance:isVisible() then
        return true
    end
    if ISWorldMap_instance and ISWorldMap_instance:isVisible() then
        return true
    end
    return false
end

local function isCraftingOrBuildingOpen()
    if not ISEntityUI then return false end
    local pNum = 0
    if ISEntityUI.players and ISEntityUI.players[pNum] and ISEntityUI.players[pNum].windows then
        for _, w in pairs(ISEntityUI.players[pNum].windows) do
            if w and w.instance and w.instance:getIsVisible() and not w.instance.isCollapsed then
                return true
            end
        end
    end
    return false
end

local function isCharacterInfoOpen()
    local charWin = (ISCharacterInfoWindow and ISCharacterInfoWindow.instance) or (getPlayerInfoPanel and getPlayerInfoPanel(0))
    return (charWin and charWin:getIsVisible() and not charWin.isCollapsed) == true
end

local function isSearchWindowOpen()
    if not (ISSearchWindow and ISSearchWindow.players) then return false end
    local player = getSpecificPlayer(0)
    if not player then return false end
    local ui = ISSearchWindow.players[player]
    return (ui and ui.getIsVisible and ui:getIsVisible() and not ui.isCollapsed) == true
end

local function isGenericInteractiveWindowOpen()
    for win, _ in pairs(activeInteractiveWindows) do
        if win and win:getIsVisible() and not win.isCollapsed then
            -- Strict guard against background chat or inventory pages
            if not (instanceof and (instanceof(win, "ISChat") or instanceof(win, "ISInventoryPage"))) then
                return true
            end
        else
            activeInteractiveWindows[win] = nil
        end
    end
    return false
end

local function isDeviceOrMenuOpen()
    local player = getSpecificPlayer(0)
    if not player or player:isDead() then return false end

    return isOvenOpen() or
           isMicrowaveOpen() or
           isRadioWindowOpen() or
           isContextMenuOpen() or
           isVehicleMechanicsOpen() or
           isVehicleSeatUIOpen() or
           isWorldMapOpen() or
           isCraftingOrBuildingOpen() or
           isCharacterInfoOpen() or
           isSearchWindowOpen() or
           isGenericInteractiveWindowOpen()
end

local function shouldMouseBeUnlocked()
    local options = ProjectViewpointQOLOptions or {}

    local invOpen = (options.unlockOnOpen ~= false) and isInventoryOpen()
    local radialOpen = (options.unlockOnRadial ~= false) and isRadialMenuOpen()
    local deviceOpen = (options.unlockOnDevice ~= false) and isDeviceOrMenuOpen()

    return invOpen or radialOpen or deviceOpen
end

local function updateMouseState(invRaw, radialRaw, deviceRaw, viewActive)
    if suppressMouseUpdates then return end

    if viewActive == nil then viewActive = isViewpointActive() end
    if not viewActive then
        wasInventoryOpen = false
        wasRadialOpen = false
        wasDeviceOrMenuOpen = false
        unlockedByMod = false
        ProjectViewpointQOL.pendingRelockUntil = 0
        manualLockOverride = false
        return
    end

    local options = ProjectViewpointQOLOptions or {}
    if invRaw == nil then invRaw = isInventoryOpen() end
    if radialRaw == nil then radialRaw = isRadialMenuOpen() end
    if deviceRaw == nil then deviceRaw = isDeviceOrMenuOpen() end

    wasInventoryOpen = invRaw
    wasRadialOpen = radialRaw
    wasDeviceOrMenuOpen = deviceRaw

    if not (invRaw or radialRaw or deviceRaw) then
        manualLockOverride = false
    end

    local wantUnlocked = (options.unlockOnOpen ~= false and invRaw) or
                         (options.unlockOnRadial ~= false and radialRaw) or
                         (options.unlockOnDevice ~= false and deviceRaw)

    -- A manual lock (middle mouse / lock hotkey) wins over the auto-unlock
    -- until the user unlocks again or the window state changes.
    if manualLockOverride then
        wantUnlocked = false
    end

    if wantUnlocked then
        ProjectViewpointQOL.pendingRelockUntil = 0
        if not isCursorUnlocked() then
            local b = bridge()
            if b and b.unlockMouse then b.unlockMouse() end
        end
        unlockedByMod = true
    else
        if unlockedByMod then
            if options.lockOnClose ~= false then
                local b = bridge()
                if b and b.lockMouse then b.lockMouse() end
                ProjectViewpointQOL.pendingRelockUntil = getTimestampMs() + 150
            end
            unlockedByMod = false
        end
    end
end

-- ====================================================================
-- Feature 2: Container Equip Detection & Execution
-- ====================================================================

local function checkEquippableRaw(item, player)
    if player:isDead() then return false end

    -- Already equipped / held?
    if (player.isEquipped and player:isEquipped(item)) or
       (player.isEquippedClothing and player:isEquippedClothing(item)) or
       (player.isHandItem and player:isHandItem(item)) then
        return false
    end

    -- Food cannot be equipped (matches the vanilla equip menu)
    if (item.IsFood and item:IsFood()) or
       (item.getCategory and item:getCategory() == "Food") then
        return false
    end

    -- Weapons (a weapon with no condition left cannot be equipped)
    if (item.IsWeapon and item:IsWeapon()) or
       (instanceof and instanceof(item, "HandWeapon")) then
        if item.getCondition and item:getCondition() <= 0 then return false end
        return true, "weapon"
    end

    -- Clothing & Armor (broken clothing cannot be worn)
    if (item.IsClothing and item:IsClothing()) or
       (instanceof and instanceof(item, "Clothing")) or
       (item.getBodyLocation and item:getBodyLocation() ~= nil) then
        if item.isBroken and item:isBroken() then return false end
        return true, "clothing"
    end

    -- Equippable Bags & Backpacks
    if (instanceof and instanceof(item, "InventoryContainer")) and item.canBeEquipped and item:canBeEquipped() then
        return true, "bag"
    end

    -- Hand-held containers (handbag, briefcase, ...) that can't be worn but can be held in a hand
    if instanceof and instanceof(item, "InventoryContainer") then
        if (item.getItemReplacementPrimaryHand and item:getItemReplacementPrimaryHand() ~= nil) or
           (item.getItemReplacementSecondHand and item:getItemReplacementSecondHand() ~= nil) then
            return true, "tool"
        end
    end

    -- Hand tools / activatable equippables (flashlight, umbrella, etc.)
    if (item.isRequiresEquippedBothHands and item:isRequiresEquippedBothHands()) or
       (item.canBeActivated and item:canBeActivated()) then
        return true, "tool"
    end

    if ItemTag and item.hasTag and ((ItemTag.EQUIPPABLE and item:hasTag(ItemTag.EQUIPPABLE)) or
       (ItemTag.WEARABLE and item:hasTag(ItemTag.WEARABLE))) then
        return true, "tool"
    end

    -- Heavy items (generators, corpses)
    if isForceDropHeavyItem and isForceDropHeavyItem(item) then
        return true, "heavy"
    end

    return false
end

local function isEquippable(item, player)
    if not item or not player then return false end

    local ok, res, kind = pcall(checkEquippableRaw, item, player)
    if ok then
        return res, kind
    end
    return false
end

local function equipTargetedItem(item, player)
    if not item or not player or player:isDead() then return end
    local playerNum = player:getPlayerNum()

    -- 1. If item is lying on the ground, register it with floor container for proper transfer
    if item:getWorldItem() ~= nil then
        local floor = ISInventoryPage.GetFloorContainer(playerNum)
        if floor and not floor:contains(item) then
            floor:AddItem(item)
        end
    end

    -- 2. Heavy item handling
    if isForceDropHeavyItem and isForceDropHeavyItem(item) then
        ISInventoryPaneContextMenu.equipHeavyItem(player, item)
        return
    end

    -- 3. Walk to container if necessary
    local container = item:getContainer()
    if container and luautils and luautils.walkToContainer and not luautils.walkToContainer(container, playerNum) then
        return
    end

    -- Transfer item to player inventory if needed before equipping (fixes CleanUI context transfer NPE)
    if container and container ~= player:getInventory() then
        local transfer = ISInventoryTransferUtil.newInventoryTransferAction(player, item, container, player:getInventory())
        ISTimedActionQueue.add(transfer)
    end

    -- 4. Equip by category
    pcall(function()
        if item:IsWeapon() or (instanceof and instanceof(item, "HandWeapon")) then
            local twoHands = (item.isTwoHandWeapon and item:isTwoHandWeapon()) or
                             (item.isRequiresEquippedBothHands and item:isRequiresEquippedBothHands())
            ISInventoryPaneContextMenu.equipWeapon(item, true, twoHands, playerNum)
        elseif item:IsClothing() or (instanceof and instanceof(item, "Clothing")) or (item.getBodyLocation and item:getBodyLocation() ~= nil) then
            ISInventoryPaneContextMenu.wearItem(item, playerNum)
        elseif (instanceof and instanceof(item, "InventoryContainer")) and item:canBeEquipped() then
            ISInventoryPaneContextMenu.wearItem(item, playerNum)
        elseif (item.canBeActivated and item:canBeActivated()) or
               (item.isRequiresEquippedBothHands and item:isRequiresEquippedBothHands()) or
               (ItemTag and item:hasTag(ItemTag.EQUIPPABLE)) then
            local twoHands = item.isRequiresEquippedBothHands and item:isRequiresEquippedBothHands()
            ISInventoryPaneContextMenu.equipWeapon(item, true, twoHands, playerNum)
        else
            if item.getBodyLocation and item:getBodyLocation() ~= nil then
                ISInventoryPaneContextMenu.wearItem(item, playerNum)
            else
                ISInventoryPaneContextMenu.equipWeapon(item, true, false, playerNum)
            end
        end
    end)
end

-- ====================================================================
-- Feature 2a: Equip Location Chooser (attachments & extra wear choices)
-- ====================================================================

local function getClothingExtraChoices(item, player)
    local choices = {}
    if not (item.getClothingItemExtraOption and item:getClothingItemExtraOption()) then return choices end
    if not (item.getClothingItemExtra and item:getClothingItemExtra()) then return choices end

    local opts = item:getClothingItemExtraOption()
    local extras = item:getClothingItemExtra()
    for i = 0, opts:size() - 1 do
        local key = opts:get(i)
        local extraType = extras:get(i)
        if key and extraType then
            local text = getText("ContextMenu_" .. key)
            if not text or text == "ContextMenu_" .. key then text = key end
            table.insert(choices, { label = text, extraType = extraType })
        end
    end
    return choices
end

local function getAttachmentChoices(item, player)
    local choices = {}
    if not (item.getAttachmentType and item:getAttachmentType()) then return choices end
    if item.isBroken and item:isBroken() then return choices end
    if item.getAttachedSlot and item:getAttachedSlot() ~= -1 then return choices end
    if not (getPlayerHotbar and ISHotbar and ISHotbar.attachItem) then return choices end

    local hotbar = getPlayerHotbar(player:getPlayerNum())
    if not (hotbar and hotbar.availableSlot) then return choices end

    local attachType = item:getAttachmentType()
    for slotIndex, slot in pairs(hotbar.availableSlot) do
        local slotDef = slot and slot.def
        if slotDef and slotDef.attachments and slotDef.attachments[attachType] then
            local model = slotDef.attachments[attachType]
            if slotDef.name == "Back" and hotbar.replacements and hotbar.replacements[attachType] then
                model = hotbar.replacements[attachType]
            end
            if model and model ~= "null" then
                local label = (getTextOrNull and getTextOrNull("IGUI_HotbarAttachment_" .. slot.slotType)) or slot.name
                table.insert(choices, { label = label, model = model, slotIndex = slotIndex, slotDef = slotDef })
            end
        end
    end
    return choices
end

local function hasExtraEquipChoices(item, player)
    if not item or not player then return false end
    local ok, result = pcall(function()
        if #getClothingExtraChoices(item, player) > 0 then return true end
        if #getAttachmentChoices(item, player) > 0 then return true end
        return false
    end)
    return ok and result == true
end

local function canGoInSecondaryHand(item, kind)
    if kind == "bag" then return true end
    if kind ~= "weapon" and kind ~= "tool" then return false end
    local twoHanded = false
    pcall(function() twoHanded = (item.isTwoHandWeapon and item:isTwoHandWeapon()) == true end)
    return not twoHanded
end

local function getBasicEquipLabel(kind)
    if kind == "heavy" then
        local text = getText("ContextMenu_Grab_Corpse")
        if not text or text == "ContextMenu_Grab_Corpse" then text = "Grab" end
        return text
    end
    if kind == "clothing" or kind == "bag" then
        local text = getText("ContextMenu_Wear")
        if not text or text == "ContextMenu_Wear" then text = "Wear" end
        return text
    end
    local text = getText("ContextMenu_Equip")
    if not text or text == "ContextMenu_Equip" then text = "Equip" end
    return text
end

local function openEquipChooser(item, player, kind)
    if not item or not player or player:isDead() then return end
    if not (ISContextMenu and ISContextMenu.get) then
        equipTargetedItem(item, player)
        return
    end

    local playerNum = player:getPlayerNum()

    -- Register ground items with the floor container so the extra/attachment
    -- callbacks can transfer them into the player inventory
    if item.getWorldItem and item:getWorldItem() ~= nil then
        local floor = ISInventoryPage.GetFloorContainer(playerNum)
        if floor and not floor:contains(item) then
            floor:AddItem(item)
        end
    end

    local menu = ISContextMenu.get(playerNum, getMouseX(), getMouseY())

    -- 1. Basic action (same as the normal one-key equip)
    menu:addOption(getBasicEquipLabel(kind), item, function(target) equipTargetedItem(target, player) end)

    -- 1b. Hand placement: weapons/tools to the secondary hand, bags into either hand
    local equipWeaponFn = ISInventoryPaneContextMenu and ISInventoryPaneContextMenu.equipWeapon
    if equipWeaponFn then
        if kind == "weapon" or kind == "tool" then
            if canGoInSecondaryHand(item, kind) then
                local label = getText("ContextMenu_Equip_Secondary")
                if not label or label == "ContextMenu_Equip_Secondary" then label = "Equip in Secondary Hand" end
                menu:addOption(label, item, equipWeaponFn, false, false, playerNum)
            end
        elseif kind == "bag" then
            menu:addOption("Hold in Primary Hand", item, equipWeaponFn, true, false, playerNum)
            menu:addOption("Hold in Secondary Hand", item, equipWeaponFn, false, false, playerNum)
        end
    end

    -- 2. Clothing extra wear choices (fanny pack front/back, hood up/down, wrist, ...)
    for _, choice in ipairs(getClothingExtraChoices(item, player)) do
        menu:addOption(choice.label, item, ISInventoryPaneContextMenu.onClothingItemExtra, choice.extraType, player)
    end

    -- 3. Hotbar attachment slots (back, belt, holster, webbing, ...)
    local hotbar = getPlayerHotbar and getPlayerHotbar(playerNum)
    for _, choice in ipairs(getAttachmentChoices(item, player)) do
        menu:addOption(choice.label, hotbar, ISHotbar.attachItem, item, choice.model, choice.slotIndex, choice.slotDef, true)
    end

    activeChooserMenu = menu
    local b = bridge()
    if b and b.unlockMouse then b.unlockMouse() end
    unlockedByMod = true
end

-- ====================================================================
-- Feature 2b: Take Destination Chooser (inventory, worn bags)
-- ====================================================================

local function getTakeDestinations(player, item)
    local destinations = {}
    if not player then return destinations end

    local playerNum = player:getPlayerNum()
    local mainInv = player:getInventory()
    local source = item and item.getContainer and item:getContainer() or nil

    local function add(label, container)
        if not container or container == source then return end
        for _, dest in ipairs(destinations) do
            if dest.container == container then return end
        end
        if item then
            local okAllowed, allowed = pcall(function() return container:isItemAllowed(item) end)
            if okAllowed and not allowed then return end
            local okRoom, room = pcall(function() return container:hasRoomFor(player, item) end)
            if okRoom and not room then return end
        end
        table.insert(destinations, { label = label, container = container })
    end

    if mainInv then
        add(getText("ContextMenu_MoveToInventory") or "Move to inventory", mainInv)
    end

    local invPage = getPlayerInventory and getPlayerInventory(playerNum)
    if invPage and invPage.backpacks then
        for _, entry in ipairs(invPage.backpacks) do
            if entry and entry.inventory and entry.inventory ~= mainInv then
                local label = entry.name
                if not label or label == "" then
                    local containing = entry.inventory.getContainingItem and entry.inventory:getContainingItem()
                    label = (containing and containing:getDisplayName()) or getText("ContextMenu_MoveToContainer") or "Container"
                end
                add(label, entry.inventory)
            end
        end
    elseif player.getWornItems then
        local worn = player:getWornItems()
        for i = 1, worn:size() do
            local entry = worn:get(i - 1)
            local wornItem = entry and entry.getItem and entry:getItem()
            if wornItem and wornItem.getInventory and wornItem:getInventory() then
                add(wornItem:getName(), wornItem:getInventory())
            end
        end
    end

    return destinations
end

local function withoutProgressBar(fn)
    local add = ISTimedActionQueue.add
    ISTimedActionQueue.add = function(action)
        action.useProgressBar = false
        return add(action)
    end
    local ok, err = pcall(fn)
    ISTimedActionQueue.add = add
    if not ok then error(err) end
end

local function takeItemTo(player, item, dest)
    if not item or not player or not dest or player:isDead() then return end
    if item:isHumanCorpse() and player:getVehicle() then return end
    local playerNum = player:getPlayerNum()

    if item:getWorldItem() ~= nil then
        local floor = ISInventoryPage.GetFloorContainer(playerNum)
        if floor and not floor:contains(item) then
            floor:AddItem(item)
        end
    end

    if isForceDropHeavyItem and isForceDropHeavyItem(item) then
        ISInventoryPaneContextMenu.equipHeavyItem(player, item)
        return
    end

    local from = item:getContainer()
    if not from or from == dest then return end

    withoutProgressBar(function()
        if luautils and luautils.walkToContainer and not luautils.walkToContainer(from, playerNum) then
            return
        end
        ISTimedActionQueue.add(ISInventoryTransferUtil.newInventoryTransferAction(player, item, from, dest))
    end)
end

-- Loot All filters: optionally protect favorites and keys from bulk looting
local function shouldSkipTakeAll(item, player)
    if not item then return true end
    local options = ProjectViewpointQOLOptions or {}
    if options.takeAllSkipFavorites ~= false and item.isFavorite then
        local okF, fav = pcall(function() return item:isFavorite() end)
        if okF and fav then return true end
    end
    if options.takeAllSkipKeys ~= false then
        local okK, key = pcall(function()
            return (item.isItemType and ItemType and ItemType.KEY_RING and item:isItemType(ItemType.KEY_RING))
                or (item.hasTag and ItemTag and ItemTag.KEY_RING and item:hasTag(ItemTag.KEY_RING))
        end)
        if okK and key then return true end
    end
    return false
end

local function takeAllTo(player, items, dest, filter)
    if not items or not player or not dest or player:isDead() then return end
    local playerNum = player:getPlayerNum()

    local list = {}
    local heavies = {}
    local inVehicle = player:getVehicle() ~= nil
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item then
            local unwanted = false
            if item.isUnwanted then
                local okU, u = pcall(function() return item:isUnwanted(player) end)
                unwanted = okU and u == true
            end
            if not unwanted and not (inVehicle and item:isHumanCorpse()) and not (filter and filter(item, player)) then
                if item:getWorldItem() ~= nil then
                    local floor = ISInventoryPage.GetFloorContainer(playerNum)
                    if floor and not floor:contains(item) then
                        floor:AddItem(item)
                    end
                end
                if isForceDropHeavyItem and isForceDropHeavyItem(item) then
                    table.insert(heavies, item)
                else
                    table.insert(list, item)
                end
            end
        end
    end

    withoutProgressBar(function()
        for _, heavy in ipairs(heavies) do
            ISInventoryPaneContextMenu.equipHeavyItem(player, heavy)
        end
        if #list > 0 and luautils and luautils.walkToContainer and luautils.walkToContainer(list[1]:getContainer(), playerNum) then
            local lootPage = getPlayerLoot and getPlayerLoot(playerNum)
            if lootPage and lootPage.inventoryPane then
                lootPage.inventoryPane:transferItemsByWeight(list, dest)
            else
                for _, item in ipairs(list) do
                    ISTimedActionQueue.add(ISInventoryTransferUtil.newInventoryTransferAction(player, item, item:getContainer(), dest))
                end
            end
        end
    end)
end

-- Resolve the globally selected loot destination for an item. Returns the
-- container plus its display label; third return is true when the selected bag
-- still exists but can't accept this item. Returns nil when no bag is selected
-- or it is no longer equipped.
local function resolveTakeDest(player, item)
    if not player or not lootDestContainer then return nil end
    for _, dest in ipairs(getTakeDestinations(player, item)) do
        if dest.container == lootDestContainer then
            return dest.container, dest.label, false
        end
    end
    for _, dest in ipairs(getTakeDestinations(player, nil)) do
        if dest.container == lootDestContainer then
            return nil, nil, true
        end
    end
    return nil, nil, false
end

local function takeTargeted(player, item)
    local options = ProjectViewpointQOLOptions or {}
    if options.enableTakeChooser == false then return false end

    local dest, _, unavailable = resolveTakeDest(player, item)
    local mainInv = player:getInventory()
    if dest and dest ~= mainInv then
        takeItemTo(player, item, dest)
    else
        takeItemTo(player, item, mainInv)
        if lootDestContainer and lootDestContainer ~= mainInv and not unavailable then
            lootDestContainer = nil
        end
    end
    return true
end

local function takeAllTargeted(player, items)
    local options = ProjectViewpointQOLOptions or {}
    if options.enableTakeChooser == false then return false end

    local sample = nil
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item and not (isForceDropHeavyItem and isForceDropHeavyItem(item)) then
            sample = item
            break
        end
    end

    local dest, _, unavailable = resolveTakeDest(player, sample)
    local mainInv = player:getInventory()
    if dest and dest ~= mainInv then
        takeAllTo(player, items, dest, shouldSkipTakeAll)
    else
        takeAllTo(player, items, mainInv, shouldSkipTakeAll)
        if lootDestContainer and lootDestContainer ~= mainInv and not unavailable then
            lootDestContainer = nil
        end
    end
    return true
end

-- Open a context menu to choose the global loot destination (inventory or an equipped bag)
local function openLootDestChooser(player)
    if not player or player:isDead() then return end
    local destinations = getTakeDestinations(player, nil)
    if #destinations <= 1 then return end
    if not (ISContextMenu and ISContextMenu.get) then return end

    local playerNum = player:getPlayerNum()
    local menu = ISContextMenu.get(playerNum, getMouseX(), getMouseY())
    local mainInv = player:getInventory()
    for _, dest in ipairs(destinations) do
        local container = dest.container
        local label = dest.label
        if container == mainInv then
            label = getText("ContextMenu_MoveToInventory") or "Inventory"
            if label == "ContextMenu_MoveToInventory" then label = "Inventory" end
        end
        if container == lootDestContainer or (not lootDestContainer and container == mainInv) then
            label = label .. " (current)"
        end
        menu:addOption(label, player, function()
            lootDestContainer = container
            ProjectViewpointQOL.hintDirty = true
        end)
    end
    activeChooserMenu = menu
    local b = bridge()
    if b and b.unlockMouse then b.unlockMouse() end
    unlockedByMod = true
end

-- Viewpoint's own "Show the loot menu" option object (PZAPI), if available
local function getViewpointLootOption()
    if not (PZAPI and PZAPI.ModOptions and PZAPI.ModOptions.getOptions) then return nil end
    local page = PZAPI.ModOptions:getOptions("Viewpoint")
    if not (page and page.getOption) then return nil end
    return page:getOption("lootMenu")
end

-- Hide/show Viewpoint's crosshair loot menu and keep its Mod Options checkbox in sync
local function toggleLootMenu(player)
    if not (Viewpoint and Viewpoint.Loot and Viewpoint.Loot.setEnabled) then return end

    local option = getViewpointLootOption()
    local enabled = nil
    if option and option.getValue then
        enabled = option:getValue()
    end
    if enabled == nil then
        enabled = ProjectViewpointQOL.lootMenuEnabled
    end
    if enabled == nil then
        enabled = true
    end
    enabled = not enabled

    Viewpoint.Loot.setEnabled(enabled)
    if option and option.setValue then
        option:setValue(enabled)
    end
    ProjectViewpointQOL.lootMenuEnabled = enabled

    if enabled then
        ProjectViewpointQOL.notify(player, "Loot menu: ON", "good")
    else
        ProjectViewpointQOL.notify(player, "Loot menu: OFF", "bad")
    end
end

-- Send the player's inventory into the open loot window's container, or into
-- the container being aimed at with Viewpoint's crosshair.
local function storeAllToContainer(player)
    if not player or player:isDead() then return end
    local playerNum = player:getPlayerNum()
    local playerInv = player:getInventory()
    if not playerInv then return end

    local dest = nil
    local lootInv = getLootInv()
    if lootInv and lootInv.getIsVisible and lootInv:getIsVisible() and lootInv.inventory then
        dest = lootInv.inventory
    else
        local b = bridge()
        local item = b and b.getTargetedItem and b.getTargetedItem() or nil
        if item and item.getContainer then
            dest = item:getContainer()
        end
    end
    if not dest or dest == playerInv then return end

    -- Loot window open on this container: use the vanilla transfer (it already
    -- protects equipped items, key rings, hotbar items, favorites and moveables)
    if lootInv and lootInv.inventory == dest and playerInv.transferAll then
        pcall(function() playerInv:transferAll() end)
        return
    end

    local hotbar = getPlayerHotbar and getPlayerHotbar(playerNum)
    local toFloor = dest.getType and dest:getType() == "floor"
    local list = {}
    local it = playerInv:getItems()
    for i = 0, it:size() - 1 do
        local item = it:get(i)
        if item then
            local ok = not item:isEquipped()
                and not (hotbar and hotbar.isInHotbar and hotbar:isInHotbar(item))
                and not (item.isFavorite and item:isFavorite())
                and not shouldSkipTakeAll(item, player)
            if ok and toFloor and instanceof and instanceof(item, "Moveable")
               and item.getSpriteGrid and item:getSpriteGrid() == nil
               and item.CanBeDroppedOnFloor and not item:CanBeDroppedOnFloor() then
                ok = false
            end
            if ok then
                table.insert(list, item)
            end
        end
    end
    if #list == 0 then return end

    withoutProgressBar(function()
        if luautils and luautils.walkToContainer and not luautils.walkToContainer(dest, playerNum) then
            return
        end
        local invPage = getPlayerInv()
        if invPage and invPage.inventoryPane and invPage.inventoryPane.transferItemsByWeight then
            invPage.inventoryPane:transferItemsByWeight(list, dest)
        else
            for _, item in ipairs(list) do
                ISTimedActionQueue.add(ISInventoryTransferUtil.newInventoryTransferAction(player, item, item:getContainer(), dest))
            end
        end
    end)
end

-- Viewpoint's LootRows.title() calls ItemContainer.getCustomName(), which in PZ
-- dereferences getParent() without a null check. Containers without an IsoObject
-- parent or vehicle part (bags, the floor, ProximityInventory's synthetic
-- "local"/"proxInv" containers, other mods' virtual containers) therefore throw
-- a NullPointerException and permanently disable Viewpoint's loot menu. Only
-- hand Viewpoint containers it can actually display.
function ProjectViewpointQOL.isSafeLootContainer(container)
    if not container then return false end
    if container.getParent and container:getParent() ~= nil then return true end
    if container.getVehiclePart and container:getVehiclePart() ~= nil then return true end
    return false
end

-- Containers within reach, mirroring the vanilla loot window's 3x3 scan
function ProjectViewpointQOL.collectNearbyContainers(player)
    local list = {}
    if not player then return list end
    local seen = {}
    local playerInv = player:getInventory()
    local floor = nil
    if ISInventoryPage and ISInventoryPage.GetFloorContainer then
        floor = ISInventoryPage.GetFloorContainer(player:getPlayerNum())
    end
    local function add(container)
        if not container or container == playerInv or container == floor or seen[container] then return end
        if not ProjectViewpointQOL.isSafeLootContainer(container) then return end
        seen[container] = true
        table.insert(list, container)
    end

    local px = math.floor(player:getX())
    local py = math.floor(player:getY())
    local pz = math.floor(player:getZ())
    local cell = getCell()
    local vehiclesSeen = {}
    for dy = -1, 1 do
        for dx = -1, 1 do
            local square = cell:getGridSquare(px + dx, py + dy, pz)
            if square then
                local sobs = square:getStaticMovingObjects()
                if sobs then
                    for i = 0, sobs:size() - 1 do
                        local so = sobs:get(i)
                        if so and so.getContainer then add(so:getContainer()) end
                    end
                end
                local objs = square:getObjects()
                if objs then
                    for i = 0, objs:size() - 1 do
                        local o = objs:get(i)
                        local count = o.getContainerCount and o:getContainerCount() or 0
                        for ci = 0, count - 1 do
                            local c = o:getContainerByIndex(ci)
                            if c then
                                add(c)
                                local items = c:getItems()
                                for ii = 0, items:size() - 1 do
                                    local it = items:get(ii)
                                    if it.getCategory and it:getCategory() == "Container" and it.getInventory then
                                        add(it:getInventory())
                                    end
                                end
                            end
                        end
                    end
                end
                local vehicle = square:getVehicleContainer()
                if vehicle and not vehiclesSeen[vehicle] then
                    vehiclesSeen[vehicle] = true
                    local partCount = vehicle.getPartCount and vehicle:getPartCount() or 0
                    for pi = 0, partCount - 1 do
                        local part = vehicle:getPartByIndex(pi)
                        if part and part.getItemContainer and vehicle.canAccessContainer and vehicle:canAccessContainer(pi, player) then
                            local c = part:getItemContainer()
                            if c then
                                add(c)
                                if part.getId and part:getId() ~= "GloveBox" then
                                    local items = c:getItems()
                                    for ii = 0, items:size() - 1 do
                                        local it = items:get(ii)
                                        if it.getCategory and it:getCategory() == "Container" and it.getInventory then
                                            add(it:getInventory())
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return list
end

-- Toggle the crosshair menu between the aimed container and every nearby one
function ProjectViewpointQOL.toggleAllContainers(player)
    if not player or player:isDead() then return end
    local api = ViewpointQOLContainers
    if not (api and api.isAvailable and api.isAvailable()) then return end
    if api.isActive and api.isActive() then
        api.clear()
        ProjectViewpointQOL.containersList = nil
        ProjectViewpointQOL.containersLastSquare = nil
        ProjectViewpointQOL.containersLastVehicle = nil
        ProjectViewpointQOL.containersListStale = false
        return
    end
    local b = bridge()
    if not (b and b.isLootShown and b.isLootShown()) then return end
    local list = ProjectViewpointQOL.collectNearbyContainers(player)
    if #list == 0 then return end
    local aimed = b.getTargetedItem and b.getTargetedItem()
    local aimedContainer = aimed and aimed.getContainer and aimed:getContainer() or nil
    if aimedContainer then
        for i, c in ipairs(list) do
            if c == aimedContainer then
                table.remove(list, i)
                table.insert(list, 1, aimedContainer)
                break
            end
        end
    end
    ProjectViewpointQOL.containersList = list
    ProjectViewpointQOL.containersLastSquare = player.getCurrentSquare and player:getCurrentSquare() or nil
    ProjectViewpointQOL.containersLastVehicle = player.getVehicle and player:getVehicle() or nil
    ProjectViewpointQOL.containersListStale = false
    api.begin()
    for _, c in ipairs(list) do
        api.addContainer(c)
    end
    api.setActive(true)
    print("[ProjectViewpointQOL] All containers: " .. tostring(#list))
end

local function getEquipSuffix(kind, key, hasExtras)
    if cachedEquipSuffix and cachedEquipSuffixKey == key and cachedEquipSuffixKind == kind and cachedEquipSuffixExtras == hasExtras then
        return cachedEquipSuffix
    end
    local keyText = getKeyName(key) or "G"
    local actionWord = nil
    if kind == "heavy" then
        actionWord = getText("ContextMenu_Grab_Corpse")
        if not actionWord or actionWord == "ContextMenu_Grab_Corpse" then actionWord = "Grab" end
    else
        actionWord = getText("ContextMenu_Equip")
        if not actionWord or actionWord == "ContextMenu_Equip" then actionWord = "Equip" end
    end
    cachedEquipSuffix = "[" .. keyText .. "] " .. actionWord .. (hasExtras and "..." or "")
    cachedEquipSuffixKey = key
    cachedEquipSuffixKind = kind
    cachedEquipSuffixExtras = hasExtras
    return cachedEquipSuffix
end

-- ====================================================================
-- Feature 2b: Container Eat Detection & Execution
-- ====================================================================

local function checkEdibleRaw(item, player)
    if player:isDead() then return false end

    -- Check if player is already full/stuffed (moodle level 3 = Very Full, 4 = Gorged)
    if player.getMoodles and player:getMoodles():getMoodleLevel(MoodleType.FOOD_EATEN) >= 3 then
        return false
    end

    -- Check if item is food
    local isFood = (item.IsFood and item:IsFood()) or
                   (item.getCategory and item:getCategory() == "Food") or
                   (instanceof and instanceof(item, "Food"))
    if not isFood then return false end

    -- Check can opening recipe if item cannot be eaten directly
    local scriptItem = item.getScriptItem and item:getScriptItem()
    local openingRecipe = nil
    if scriptItem and scriptItem.getOpeningRecipe and scriptItem:getOpeningRecipe() then
        local rName = scriptItem:getOpeningRecipe()
        if getScriptManager and getScriptManager():getCraftRecipe(rName) then
            openingRecipe = getScriptManager():getCraftRecipe(rName)
            if ISInventoryPaneContextMenu and ISInventoryPaneContextMenu.getContainers and HandcraftLogic then
                local containers = ISInventoryPaneContextMenu.getContainers(player)
                local logic = HandcraftLogic.new(player, nil, nil)
                logic:setContainers(containers)
                logic:setRecipeFromContextClick(openingRecipe, item)
                if not logic:canPerformCurrentRecipe() then
                    openingRecipe = nil
                end
            end
        end
    end

    if scriptItem and scriptItem.isCantEat and scriptItem:isCantEat() and not openingRecipe then
        return false
    end

    -- Determine if it can be halved / quartered
    local canHalve = false
    local canQuarter = false
    if openingRecipe then
        canHalve = true
        canQuarter = true
    elseif item.getBaseHunger and item.getHungChange then
        local hungerChange = math.abs((item:getHungChange() * 100)) + 0.001
        local baseHunger = math.abs((item:getBaseHunger() * 100)) + 0.001
        canHalve = (hungerChange >= 2) and (hungerChange >= baseHunger / 2)
        canQuarter = (hungerChange >= 4) and (hungerChange >= baseHunger / 4)
    end

    return true, canHalve, canQuarter, openingRecipe
end

local function isEdible(item, player)
    if not item or not player then return false end
    local ok, edible, canHalve, canQuarter, recipe = pcall(checkEdibleRaw, item, player)
    if ok and edible then
        return true, canHalve, canQuarter, recipe
    end
    return false, false, false, nil
end

local function eatTargetedItem(item, player, percentage)
    if not item or not player or player:isDead() then return end
    local playerNum = player:getPlayerNum()

    -- 1. Floor item handling
    if item:getWorldItem() ~= nil then
        local floor = ISInventoryPage.GetFloorContainer(playerNum)
        if floor and not floor:contains(item) then
            floor:AddItem(item)
        end
    end

    -- 2. Walk to container if necessary
    local container = item:getContainer()
    if container and luautils and luautils.walkToContainer and not luautils.walkToContainer(container, playerNum) then
        return
    end

    -- 3. Check opening recipe if canned food
    local openingRecipe = nil
    local eatPercentage = math.floor(percentage * 100 + 0.5)
    local scriptItem = item.getScriptItem and item:getScriptItem()
    if scriptItem and scriptItem.getOpeningRecipe and scriptItem:getOpeningRecipe() then
        local rName = scriptItem:getOpeningRecipe()
        if getScriptManager and getScriptManager():getCraftRecipe(rName) then
            openingRecipe = getScriptManager():getCraftRecipe(rName)
        end
    end

    -- 4. Call vanilla PZ eat action
    ISInventoryPaneContextMenu.eatItem(item, percentage, playerNum, openingRecipe, eatPercentage)
end

local function getEatAllSuffix(key)
    if cachedEatAllSuffix and cachedEatAllSuffixKey == key then
        return cachedEatAllSuffix
    end
    local keyText = getKeyName(key) or "H"
    local eatWord = getText("ContextMenu_Eat")
    if not eatWord or eatWord == "ContextMenu_Eat" then eatWord = "Eat" end
    cachedEatAllSuffix = "[" .. keyText .. "] " .. eatWord .. "..."
    cachedEatAllSuffixKey = key
    return cachedEatAllSuffix
end

-- ====================================================================
-- Feature 2c: Container Drink Detection & Execution
-- ====================================================================

local function checkDrinkableRaw(item, player)
    if player:isDead() then return false end

    -- Check if item has a fluid container
    local fc = item.getFluidContainer and item:getFluidContainer()
    if not fc or fc:isEmpty() or fc:getAmount() <= 0.001 then
        return false
    end

    -- Vanilla PZ limits direct drinking from containers to <= 3.0 liters (e.g. bottles, cans, mugs, boxes)
    if fc.getCapacity and fc:getCapacity() > 3.0 then
        return false
    end

    -- Check primary fluid
    local fluid = fc.getPrimaryFluid and fc:getPrimaryFluid()
    if not fluid then return false end

    local isDrink = false
    if FluidCategory and fluid.isCategory and fluid:isCategory(FluidCategory.Beverage) then
        isDrink = true
    elseif item.isWaterSource and item:isWaterSource() then
        isDrink = true
    end

    if not isDrink then return false end

    -- Check if player is already full/stuffed (only applies if fluid has hunger value, e.g. milk, juice, soup)
    if player.getMoodles and player:getMoodles():getMoodleLevel(MoodleType.FOOD_EATEN) >= 3 then
        local props = fc.getProperties and fc:getProperties()
        if props and props.getHungerChange and props:getHungerChange() ~= 0 then
            return false
        end
    end

    -- Check sealed opening recipe if applicable
    local openingRecipe = nil
    if item.isSealed and item:isSealed() then
        local rName = item.getOpeningRecipe and item:getOpeningRecipe()
        if rName and getScriptManager and getScriptManager():getCraftRecipe(rName) then
            openingRecipe = getScriptManager():getCraftRecipe(rName)
            if ISInventoryPaneContextMenu and ISInventoryPaneContextMenu.getContainers and HandcraftLogic then
                local containers = ISInventoryPaneContextMenu.getContainers(player)
                local logic = HandcraftLogic.new(player, nil, nil)
                logic:setContainers(containers)
                logic:setRecipeFromContextClick(openingRecipe, item)
                if not logic:canPerformCurrentRecipe() then
                    openingRecipe = nil
                end
            end
        end
        if not openingRecipe and not fc:canPlayerEmpty() then
            return false
        end
    end

    -- Determine if beverage can be halved / quartered
    local capacity = fc:getCapacity()
    local amount = fc:getAmount()
    local canHalve = false
    local canQuarter = false
    if capacity and capacity > 0 and amount then
        canHalve = (amount / capacity >= 0.5)
        canQuarter = (amount / capacity >= 0.25)
    end

    return true, canHalve, canQuarter, openingRecipe
end

local function isDrinkable(item, player)
    if not item or not player then return false end
    local ok, drinkable, canHalve, canQuarter, recipe = pcall(checkDrinkableRaw, item, player)
    if ok and drinkable then
        return true, canHalve, canQuarter, recipe
    end
    return false, false, false, nil
end

local function drinkTargetedItem(item, player, percentage)
    if not item or not player or player:isDead() then return end
    local playerNum = player:getPlayerNum()

    -- 1. Floor item handling
    if item:getWorldItem() ~= nil then
        local floor = ISInventoryPage.GetFloorContainer(playerNum)
        if floor and not floor:contains(item) then
            floor:AddItem(item)
        end
    end

    -- 2. Walk to container if necessary
    local container = item:getContainer()
    if container and luautils and luautils.walkToContainer and not luautils.walkToContainer(container, playerNum) then
        return
    end

    -- 3. Check opening recipe if sealed
    local openingRecipe = nil
    if item.isSealed and item:isSealed() and item.getOpeningRecipe and item:getOpeningRecipe() then
        local rName = item:getOpeningRecipe()
        if getScriptManager and getScriptManager():getCraftRecipe(rName) then
            openingRecipe = getScriptManager():getCraftRecipe(rName)
        end
    end

    -- 4. Call vanilla PZ drink handler
    if ISInventoryPaneContextMenu and ISInventoryPaneContextMenu.onDrinkFluid then
        ISInventoryPaneContextMenu.onDrinkFluid(item, percentage, player, openingRecipe, item)
    elseif ISTimedActionQueue and ISDrinkFluidAction then
        ISInventoryPaneContextMenu.transferIfNeeded(player, item)
        ISTimedActionQueue.add(ISDrinkFluidAction:new(player, item, percentage))
    end
end

-- Portion chooser for food/drink: All, Half, Quarter (when the item/fluid allows)
local function openEatPortionChooser(item, player, kind, canHalve, canQuarter)
    if not item or not player or player:isDead() then return end

    local function consume(portion)
        if kind == "drink" then
            drinkTargetedItem(item, player, portion)
        else
            eatTargetedItem(item, player, portion)
        end
    end

    if not (ISContextMenu and ISContextMenu.get) then
        consume(1.0)
        return
    end

    local playerNum = player:getPlayerNum()
    local menu = ISContextMenu.get(playerNum, getMouseX(), getMouseY())
    local function addPortion(textKey, fallback, portion)
        local label = getText(textKey)
        if not label or label == textKey then label = fallback end
        menu:addOption(label, item, function()
            consume(portion)
        end)
    end
    addPortion("ContextMenu_Eat_All", "All", 1.0)
    if canHalve then addPortion("ContextMenu_Eat_Half", "1/2", 0.5) end
    if canQuarter then addPortion("ContextMenu_Eat_Quarter", "1/4", 0.25) end

    activeChooserMenu = menu
    local b = bridge()
    if b and b.unlockMouse then b.unlockMouse() end
    unlockedByMod = true
end

local function getDrinkAllSuffix(key)
    if cachedDrinkAllSuffix and cachedDrinkAllSuffixKey == key then
        return cachedDrinkAllSuffix
    end
    local keyText = getKeyName(key) or "H"
    local drinkWord = getText("ContextMenu_Drink")
    if not drinkWord or drinkWord == "ContextMenu_Drink" then drinkWord = "Drink" end
    cachedDrinkAllSuffix = "[" .. keyText .. "] " .. drinkWord .. "..."
    cachedDrinkAllSuffixKey = key
    return cachedDrinkAllSuffix
end

-- ====================================================================
-- Feature 2d: Container Pill Detection & Execution
-- ====================================================================

local function checkPillRaw(item, player)
    if player:isDead() then return false end
    if not item then return false end

    -- Check if item is pills / medicine
    local isPillItem = false
    if ItemTag and ItemTag.PILLS and item.hasTag and item:hasTag(ItemTag.PILLS) then
        isPillItem = true
    elseif ItemTag and ItemTag.CONSUMABLE and item.hasTag and item:hasTag(ItemTag.CONSUMABLE) and (instanceof and instanceof(item, "DrainableComboItem")) then
        isPillItem = true
    elseif item.getCustomMenuOption and item:getCustomMenuOption() == getText("ContextMenu_Take_pills") then
        isPillItem = true
    else
        local itemType = item.getType and item:getType() or ""
        if string.find(itemType, "Pills") or itemType == "Antibiotics" or itemType == "Vitamins" or itemType == "Painkillers" or itemType == "BetaBlockers" or itemType == "SleepingTablets" or itemType == "Antidepressants" then
            isPillItem = true
        end
    end

    if not isPillItem then return false end

    -- If drainable, ensure it has remaining uses
    if item.getRemainingUses and item:getRemainingUses() <= 0 then
        return false
    end
    if item.getCurrentUses and item:getCurrentUses() <= 0 then
        return false
    end

    return true
end

local function isPill(item, player)
    if not item or not player then return false end
    local ok, pill = pcall(checkPillRaw, item, player)
    return ok and pill == true
end

local function takePillTargetedItem(item, player)
    if not item or not player or player:isDead() then return end
    local playerNum = player:getPlayerNum()

    -- 1. Floor item handling
    if item:getWorldItem() ~= nil then
        local floor = ISInventoryPage.GetFloorContainer(playerNum)
        if floor and not floor:contains(item) then
            floor:AddItem(item)
        end
    end

    -- 2. Walk to container if necessary
    local container = item:getContainer()
    if container and luautils and luautils.walkToContainer and not luautils.walkToContainer(container, playerNum) then
        return
    end

    -- 3. Call vanilla PZ takePill
    if ISInventoryPaneContextMenu and ISInventoryPaneContextMenu.takePill then
        ISInventoryPaneContextMenu.takePill(item, playerNum)
    end
end

local function getPillSuffix(key)
    if cachedPillSuffix and cachedPillSuffixKey == key then
        return cachedPillSuffix
    end
    local keyText = getKeyName(key) or "H"
    local pillWord = getText("ContextMenu_Take_pills")
    if not pillWord or pillWord == "ContextMenu_Take_pills" then pillWord = "Take Pill" end
    cachedPillSuffix = "[" .. keyText .. "] " .. pillWord
    cachedPillSuffixKey = key
    return cachedPillSuffix
end

-- ====================================================================
-- Feature 2e: Container Cigarette / Smokable Detection & Execution
-- ====================================================================

local function predicateNotEmpty(item)
    if not item then return false end
    if item.getCurrentUsesFloat then
        return item:getCurrentUsesFloat() > 0
    end
    if item.getDrainableUsesFloat then
        return item:getDrainableUsesFloat() > 0
    end
    return true
end

local function checkSmokableRaw(item, player)
    if player:isDead() then return false end
    if not item then return false end

    local isSmokableItem = (ItemTag and ItemTag.SMOKABLE and item.hasTag and item:hasTag(ItemTag.SMOKABLE)) or
                           (item.getCustomMenuOption and item:getCustomMenuOption() == "Smoke") or
                           (item.getType and item:getType() == "Cigarettes")

    if not isSmokableItem then return false end

    -- Check if player has open flame / lighter / matches / vehicle lighter
    if player.getVehicle and player:getVehicle() and player:getVehicle().canLightSmoke and player:getVehicle():canLightSmoke(player) then
        return true
    end

    if ISInventoryPaneContextMenu and ISInventoryPaneContextMenu.hasOpenFlame and ISInventoryPaneContextMenu.hasOpenFlame(player) then
        return true
    end

    if item.getRequireInHandOrInventory and item:getRequireInHandOrInventory() then
        local list = item:getRequireInHandOrInventory()
        for i = 0, list:size() - 1 do
            local reqType = list:get(i)
            local fullType = (moduleDotType and item.getModule) and moduleDotType(item:getModule(), reqType) or reqType
            local ok, hasReq = pcall(function()
                return player.getInventory and player:getInventory():getFirstTypeEvalRecurse(fullType, predicateNotEmpty) ~= nil
            end)
            if ok and hasReq then
                return true
            end
        end
    end

    local inv = player.getInventory and player:getInventory()
    if inv then
        if inv:containsTypeRecurse("Lighter") or inv:containsTypeRecurse("Matches") then
            return true
        end
    end

    return false
end

local function isSmokable(item, player)
    if not item or not player then return false end
    local ok, smokable = pcall(checkSmokableRaw, item, player)
    return ok and smokable == true
end

local function smokeTargetedItem(item, player)
    if not item or not player or player:isDead() then return end
    local playerNum = player:getPlayerNum()

    -- 1. Floor item handling
    if item:getWorldItem() ~= nil then
        local floor = ISInventoryPage.GetFloorContainer(playerNum)
        if floor and not floor:contains(item) then
            floor:AddItem(item)
        end
    end

    -- 2. Walk to container if necessary
    local container = item:getContainer()
    if container and luautils and luautils.walkToContainer and not luautils.walkToContainer(container, playerNum) then
        return
    end

    -- 3. Call vanilla PZ eat/smoke handler
    ISInventoryPaneContextMenu.eatItem(item, 1.0, playerNum, nil, 100)
end

local function getSmokeSuffix(key)
    if cachedSmokeSuffix and cachedSmokeSuffixKey == key then
        return cachedSmokeSuffix
    end
    local keyText = getKeyName(key) or "H"
    local smokeWord = getText("ContextMenu_Smoke")
    if not smokeWord or smokeWord == "ContextMenu_Smoke" then smokeWord = "Smoke" end
    cachedSmokeSuffix = "[" .. keyText .. "] " .. smokeWord
    cachedSmokeSuffixKey = key
    return cachedSmokeSuffix
end

-- ====================================================================
-- Feature 2f: Container Literature Reading Detection & Execution
-- ====================================================================

local function checkReadableRaw(item, player)
    if player:isDead() then return false end
    if not item then return false end

    -- Check if item is literature or can be read
    local canRead = false
    if item.canBeRead and item:canBeRead() then
        canRead = true
    elseif instanceof and instanceof(item, "Literature") then
        canRead = true
    elseif item.getNumberOfPages and item:getNumberOfPages() > 0 then
        canRead = true
    end

    if not canRead then return false end

    -- Too dark to read
    if player.tooDarkToRead and player:tooDarkToRead() then
        return false
    end

    -- Illiterate trait check (can only read picture books)
    if CharacterTrait and CharacterTrait.ILLITERATE and player.hasTrait and player:hasTrait(CharacterTrait.ILLITERATE) then
        local isPic = (ItemTag and ((ItemTag.PICTUREBOOK and item:hasTag(ItemTag.PICTUREBOOK)) or (ItemTag.PICTURE and item:hasTag(ItemTag.PICTURE))))
        if not isPic then return false end
    end

    -- Skill book requirement check: Don't prompt to read if the skill book is too advanced
    if item.getLvlSkillTrained and item.getSkillTrained and item:getLvlSkillTrained() ~= -1 then
        local skillName = item:getSkillTrained()
        if SkillBook and SkillBook[skillName] and SkillBook[skillName].perk then
            local perk = SkillBook[skillName].perk
            local reqLvl = item:getLvlSkillTrained()
            local currentPerkLvl = player.getPerkLevel and player:getPerkLevel(perk) or 0
            if reqLvl > currentPerkLvl + 1 then
                return false -- Book is too advanced
            end
        end
    end

    -- Skill book already mastered (vanilla "too simple" check)
    if item.getMaxLevelTrained and item.getSkillTrained then
        local maxLvl = item:getMaxLevelTrained()
        local skillName = item:getSkillTrained()
        if maxLvl ~= -1 and SkillBook and SkillBook[skillName] and SkillBook[skillName].perk then
            local currentPerkLvl = player.getPerkLevel and player:getPerkLevel(SkillBook[skillName].perk) or 0
            if maxLvl <= currentPerkLvl then
                return false
            end
        end
    end

    -- Uninteresting tag check
    if ItemTag and ItemTag.UNINTERESTING and item.hasTag and item:hasTag(ItemTag.UNINTERESTING) then
        return false
    end

    return true
end

local function isReadable(item, player)
    if not item or not player then return false end
    local ok, readable = pcall(checkReadableRaw, item, player)
    return ok and readable == true
end

local function readTargetedItem(item, player)
    if not item or not player or player:isDead() then return end
    local playerNum = player:getPlayerNum()

    -- 1. Floor item handling
    if item:getWorldItem() ~= nil then
        local floor = ISInventoryPage.GetFloorContainer(playerNum)
        if floor and not floor:contains(item) then
            floor:AddItem(item)
        end
    end

    -- 2. Walk to container if necessary
    local container = item:getContainer()
    if container and luautils and luautils.walkToContainer and not luautils.walkToContainer(container, playerNum) then
        return
    end

    -- 3. Call vanilla PZ read handler
    ISInventoryPaneContextMenu.readItem(item, playerNum)
end

local function getReadSuffix(key)
    if cachedReadSuffix and cachedReadSuffixKey == key then
        return cachedReadSuffix
    end
    local keyText = getKeyName(key) or "G"
    local readWord = getText("ContextMenu_Read")
    if not readWord or readWord == "ContextMenu_Read" then readWord = "Read" end
    cachedReadSuffix = "[" .. keyText .. "] " .. readWord
    cachedReadSuffixKey = key
    return cachedReadSuffix
end

-- ====================================================================
-- Feature 2g: Container First-Aid & Bandaging Detection & Execution
-- ====================================================================

local bodyPartUrgency = nil
local function initBodyPartUrgency()
    if bodyPartUrgency then return end
    bodyPartUrgency = {}
    if BodyPartType then
        bodyPartUrgency[BodyPartType.Neck] = 100
        bodyPartUrgency[BodyPartType.Head] = 90
        bodyPartUrgency[BodyPartType.Torso_Upper] = 80
        bodyPartUrgency[BodyPartType.Torso_Lower] = 70
        bodyPartUrgency[BodyPartType.Groin] = 60
        bodyPartUrgency[BodyPartType.UpperArm_L] = 50
        bodyPartUrgency[BodyPartType.UpperArm_R] = 50
        bodyPartUrgency[BodyPartType.ForeArm_L] = 45
        bodyPartUrgency[BodyPartType.ForeArm_R] = 45
        bodyPartUrgency[BodyPartType.Hand_L] = 40
        bodyPartUrgency[BodyPartType.Hand_R] = 40
        bodyPartUrgency[BodyPartType.UpperLeg_L] = 35
        bodyPartUrgency[BodyPartType.UpperLeg_R] = 35
        bodyPartUrgency[BodyPartType.LowerLeg_L] = 30
        bodyPartUrgency[BodyPartType.LowerLeg_R] = 30
        bodyPartUrgency[BodyPartType.Foot_L] = 20
        bodyPartUrgency[BodyPartType.Foot_R] = 20
    end
end

local function hasTagSafe(item, tagName)
    if not item or not tagName then return false end
    if ItemTag and ItemTag[tagName] then
        local ok, res = pcall(function() return item:hasTag(ItemTag[tagName]) end)
        if ok and res then return true end
    end
    if item.getTags then
        local ok, tags = pcall(function() return item:getTags() end)
        if ok and tags and tags.iterator then
            local okIter, it = pcall(function() return tags:iterator() end)
            if okIter and it then
                while it:hasNext() do
                    local t = it:next()
                    if t and (tostring(t) == tagName or (t.toString and t:toString() == tagName)) then
                        return true
                    end
                end
            end
        end
    end
    return false
end

-- Strict bandage check: only items the game itself treats as bandages.
-- Prevents rag clothing (Hat_RagBandana, Gloves_RagWrap, etc.), boxes/kits and
-- hidden model items (Bandage_LeftHand, ...) from being consumed as bandages.
local function isUsableBandageItem(item)
    if not item or not item.getType then return false end

    local okContainer, isContainer = pcall(function() return item:IsInventoryContainer() end)
    if okContainer and isContainer then return false end

    local itemType = item:getType() or ""
    if string.find(itemType, "Box") or string.find(itemType, "Bundle") or string.find(itemType, "Kit") then
        return false
    end

    if item.IsDrainable and item:IsDrainable() then
        local ok, uses = pcall(function() return item:getCurrentUsesFloat() end)
        if ok and uses and uses <= 0 then return false end
    end

    if item.isCanBandage then
        local ok, can = pcall(function() return item:isCanBandage() end)
        if ok and can then return true end
    end
    if item.getBandagePower then
        local ok, power = pcall(function() return item:getBandagePower() end)
        if ok and power and power > 0 then return true end
    end

    return false
end

local function checkFirstAidRaw(item, player)
    if not item or not player or player:isDead() then return nil, nil, nil end

    local bodyDamage = player:getBodyDamage()
    if not bodyDamage then return nil, nil, nil end
    local bodyParts = bodyDamage:getBodyParts()
    if not bodyParts or bodyParts:size() == 0 then return nil, nil, nil end

    initBodyPartUrgency()

    local itemType = item.getType and item:getType() or ""

    -- 1. Sutures: SutureNeedle or Needle + Thread
    local isSuture = false
    local sutureThread = nil

    if itemType == "SutureNeedle" or hasTagSafe(item, "SutureNeedle") then
        isSuture = true
    elseif itemType == "Needle" or hasTagSafe(item, "SEWING_NEEDLE") then
        local inv = player:getInventory()
        if inv and (inv:containsTypeRecurse("Thread") or (ItemTag and ItemTag.THREAD and inv:getFirstTagRecurse(ItemTag.THREAD))) then
            isSuture = true
            sutureThread = inv:getFirstTypeRecurse("Thread") or (ItemTag and ItemTag.THREAD and inv:getFirstTagRecurse(ItemTag.THREAD))
        end
    end

    if isSuture then
        local bestPart = nil
        local bestScore = -1
        for i = 0, bodyParts:size() - 1 do
            local part = bodyParts:get(i)
            if part:isDeepWounded() and not part:stitched() and not part:haveGlass() and not part:bandaged() then
                local score = (bodyPartUrgency and bodyPartUrgency[part:getType()]) or 10
                if score > bestScore then
                    bestScore = score
                    bestPart = part
                end
            end
        end
        if bestPart then
            return "Suture", bestPart, sutureThread
        end
    end

    -- 2. Bandages & Rags: only genuine bandage items (see isUsableBandageItem)
    local isBandageItem = isUsableBandageItem(item)

    if isBandageItem then
        local bestPart = nil
        local bestScore = -1
        for i = 0, bodyParts:size() - 1 do
            local part = bodyParts:get(i)
            if not part:bandaged() then
                local score = 0
                local urgency = (bodyPartUrgency and bodyPartUrgency[part:getType()]) or 10
                local neededLevel = (part.getBandageNeededDamageLevel and part:getBandageNeededDamageLevel()) or 0
                if part:bleeding() then
                    score = 10000 + (urgency * 10)
                elseif part:isDeepWounded() or (part.deepWounded and part:deepWounded()) then
                    score = 5000 + (urgency * 5)
                elseif part:bitten() then
                    score = 3000 + urgency
                elseif part:isCut() or (part.isCut and part:isCut()) then
                    score = 2000 + urgency
                elseif part:scratched() then
                    score = 1000 + urgency
                elseif part:isBurnt() or part:HasInjury() or part:stitched() or neededLevel > 0 then
                    score = 500 + urgency + (neededLevel * 10)
                end
                if score > 0 and score > bestScore then
                    bestScore = score
                    bestPart = part
                end
            end
        end
        if bestPart then
            return "Bandage", bestPart, nil
        end
    end

    -- 3. Disinfectants: FluidContainer with alcohol >= 40% & > 0.15L, drainable alcoholPower == 4.0, or AlcoholWipes
    local isDisinfectant = false
    if item.hasComponent and ComponentType and ComponentType.FluidContainer and item:hasComponent(ComponentType.FluidContainer) then
        local fc = item:getFluidContainer()
        if fc and fc.getProperties and fc.getAmount and (fc:getAmount() > 0.15) then
            local props = fc:getProperties()
            if props and props.getAlcohol and ((props:getAlcohol() / fc:getAmount()) + 0.001 >= 0.4) then
                isDisinfectant = true
            end
        end
    elseif item.IsDrainable and item:IsDrainable() and (item.getAlcoholPower and item:getAlcoholPower() == 4.0) then
        isDisinfectant = true
    elseif itemType == "AlcoholWipes" or hasTagSafe(item, "AlcoholWipes") or (item.getAlcoholPower and item:getAlcoholPower() > 0) then
        isDisinfectant = true
    end

    if isDisinfectant then
        local bestPart = nil
        local bestScore = -1
        for i = 0, bodyParts:size() - 1 do
            local part = bodyParts:get(i)
            if not part:bandaged() and (part:HasInjury() or part:stitched()) then
                local alcLevel = (part.getAlcoholLevel and part:getAlcoholLevel()) or 0
                if alcLevel < 10 or part:isInfectedWound() then
                    local urgency = (bodyPartUrgency and bodyPartUrgency[part:getType()]) or 10
                    local score = (part:isInfectedWound() and 5000 or 1000) + urgency
                    if score > bestScore then
                        bestScore = score
                        bestPart = part
                    end
                end
            end
        end
        if bestPart then
            return "Disinfect", bestPart, nil
        end
    end

    return nil, nil, nil
end

local function isFirstAid(item, player)
    if not item or not player then return nil, nil, nil end
    local ok, faType, faPart, faExtra = pcall(checkFirstAidRaw, item, player)
    if ok and faType then
        return faType, faPart, faExtra
    end
    return nil, nil, nil
end

local function isFirstAidActionPending(player)
    if not player or not ISTimedActionQueue or not ISTimedActionQueue.hasActionType then return false end
    return ISTimedActionQueue.hasActionType(player, "ISApplyBandage") or
           ISTimedActionQueue.hasActionType(player, "ISDisinfect") or
           ISTimedActionQueue.hasActionType(player, "ISStitch")
end

local function findBestFirstAidInInventory(player)
    if not player or player:isDead() then return nil, nil, nil, nil end
    local inv = player:getInventory()
    if not inv then return nil, nil, nil, nil end

    local bodyDamage = player:getBodyDamage()
    if not bodyDamage then return nil, nil, nil, nil end
    local bodyParts = bodyDamage:getBodyParts()
    if not bodyParts or bodyParts:size() == 0 then return nil, nil, nil, nil end

    local hasAnyInjury = false
    for i = 0, bodyParts:size() - 1 do
        local p = bodyParts:get(i)
        -- HasInjury() covers bleeding, deep wounds, bites, cuts, scratches,
        -- burns, fractures and bullets; only stitched is not covered.
        if not p:bandaged() and (p:HasInjury() or p:stitched()) then
            hasAnyInjury = true
            break
        end
    end
    if not hasAnyInjury then return nil, nil, nil, nil end

    local bestActionType = nil
    local bestItem = nil
    local bestPart = nil
    local bestExtra = nil
    local highestPriority = -1

    -- Evaluate inline (no candidate table) to avoid per-scan allocations.
    local function evaluate(itm)
        if not itm then return end
        local faType, faPart, faExtra = isFirstAid(itm, player)
        if not (faType and faPart) then return end
        local priority = 0
        local partType = faPart:getType()
        local urgency = (bodyPartUrgency and bodyPartUrgency[partType]) or 10

        if faPart:bleeding() then
            priority = 100000 + (urgency * 10)
        elseif faPart:isDeepWounded() or (faPart.deepWounded and faPart:deepWounded()) then
            if faType == "Suture" then
                priority = 80000 + (urgency * 10)
            else
                priority = 50000 + (urgency * 5)
            end
        elseif faPart:bitten() then
            priority = 30000 + urgency
        elseif faPart:isCut() or (faPart.isCut and faPart:isCut()) then
            priority = 20000 + urgency
        elseif faPart:scratched() then
            priority = 10000 + urgency
        elseif faPart:isInfectedWound() and faType == "Disinfect" then
            priority = 15000 + urgency
        else
            priority = 5000 + urgency
        end

        local itmType = itm.getType and itm:getType() or ""
        if string.find(itmType, "Alcohol") or string.find(itmType, "Sterilized") then
            priority = priority + 500
        elseif string.find(itmType, "Dirty") then
            priority = priority - 2000
        end

        if itm:getContainer() == inv then
            priority = priority + 50
        end

        if priority > highestPriority then
            highestPriority = priority
            bestActionType = faType
            bestItem = itm
            bestPart = faPart
            bestExtra = faExtra
        end
    end

    local items = inv:getItems()
    if items then
        for i = 0, items:size() - 1 do
            local itm = items:get(i)
            evaluate(itm)
            if itm and itm:IsInventoryContainer() and itm:getItemContainer() then
                local subItems = itm:getItemContainer():getItems()
                if subItems then
                    for j = 0, subItems:size() - 1 do
                        evaluate(subItems:get(j))
                    end
                end
            end
        end
    end

    return bestActionType, bestItem, bestPart, bestExtra
end

local PVQOL_FirstAidHUD = ISPanel:derive("PVQOL_FirstAidHUD")
local firstAidHUDInstance = nil

function PVQOL_FirstAidHUD:new()
    local o = ISPanel:new(0, 0, 200, 28)
    setmetatable(o, self)
    self.__index = self
    o.backgroundColor = {r=0.06, g=0.06, b=0.06, a=0.85}
    o.borderColor = {r=0.85, g=0.25, b=0.25, a=0.95}
    o.anchorLeft = false
    o.anchorRight = false
    o.anchorTop = false
    o.anchorBottom = false
    o.visible = false
    o.promptText = ""
    o.wantMouseEvents = false
    return o
end

function PVQOL_FirstAidHUD:initialise()
    ISPanel.initialise(self)
    self.wantMouseEvents = false
    if self.javaObject then
        self.javaObject:setConsumeMouseEvents(false)
    end
end

function PVQOL_FirstAidHUD:onMouseDown(x, y)
    return false
end

function PVQOL_FirstAidHUD:onMouseUp(x, y)
    return false
end

function PVQOL_FirstAidHUD:render()
    if not self:getIsVisible() or not self.promptText or self.promptText == "" then return end

    self:drawRect(0, 0, self.width, self.height, self.backgroundColor.a, self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b)
    self:drawRectBorder(0, 0, self.width, self.height, self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b)

    local font = UIFont.Small
    local tm = getTextManager()
    local textH = tm and tm:getFontHeight(font) or 16
    local textY = math.floor((self.height - textH) / 2)

    self:drawTextCentre(self.promptText, math.floor(self.width / 2) + 1, textY + 1, 0.0, 0.0, 0.0, 0.8, font)
    self:drawTextCentre(self.promptText, math.floor(self.width / 2), textY, 1.0, 0.85, 0.85, 1.0, font)
end

local function initFirstAidHUD(forceRecreate)
    if not UIManager or not UIManager.getUI then return end
    local uiList = UIManager.getUI()

    if firstAidHUDInstance and not forceRecreate then
        if firstAidHUDInstance.javaObject and uiList and uiList:contains(firstAidHUDInstance.javaObject) then
            return
        end
    end

    if firstAidHUDInstance and firstAidHUDInstance.removeFromUIManager then
        pcall(function() firstAidHUDInstance:removeFromUIManager() end)
    end

    firstAidHUDInstance = PVQOL_FirstAidHUD:new()
    firstAidHUDInstance:initialise()
    firstAidHUDInstance:addToUIManager()
    firstAidHUDInstance:setVisible(false)
end

local hudTickCounter = 0
local lastHUDPart = nil
local lastHUDAction = nil
local lastHUDItem = nil

local function updateFirstAidHUD(viewActive, invRaw, radialRaw, deviceRaw)
    local options = ProjectViewpointQOLOptions or {}
    if options.enableFirstAidHotkey == false or options.enableFirstAidHUD == false then
        if firstAidHUDInstance and firstAidHUDInstance:getIsVisible() then
            firstAidHUDInstance:setVisible(false)
        end
        return
    end

    local player = getSpecificPlayer(0)
    if not player or player:isDead() or getGameSpeed() == 0 then
        if firstAidHUDInstance and firstAidHUDInstance:getIsVisible() then
            firstAidHUDInstance:setVisible(false)
        end
        return
    end

    if viewActive == nil then viewActive = isViewpointActive() end
    if not viewActive then
        if firstAidHUDInstance and firstAidHUDInstance:getIsVisible() then
            firstAidHUDInstance:setVisible(false)
        end
        return
    end

    -- Check for an unbandaged injury first: the common uninjured case can hide
    -- and return without the cursor/action/UI work below.
    local bodyDamage = player:getBodyDamage()
    if not bodyDamage then
        if firstAidHUDInstance and firstAidHUDInstance:getIsVisible() then firstAidHUDInstance:setVisible(false) end
        return
    end
    local bodyParts = bodyDamage:getBodyParts()
    if not bodyParts or bodyParts:size() == 0 then
        if firstAidHUDInstance and firstAidHUDInstance:getIsVisible() then firstAidHUDInstance:setVisible(false) end
        return
    end

    local hasAnyInjury = false
    for i = 0, bodyParts:size() - 1 do
        local p = bodyParts:get(i)
        -- HasInjury() covers bleeding, deep wounds, bites, cuts, scratches,
        -- burns, fractures and bullets; only stitched is not covered.
        if not p:bandaged() and (p:HasInjury() or p:stitched()) then
            hasAnyInjury = true
            break
        end
    end

    if not hasAnyInjury then
        ProjectViewpointQOL.faHudHadInjury = false
        lastHUDPart = nil
        lastHUDAction = nil
        lastHUDItem = nil
        if firstAidHUDInstance and firstAidHUDInstance:getIsVisible() then
            firstAidHUDInstance:setVisible(false)
        end
        return
    end

    if invRaw == nil then
        invRaw = isInventoryOpen()
        radialRaw = isRadialMenuOpen()
        deviceRaw = isDeviceOrMenuOpen()
    end
    local wantUnlocked = (options.unlockOnOpen ~= false and invRaw) or
                         (options.unlockOnRadial ~= false and radialRaw) or
                         (options.unlockOnDevice ~= false and deviceRaw)
    if isCursorUnlocked() or wantUnlocked then
        ProjectViewpointQOL.faHudHadInjury = false
        if firstAidHUDInstance and firstAidHUDInstance:getIsVisible() then
            firstAidHUDInstance:setVisible(false)
        end
        return
    end

    if isFirstAidActionPending(player) then
        ProjectViewpointQOL.faHudHadInjury = false
        lastHUDAction = nil
        lastHUDItem = nil
        lastHUDPart = nil
        if firstAidHUDInstance and firstAidHUDInstance:getIsVisible() then
            firstAidHUDInstance:setVisible(false)
        end
        return
    end

    -- Ensure HUD instance is valid and attached to UIManager
    if not firstAidHUDInstance or not firstAidHUDInstance.javaObject or not (UIManager.getUI() and UIManager.getUI():contains(firstAidHUDInstance.javaObject)) then
        initFirstAidHUD(true)
    end
    if not firstAidHUDInstance then return end

    -- Drop cached item if it was consumed or moved out of its container
    if lastHUDItem then
        local lastContainer = lastHUDItem.getContainer and lastHUDItem:getContainer()
        if not lastContainer or (lastContainer.contains and not lastContainer:contains(lastHUDItem)) then
            lastHUDAction = nil
            lastHUDItem = nil
            lastHUDPart = nil
            hudTickCounter = 30
        end
    end

    -- A fresh injury searches immediately; otherwise rescan every 30 updates (3s)
    -- while a valid candidate is cached.
    if not ProjectViewpointQOL.faHudHadInjury then
        ProjectViewpointQOL.faHudHadInjury = true
        hudTickCounter = 30
    end
    hudTickCounter = hudTickCounter + 1
    if hudTickCounter >= 30 then
        hudTickCounter = 0
        local faType, itm, part = findBestFirstAidInInventory(player)
        lastHUDAction = faType
        lastHUDItem = itm
        lastHUDPart = part
    end

    if not (lastHUDAction and lastHUDItem and lastHUDPart) then
        if firstAidHUDInstance:getIsVisible() then
            firstAidHUDInstance:setVisible(false)
        end
        return
    end

    local firstAidKey = options.firstAidKey or ((Keyboard and Keyboard.KEY_U) or 22)
    local keyText = getKeyName(firstAidKey) or "U"

    local actionText = "bandage"
    if lastHUDAction == "Suture" then actionText = "suture"
    elseif lastHUDAction == "Disinfect" then actionText = "disinfect" end

    local partType = lastHUDPart:getType()
    local partLabel = nil
    if BodyPartType and BodyPartType.getDisplayName then
        partLabel = BodyPartType.getDisplayName(partType)
    elseif BodyPartType and BodyPartType.ToStringLabel then
        partLabel = BodyPartType.ToStringLabel(partType)
    end
    if not partLabel or partLabel == "" then
        partLabel = "wound"
    end

    local promptText = "Press [" .. keyText .. "] to " .. actionText .. " " .. partLabel
    firstAidHUDInstance.promptText = promptText

    local font = UIFont.Small
    local tm = getTextManager()
    local textW = tm and tm:MeasureStringX(font, promptText) or 200
    local textH = tm and tm:getFontHeight(font) or 16

    local sw = getCore():getScreenWidth()
    local sh = getCore():getScreenHeight()
    local w = textW + 24
    local h = textH + 10

    local x = math.floor((sw - w) / 2)
    local y = math.floor((sh / 2) + 60)

    firstAidHUDInstance:setX(x)
    firstAidHUDInstance:setY(y)
    firstAidHUDInstance:setWidth(w)
    firstAidHUDInstance:setHeight(h)

    if not firstAidHUDInstance:getIsVisible() then
        firstAidHUDInstance:setVisible(true)
    end
end

local function applyFirstAidItem(item, player, targetPart, faType, extraItem)
    if not item or not player or player:isDead() then return end
    if isFirstAidActionPending(player) then return end
    if not faType or not targetPart then
        faType, targetPart, extraItem = isFirstAid(item, player)
    end
    if not faType or not targetPart then return end
    if faType == "Bandage" and not isUsableBandageItem(item) then return end

    local playerNum = player:getPlayerNum()

    -- 1. Floor item handling
    if item:getWorldItem() ~= nil then
        local floor = ISInventoryPage.GetFloorContainer(playerNum)
        if floor and not floor:contains(item) then
            floor:AddItem(item)
        end
    end

    -- 2. Walk to container if necessary
    local container = item:getContainer()
    if not container then return end
    if container.contains and not container:contains(item) then return end
    if container ~= player:getInventory() then
        if luautils and luautils.walkToContainer and not luautils.walkToContainer(container, playerNum) then
            return
        end
    end

    -- 3. Transfer item to player inventory if needed
    if container and container ~= player:getInventory() then
        local transfer = ISInventoryTransferUtil.newInventoryTransferAction(player, item, container, player:getInventory())
        ISTimedActionQueue.add(transfer)
    end

    -- Transfer extra item (e.g. thread) if needed
    if extraItem and extraItem:getContainer() and extraItem:getContainer() ~= player:getInventory() then
        local transferExtra = ISInventoryTransferUtil.newInventoryTransferAction(player, extraItem, extraItem:getContainer(), player:getInventory())
        ISTimedActionQueue.add(transferExtra)
    end

    -- 4. Queue timed action
    pcall(function()
        if faType == "Bandage" and ISApplyBandage then
            ISTimedActionQueue.add(ISApplyBandage:new(player, player, item, targetPart, true))
        elseif faType == "Disinfect" and ISDisinfect then
            ISTimedActionQueue.add(ISDisinfect:new(player, player, item, targetPart))
        elseif faType == "Suture" and ISStitch then
            ISTimedActionQueue.add(ISStitch:new(player, player, extraItem or item, targetPart, true))
        end
    end)

    -- Feedback
    pcall(function()
        if HaloTextHelper and HaloTextHelper.addTextWithArrow then
            local actionWord = "Bandaging"
            if faType == "Disinfect" then actionWord = "Disinfecting"
            elseif faType == "Suture" then actionWord = "Stitching" end
            local partLabel = (BodyPartType and BodyPartType.ToStringLabel and BodyPartType.ToStringLabel(targetPart:getType())) or ""
            local msg = actionWord .. (partLabel ~= "" and (" " .. partLabel) or "") .. "..."
            HaloTextHelper.addTextWithArrow(player, msg, true, 0.35, 0.95, 0.45)
        end
    end)
end

local function getFirstAidSuffix(item, faType, key)
    if cachedFirstAidSuffix and cachedFirstAidSuffixKey == key and cachedFirstAidSuffixType == faType and cachedFirstAidSuffixItem == item then
        return cachedFirstAidSuffix
    end
    local keyText = getKeyName(key) or "U"
    local actionText = "Bandage"
    if faType == "Suture" then
        actionText = getText("ContextMenu_Stitch")
        if not actionText or actionText == "ContextMenu_Stitch" then actionText = "Suture" end
    elseif faType == "Disinfect" then
        actionText = getText("ContextMenu_Disinfect")
        if not actionText or actionText == "ContextMenu_Disinfect" then actionText = "Disinfect" end
    else
        local itemType = item and item.getType and item:getType() or ""
        if itemType == "Bandaid" or (item and hasTagSafe(item, "Bandaid")) then
            actionText = "Band-Aid"
        else
            actionText = getText("ContextMenu_Bandage")
            if not actionText or actionText == "ContextMenu_Bandage" then actionText = "Bandage" end
        end
    end
    cachedFirstAidSuffix = "[" .. keyText .. "] " .. actionText
    cachedFirstAidSuffixKey = key
    cachedFirstAidSuffixType = faType
    cachedFirstAidSuffixItem = item
    return cachedFirstAidSuffix
end

-- ====================================================================
-- Feature 2h: Hands-Free Auto-Walk Engine
-- ====================================================================

local function isMovementKey(key)
    if not key then return false end
    if key == ((Keyboard and Keyboard.KEY_W) or 17) or
       key == ((Keyboard and Keyboard.KEY_A) or 30) or
       key == ((Keyboard and Keyboard.KEY_S) or 31) or
       key == ((Keyboard and Keyboard.KEY_D) or 32) or
       key == ((Keyboard and Keyboard.KEY_SPACE) or 57) or
       key == ((Keyboard and Keyboard.KEY_ESCAPE) or 1) then
        return true
    end
    if getCore() and KeybindId then
        if (KeybindId.FORWARD and getCore():isKey(KeybindId.FORWARD, key)) or
           (KeybindId.BACKWARD and getCore():isKey(KeybindId.BACKWARD, key)) or
           (KeybindId.LEFT and getCore():isKey(KeybindId.LEFT, key)) or
           (KeybindId.RIGHT and getCore():isKey(KeybindId.RIGHT, key)) then
            return true
        end
    end
    return false
end

-- True when a living zombie is within radius tiles of the player (same floor).
-- Uses the engine's nearby-enemy lists so it stays cheap to call every tick.
-- True for NPC companion bodies (Stay With Me and similar mods). They are
-- zombie-bodied and sit in the cell's zombie list, but they are friendly, so
-- the auto-walk/fast-forward zombie slowdown must ignore them. Soft
-- dependency: every check is pcall-guarded and does nothing without the mod.
local function isCompanionBody(z)
    local ok, companion = pcall(function()
        if Bridge ~= nil and Bridge.body == z then return true end
        if z:getVariableBoolean("NotAloneBody") then return true end
        if Bridge ~= nil and type(Bridge.isCompanion) == "function" and Bridge.isCompanion(z) then return true end
        if z:hasModData() then
            local md = z:getModData()
            if type(md) == "table" and md.notAloneBody == true then return true end
        end
        return false
    end)
    return ok and companion == true
end

local function hasZombieNearby(player, radius)
    if not player then return false end

    -- The IsoGameCharacter enemy lists are not populated in B42, so scan the
    -- cell's zombie list instead. The scan is sliced across ticks (150 zombies
    -- per call) so a horde cannot cause one big frame spike; a found result is
    -- published immediately and stays true until a full clear pass completes.
    local cell = player.getCell and player:getCell()
    local list = cell and cell.getZombieList and cell:getZombieList()
    local size = list and list:size() or 0
    if size <= 0 then
        ProjectViewpointQOL.zombieScanIndex = 0
        ProjectViewpointQOL.zombieScanAccum = false
        ProjectViewpointQOL.zombieScanResult = false
        return false
    end

    -- Advance the scan at most every 16 ms: the game tick runs once per frame,
    -- so without this the scan work would scale with the frame rate.
    local now = getTimestampMs()
    if now - (ProjectViewpointQOL.zombieScanAt or 0) < 16 then
        return ProjectViewpointQOL.zombieScanResult == true
    end
    ProjectViewpointQOL.zombieScanAt = now

    local px, py, pz = player:getX(), player:getY(), player:getZ()
    local r2 = radius * radius

    local index = ProjectViewpointQOL.zombieScanIndex or 0
    if index >= size then
        -- A full pass finished: publish its result. When it was clear, give the
        -- secondary enemy lists (used by some mods) one chance to report.
        if ProjectViewpointQOL.zombieScanAccum ~= true then
            local function scan(other)
                if not other then return false end
                for i = 0, other:size() - 1 do
                    local z = other:get(i)
                    if z and not z:isDead() and (not instanceof or instanceof(z, "IsoZombie")) and not isCompanionBody(z) then
                        local dx, dy = z:getX() - px, z:getY() - py
                        if dx * dx + dy * dy <= r2 and math.abs(z:getZ() - pz) < 1.5 then
                            return true
                        end
                    end
                end
                return false
            end
            if (player.getVeryCloseEnemyList and scan(player:getVeryCloseEnemyList())) or
               (player.getLocalRelevantEnemyList and scan(player:getLocalRelevantEnemyList())) then
                ProjectViewpointQOL.zombieScanAccum = true
            end
        end
        ProjectViewpointQOL.zombieScanResult = ProjectViewpointQOL.zombieScanAccum == true
        ProjectViewpointQOL.zombieScanAccum = false
        index = 0
    end

    local found = ProjectViewpointQOL.zombieScanAccum == true
    local stop = index + 150
    if stop > size then stop = size end
    for i = index, stop - 1 do
        local z = list:get(i)
        if z and not z:isDead() and not isCompanionBody(z) then
            local dx, dy = z:getX() - px, z:getY() - py
            if dx * dx + dy * dy <= r2 and math.abs(z:getZ() - pz) < 1.5 then
                found = true
                break
            end
        end
    end
    ProjectViewpointQOL.zombieScanAccum = found
    ProjectViewpointQOL.zombieScanIndex = stop

    if found then
        ProjectViewpointQOL.zombieScanResult = true
        ProjectViewpointQOL.zombieScanIndex = size
        return true
    end
    return ProjectViewpointQOL.zombieScanResult == true
end

local function startAutoWalk(player)
    if not player or player:isDead() or getGameSpeed() == 0 then return end
    if player:isSeatedInVehicle() or player:isAsleep() then return end

    autoWalkActive = true
    autoWalkLastX = player:getX()
    autoWalkLastY = player:getY()
    autoWalkStuckTicks = 0
    ProjectViewpointQOL.autoWalkStuckAt = getTimestampMs() + 250
    autoWalkZombieSlowed = false
    local bd = player:getBodyDamage()
    autoWalkLastHealth = bd and bd:getOverallBodyHealth() or 100

    player:setAutoWalk(true)
    local walkDir = (IsoDirections and IsoDirections.N and IsoDirections.N:ToVector()) or (Vector2 and Vector2.new and Vector2.new(0, -1))
    if walkDir then
        player:setAutoWalkDirection(walkDir)
    end

    ProjectViewpointQOL.notify(player, "Auto-Walk: ON", "good")
end

local function stopAutoWalk(player, showFeedback)
    if not autoWalkActive and (not player or not player:isAutoWalk()) then
        return
    end

    autoWalkActive = false
    autoWalkStuckTicks = 0
    autoWalkZombieSlowed = false

    if player and player.setAutoWalk then
        player:setAutoWalk(false)
    end

    if showFeedback and player and not player:isDead() then
        ProjectViewpointQOL.notify(player, "Auto-Walk: OFF", "bad")
    end
end

local function toggleAutoWalk(player)
    if not player or player:isDead() or getGameSpeed() == 0 then return end
    if autoWalkActive or player:isAutoWalk() then
        stopAutoWalk(player, true)
    else
        startAutoWalk(player)
    end
end

-- Global auto-open: jogging or sprinting into a closed, unlocked door or gate
-- toggles it directly (no walk-adjacent action) so momentum is kept.
local function autoOpenDoorOnContact(player, now)
    local options = ProjectViewpointQOLOptions or {}
    if options.autoOpenDoors == false then return end
    if not player or player:isDead() or getGameSpeed() == 0 then return end
    -- Jogging/sprinting only, like vanilla auto-vaulting (cheapest gate first)
    if not ((player.isRunning and player:isRunning()) or (player.isSprinting and player:isSprinting())) then return end
    if player:isSeatedInVehicle() or player:isAsleep() then return end
    if isCursorUnlocked() then return end
    -- Reuse the 100 ms window-state cache instead of re-running the whole
    -- inventory/radial/device chain every frame while running.
    local cache = ProjectViewpointQOL.uiStateCache
    if cache then
        local uiOptions = ProjectViewpointQOLOptions or {}
        if (uiOptions.unlockOnOpen ~= false and cache[1]) or
           (uiOptions.unlockOnRadial ~= false and cache[2]) or
           (uiOptions.unlockOnDevice ~= false and cache[3]) then
            return
        end
    elseif shouldMouseBeUnlocked() then
        return
    end
    now = now or getTimestampMs()
    if ProjectViewpointQOL.doorAutoUntil and now < ProjectViewpointQOL.doorAutoUntil then return end
    if not player.getContextDoorOrWindowOrWindowFrame or not player.getDir then return end

    local door = player:getContextDoorOrWindowOrWindowFrame(player:getDir())
    if not door then return end
    if not (instanceof(door, "IsoDoor") or (instanceof(door, "IsoThumpable") and door:isDoor())) then return end
    if door.IsOpen and door:IsOpen() then return end
    if door.isBarricaded and door:isBarricaded() then return end
    if door.isLocked and door:isLocked() then return end
    if door.isLockedToCharacter and door:isLockedToCharacter(player) then return end

    -- Only on contact: collision flag, or close to the door's square
    local contact = (player:isLastCollidedN() or player:isLastCollidedW())
    if not contact then
        local dsq = door.getSquare and door:getSquare() or nil
        if dsq then
            local dx = player:getX() - (dsq:getX() + 0.5)
            local dy = player:getY() - (dsq:getY() + 0.5)
            contact = (dx * dx + dy * dy) < 1.2
        end
    end
    if not contact then return end

    ProjectViewpointQOL.doorAutoUntil = now + 500
    pcall(function() door:ToggleDoor(player) end)
end

local function updateAutoWalk(player, invRaw, radialRaw, deviceRaw, now)
    if not autoWalkActive then return end
    now = now or getTimestampMs()

    if not player or player:isDead() or getGameSpeed() == 0 then
        stopAutoWalk(player, false)
        return
    end

    -- 1. Safety disengagement: UI / Menu / Inventory open.
    -- Note: manually freeing the mouse with middle mouse does NOT stop auto-walk.
    if invRaw == nil then
        invRaw = isInventoryOpen()
        radialRaw = isRadialMenuOpen()
        deviceRaw = isDeviceOrMenuOpen()
    end
    local options = ProjectViewpointQOLOptions or {}
    local unlockBlocks = (options.unlockOnOpen ~= false and invRaw) or
                         (options.unlockOnRadial ~= false and radialRaw) or
                         (options.unlockOnDevice ~= false and deviceRaw)
    if unlockBlocks or invRaw or radialRaw or deviceRaw then
        stopAutoWalk(player, true)
        return
    end

    -- 2. Vehicle / Sleep / Fall / Climb disengagement
    if player:isSeatedInVehicle() or player:isAsleep() or (player.isFallOnFront and player:isFallOnFront()) then
        stopAutoWalk(player, true)
        return
    end

    -- 3. Collision disengagement (wall, fence, vehicle, solid obstacle).
    -- The global auto-open door handler runs on its own; collisions still stop auto-walk.
    if player:isLastCollidedN() or player:isLastCollidedW() then
        stopAutoWalk(player, true)
        return
    end

    -- 4. Health / Damage disengagement
    local bd = player:getBodyDamage()
    local currentHealth = bd and bd:getOverallBodyHealth() or 100
    if currentHealth < (autoWalkLastHealth - 0.5) then
        stopAutoWalk(player, true)
        return
    end
    autoWalkLastHealth = currentHealth

    -- 5. Stuck check (every ~250 ms of real time)
    if now - (ProjectViewpointQOL.autoWalkStuckAt or 0) >= 250 then
        ProjectViewpointQOL.autoWalkStuckAt = now
        local curX = player:getX()
        local curY = player:getY()
        local dx = curX - autoWalkLastX
        local dy = curY - autoWalkLastY
        if (dx * dx + dy * dy) < 0.0004 then
            autoWalkStuckTicks = autoWalkStuckTicks + 1
            if autoWalkStuckTicks >= 4 then
                stopAutoWalk(player, true)
                return
            end
        else
            autoWalkStuckTicks = 0
        end
        autoWalkLastX = curX
        autoWalkLastY = curY
    end

    -- 6. Keep engine autoWalk state active
    if not player:isAutoWalk() then
        player:setAutoWalk(true)
        local walkDir = (IsoDirections and IsoDirections.N and IsoDirections.N:ToVector()) or (Vector2 and Vector2.new and Vector2.new(0, -1))
        if walkDir then
            player:setAutoWalkDirection(walkDir)
        end
    end
end

-- Java-side keeper exposed by ZombieBuddy as ViewpointQOLSpeed. The engine
-- (IsoPlayer) resets the speed every frame while walking; SpeedKeeper is
-- patched into IsoPlayer.update and re-applies the desired speed after those
-- resets and before GameTime.update.
function ProjectViewpointQOL.clearSpeedKeeper()
    local sk = ViewpointQOLSpeed
    if sk and sk.reset then
        sk.reset()
    end
end

-- Keeps the player's chosen fast-forward speed alive while moving (vanilla drops
-- back to 1x the moment the player moves without a path), with an optional
-- auto-slow when zombies are near.
function ProjectViewpointQOL.updateFastForwardKeepAlive(player)
    local options = ProjectViewpointQOLOptions or {}
    local sk = ViewpointQOLSpeed

    if not player or player:isDead() then
        autoWalkZombieSlowed = false
        if sk and sk.setEnabled then
            if ProjectViewpointQOL.ffKeepAliveEnabled ~= false then
                ProjectViewpointQOL.ffKeepAliveEnabled = false
                sk.setEnabled(false)
            end
            if sk.setBlocked and ProjectViewpointQOL.ffBlocked ~= true then
                ProjectViewpointQOL.ffBlocked = true
                sk.setBlocked(true)
            end
        end
        return
    end

    local enabled = options.fastForwardKeepAlive ~= false and not isClient() and not isServer()

    if not enabled then
        autoWalkZombieSlowed = false
        if sk and sk.setEnabled and ProjectViewpointQOL.ffKeepAliveEnabled ~= false then
            ProjectViewpointQOL.ffKeepAliveEnabled = false
            sk.setEnabled(false)
            ProjectViewpointQOL.zombieScanResult = false
        end
        return
    end

    if sk and sk.setEnabled and ProjectViewpointQOL.ffKeepAliveEnabled ~= true then
        ProjectViewpointQOL.ffKeepAliveEnabled = true
        sk.setEnabled(true)
        ProjectViewpointQOL.zombieScanAt = 0
        ProjectViewpointQOL.zombieScanIndex = 0
        ProjectViewpointQOL.zombieScanAccum = false
    end

    -- Keep the Java keeper's movement rule in sync with the option: by default
    -- manual movement/Shift cancel fast-forward; the opt-in manual mode keeps it.
    if sk and sk.setManualMoveCancels then
        local keepWhileMoving = options.fastForwardWhileMoving == true
        if ProjectViewpointQOL.ffManualMoveCancels ~= keepWhileMoving then
            ProjectViewpointQOL.ffManualMoveCancels = keepWhileMoving
            sk.setManualMoveCancels(not keepWhileMoving)
        end
    end

    -- Nothing to keep alive (and no movement cancel to detect) while not
    -- fast-forwarding; skip the movement/on-fire/zombie work in that common case.
    local ffIntent
    if sk and sk.getUserSpeed then
        ffIntent = (sk.getUserSpeed() or 0) > 1 or (getGameSpeed() or 0) > 1
    else
        ffIntent = (ProjectViewpointQOL.desiredFastForwardSpeed or 0) > 1 or (getGameSpeed() or 0) > 1
    end
    if not ffIntent and not ProjectViewpointQOL.ffBlocked then
        autoWalkZombieSlowed = false
        return
    end

    -- Vanilla drops fast-forward when the player moves. Manual movement and
    -- Shift/Sprint cancel the keep-alive (auto-walk keeps it), so zombies can
    -- never close in at boosted speed. Mirrors the vanilla condition:
    -- isJustMoved() with no path/pathfinding, excluding auto-walk.
    local manualMove = false
    if player.isJustMoved and player:isJustMoved() then
        local autoWalking = player.isAutoWalk and player:isAutoWalk()
        local pathing = (player.hasPath and player:hasPath()) or (player.isCurrentActionPathfinding and player:isCurrentActionPathfinding())
        if not autoWalking and not pathing then
            manualMove = true
        end
    end
    local running = (player.isRunning and player:isRunning()) or (player.isSprinting and player:isSprinting())
    if (manualMove or running) and options.fastForwardWhileMoving ~= true then
        autoWalkZombieSlowed = false
        ProjectViewpointQOL.desiredFastForwardSpeed = nil
        ProjectViewpointQOL.desiredFastForwardMultiplier = nil
        if sk and sk.setUserSpeed then
            sk.setUserSpeed(1, 1)
        end
        if sk and sk.setBlocked and ProjectViewpointQOL.ffBlocked ~= false then
            ProjectViewpointQOL.ffBlocked = false
            sk.setBlocked(false)
        end
        if getGameSpeed() > 1 then
            setGameSpeed(1)
            if getGameTime then
                getGameTime():setMultiplier(1)
            end
        end
        return
    end

    local blocked = false
    if player:isOnFire() or
       (player.isFallOnFront and player:isFallOnFront()) or
       (player.getFallTime and player:getFallTime() > 0) then
        blocked = true
    end

    -- Only slow down / warn when we were actually fast-forwarding
    local zombieSlowed = false
    local zombieRadius = tonumber(options.autoWalkZombieRadius) or 10
    if not blocked and ffIntent and options.autoWalkZombieSafety ~= false and hasZombieNearby(player, zombieRadius) then
        blocked = true
        zombieSlowed = true
        if not autoWalkZombieSlowed then
            ProjectViewpointQOL.notify(player, "Zombies nearby - slowing down", "bad")
        end
    end
    autoWalkZombieSlowed = zombieSlowed

    if sk and sk.setBlocked then
        if ProjectViewpointQOL.ffBlocked ~= blocked then
            ProjectViewpointQOL.ffBlocked = blocked
            sk.setBlocked(blocked)
        end
        return
    end

    -- Fallback when the ZombieBuddy bridge is unavailable: best-effort re-apply
    -- (the engine still wins while moving, so this only helps while standing).
    if getGameSpeed() > 1 then
        ProjectViewpointQOL.desiredFastForwardSpeed = getGameSpeed()
        ProjectViewpointQOL.desiredFastForwardMultiplier = getGameTime and getGameTime():getTrueMultiplier() or 5
    end

    local desired = ProjectViewpointQOL.desiredFastForwardSpeed
    local desiredMult = ProjectViewpointQOL.desiredFastForwardMultiplier
    if not desired or desired <= 1 then
        autoWalkZombieSlowed = false
        return
    end

    if blocked or getGameSpeed() == 0 or isInventoryOpen() or isRadialMenuOpen() or
       isDeviceOrMenuOpen() or isContextMenuOpen() then
        if blocked and getGameSpeed() > 1 then
            setGameSpeed(1)
            if getGameTime then
                getGameTime():setMultiplier(1)
            end
        end
        return
    end

    if getGameSpeed() ~= desired then
        setGameSpeed(desired)
        if getGameTime then
            getGameTime():setMultiplier(desiredMult or 1)
        end
    end
end

-- ====================================================================
-- Feature 2i: Container Ammunition Unpacking & Magazine Loading
-- ====================================================================

local function getAmmoBoxRecipe(item, player)
    if not item then return nil, nil, nil end

    -- 1. Check doubleClickRecipe
    local dc = item.getDoubleClickRecipe and item:getDoubleClickRecipe()
    if dc and dc ~= "" then
        local sm = getScriptManager and getScriptManager()
        if sm then
            if sm.getCraftRecipe and sm:getCraftRecipe(dc) then
                return sm:getCraftRecipe(dc), "CraftRecipe", dc
            elseif sm.getRecipe and sm:getRecipe(dc) then
                return sm:getRecipe(dc), "Recipe", dc
            end
        end
    end

    -- 2. Check openingRecipe
    local op = item.getOpeningRecipe and item:getOpeningRecipe()
    if op and op ~= "" then
        local sm = getScriptManager and getScriptManager()
        if sm then
            if sm.getCraftRecipe and sm:getCraftRecipe(op) then
                return sm:getCraftRecipe(op), "CraftRecipe", op
            elseif sm.getRecipe and sm:getRecipe(op) then
                return sm:getRecipe(op), "Recipe", op
            end
        end
    end

    -- 3. Check CraftRecipeManager unique recipes for item
    if CraftRecipeManager and CraftRecipeManager.getUniqueRecipeItems and player then
        local containers = ISInventoryPaneContextMenu and ISInventoryPaneContextMenu.getContainers and ISInventoryPaneContextMenu.getContainers(player)
        local recipes = CraftRecipeManager.getUniqueRecipeItems(item, player, containers)
        if recipes and recipes.size then
            for i = 0, recipes:size() - 1 do
                local r = recipes:get(i)
                local name = r.getName and r:getName() or ""
                if string.find(name, "Open") or string.find(name, "Unpack") or string.find(name, "Box") then
                    return r, "CraftRecipe", name
                end
            end
        end
    end

    return nil, nil, nil
end

local function checkAmmoActionRaw(item, player)
    if not item or not player or player:isDead() then return nil, nil, 0, nil, nil end

    local isAmmoCat = (item.getDisplayCategory and item:getDisplayCategory() == "Ammo") or
                      hasTagSafe(item, "Ammo") or hasTagSafe(item, "Bullet") or hasTagSafe(item, "SHOTGUN_SHELL")
    local itemType = item.getType and item:getType() or ""
    if not isAmmoCat then
        if string.find(itemType, "Bullets") or string.find(itemType, "Shells") or
           string.find(itemType, "308") or string.find(itemType, "556") or string.find(itemType, "3030") or
           string.find(itemType, "44Clip") or string.find(itemType, "45Clip") or string.find(itemType, "9mmClip") then
            isAmmoCat = true
        end
    end

    -- 1. Check if item is an ammo box or carton with an opening recipe
    if isAmmoCat or string.find(itemType, "Box") or string.find(itemType, "Carton") then
        local recipe, recipeKind, recipeName = getAmmoBoxRecipe(item, player)
        if recipe then
            local subType = "Box"
            if string.find(itemType, "Carton") or (recipeName and string.find(recipeName, "Carton")) then
                subType = "Carton"
            end
            return "Unpack", recipe, 0, subType, recipeKind
        end
    end

    -- 2. Check if item is an empty/partial magazine in container or on floor
    if item.getMaxAmmo and item:getMaxAmmo() > 0 and not (instanceof and instanceof(item, "HandWeapon")) then
        if item:getCurrentAmmoCount() < item:getMaxAmmo() then
            local ammoType = item:getAmmoType()
            if ammoType then
                local itemKey = ammoType:getItemKey()
                local inv = player:getInventory()
                local count = inv and inv:getItemCountRecurse(itemKey) or 0
                local needed = item:getMaxAmmo() - item:getCurrentAmmoCount()
                local toLoad = math.min(count, needed)
                if toLoad > 0 then
                    return "LoadMag", item, toLoad, "Mag", itemKey
                end
            end
        end
        return nil, nil, 0, nil, nil
    end

    -- 3. Check if item is loose ammo / bullets in container or on floor
    if not (instanceof and instanceof(item, "HandWeapon")) and not (item.getMaxAmmo and item:getMaxAmmo() > 0) then
        local isBullet = isAmmoCat
        if not isBullet then
            if string.find(itemType, "Bullets") or string.find(itemType, "Shells") then
                isBullet = true
            end
        end

        if isBullet then
            local fullType = item:getFullType()
            local inv = player:getInventory()
            if inv then
                -- 3a: Check carried magazine that accepts this ammo
                local bestMag = nil
                local bestMagNeeded = 0
                for i = 0, inv:getItems():size() - 1 do
                    local candidate = inv:getItems():get(i)
                    if candidate:getMaxAmmo() > 0 and not (instanceof and instanceof(candidate, "HandWeapon")) then
                        local mType = candidate:getAmmoType()
                        if mType and mType:getItemKey() == fullType then
                            local needed = candidate:getMaxAmmo() - candidate:getCurrentAmmoCount()
                            if needed > bestMagNeeded then
                                bestMag = candidate
                                bestMagNeeded = needed
                            end
                        end
                    end
                end
                if bestMag and bestMagNeeded > 0 then
                    local container = item:getContainer()
                    local available = container and container:getItemCountRecurse(fullType) or 1
                    local toLoad = math.min(available, bestMagNeeded)
                    return "LoadLooseIntoMag", bestMag, toLoad, "Mag", fullType
                end

                -- 3b: Check equipped direct-feed firearm (shotgun, revolver, internal mag rifle)
                local gun = player:getPrimaryHandItem()
                if not (gun and instanceof and instanceof(gun, "HandWeapon") and gun:isAimedFirearm()) then
                    gun = player:getSecondaryHandItem()
                end
                if gun and instanceof and instanceof(gun, "HandWeapon") and gun:isAimedFirearm() then
                    if not gun:getMagazineType() then
                        local gAmmo = gun:getAmmoType()
                        if gAmmo and gAmmo:getItemKey() == fullType then
                            local gunNeeded = gun:getMaxAmmo() - gun:getCurrentAmmoCount()
                            if gunNeeded > 0 then
                                local container = item:getContainer()
                                local available = container and container:getItemCountRecurse(fullType) or 1
                                local toLoad = math.min(available, gunNeeded)
                                return "LoadLooseIntoGun", gun, toLoad, "Gun", fullType
                            end
                        end
                    end
                end
            end
        end
    end

    return nil, nil, 0, nil, nil
end

local function isAmmoActionable(item, player)
    if not item or not player then return nil, nil, 0, nil, nil end
    local ok, aAction, aTarget, aCount, aSub, aExtra = pcall(checkAmmoActionRaw, item, player)
    if ok and aAction then
        return aAction, aTarget, aCount, aSub, aExtra
    end
    return nil, nil, 0, nil, nil
end

local function executeAmmoTargetedItem(item, player)
    if not item or not player or player:isDead() then return end
    local actionType, target, ammoCount, subType, extra = isAmmoActionable(item, player)
    if not actionType then return end

    local playerNum = player:getPlayerNum()

    -- 1. Floor item handling
    if item:getWorldItem() ~= nil then
        local floor = ISInventoryPage.GetFloorContainer(playerNum)
        if floor and not floor:contains(item) then
            floor:AddItem(item)
        end
    end

    -- 2. Walk to container if necessary
    local container = item:getContainer()
    if container and luautils and luautils.walkToContainer and not luautils.walkToContainer(container, playerNum) then
        return
    end

    -- 3. Execution based on actionType:
    if actionType == "Unpack" then
        if container and container ~= player:getInventory() then
            local transfer = ISInventoryTransferUtil.newInventoryTransferAction(player, item, container, player:getInventory())
            ISTimedActionQueue.add(transfer)
        end
        local recipe = target
        local recipeKind = extra
        if recipeKind == "CraftRecipe" and ISInventoryPaneContextMenu and ISInventoryPaneContextMenu.OnNewCraft then
            ISInventoryPaneContextMenu.OnNewCraft(item, recipe, playerNum)
        elseif ISInventoryPaneContextMenu and ISInventoryPaneContextMenu.OnCraft then
            ISInventoryPaneContextMenu.OnCraft(item, recipe, playerNum)
        elseif ISInventoryPaneContextMenu and ISInventoryPaneContextMenu.OnNewCraft then
            ISInventoryPaneContextMenu.OnNewCraft(item, recipe, playerNum)
        end
        closeCraftingWindowIfOpen()

    elseif actionType == "LoadMag" then
        if container and container ~= player:getInventory() then
            local transfer = ISInventoryTransferUtil.newInventoryTransferAction(player, item, container, player:getInventory())
            ISTimedActionQueue.add(transfer)
        end
        if ISInventoryPaneContextMenu and ISInventoryPaneContextMenu.onLoadBulletsInMagazine then
            ISInventoryPaneContextMenu.onLoadBulletsInMagazine(player, item, ammoCount)
        end

    elseif actionType == "LoadLooseIntoMag" then
        local fullType = extra
        local inv = player:getInventory()
        if container and container ~= inv then
            local bullets = container:getSomeTypeRecurse(fullType, ammoCount)
            if bullets and bullets:size() > 0 then
                for i = 0, bullets:size() - 1 do
                    local bItem = bullets:get(i)
                    local transfer = ISInventoryTransferUtil.newInventoryTransferAction(player, bItem, container, inv)
                    ISTimedActionQueue.add(transfer)
                end
            end
        end
        if ISInventoryPaneContextMenu and ISInventoryPaneContextMenu.onLoadBulletsInMagazine then
            ISInventoryPaneContextMenu.onLoadBulletsInMagazine(player, target, ammoCount)
        end

    elseif actionType == "LoadLooseIntoGun" then
        local fullType = extra
        local inv = player:getInventory()
        if container and container ~= inv then
            local bullets = container:getSomeTypeRecurse(fullType, ammoCount)
            if bullets and bullets:size() > 0 then
                for i = 0, bullets:size() - 1 do
                    local bItem = bullets:get(i)
                    local transfer = ISInventoryTransferUtil.newInventoryTransferAction(player, bItem, container, inv)
                    ISTimedActionQueue.add(transfer)
                end
            end
        end
        if ISInventoryPaneContextMenu and ISInventoryPaneContextMenu.onLoadBulletsIntoFirearm then
            ISInventoryPaneContextMenu.onLoadBulletsIntoFirearm(player, target)
        end
    end
end

local function getAmmoSuffix(actionType, subType, count, key, item)
    if cachedAmmoSuffix and cachedAmmoSuffixKey == key and cachedAmmoSuffixAction == actionType and cachedAmmoSuffixCount == count and cachedAmmoSuffixItem == item then
        return cachedAmmoSuffix
    end
    local keyText = getKeyName(key) or "R"
    local text = "Ammo"
    if actionType == "Unpack" then
        if subType == "Carton" then
            text = "Open Carton"
        else
            text = "Open Box"
        end
    elseif actionType == "LoadMag" or actionType == "LoadLooseIntoMag" then
        if count and count > 0 then
            text = "Load Mag (" .. tostring(count) .. ")"
        else
            text = "Load Mag"
        end
    elseif actionType == "LoadLooseIntoGun" then
        if count and count > 0 then
            text = "Load Gun (" .. tostring(count) .. ")"
        else
            text = "Load Gun"
        end
    end
    cachedAmmoSuffix = "[" .. keyText .. "] " .. text
    cachedAmmoSuffixKey = key
    cachedAmmoSuffixAction = actionType
    cachedAmmoSuffixCount = count
    cachedAmmoSuffixItem = item
    return cachedAmmoSuffix
end

-- ====================================================================
-- Feature 2i: Container Crafting Detection & Execution
-- ====================================================================

local function isItemCraftable(item, player)
    if not item or not player or player:isDead() then return false end

    -- 1. Fast check: PZ Build 42 native isNoRecipes on InventoryItem
    if item.isNoRecipes then
        local ok, noRec = pcall(function() return item:isNoRecipes(player) end)
        if ok and noRec ~= nil then
            return not noRec
        end
    end

    -- 2. Check ScriptItem used in recipes
    local ok1, res1 = pcall(function()
        local si = item.getScriptItem and item:getScriptItem()
        if si and si.getUsedInRecipes then
            local list = si:getUsedInRecipes(player)
            return list and list:size() > 0
        end
        return false
    end)
    if ok1 and res1 then return true end

    -- 3. Check Build 42 CraftRecipeManager with valid containerList
    if CraftRecipeManager and CraftRecipeManager.getUniqueRecipeItems and ISInventoryPaneContextMenu and ISInventoryPaneContextMenu.getContainers then
        local ok2, res2 = pcall(function()
            local containers = ISInventoryPaneContextMenu.getContainers(player)
            if containers then
                local list = CraftRecipeManager.getUniqueRecipeItems(item, player, containers)
                return list and list:size() > 0
            end
            return false
        end)
        if ok2 and res2 then return true end
    end

    return false
end

local function craftTargetedItem(item, player)
    if not item or not player or player:isDead() then return end
    local itemName = (item.getFullName and item:getFullName()) or (item.getName and item:getName()) or ""
    if ISEntityUI and ISEntityUI.OpenHandcraftWindow then
        ISEntityUI.OpenHandcraftWindow(player, nil, "*", false, nil, itemName)
    elseif ISHandcraftWindow and ISHandcraftWindow.openHandcraftWindow then
        ISHandcraftWindow.openHandcraftWindow(player, nil, "*", false, nil, itemName)
    elseif ISEntityUI and ISEntityUI.openHandcraftWindow then
        ISEntityUI.openHandcraftWindow(player)
    end
end

-- Clear a crafting window's stale search/filter text and show all recipes again.
-- Supports both the vanilla ISHandcraftWindow and Neat Crafting's NC_HandcraftWindow.
local function clearHandcraftFilter(win)
    if not win then return end

    -- Neat Crafting's inventory context search ("Used in recipes / Created by
    -- recipes") applies its search while the window is created and marks the
    -- window so its own remembered-search restore skips. Clearing here would
    -- wipe that explicit search; consume the mark so a reused instance is not
    -- permanently exempt from stale-search clearing.
    if win._ncExplicitInitialSearch then
        win._ncExplicitInitialSearch = nil
        return
    end

    -- Neat Crafting UI: window.header.searchComponent (NC_SearchBox)
    local search = win.header and win.header.searchComponent
    if search then
        pcall(function()
            local oldText = search.getSearchText and search:getSearchText() or nil
            if oldText and oldText ~= "" then
                print("[ProjectViewpointQOL] Cleared crafting search text: " .. tostring(oldText))
            end
            if search.setSearchState then
                search:setSearchState("RecipeName", "", true)
            else
                if search.setSearchMode then search:setSearchMode("RecipeName") end
                if search.setSearchText then search:setSearchText("") end
                if search.performSearch then search:performSearch() end
            end
        end)
        return
    end

    -- Vanilla UI
    local panel = win.handCraftPanel
    if not panel then return end
    pcall(function()
        panel._filterString = nil
        panel._filterMode = nil
        local filterPanel = panel.recipesPanel and panel.recipesPanel.recipeFilterPanel
        if filterPanel then
            if filterPanel.searchEntryBox and filterPanel.searchEntryBox.setText then
                local oldText = filterPanel.searchEntryBox.getInternalText and filterPanel.searchEntryBox:getInternalText() or nil
                if oldText and oldText ~= "" then
                    print("[ProjectViewpointQOL] Cleared crafting search text: " .. tostring(oldText))
                end
                filterPanel.searchEntryBox:setText("")
            end
            if filterPanel.filterTypeCombo and filterPanel.filterTypeCombo.setSelected then
                filterPanel.filterTypeCombo:setSelected(1)
            end
        end
        if panel.filterRecipeList then
            panel:filterRecipeList()
        end
    end)
end

-- Clear stale crafting search text whenever the crafting window becomes visible.
-- Neat Crafting restores its "last search" in createChildren (before setVisible),
-- and the item/recipe filter is applied after createWindow, so this clears plain
-- opens while keeping the container-hotkey filter.
local function hookCraftingWindowVisibility()
    local function install(cls)
        if not cls or not cls.setVisible or cls._pvqolVisibleHooked then return end
        local origSetVisible = cls.setVisible
        function cls:setVisible(visible)
            if origSetVisible then origSetVisible(self, visible) end
            if visible then
                clearHandcraftFilter(self)
            end
        end
        cls._pvqolVisibleHooked = true
    end
    install(ISHandcraftWindow)
    install(NC_HandcraftWindow)
    install(NC_EntityWindow)
end

local function getCraftSuffix(key)
    if cachedCraftSuffix and cachedCraftSuffixKey == key then
        return cachedCraftSuffix
    end
    local keyText = getKeyName(key) or "B"
    local craftWord = getText("IGUI_CraftUI_Title")
    if not craftWord or craftWord == "IGUI_CraftUI_Title" then craftWord = "Craft" end
    cachedCraftSuffix = "[" .. keyText .. "] " .. craftWord
    cachedCraftSuffixKey = key
    return cachedCraftSuffix
end

-- Build the "[V] -> destination" hint segment. Hidden when there is nothing to choose.
local function getLootDestIndicator(player, options)
    if not player or not options or options.enableTakeChooser == false then return nil end
    local lootKey = options.lootCycleKey or ((Keyboard and Keyboard.KEY_V) or 47)
    if lootKey == 0 then return nil end
    local destinations = getTakeDestinations(player, nil)
    if #destinations <= 1 then return nil end
    local label = "Inventory"
    if lootDestContainer and lootDestContainer ~= player:getInventory() then
        for _, dest in ipairs(destinations) do
            if dest.container == lootDestContainer then
                label = dest.label
                break
            end
        end
    end
    return "[" .. (getKeyName(lootKey) or "V") .. "] -> " .. label
end

-- Wrap our hotkey prompts onto their own lines under Viewpoint's own hint, so
-- they cannot widen the crosshair panel (multi-line text is measured per line).
function ProjectViewpointQOL.formatHintSuffix(suffixes)
    if not suffixes or #suffixes == 0 then return nil end
    local lines = {}
    local current = ""
    for _, part in ipairs(suffixes) do
        if current == "" then
            current = part
        elseif #current + 2 + #part <= 40 then
            current = current .. "  " .. part
        else
            table.insert(lines, current)
            current = part
        end
    end
    if current ~= "" then
        table.insert(lines, current)
    end
    return "\n" .. table.concat(lines, "\n")
end

local function updateLootHint()
    local now = getTimestampMs()
    if (ProjectViewpointQOL.pendingRelockUntil or 0) > now then
        if not shouldMouseBeUnlocked() and isCursorUnlocked() then
            local options = ProjectViewpointQOLOptions or {}
            if options.lockOnClose ~= false then
                local b = bridge()
                if b and b.lockMouse then b.lockMouse() end
            end
        end
    elseif ProjectViewpointQOL.pendingRelockUntil then
        ProjectViewpointQOL.pendingRelockUntil = 0
    end

    local b = bridge()
    if not ProjectViewpointQOL.bridgeAvailable and b and b.isAvailable and b.isAvailable() then
        ProjectViewpointQOL.bridgeAvailable = true
    end
    if not (b and ProjectViewpointQOL.bridgeAvailable) then
        if lastHintSuffix ~= nil and b and b.setLootHintSuffix then
            b.setLootHintSuffix(nil)
            lastHintSuffix = nil
        end
        lastTargetedItem = nil
        lastTargetedItemEquippable = false
        lastTargetedItemEquipKind = nil
        lastTargetedItemHasExtras = false
        return
    end

    -- Nothing to annotate while the crosshair loot menu is not showing. Checking
    -- this first skips the reflective isLootLocked/getTargetedItem calls in the
    -- common case (no loot menu up).
    if not (b.isLootShown and b.isLootShown()) then
        if lastHintSuffix ~= nil and b.setLootHintSuffix then
            b.setLootHintSuffix(nil)
            lastHintSuffix = nil
        end
        lastTargetedItem = nil
        lastTargetedItemEquippable = false
        lastTargetedItemEquipKind = nil
        lastTargetedItemHasExtras = false
        ProjectViewpointQOL.noItemHintDirty = true
        return
    end

    if not (b.isViewpointActive and b.isViewpointActive()) then
        if lastHintSuffix ~= nil and b.setLootHintSuffix then
            b.setLootHintSuffix(nil)
            lastHintSuffix = nil
        end
        lastTargetedItem = nil
        lastTargetedItemEquippable = false
        lastTargetedItemEquipKind = nil
        lastTargetedItemHasExtras = false
        return
    end

    local player = getSpecificPlayer(0)
    if not player or player:isDead() then
        if lastHintSuffix ~= nil and b.setLootHintSuffix then
            b.setLootHintSuffix(nil)
            lastHintSuffix = nil
        end
        lastTargetedItem = nil
        lastTargetedItemEquippable = false
        lastTargetedItemEquipKind = nil
        lastTargetedItemHasExtras = false
        return
    end

    if b.isLootLocked and b.isLootLocked() then
        if lastHintSuffix ~= nil and b.setLootHintSuffix then
            b.setLootHintSuffix(nil)
            lastHintSuffix = nil
        end
        lastTargetedItem = nil
        lastTargetedItemEquippable = false
        lastTargetedItemEquipKind = nil
        lastTargetedItemHasExtras = false
        return
    end

    -- Do not add our hints while a context menu is open (avoids cluttering the menu)
    if isContextMenuOpen() then
        if lastHintSuffix ~= nil and b.setLootHintSuffix then
            b.setLootHintSuffix(nil)
            lastHintSuffix = nil
        end
        lastTargetedItem = nil
        lastTargetedItemEquippable = false
        lastTargetedItemEquipKind = nil
        lastTargetedItemHasExtras = false
        return
    end

    local item = b.getTargetedItem and b.getTargetedItem()
    if not item then
        lastTargetedItem = nil
        lastTargetedItemEquippable = false
        lastTargetedItemEquipKind = nil
        lastTargetedItemHasExtras = false
        -- Show just the loot destination indicator while the loot menu is up.
        -- Rebuild only when an input changes (or every 30 frames to pick up bag
        -- changes); otherwise re-apply the cached suffix. The Java hint cache
        -- drops our suffix when it recomputes, so it is re-applied every frame.
        local options = ProjectViewpointQOLOptions or {}
        local lootShown = (b.isLootShown and b.isLootShown()) and true or false
        local containersActive = (ViewpointQOLContainers and ViewpointQOLContainers.isActive and ViewpointQOLContainers.isActive()) and true or false
        local storeAllKey = options.storeAllKey or 0
        local containersKey = options.containersKey or 0
        local enableStoreAll = options.enableStoreAllHotkey ~= false
        local enableContainers = options.enableContainersHotkey ~= false
        local takeChooser = options.enableTakeChooser ~= false
        local cycleKey = options.lootCycleKey or 0
        local dest = lootDestContainer

        local dirty = ProjectViewpointQOL.noItemHintDirty
            or lootShown ~= ProjectViewpointQOL.noItemHintLootShown
            or containersActive ~= ProjectViewpointQOL.noItemHintContainersActive
            or dest ~= ProjectViewpointQOL.noItemHintDest
            or storeAllKey ~= ProjectViewpointQOL.noItemHintStoreAllKey
            or containersKey ~= ProjectViewpointQOL.noItemHintContainersKey
            or enableStoreAll ~= ProjectViewpointQOL.noItemHintEnableStoreAll
            or enableContainers ~= ProjectViewpointQOL.noItemHintEnableContainers
            or takeChooser ~= ProjectViewpointQOL.noItemHintTakeChooser
            or cycleKey ~= ProjectViewpointQOL.noItemHintCycleKey

        if not dirty and ProjectViewpointQOL.noItemHintBuilt and now - (ProjectViewpointQOL.noItemHintAt or 0) < 500 then
            if lastHintSuffix and b.setLootHintSuffix then
                b.setLootHintSuffix(lastHintSuffix)
            end
            return
        end
        ProjectViewpointQOL.noItemHintAt = now
        ProjectViewpointQOL.noItemHintDirty = false
        ProjectViewpointQOL.noItemHintBuilt = true
        ProjectViewpointQOL.noItemHintLootShown = lootShown
        ProjectViewpointQOL.noItemHintContainersActive = containersActive
        ProjectViewpointQOL.noItemHintDest = dest
        ProjectViewpointQOL.noItemHintStoreAllKey = storeAllKey
        ProjectViewpointQOL.noItemHintContainersKey = containersKey
        ProjectViewpointQOL.noItemHintEnableStoreAll = enableStoreAll
        ProjectViewpointQOL.noItemHintEnableContainers = enableContainers
        ProjectViewpointQOL.noItemHintTakeChooser = takeChooser
        ProjectViewpointQOL.noItemHintCycleKey = cycleKey

        local parts = {}
        if lootShown then
            local destIndicator = getLootDestIndicator(player, options)
            if destIndicator then
                table.insert(parts, destIndicator)
            end
            if enableContainers and containersKey ~= 0 then
                local label = containersActive and "All Containers" or "Single Container"
                local keyName = getKeyName(containersKey) or "["
                if enableStoreAll then
                    table.insert(parts, "[" .. keyName .. "] " .. label .. " / hold: Store All")
                else
                    table.insert(parts, "[" .. keyName .. "] " .. label)
                end
            end
            if enableStoreAll and storeAllKey ~= 0 then
                table.insert(parts, "[" .. (getKeyName(storeAllKey) or "[") .. "] Store All")
            end
        end
        local destSuffix = ProjectViewpointQOL.formatHintSuffix(parts)
        if destSuffix then
            if b.setLootHintSuffix then
                b.setLootHintSuffix(destSuffix)
            end
            lastHintSuffix = destSuffix
        elseif lastHintSuffix ~= nil then
            if b.setLootHintSuffix then
                b.setLootHintSuffix(nil)
            end
            lastHintSuffix = nil
        end
        return
    end

    -- The item path ran, so the cached "no item" suffix is stale.
    ProjectViewpointQOL.noItemHintDirty = true

    local options = ProjectViewpointQOLOptions or {}

    if item ~= lastTargetedItem then
        lastTargetedItem = item
        ProjectViewpointQOL.hintDirty = true
        -- Only evaluate the flags whose feature is enabled; disabled features
        -- never build a suffix, so the work would be wasted.
        local eqOk, eqKind = false, nil
        if options.enableEquipHotkey ~= false then
            eqOk, eqKind = isEquippable(item, player)
        end
        lastTargetedItemEquippable = eqOk
        lastTargetedItemEquipKind = eqKind
        lastTargetedItemHasExtras = eqOk and (options.enableEquipChooser ~= false) and hasExtraEquipChoices(item, player) or false
        local edible = false
        local drinkable = false
        local pill = false
        local smokable = false
        if options.enableEatHotkey ~= false then
            edible = isEdible(item, player)
            drinkable = isDrinkable(item, player)
            pill = isPill(item, player)
            smokable = isSmokable(item, player)
        end
        lastTargetedItemEdible = edible
        lastTargetedItemDrinkable = drinkable
        lastTargetedItemPill = pill
        lastTargetedItemSmokable = smokable
        lastTargetedItemReadable = (options.enableReadHotkey ~= false) and isReadable(item, player) or false
        lastTargetedItemCraftable = (options.enableContainerCraftHotkey ~= false) and isItemCraftable(item, player) or false

        local faType, faPart, faExtra = nil, nil, nil
        if options.enableFirstAidHotkey ~= false then
            faType, faPart, faExtra = isFirstAid(item, player)
        end
        lastTargetedItemFirstAid = (faType ~= nil)
        lastTargetedItemFirstAidType = faType
        lastTargetedItemFirstAidPart = faPart
        lastTargetedItemFirstAidExtra = faExtra

        local aAction, aCount, aSub = nil, nil, nil
        if options.enableAmmoHotkey ~= false then
            aAction, _, aCount, aSub = isAmmoActionable(item, player)
        end
        lastTargetedItemAmmo = (aAction ~= nil)
        lastTargetedItemAmmoAction = aAction
        lastTargetedItemAmmoCount = aCount
        lastTargetedItemAmmoSubType = aSub
    else
        if lastTargetedItemEquippable and player.isEquipped and
           (player:isEquipped(item) or (player.isHandItem and player:isHandItem(item)) or
            (player.isEquippedClothing and player:isEquippedClothing(item))) then
            lastTargetedItemEquippable = false
            lastTargetedItemEquipKind = nil
            lastTargetedItemHasExtras = false
            ProjectViewpointQOL.hintDirty = true
        end

        -- Revalidate all cached flags for the same item periodically (~500 ms)
        if now - (ProjectViewpointQOL.hintRevalidateAt or 0) >= 500 then
            ProjectViewpointQOL.hintRevalidateAt = now
            lastTargetedItem = nil
        end
    end

    -- Nothing changed since the last build: just make sure our suffix is still applied.
    -- The Java hint cache overwrites it whenever it recomputes (e.g. after looting).
    if not ProjectViewpointQOL.hintDirty then
        if lastHintSuffix and b.setLootHintSuffix then
            b.setLootHintSuffix(lastHintSuffix)
        end
        return
    end
    ProjectViewpointQOL.hintDirty = false

    local suffixes = {}

    -- 1. First-Aid suffix (Bandage, Disinfect, Suture)
    if lastTargetedItemFirstAid and options.enableFirstAidHotkey ~= false then
        local firstAidKey = options.firstAidKey or ((Keyboard and Keyboard.KEY_U) or 22)
        table.insert(suffixes, getFirstAidSuffix(item, lastTargetedItemFirstAidType, firstAidKey))
    end

    -- 2. Equip suffix
    if lastTargetedItemEquippable and options.enableEquipHotkey ~= false then
        local equipKey = options.equipKey or ((Keyboard and Keyboard.KEY_G) or 34)
        table.insert(suffixes, getEquipSuffix(lastTargetedItemEquipKind, equipKey, lastTargetedItemHasExtras))
    end

    -- 3. Read Literature suffix
    if lastTargetedItemReadable and options.enableReadHotkey ~= false then
        local readKey = options.readKey or ((Keyboard and Keyboard.KEY_G) or 34)
        table.insert(suffixes, getReadSuffix(readKey))
    end

    -- 4. Ammo Unpack & Magazine Loading suffix
    if lastTargetedItemAmmo and options.enableAmmoHotkey ~= false then
        local ammoKey = options.ammoKey or ((Keyboard and Keyboard.KEY_R) or 19)
        table.insert(suffixes, getAmmoSuffix(lastTargetedItemAmmoAction, lastTargetedItemAmmoSubType, lastTargetedItemAmmoCount, ammoKey, item))
    end

    -- 5. Container Crafting suffix
    if lastTargetedItemCraftable and options.enableContainerCraftHotkey ~= false then
        local craftKey = options.containerCraftKey or ((Keyboard and Keyboard.KEY_B) or 48)
        table.insert(suffixes, getCraftSuffix(craftKey))
    end

    -- 6. Eat / Drink / Pill / Smoke suffixes
    if options.enableEatHotkey ~= false then
        local eatAllKey = options.eatAllKey or ((Keyboard and Keyboard.KEY_G) or 34)

        if lastTargetedItemSmokable then
            table.insert(suffixes, getSmokeSuffix(eatAllKey))
        elseif lastTargetedItemPill then
            table.insert(suffixes, getPillSuffix(eatAllKey))
        elseif lastTargetedItemDrinkable then
            table.insert(suffixes, getDrinkAllSuffix(eatAllKey))
        elseif lastTargetedItemEdible then
            table.insert(suffixes, getEatAllSuffix(eatAllKey))
        end
    end

    -- 7. Loot destination indicator (defaults to Inventory before any cycling)
    local destIndicator = getLootDestIndicator(player, options)
    if destIndicator then
        table.insert(suffixes, destIndicator)
    end

    -- 8. Store All prompt while looking at a container (dedicated key, if bound)
    if options.enableStoreAllHotkey ~= false and (options.storeAllKey or 0) ~= 0 then
        table.insert(suffixes, "[" .. (getKeyName(options.storeAllKey) or "[") .. "] Store All")
    end

    -- 9. All-containers prompt while looking at a container (tap toggle / hold store)
    if options.enableContainersHotkey ~= false and (options.containersKey or 0) ~= 0 then
        local label = (ViewpointQOLContainers and ViewpointQOLContainers.isActive and ViewpointQOLContainers.isActive()) and "All Containers" or "Single Container"
        local keyName = getKeyName(options.containersKey) or "["
        if options.enableStoreAllHotkey ~= false then
            table.insert(suffixes, "[" .. keyName .. "] " .. label .. " / hold: Store All")
        else
            table.insert(suffixes, "[" .. keyName .. "] " .. label)
        end
    end

    local newSuffix = ProjectViewpointQOL.formatHintSuffix(suffixes)
    if b.setLootHintSuffix then
        -- Clear first so an older bridge can never leave a stale/duplicated suffix behind
        b.setLootHintSuffix(nil)
        b.setLootHintSuffix(newSuffix)
    end
    lastHintSuffix = newSuffix
end

-- ====================================================================
-- Event Handlers & Watchdog
-- ====================================================================

-- Helper to close character info window if open
function closeCharacterInfoIfOpen()
    local charWin = (ISCharacterInfoWindow and ISCharacterInfoWindow.instance)
    if not charWin and getPlayerInfoPanel then
        charWin = getPlayerInfoPanel(0)
    end
    if charWin and charWin.close and charWin:getIsVisible() then
        charWin:close()
    end
end

-- Helper to close crafting window if open
function closeCraftingWindowIfOpen()
    if ISEntityUI and ISEntityUI.GetWindowInstance then
        local w = ISEntityUI.GetWindowInstance(0, "HandcraftWindow")
        if w and w.close and w:getIsVisible() then w:close() end
    end
end

-- Some windows (oven, microwave, vehicle AC, lightbar) store their close button in
-- a field named "close", which shadows their :close() method. Only call close()
-- when it is actually a function, otherwise hide and detach the window.
local function closeWindowSafe(win)
    if not win then return end
    if type(win.close) == "function" then
        pcall(function() win:close() end)
        return
    end
    pcall(function()
        if win.setVisible then win:setVisible(false) end
        if win.removeFromUIManager then win:removeFromUIManager() end
    end)
end

-- Feature 4: Close every open popup window (used when manually locking the cursor)
local function closeAllPopups()
    local playerNum = 0

    local playerInv = getPlayerInv()
    if playerInv and playerInv.getIsVisible and playerInv:getIsVisible() and playerInv.close then
        pcall(function() playerInv:close() end)
    end

    local lootInv = getLootInv()
    if lootInv and lootInv.getIsVisible and lootInv:getIsVisible() and lootInv.close then
        pcall(function() lootInv:close() end)
    end

    local radial = getPlayerRadialMenu and getPlayerRadialMenu(0)
    if radial and radial.isReallyVisible and radial:isReallyVisible() and radial.undisplay then
        pcall(function() radial:undisplay() end)
    end
    for menu, _ in pairs(activeRadialMenus) do
        if menu then
            pcall(function()
                if menu.undisplay then menu:undisplay() end
                if menu.removeFromUIManager then menu:removeFromUIManager() end
            end)
        end
        activeRadialMenus[menu] = nil
    end

    local contextMenu = getPlayerContextMenu and getPlayerContextMenu(0)
    if contextMenu and contextMenu.getIsVisible and contextMenu:getIsVisible() then
        pcall(function()
            if contextMenu.hideAndChildren then
                contextMenu:hideAndChildren()
            elseif contextMenu.setVisible then
                contextMenu:setVisible(false)
            end
        end)
    end

    if ISOvenUI and ISOvenUI.instance then
        local ui = ISOvenUI.instance[playerNum + 1]
        if ui and ui.getIsVisible and ui:getIsVisible() then
            closeWindowSafe(ui)
            ISOvenUI.instance[playerNum + 1] = nil
        end
    end

    if ISMicrowaveUI and ISMicrowaveUI.instance then
        local ui = ISMicrowaveUI.instance[playerNum + 1]
        if ui and ui.getIsVisible and ui:getIsVisible() then
            closeWindowSafe(ui)
            ISMicrowaveUI.instance[playerNum + 1] = nil
        end
    end

    if ISRadioWindow then
        local function closeRadioWindows(list)
            if not list then return end
            for _, win in pairs(list) do
                if win and win.getIsVisible and win:getIsVisible() then
                    closeWindowSafe(win)
                end
            end
        end
        closeRadioWindows(ISRadioWindow.instances)
        closeRadioWindows(ISRadioWindow.instancesIso)
    end

    if getPlayerMechanicsUI then
        local ui = getPlayerMechanicsUI(playerNum)
        if ui and ui.getIsVisible and ui:getIsVisible() then
            closeWindowSafe(ui)
        end
    end

    if ISVehicleMenu and ISVehicleMenu.seatUI then
        local ui = ISVehicleMenu.seatUI[playerNum]
        if ui and ui.getIsVisible and ui:getIsVisible() then
            closeWindowSafe(ui)
        end
    end

    if ISWorldMap_instance and ISWorldMap_instance.isVisible and ISWorldMap_instance:isVisible() then
        if ISWorldMap and ISWorldMap.HideWorldMap then
            pcall(function() ISWorldMap.HideWorldMap(playerNum) end)
        elseif ISWorldMap_instance.close then
            pcall(function() ISWorldMap_instance:close() end)
        end
    elseif ISWorldMap and ISWorldMap.instance and ISWorldMap.instance.close then
        pcall(function() ISWorldMap.instance:close() end)
    end

    if ISSearchWindow and ISSearchWindow.players then
        local searchPlayer = getSpecificPlayer(0)
        local ui = searchPlayer and ISSearchWindow.players[searchPlayer] or nil
        if ui and ui.getIsVisible and ui:getIsVisible() then
            closeWindowSafe(ui)
        end
    end

    closeCharacterInfoIfOpen()
    closeCraftingWindowIfOpen()

    for win, _ in pairs(activeInteractiveWindows) do
        if win and win.getIsVisible and win:getIsVisible() then
            closeWindowSafe(win)
        end
        activeInteractiveWindows[win] = nil
    end

    local b = bridge()
    if b and b.setLootHintSuffix then
        b.setLootHintSuffix(nil)
    end
    lastHintSuffix = nil
    lastTargetedItem = nil
    lastTargetedItemEquippable = false
    lastTargetedItemEquipKind = nil
    lastTargetedItemHasExtras = false
    activeChooserMenu = nil
    lastHUDAction = nil
    lastHUDItem = nil
    lastHUDPart = nil
    if firstAidHUDInstance and firstAidHUDInstance.setVisible then
        firstAidHUDInstance:setVisible(false)
    end

    local player = getSpecificPlayer(0)
    if player and autoWalkActive then
        stopAutoWalk(player, false)
    end
end

-- Shared close+reset used when the player manually locks the cursor
local function performManualLock()
    suppressMouseUpdates = true
    local ok, err = pcall(closeAllPopups)
    suppressMouseUpdates = false
    unlockedByMod = false
    ProjectViewpointQOL.pendingRelockUntil = 0
    wasInventoryOpen = false
    wasRadialOpen = false
    wasDeviceOrMenuOpen = false
    -- Do NOT lock the mouse here: Viewpoint's own middle-mouse handler toggles
    -- the cursor in the same frame, and setting it here can race that toggle.
    if not ok and err then
        print("[ProjectViewpointQOL] performManualLock error: " .. tostring(err))
    end
end

-- Viewpoint 0.1.6 owns the manual cursor toggle (its "Cursor free or locked"
-- key, Mouse 3 by default and rebindable). Follow that binding instead of
-- assuming middle mouse; fall back to middle only when Viewpoint is missing.
function ProjectViewpointQOL.isCursorToggleDown()
    local vk = Viewpoint and Viewpoint.Keys
    if vk and vk.get and vk.trigger then
        local text = vk.get("keys.cursor")
        if text and text ~= "" then
            -- This runs every frame; only re-parse the chord text when the bind
            -- actually changes (get/trigger build and parse key name strings).
            local code = ProjectViewpointQOL.cursorToggleCode
            if ProjectViewpointQOL.cursorToggleText ~= text then
                code = tonumber(vk.trigger(text)) or 0
                ProjectViewpointQOL.cursorToggleText = text
                ProjectViewpointQOL.cursorToggleCode = code
            end
            if code and code >= 10000 then
                return (isMouseButtonDown and isMouseButtonDown(code - 10000)) and true or false
            end
            if code and code > 0 then
                return (isKeyDown and isKeyDown(code)) and true or false
            end
            return false
        end
    end
    return (isMouseButtonDown and isMouseButtonDown(2)) and true or false
end

-- Feature 4: Detect the native cursor-lock toggle (Viewpoint's cursor key)
local function checkManualCursorLock(viewActive)
    if viewActive == nil then viewActive = isViewpointActive() end
    if not viewActive then
        wasMiddleDown = false
        lastCursorUnlocked = false
        manualLockOverride = false
        return
    end

    local options = ProjectViewpointQOLOptions or {}
    local toggleDown = ProjectViewpointQOL.isCursorToggleDown()
    local pressed = toggleDown and not wasMiddleDown
    wasMiddleDown = toggleDown

    if pressed and getGameSpeed() ~= 0 then
        if lastCursorUnlocked then
            -- Locking: suppress the mod's auto-unlock until the user unlocks again
            manualLockOverride = true
            if options.closeWindowsOnManualLock then
                performManualLock()
            end
        else
            -- Unlocking
            manualLockOverride = false
        end
    end

    lastCursorUnlocked = isCursorUnlocked()
end

-- Check if a key press should suppress vanilla panel/action triggers (Health H, Info J, Safety G, Crafting B, Reload R)
local function shouldSuppressVanillaKey(key)
    if not isViewpointActive() or getGameSpeed() == 0 then return false end
    local options = ProjectViewpointQOLOptions or {}

    local equipKey = options.equipKey or ((Keyboard and Keyboard.KEY_G) or 34)
    local eatAllKey = options.eatAllKey or ((Keyboard and Keyboard.KEY_G) or 34)
    local readKey = options.readKey or ((Keyboard and Keyboard.KEY_G) or 34)
    local firstAidKey = options.firstAidKey or ((Keyboard and Keyboard.KEY_U) or 22)
    local ammoKey = options.ammoKey or ((Keyboard and Keyboard.KEY_R) or 19)
    local craftKey = options.containerCraftKey or ((Keyboard and Keyboard.KEY_B) or 48)

    local isEatKey = (options.enableEatHotkey ~= false) and (key == eatAllKey)
    local isEquipKey = (options.enableEquipHotkey ~= false) and (key == equipKey)
    local isReadKey = (options.enableReadHotkey ~= false) and (key == readKey)
    local isFirstAidKey = (options.enableFirstAidHotkey ~= false) and (key == firstAidKey)
    local isAmmoKey = (options.enableAmmoHotkey ~= false) and (key == ammoKey)
    local isCraftKey = (options.enableContainerCraftHotkey ~= false) and (key == craftKey)

    if not isEatKey and not isEquipKey and not isReadKey and not isFirstAidKey and not isAmmoKey and not isCraftKey then return false end

    local player = getSpecificPlayer(0)
    if not player or player:isDead() then return false end

    local b = bridge()
    if not (b and b.isAvailable and b.isAvailable()) then return false end
    if b.isLootLocked and b.isLootLocked() then return false end

    local item = b.getTargetedItem and b.getTargetedItem()
    if not item then
        if isFirstAidKey then
            local invFaType = findBestFirstAidInInventory(player)
            if invFaType then return true end
        end
        return false
    end

    if isAmmoKey and isAmmoActionable(item, player) then
        return true
    end

    if isFirstAidKey and isFirstAid(item, player) then
        return true
    end

    if isEatKey and (isSmokable(item, player) or isPill(item, player) or isDrinkable(item, player) or isEdible(item, player)) then
        return true
    end

    if isEquipKey and isEquippable(item, player) then
        return true
    end

    if isReadKey and isReadable(item, player) then
        return true
    end

    if isCraftKey and isItemCraftable(item, player) then
        return true
    end

    return false
end

-- All Containers key: arm the tap/hold state on the real key-down event.
-- In B42 the OnKeyPressed event fires on key RELEASE (GameKeyboard.update
-- triggers it in the release branch), so arming there meant the key was
-- already up when onTick resolved it: taps toggled and holds could not store.
function ProjectViewpointQOL.onContainersKeyStartPressed(key)
    local player = getSpecificPlayer(0)
    if not player or getGameSpeed() == 0 or not isViewpointActive() then return end
    local options = ProjectViewpointQOLOptions or {}
    local containersKey = options.containersKey or ((Keyboard and Keyboard.KEY_LEFTBRACKET) or 26)
    if containersKey ~= 0 and key == containersKey and not ProjectViewpointQOL.containersKeyPending then
        ProjectViewpointQOL.containersKeyPending = true
        ProjectViewpointQOL.containersKeyStarted = getTimestampMs()
        ProjectViewpointQOL.containersKeyFiredHold = false
    end
end

-- Auto-Walk input runs on the real key-down event: OnKeyPressed fires on key
-- RELEASE in B42, so toggling there (and stopping on movement-key release) made
-- releasing W cancel the walk the player had just started.
function ProjectViewpointQOL.onAutoWalkKeyStartPressed(key)
    local player = getSpecificPlayer(0)
    if not player or player:isDead() or getGameSpeed() == 0 or not isViewpointActive() then return end
    local options = ProjectViewpointQOLOptions or {}
    if options.enableAutoWalk == false then return end

    -- Toggle key
    local autoWalkKey = options.autoWalkKey or ((Keyboard and Keyboard.KEY_APOSTROPHE) or 40)
    if autoWalkKey ~= 0 and key == autoWalkKey then
        toggleAutoWalk(player)
        return
    end

    -- Modifier + forward
    if options.autoWalkAltW ~= false then
        local wKey = (Keyboard and Keyboard.KEY_W) or 17
        local isForward = (key == wKey) or (KeybindId and KeybindId.FORWARD and getCore() and getCore():isKey(KeybindId.FORWARD, key))
        if isForward then
            local autoWalkMod = options.autoWalkModifierKey or ((Keyboard and Keyboard.KEY_RMENU) or 184)
            if isModifierKeyDown(autoWalkMod) then
                toggleAutoWalk(player)
                return
            end
        end
    end

    -- Manual movement input disengages (on press, not release)
    if autoWalkActive and isMovementKey(key) then
        stopAutoWalk(player, true)
    end
end

-- Keypress listener for instant Tab toggle, Container Equip / Eat / Drink / Read / First-Aid hotkeys, and Auto-Walk
local function onKeyPressed(key)
    local player = getSpecificPlayer(0)
    if not player or getGameSpeed() == 0 or not isViewpointActive() then return end

    local options = ProjectViewpointQOLOptions or {}

    -- Lock Cursor hotkey (optional alternative to middle mouse)
    local lockKey = options.lockCursorKey or 0
    if lockKey ~= 0 and key == lockKey then
        if isCursorUnlocked() then
            manualLockOverride = true
            if options.closeWindowsOnManualLock then
                performManualLock()
            end
            -- Lock explicitly: Viewpoint only toggles the cursor on middle mouse,
            -- so this key needs its own lock (no toggle race here).
            local b = bridge()
            if b and b.lockMouse then b.lockMouse() end
            unlockedByMod = false
            ProjectViewpointQOL.pendingRelockUntil = 0
            wasInventoryOpen = false
            wasRadialOpen = false
            wasDeviceOrMenuOpen = false
        else
            manualLockOverride = false
            local b = bridge()
            if b and b.unlockMouse then b.unlockMouse() end
            unlockedByMod = false
        end
        return
    end

    -- 0. Auto-Walk input runs on key-down (Events.OnKeyStartPressed); see
    -- ProjectViewpointQOL.onAutoWalkKeyStartPressed.

    -- 0b. Loot destination chooser hotkey (Viewpoint crosshair or loot window)
    local lootKey = options.lootCycleKey or ((Keyboard and Keyboard.KEY_V) or 47)
    if lootKey ~= 0 and key == lootKey and options.enableTakeChooser ~= false then
        local b = bridge()
        local lootShown = b and b.isLootShown and b.isLootShown()
        local lootInv = getLootInv()
        local lootWindowOpen = lootInv and lootInv.getIsVisible and lootInv:getIsVisible()
        if lootShown or lootWindowOpen then
            openLootDestChooser(player)
            return
        end
    end

    -- 0c. Loot menu toggle hotkey (hide/show Viewpoint's crosshair loot menu)
    local lootToggleKey = options.lootMenuToggleKey or ((Keyboard and Keyboard.KEY_K) or 37)
    if lootToggleKey ~= 0 and key == lootToggleKey and options.enableLootMenuToggle ~= false then
        toggleLootMenu(player)
        return
    end

    -- 0d. Store all to container hotkey (optional dedicated bind)
    local storeAllKey = options.storeAllKey or 0
    if storeAllKey ~= 0 and key == storeAllKey and options.enableStoreAllHotkey ~= false then
        storeAllToContainer(player)
        return
    end

    -- 0e. All containers / store all is armed on key-down (OnKeyPressed fires
    -- on key RELEASE in B42; see ProjectViewpointQOL.onContainersKeyStartPressed)
    -- and resolved in onTick.

    -- 1. First-Aid hotkey check (Container loot OR personal inventory)
    local firstAidKey = options.firstAidKey or ((Keyboard and Keyboard.KEY_U) or 22)
    if key == firstAidKey and options.enableFirstAidHotkey ~= false and not isFirstAidActionPending(player) then
        local b = bridge()
        local item = nil
        if b and b.isAvailable and b.isAvailable() and not (b.isLootLocked and b.isLootLocked()) then
            item = b.getTargetedItem and b.getTargetedItem()
        end

        if item then
            local faType, faPart, faExtra = isFirstAid(item, player)
            if faType and faPart then
                stopAutoWalk(player, false)
                lastTargetedItem = nil
                lastHUDAction = nil
                lastHUDItem = nil
                lastHUDPart = nil
                applyFirstAidItem(item, player, faPart, faType, faExtra)
                closeCharacterInfoIfOpen()
                return
            end
        end

        -- Check personal inventory & equipped bags if not using container item
        local invFaType, invItem, invPart, invExtra = findBestFirstAidInInventory(player)
        if invFaType and invItem and invPart then
            stopAutoWalk(player, false)
            lastHUDAction = nil
            lastHUDItem = nil
            lastHUDPart = nil
            applyFirstAidItem(invItem, player, invPart, invFaType, invExtra)
            closeCharacterInfoIfOpen()
            return
        end
    end

    -- 2. Container Equip hotkey check
    local equipKey = options.equipKey or ((Keyboard and Keyboard.KEY_G) or 34)
    if key == equipKey and options.enableEquipHotkey ~= false then
        local b = bridge()
        if b and b.isAvailable and b.isAvailable() then
            if not (b.isLootLocked and b.isLootLocked()) then
                local item = b.getTargetedItem and b.getTargetedItem()
                if item then
                    local eqOk, eqKind = isEquippable(item, player)
                    if eqOk then
                        stopAutoWalk(player, false)
                        lastTargetedItem = nil
                        if options.enableEquipChooser ~= false and (canGoInSecondaryHand(item, eqKind) or hasExtraEquipChoices(item, player)) then
                            openEquipChooser(item, player, eqKind)
                        else
                            equipTargetedItem(item, player)
                        end
                        return
                    end
                end
            end
        end
    end

    -- 3. Container Read Literature hotkey check
    local readKey = options.readKey or ((Keyboard and Keyboard.KEY_G) or 34)
    if key == readKey and options.enableReadHotkey ~= false then
        local b = bridge()
        if b and b.isAvailable and b.isAvailable() then
            if not (b.isLootLocked and b.isLootLocked()) then
                local item = b.getTargetedItem and b.getTargetedItem()
                if item and isReadable(item, player) then
                    stopAutoWalk(player, false)
                    lastTargetedItem = nil
                    readTargetedItem(item, player)
                    closeCraftingWindowIfOpen()
                    return
                end
            end
        end
    end

    -- 4. Container Ammunition Unpack & Loading hotkey check
    local ammoKey = options.ammoKey or ((Keyboard and Keyboard.KEY_R) or 19)
    if key == ammoKey and options.enableAmmoHotkey ~= false then
        local b = bridge()
        if b and b.isAvailable and b.isAvailable() then
            if not (b.isLootLocked and b.isLootLocked()) then
                local item = b.getTargetedItem and b.getTargetedItem()
                if item and isAmmoActionable(item, player) then
                    stopAutoWalk(player, false)
                    lastTargetedItem = nil
                    executeAmmoTargetedItem(item, player)
                    closeCraftingWindowIfOpen()
                    return
                end
            end
        end
    end

    -- 4b. Container Crafting hotkey check
    local craftKey = options.containerCraftKey or ((Keyboard and Keyboard.KEY_B) or 48)
    if key == craftKey and options.enableContainerCraftHotkey ~= false then
        local b = bridge()
        if b and b.isAvailable and b.isAvailable() then
            if not (b.isLootLocked and b.isLootLocked()) then
                local item = b.getTargetedItem and b.getTargetedItem()
                if item and isItemCraftable(item, player) then
                    stopAutoWalk(player, false)
                    lastTargetedItem = nil
                    craftTargetedItem(item, player)
                    return
                end
            end
        end
        -- Not looking at a craftable item: clear any stale search text in the crafting menu
        if ISEntityUI and ISEntityUI.GetWindowInstance then
            clearHandcraftFilter(ISEntityUI.GetWindowInstance(0, "HandcraftWindow"))
        end
    end

    -- 5. Container Eat / Drink / Pill / Smoke hotkey check
    local eatAllKey = options.eatAllKey or ((Keyboard and Keyboard.KEY_G) or 34)
    if key == eatAllKey and options.enableEatHotkey ~= false then
        local b = bridge()
        if b and b.isAvailable and b.isAvailable() then
            if not (b.isLootLocked and b.isLootLocked()) then
                local item = b.getTargetedItem and b.getTargetedItem()
                if item then
                    if isSmokable(item, player) then
                        stopAutoWalk(player, false)
                        lastTargetedItem = nil
                        smokeTargetedItem(item, player)
                        closeCharacterInfoIfOpen()
                        return
                    end
                    if isPill(item, player) then
                        stopAutoWalk(player, false)
                        lastTargetedItem = nil
                        takePillTargetedItem(item, player)
                        closeCharacterInfoIfOpen()
                        return
                    end
                    local drinkable, canHalveDrink, canQuarterDrink = isDrinkable(item, player)
                    if drinkable then
                        stopAutoWalk(player, false)
                        lastTargetedItem = nil
                        openEatPortionChooser(item, player, "drink", canHalveDrink, canQuarterDrink)
                        closeCharacterInfoIfOpen()
                        return
                    end
                    local edible, canHalveEat, canQuarterEat = isEdible(item, player)
                    if edible then
                        stopAutoWalk(player, false)
                        lastTargetedItem = nil
                        openEatPortionChooser(item, player, "eat", canHalveEat, canQuarterEat)
                        closeCharacterInfoIfOpen()
                        return
                    end
                end
            end
        end
    end

    -- 6. Inventory Toggle check (Tab key)
    local isToggleKey = false
    if KeybindId and KeybindId.TOGGLE_INVENTORY then
        isToggleKey = getCore():isKey(KeybindId.TOGGLE_INVENTORY, key)
    else
        isToggleKey = (key == (Keyboard and Keyboard.KEY_TAB or 15))
    end

    if not isToggleKey then return end

    local playerInv = getPlayerInv()
    if not playerInv then return end

    -- Vanilla ISInventoryPage.onKeyPressed toggles getIsVisible()
    if not playerInv:getIsVisible() then
        if options.uncollapseOnTab ~= false then
            expandInventory(playerInv)
            expandInventory(getLootInv())
        end
        wasInventoryOpen = true
        if options.unlockOnOpen ~= false then
            local b = bridge()
            if b and b.unlockMouse then b.unlockMouse() end
            unlockedByMod = true
        end
    else
        wasInventoryOpen = false
        updateMouseState()
    end
end

-- Mouse wheel listener for Modifier + Wheel Hotbar cycling and 1st/3rd person camera zoom
local function onMouseWheel(del)
    if not isViewpointActive() then return end

    local player = getSpecificPlayer(0)
    if not player or player:isDead() or getGameSpeed() == 0 then return end

    local options = ProjectViewpointQOLOptions or {}

    -- 1. Modifier + Mouse Wheel Hotbar cycling
    local hotbarMod = options.hotbarModifierKey or ((Keyboard and Keyboard.KEY_LMENU) or 56)
    if isModifierKeyDown(hotbarMod) and options.enableHotbarWheel ~= false then
        -- Don't hijack the wheel while scrolling loot or with the cursor unlocked
        local bHotbar = bridge()
        local lootShown = (bHotbar and bHotbar.isLootShown and bHotbar.isLootShown()) or
                          (bHotbar and bHotbar.getTargetedItem and bHotbar.getTargetedItem()) or false
        if isCursorUnlocked() or lootShown then
            return
        end

        local pNum = player:getPlayerNum()
        local hotbar = getPlayerHotbar and getPlayerHotbar(pNum)
        if hotbar and hotbar.availableSlot and hotbar.attachedItems then
            local occupiedSlots = {}
            for i, _ in pairs(hotbar.availableSlot) do
                if hotbar.attachedItems[i] then
                    table.insert(occupiedSlots, i)
                end
            end
            table.sort(occupiedSlots)

            if #occupiedSlots > 0 then
                local currentIdxInList = nil
                for idx, slotNum in ipairs(occupiedSlots) do
                    local itm = hotbar.attachedItems[slotNum]
                    if itm and (itm:isEquipped() or player:isPrimaryHandItem(itm)) then
                        currentIdxInList = idx
                        break
                    end
                end

                if not (#occupiedSlots == 1 and currentIdxInList == 1) then
                    local dir = (del > 0) and 1 or -1
                    if options.invertHotbarScroll then
                        dir = -dir
                    end

                    local nextIdx = 1
                    if currentIdxInList then
                        nextIdx = currentIdxInList + dir
                        if nextIdx > #occupiedSlots then
                            nextIdx = 1
                        elseif nextIdx < 1 then
                            nextIdx = #occupiedSlots
                        end
                    else
                        nextIdx = (dir > 0) and 1 or #occupiedSlots
                    end

                    local targetSlotNum = occupiedSlots[nextIdx]
                    if targetSlotNum then
                        local cycleRunning = options.hotbarCycleWhileRunning ~= false
                        if cycleRunning then
                            ProjectViewpointQOL.hotbarRunEquipActive = true
                        end
                        local ok = pcall(function() hotbar:activateSlot(targetSlotNum) end)
                        if cycleRunning then
                            ProjectViewpointQOL.hotbarRunEquipActive = false
                        end
                        if not ok then
                            print("[ProjectViewpointQOL] Hotbar cycle failed to activate slot " .. tostring(targetSlotNum) .. ".")
                        end
                    end
                end
            end
        end
        -- Consume wheel event so camera zoom does NOT trigger
        return
    end

    local b = bridge()
    if not b then return end

    -- 2. If looking at a container or floor loot, do NOT zoom (scrolls container loot rows instead)
    if (b.isLootShown and b.isLootShown()) or (b.getTargetedItem and b.getTargetedItem()) then
        return
    end

    -- 3. If mouse cursor is unlocked or an inventory/radial menu is open, do NOT zoom
    if isCursorUnlocked() or shouldMouseBeUnlocked() then
        return
    end

    local dir = (del > 0) and 1 or -1
    if options.invertZoom then
        dir = -dir
    end

    -- 4. Modifier (default CTRL) + wheel adjusts FOV in both views
    local fovMod = options.zoomFovModifierKey or ((Keyboard and Keyboard.KEY_LCONTROL) or 29)
    if fovMod ~= 0 and isModifierKeyDown(fovMod) then
        if options.enableMouseWheelZoom == false then return end
        local step = options.zoomStep or 5.0
        local deltaFov = (dir == 1) and -step or step
        local zoomApi = ViewpointQOLZoom
        if zoomApi and zoomApi.zoomFov then
            zoomApi.zoomFov(deltaFov)
        elseif b.zoom then
            b.zoom(deltaFov)
        end
        return
    end

    -- 5. Plain wheel: third-person camera distance, handing over to first person
    -- when fully zoomed in. Since Viewpoint 0.1.6 the zoom is its own "Camera
    -- distance" setting (0.25-3.0, default 0.85); the wheel writes that setting
    -- directly, so the distance the player picks is remembered.
    if options.enableThirdPersonZoom == false then return end
    local zoomApi = ViewpointQOLZoom
    if not (zoomApi and zoomApi.isAvailable and zoomApi.isAvailable()) then return end

    local step = options.thirdPersonZoomStep or 0.15
    local smooth = options.smoothThirdPersonZoom ~= false

    -- Viewpoint keeps a separate camera distance while seated in a vehicle
    -- ("Vehicle camera distance", 0.25-4.0) from the on-foot one
    -- ("Camera distance", 0.25-3.0); the wheel moves whichever applies.
    local seated = player:getVehicle() ~= nil
    local minDistance = 0.25
    local maxDistance = 3.0
    local defaultDistance = 0.85
    local getDistance, setDistance, snapDistance
    if seated then
        if not (zoomApi.getVehicleDistance and zoomApi.setVehicleDistance) then return end
        getDistance = zoomApi.getVehicleDistance
        setDistance = zoomApi.setVehicleDistance
        snapDistance = zoomApi.snapVehicleDistance
        if zoomApi.getVehicleDistanceMin then minDistance = zoomApi.getVehicleDistanceMin() or 0.25 end
        if zoomApi.getVehicleDistanceMax then maxDistance = zoomApi.getVehicleDistanceMax() or 4.0 end
        local seatedDefault = zoomApi.getVehicleDistanceFallback and zoomApi.getVehicleDistanceFallback() or nil
        if not seatedDefault or seatedDefault <= 0 then seatedDefault = 0.9 end
        defaultDistance = seatedDefault
    else
        getDistance = zoomApi.getDistance
        setDistance = zoomApi.setDistance
        snapDistance = zoomApi.snapDistance
        if zoomApi.getDistanceMin then minDistance = zoomApi.getDistanceMin() or 0.25 end
        if zoomApi.getDistanceMax then maxDistance = zoomApi.getDistanceMax() or 3.0 end
        if zoomApi.getDistanceFallback then defaultDistance = zoomApi.getDistanceFallback() or 0.85 end
    end

    local function beginSmoothZoom(target)
        -- The camera distance setting snaps to its own grid; land the persisted
        -- target on it. The glide itself is continuous and time-based: it starts
        -- from the current visual distance (or the setting when idle) and lands
        -- exactly on the target after a fixed duration, so it never keeps
        -- drifting after the wheel stops. Scrolling again restarts the glide
        -- from wherever the camera is.
        if snapDistance then
            target = snapDistance(target)
        end
        local from = ProjectViewpointQOL.zoomVisualDistance
        if not from and getDistance then
            from = getDistance()
        end
        from = from or defaultDistance
        ProjectViewpointQOL.zoomVisualDistance = from
        ProjectViewpointQOL.zoomEaseFrom = from
        ProjectViewpointQOL.zoomTargetDistance = target
        ProjectViewpointQOL.zoomEaseStartedAt = getTimestampMs()
        ProjectViewpointQOL.zoomSeated = seated
        if zoomApi.setVisualDistance then
            zoomApi.setVisualDistance(from)
        end
        -- Keep the camera's boom limit snapped while the zoom runs, so a
        -- zoom-out does not keep drifting outward afterwards.
        if zoomApi.noteZoomActivity then zoomApi.noteZoomActivity() end
    end

    if zoomApi.isThirdPerson and zoomApi.isThirdPerson() then
        local current = (getDistance and getDistance()) or defaultDistance
        if seated and current <= 0 then return end
        if dir == 1 and current <= minDistance + 0.001 then
            -- Already at the closest camera position: hand over to first person
            ProjectViewpointQOL.zoomTargetDistance = nil
            ProjectViewpointQOL.zoomVisualDistance = nil
            ProjectViewpointQOL.zoomSeated = nil
            if zoomApi.setVisualDistance then zoomApi.setVisualDistance(0) end
            zoomApi.setThirdPerson(false)
            if setDistance then setDistance(defaultDistance) end
            return
        end
        local target = ProjectViewpointQOL.zoomTargetDistance or current
        target = target + ((dir == 1) and -step or step)
        if target < minDistance then target = minDistance end
        if target > maxDistance then target = maxDistance end
        if smooth then
            beginSmoothZoom(target)
        else
            ProjectViewpointQOL.zoomTargetDistance = nil
            ProjectViewpointQOL.zoomVisualDistance = nil
            ProjectViewpointQOL.zoomSeated = nil
            if zoomApi.setVisualDistance then zoomApi.setVisualDistance(0) end
            if zoomApi.noteZoomActivity then zoomApi.noteZoomActivity() end
            if setDistance then setDistance(target) end
        end
        return
    end

    -- First person: scrolling out returns to third person just behind the head
    if dir ~= 1 then
        zoomApi.setThirdPerson(true)
        ProjectViewpointQOL.zoomThirdGraceUntil = getTimestampMs() + 500
        if smooth then
            beginSmoothZoom(minDistance + step)
        else
            ProjectViewpointQOL.zoomTargetDistance = nil
            ProjectViewpointQOL.zoomVisualDistance = nil
            ProjectViewpointQOL.zoomSeated = nil
            if zoomApi.setVisualDistance then zoomApi.setVisualDistance(0) end
            if zoomApi.noteZoomActivity then zoomApi.noteZoomActivity() end
            if setDistance then setDistance(minDistance + step) end
        end
    end
end

-- Keep the Viewpoint QOL tab and the Mod Options page in sync (pull side)
function ProjectViewpointQOL.syncOptionsFromViewpoint()
    local opts = ProjectViewpointQOLOptions
    if not (opts and opts.pullFromViewpoint) then return end
    local ok, err = pcall(opts.pullFromViewpoint)
    if ok then
        ProjectViewpointQOL.optionsSyncFailures = 0
        return
    end
    ProjectViewpointQOL.optionsSyncFailures = (ProjectViewpointQOL.optionsSyncFailures or 0) + 1
    if ProjectViewpointQOL.optionsSyncFailures == 5 then
        opts.viewpointAvailable = false
        print("[ProjectViewpointQOL] Viewpoint settings sync failed; Mod Options remains the source. " .. tostring(err))
    end
end

-- Watchdog runs each tick to detect external UI changes (ESC, radial close, moving away, etc.) and steer auto-walk
local function onTick()
    if not firstAidHUDInstance then
        initFirstAidHUD()
    end

    -- Real time in ms, so background intervals do not scale with the frame rate
    -- (Events.OnTick fires once per rendered frame, not at a fixed 60 Hz).
    local now = getTimestampMs()

    -- Keep the Viewpoint QOL tab and the Mod Options page in sync. The tab can
    -- only be edited while Viewpoint's settings window is open, so poll then
    -- (fast, live feedback), once when it closes, and rarely otherwise for
    -- external file edits. The old always-on 2 s poll read all ~53 options for
    -- 2-8 ms per pass and was pure waste during play.
    local settingsShown = false
    if ViewpointQOLSettings and ViewpointQOLSettings.isSettingsShown then
        settingsShown = ViewpointQOLSettings.isSettingsShown() and true or false
    end
    if settingsShown then
        ProjectViewpointQOL.settingsWasShown = true
        if now - (ProjectViewpointQOL.optionsSyncAt or 0) >= 500 then
            ProjectViewpointQOL.optionsSyncAt = now
            ProjectViewpointQOL.syncOptionsFromViewpoint()
        end
    elseif ProjectViewpointQOL.settingsWasShown then
        ProjectViewpointQOL.settingsWasShown = false
        ProjectViewpointQOL.optionsSyncAt = now
        ProjectViewpointQOL.syncOptionsFromViewpoint()
    elseif now - (ProjectViewpointQOL.optionsSyncAt or 0) >= 30000 then
        ProjectViewpointQOL.optionsSyncAt = now
        ProjectViewpointQOL.syncOptionsFromViewpoint()
    end

    -- Smooth third-person camera zoom toward the wheel target (camera distance).
    -- Viewpoint's setting snaps to a 0.05 grid, so writing it directly stepped;
    -- the glide drives a continuous visual distance on the camera (via the
    -- CameraStep patch) with a fixed-duration ease-out, lands exactly on the
    -- target (no drift after the wheel stops) and persists the level once.
    if ProjectViewpointQOL.zoomTargetDistance then
        local options = ProjectViewpointQOLOptions or {}
        local zoomApi = ViewpointQOLZoom
        local function dropZoomTarget()
            ProjectViewpointQOL.zoomTargetDistance = nil
            ProjectViewpointQOL.zoomVisualDistance = nil
            ProjectViewpointQOL.zoomEaseFrom = nil
            ProjectViewpointQOL.zoomEaseStartedAt = nil
            ProjectViewpointQOL.zoomSeated = nil
            if zoomApi and zoomApi.setVisualDistance then zoomApi.setVisualDistance(0) end
        end
        -- The glide runs against whichever distance setting applied when it
        -- started: on foot or in a vehicle (Viewpoint keeps them separate).
        local seated = ProjectViewpointQOL.zoomSeated == true
        local player = getSpecificPlayer(0)
        local seatedNow = (player and player:getVehicle()) ~= nil
        local getDistance = zoomApi and ((seated and zoomApi.getVehicleDistance) or zoomApi.getDistance)
        local setDistance = zoomApi and ((seated and zoomApi.setVehicleDistance) or zoomApi.setDistance)
        local defaultDistance = 0.85
        if seated then
            local seatedDefault = zoomApi and zoomApi.getVehicleDistanceFallback and zoomApi.getVehicleDistanceFallback() or nil
            defaultDistance = (seatedDefault and seatedDefault > 0) and seatedDefault or 0.9
        elseif zoomApi and zoomApi.getDistanceFallback then
            local footDefault = zoomApi.getDistanceFallback()
            defaultDistance = (footDefault and footDefault > 0) and footDefault or 0.85
        end
        if options.enableThirdPersonZoom == false or not (zoomApi and zoomApi.isAvailable and zoomApi.isAvailable()) then
            dropZoomTarget()
        elseif ProjectViewpointQOL.zoomSeated ~= nil and ProjectViewpointQOL.zoomSeated ~= seatedNow then
            -- Entered or left a vehicle mid-glide; the new camera must not
            -- inherit the other state's distance.
            dropZoomTarget()
        elseif not (zoomApi.isThirdPerson and zoomApi.isThirdPerson())
            and now >= (ProjectViewpointQOL.zoomThirdGraceUntil or 0) then
            -- Perspective changed externally; drop the target
            dropZoomTarget()
        else
            local target = ProjectViewpointQOL.zoomTargetDistance
            local from = ProjectViewpointQOL.zoomEaseFrom
            local startedAt = ProjectViewpointQOL.zoomEaseStartedAt
            if not from then
                from = ProjectViewpointQOL.zoomVisualDistance
                    or (getDistance and getDistance()) or defaultDistance
                ProjectViewpointQOL.zoomEaseFrom = from
                ProjectViewpointQOL.zoomVisualDistance = from
            end
            if not startedAt then
                startedAt = now
                ProjectViewpointQOL.zoomEaseStartedAt = now
            end
            local t = (now - startedAt) / 220
            if t >= 1 then
                -- Arrived: drop the override, persist the level into Viewpoint's
                -- setting (a single save) and hand over to first person when
                -- fully zoomed in.
                local minDistance = 0.25
                if seated then
                    if zoomApi.getVehicleDistanceMin then minDistance = zoomApi.getVehicleDistanceMin() or 0.25 end
                elseif zoomApi.getDistanceMin then
                    minDistance = zoomApi.getDistanceMin() or 0.25
                end
                dropZoomTarget()
                if target <= minDistance + 0.0001 and zoomApi.setThirdPerson then
                    zoomApi.setThirdPerson(false)
                    if setDistance then setDistance(defaultDistance) end
                elseif setDistance then
                    setDistance(target)
                end
            else
                -- Cubic ease-out: quick start, gentle landing, exact at t = 1.
                local u = 1 - t
                local eased = 1 - u * u * u
                local next = from + (target - from) * eased
                ProjectViewpointQOL.zoomVisualDistance = next
                if zoomApi.setVisualDistance then zoomApi.setVisualDistance(next) end
            end
        end
    end

    -- Respect the vanilla "resume normal speed when timed actions complete" option
    if ISTimedActionQueue then
        local nowResetting = ISTimedActionQueue.shouldResetGameSpeed
        if ProjectViewpointQOL.prevTimedActionReset and not nowResetting then
            ProjectViewpointQOL.desiredFastForwardSpeed = nil
            ProjectViewpointQOL.desiredFastForwardMultiplier = nil
            ProjectViewpointQOL.clearSpeedKeeper()
        end
        ProjectViewpointQOL.prevTimedActionReset = nowResetting
    end

    -- UI open-state is a fallback safety net (the window hooks handle the
    -- immediate case), so refresh it at most every 100 ms and reuse the cache.
    local viewActive = isViewpointActive()
    local invRaw, radialRaw, deviceRaw
    if viewActive then
        local cache = ProjectViewpointQOL.uiStateCache
        if not cache or now - (ProjectViewpointQOL.uiStateAt or 0) >= 100 then
            cache = { isInventoryOpen(), isRadialMenuOpen(), isDeviceOrMenuOpen() }
            ProjectViewpointQOL.uiStateCache = cache
            ProjectViewpointQOL.uiStateAt = now
        end
        invRaw, radialRaw, deviceRaw = cache[1], cache[2], cache[3]
    end

    if now - (ProjectViewpointQOL.faHudAt or 0) >= 100 then
        ProjectViewpointQOL.faHudAt = now
        updateFirstAidHUD(viewActive, invRaw, radialRaw, deviceRaw)
    end

    checkManualCursorLock(viewActive)

    -- Relock the cursor once the equip chooser menu has been closed
    if activeChooserMenu and not (activeChooserMenu.getIsVisible and activeChooserMenu:getIsVisible()) then
        activeChooserMenu = nil
        if unlockedByMod then
            updateMouseState(invRaw, radialRaw, deviceRaw, viewActive)
        end
    end

    -- Safety net: if a tracked window/radial is visible but the cursor is still locked, unlock it
    if viewActive and not lastCursorUnlocked and (radialRaw or deviceRaw) then
        updateMouseState(invRaw, radialRaw, deviceRaw, viewActive)
    end

    local player = getSpecificPlayer(0)
    if player then
        autoOpenDoorOnContact(player, now)
        ProjectViewpointQOL.updateFastForwardKeepAlive(player)
        ProjectViewpointQOL.checkBridgeStatus(player, now)

        -- Retry Viewpoint settings registration until it succeeds (covers a
        -- bridge that loads late, e.g. delayed Java mod approval in MP).
        if ProjectViewpointQOLOptions and ProjectViewpointQOLOptions.setupViewpoint
            and not ProjectViewpointQOLOptions.viewpointSetup
            and now - (ProjectViewpointQOL.viewpointSetupAt or 0) >= 5000 then
            ProjectViewpointQOL.viewpointSetupAt = now
            ProjectViewpointQOLOptions.setupViewpoint()
        end

        -- Retry the Viewpoint/Advanced Movement key-conflict check until its
        -- Mod Options page is available (then it marks itself resolved).
        if ProjectViewpointQOLOptions and ProjectViewpointQOLOptions.resolveVPAMKeyCollisions
            and not ProjectViewpointQOLOptions.vpamKeysResolved
            and now - (ProjectViewpointQOL.vpamResolveAt or 0) >= 5000 then
            ProjectViewpointQOL.vpamResolveAt = now
            ProjectViewpointQOLOptions.resolveVPAMKeyCollisions()
        end

        -- All-containers key: tap toggles, hold (350 ms) stores all
        if ProjectViewpointQOL.containersKeyPending then
            local keyOptions = ProjectViewpointQOLOptions or {}
            local cKey = keyOptions.containersKey or 0
            local held = cKey ~= 0 and isKeyDown and isKeyDown(cKey)
            if held and not ProjectViewpointQOL.containersKeyFiredHold
                and now - (ProjectViewpointQOL.containersKeyStarted or 0) >= 350
                and keyOptions.enableStoreAllHotkey ~= false then
                ProjectViewpointQOL.containersKeyFiredHold = true
                storeAllToContainer(player)
            end
            if not held then
                local fired = ProjectViewpointQOL.containersKeyFiredHold
                ProjectViewpointQOL.containersKeyPending = false
                ProjectViewpointQOL.containersKeyFiredHold = nil
                if not fired and keyOptions.enableContainersHotkey ~= false then
                    ProjectViewpointQOL.toggleAllContainers(player)
                end
            end
        end

        -- Keep the "all nearby containers" list current while it is active.
        -- The mode persists until the key is pressed again, so it also applies
        -- when the player looks at a different container. The list only matters
        -- while the crosshair loot menu is up, and it is rebuilt with our own
        -- 3x3 scan: vanilla's lootWindow:refreshBackpacks() is a full hidden
        -- loot-window UI rebuild (the 15-40 ms container hitch) and must not run
        -- on tick.
        if ViewpointQOLContainers and ViewpointQOLContainers.isActive and ViewpointQOLContainers.isActive() then
            if player:isDead() then
                ViewpointQOLContainers.clear()
                ProjectViewpointQOL.containersList = nil
                ProjectViewpointQOL.containersLastSquare = nil
                ProjectViewpointQOL.containersLastVehicle = nil
                ProjectViewpointQOL.containersListStale = false
            elseif now - (ProjectViewpointQOL.containersRefreshAt or 0) >= 250 then
                ProjectViewpointQOL.containersRefreshAt = now
                local bContainers = bridge()
                if bContainers and bContainers.isLootShown and bContainers.isLootShown() then
                    local square = player.getCurrentSquare and player:getCurrentSquare() or nil
                    local vehicle = player.getVehicle and player:getVehicle() or nil
                    if square ~= ProjectViewpointQOL.containersLastSquare or vehicle ~= ProjectViewpointQOL.containersLastVehicle then
                        ProjectViewpointQOL.containersLastSquare = square
                        ProjectViewpointQOL.containersLastVehicle = vehicle
                        ProjectViewpointQOL.containersListStale = true
                    end
                    -- Rebuild once the player stops moving, so walking between
                    -- containers never rescans; on arrival the scan is cheap.
                    local moving = player.isPlayerMoving and player:isPlayerMoving()
                    if ProjectViewpointQOL.containersListStale and not moving then
                        local list = ProjectViewpointQOL.collectNearbyContainers(player)
                        local prev = ProjectViewpointQOL.containersList
                        local changed = (prev == nil) or (#prev ~= #list)
                        if not changed then
                            local prevSet = {}
                            for i = 1, #prev do
                                prevSet[prev[i]] = true
                            end
                            for i = 1, #list do
                                if not prevSet[list[i]] then
                                    changed = true
                                    break
                                end
                            end
                        end
                        -- Only re-apply when the container set actually changed, so the
                        -- menu selection is not reset every refresh interval. An empty
                        -- scan clears the override but keeps the mode armed.
                        if changed then
                            ProjectViewpointQOL.containersList = list
                            ViewpointQOLContainers.begin()
                            for _, c in ipairs(list) do
                                ViewpointQOLContainers.addContainer(c)
                            end
                            ViewpointQOLContainers.setActive(true)
                        end
                        ProjectViewpointQOL.containersListStale = false
                    end
                end
            end
        end
    end

    if not viewActive then
        wasInventoryOpen = false
        wasRadialOpen = false
        wasDeviceOrMenuOpen = false
        unlockedByMod = false
        if autoWalkActive then
            stopAutoWalk(player, false)
        end
        return
    end

    if player then
        updateAutoWalk(player, invRaw, radialRaw, deviceRaw, now)
    end

    if invRaw ~= wasInventoryOpen or
       radialRaw ~= wasRadialOpen or
       deviceRaw ~= wasDeviceOrMenuOpen then
        wasInventoryOpen = invRaw
        wasRadialOpen = radialRaw
        wasDeviceOrMenuOpen = deviceRaw
        manualLockOverride = false
        updateMouseState(invRaw, radialRaw, deviceRaw, viewActive)
    end
end

-- Hook into ISInventoryPage for immediate inventory visibility callback
local function hookInventoryPage()
    if not ISInventoryPage or ISInventoryPage._pvqolHooked then return end

    local origSetVisible = ISInventoryPage.setVisible or ISUIElement.setVisible
    function ISInventoryPage:setVisible(bVisible)
        if origSetVisible then origSetVisible(self, bVisible) end
        updateMouseState()
    end

    local origOnToggleVisible = ISInventoryPage.onToggleVisible
    function ISInventoryPage:onToggleVisible()
        if origOnToggleVisible then origOnToggleVisible(self) end
        updateMouseState()
    end

    local origClose = ISInventoryPage.close
    function ISInventoryPage:close()
        if origClose then origClose(self) end
        updateMouseState()
    end

    -- Redirect the loot window's "Loot all" button and context option to the selected bag
    if ISInventoryPane and ISInventoryPane.lootAll and not ISInventoryPane._pvqolLootAllHooked then
        local origLootAll = ISInventoryPane.lootAll
        ISInventoryPane.lootAll = function(self, ...)
            local options = ProjectViewpointQOLOptions or {}
            local playerObj = getSpecificPlayer(self.player)
            if options.enableTakeChooser ~= false and playerObj and lootDestContainer then
                local mainInv = playerObj:getInventory()
                if lootDestContainer ~= mainInv then
                    local valid = false
                    for _, dest in ipairs(getTakeDestinations(playerObj, nil)) do
                        if dest.container == lootDestContainer then
                            valid = true
                            break
                        end
                    end
                    if valid then
                        local items = {}
                        local it = self.inventory:getItems()
                        local heavyItem = nil
                        if luautils.walkToContainer(self.inventory, self.player) then
                            for i = 0, it:size() - 1 do
                                local item = it:get(i)
                                if not item:isUnwanted(playerObj) and not shouldSkipTakeAll(item, playerObj) then
                                    if isForceDropHeavyItem and isForceDropHeavyItem(item) then
                                        heavyItem = item
                                    else
                                        table.insert(items, item)
                                    end
                                end
                            end
                            if heavyItem and it:size() == 1 then
                                ISInventoryPaneContextMenu.equipHeavyItem(playerObj, heavyItem)
                                return
                            end
                            self:transferItemsByWeight(items, lootDestContainer)
                        end
                        self.selected = {}
                        local lootPage = getPlayerLoot(self.player)
                        if lootPage and lootPage.inventoryPane then lootPage.inventoryPane.selected = {} end
                        local invPage = getPlayerInventory(self.player)
                        if invPage and invPage.inventoryPane then invPage.inventoryPane.selected = {} end
                        return
                    end
                end
            end
            if origLootAll then return origLootAll(self, ...) end
        end
        ISInventoryPane._pvqolLootAllHooked = true
    end

    ISInventoryPage._pvqolHooked = true
end

-- Hook into ISRadialMenu for immediate wheel menu open/close callback
local function hookRadialMenu()
    if not ISRadialMenu or ISRadialMenu._pvqolHooked then return end

    local origAddToUIManager = ISRadialMenu.addToUIManager
    function ISRadialMenu:addToUIManager()
        if origAddToUIManager then origAddToUIManager(self) end
        activeRadialMenus[self] = true
        updateMouseState()
    end

    local origUndisplay = ISRadialMenu.undisplay
    function ISRadialMenu:undisplay()
        if origUndisplay then origUndisplay(self) end
        activeRadialMenus[self] = nil
        updateMouseState()
    end

    local origRemoveFromUIManager = ISRadialMenu.removeFromUIManager
    function ISRadialMenu:removeFromUIManager()
        if origRemoveFromUIManager then origRemoveFromUIManager(self) end
        activeRadialMenus[self] = nil
        updateMouseState()
    end

    ISRadialMenu._pvqolHooked = true
end

-- Hook into ISRadioWindow for TV, Radio, and Communication devices
local function hookRadioWindow()
    if not ISRadioWindow or ISRadioWindow._pvqolHooked then return end

    local origActivate = ISRadioWindow.activate
    ISRadioWindow.activate = function(player, deviceObject)
        local win = origActivate and origActivate(player, deviceObject) or nil
        if win then
            activeInteractiveWindows[win] = true
        end
        updateMouseState()
        return win
    end

    local origClose = ISRadioWindow.close
    function ISRadioWindow:close()
        if origClose then origClose(self) end
        activeInteractiveWindows[self] = nil
        updateMouseState()
    end

    ISRadioWindow._pvqolHooked = true
end

-- Hook into ISContextMenu for right-click and world interaction context menus
local function hookContextMenu()
    if not ISContextMenu or ISContextMenu._pvqolHooked then return end

    -- While a menu is being (re)built, "get" hides it and shows it again;
    -- reacting to each of those steps made the cursor blink. Only look at
    -- the final state once the rebuild is done.
    local origGet = ISContextMenu.get
    if origGet then
        ISContextMenu.get = function(...)
            ProjectViewpointQOL.rebuildingContextMenu = true
            local results = { pcall(origGet, ...) }
            ProjectViewpointQOL.rebuildingContextMenu = false
            if not results[1] then
                error(results[2], 0)
            end
            if not isHarvestingContextMenu then
                updateMouseState()
            end
            return results[2], results[3], results[4]
        end
    end

    local origSetVisible = ISContextMenu.setVisible
    function ISContextMenu:setVisible(visible)
        if origSetVisible then origSetVisible(self, visible) end
        if not isHarvestingContextMenu and not ProjectViewpointQOL.rebuildingContextMenu then
            updateMouseState()
        end
    end

    local origCloseAll = ISContextMenu.closeAll
    function ISContextMenu:closeAll()
        if origCloseAll then origCloseAll(self) end
        if not isHarvestingContextMenu and not ProjectViewpointQOL.rebuildingContextMenu then
            updateMouseState()
        end
    end

    local origHideAndChildren = ISContextMenu.hideAndChildren
    function ISContextMenu:hideAndChildren()
        if origHideAndChildren then origHideAndChildren(self) end
        if not isHarvestingContextMenu and not ProjectViewpointQOL.rebuildingContextMenu then
            updateMouseState()
        end
    end

    ISContextMenu._pvqolHooked = true
end

-- Vanilla ISWorldObjectContextMenuLogic.fetch dereferences a sprite name that
-- can be null on some corpses (burned/decomposed), so Viewpoint's interaction
-- harvest - which builds that vanilla context menu to gather actions - throws
-- on every hover of such a corpse. Recognise that specific error so it can be
-- treated as "nothing gathered" instead of spamming the error log.
function ProjectViewpointQOL.isKnownHarvestError(err)
    local msg = tostring(err or "")
    return msg:find("spriteName", 1, true) ~= nil
        or msg:find("ISWorldObjectContextMenuLogic", 1, true) ~= nil
        or msg:find("inventoryPane", 1, true) ~= nil
end

-- Hook into ViewpointInteract.harvest to prevent brief cursor flicker when hovering over world objects & containers
local function hookViewpointHarvest()
    if ViewpointInteract and not ViewpointInteract._pvqolHooked then
        local function harvestFailed(err)
            if ProjectViewpointQOL.isKnownHarvestError(err) then
                if not ProjectViewpointQOL.harvestBugWarned then
                    ProjectViewpointQOL.harvestBugWarned = true
                    print("[ProjectViewpointQOL] Skipped an interaction gather that trips a known vanilla bug (null sprite on a corpse or missing inventory UI).")
                end
                return { why = "known vanilla harvest bug" }
            end
            error(err)
        end
        if ViewpointInteract.harvest then
            local origHarvest = ViewpointInteract.harvest
            ViewpointInteract.harvest = function(...)
                isHarvestingContextMenu = true
                local ok, res = pcall(origHarvest, ...)
                isHarvestingContextMenu = false
                if not ok then return harvestFailed(res) end
                return res
            end
        end
        if ViewpointInteract.harvestVehicle then
            local origHarvestVeh = ViewpointInteract.harvestVehicle
            ViewpointInteract.harvestVehicle = function(...)
                isHarvestingContextMenu = true
                local ok, res = pcall(origHarvestVeh, ...)
                isHarvestingContextMenu = false
                if not ok then return harvestFailed(res) end
                return res
            end
        end
        ViewpointInteract._pvqolHooked = true
    end
end

-- Hook into Viewpoint's loot grab/take so the player can choose a destination
local function hookViewpointLoot()
    if ViewpointLoot and not ViewpointLoot._pvqolHooked then
        local origTake = ViewpointLoot.take
        local origTakeAll = ViewpointLoot.takeAll

        ViewpointLoot.take = function(player, item)
            if not item or not player then
                if origTake then return origTake(player, item) end
                return
            end
            if item:isHumanCorpse() and player:getVehicle() then
                if origTake then return origTake(player, item) end
                return
            end
            if not takeTargeted(player, item) and origTake then
                return origTake(player, item)
            end
        end

        ViewpointLoot.takeAll = function(player, items)
            if not items or not player or items:size() == 0 then
                if origTakeAll then return origTakeAll(player, items) end
                return
            end
            if not takeAllTargeted(player, items) and origTakeAll then
                return origTakeAll(player, items)
            end
        end

        ViewpointLoot._pvqolHooked = true
    end
end

-- Third-person animal context menu fallback: Viewpoint's raycast pick only
-- reaches a short distance around the hit point, so small animals (rats, mice)
-- are often missed and their right-click menu (Info, Feed, Kill, Butcher, ...)
-- never appears in third person. When the vanilla menu is being built and no
-- animal was picked, find the animal or animal corpse under Viewpoint's cursor
-- world point and feed it into the same fetch the game itself uses, so the
-- normal vanilla menu options appear. Skips the test passes and anything the
-- game already picked.
function ProjectViewpointQOL.onPreFillWorldObjectContextMenu(playerNum, context, worldobjects, test)
    if test then return end
    if not isViewpointActive() then return end
    local mouse = Viewpoint and Viewpoint.Mouse
    if not (mouse and mouse.worldX and mouse.worldY) then return end
    local wx, wy = mouse.worldX(), mouse.worldY()
    if not (wx and wy) then return end
    local playerObj = getSpecificPlayer and getSpecificPlayer(playerNum) or nil
    if not playerObj then return end
    local fetch = ISWorldObjectContextMenu and ISWorldObjectContextMenu.fetchVars
    if not fetch or fetch.animalbody then return end
    local animals = fetch.clickedAnimals
    if animals and #animals > 0 then return end

    local z = math.floor(playerObj:getZ())
    local cx, cy = math.floor(wx), math.floor(wy)
    local foundAnimal, bestAnimal = nil, 0.8
    local foundBody, bestBody = nil, 0.8
    for dx = -1, 1 do
        for dy = -1, 1 do
            local sq = getCell():getGridSquare(cx + dx, cy + dy, z)
            if sq and sq:isSeen(playerNum) then
                local movers = sq:getMovingObjects()
                if movers then
                    for i = 0, movers:size() - 1 do
                        local v = movers:get(i)
                        if instanceof(v, "IsoAnimal") then
                            local d = math.sqrt((v:getX() - wx) ^ 2 + (v:getY() - wy) ^ 2)
                            if d < bestAnimal then bestAnimal = d foundAnimal = v end
                        end
                    end
                end
                local statics = sq:getStaticMovingObjects()
                if statics then
                    for i = 0, statics:size() - 1 do
                        local v = statics:get(i)
                        if instanceof(v, "IsoDeadBody") and v:isAnimal() then
                            local d = math.sqrt((v:getX() - wx) ^ 2 + (v:getY() - wy) ^ 2)
                            if d < bestBody then bestBody = d foundBody = v end
                        end
                    end
                end
            end
        end
    end

    if foundAnimal then
        ISWorldObjectContextMenuLogic.fetch(fetch, foundAnimal, playerNum, true)
        fetch.c = (tonumber(fetch.c) or 0) + 1
        if not ProjectViewpointQOL.animalMenuPickWarned then
            ProjectViewpointQOL.animalMenuPickWarned = true
            print("[ProjectViewpointQOL] Animal context menu: picked up a nearby animal that Viewpoint's third-person pick missed.")
        end
    elseif foundBody then
        fetch.animalbody = foundBody
        fetch.c = (tonumber(fetch.c) or 0) + 1
        if not ProjectViewpointQOL.animalMenuPickWarned then
            ProjectViewpointQOL.animalMenuPickWarned = true
            print("[ProjectViewpointQOL] Animal context menu: picked up a nearby animal corpse that Viewpoint's third-person pick missed.")
        end
    end
end

-- Hook into ISOvenUI for stove and oven settings
local function hookOvenUI()
    if not ISOvenUI or ISOvenUI._pvqolHooked then return end

    local origAddToUIManager = ISOvenUI.addToUIManager or (ISUIElement and ISUIElement.addToUIManager)
    function ISOvenUI:addToUIManager()
        if origAddToUIManager then origAddToUIManager(self) end
        activeInteractiveWindows[self] = true
        updateMouseState()
    end

    local origRemoveFromUIManager = ISOvenUI.removeFromUIManager or (ISUIElement and ISUIElement.removeFromUIManager)
    function ISOvenUI:removeFromUIManager()
        if origRemoveFromUIManager then origRemoveFromUIManager(self) end
        activeInteractiveWindows[self] = nil
        updateMouseState()
    end

    local origClose = ISOvenUI.close
    function ISOvenUI:close()
        if origClose then origClose(self) end
        activeInteractiveWindows[self] = nil
        updateMouseState()
    end

    ISOvenUI._pvqolHooked = true
end

-- Hook into ISMicrowaveUI for microwave settings
local function hookMicrowaveUI()
    if not ISMicrowaveUI or ISMicrowaveUI._pvqolHooked then return end

    local origAddToUIManager = ISMicrowaveUI.addToUIManager or (ISUIElement and ISUIElement.addToUIManager)
    function ISMicrowaveUI:addToUIManager()
        if origAddToUIManager then origAddToUIManager(self) end
        activeInteractiveWindows[self] = true
        updateMouseState()
    end

    local origRemoveFromUIManager = ISMicrowaveUI.removeFromUIManager or (ISUIElement and ISUIElement.removeFromUIManager)
    function ISMicrowaveUI:removeFromUIManager()
        if origRemoveFromUIManager then origRemoveFromUIManager(self) end
        activeInteractiveWindows[self] = nil
        updateMouseState()
    end

    local origClose = ISMicrowaveUI.close
    function ISMicrowaveUI:close()
        if origClose then origClose(self) end
        activeInteractiveWindows[self] = nil
        updateMouseState()
    end

    ISMicrowaveUI._pvqolHooked = true
end

-- Hook into ISVehicleACUI for vehicle air conditioning / heater panel
local function hookVehicleACUI()
    if not ISVehicleACUI or ISVehicleACUI._pvqolHooked then return end

    local origAddToUIManager = ISVehicleACUI.addToUIManager or (ISUIElement and ISUIElement.addToUIManager)
    function ISVehicleACUI:addToUIManager()
        if origAddToUIManager then origAddToUIManager(self) end
        activeInteractiveWindows[self] = true
        updateMouseState()
    end

    local origRemoveFromUIManager = ISVehicleACUI.removeFromUIManager or (ISUIElement and ISUIElement.removeFromUIManager)
    function ISVehicleACUI:removeFromUIManager()
        if origRemoveFromUIManager then origRemoveFromUIManager(self) end
        activeInteractiveWindows[self] = nil
        updateMouseState()
    end

    local origClose = ISVehicleACUI.close
    function ISVehicleACUI:close()
        if origClose then origClose(self) end
        activeInteractiveWindows[self] = nil
        updateMouseState()
    end

    ISVehicleACUI._pvqolHooked = true
end

-- Hook into ISLightbarUI for vehicle emergency lightbar panel
local function hookLightbarUI()
    if not ISLightbarUI or ISLightbarUI._pvqolHooked then return end

    local origAddToUIManager = ISLightbarUI.addToUIManager or (ISUIElement and ISUIElement.addToUIManager)
    function ISLightbarUI:addToUIManager()
        if origAddToUIManager then origAddToUIManager(self) end
        activeInteractiveWindows[self] = true
        updateMouseState()
    end

    local origRemoveFromUIManager = ISLightbarUI.removeFromUIManager or (ISUIElement and ISUIElement.removeFromUIManager)
    function ISLightbarUI:removeFromUIManager()
        if origRemoveFromUIManager then origRemoveFromUIManager(self) end
        activeInteractiveWindows[self] = nil
        updateMouseState()
    end

    local origClose = ISLightbarUI.close
    function ISLightbarUI:close()
        if origClose then origClose(self) end
        activeInteractiveWindows[self] = nil
        updateMouseState()
    end

    ISLightbarUI._pvqolHooked = true
end

-- Hook into ISVehicleMechanics for instant cursor unlock when the mechanics window opens
local function hookVehicleMechanicsUI()
    if not ISVehicleMechanics or ISVehicleMechanics._pvqolHooked then return end

    local origAddToUIManager = ISVehicleMechanics.addToUIManager or (ISUIElement and ISUIElement.addToUIManager)
    function ISVehicleMechanics:addToUIManager()
        if origAddToUIManager then origAddToUIManager(self) end
        activeInteractiveWindows[self] = true
        updateMouseState()
    end

    local origRemoveFromUIManager = ISVehicleMechanics.removeFromUIManager or (ISUIElement and ISUIElement.removeFromUIManager)
    function ISVehicleMechanics:removeFromUIManager()
        if origRemoveFromUIManager then origRemoveFromUIManager(self) end
        activeInteractiveWindows[self] = nil
        updateMouseState()
    end

    local origSetVisible = ISVehicleMechanics.setVisible
    function ISVehicleMechanics:setVisible(bVisible, joypadData)
        if origSetVisible then origSetVisible(self, bVisible, joypadData) end
        updateMouseState()
    end

    local origClose = ISVehicleMechanics.close
    function ISVehicleMechanics:close()
        if origClose then origClose(self) end
        activeInteractiveWindows[self] = nil
        updateMouseState()
    end

    ISVehicleMechanics._pvqolHooked = true
end

-- Hook into ISVehicleSeatUI (Z seat switch) for instant cursor unlock
local function hookVehicleSeatUI()
    if not ISVehicleSeatUI or ISVehicleSeatUI._pvqolHooked then return end

    local origAddToUIManager = ISVehicleSeatUI.addToUIManager or (ISUIElement and ISUIElement.addToUIManager)
    function ISVehicleSeatUI:addToUIManager()
        if origAddToUIManager then origAddToUIManager(self) end
        activeInteractiveWindows[self] = true
        updateMouseState()
    end

    local origRemoveFromUIManager = ISVehicleSeatUI.removeFromUIManager or (ISUIElement and ISUIElement.removeFromUIManager)
    function ISVehicleSeatUI:removeFromUIManager()
        if origRemoveFromUIManager then origRemoveFromUIManager(self) end
        activeInteractiveWindows[self] = nil
        updateMouseState()
    end

    local origCloseSelf = ISVehicleSeatUI.closeSelf
    function ISVehicleSeatUI:closeSelf()
        if origCloseSelf then origCloseSelf(self) end
        activeInteractiveWindows[self] = nil
        updateMouseState()
    end

    ISVehicleSeatUI._pvqolHooked = true
end

-- Vanilla VehicleUtils.getContainers (Vehicles.lua) dereferences the legacy
-- inventory/loot UI pages without null checks. Events.OnPostSave destroys them
-- (and they only rebuild on player creation), while Viewpoint's render-time
-- vehicle harvest still runs during session start/exit; that throws
-- "attempted index: inventoryPane of non-table: null". Return an empty set
-- while they are missing, so radial entries that do not need the player's
-- items (mechanics, seats, doors) still gather instead of aborting.
function ProjectViewpointQOL.hookVehicleUtilsContainers()
    if not (VehicleUtils and VehicleUtils.getContainers) then return end
    if VehicleUtils._pvqolContainersHooked then return end
    local origGetContainers = VehicleUtils.getContainers
    VehicleUtils.getContainers = function(playerNum)
        local inv = getPlayerInventory and getPlayerInventory(playerNum) or nil
        local loot = getPlayerLoot and getPlayerLoot(playerNum) or nil
        if not (inv and inv.inventoryPane and loot and loot.inventoryPane) then
            return {}
        end
        return origGetContainers(playerNum)
    end
    VehicleUtils._pvqolContainersHooked = true
end

-- Hook into the vehicle radial menu so the cursor unlocks right after it is shown
local function hookVehicleRadialMenu()
    if not ISVehicleMenu or ISVehicleMenu._pvqolHooked then return end

    local origRadial = ISVehicleMenu.showRadialMenu
    if origRadial then
        ISVehicleMenu.showRadialMenu = function(...)
            local res = origRadial(...)
            updateMouseState()
            return res
        end
    end

    local origRadialOutside = ISVehicleMenu.showRadialMenuOutside
    if origRadialOutside then
        ISVehicleMenu.showRadialMenuOutside = function(...)
            local res = origRadialOutside(...)
            updateMouseState()
            return res
        end
    end

    ISVehicleMenu._pvqolHooked = true
end

-- Hook into ISWorldMap to provide instant 0ms mouse unlock/lock when opening/closing the World Map
local function hookWorldMap()
    if not ISWorldMap or ISWorldMap._pvqolHooked then return end

    local origShow = ISWorldMap.ShowWorldMap
    if origShow then
        ISWorldMap.ShowWorldMap = function(...)
            origShow(...)
            updateMouseState()
        end
    end

    local origHide = ISWorldMap.HideWorldMap
    if origHide then
        ISWorldMap.HideWorldMap = function(...)
            origHide(...)
            updateMouseState()
        end
    end

    local origClose = ISWorldMap.close
    if origClose then
        function ISWorldMap:close(...)
            origClose(self, ...)
            updateMouseState()
        end
    end

    if ISWorldMap_instance and origClose then
        local prevInstanceClose = ISWorldMap_instance.close
        ISWorldMap_instance.close = function(self, ...)
            if prevInstanceClose then
                prevInstanceClose(self, ...)
            else
                origClose(self, ...)
            end
            updateMouseState()
        end
    end

    ISWorldMap._pvqolHooked = true
end

-- Hook into xpUpdate.displayCharacterInfo to suppress Health/Info panels when eating/drinking from containers
local function hookDisplayCharacterInfo()
    if not xpUpdate or not xpUpdate.displayCharacterInfo or xpUpdate._pvqolHooked then return end

    local origDisplay = xpUpdate.displayCharacterInfo
    Events.OnKeyPressed.Remove(origDisplay)

    local function guardedDisplay(key)
        if shouldSuppressVanillaKey(key) then return end
        return origDisplay(key)
    end

    xpUpdate.displayCharacterInfo = guardedDisplay
    Events.OnKeyPressed.Add(guardedDisplay)
    xpUpdate._pvqolHooked = true
end

-- Hook into ISEquippedItem.onKeyPressed to suppress PvP safety toggle when equipping from containers
local function hookEquippedItemSafety()
    if not ISEquippedItem or not ISEquippedItem.onKeyPressed or ISEquippedItem._pvqolHooked then return end

    local origOnKeyPressed = ISEquippedItem.onKeyPressed
    Events.OnKeyPressed.Remove(origOnKeyPressed)

    local function guardedOnKeyPressed(key)
        if shouldSuppressVanillaKey(key) then return end
        return origOnKeyPressed(key)
    end

    ISEquippedItem.onKeyPressed = guardedOnKeyPressed
    Events.OnKeyPressed.Add(guardedOnKeyPressed)
    ISEquippedItem._pvqolHooked = true
end

-- Hook into ISFirearmRadialMenu.checkKey to suppress vanilla reload/radial menu when aiming at actionable ammo
local function hookFirearmRadialMenu()
    if not ISFirearmRadialMenu or not ISFirearmRadialMenu.checkKey or ISFirearmRadialMenu._pvqolHooked then return end

    local origCheckKey = ISFirearmRadialMenu.checkKey
    ISFirearmRadialMenu.checkKey = function(key)
        if shouldSuppressVanillaKey(key) then return false end
        return origCheckKey(key)
    end
    ISFirearmRadialMenu._pvqolHooked = true
end

-- Hook the vanilla speed keys so we know which fast-forward speed the player picked
function ProjectViewpointQOL.hookSpeedControlsHandler()
    if not SpeedControlsHandler or not SpeedControlsHandler.onKeyPressed or SpeedControlsHandler._pvqolHooked then return end

    local origOnKeyPressed = SpeedControlsHandler.onKeyPressed
    Events.OnKeyPressed.Remove(origOnKeyPressed)

    local function isSpeedKey(key)
        local core = getCore and getCore()
        if not (core and core.isKey) then return true end
        if KeybindId then
            if core:isKey(KeybindId.PAUSE, key) or core:isKey(KeybindId.NORMAL_SPEED, key) or
               core:isKey(KeybindId.FAST_FORWARD_X1, key) or core:isKey(KeybindId.FAST_FORWARD_X2, key) or
               core:isKey(KeybindId.FAST_FORWARD_X3, key) then
                return true
            end
        end
        return core:isKey("Step Forward", key) == true
    end

    local function guardedSpeedKey(key)
        origOnKeyPressed(key)
        if not isSpeedKey(key) then return end

        local speed = getGameSpeed()
        local sk = ViewpointQOLSpeed

        if speed and speed > 1 then
            local mult = (speed == 3 and 20) or (speed == 4 and 40) or 5
            ProjectViewpointQOL.desiredFastForwardSpeed = speed
            ProjectViewpointQOL.desiredFastForwardMultiplier = mult
            if sk and sk.setUserSpeed then
                sk.setUserSpeed(speed, mult)
            end
        elseif speed == 0 then
            -- Paused
            ProjectViewpointQOL.desiredFastForwardSpeed = nil
            ProjectViewpointQOL.desiredFastForwardMultiplier = nil
            if sk and sk.setUserSpeed then
                sk.setUserSpeed(0, 1)
            end
        else
            local mult = getGameTime and getGameTime():getTrueMultiplier() or 1
            if mult and mult > 1 then
                -- Unpausing restores the previous multiplier; re-arm the keep-alive
                local mapped = 2
                if mult >= 30 then
                    mapped = 4
                elseif mult >= 10 then
                    mapped = 3
                end
                ProjectViewpointQOL.desiredFastForwardSpeed = mapped
                ProjectViewpointQOL.desiredFastForwardMultiplier = mult
                if sk and sk.setUserSpeed then
                    sk.setUserSpeed(mapped, mult)
                end
            else
                ProjectViewpointQOL.desiredFastForwardSpeed = nil
                ProjectViewpointQOL.desiredFastForwardMultiplier = nil
                if sk and sk.setUserSpeed then
                    sk.setUserSpeed(1, 1)
                end
            end
        end
    end

    SpeedControlsHandler.onKeyPressed = guardedSpeedKey
    Events.OnKeyPressed.Add(guardedSpeedKey)
    SpeedControlsHandler._pvqolHooked = true
end

-- Shared reset for player death / new character / game start
function ProjectViewpointQOL.resetState()
    ProjectViewpointQOL.desiredFastForwardSpeed = nil
    ProjectViewpointQOL.desiredFastForwardMultiplier = nil
    ProjectViewpointQOL.clearSpeedKeeper()
    autoWalkZombieSlowed = false
    wasMiddleDown = false
    lastCursorUnlocked = false
    suppressMouseUpdates = false
    wasInventoryOpen = false
    wasRadialOpen = false
    wasDeviceOrMenuOpen = false
    unlockedByMod = false
    ProjectViewpointQOL.pendingRelockUntil = 0
    activeRadialMenus = {}
    activeInteractiveWindows = {}
    lastTargetedItem = nil
    lastTargetedItemEquippable = false
    lastTargetedItemEquipKind = nil
    lastTargetedItemHasExtras = false
    activeChooserMenu = nil
    lastHintSuffix = nil
    lastHUDAction = nil
    lastHUDItem = nil
    lastHUDPart = nil
    cachedFirstAidSuffixItem = nil
    cachedAmmoSuffixItem = nil
    lootDestContainer = nil
    manualLockOverride = false
    ProjectViewpointQOL.ffKeepAliveEnabled = nil
    ProjectViewpointQOL.ffBlocked = nil
    ProjectViewpointQOL.ffManualMoveCancels = nil
    ProjectViewpointQOL.containersKeyPending = false
    ProjectViewpointQOL.containersKeyStarted = nil
    ProjectViewpointQOL.containersKeyFiredHold = nil
    ProjectViewpointQOL.doorAutoUntil = nil
    ProjectViewpointQOL.prevTimedActionReset = nil
    ProjectViewpointQOL.hintDirty = true
    ProjectViewpointQOL.zombieScanAt = 0
    ProjectViewpointQOL.zombieScanIndex = 0
    ProjectViewpointQOL.zombieScanAccum = false
    ProjectViewpointQOL.zombieScanResult = false
    ProjectViewpointQOL.contextMenuWasOpen = false
    ProjectViewpointQOL.radialMenuWasOpen = false
    -- Drop any in-flight zoom glide and its continuous camera override.
    ProjectViewpointQOL.zoomTargetDistance = nil
    ProjectViewpointQOL.zoomVisualDistance = nil
    ProjectViewpointQOL.zoomEaseFrom = nil
    ProjectViewpointQOL.zoomEaseStartedAt = nil
    ProjectViewpointQOL.zoomSeated = nil
    if ViewpointQOLZoom and ViewpointQOLZoom.setVisualDistance then
        pcall(ViewpointQOLZoom.setVisualDistance, 0)
    end
end

local function onPlayerDeath(playerObj)
    if playerObj and playerObj ~= getSpecificPlayer(0) then return end
    stopAutoWalk(playerObj, false)
    ProjectViewpointQOL.resetState()
    if firstAidHUDInstance and firstAidHUDInstance.setVisible then
        firstAidHUDInstance:setVisible(false)
    end
end

local function onCreatePlayer(playerNum)
    if playerNum ~= 0 then return end
    ProjectViewpointQOL.resetState()
    initFirstAidHUD(true)
    updateMouseState()
end

-- Vanilla cancels timed actions with stopOnRun every frame while running, and
-- the equip/unequip/transfer actions set that flag. Wheel cycling while the
-- modifier is held usually means sprinting, so the swap would die instantly.
-- Scoped: only actions created during our activateSlot call are affected.
function ProjectViewpointQOL.installHotbarRunEquipHooks()
    if ProjectViewpointQOL.hotbarRunEquipHooks then return end
    ProjectViewpointQOL.hotbarRunEquipHooks = true

    if ISEquipWeaponAction and ISEquipWeaponAction.new then
        local baseEquipNew = ISEquipWeaponAction.new
        function ISEquipWeaponAction:new(character, item, maxTimeInit, primary, twoHands, alwaysTurnOn)
            local action = baseEquipNew(self, character, item, maxTimeInit, primary, twoHands, alwaysTurnOn)
            if action and ProjectViewpointQOL.hotbarRunEquipActive then
                action.stopOnRun = false
            end
            return action
        end
    end

    if ISUnequipAction and ISUnequipAction.new then
        local baseUnequipNew = ISUnequipAction.new
        function ISUnequipAction:new(character, item, maxTimeInit, reason)
            local action = baseUnequipNew(self, character, item, maxTimeInit, reason)
            if action and ProjectViewpointQOL.hotbarRunEquipActive then
                action.stopOnRun = false
            end
            return action
        end
    end

    if ISInventoryTransferAction and ISInventoryTransferAction.new then
        local baseTransferNew = ISInventoryTransferAction.new
        function ISInventoryTransferAction:new(character, item, srcContainer, destContainer, time)
            local action = baseTransferNew(self, character, item, srcContainer, destContainer, time)
            if action and ProjectViewpointQOL.hotbarRunEquipActive then
                action.stopOnRun = false
            end
            return action
        end
    end
end

Events.OnPlayerDeath.Add(onPlayerDeath)
Events.OnCreatePlayer.Add(onCreatePlayer)
Events.OnKeyPressed.Add(onKeyPressed)
Events.OnKeyStartPressed.Add(ProjectViewpointQOL.onContainersKeyStartPressed)
Events.OnKeyStartPressed.Add(ProjectViewpointQOL.onAutoWalkKeyStartPressed)
Events.OnMouseWheel.Add(onMouseWheel)
Events.OnTick.Add(onTick)
Events.OnRenderTick.Add(updateLootHint)
Events.OnGameStart.Add(hookInventoryPage)
Events.OnGameStart.Add(hookRadialMenu)
Events.OnGameStart.Add(hookRadioWindow)
Events.OnGameStart.Add(hookContextMenu)
Events.OnGameStart.Add(hookOvenUI)
Events.OnGameStart.Add(hookMicrowaveUI)
Events.OnGameStart.Add(hookVehicleACUI)
Events.OnGameStart.Add(hookLightbarUI)
Events.OnGameStart.Add(hookVehicleMechanicsUI)
Events.OnGameStart.Add(hookVehicleSeatUI)
Events.OnGameStart.Add(hookVehicleRadialMenu)
Events.OnGameStart.Add(hookWorldMap)
Events.OnGameStart.Add(hookDisplayCharacterInfo)
Events.OnGameStart.Add(hookEquippedItemSafety)
Events.OnGameStart.Add(hookFirearmRadialMenu)
Events.OnGameStart.Add(ProjectViewpointQOL.hookSpeedControlsHandler)
Events.OnGameStart.Add(ProjectViewpointQOL.hookVehicleUtilsContainers)
Events.OnGameStart.Add(initFirstAidHUD)
Events.OnGameStart.Add(hookViewpointHarvest)
Events.OnGameStart.Add(hookViewpointLoot)
Events.OnGameStart.Add(hookCraftingWindowVisibility)
Events.OnGameStart.Add(ProjectViewpointQOL.onPreFillWorldObjectContextMenu)
hookInventoryPage()
hookRadialMenu()
hookRadioWindow()
hookContextMenu()
hookViewpointHarvest()
hookViewpointLoot()
hookOvenUI()
hookMicrowaveUI()
hookVehicleACUI()
hookLightbarUI()
hookVehicleMechanicsUI()
hookVehicleSeatUI()
hookVehicleRadialMenu()
hookWorldMap()
hookDisplayCharacterInfo()
hookEquippedItemSafety()
hookFirearmRadialMenu()
ProjectViewpointQOL.hookSpeedControlsHandler()
ProjectViewpointQOL.hookVehicleUtilsContainers()
hookCraftingWindowVisibility()
ProjectViewpointQOL.installHotbarRunEquipHooks()
initFirstAidHUD()

print("[ProjectViewpointQOL] Client initialized successfully with Inventory, Radial Menu, Container Equip, Ingest (Eat/Drink/Pill/Smoke), Literature Reading, First-Aid & Bandaging, Ammunition Unpacking & Loading, Container Crafting, Hotbar Cycling, Hands-Free Auto-Walk, Device Windows, World Map, Appliances, Lock-to-Close Windows, and Camera Zoom.")
