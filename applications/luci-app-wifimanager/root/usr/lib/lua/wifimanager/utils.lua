--[[ WIFI MANAGER UTILITIES MODULE ]]--

--By Hostle 3/7/2016 { hostle@fire-wrt.com }

local M = {}

require ("uci")
local debug = 0
local logger = require ("wifimanager.logger")
local nix = require ("nixio")

--## FIND A SECTION IN A UCI CONFIG FILE ##--
local uci_sec = function(conf,val)
  if (debug > 2) then logger.log(6,"{"..conf.."_sec func} BEGINNING "..conf:upper().." SECTION TEST") end
  if (debug > 2) then logger.log(7,"{"..conf.."_sec func} SEARCH FOR SECTION: { "..val:upper().." }") end
  local i = 0
  local sec
  local uci = uci.cursor()
  repeat
    if conf == "wmgr" then
	  sec = uci:get("wifimanager.@wifi["..i.."].ssid")
	else
	  sec = uci:get("wireless.@wifi-iface["..i.."].mode")
	end
    i = i + 1
   if sec == nil then
     if (debug > 1) then logger.log(6,"{"..conf.."_sec func} "..conf:upper().." SECTION TEST FAILED: { NO "..val:upper().."FOUND }") end
     return -1
   end
  until sec == val
 if sec then
  if (debug == 1) then logger.log(6,"{"..val.."_sec func}  "..conf:upper().." SECTION TEST PASSED: { "..val:upper().." FOUND }") end
  if (debug == 2) then logger.log(7,"{"..val.."_sec func} "..conf:upper().." SECTION { "..i-1 .." }") end
  return i-1
 else
  return -1
 end
end
M.uci_sec = uci_sec

--## LOAD STA NETWORKS FROM CONFIG INTO TABLE ##--
local config_sta = function()
  local csta = {}
  local uci = uci.cursor()
  uci:foreach("wifimanager", "wifi", function(s) if s.ssid ~= nil then csta[#csta+1]=s.ssid end end )
  return csta
end
M.config_sta = config_sta

--## LOAD TRUSTED NETWORKS FROM WIRELESS CONFIG INTO TABLE ##--
local wifi_sta = function()
  local wsta = {}
  local uci = uci.cursor()
  uci:foreach("wireless", "wifi-iface", function(s) if s.ssid ~= nil then wsta[#wsta+1]=s.ssid end end )
  return wsta
end
M.wifi_sta = wifi_sta

--## GET THE RADIO NAME ##--
local get_dev = function()
  local uci = uci.cursor()
  local sec
  for sec=0, 5 do
    if uci:get("wireless", "radio"..sec) ~= nil then return "radio"..sec end
  end
 return "radio0"
end
M.get_dev = get_dev

--## PREVENT COLLISIONS BETWEEN LUCI AND WIFIMANAGER ##--
local has_pending = function(sta)
  local uci = uci.cursor()
  local chg = uci:changes() or {}
  for i,v in pairs(chg) do
    if i == "wirelss" or i == "network" or i == "firewall" or i == sta then
      return true
    end
  end
 return false
end
M.has_pending = has_pending

local wait = function()
  logger.log(2,"{ has_pending function } WAITING FOR UCI COMMIT ")
  local task = has_pending
  while task do
   task = has_pending()
   nix.nanosleep(1,0)
  end
 return true
end
M.wait = wait

--## CHECK IF SYSTEM IS SANE ##--
local not_sane = function()
  local uci = uci.cursor()
  local sec = uci_sec("sta","sta")
  local net = uci:get("network", "wwan")
  local sta = (sec >= 0 )
  if net and sta then return false end
 return true
end
M.not_sane = not_sane

--## GET THE SSID OF THE CURRENT NETWORK ##--
local get_ssid = function()
  if not_sane() then return "NO STA CONFIGURED" end
  local sec = uci_sec("sta","sta")
  if (sec < 0 ) then return "NO STA CONFIGURED" end 
  local uci = uci.cursor()
  local dis = uci:get("wireless.@wifi-iface["..sec.."].disabled")
  local ssid = uci:get("wireless.@wifi-iface["..sec.."].ssid")
  if dis == "1" then return "DISABLED" end
 return ssid
end
M.get_ssid = get_ssid

return M
