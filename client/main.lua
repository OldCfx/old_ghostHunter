ESX = exports['es_extended']:getSharedObject()

local currentStep = 0
local totalGhosts = #Config.Ghosts
local isMissionActive = false
local missionDone = false
local isHudHidden = false
local currentGhostEntity = nil
local currentGhostParticle = nil
local currentProp = nil
local npcPed = nil
local ghostBlip = nil
local isTalkingToNpc = false
local isTakingPhoto = false
local npcCam = nil

local function isNightTime()
    local hour = GetClockHours()
    if Config.Hours.start > Config.Hours.finish then
        return hour >= Config.Hours.start or hour < Config.Hours.finish
    else
        return hour >= Config.Hours.start and hour < Config.Hours.finish
    end
end

local function setGhostWaypoint(coords)
    if DoesBlipExist(ghostBlip) then
        RemoveBlip(ghostBlip)
    end
    ghostBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(ghostBlip, 66)
    SetBlipColour(ghostBlip, 7)
    SetBlipScale(ghostBlip, 0.8)
    SetBlipRoute(ghostBlip, not isHudHidden)
    SetBlipRouteColour(ghostBlip, 7)
    SetBlipDisplay(ghostBlip, isHudHidden and 0 or 2)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName("Fantôme")
    EndTextCommandSetBlipName(ghostBlip)
end

local function clearWaypoint()
    if DoesBlipExist(ghostBlip) then
        RemoveBlip(ghostBlip)
        ghostBlip = nil
    end
end

local function toggleMissionDisplay()
    isHudHidden = not isHudHidden

    SendNUIMessage({
        action = 'toggleHud'
    })

    if DoesBlipExist(ghostBlip) then
        if isHudHidden then
            SetBlipDisplay(ghostBlip, 0)
            SetBlipRoute(ghostBlip, false)
        else
            SetBlipDisplay(ghostBlip, 2)
            SetBlipRoute(ghostBlip, true)
        end
    end
end

local function despawnCurrentGhost()
    if currentGhostParticle and DoesParticleFxLoopedExist(currentGhostParticle) then
        StopParticleFxLooped(currentGhostParticle, false)
        currentGhostParticle = nil
    end

    if DoesEntityExist(currentGhostEntity) then
        SetEntityAsMissionEntity(currentGhostEntity, true, true)
        DeleteObject(currentGhostEntity)
        DeleteEntity(currentGhostEntity)
        currentGhostEntity = nil
    end
end

local function safeRequestModel(model)
    RequestModel(model)
    local timeout = GetGameTimer() + 3000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do
        Wait(10)
    end
    return HasModelLoaded(model)
end

local function safeRequestPtfx(asset)
    RequestNamedPtfxAsset(asset)
    local timeout = GetGameTimer() + 3000
    while not HasNamedPtfxAssetLoaded(asset) and GetGameTimer() < timeout do
        Wait(10)
    end
    return HasNamedPtfxAssetLoaded(asset)
end

local function safeRequestAnimDict(dict)
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do
        Wait(10)
    end
    return HasAnimDictLoaded(dict)
end

local function applyScreamerEffects()
    CreateThread(function()
        local ped = PlayerPedId()

        SetPedToRagdoll(ped, 4000, 4000, 0, false, false, false)
        ShakeGameplayCam('FAMILY5_DRUG_TRIP_SHAKE', 1.3)
        StartScreenEffect('Rampage', 0, true)

        ESX.ShowNotification("~y~Vous avez été effrayé par quelque chose")

        Wait(10000)

        DoScreenFadeOut(500)
        while not IsScreenFadedOut() do
            Wait(10)
        end

        StopScreenEffect('Rampage')
        StopGameplayCamShaking(true)

        Wait(200)

        DoScreenFadeIn(800)
        while not IsScreenFadedIn() do
            Wait(10)
        end
    end)
end

local function triggerRandomScreamer()
    if not Config.Screamer.enabled then return false end

    local roll = math.random(1, 100)
    if roll <= Config.Screamer.chance then
        SendNUIMessage({
            action = 'playRandomScreamer'
        })
        applyScreamerEffects()
        return true
    end
    return false
end

