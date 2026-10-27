ProjectViewpointQOLOptions = ProjectViewpointQOLOptions or {
    unlockOnOpen = true,
    lockOnClose = true,
    uncollapseOnTab = true,
    watchLoot = true,
    unlockOnRadial = true,
    unlockOnDevice = true,
    closeWindowsOnManualLock = false,
    enableNotifications = true,
    lockCursorKey = (Keyboard and Keyboard.KEY_NONE) or 0,
    enableEquipHotkey = true,
    enableEquipChooser = true,
    enableTakeChooser = true,
    lootCycleKey = (Keyboard and Keyboard.KEY_V) or 47,
    enableLootMenuToggle = true,
    lootMenuToggleKey = (Keyboard and Keyboard.KEY_K) or 37,
    takeAllSkipFavorites = false,
    takeAllSkipKeys = false,
    enableStoreAllHotkey = true,
    storeAllKey = (Keyboard and Keyboard.KEY_NONE) or 0,
    enableContainersHotkey = true,
    containersKey = (Keyboard and Keyboard.KEY_LEFTBRACKET) or 26,
    itemActionKey = (Keyboard and Keyboard.KEY_G) or 34,
    equipKey = (Keyboard and Keyboard.KEY_G) or 34,
    enableEatHotkey = true,
    eatAllKey = (Keyboard and Keyboard.KEY_G) or 34,
    enableReadHotkey = true,
    readKey = (Keyboard and Keyboard.KEY_G) or 34,
    enableFirstAidHotkey = true,
    firstAidKey = (Keyboard and Keyboard.KEY_G) or 34,
    enableFirstAidHUD = true,
    enableAmmoHotkey = true,
    ammoKey = (Keyboard and Keyboard.KEY_G) or 34,
    enableAutoWalk = true,
    autoWalkKey = (Keyboard and Keyboard.KEY_APOSTROPHE) or 40,
    autoWalkModifierKey = (Keyboard and Keyboard.KEY_RMENU) or 184,
    autoWalkAltW = true,
    autoWalkZombieSafety = true,
    autoWalkZombieRadius = 10,
    autoOpenDoors = true,
    fastForwardKeepAlive = true,
    fastForwardWhileMoving = false,
    enableMouseWheelZoom = true,
    invertZoom = false,
    zoomStep = 5.0,
    enableThirdPersonZoom = true,
    thirdPersonZoomStep = 0.15,
    smoothThirdPersonZoom = true,
    zoomFovModifierKey = (Keyboard and Keyboard.KEY_LCONTROL) or 29,
    enableHotbarWheel = true,
    hotbarModifierKey = (Keyboard and Keyboard.KEY_LSHIFT) or 42,
    invertHotbarScroll = false,
    hotbarCycleWhileRunning = true,
    enableContainerCraftHotkey = true,
    containerCraftKey = (Keyboard and Keyboard.KEY_B) or 48,
    classicCamera = false,
    disableCameraEffects = false,
    thirdPersonStrafe = false,
}

-- ====================================================================
-- Viewpoint QOL tab registration (native settings window, DELETE key)
-- These options are ALSO in the Mod Options page; both stay in sync.
-- ====================================================================

local viewpointToggles = {
    { "unlockOnOpen", "QOL/General", "Unlock mouse on inventory open", "Frees the cursor when opening inventory or loot." },
    { "lockOnClose", "QOL/General", "Auto-lock mouse on inventory close", "Locks back to camera look when inventory is closed." },
    { "uncollapseOnTab", "QOL/General", "Auto-uncollapse inventory on Tab", "Expands collapsed inventory windows when pressing Tab." },
    { "watchLoot", "QOL/General", "Include loot container window", "Keeps the cursor unlocked while the loot window is open." },
    { "closeWindowsOnManualLock", "QOL/General", "Close windows when locking cursor", "Locking the cursor also closes all open popup windows." },
    { "enableNotifications", "QOL/General", "On-screen notifications", "Show popup messages for auto-walk, loot menu, zombie slowdown, moved keybinds and bridge warnings. The injury alert HUD has its own toggle." },
    { "unlockOnRadial", "QOL/Mouse", "Unlock mouse on radial menus", "Frees the cursor for radial menus (vehicle, emote, firearm, light)." },
    { "unlockOnDevice", "QOL/Mouse", "Unlock mouse on appliances & popups", "Frees the cursor for ovens, radios, TVs, maps, context menus and dialogs." },
    { "enableHotbarWheel", "QOL/Mouse", "Enable modifier + wheel hotbar cycling", "Hold the modifier and scroll to cycle attached hotbar items." },
    { "invertHotbarScroll", "QOL/Mouse", "Invert hotbar cycle direction", "Reverses the wheel direction when cycling hotbar items." },
    { "hotbarCycleWhileRunning", "QOL/Mouse", "Cycle hotbar while running", "Allow modifier + wheel to equip hotbar items mid-sprint; off restores vanilla behavior (running cancels equipping)." },
    { "enableMouseWheelZoom", "QOL/Zoom", "Enable mouse wheel FOV zoom", "Scroll to adjust FOV zoom in 1st and 3rd person." },
    { "invertZoom", "QOL/Zoom", "Invert zoom scroll direction", "Reverses the wheel direction for camera zoom." },
    { "enableThirdPersonZoom", "QOL/Zoom", "Enable 3rd-person camera zoom", "Scroll to zoom the camera in third person; fully zoomed in switches to first person. Works on foot and in vehicles." },
    { "smoothThirdPersonZoom", "QOL/Zoom", "Smooth 3rd-person zoom", "Eases the camera in and out instead of stepping." },
    { "classicCamera", "QOL/Zoom", "Classic camera (less sway)", "Removes the new follow-camera float, sets Viewpoint's Camera motion to Off (default Medium) and disables automatic shoulder swap. Your previous values are restored when turned off." },
    { "disableCameraEffects", "QOL/Zoom", "Disable extra camera effects", "Removes Viewpoint's reaction camera moves: the bite push-in and wobble, the knockdown dip, the death cam and the climb/getup shifts. Viewpoint's own Camera motion setting still covers shake and weapon kick." },
    { "enableEquipHotkey", "QOL/Loot", "Enable container equip hotkey", "1-key equip prompt on highlighted items in containers." },
    { "enableEquipChooser", "QOL/Loot", "Show equip location chooser", "Pick where an item goes when it has multiple slots, or place weapons, tools and bags in a specific hand." },
    { "enableTakeChooser", "QOL/Loot", "Enable loot destination hotkey", "Choose where grabbed/looted items go." },
    { "enableLootMenuToggle", "QOL/Loot", "Enable loot menu toggle hotkey", "Hide or show Viewpoint's crosshair loot menu." },
    { "enableStoreAllHotkey", "QOL/Loot", "Enable store-all hotkey", "Send your inventory into the open or aimed container." },
    { "takeAllSkipFavorites", "QOL/Loot", "Protect favorites on Loot All", "Loot All skips items marked as favorites." },
    { "takeAllSkipKeys", "QOL/Loot", "Protect keys on Loot All", "Loot All skips key rings and keys." },
    { "enableContainersHotkey", "QOL/Loot", "Enable all-containers hotkey", "Show the loot from every container within reach while looking at a container." },
    { "enableEatHotkey", "QOL/Loot", "Enable eat & drink hotkeys", "Consume prompts and portion chooser for food and drinks." },
    { "enableReadHotkey", "QOL/Loot", "Enable read hotkey", "Read literature directly from containers." },
    { "enableAmmoHotkey", "QOL/Loot", "Enable ammo hotkey", "Unpack ammo and load magazines from containers." },
    { "enableFirstAidHotkey", "QOL/Loot", "Enable first-aid hotkey", "Bandage, disinfect or suture directly from containers." },
    { "enableFirstAidHUD", "QOL/Loot", "Enable injury alert prompt", "On-screen prompt when injured and carrying supplies." },
    { "enableContainerCraftHotkey", "QOL/Loot", "Enable container craft hotkey", "Open crafting pre-filtered to the highlighted ingredient." },
    { "enableAutoWalk", "QOL/Movement", "Enable hands-free auto-walk", "Toggle hands-free forward walking with mouse steering." },
    { "autoWalkAltW", "QOL/Movement", "Enable modifier + forward shortcut", "Modifier + forward key also toggles auto-walk (default Right Alt; Left Alt is the game's Sprint)." },
    { "autoWalkZombieSafety", "QOL/Movement", "Slow down near zombies", "Drop to normal speed while zombies are close, during auto-walk or manual fast-forward (radius tunable below)." },
    { "autoOpenDoors", "QOL/Movement", "Auto-open doors & gates while jogging", "When jogging or sprinting into a closed, unlocked door or gate, open it and keep your momentum. Locked or barricaded doors still stop you." },
    { "fastForwardKeepAlive", "QOL/Movement", "Keep fast-forward while auto-walking", "Keeps your fast-forward speed while auto-walking. Manual movement and Shift/Sprint drop back to normal, like vanilla." },
    { "fastForwardWhileMoving", "QOL/Movement", "Keep fast-forward during manual movement", "Keep the speed while walking, running, turning or sprinting; WASD and Shift/Sprint no longer drop fast-forward. The zombie safety above still applies." },
    { "thirdPersonStrafe", "QOL/Movement", "Third-person strafing", "Honor Viewpoint's Strafe movement setting in third person. Viewpoint forces turn-to-move there by design; enable to strafe and backpedal in 3rd person with the character turning with the camera, like in 1st." },
}

