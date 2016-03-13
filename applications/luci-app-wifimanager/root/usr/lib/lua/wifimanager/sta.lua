--[[ WIFI MANAGER STATION MODULE ]]--

-- By Hostle 3/13/2016 { hostle@fire-wrt.com }

local M = {}

require ("uci")
local logger = require ("wifimanager.logger")
local lutil = require ("luci.util")
local util = require ("wifimanager.utils")

--## ADD THE CURRENT NETWORK TO THE CONFIG IF IT DOESN'T EXIST ##--
local add_sta = function()
  if util.not_sane() then return false end
  if util.has_pending("wifimanager") then 
    logger.log(2,"{ add_sta function } A UCI CONFIG HAS PENDING CHANGES ")
    util.wait() 
  end
  local sec = util.uci_sec("sta","sta")
  local uci = uci.cursor()
  local csta = util.config_sta()
  local essid = uci:get("wireless.@wifi-iface["..sec.."].ssid")
  local enc = uci:get("wireless.@wifi-iface["..sec.."].encryption")
  local key = uci:get("wireless.@wifi-iface["..sec.."].key")

  if not lutil.contains(csta, essid) then
  if util.not_sane() then return false end
  if util.has_pending() then 
    logger.log(2,"{ add_sta function } A UCI CONFIG HAS PENDING CHANGES ")
    util.wait() 
  end
    uci:add("wifimanager", "wifi")
    uci:commit("wifimanager")
    uci:set("wifimanager.@wifi[-1].ssid="..essid)
    uci:set("wifimanager.@wifi[-1].encrypt="..enc)
    uci:set("wifimanager.@wifi[-1].key="..key)
    uci:commit("wifimanager")
    logger.log(1,"{add_sta func} SSID: "..essid.." ADDED TO TRUSTED NETWORKS")
  end
 return true
end
M.add_sta = add_sta

return M
