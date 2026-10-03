ESX = exports['es_extended']:getSharedObject()

local activeMissions = {}

local function getTodayDateString()
    return os.date('%Y-%m-%d')
end

local function restorePlayerSession(src)
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    if not Config.SaveMetadata then return end

    local questMeta = xPlayer.getMeta('old_ghostHunter_data')
    if not questMeta then return end

    if questMeta.completed then
        if Config.CooldownType == 'daily' and questMeta.lastCompleted ~= getTodayDateString() then
            questMeta = {
                started = false,
                photographed = {},
                completed = false,
                lastCompleted = nil
            }
            xPlayer.setMeta('old_ghostHunter_data', questMeta)
        else
            return
        end
    end

    if not questMeta.started then return end

    local photographed = questMeta.photographed or {}
    local currentStep = 1

    for index, ghost in ipairs(Config.Ghosts) do
        if not photographed[ghost.id] then
            currentStep = index
            break
        end
        if index == #Config.Ghosts then
            currentStep = #Config.Ghosts + 1
        end
    end

    if currentStep > #Config.Ghosts then
        activeMissions[src] = {
            step = #Config.Ghosts + 1,
            total = #Config.Ghosts,
            completed = true
        }
        TriggerClientEvent('old_ghostHunter:missionFinished', src)
        return
    end

    activeMissions[src] = {
        step = currentStep,
        total = #Config.Ghosts,
        completed = false
    }
    TriggerClientEvent('old_ghostHunter:resumeMission', src, activeMissions[src])
end

AddEventHandler('esx:playerLoaded', function(playerId, xPlayer)
    SetTimeout(2000, function()
        restorePlayerSession(playerId)
    end)
end)

AddEventHandler('esx:playerDropped', function(playerId)
    activeMissions[playerId] = nil
end)

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    Wait(1000)
    local xPlayers = ESX.GetExtendedPlayers()
    for _, xPlayer in ipairs(xPlayers) do
        restorePlayerSession(xPlayer.source)
    end
end)

ESX.RegisterServerCallback('old_ghostHunter:checkCanStart', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        cb(false, "Erreur joueur introuvable.")
        return
    end

    if Config.SaveMetadata then
        local questMeta = xPlayer.getMeta('old_ghostHunter_data') or {}

        if questMeta.completed then
            if Config.CooldownType == 'unique' then
                cb(false, "~r~Vous avez déjà accompli cette mission définitivement.")
                return
            elseif Config.CooldownType == 'daily' then
                if questMeta.lastCompleted == getTodayDateString() then
                    cb(false, "~r~Vous avez déjà terminé cette chasse aujourd'hui. Revenez demain.")
                    return
                end
            end
        end

        if questMeta.started and not questMeta.completed then
            cb(false, "~y~Vous avez déjà commencé cette traque. Trouvez les fantômes restants.")
            return
        end
    end

    cb(true, nil)
end)

RegisterNetEvent('old_ghostHunter:startMission', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    local photographed = {}
    local currentStep = 1

    if Config.SaveMetadata then
        local questMeta = xPlayer.getMeta('old_ghostHunter_data') or {}

        if questMeta.completed and Config.CooldownType == 'daily' and questMeta.lastCompleted ~= getTodayDateString() then
            questMeta = {
                started = true,
                photographed = {},
                completed = false,
                lastCompleted = nil
            }
        else
            questMeta.started = true
            questMeta.photographed = questMeta.photographed or {}
        end

        xPlayer.setMeta('old_ghostHunter_data', questMeta)
        photographed = questMeta.photographed

        for index, ghost in ipairs(Config.Ghosts) do
            if not photographed[ghost.id] then
                currentStep = index
                break
            end
            if index == #Config.Ghosts then
                currentStep = #Config.Ghosts + 1
            end
        end
    end

    if currentStep > #Config.Ghosts then
        TriggerClientEvent('old_ghostHunter:missionFinished', src)
        return
    end

    activeMissions[src] = {
        step = currentStep,
        total = #Config.Ghosts,
        completed = false
    }

    TriggerClientEvent('old_ghostHunter:startMission', src, activeMissions[src])
end)

RegisterNetEvent('old_ghostHunter:validatePhoto', function(step)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer or not activeMissions[src] then return end

    if activeMissions[src].step == step then
        local ghostData = Config.Ghosts[step]

        if Config.SaveMetadata and ghostData then
            local questMeta = xPlayer.getMeta('old_ghostHunter_data') or { started = true, photographed = {} }
            questMeta.started = true
            questMeta.photographed = questMeta.photographed or {}
            questMeta.photographed[ghostData.id] = {
                coords = {
                    x = ghostData.coords.x,
                    y = ghostData.coords.y,
                    z = ghostData.coords.z,
                    w = ghostData.coords.w
                },
                time = os.time()
            }
            xPlayer.setMeta('old_ghostHunter_data', questMeta)
        end

        activeMissions[src].step = activeMissions[src].step + 1

        if activeMissions[src].step > activeMissions[src].total then
            activeMissions[src].completed = true
            TriggerClientEvent('old_ghostHunter:missionFinished', src)
        else
            TriggerClientEvent('old_ghostHunter:nextStep', src, activeMissions[src].step)
        end
    end
end)

RegisterNetEvent('old_ghostHunter:claimReward', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer or not activeMissions[src] or not activeMissions[src].completed then return end

    if Config.SaveMetadata then
        local questMeta = xPlayer.getMeta('old_ghostHunter_data') or { photographed = {} }
        questMeta.started = false
        questMeta.completed = true
        questMeta.lastCompleted = getTodayDateString()
        xPlayer.setMeta('old_ghostHunter_data', questMeta)
    end

    if Config.Rewards.money and Config.Rewards.money > 0 then
        xPlayer.addMoney(Config.Rewards.money)
    end

    if Config.Rewards.items then
        for _, item in ipairs(Config.Rewards.items) do
            xPlayer.addInventoryItem(item.name, item.count)
        end
    end

    activeMissions[src] = nil
    TriggerClientEvent('old_ghostHunter:resetMission', src)
    xPlayer.showNotification('~g~Vous avez reçu votre récompense pour avoir photographié tous les fantômes.')
end)

ESX.RegisterCommand('resetghost', 'admin', function(xPlayer, args)
    local targetId = args.playerId and args.playerId.source or (xPlayer and xPlayer.source or nil)

    if not targetId then
        if xPlayer then
            xPlayer.showNotification("~r~Veuillez spécifier l'ID d'un joueur.")
        end
        return
    end

    local targetPlayer = ESX.GetPlayerFromId(targetId)
    if not targetPlayer then
        if xPlayer then
            xPlayer.showNotification("~r~Joueur introuvable.")
        end
        return
    end

    if Config.SaveMetadata then
        targetPlayer.clearMeta('old_ghostHunter_data')
    end

    activeMissions[targetId] = nil
    TriggerClientEvent('old_ghostHunter:resetMission', targetId)

    targetPlayer.showNotification("~g~Votre progression et cooldown d'Halloween ont été réinitialisés.")
    if xPlayer and xPlayer.source ~= targetId then
        xPlayer.showNotification(string.format("~g~Progression réinitialisée pour l'ID %s.", targetId))
    end
end, false, {
    help = "Réinitialiser la quête et le cooldown fantôme d'un joueur",
    arguments = {
        { name = 'playerId', help = 'ID du joueur cible (optionnel)', type = 'player' }
    }
})
