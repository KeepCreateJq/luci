--[[ WIFI MANAGER FORCE NETWORK MODULE ]]--

--By Hostle 3/7/2016 { hostle@fire-wrt.com }

local M = {}

require ("uci")
local logger = require ("wifimanager.logger")
local net = require ("wifimanager.net")
local util = require ("wifimanager.utils")

local get_fnet = function()
   local uci = uci.cursor()
   local fnet = uci:get("wifimanager", "conn", "force")
   if fnet == nil then return false end
 return fnet
end
M.get_fnet = get_fnet

local check = function(ssid)
  local fn = get_fnet()
  if fn and fn == ssid then
    if (logger.log_lev > 1) then logger.log(7,"FORCED NETWORK IS SET [ "..fn.." ] AND CONFIGURED") end
    return false
  elseif fn then
    logger.log(7,"ATTEMPTING TO CONFIGURE FORCED NETWORK [ "..fn.." ]")
    if net.prep_client(fn) then
      logger.log(7,"FORCE NETWORK IS SET [ "..fn.." ] AND CONFIGURED")
      return true
    else
     logger.log(7,"FAILED TO CONFIGURE FORCED NETWORK [ "..fn.." ]")
    end
  else
    if (logger.log_lev > 2) then logger.log(7,"{ fnet_check function } FORCE NETWORK NOT SET") end
    return false
  end
end
M.check = check

return M
