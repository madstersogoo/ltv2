Citizen.CreateThread(function()
    exports.oxmysql:insert("SELECT * FROM `companies`", function(result)
        if result[1] ~= nil then
            for k, v in pairs(result) do
                Config.Companies[v.name] = {
                    name = v.name,
                    label = v.label,
                    employees = v.employees ~= nil and json.decode(v.employees) or {},
                    owner = v.owner,
                    money = v.money,
                }
            end
        end
        TriggerClientEvent("qb-companies:client:setCompanies", -1, Config.Companies)
    end)
end)

RegisterServerEvent('qb-companies:server:loadCompanies')
AddEventHandler('qb-companies:server:loadCompanies', function()
    local src = source
    TriggerClientEvent("qb-companies:client:setCompanies", src, Config.Companies)
end)

RegisterServerEvent('qb-companies:server:createCompany')
AddEventHandler('qb-companies:server:createCompany', function(name)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local bankAmount = Player.PlayerData.money["bank"]
    local cashAmount = Player.PlayerData.money["cash"]
    if cashAmount >= Config.CompanyPrice or bankAmount >= Config.CompanyPrice then
        if name ~= nil then 
            local companyLabel = escapeSqli(name)
            local companyName = escapeSqli(name:gsub("%s+", ""):lower())
            if companyName ~= "" then
                if IsNameAvailable(companyName) then
                    if cashAmount >= Config.CompanyPrice then
                        Player.Functions.RemoveMoney("cash", Config.CompanyPrice, "company-created")
                        exports.oxmysql:insert("INSERT INTO `companies` (`name`, `label`, `owner`) VALUES ('"..companyName.."', '"..companyLabel.."', '"..Player.PlayerData.citizenid.."')")
                        Config.Companies[companyName] = {
                            name = companyName,
                            label = name,
                            employees = {},
                            owner = Player.PlayerData.citizenid,
                            money = 0,
                        }
                        TriggerClientEvent("qb-companies:client:setCompanies", -1, Config.Companies)
                        TriggerClientEvent('QBCore:Notify', src, "F??licitation, Vous ??tes le propri??taire de : "..companyLabel)
                    else
                        Player.Functions.RemoveMoney("bank", Config.CompanyPrice, "company-created")
                        exports.oxmysql:insert("INSERT INTO `companies` (`name`, `label`, `owner`) VALUES ('"..companyName.."', '"..companyLabel.."', '"..Player.PlayerData.citizenid.."')")
                        Config.Companies[companyName] = {
                            name = companyName,
                            label = name,
                            employees = {},
                            owner = Player.PlayerData.citizenid,
                            money = 0,
                        }
                        TriggerClientEvent("qb-companies:client:setCompanies", -1, Config.Companies)
                        TriggerClientEvent('QBCore:Notify', src, "F??licitation, Vous ??tes le propri??taire de : "..companyLabel)
                    end
                else
                    TriggerClientEvent('QBCore:Notify', src, 'La soci??t?? : ' .. companyLabel .. ' est occup??..', 'error', 4000)
                end
            else
                TriggerClientEvent('QBCore:Notify', src, 'Le nom ne peut pas ??tre vide..', 'error', 4000)
            end
        else
            TriggerClientEvent('QBCore:Notify', src, 'Le nom ne peut pas ??tre vide', 'error', 4000)
        end
    else
        TriggerClientEvent('QBCore:Notify', src, 'Vous n\'avez pas assez d\'argent', 'error', 4000)
    end
end)

