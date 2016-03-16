--[[ WIFI MANGER STATUS MODULE ]]--

--By Hostle 3/16/2016 { hostle@fire-wrt.com }

local M = {}

local util = require("wifimanager.utils")

--## GET THE SSID OF THE CURRENT NETWORK ##--
local get_ssid = function()
  require ("uci")
  local sec = util.uci_sec("sta","sta")
  local uci = uci.cursor()
  local ssid = uci:get("wireless.@wifi-iface["..sec.."].ssid")
 return ssid
end
M.get_ssid = get_ssid

--## TEST IS STA IS VALID ##--
local sta_valid = function()
  require ("iwinfo")
  local ssid = get_ssid()
  local dev = "phy0"
  local api = iwinfo.type(dev)
  local iw = iwinfo[api]
  local essid = iw.ssid(dev)
  if essid and essid ~= "?" and essid ~= "" then 
    return false 
  else 
    return true 
  end
 return true
end
M.sta_valid = sta_valid

return M
