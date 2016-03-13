--[[ WIFI MANAGER FORCE NETWORK MODULE ]]--

--By Hostle 3/7/2016 { hostle@fire-wrt.com }

local M = {}

require ("uci")
local logger = require ("wifimanager.logger")
local net = require ("wifimanager.net")
local scan = require ("wifimanager.scan")
local util = require ("wifimanager.utils")

local get_fnet = function()
   local uci = uci.cursor()
   local fnet = uci:get("wifimanager", "conn", "force")
   if fnet == nil then return false end
 return fnet
end
M.get_fnet = get_fnet

--## SCAN FOR FORCED NETWORK ##--
local find_fnet = function(fn)
  if util.not_sane() then return false end
  if util.has_pending() then 
    logger.log(2,"{ find_fnet function } A UCI CONFIG HAS PENDING CHANGES ")
    util.wait() 
  end
  logger.log(1,"{find_fnet func} SCANNING FOR FORCED NETWORK: [ "..fn.." ]")
  local ssta = scan.net_scan("phy0")

  if fn then
    for i,v in ipairs(ssta) do
      if v[1] == fn then
        if net.prep_client(v[1],v[2],v[3]) then
          logger.log(1,"{ find_fnet func } FORCED NETWORK: [ "..fn.." ] HAS BEEN CONFIGURED SUCCESSFULLY")
          return true
        else
          logger.log(2,"{ find_fnet func } FORCED NETWORK: [ "..fn.." ] NOT AVAILABLE FOR CONFIGURATION")
          return false
        end
      end
    end
    logger.log(2,"{ find_fnet func } FORCED NETWORK: [ "..fn.." ] NOT ACCESSIBLE")
  end
 return false
end
M.find_fnet = find_fnet

local check = function(ssid)
  local fn = get_fnet()
  if fn and fn == ssid then
    if (logger.log_lev > 1) then logger.log(7,"FORCE NETWORK IS SET [ "..fn.." ] AND CONFIGURED") end
    return false
  elseif fn then
    if find_fnet(fn) then
      return true
    end
  else
    if (logger.log_lev > 2) then logger.log(7,"{ fnet_check function } FORCE NETWORK NOT SET") end
    return false
  end
end
M.check = check

return M