RegisterServerEvent('qb-companies:server:removeCompany')
AddEventHandler('qb-companies:server:removeCompany', function(companyName)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if companyName ~= nil then 
        if IsCompanyOwner(companyName, Player.PlayerData.citizenid) then
            companyLabel = Config.Companies[companyName].label
            QBCore.Functions.ExecuteSql(true, "DELETE FROM `companies` WHERE `name` = '"..escapeSqli(companyName).."'")
            Config.Companies[companyName] = nil
            TriggerClientEvent("qb-companies:client:setCompanies", -1, Config.Companies)
            TriggerClientEvent("qb-phone:client:setupCompanies", src)
            TriggerClientEvent("qb-phone:client:InPhoneNotify", src, "Businesses", "success", "Tu as supprim?? " .. companyLabel .. " !")
        else
            TriggerClientEvent('QBCore:Notify', src, 'Vous ne poss??dez pas cette entreprise ..', 'error', 4000)
        end
    else
        TriggerClientEvent('QBCore:Notify', src, 'Le nom ne peut pas ??tre vide ..', 'error', 4000)
    end
end)

RegisterServerEvent('qb-companies:server:quitCompany')
AddEventHandler('qb-companies:server:quitCompany', function(companyName)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if companyName ~= nil then 
        if IsEmployee(companyName, Player.PlayerData.citizenid) then
            companyLabel = Config.Companies[companyName].label
            Config.Companies[companyName].employees[Player.PlayerData.citizenid] = nil

            TriggerClientEvent("qb-companies:client:setCompanies", -1, Config.Companies)
            TriggerClientEvent("qb-phone:client:setupCompanies", src)
            TriggerClientEvent("qb-phone:client:InPhoneNotify", src, "Businesses", "success", "Vous avez d??missionn?? de" .. companyLabel .. "!")

            local updatedEmployees = {}
            for employee, info in pairs(Config.Companies[companyName].employees) do
                updatedEmployees[employee] = info
            end
            exports.oxmysql:insert("UPDATE `companies` SET `employees` = '"..json.encode(updatedEmployees).."' WHERE `name` = '"..escapeSqli(companyName).."'")
        else
            TriggerClientEvent('QBCore:Notify', src, 'Vous ne poss??dez pas cette entreprise ..', 'error', 4000)
        end
    else
        TriggerClientEvent('QBCore:Notify', src, 'Le nom ne peut pas ??tre vide ..', 'error', 4000)
    end
end)

RegisterServerEvent('qb-companies:server:addEmployee')
AddEventHandler('qb-companies:server:addEmployee', function(playerCitizenId, companyName, rank)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local OtherPlayer = QBCore.Functions.GetPlayerByCitizenId(playerCitizenId)
    local rank = tonumber(rank)
    if OtherPlayer ~= nil then 
        if IsCompanyOwner(companyName, Player.PlayerData.citizenid) then
            if rank > 0 and rank < Config.MaxRank then
                Config.Companies[companyName].employees[OtherPlayer.PlayerData.citizenid] {
                    name = OtherPlayer.PlayerData.charinfo.firstname .. " " .. OtherPlayer.PlayerData.charinfo.lastname,
                    citizenid = OtherPlayer.PlayerData.citizenid,
                    rank = rank,
                }
                exports.oxmysql:insert("UPDATE `companies` SET `employees` = '"..json.encode(Config.Companies[companyName].employees).."' WHERE `name` = '"..escapeSqli(companyName).."'")
                TriggerClientEvent("qb-companies:client:setCompanies", -1, Config.Companies)
                TriggerClientEvent('QBCore:Notify', src, 'Tu as embauch?? ' .. OtherPlayer.PlayerData.firstname .. ' ' .. OtherPlayer.PlayerData.lastname .. ' (rang: '..rank..')')
                TriggerClientEvent('QBCore:Notify', OtherPlayer.PlayerData.source, 'Vous avez ??t?? embauch?? chez ' .. Config.Companies[companyName].label .. "(rang: " ..rank..")")
            else
                TriggerClientEvent('QBCore:Notify', src, 'Le rang minimum est 1 et le maximum '..(Config.MaxRank-1)..'...', 'error', 4000)
            end
        else
            TriggerClientEvent('QBCore:Notify', src, 'Vous ne poss??dez pas cette entreprise ...', 'error', 4000)
        end
    else
        TriggerClientEvent('QBCore:Notify', src, 'La personne n\'est pas pr??sente ...', 'error', 4000)
    end
end)