local viewpointNumbers = {
    { "zoomStep", "QOL/Zoom", "Zoom Step", 1, 20, 1, "How much each mouse wheel notch changes the camera FOV." },
    { "thirdPersonZoomStep", "QOL/Zoom", "3rd-Person Zoom Step", 0.05, 0.5, 0.05, "How much each mouse wheel notch zooms the third-person camera." },
    { "autoWalkZombieRadius", "QOL/Movement", "Zombie Slowdown Radius", 3, 30, 1, "Tiles: how close zombies must be for fast-forward to slow back to normal speed." },
}

local viewpointKeys = {
    { "lockCursorKey", "QOL/Hotkeys", "Lock Cursor Hotkey", "Optional key to lock the cursor to camera look." },
    { "hotbarModifierKey", "QOL/Hotkeys", "Hotbar Cycle Modifier", "Modifier held while scrolling to cycle hotbar items (default Shift)." },
    { "itemActionKey", "QOL/Hotkeys", "Item Action Key", "One key for all item actions on the highlighted item: equip, read, eat/drink, first aid, ammo. The action follows what you are looking at; split them individually in Mod Options." },
    { "lootCycleKey", "QOL/Hotkeys", "Choose Loot Destination Hotkey", "Choose where grabbed/looted items go." },
    { "lootMenuToggleKey", "QOL/Hotkeys", "Toggle Loot Menu Hotkey", "Hide or show the crosshair loot menu." },
    { "containerCraftKey", "QOL/Hotkeys", "Container Craft Hotkey", "Open crafting with the highlighted item." },
    { "autoWalkKey", "QOL/Hotkeys", "Auto-Walk Toggle Hotkey", "Toggle auto-walk." },
    { "autoWalkModifierKey", "QOL/Hotkeys", "Auto-Walk Shortcut Modifier", "Modifier held with the forward key to toggle auto-walk (default Right Alt; Left Alt is the game's Sprint)." },
    { "zoomFovModifierKey", "QOL/Hotkeys", "FOV Zoom Modifier", "Hold this key and scroll to adjust FOV (default CTRL)." },
    { "storeAllKey", "QOL/Hotkeys", "Store All Hotkey", "Optional dedicated key to store your inventory into the open or aimed container. Unbound by default; hold the All Containers key instead." },
    { "containersKey", "QOL/Hotkeys", "All Containers Hotkey", "Tap to toggle between the aimed container and every container within reach; hold to store your inventory into the open or aimed container (default [)." },
}

local function viewpointApi()
    local api = ViewpointQOLSettings
    if api and api.isAvailable and api.isAvailable() then
        return api
    end
    return nil
end

function ProjectViewpointQOLOptions.registerViewpoint()
    if ProjectViewpointQOLOptions.viewpointAvailable == true then
        return true
    end

    local api = viewpointApi()
    if not api then
        ProjectViewpointQOLOptions.viewpointAvailable = false
        if not ProjectViewpointQOLOptions.viewpointApiWarned then
            ProjectViewpointQOLOptions.viewpointApiWarned = true
            print("[ProjectViewpointQOL] Viewpoint settings API not available yet; will retry (Mod Options still works).")
        end
        return false
    end
    ProjectViewpointQOLOptions.viewpointKeyPushed = {}

    local allOk = true
    for _, def in ipairs(viewpointToggles) do
        local ok = api.registerToggle("qol." .. def[1], def[3], def[2], ProjectViewpointQOLOptions[def[1]] ~= false, def[4])
        if not ok then allOk = false end
    end
    for _, def in ipairs(viewpointNumbers) do
        local ok = api.registerNumber("qol." .. def[1], def[3], def[2], def[4], def[5], def[6],
            ProjectViewpointQOLOptions[def[1]] or 5, def[7])
        if not ok then allOk = false end
    end
    for _, def in ipairs(viewpointKeys) do
        local ok = api.registerKey("qol." .. def[1], def[3], def[2], ProjectViewpointQOLOptions[def[1]] or 0, def[4])
        if not ok then allOk = false end
    end

    ProjectViewpointQOLOptions.viewpointAvailable = allOk
    if allOk then
        if not ProjectViewpointQOLOptions.viewpointRegisteredLogged then
            ProjectViewpointQOLOptions.viewpointRegisteredLogged = true
            print("[ProjectViewpointQOL] Options registered in Viewpoint's QOL tab (also available in Mod Options).")
        end
    elseif not ProjectViewpointQOLOptions.viewpointRegisterWarned then
        ProjectViewpointQOLOptions.viewpointRegisterWarned = true
        print("[ProjectViewpointQOL] Some Viewpoint settings failed to register; Mod Options still has everything.")
    end
    return allOk
end

function ProjectViewpointQOLOptions.mirrorToPZAPI()
    local page = ProjectViewpointQOLOptions.page
    if not (page and page.getOption) then return end
    local function mirror(def)
        local opt = page:getOption(def[1])
        if opt and opt.setValue then
            opt:setValue(ProjectViewpointQOLOptions[def[1]])
        end
    end
    for _, def in ipairs(viewpointToggles) do mirror(def) end
    for _, def in ipairs(viewpointNumbers) do mirror(def) end
    for _, def in ipairs(viewpointKeys) do mirror(def) end
    if PZAPI and PZAPI.ModOptions and PZAPI.ModOptions.save then
        pcall(function() PZAPI.ModOptions:save() end)
    end
end

