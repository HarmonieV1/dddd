-- Factures / amendes : stockées en BDD, payées par la cible depuis sa banque (/factures).
lib.callback.register('gs_jobs:billing:create', function(src, target, amount, reason)
    if not GSJ.guard(src, 'bill', 3, 60000) then return false, L('slow_down') end
    local job, def = GSJ.activeJob(src)
    local billing = def and def.society and def.billing
    if not billing or not job.onduty then return false, L('not_on_duty') end

    target, amount = tonumber(target), tonumber(amount)
    if not target or target == src or not Members[target] then return false, L('player_not_found') end
    if not GSJ.isInt(amount, 1, billing.max) then return false, L('amount_invalid') end
    if not Security:PlayersInRange(src, target, Config.PlayerActionRange) then return false, L('too_far') end
    reason = Security:Sanitize(reason, Config.Billing.reasonMaxLength) or billing.label

    local cid = Members[target].cid
    if DB.countBills(cid) >= Config.Billing.maxUnpaidPerPlayer then return false, L('too_many_bills') end
    DB.createBill(cid, job.name, amount, reason, GSJ.cid(src), Bridge:GetName(src) or '')
    GSJ.notify(target, L('bill_received', def.label, amount, reason), 'inform')
    DB.audit('bill', job.name, GSJ.cid(src), cid, amount, reason)
    return true, L('bill_sent')
end)

lib.callback.register('gs_jobs:billing:list', function(src)
    if not GSJ.guard(src, 'bill_list', 5, 10000) then return {} end
    local cid = GSJ.cid(src)
    return cid and DB.getBills(cid) or {}
end)

lib.callback.register('gs_jobs:billing:pay', function(src, id)
    if not GSJ.guard(src, 'bill_pay', 3, 10000) then return false, L('slow_down') end
    local cid, billId = GSJ.cid(src), tonumber(id)
    if not cid or not billId then return false, L('invalid') end

    local ok, res = GSJ.withLock(cid, function()
        local bill = DB.getBill(billId, cid)
        if not bill then return false, 'bill_not_found' end
        if not Bridge:RemoveMoney(src, 'bank', bill.amount, 'facture ' .. bill.job) then return false, 'not_enough_bank' end
        if not DB.deleteBill(billId, cid) then
            Bridge:AddMoney(src, 'bank', bill.amount, 'remboursement facture')
            return false, 'bill_not_found'
        end
        return true, bill
    end)
    if not ok then return false, L(res) end

    local bill = res
    local share = math.floor(bill.amount * Config.Billing.issuerShare)
    local issuer = Bridge:GetSourceByIdentifier(bill.issuer_citizenid)
    if share > 0 and issuer and Bridge:AddMoney(issuer, 'bank', share, 'commission facture') then
        GSJ.notify(issuer, L('bill_paid_issuer', share), 'success')
    else
        share = 0 -- émetteur hors ligne : tout va à la caisse
    end
    if bill.amount - share > 0 then Society.add(bill.job, bill.amount - share) end
    DB.audit('bill_paid', bill.job, cid, bill.issuer_citizenid, bill.amount, nil)
    return true, L('bill_paid', bill.amount)
end)
