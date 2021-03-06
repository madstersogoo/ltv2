QBCore.Functions.CreateCallback('qb-occasions:server:getVehicles', function(source, cb)
    local result = exports.oxmysql:fetchSync('SELECT * FROM occasion_vehicles', {})
    if result[1] ~= nil then
        cb(result)
    else
        cb(nil)
    end
end)

QBCore.Functions.CreateCallback("qb-occasions:server:getSellerInformation", function(source, cb, citizenid)
    local src = source

    exports.oxmysql:fetch('SELECT * FROM players WHERE citizenid = @citizenid', {['@citizenid'] = citizenid}, function(result)
        if result[1] ~= nil then
            cb(result[1])
        else
            cb(nil)
        end
    end)
end)

RegisterServerEvent('qb-occasions:server:ReturnVehicle')
AddEventHandler('qb-occasions:server:ReturnVehicle', function(vehicleData)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local result = exports.oxmysql:fetchSync('SELECT * FROM occasion_vehicles WHERE plate=@plate AND occasionid=@occasionid', {['@plate'] = vehicleData['plate'], ['@occasionid'] = vehicleData["oid"]})
    if result[1] ~= nil then 
        if result[1].seller == Player.PlayerData.citizenid then
            exports.oxmysql:insert('INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, state) VALUES (@license, @citizenid, @vehicle, @hash, @mods, @plate, @state)', {
                ['@license'] = Player.PlayerData.license,
                ['@citizenid'] = Player.PlayerData.citizenid,
                ['@vehicle'] = vehicleData["model"],
                ['@hash'] = GetHashKey(vehicleData["model"]),
                ['@mods'] = vehicleData["mods"],
                ['@plate'] = vehicleData["plate"],
                ['@state'] = 0
            })
            exports.oxmysql:execute('DELETE FROM occasion_vehicles WHERE occasionid=@occasionid AND plate=@plate', {['@occasionid'] = vehicleData["oid"], ['@plate'] = vehicleData['plate']})
            TriggerClientEvent("qb-occasions:client:ReturnOwnedVehicle", src, result[1])
            TriggerClientEvent('qb-occasion:client:refreshVehicles', -1)
        else
            TriggerClientEvent('QBCore:Notify', src, 'Ce n\'est pas votre v??hicule', 'error', 3500)
        end
    else
        TriggerClientEvent('QBCore:Notify', src, 'Ce v??hicule n\'existe pas', 'error', 3500)
    end
end)

RegisterServerEvent('qb-occasions:server:sellVehicle')
AddEventHandler('qb-occasions:server:sellVehicle', function(vehiclePrice, vehicleData)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    exports.oxmysql:execute('DELETE FROM player_vehicles WHERE plate=@plate AND vehicle=@vehicle', {['@plate'] = vehicleData.plate, ['@vehicle'] = vehicleData.model})
    exports.oxmysql:insert('INSERT INTO occasion_vehicles (seller, price, description, plate, model, mods, occasionid) VALUES (@seller, @price, @description, @plate, @model, @mods, @occasionid)', {
        ['@seller'] = Player.PlayerData.citizenid,
        ['@price'] = vehiclePrice,
        ['@description'] = escapeSqli(vehicleData.desc),
        ['@plate'] = vehicleData.plate,
        ['@model'] = vehicleData.model,
        ['@mods'] = json.encode(vehicleData.mods),
        ['@occasionid'] = generateOID()
    })
    TriggerEvent("qb-log:server:sendLog", Player.PlayerData.citizenid, "vehiclesold", {model=vehicleData.model, vehiclePrice=vehiclePrice})
    TriggerEvent("qb-log:server:CreateLog", "vehicleshop", "V??hicule vendu", "red", "**"..GetPlayerName(src) .. "** a vendu un(e) " .. vehicleData.model .. " pour "..vehiclePrice.."$")

    TriggerClientEvent('qb-occasion:client:refreshVehicles', -1)
end)

RegisterServerEvent('qb-occasions:server:sellVehicleBack')
AddEventHandler('qb-occasions:server:sellVehicleBack', function(vData)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local cid = Player.PlayerData.citizenid
    local price = math.floor(vData.price / 2)
    local plate = vData.plate
   
    Player.Functions.AddMoney('bank', price)
    TriggerClientEvent('QBCore:Notify', src, 'Tu as vendu ce v??hicule pour $'..price, 'success', 5500)
    exports.oxmysql:execute('DELETE FROM player_vehicles WHERE plate=@plate', {['@plate'] = plate, ['@citizenid'] = cid})
end)