function ProjectViewpointQOLOptions.pullFromViewpoint()
    if not ProjectViewpointQOLOptions.viewpointAvailable then return end
    local api = viewpointApi()
    if not api then
        ProjectViewpointQOLOptions.viewpointAvailable = false
        return
    end

    local changed = false
    for _, def in ipairs(viewpointToggles) do
        local value = api.getToggle("qol." .. def[1]) == true
        if ProjectViewpointQOLOptions[def[1]] ~= value then
            ProjectViewpointQOLOptions[def[1]] = value
            changed = true
        end
    end
    for _, def in ipairs(viewpointNumbers) do
        local value = api.getNumber("qol." .. def[1])
        if ProjectViewpointQOLOptions[def[1]] ~= value then
            ProjectViewpointQOLOptions[def[1]] = value
            changed = true
        end
    end
    local sharedActionChanged = false
    for _, def in ipairs(viewpointKeys) do
        local id = def[1]
        local code = api.getKeyCode("qol." .. id)
        local pushed = ProjectViewpointQOLOptions.viewpointKeyPushed[id]
        local current = ProjectViewpointQOLOptions[id] or 0
        if pushed == nil then
            -- First sync: Viewpoint wins unless it cannot represent a mouse bind
            if code == 0 and current >= 10000 then
                ProjectViewpointQOLOptions.viewpointKeyPushed[id] = 0
            else
                if current ~= code then
                    ProjectViewpointQOLOptions[id] = code
                    changed = true
                end
                ProjectViewpointQOLOptions.viewpointKeyPushed[id] = code
            end
        elseif code ~= pushed then
            if current ~= code then
                ProjectViewpointQOLOptions[id] = code
                changed = true
                if id == "itemActionKey" then sharedActionChanged = true end
            end
            ProjectViewpointQOLOptions.viewpointKeyPushed[id] = code
        end
    end

    if sharedActionChanged then
        -- The single Item Action row was changed in the Viewpoint tab: apply
        -- it to every action it drives (equip, read, eat, first aid, ammo).
        ProjectViewpointQOLOptions.applyItemActionKey()
    end

    if changed then
        ProjectViewpointQOLOptions.mirrorToPZAPI()
    end
    ProjectViewpointQOLOptions.applyClassicCamera()
    ProjectViewpointQOLOptions.applyThirdPersonStrafe()
    ProjectViewpointQOLOptions.applyCameraEffects()
end

function ProjectViewpointQOLOptions.pushToViewpoint()
    if not ProjectViewpointQOLOptions.viewpointAvailable then return end
    local api = viewpointApi()
    if not api then return end
    -- Keep the single Item Action row on the primary action key: it matches
    -- the shared value unless the player split the actions in Mod Options.
    if (ProjectViewpointQOLOptions.equipKey or 0) > 0 then
        ProjectViewpointQOLOptions.itemActionKey = ProjectViewpointQOLOptions.equipKey
    end
    for _, def in ipairs(viewpointToggles) do
        api.setToggle("qol." .. def[1], ProjectViewpointQOLOptions[def[1]] ~= false)
    end
    for _, def in ipairs(viewpointNumbers) do
        api.setNumber("qol." .. def[1], ProjectViewpointQOLOptions[def[1]] or 5)
    end
    for _, def in ipairs(viewpointKeys) do
        local id = def[1]
        api.setKey("qol." .. id, ProjectViewpointQOLOptions[id] or 0)
        ProjectViewpointQOLOptions.viewpointKeyPushed[id] = api.getKeyCode("qol." .. id)
    end
    api.save()
end

function ProjectViewpointQOLOptions.applyOptionsFromPZAPI()
    local page = ProjectViewpointQOLOptions.page
    if not (page and page.getOption) then return end
    local function read(def)
        local opt = page:getOption(def[1])
        if opt and opt.getValue then
            ProjectViewpointQOLOptions[def[1]] = opt:getValue()
        end
    end
    for _, def in ipairs(viewpointToggles) do read(def) end
    for _, def in ipairs(viewpointNumbers) do read(def) end
    for _, def in ipairs(viewpointKeys) do read(def) end
    ProjectViewpointQOLOptions.applyClassicCamera()
    ProjectViewpointQOLOptions.applyThirdPersonStrafe()
    ProjectViewpointQOLOptions.applyCameraEffects()
end

-- "Classic camera": Viewpoint 0.1.6's third-person camera floats around the
-- character (a spring-follow lag), sways ("Camera motion", default Medium) and
-- swaps shoulders automatically. This preset removes the float (the Follow
-- patches zero the spring lag while the flag is set), turns the motion off and
-- restores the player's previous values when the toggle is turned back off.
-- Motion: 0 Off, 1 Low, 2 Medium, 3 High.
function ProjectViewpointQOLOptions.applyClassicCamera()
    local api = ViewpointQOLCamera
    if not (api and api.isAvailable and api.isAvailable()) then return end
    local want = ProjectViewpointQOLOptions.classicCamera == true
    local applied = ProjectViewpointQOLOptions.classicCameraApplied == true
    if want then
        if not ProjectViewpointQOLOptions.classicCameraSaved then
            if ProjectViewpointQOLOptions.classicCameraApplied == nil then
                -- Enabled in a previous session: the current values are already
                -- this preset's, so the restore target is Viewpoint's defaults.
                ProjectViewpointQOLOptions.classicCameraSaved = { motion = 2, autoSwap = true }
            else
                -- Just enabled in this session: keep the player's own values.
                ProjectViewpointQOLOptions.classicCameraSaved = {
                    motion = api.getMotion(),
                    autoSwap = api.isAutoSwap(),
                }
            end
        end
        ProjectViewpointQOLOptions.classicCameraApplied = true
        if api.getMotion() ~= 0 then
            api.setMotion(0)
            print("[ProjectViewpointQOL] Classic camera: Camera motion set to Off.")
        end
        if api.isAutoSwap() then
            api.setAutoSwap(false)
            print("[ProjectViewpointQOL] Classic camera: automatic shoulder swap turned off.")
        end
    elseif applied then
        local saved = ProjectViewpointQOLOptions.classicCameraSaved
        ProjectViewpointQOLOptions.classicCameraApplied = false
        ProjectViewpointQOLOptions.classicCameraSaved = nil
        api.setMotion((saved and saved.motion) or 2)
        api.setAutoSwap(not saved or saved.autoSwap ~= false)
        print("[ProjectViewpointQOL] Classic camera off: previous camera motion and shoulder swap restored.")
    else
        ProjectViewpointQOLOptions.classicCameraApplied = false
    end
    if api.setClassicActive then
        api.setClassicActive(want)
    end
end

-- Opt-in third-person strafing: hand the toggle to the Java Locomotion patch,
-- which honors Viewpoint's Strafe movement setting in third person instead of
-- the forced turn-to-move orbit.
function ProjectViewpointQOLOptions.applyThirdPersonStrafe()
    local api = ViewpointQOLStrafe
    if not (api and api.setEnabled) then return end
    local want = ProjectViewpointQOLOptions.thirdPersonStrafe == true
    if ProjectViewpointQOLOptions.thirdPersonStrafeApplied ~= want then
        ProjectViewpointQOLOptions.thirdPersonStrafeApplied = want
        pcall(function() api.setEnabled(want) end)
        if want then
            print("[ProjectViewpointQOL] Third-person strafing enabled (Viewpoint's Strafe setting is now honored in 3rd person).")
        end
    end
end

-- "Disable extra camera effects": hand the toggle to the Java Beats patch,
-- which skips and clears Viewpoint's reaction camera moves (bite, knockdown,
-- death, climb/getup) so the camera stays on the player's own framing.
function ProjectViewpointQOLOptions.applyCameraEffects()
    local api = ViewpointQOLCamera
    if not (api and api.setBeatsDisabled) then return end
    local want = ProjectViewpointQOLOptions.disableCameraEffects == true
    if ProjectViewpointQOLOptions.cameraEffectsApplied ~= want then
        ProjectViewpointQOLOptions.cameraEffectsApplied = want
        pcall(function() api.setBeatsDisabled(want) end)
        print(want and "[ProjectViewpointQOL] Extra camera effects disabled (bite, knockdown, death, climb/getup)."
            or "[ProjectViewpointQOL] Extra camera effects enabled.")
    end
