local QBCore = exports['qb-core']:GetCoreObject()

local function cv(amount)
    local formatted = amount
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if (k==0) then
            break
        end
    end
    return formatted
end

--QBCore.Commands.Add("cashregister", "Use mobile cash register", {}, false, function(source) TriggerClientEvent("jim-payments:client:Charge", source, true) end)

RegisterServerEvent('jim-payments:Tickets:Give', function(amount, job)
	if Config.TicketSystem then
		for k, v in pairs(QBCore.Functions.GetPlayers()) do
			local Player = QBCore.Functions.GetPlayer(v)
			if Player ~= nil then
				if Player.PlayerData.job.name == job and Player.PlayerData.job.onduty then
					if amount >= Config.Jobs[job].MinAmountforTicket then
						Player.Functions.AddItem('payticket', 1, false, {["quality"] = nil})
						TriggerClientEvent('QBCore:Notify', Player.PlayerData.source, 'Receipt received', 'success')
						TriggerClientEvent('inventory:client:ItemBox', Player.PlayerData.source, QBCore.Shared.Items['payticket'], "add", 1) 
					elseif amount < Config.Jobs[job].MinAmountforTicket then
						TriggerClientEvent("QBCore:Notify", Player.PlayerData.source, "Amount too low, didn't receive a receipt", "error")
					end
				end
			end
		end
	end
end)

RegisterServerEvent('jim-payments:Tickets:Sell', function()
    local Player = QBCore.Functions.GetPlayer(source)
	if Player.Functions.GetItemByName("payticket") == nil then TriggerClientEvent('QBCore:Notify', source, "No tickets to trade", 'error') return
	else
		tickets = Player.Functions.GetItemByName("payticket").amount
		Player.Functions.RemoveItem('payticket', tickets)
		pay = (tickets * Config.Jobs[Player.PlayerData.job.name].PayPerTicket)
		Player.Functions.AddMoney('bank', pay, 'ticket-payment')
		TriggerClientEvent('inventory:client:ItemBox', source, QBCore.Shared.Items['payticket'], "remove", tickets)
		TriggerClientEvent('QBCore:Notify', source, "Tickets traded: "..tickets.." Total: $"..cv(pay), 'success')
	end
end)

QBCore.Functions.CreateCallback('jim-payments:Ticket:Count', function(source, cb) 
	if QBCore.Functions.GetPlayer(source).Functions.GetItemByName('payticket') == nil then amount = 0
	else amount = QBCore.Functions.GetPlayer(source).Functions.GetItemByName('payticket').amount end 
	cb(amount) 
end)

RegisterServerEvent("jim-payments:server:Charge", function(citizen, price, billtype)
	local src = source
    local biller = QBCore.Functions.GetPlayer(src)
    local billed = QBCore.Functions.GetPlayer(tonumber(citizen))
    local amount = tonumber(price)
	if amount and amount > 0 then
		if billtype == "cash" then balance = billed.Functions.GetMoney(billtype)
			if balance >= amount then
				TriggerClientEvent("jim-payments:client:PayPopup", billed.PlayerData.source, amount, src, billtype)
			elseif balance < amount then
				TriggerClientEvent("QBCore:Notify", src, "Customer doesn't have enough cash to pay", "error")
				TriggerClientEvent("QBCore:Notify", tonumber(citizen), "You don't have enough cash to pay", "error")
			end
		elseif billtype == "card" then
			if Config.PhoneBank == false then
				TriggerClientEvent("jim-payments:client:PayPopup", billed.PlayerData.source, amount, src, billtype)
			else
				MySQL.Async.insert(
					'INSERT INTO phone_invoices (citizenid, amount, society, sender, sendercitizenid) VALUES (?, ?, ?, ?, ?)',
					{billed.PlayerData.citizenid, amount, biller.PlayerData.job.name, biller.PlayerData.charinfo.firstname, biller.PlayerData.citizenid})
				TriggerClientEvent('qb-phone:RefreshPhone', billed.PlayerData.source)
				TriggerClientEvent('QBCore:Notify', src, 'Invoice Successfully Sent', 'success')
				TriggerClientEvent('QBCore:Notify', billed.PlayerData.source, 'New Invoice Received')
			end
		end
	else TriggerClientEvent('QBCore:Notify', source, "You can't charge $0", 'error') return end
end)

RegisterServerEvent("jim-payments:server:PayPopup", function(data)
	local src = source
	local billtype = data.billtype
	local billed = QBCore.Functions.GetPlayer(src)
	local biller = QBCore.Functions.GetPlayer(tonumber(data.biller))
		if billtype == "card" then billtype = "bank" end
	if data.accept == true then
		billed.Functions.RemoveMoney(tostring(billtype), data.amount) TriggerEvent("qb-bossmenu:server:addAccountMoney", tostring(biller.PlayerData.job.name), data.amount)
		TriggerEvent('jim-payments:Tickets:Give', data.amount, tostring(biller.PlayerData.job.name))
		TriggerClientEvent("QBCore:Notify", data.biller, billed.PlayerData.charinfo.firstname.." accepted the payment", "success")
	elseif data.accept == false then
		TriggerClientEvent("QBCore:Notify", src, "You declined the payment")
		TriggerClientEvent("QBCore:Notify", data.biller, billed.PlayerData.charinfo.firstname.." declined the payment", "error")
	end
end)

QBCore.Functions.CreateCallback('jim-payments:MakePlayerList', function(source, cb)
	local onlineList = {}
	for k, v in pairs(QBCore.Functions.GetPlayers()) do
		local P = QBCore.Functions.GetPlayer(v)
		onlineList[#onlineList+1] = { value = tonumber(v), text = "["..v.."] - "..P.PlayerData.charinfo.firstname..' '..P.PlayerData.charinfo.lastname  }
	end
	cb(onlineList) 
end)