RegisterServerEvent('qb-companies:server:alterEmployee')
AddEventHandler('qb-companies:server:alterEmployee', function(playerCitizenId, companyName, isPromote)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local otherCitizenId = playerCitizenId:upper()
    if CanAlterEmployee(companyName, Player.PlayerData.citizenid) then
        if Config.Companies[companyName].employees[otherCitizenId] ~= nil then 
            if isPromote then
                local newRank = Config.Companies[companyName].employees[otherCitizenId].rank + 1
                if newRank < Config.MaxRank then
                    Config.Companies[companyName].employees[otherCitizenId].rank = newRank
                    exports.oxmysql:insert("UPDATE `companies` SET `employees` = '"..json.encode(Config.Companies[companyName].employees).."' WHERE `name` = '"..escapeSqli(companyName).."'")
                    TriggerClientEvent("qb-companies:client:setCompanies", -1, Config.Companies)
                    TriggerClientEvent('QBCore:Notify', src, 'Promu au rang : ' ..newRank)
                else
                    TriggerClientEvent('QBCore:Notify', src, 'La personne ne peut pas ??tre promu ..', 'error', 4000)
                end
            else
                local newRank = Config.Companies[companyName].employees[otherCitizenId].rank - 1
                if newRank > 0 then
                    Config.Companies[companyName].employees[otherCitizenId].rank = newRank
                    exports.oxmysql:insert("UPDATE `companies` SET `employees` = '"..json.encode(Config.Companies[companyName].employees).."' WHERE `name` = '"..escapeSqli(companyName).."'")
                    TriggerClientEvent("qb-companies:client:setCompanies", -1, Config.Companies)
                    TriggerClientEvent('QBCore:Notify', src, 'Promu au rang : ' ..newRank)
                else
                    TriggerClientEvent('QBCore:Notify', src, 'La personne ne peut pas ??tre promu ...', 'error', 4000)
                end
            end
        else
            TriggerClientEvent('QBCore:Notify', src, 'Cette personne n\'est pas un employ?? de votre entreprise ..', 'error', 4000)
        end
    else
        TriggerClientEvent('QBCore:Notify', src, 'Vous ne poss??dez pas cette entreprise ..', 'error', 4000)
    end
end)

function IsEmployee(companyName, citizenid)
    local retval = false
    if Config.Companies[companyName] ~= nil then 
        if Config.Companies[companyName].employees ~= nil then 
            if Config.Companies[companyName].employees[citizenid] ~= nil then 
                retval = true
            elseif Config.Companies[companyName].owner == citizenid then
                retval = true
            end
        else
            if Config.Companies[companyName].owner == citizenid then
                retval = true
            end
        end
    end
    return retval
end

function CanAlterEmployee(companyName, citizenid)
    local retval = false
    if Config.Companies[companyName] ~= nil then 
        if Config.Companies[companyName].owner == citizenid then
            retval = true
        elseif Config.Companies[companyName].employees[citizenid] ~= nil then 
            if Config.Companies[companyName].employees[citizenid].rank == (Config.MaxRank - 1) then
                retval = true
            end
        end
    end
    return retval
end

function IsCompanyOwner(companyName, citizenid)
    local retval = false
    if Config.Companies[companyName] ~= nil then 
        if Config.Companies[companyName].owner == citizenid then
            retval = true
        end
    end
    return retval
end

function IsNameAvailable(name)
    local retval = false
    QBCore.Functions.ExecuteSql(true, "SELECT * FROM `companies` WHERE `name` = '"..name.."'", function(result)
        if result[1] ~= nil then 
            retval = false
        else
            retval = true
        end
    end)
    return retval
end

function escapeSqli(str)
    local replacements = { ['"'] = '\\"', ["'"] = "\\'" }
    return str:gsub( "['\"]", replacements ) -- or string.gsub( source, "['\"]", replacements )
end