end

-- The five item actions (equip, read, eat/drink, first aid, ammo) share one
-- key by default, but Viewpoint's key editor only allows a key on a single
-- bind: editing them there used to unbind the others. The Viewpoint tab now
-- exposes one Item Action row; these helpers keep the five in step with it.
function ProjectViewpointQOLOptions.applyItemActionKey()
    local shared = ProjectViewpointQOLOptions.itemActionKey or 0
    if shared <= 0 then return end
    for _, id in ipairs({ "equipKey", "eatAllKey", "readKey", "firstAidKey", "ammoKey" }) do
        ProjectViewpointQOLOptions[id] = shared
    end
end

-- Load-time seeding and self-heal for the shared item actions: seed the Item
-- Action key from the values the player already had, and restore any action
-- key that lost its bind (set to none) instead of needing a reinstall.
function ProjectViewpointQOLOptions.migrateItemActionKey()
    local ids = { "equipKey", "eatAllKey", "readKey", "firstAidKey", "ammoKey" }
    local shared = ProjectViewpointQOLOptions.itemActionKey or 0
    if shared <= 0 then
        local allSame = true
        local first = nil
        for _, id in ipairs(ids) do
            local value = ProjectViewpointQOLOptions[id] or 0
            if value > 0 then
                if first == nil then
                    first = value
                elseif value ~= first then
                    allSame = false
                end
            end
        end
        shared = (allSame and first) or ProjectViewpointQOLOptions.equipKey or 0
        if shared <= 0 then shared = (Keyboard and Keyboard.KEY_G) or 34 end
        ProjectViewpointQOLOptions.itemActionKey = shared
    end
    local healed = false
    for _, id in ipairs(ids) do
        if (ProjectViewpointQOLOptions[id] or 0) <= 0 then
            ProjectViewpointQOLOptions[id] = shared
            healed = true
        end
    end
    if healed then
        print("[ProjectViewpointQOL] Restored the shared Item Action key for item actions that had lost their bind.")
        ProjectViewpointQOLOptions.mirrorToPZAPI()
    end
end

-- One-time bind consolidation: only when every affected bind is still the
-- factory value (U / R / Left Bracket) do we move them to the merged defaults
-- (first aid and ammo share G; Store All is held on the All Containers key).
function ProjectViewpointQOLOptions.migrateBindings()
    local oldFirstAid = (Keyboard and Keyboard.KEY_U) or 22
    local oldAmmo = (Keyboard and Keyboard.KEY_R) or 19
    local oldStoreAll = (Keyboard and Keyboard.KEY_LEFTBRACKET) or 26
    if ProjectViewpointQOLOptions.firstAidKey ~= oldFirstAid
        or ProjectViewpointQOLOptions.ammoKey ~= oldAmmo
        or ProjectViewpointQOLOptions.storeAllKey ~= oldStoreAll then
        return
    end
    local actionKey = (Keyboard and Keyboard.KEY_G) or 34
    ProjectViewpointQOLOptions.firstAidKey = actionKey
    ProjectViewpointQOLOptions.ammoKey = actionKey
    ProjectViewpointQOLOptions.storeAllKey = 0
    ProjectViewpointQOLOptions.mirrorToPZAPI()
    ProjectViewpointQOLOptions.pushToViewpoint()
    print("[ProjectViewpointQOL] Merged default hotkeys: first aid and ammo now share G; Store All is held on the All Containers key.")
end

-- Viewpoint 0.1.6 put "Third person: swap shoulders" on the semicolon, which
-- was our All Containers key. The All Containers default moved to the left
-- bracket (its old Store All key, free again since the merge above). One-time
-- move for factory binds only; a rebound key is left alone.
function ProjectViewpointQOLOptions.migrateContainersKey()
    local semicolon = (Keyboard and Keyboard.KEY_SEMICOLON) or 39
    local leftbracket = (Keyboard and Keyboard.KEY_LEFTBRACKET) or 26
    if ProjectViewpointQOLOptions.containersKey ~= semicolon then return end
    ProjectViewpointQOLOptions.containersKey = leftbracket
    ProjectViewpointQOLOptions.mirrorToPZAPI()
    ProjectViewpointQOLOptions.pushToViewpoint()
    print("[ProjectViewpointQOL] All Containers key moved from ; to [ (Viewpoint 0.1.6 uses ; for the shoulder swap).")
end

-- Viewpoint Advanced Movement (workshop id 3812702301) claims Left Alt for
-- free look and rebinds the vanilla actions on its keys; detect it so our
-- Alt-based defaults can step aside.
function ProjectViewpointQOLOptions.isVPAMActive()
    local mods = getActivatedMods and getActivatedMods()
    if not mods then return false end
    local ok, has = pcall(function() return mods:contains("ViewpointAdvancedMovement") end)
    return ok and has == true
end

-- The hotbar cycling modifier default moved from Left Alt to Left Shift
-- (Left Alt is free look in Viewpoint Advanced Movement and is used by other
-- mods). One-time move for factory binds only.
function ProjectViewpointQOLOptions.migrateHotbarToShift()
    local lmenu = (Keyboard and Keyboard.KEY_LMENU) or 56
    local lshift = (Keyboard and Keyboard.KEY_LSHIFT) or 42
    if ProjectViewpointQOLOptions.hotbarModifierKey ~= lmenu then return end
    ProjectViewpointQOLOptions.hotbarModifierKey = lshift
    ProjectViewpointQOLOptions.mirrorToPZAPI()
    ProjectViewpointQOLOptions.pushToViewpoint()
    print("[ProjectViewpointQOL] Hotbar cycling modifier moved to Left Shift (Shift+wheel).")
end

-- Left Alt is the game's Sprint, so the Auto-Walk shortcut modifier default
-- moved to Right Alt (matched exactly). One-time move for factory binds.
function ProjectViewpointQOLOptions.migrateAutoWalkModifier()
    local lmenu = (Keyboard and Keyboard.KEY_LMENU) or 56
    local rmenu = (Keyboard and Keyboard.KEY_RMENU) or 184
    if ProjectViewpointQOLOptions.autoWalkModifierKey ~= lmenu then return end
    ProjectViewpointQOLOptions.autoWalkModifierKey = rmenu
    ProjectViewpointQOLOptions.mirrorToPZAPI()
    ProjectViewpointQOLOptions.pushToViewpoint()
    print("[ProjectViewpointQOL] Auto-Walk shortcut modifier moved to Right Alt (Left Alt is the game's Sprint).")
end

