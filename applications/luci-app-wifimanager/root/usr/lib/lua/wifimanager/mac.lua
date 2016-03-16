--[[ WIFI MANAGER RANDOM MAC MODULE ]]--

--By Hostle 3/16/2016 { hostle@fire-wrt.com }

local M = {}

require ("uci")
local logger = require ("wifimanager.logger")
local sys = require ("luci.sys")
local util = require ("wifimanager.utils")
local net = require ("wifimanager.net")
local nix = require ("nixio")

--## RANDOM MAC ADDRESS ##--
local randmac = function()
  local mac = sys.exec("dd if=/dev/urandom bs=1024 count=1 2>/dev/null|md5sum|sed 's/^\(..\)\(..\)\(..\)\(..\)\(..\)\(..\).*$/00:\2:\3:\4:\5:01/'")
  mac = string.format("02:%s:%s:%s:%s:%s", mac:sub(3,4), mac:sub(6,7),mac:sub(9,10),mac:sub(12,13),mac:sub(15,16))
  mac = mac:upper()
 return tostring(mac)
end
M.randmac = randmac

--## GET RANDOM MAC STATUS ##--
local get_mac = function()
  local uci = uci.cursor()
  local rmac = tonumber(uci:get("wifimanager", "conn", "randMac"))
  if ( rmac > 0 ) then return true end
 return false
end
M.get_mac = get_mac

--## CHECK IF RANDOM MAC IS SET ##--
local check_mac = function()
  local sec = util.uci_sec("sta","sta")
  local uci = uci.cursor()
  local has_mac = uci:get("wireless.@wifi-iface["..sec.."].macaddr")
  if has_mac then return true end
 return false
end
M.check_mac = check_mac

--## REMOVE A RANDOM MAC ##--
local remove_mac = function()
  local sec = util.uci_sec("sta","sta")
  local uci = uci.cursor()

  if util.has_pending() then 
    logger.log(2,"{ remove_mac function } A UCI CONFIG HAS PENDING CHANGES ")
    util.wait() 
  end
  logger.log(6,"{ remove_mac func } REMOVING RANDOM MAC ADDRESS ")
  uci:delete("wireless.@wifi-iface["..sec.."].macaddr")
  uci:commit("wireless")
  nix.nanosleep(1,0)
end
M.remove_mac = remove_mac

--## ADD A RANDOM MAC ##--
local add_mac = function()
  local sec = util.uci_sec("sta","sta")
  local uci = uci.cursor()
  local mac = randmac()

  if util.has_pending() then 
    logger.log(2,"{ add_mac function } A UCI CONFIG HAS PENDING CHANGES ")
    util.wait() 
  end
    logger.log(6,"{ add_mac func } ADDING RANDOM MAC ADDRESS [ "..mac.." ]")
    uci:set("wireless.@wifi-iface["..sec.."].macaddr="..mac)
    uci:commit("wireless")
    nix.nanosleep(1,0)
end
M.add_mac = add_mac

--## CHECK RANDOM MAC STATUS ##--
local check = function()
   if util.has_pending() then 
     logger.log(2,"{ mac check function } A UCI CONFIG HAS PENDING CHANGES ")
     util.wait() 
   end
   local rmac = get_mac()
   local has_mac = check_mac()

   if rmac then
     if util.has_pending() then util.wait() end
     add_mac()
     return true
   elseif not rmac and has_mac then
     if util.has_pending() then 
       logger.log(2,"{ mac check function } A UCI CONFIG HAS PENDING CHANGES ")
       util.wait() 
     end
     remove_mac()
     return true
  else
    return false
  end
end
M.check = check

return M