local function spawnGhost(index)
    despawnCurrentGhost()

    local ghostData = Config.Ghosts[index]
    if not ghostData then return end

    local modelHash = GetHashKey(ghostData.model)
    local modelOk = safeRequestModel(modelHash)
    if not modelOk then return end

    currentGhostEntity = CreateObject(modelHash, ghostData.coords.x, ghostData.coords.y, ghostData.coords.z - 1.0, false,
        false, false)
    SetEntityHeading(currentGhostEntity, ghostData.coords.w)
    FreezeEntityPosition(currentGhostEntity, true)
    SetEntityCollision(currentGhostEntity, false, false)
    ResetEntityAlpha(currentGhostEntity)
    SetModelAsNoLongerNeeded(modelHash)

    setGhostWaypoint(ghostData.coords)
end

local function takePhoto(targetIndex)
    if isTakingPhoto then return end
    isTakingPhoto = true

    CreateThread(function()
        local ped = PlayerPedId()
        local animDict = 'cellphone@female'
        local animName = 'cellphone_text_read_base_cover_low'
        local propModel = GetHashKey('prop_ing_camera_01')
        local flashAsset = 'scr_bike_business'
        local flashPtfx = 'scr_bike_cfid_camera_flash'
        local gasAsset = 'core'
        local gasPtfx = 'exp_grd_grenade_smoke'

        local animOk = safeRequestAnimDict(animDict)
        local modelOk = safeRequestModel(propModel)
        local flashOk = safeRequestPtfx(flashAsset)
        local gasOk = safeRequestPtfx(gasAsset)

        if not animOk or not modelOk then
            isTakingPhoto = false
            ESX.ShowNotification("~r~Erreur de chargement des animations.")
            return
        end

        TaskPlayAnim(ped, animDict, animName, 4.0, -4.0, -1, 49, 0, false, false, false)

        if gasOk and DoesEntityExist(currentGhostEntity) then
            if currentGhostParticle and DoesParticleFxLoopedExist(currentGhostParticle) then
                StopParticleFxLooped(currentGhostParticle, false)
                currentGhostParticle = nil
            end
            local ghostCoords = GetEntityCoords(currentGhostEntity)
            UseParticleFxAssetNextCall(gasAsset)
            currentGhostParticle = StartParticleFxLoopedAtCoord(gasPtfx, ghostCoords.x, ghostCoords.y,
                ghostCoords.z - 1.2, 0.0, 0.0, 0.0, 1.4, false, false, false, false)
        end

        local startCoords = GetEntityCoords(ped)
        currentProp = CreateObject(propModel, startCoords.x, startCoords.y, startCoords.z, true, true, false)
        AttachEntityToEntity(currentProp, ped, GetPedBoneIndex(ped, 28422), 0.01, -0.03, 0.052, -172.04, -163.93, -29.02,
            true, true, false, true, 1, true)

        Wait(200)

        local endTime = GetGameTimer() + 4000
        local nextFlash = 0
        local failed = false

        while GetGameTimer() < endTime do
            Wait(10)

            local currentCoords = GetEntityCoords(ped)
            if #(currentCoords - startCoords) > 0.5 then
                failed = true
                break
            end

            if flashOk and GetGameTimer() > nextFlash then
                UseParticleFxAssetNextCall(flashAsset)
                StartParticleFxNonLoopedOnEntity(flashPtfx, currentProp, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, false, false,
                    false)
                nextFlash = GetGameTimer() + math.random(400, 700)
            end
        end

        ClearPedTasks(ped)

        if DoesEntityExist(currentProp) then
            SetEntityAsMissionEntity(currentProp, true, true)
            DeleteObject(currentProp)
            DeleteEntity(currentProp)
            currentProp = nil
        end

        if failed then
            if currentGhostParticle and DoesParticleFxLoopedExist(currentGhostParticle) then
                StopParticleFxLooped(currentGhostParticle, false)
                currentGhostParticle = nil
            end
            isTakingPhoto = false
            ESX.ShowNotification("~r~La photo est floue car vous avez bougé. Veuillez recommencer.")
            return
        end

        Wait(200)

        if DoesEntityExist(currentGhostEntity) then
            triggerRandomScreamer()

            for alpha = 255, 0, -15 do
                if DoesEntityExist(currentGhostEntity) then
                    SetEntityAlpha(currentGhostEntity, alpha, false)
                end
                Wait(30)
            end

            despawnCurrentGhost()
        end

        TriggerServerEvent('old_ghostHunter:validatePhoto', targetIndex)
    end)