-- Compatibility when Viewpoint Advanced Movement is active: keep the Auto-Walk
-- shortcut but move it off Left Alt (free look in VPAM 1.3.2 and older; the
-- game's Sprint again in 1.3.3) to Right Alt, which is matched exactly. Also
-- re-enables the shortcut if an earlier version turned it off.
function ProjectViewpointQOLOptions.migrateForVPAM()
    if not ProjectViewpointQOLOptions.isVPAMActive() then return end
    local lmenu = (Keyboard and Keyboard.KEY_LMENU) or 56
    local rmenu = (Keyboard and Keyboard.KEY_RMENU) or 184
    if ProjectViewpointQOLOptions.autoWalkModifierKey ~= lmenu then return end
    ProjectViewpointQOLOptions.autoWalkModifierKey = rmenu
    ProjectViewpointQOLOptions.autoWalkAltW = true
    ProjectViewpointQOLOptions.mirrorToPZAPI()
    ProjectViewpointQOLOptions.pushToViewpoint()
    print("[ProjectViewpointQOL] Viewpoint Advanced Movement detected: Auto-Walk shortcut moved to Right Alt (Left Alt is the game's Sprint again in VPAM 1.3.3).")
end

-- Keep the grab key on F (Viewpoint's default) with or without Viewpoint
-- Advanced Movement. E collides with VPAM's lean right and the old auto-move
-- used I, which fights inventory keys for some players.
function ProjectViewpointQOLOptions.ensureViewpointTakeKey()
    if ProjectViewpointQOLOptions.takeKeyEnsured then return end
    local vk = Viewpoint and Viewpoint.Keys
    if not (vk and vk.get and vk.trigger and vk.set and vk.captured) then return end
    local function codeOf(id)
        local text = vk.get(id)
        if not text or text == "" then return 0 end
        return tonumber(vk.trigger(text)) or 0
    end
    local fKey = (Keyboard and Keyboard.KEY_F) or 33
    local code = codeOf("keys.lootTake")
    if code == fKey then
        ProjectViewpointQOLOptions.takeKeyEnsured = true
        return
    end
    -- Only move the known problem keys (E = VPAM lean right, I = the earlier
    -- auto-move, unbound); other deliberate choices are left alone.
    if code == 18 or code == 23 or code == 0 then
        local text = vk.captured(fKey)
        if text and text ~= "" then
            vk.set("keys.lootTake", text)
            local oldName = (code ~= 0 and getKeyName(code)) or "none"
            print("[ProjectViewpointQOL] Viewpoint grab key set to F (was " .. oldName .. ").")
        end
    end
    ProjectViewpointQOLOptions.takeKeyEnsured = true
end

-- Viewpoint's keys and Viewpoint Advanced Movement's actions can collide (for
-- example Viewpoint take on E with VPAM lean right on E). VPAM reads the raw
-- key in Java, so the Viewpoint key is moved to a free key instead.
function ProjectViewpointQOLOptions.resolveVPAMKeyCollisions()
    if ProjectViewpointQOLOptions.vpamKeysResolved then return end
    if not ProjectViewpointQOLOptions.isVPAMActive() then
        ProjectViewpointQOLOptions.vpamKeysResolved = true
        return
    end
    local viewKeys = Viewpoint and Viewpoint.Keys
    if not (viewKeys and viewKeys.get and viewKeys.trigger and viewKeys.set) then return end

    local function codeOf(id)
        local text = viewKeys.get(id)
        if not text or text == "" then return 0 end
        return tonumber(viewKeys.trigger(text)) or 0
    end

    local page = nil
    if PZAPI and PZAPI.ModOptions and PZAPI.ModOptions.getOptions then
        page = PZAPI.ModOptions:getOptions("ViewpointAdvancedMovement")
    end
    ProjectViewpointQOLOptions.vpamResolveTries = (ProjectViewpointQOLOptions.vpamResolveTries or 0) + 1
    if not page and ProjectViewpointQOLOptions.vpamResolveTries < 12 then
        return -- options page not loaded yet; retry from onTick
    end

    local defaults = {
        -- Viewpoint Advanced Movement 1.3.3: free look is Viewpoint's own key
        -- (Mouse 4 default) and its floor attack is back on Left Alt, so the
        -- only VPAM action keys left are these.
        leanLeft = (Keyboard and Keyboard.KEY_Q) or 16,
        leanRight = (Keyboard and Keyboard.KEY_E) or 18,
        jump = (Keyboard and Keyboard.KEY_SPACE) or 57,
    }
    local function vpamKey(id)
        local opt = page and page.getOption and page:getOption(id) or nil
        if opt then
            if type(opt.element) == "table" and opt.element.keyCode ~= nil then
                local k = tonumber(opt.element.keyCode) or 0
                if k > 0 then return k end
            end
            if opt.getValue then
                local k = tonumber(opt:getValue()) or 0
                if k > 0 then return k end
            end
        end
        return defaults[id] or 0
    end

    local vpam = {}
    for _, id in ipairs({ "leanLeft", "leanRight", "jump" }) do
        local k = vpamKey(id)
        if k and k > 0 then vpam[k] = id end
    end

    -- Never land on keys someone else uses (Viewpoint, ours, or VPAM's moved
    -- vanilla actions: F, Z, N, Caps, Left Alt, Mouse 3/4/5).
    local used = {}
    for _, id in ipairs({ "keys.lootTake", "keys.lootTakeAll", "keys.lootWindow", "keys.firstPerson", "keys.thirdPerson", "keys.shoulderSwap", "keys.cameraBehind", "keys.freeLook", "keys.cursor", "keys.settings", "keys.freeCamera" }) do
        local c = codeOf(id)
        if c > 0 then used[c] = true end
    end
    for _, id in ipairs({ "equipKey", "eatAllKey", "readKey", "firstAidKey", "ammoKey", "containerCraftKey", "lootCycleKey", "lootMenuToggleKey", "storeAllKey", "containersKey", "autoWalkKey", "hotbarModifierKey", "autoWalkModifierKey", "zoomFovModifierKey" }) do
        local c = tonumber(ProjectViewpointQOLOptions[id]) or 0
        if c > 0 then used[c] = true end
    end
    for _, c in ipairs({ 33, 44, 49, 56, 58, 10003, 10004 }) do used[c] = true end -- F, Z, N, LAlt, Caps, Mouse 3/4

    local candidates = { 26, 51, 53, 43 } -- [, comma, slash, backslash

    for _, id in ipairs({ "keys.lootTake", "keys.lootTakeAll", "keys.lootWindow" }) do
        local code = codeOf(id)
        if code > 0 and vpam[code] then
            local replacement = nil
            if id == "keys.lootTake" then
                -- Grab stays on F per the author's setup; skip if already there.
                local fKey = (Keyboard and Keyboard.KEY_F) or 33
                if code ~= fKey then replacement = fKey end
            else
                for _, c in ipairs(candidates) do
                    if not used[c] and not vpam[c] then
                        replacement = c
                        break
                    end
                end
            end
            if replacement and viewKeys.captured then
                local text = viewKeys.captured(replacement)
                if text and text ~= "" then
                    local oldName = getKeyName(code) or tostring(code)
                    local newName = getKeyName(replacement) or tostring(replacement)
                    viewKeys.set(id, text)
                    used[replacement] = true
                    print("[ProjectViewpointQOL] Viewpoint Advanced Movement: moved Viewpoint " .. id .. " from " .. oldName .. " to " .. newName .. " (conflict with " .. vpam[code] .. ").")
                    local player = getSpecificPlayer and getSpecificPlayer(0) or nil
                    if ProjectViewpointQOL and ProjectViewpointQOL.notify then
                        ProjectViewpointQOL.notify(player, "Advanced Movement conflict: moved Viewpoint " .. id .. " from " .. oldName .. " to " .. newName, "bad")
                    end
                end
            else
                print("[ProjectViewpointQOL] Viewpoint Advanced Movement: no free key to move " .. id .. " off " .. tostring(vpam[code]) .. "; rebind one of them manually.")
            end
        end
    end
    ProjectViewpointQOLOptions.vpamKeysResolved = true
end

function ProjectViewpointQOLOptions.setupViewpoint()
    if ProjectViewpointQOLOptions.viewpointSetup then return end
    if ProjectViewpointQOLOptions.registerViewpoint() then
        ProjectViewpointQOLOptions.viewpointSetup = true
        ProjectViewpointQOLOptions.pullFromViewpoint()
        ProjectViewpointQOLOptions.migrateBindings()
        ProjectViewpointQOLOptions.migrateHotbarToShift()
        ProjectViewpointQOLOptions.migrateAutoWalkModifier()
        ProjectViewpointQOLOptions.migrateForVPAM()
        ProjectViewpointQOLOptions.migrateItemActionKey()
        ProjectViewpointQOLOptions.ensureViewpointTakeKey()
        ProjectViewpointQOLOptions.resolveVPAMKeyCollisions()
    end
end

local function installOptions()
    if not (PZAPI and PZAPI.ModOptions) then return end
    if ProjectViewpointQOLOptions.page then return end

    local page = PZAPI.ModOptions:create("ProjectViewpointQOL", "Project Viewpoint QOL")
    ProjectViewpointQOLOptions.page = page

    page:addTitle("Inventory Mouse Control")

    local optUnlock = page:addTickBox("unlockOnOpen", "Unlock mouse on inventory open", ProjectViewpointQOLOptions.unlockOnOpen,
        "Automatically frees the mouse cursor when opening player inventory or loot.")
    local optLock = page:addTickBox("lockOnClose", "Auto-lock mouse on inventory close", ProjectViewpointQOLOptions.lockOnClose,
        "Automatically locks the mouse cursor back to camera look when inventory is closed.")
    local optUncollapse = page:addTickBox("uncollapseOnTab", "Auto-uncollapse inventory on Tab", ProjectViewpointQOLOptions.uncollapseOnTab,
        "Automatically expands collapsed inventory windows when pressing Tab.")
    local optWatchLoot = page:addTickBox("watchLoot", "Include loot container window", ProjectViewpointQOLOptions.watchLoot,
        "Keeps the mouse unlocked while either player inventory or loot container window is open.")
    local optCloseOnLock = page:addTickBox("closeWindowsOnManualLock", "Close windows when locking cursor", ProjectViewpointQOLOptions.closeWindowsOnManualLock,
        "When the mouse cursor is unlocked, pressing a lock key (middle mouse or the Lock Cursor Hotkey below) also closes all open popup windows. Off by default: locking normally keeps your inventory and container panels open.")
    local optLockKey = nil
    if page.addKeyBind then
        optLockKey = page:addKeyBind("lockCursorKey", "Lock Cursor Hotkey", ProjectViewpointQOLOptions.lockCursorKey or 0,
            "Optional extra key to lock the cursor to camera look (and close popups if the option above is enabled). Middle mouse always works. Unbound by default.")
    end
    local optNotifications = page:addTickBox("enableNotifications", "On-screen notifications", ProjectViewpointQOLOptions.enableNotifications,
        "Show popup messages for auto-walk, loot menu, zombie slowdown, moved keybinds and bridge warnings. The injury alert HUD has its own toggle.")

    page:addTitle("Radial & Wheel Menus")

    local optRadial = page:addTickBox("unlockOnRadial", "Unlock mouse on radial menus", ProjectViewpointQOLOptions.unlockOnRadial,
        "Automatically frees the mouse cursor when opening radial menus (such as vehicle menu 'V', emote wheel 'Q', firearm menu 'R', or light source menu 'F').")

    page:addTitle("Appliance, Device & Interaction Windows")

    local optDevice = page:addTickBox("unlockOnDevice", "Unlock mouse on appliances, devices & popups", ProjectViewpointQOLOptions.unlockOnDevice,
        "Automatically frees the mouse cursor when interacting with ovens, stoves, microwaves, televisions, radios, context menus, vehicle mechanics, and modal dialogs.")

    page:addTitle("FOV Camera Zoom (1st & 3rd Person)")

    local optZoom = page:addTickBox("enableMouseWheelZoom", "Enable FOV Camera Zoom", ProjectViewpointQOLOptions.enableMouseWheelZoom,
        "Scroll mouse wheel to adjust FOV zoom independently in first-person and third-person modes without switching perspectives. Auto-suppressed on containers and menus.")
    local optInvertZoom = page:addTickBox("invertZoom", "Invert Zoom Scroll Direction", ProjectViewpointQOLOptions.invertZoom,
        "Inverts the scroll wheel direction for camera zoom (Wheel Up = Zoom Out instead of Zoom In).")
    local optZoomStep = nil
    if page.addSlider then
        optZoomStep = page:addSlider("zoomStep", "Zoom Step", 1, 20, 1, ProjectViewpointQOLOptions.zoomStep or 5,
            "How much each mouse wheel notch changes the camera FOV.")
    end
    local optThirdPersonZoom = page:addTickBox("enableThirdPersonZoom", "Enable 3rd-person camera zoom", ProjectViewpointQOLOptions.enableThirdPersonZoom,
        "In third person, scroll the mouse wheel to move the camera in and out. Zooming all the way in switches seamlessly to first person. Works on foot and in vehicles.")
    local optThirdPersonStep = nil
    if page.addSlider then
        optThirdPersonStep = page:addSlider("thirdPersonZoomStep", "3rd-Person Zoom Step", 0.05, 0.5, 0.05, ProjectViewpointQOLOptions.thirdPersonZoomStep or 0.15,
            "How much each mouse wheel notch zooms the third-person camera.")
    end
    local optZoomModKey = nil
    if page.addKeyBind then
        optZoomModKey = page:addKeyBind("zoomFovModifierKey", "FOV Zoom Modifier", ProjectViewpointQOLOptions.zoomFovModifierKey or ((Keyboard and Keyboard.KEY_LCONTROL) or 29),
            "Hold this key and scroll the mouse wheel to adjust FOV instead of zooming the camera (default CTRL).")
    end
    local optSmoothZoom = page:addTickBox("smoothThirdPersonZoom", "Smooth 3rd-person zoom", ProjectViewpointQOLOptions.smoothThirdPersonZoom,
        "Eases the third-person camera in and out instead of stepping instantly.")
    local optClassicCamera = page:addTickBox("classicCamera", "Classic camera (less sway)", ProjectViewpointQOLOptions.classicCamera,
        "Removes the new follow-camera float, sets Viewpoint's Camera motion to Off (default Medium) and disables automatic shoulder swap. Your previous values are restored when turned off.")
    local optDisableCameraEffects = page:addTickBox("disableCameraEffects", "Disable extra camera effects", ProjectViewpointQOLOptions.disableCameraEffects,
        "Removes Viewpoint's reaction camera moves: the bite push-in and wobble, the knockdown dip, the death cam and the climb/getup shifts. Viewpoint's own Camera motion setting still covers shake and weapon kick.")

    page:addTitle("Hotbar Cycling (Modifier + Mouse Wheel)")

    local optHotbarWheel = page:addTickBox("enableHotbarWheel", "Enable Modifier + Mouse Wheel Hotbar Cycling", ProjectViewpointQOLOptions.enableHotbarWheel,
        "Hold the configured modifier key (default Shift) and scroll the mouse wheel to cycle equipping attached weapons/items from your hotbar.")
    local optHotbarModKey = nil
    if page.addKeyBind then
        optHotbarModKey = page:addKeyBind("hotbarModifierKey", "Hotbar Cycle Modifier", ProjectViewpointQOLOptions.hotbarModifierKey or ((Keyboard and Keyboard.KEY_LSHIFT) or 42),
            "Modifier key held while scrolling the mouse wheel to cycle hotbar items (default Shift).")
    end
    local optInvertHotbar = page:addTickBox("invertHotbarScroll", "Invert Hotbar Cycle Direction", ProjectViewpointQOLOptions.invertHotbarScroll,
        "Inverts scroll wheel direction when cycling hotbar items.")
    local optCycleWhileRunning = page:addTickBox("hotbarCycleWhileRunning", "Cycle Hotbar While Running", ProjectViewpointQOLOptions.hotbarCycleWhileRunning,
        "Allow modifier + wheel to equip hotbar items mid-sprint. Off restores vanilla behavior, where running cancels the equip.")

    page:addTitle("Container Loot & Equip")

    local optEquip = page:addTickBox("enableEquipHotkey", "Enable Container Equip Hotkey", ProjectViewpointQOLOptions.enableEquipHotkey,
        "When looking at an equippable item in a container or floor loot, adds an Equip prompt and allows 1-key equipping.")

    local defaultKey = (Keyboard and Keyboard.KEY_G) or 34
    local optEquipKey = nil
    if page.addKeyBind then
        optEquipKey = page:addKeyBind("equipKey", "Equip Hotkey", ProjectViewpointQOLOptions.equipKey or defaultKey,
            "Key to equip the highlighted item directly from containers.")
    end

    local optEquipChooser = page:addTickBox("enableEquipChooser", "Show equip location chooser", ProjectViewpointQOLOptions.enableEquipChooser,
        "Open a chooser instead of equipping to the default spot: multi-slot clothing and attachments (back, belt, holster, fanny pack front/back, hood up/down, ...), and primary/secondary hand placement for weapons, tools and bags.")
    local optTakeChooser = page:addTickBox("enableTakeChooser", "Enable loot destination hotkey", ProjectViewpointQOLOptions.enableTakeChooser,
        "Press the Choose Loot Destination key while looting (Viewpoint crosshair or the loot window) to pick where grabbed/looted items go: your inventory or a specific equipped bag. The current destination is shown in the loot hint.")

    local optLootCycleKey = nil
    if page.addKeyBind then
        optLootCycleKey = page:addKeyBind("lootCycleKey", "Choose Loot Destination Hotkey", ProjectViewpointQOLOptions.lootCycleKey or ((Keyboard and Keyboard.KEY_V) or 47),
            "Key to choose where grabbed/looted items go (inventory or an equipped bag) while looting.")
    end

    local optLootToggle = page:addTickBox("enableLootMenuToggle", "Enable loot menu toggle hotkey", ProjectViewpointQOLOptions.enableLootMenuToggle,
        "Press the Toggle Loot Menu key to instantly hide or show Viewpoint's crosshair loot menu. Useful to stop hover popups and stutter while running through the open or passing through buildings. Syncs with Viewpoint's own 'Show the loot menu' option.")
    local optLootToggleKey = nil
    if page.addKeyBind then
        optLootToggleKey = page:addKeyBind("lootMenuToggleKey", "Toggle Loot Menu Hotkey", ProjectViewpointQOLOptions.lootMenuToggleKey or ((Keyboard and Keyboard.KEY_K) or 37),
            "Key to hide or show Viewpoint's crosshair loot menu.")
    end
    local optStoreAll = page:addTickBox("enableStoreAllHotkey", "Enable store-all hotkey", ProjectViewpointQOLOptions.enableStoreAllHotkey,
        "Send everything from your inventory into the open loot window's container, or into the container you are aiming at with Viewpoint's crosshair. Hold the All Containers key, or press the Store All key if you bind one.")
    local optStoreAllKey = nil
    if page.addKeyBind then
        optStoreAllKey = page:addKeyBind("storeAllKey", "Store All Hotkey", ProjectViewpointQOLOptions.storeAllKey or ((Keyboard and Keyboard.KEY_NONE) or 0),
            "Optional dedicated Store All key (unbound by default; hold the All Containers key instead).")
    end
    local optSkipFavorites = page:addTickBox("takeAllSkipFavorites", "Protect favorites on Loot All", ProjectViewpointQOLOptions.takeAllSkipFavorites,
        "Viewpoint's Loot All (and the loot window's Loot all) skips items marked as favorites.")
    local optSkipKeys = page:addTickBox("takeAllSkipKeys", "Protect keys on Loot All", ProjectViewpointQOLOptions.takeAllSkipKeys,
        "Viewpoint's Loot All (and the loot window's Loot all) skips key rings and keys.")
    local optContainers = page:addTickBox("enableContainersHotkey", "Enable all-containers hotkey", ProjectViewpointQOLOptions.enableContainersHotkey,
        "While looking at a container, press the All Containers key to show the loot from every container within reach (like the vanilla loot window). Tap to toggle; hold to store your inventory into the open or aimed container.")
    local optContainersKey = nil
    if page.addKeyBind then
        optContainersKey = page:addKeyBind("containersKey", "All Containers Hotkey", ProjectViewpointQOLOptions.containersKey or ((Keyboard and Keyboard.KEY_LEFTBRACKET) or 26),
            "Tap to toggle between the aimed container and every container within reach; hold to store all (default [).")
    end

    page:addTitle("Container Food, Drinks & Consumables")

    local optEat = page:addTickBox("enableEatHotkey", "Enable Container Eat & Drink Hotkeys", ProjectViewpointQOLOptions.enableEatHotkey,
        "When looking at edible food, drinks, pills, or smokables in a container or floor loot, adds consume prompts to Viewpoint's hint bar. Food and drinks open a portion chooser.")

    local defaultEatAllKey = (Keyboard and Keyboard.KEY_G) or 34
    local optEatAllKey = nil
    if page.addKeyBind then
        optEatAllKey = page:addKeyBind("eatAllKey", "Eat / Drink Hotkey", ProjectViewpointQOLOptions.eatAllKey or defaultEatAllKey,
            "Key to smoke or take pills instantly, or to open a portion chooser (Quarter / Half / All) for food and drinks from a container or floor loot.")
    end

    page:addTitle("Container Literature & Books")

    local optRead = page:addTickBox("enableReadHotkey", "Enable Container Read Hotkey", ProjectViewpointQOLOptions.enableReadHotkey,
        "When looking at readable books, skill books, or magazines in a container or floor loot, adds a Read prompt and allows 1-key reading.")

    local defaultReadKey = (Keyboard and Keyboard.KEY_G) or 34
    local optReadKey = nil
    if page.addKeyBind then
        optReadKey = page:addKeyBind("readKey", "Read Hotkey", ProjectViewpointQOLOptions.readKey or defaultReadKey,
            "Key to read the highlighted literature directly from containers.")
    end

    page:addTitle("First-Aid & Medical Supplies")

    local optFirstAid = page:addTickBox("enableFirstAidHotkey", "Enable First-Aid Hotkey", ProjectViewpointQOLOptions.enableFirstAidHotkey,
        "When looking at bandages, disinfectants, or suture needles in a container, or when carrying them while injured, enables quick 1-key treatment.")
    local optFirstAidHUD = page:addTickBox("enableFirstAidHUD", "Enable On-Screen Injury Alert Prompt", ProjectViewpointQOLOptions.enableFirstAidHUD,
        "Displays an on-screen prompt ('Press U to bandage [body part]') when injured and carrying medical supplies in inventory.")

    local defaultFirstAidKey = (Keyboard and Keyboard.KEY_G) or 34
    local optFirstAidKey = nil
    if page.addKeyBind then
        optFirstAidKey = page:addKeyBind("firstAidKey", "First-Aid Hotkey", ProjectViewpointQOLOptions.firstAidKey or defaultFirstAidKey,
            "Key to apply first aid (bandage, disinfect, suture) directly from containers or inventory. Shares the Item Action key (G) by default.")
    end

    page:addTitle("Container Crafting")

    local optCraft = page:addTickBox("enableContainerCraftHotkey", "Enable Container Craft Hotkey", ProjectViewpointQOLOptions.enableContainerCraftHotkey,
        "When looking at an item in a container or floor loot that can be used in craft recipes, adds a Craft prompt to open the recipe list.")

    local defaultCraftKey = (Keyboard and Keyboard.KEY_B) or 48
    local optCraftKey = nil
    if page.addKeyBind then
        optCraftKey = page:addKeyBind("containerCraftKey", "Container Craft Hotkey", ProjectViewpointQOLOptions.containerCraftKey or defaultCraftKey,
            "Key to open crafting with the highlighted item.")
    end

    page:addTitle("Container Ammunition & Magazine Loading")

    local optAmmo = page:addTickBox("enableAmmoHotkey", "Enable Container Ammo Hotkey", ProjectViewpointQOLOptions.enableAmmoHotkey,
        "When looking at ammo boxes, cartons, magazines, or loose rounds in a container or floor loot, adds unpack/load prompts to Viewpoint's hint bar.")

    local defaultAmmoKey = (Keyboard and Keyboard.KEY_G) or 34
    local optAmmoKey = nil
    if page.addKeyBind then
        optAmmoKey = page:addKeyBind("ammoKey", "Ammo Unpack & Load Hotkey", ProjectViewpointQOLOptions.ammoKey or defaultAmmoKey,
            "Key to unpack ammo boxes/cartons or load magazines directly from containers. Shares the Item Action key (G) by default.")
    end

    page:addTitle("Hands-Free Auto-Walk & Mouse Steering")

    local optAutoWalk = page:addTickBox("enableAutoWalk", "Enable Hands-Free Auto-Walk", ProjectViewpointQOLOptions.enableAutoWalk,
        "Allows toggling hands-free forward walking with first-person mouse steering and instant safety disengagement.")

    local defaultAutoWalkKey = (Keyboard and Keyboard.KEY_APOSTROPHE) or 40
    local optAutoWalkKey = nil
    if page.addKeyBind then
        optAutoWalkKey = page:addKeyBind("autoWalkKey", "Auto-Walk Toggle Hotkey", ProjectViewpointQOLOptions.autoWalkKey or defaultAutoWalkKey,
            "Key to toggle auto-walk on and off.")
    end

    local optAutoWalkModKey = nil
    if page.addKeyBind then
        optAutoWalkModKey = page:addKeyBind("autoWalkModifierKey", "Auto-Walk Shortcut Modifier", ProjectViewpointQOLOptions.autoWalkModifierKey or ((Keyboard and Keyboard.KEY_RMENU) or 184),
            "Modifier key held together with the forward key to toggle auto-walk (default Right Alt; Left Alt is the game's Sprint).")
    end

    local optAutoWalkAltW = page:addTickBox("autoWalkAltW", "Enable modifier + forward toggle shortcut", ProjectViewpointQOLOptions.autoWalkAltW,
        "Allows pressing the configured modifier (default Right Alt) + forward key as an additional shortcut to toggle auto-walk. Left Alt is left free because it is the game's Sprint.")
    local optAutoWalkZombieSafety = page:addTickBox("autoWalkZombieSafety", "Slow down near zombies", ProjectViewpointQOLOptions.autoWalkZombieSafety,
        "While fast-forwarding (auto-walk or manual movement), zombies coming near drop the game speed back to normal until the area is clear. Radius is tunable with the slider below.")
    local optZombieRadius = nil
    if page.addSlider then
        optZombieRadius = page:addSlider("autoWalkZombieRadius", "Zombie Slowdown Radius (tiles)", 3, 30, 1, ProjectViewpointQOLOptions.autoWalkZombieRadius or 10,
            "How close zombies must be for fast-forward to slow back to normal speed (default 10 tiles).")
    end
    local optAutoWalkDoors = page:addTickBox("autoOpenDoors", "Auto-open doors & gates while jogging", ProjectViewpointQOLOptions.autoOpenDoors,
        "When you jog or sprint into a closed, unlocked door or gate, open it and keep your momentum. Locked or barricaded doors still stop you.")
    local optFastForwardKeepAlive = page:addTickBox("fastForwardKeepAlive", "Keep fast-forward while auto-walking", ProjectViewpointQOLOptions.fastForwardKeepAlive,
        "Keeps your chosen fast-forward speed while auto-walking. Manual movement and Shift/Sprint drop back to normal, like vanilla. The zombie safety above still applies.")
    local optFastForwardWhileMoving = page:addTickBox("fastForwardWhileMoving", "Keep fast-forward during manual movement", ProjectViewpointQOLOptions.fastForwardWhileMoving,
        "While fast-forwarding, keep the speed while walking, running, turning or sprinting. WASD and Shift/Sprint no longer drop back to normal speed. Requires the keep-alive option above; the zombie safety above still applies.")

    local optThirdPersonStrafe = page:addTickBox("thirdPersonStrafe", "Third-person strafing", ProjectViewpointQOLOptions.thirdPersonStrafe,
        "Honor Viewpoint's Strafe movement setting in third person. Viewpoint forces turn-to-move there by design; enable to strafe and backpedal in 3rd person with the character turning with the camera, like in 1st.")

    page.apply = function()
        ProjectViewpointQOLOptions.applyOptionsFromPZAPI()
        ProjectViewpointQOLOptions.pushToViewpoint()
    end

end

-- Add the QOL page's top tabs (General / Mouse / Camera / Loot / Keys /
-- Movement) to Viewpoint's settings window. Soft-fails: without it the page
-- simply keeps the card layout. Retried at game start in case the class is
-- not exposed yet at boot.
function ProjectViewpointQOLOptions.ensureQolTabs()
    if ProjectViewpointQOLOptions.qolTabsDone then return end
    local api = ViewpointQOLTabs
    if api and api.ensure then
        local ok, done = pcall(api.ensure)
        if ok and done then
            ProjectViewpointQOLOptions.qolTabsDone = true
        end
    end
end

installOptions()
-- Register the QOL settings as soon as the game boots so the tab also exists
-- in Viewpoint's settings window from the main menu, not only after a save is
-- loaded. Same value-seeding order as before: Mod Options values load first,
-- then LiveSettings registration, so the first sync cannot clobber them.
Events.OnGameBoot.Add(function()
    installOptions()
    if PZAPI and PZAPI.ModOptions then
        pcall(function() PZAPI.ModOptions:load() end)
    end
    ProjectViewpointQOLOptions.applyOptionsFromPZAPI()
    ProjectViewpointQOLOptions.registerViewpoint()
    ProjectViewpointQOLOptions.ensureQolTabs()
end)
Events.OnGameStart.Add(function()
    installOptions()
    if PZAPI and PZAPI.ModOptions then
        PZAPI.ModOptions:load()
    end
    ProjectViewpointQOLOptions.applyOptionsFromPZAPI()
    ProjectViewpointQOLOptions.setupViewpoint()
    ProjectViewpointQOLOptions.migrateBindings()
    ProjectViewpointQOLOptions.migrateContainersKey()
    ProjectViewpointQOLOptions.migrateHotbarToShift()
    ProjectViewpointQOLOptions.migrateAutoWalkModifier()
    ProjectViewpointQOLOptions.migrateForVPAM()
    ProjectViewpointQOLOptions.migrateItemActionKey()
    ProjectViewpointQOLOptions.ensureViewpointTakeKey()
    ProjectViewpointQOLOptions.resolveVPAMKeyCollisions()
    ProjectViewpointQOLOptions.applyClassicCamera()
    ProjectViewpointQOLOptions.applyThirdPersonStrafe()
    ProjectViewpointQOLOptions.applyCameraEffects()
    ProjectViewpointQOLOptions.ensureQolTabs()
end)