RegisterServerEvent('qb-occasions:server:buyVehicle')
AddEventHandler('qb-occasions:server:buyVehicle', function(vehicleData)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local result = exports.oxmysql:fetchSync('SELECT * FROM occasion_vehicles WHERE plate=@plate AND occasionid=@occasionid', {['@plate'] = vehicleData['plate'], ['@occasionid'] = vehicleData["oid"]})
    if result[1] ~= nil and next(result[1]) ~= nil then
        if Player.PlayerData.money.bank >= result[1].price then
            local SellerCitizenId = result[1].seller
            local SellerData = QBCore.Functions.GetPlayerByCitizenId(SellerCitizenId)
            -- New price calculation minus tax
            local NewPrice = math.ceil((result[1].price / 100) * 77)

            Player.Functions.RemoveMoney('bank', result[1].price)

            -- Insert vehicle for buyer
            exports.oxmysql:insert('INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, state) VALUES (@license, @citizenid, @vehicle, @hash, @mods, @plate, @state)', {
                ['@license'] = Player.PlayerData.license,
                ['@citizenid'] = Player.PlayerData.citizenid,
                ['@vehicle'] = result[1]["model"],
                ['@hash'] = GetHashKey(result[1]["model"]),
                ['@mods'] = result[1]["mods"],
                ['@plate'] = result[1]["plate"],
                ['@state'] = 0
            })
            -- Handle money transfer
            if SellerData ~= nil then
                -- Add money for online
                SellerData.Functions.AddMoney('bank', NewPrice)
            else
                -- Add money for offline
                local BuyerData = exports.oxmysql:fetchSync('SELECT * FROM players WHERE citizenid=@citizenid', {['@citizenid'] = SellerCitizenId})
                if BuyerData[1] ~= nil then
                    local BuyerMoney = json.decode(BuyerData[1].money)
                    BuyerMoney.bank = BuyerMoney.bank + NewPrice
                    exports.oxmysql:execute('UPDATE players SET money=@money WHERE citizenid=@citizenid', {['@money'] = json.encode(BuyerMoney), ['@citizenid'] = SellerCitizenId})
                end
            end

            TriggerEvent("qb-log:server:sendLog", Player.PlayerData.citizenid, "vehiclebought", {model = result[1].model, from = SellerCitizenId, moneyType = "cash", vehiclePrice = result[1].price, plate = result[1].plate})
            TriggerEvent("qb-log:server:CreateLog", "vehicleshop", "bought", "green", "**"..GetPlayerName(src) .. "** ?? vendu pour "..result[1].price .."$ (" .. result[1].plate .. ") ?? **"..SellerCitizenId.."**")
            TriggerClientEvent("qb-occasions:client:BuyFinished", src, result[1])
            TriggerClientEvent('qb-occasion:client:refreshVehicles', -1)
        
            -- Delete vehicle from Occasion
            exports.oxmysql:execute('DELETE FROM occasion_vehicles WHERE plate=@plate AND occasionid=@occasionid', {['@plate'] = result[1].plate, ['@occasionid'] = result[1].occasionid})
            -- Send selling mail to seller
            TriggerEvent('qb-phone:server:sendNewMailToOffline', SellerCitizenId, {
                sender = "Mosleys Occasions",
                subject = "Tu as vendu un v??hicule !",
                message = "La voiture "..QBCore.Shared.Vehicles[result[1].model].name.." a ??t?? vendu pour $"..result[1].price.."!"
            })
        else
            TriggerClientEvent('QBCore:Notify', src, 'Tu n\'as pas assez d\'argent', 'error', 3500)
        end
    end
end)

QBCore.Functions.CreateCallback("qb-vehiclesales:server:CheckModelName",function(source,cb,plate) 
    if plate then
        local ReturnData = exports.oxmysql:scalarSync("SELECT vehicle FROM `player_vehicles` WHERE plate = @plate",{['@plate'] = plate})
        cb(ReturnData)
    end
end)

function generateOID()
    local num = math.random(1, 10)..math.random(111, 999)

    return "OC"..num
end

function round(number)
    return number - (number % 1)
end

function escapeSqli(str)
    local replacements = { ['"'] = '\\"', ["'"] = "\\'" }
    return str:gsub( "['\"]", replacements ) -- or string.gsub( source, "['\"]", replacements )
end