end

RegisterNUICallback('audioFinished', function(_, cb)
    local playerPed = PlayerPedId()
    FreezeEntityPosition(playerPed, false)
    isTalkingToNpc = false

    if DoesCamExist(npcCam) then
        RenderScriptCams(false, true, 1000, true, true)
        DestroyCam(npcCam, false)
        npcCam = nil
    end

    if DoesEntityExist(npcPed) then
        ClearPedTasks(npcPed)
        PlayFacialAnim(npcPed, "mood_normal_1", "facials@gen_male@variations@normal")
    end

    TriggerServerEvent('old_ghostHunter:startMission')
    cb('ok')
end)

CreateThread(function()
    local npcHash = GetHashKey(Config.Npc.model)
    safeRequestModel(npcHash)

    npcPed = CreatePed(4, npcHash, Config.Npc.coords.x, Config.Npc.coords.y, Config.Npc.coords.z - 1.0,
        Config.Npc.coords.w, false, true)
    FreezeEntityPosition(npcPed, true)
    SetEntityInvincible(npcPed, true)
    SetBlockingOfNonTemporaryEvents(npcPed, true)
    SetModelAsNoLongerNeeded(npcHash)

    local blip = AddBlipForCoord(Config.Npc.coords.x, Config.Npc.coords.y, Config.Npc.coords.z)
    SetBlipSprite(blip, 484)
    SetBlipColour(blip, 47)
    SetBlipScale(blip, 0.8)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName("Chasseur de fantômes")
    EndTextCommandSetBlipName(blip)

    while true do
        local sleep = 1000
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)

        local distNpc = #(playerCoords - vector3(Config.Npc.coords.x, Config.Npc.coords.y, Config.Npc.coords.z))
        if distNpc < 3.0 and not isTalkingToNpc then
            sleep = 0
            if not isMissionActive and not missionDone then
                ESX.ShowHelpNotification("Appuyez sur ~INPUT_CONTEXT~ pour parler avec l'individu.")
                if IsControlJustReleased(0, 38) then
                    if not isNightTime() then
                        ESX.ShowNotification(string.format(
                            "~r~Revenez entre %02dh et %02dh.", Config.Hours.start, Config.Hours.finish))
                    else
                        ESX.TriggerServerCallback('old_ghostHunter:checkCanStart', function(canStart, message)
                            if not canStart then
                                if message then
                                    ESX.ShowNotification(message)
                                end
                            else
                                isTalkingToNpc = true
                                FreezeEntityPosition(playerPed, true)
                                ESX.ShowNotification("Écoutez les indications...")
                                local bodyDict = "anim@amb@casino@brawl@fights@argue@"
                                local bodyAnim = "arguement_loop_mp_m_brawler_01"
                                local facialDict = "mp_facial"
                                RequestAnimDict(bodyDict)
                                while not HasAnimDictLoaded(bodyDict) do
                                    Wait(10)
                                end

                                RequestAnimDict(facialDict)
                                while not HasAnimDictLoaded(facialDict) do
                                    Wait(10)
                                end

                                TaskPlayAnim(npcPed, bodyDict, bodyAnim, 8.0, -8.0, -1, 1, 0.0, false, false, false)
                                PlayFacialAnim(npcPed, "mic_chatter", facialDict)

                                CreateThread(function()
                                    while isTalkingToNpc and DoesEntityExist(npcPed) do
                                        Wait(800)
                                        if isTalkingToNpc and DoesEntityExist(npcPed) then
                                            PlayFacialAnim(npcPed, "mic_chatter", facialDict)
                                        end
                                    end
                                end)

                                local headCoords = GetPedBoneCoords(npcPed, 31086, 0.0, 0.0, 0.0)
                                local camForward = GetEntityForwardVector(npcPed)
                                local camPos = headCoords + (camForward * 1.2) + vector3(0.0, 0.0, 0.05)

                                npcCam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", camPos.x, camPos.y, camPos.z, 0.0,
                                    0.0, 0.0, 45.0, false, 0)
                                PointCamAtCoord(npcCam, headCoords.x, headCoords.y, headCoords.z)
                                SetCamActive(npcCam, true)
                                RenderScriptCams(true, true, 1000, true, true)

                                SendNUIMessage({
                                    action = 'playIntroAudio'
                                })
                            end
                        end)
                    end
                end
            elseif missionDone then
                ESX.ShowHelpNotification("Appuyez sur ~INPUT_CONTEXT~ pour récupérer votre récompense.")
                if IsControlJustReleased(0, 38) then
                    TriggerServerEvent('old_ghostHunter:claimReward')
                end
            end
        end

        if isMissionActive and currentStep > 0 and currentStep <= totalGhosts and not isTakingPhoto then
            local ghostCoords = vector3(Config.Ghosts[currentStep].coords.x, Config.Ghosts[currentStep].coords.y,
                Config.Ghosts[currentStep].coords.z)
            local distGhost = #(playerCoords - ghostCoords)

            if isNightTime() then
                if not DoesEntityExist(currentGhostEntity) and distGhost < 60.0 then
                    spawnGhost(currentStep)
                end

                if distGhost < 5.0 then
                    sleep = 0
                    ESX.ShowHelpNotification("Appuyez sur ~INPUT_CONTEXT~ pour photographier le fantôme.")
                    if IsControlJustReleased(0, 38) then
                        takePhoto(currentStep)
                    end
                end
            else
                despawnCurrentGhost()
            end
        end

        Wait(sleep)
    end
