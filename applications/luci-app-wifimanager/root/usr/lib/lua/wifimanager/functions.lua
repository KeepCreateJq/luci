--[[ WIFI MANAGER FUNCTIONS MODULE ]]--

--By Hostle 3/13/2016 { hostle@fire-wrt.com }

local M = {}
local ap = require ("wifimanager.ap")
local fnet = require ("wifimanager.force")
local logger = require ("wifimanager.logger")
local mac = require ("wifimanager.mac")
local net = require ("wifimanager.net")
local sta = require ("wifimanager.sta")
local util = require ("wifimanager.utils")

--## BOOT FUNCTION ##--
-- wait for network to come up
-- get force network status, if set compare current  ssid angainst the force network
-- if force network is not set or ssid is aligned with forced network check for random mac
-- make any changes neccessary and restart the network

local run = function()
  local uci = uci.cursor()
  local ssid = util.get_ssid() or "NO STA CONFIGURED"
  local boot_tries = tonumber(uci:get("wifimanager", "conn", "boot_tries"))
  
  -- if no station switch to offline mode and wait for Luci to configure a station
  if ssid == "NO STA CONFIGURED" then
    logger.log(1,"{ boot thread } "..ssid.." ... SWITCHING TO OFFLINE MODE")
    net.net_status("no_sta")
    if (logger.log_lev > 1) then logger.log(6,"{ boot thread } WWAN NETWORK IS UP") end
  else
    -- we have a sta so wait for the network to come up --
    repeat
      local up = net.net_status()
    until up
    if (logger.log_lev > 1) then logger.log(6,"{ boot thread } WWAN NETWORK IS UP") end
  end
  -- get current sta --
  if ssid == "DISABLED" then
    logger.log(1,"{ boot thread } STA IS DISABLED")
  else
    logger.log(1,"{boot thread} CONNECTED TO: "..ssid:upper())
  end
  mac.check()
  -- check for force net, if set try to configure the forced network
  if fnet.check(ssid) then
    return 0
  -- force network not available or not set
  -- test current sta is not disabled, if not then test for inet
  elseif net.conn_test(boot_tries) then
      if(logger.log_lev == 1) then logger.log(1,"{ boot function } INTERNET CONNECTION TEST PASSED") end
      return 0
  else
    -- current sta is disabled or does not have net, check for a new network
    if net.find_network(ssid) then
      return 0
    else
    -- check the sta is disabled 
      if net.sta_disable() then
        return 0
      else
	return 1
      end
    end
  end
end
M.run = run

return M
