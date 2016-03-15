--[[ WIFI MANAGER SCAN MODULE ]]--

--By Hostle 3/7/2016 { hostle@fire-wrt.com }

local M = {}

require ("iwinfo")
local logger = require ("wifimanager.logger")
local util = require ("wifimanager.utils")

--## CHECK IF VAL IS A STRING ##--
local str = function(x)
  if x == nil then
    return "?"
  else
    return tostring(x)
  end
end
M.str = str

--## CHECK IF VAL IS A NUMBER ##--
local num = function(x)
  if x == nil then
    return 0
  else
    return tonumber(x)
  end
end
M.num = num

--## SORT NETWORKS BY SIGNAL STRENGTH ##--
local spairs = function(t, order)
    -- collect the keys
    local keys = {}
    for k in pairs(t) do keys[#keys+1] = k end

    -- if order function given, sort by it by passing the table and keys a, b,
    -- otherwise just sort the keys
    if order then
        table.sort(keys, function(a,b) return order(t, a, b) end)
    else
        table.sort(keys)
    end

    -- return the iterator function
    local i = 0
    return function()
        i = i + 1
        if keys[i] then
            return keys[i], t[keys[i]]
        end
    end
end
M.spairs =spairs

--## SCAN AVAILABLE NETWORKS AND LOAD INTO SORTED TABLE, SSID IS KEY BSSID IS VALUE##--
local net_scan = function(dev)
  if util.not_sane() then return false end
  if util.has_pending() then 
    logger.log(2,"{ net_scan function } A UCI CONFIG HAS PENDING CHANGES ")
    util.wait() 
  end
  logger.log(6,"{net_scan func} NETWORK SCAN { "..dev.." }")
  local api = iwinfo.type(dev)
  local ssta = {}
  if not api then
    logger.log(1,"{net_scan func} NO SUCH WIRELESS DEVICE: " .. dev)
    return ssta
  end
  local iw = iwinfo[api]
  local sr = iw.scanlist(dev)
  local si, se
  local conns = {}
  if sr and #sr > 0 then
    for si, se in ipairs(sr) do
      conns[str(se.ssid)] = {
			     ["bssid"]=se.bssid,
			     ["essid"]= str(se.ssid),
			     ["mode"]=str(se.mode),
			     ["channel"]=num(se.channel),
			     ["signal"]=str(se.signal),
			     ["quality"]= num(se.quality),
			     ["quality_max"]= num(se.quality_max),
			     ["encryption"]=str(se.encryption.description or "None")
			    }
    end
  else
    logger.log(1,"{net_scan func} NO SCAN RESULTS OR SCANNING NOT POSSIBLE")
  end
  local x = 1
  local tbuf = {}
  for i,v in pairs(conns) do
    tbuf[conns[i]["essid"]] = conns[i]["signal"]
    --print(i,i["signal"])
  end
  for k,v in spairs(tbuf, function(t,a,b) return t[b] > t[a] end) do
    if (logger.log_lev > 1) then logger.log(1,"SSID: "..k.." SIGNAL: [ "..v:gsub("-","").." dbm ]") end
     --print(string.format("SSID: %s\nSIGNAL: %s dbm\n",k,v))
    ssta[x]={ k, conns[k]["bssid"], conns[k]["channel"], conns[k]["signal"] }
    x = x + 1
  end
  logger.log(6,"{net_scan func} NETWORK SCAN COMPLETED")
 return ssta
end
M.net_scan = net_scan

return M
