--[[ WIFI MANAGER AP MODULE ]]--

--By Hostle 3/7/2016 { hostle@fire-wrt.com }

local M = {}

require ("uci")

local logger = require ("wifimanager.logger")
local lutil = require ("luci.util")
local nix = require ("nixio")
local util = require ("wifimanager.utils")

--## ADD AN AP TO THE NETWORK ##--
local add_ap = function()
  local sec = util.uci_sec("ap","ap")
  local uci = uci.cursor()
  local ap_ssid = uci:get("wifimanager","conn","ap_ssid")
  local ap_enc =  uci:get("wifimanager","conn","ap_encrypt")
  local ap_key =  uci:get("wifimanager","conn","ap_key")
  local dev = util.get_dev()
  local wsta = util.wifi_sta()
  if (sec >= 0) then return false end
  if not lutil.contains(wsta, ap_ssid) then
    if util.not_sane() then return false end
    if util.has_pending() then 
     logger.log(2,"{ add_ap function } A UCI CONFIG HAS PENDING CHANGES ")
     util.wait() 
   end
    logger.log(1,"{add_ap func} NO AP FOUND !!")
    logger.log(1,"{add_ap func} ADDING AP { "..ap_ssid.." }")
    uci:add("wireless", "wifi-iface")
    uci:set("wireless.@wifi-iface[-1].device="..dev)
    uci:set("wireless.@wifi-iface[-1].mode=ap")
    uci:set("wireless.@wifi-iface[-1].network=lan")
    uci:set("wireless.@wifi-iface[-1].ssid="..ap_ssid)
    uci:set("wireless.@wifi-iface[-1].encryption="..ap_enc)
    if ap_enc ~= "none" then
      uci:set("wireless.@wifi-iface[-1].key="..ap_key)
    end
    uci:commit("wireless")
    nix.nanosleep(1,0)
    logger.log(1,"{add_ap func} AP [ "..ap_ssid.." ] CONFIGURED SUCCESSFULLY")
    return true
  end
end
M.add_ap = add_ap

return M