end)

CreateThread(function()
    while true do
        local sleep = 500
        if isMissionActive or missionDone then
            sleep = 0
            if IsControlJustReleased(0, 74) then
                toggleMissionDisplay()
            end
        end
        Wait(sleep)
    end
end)

RegisterNetEvent('old_ghostHunter:startMission', function(data)
    isTakingPhoto = false
    isMissionActive = true
    missionDone = false
    isHudHidden = false
    currentStep = data.step
    totalGhosts = data.total
    despawnCurrentGhost()
    SendNUIMessage({
        action = 'updateHud',
        visible = true,
        current = currentStep - 1,
        total = totalGhosts
    })
    setGhostWaypoint(Config.Ghosts[currentStep].coords)
    ESX.ShowNotification("~y~La traque commence. Trouvez le fantôme pendant la nuit.")
end)

RegisterNetEvent('old_ghostHunter:resumeMission', function(data)
    isTakingPhoto = false
    isMissionActive = true
    missionDone = false
    isHudHidden = false
    currentStep = data.step
    totalGhosts = data.total
    despawnCurrentGhost()
    SendNUIMessage({
        action = 'updateHud',
        visible = true,
        current = currentStep - 1,
        total = totalGhosts
    })
    setGhostWaypoint(Config.Ghosts[currentStep].coords)
    ESX.ShowNotification(string.format("~y~Reprise de la traque : %d/%d fantôme(s) photographié(s).", currentStep - 1,
        totalGhosts))
end)

RegisterNetEvent('old_ghostHunter:nextStep', function(step)
    despawnCurrentGhost()
    currentStep = step
    isTakingPhoto = false
    SendNUIMessage({
        action = 'updateHud',
        visible = true,
        current = currentStep - 1,
        total = totalGhosts
    })
    setGhostWaypoint(Config.Ghosts[currentStep].coords)
    ESX.ShowNotification("~g~Fantôme photographié ! Passez au suivant.")
end)

RegisterNetEvent('old_ghostHunter:missionFinished', function()
    despawnCurrentGhost()
    isTakingPhoto = false
    missionDone = true
    isMissionActive = false
    clearWaypoint()
    SendNUIMessage({
        action = 'updateHud',
        visible = true,
        current = totalGhosts,
        total = totalGhosts
    })
    ESX.ShowNotification("~g~Tous les fantômes ont été photographiés ! Retournez voir l'individu.")
    setGhostWaypoint(Config.Npc.coords)
end)

RegisterNetEvent('old_ghostHunter:resetMission', function()
    isTakingPhoto = false
    isMissionActive = false
    missionDone = false
    isHudHidden = false
    currentStep = 0
    despawnCurrentGhost()
    clearWaypoint()
    SendNUIMessage({
        action = 'updateHud',
        visible = false,
        current = 0,
        total = totalGhosts
    })
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    if DoesCamExist(npcCam) then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(npcCam, false)
        npcCam = nil
    end

    if DoesEntityExist(npcPed) then
        DeletePed(npcPed)
    end
    despawnCurrentGhost()
    if DoesEntityExist(currentProp) then
        DeleteEntity(currentProp)
    end
    clearWaypoint()
end)
