 --[[ WIFI MANAGER NETWORK MODULE ]]--

--By Hostle 3/7/2016 { hostle@fire-wrt.com }

local M = {}

require ("uci")
local ap = require ("wifimanager.ap")
local debug = 0
local logger = require ("wifimanager.logger")
local nix = require ("nixio")
local scan = require ("wifimanager.scan")
local sta = require ("wifimanager.sta")
local sys = require ("luci.sys")
local util = require ("wifimanager.utils")
local lutil = require ("luci.util")

--## GET NET TRIES ##--
local get_tries = function()
 local uci = uci.cursor()
 local net_tries = tonumber(uci:get("wifimanager", "conn", "net_tries"))
 return net_tries or 0
end
M.get_tries = get_tries

--## GET NET TRIES ##--
local ping_addr = function()
 local uci = uci.cursor()
 local ping_addr = uci:get("wifimanager", "conn", "PingLocation")
 return ping_addr or "www.google.com"
end
M.get_tries = get_tries

--## GET AUTO AP STATUS ##--
local get_apmode = function()
  local uci = uci.cursor()
  local ap_mode = tonumber(uci:get("wifimanager", "conn", "ap_mode"))
  if (ap_mode > 0) then return true end
 return false
end
M.get_apmode = get_apmode

--## GET AUTO ADD NETWORKS STATUS ##--
local get_newnets = function()
  local uci = uci.cursor()
  local new_nets = tonumber(uci:get("wifimanager", "conn", "new_nets"))
  if (new_nets > 0) then return true end
 return false
end
M.get_newnets = get_newnets

--## RELOAD NETWORK ##--
local network_reload = function()
  if util.not_sane() then return false end
  if util.has_pending() then 
    logger.log(2,"{ network_reload function } A UCI CONFIG HAS PENDING CHANGES ")
    util.wait() 
  end
  if (logger.log_lev > 0) then logger.log(6,"{network_reload func} RELOADING NETWORK") end
  sys.exec("/etc/init.d/network reload")
  nix.nanosleep(3,0)
  if (logger.log_lev > 0) then logger.log(6,"{network_reload func} NETWORK RELOADED SUCCESSFULLY") end
 return
end
M.network_reload = network_reload


 --## TEST IF NETWORK IS UP ##--
local net_up = function()
  require ("ubus")
  
  local conn = ubus.connect(nil,600)
  if not conn then
    logger.log(2,"{ net_status func } ERROR FAILED TO CONNECT TO UBUSD !!")
    os.exit(1)
  end

  local net = conn:call("network.device", "status", { name = "wlan0" })
  conn:close()
  if net and net.up then
    return net.up
  end
 return false
end
M.net_up = net_up

local net_status = function(no_sta)
  local uci = uci.cursor()
  if no_sta then
    local sec = util.uci_sec("ap","ap")
    if (sec < 0) then ap.add_ap() end
    local sta = util.uci_sec("sta","sta")
    logger.log(6,"{ net_status func } NO STA AVAIABLE CHECK SETTINGS !!")
    while (sta < 0) do
      sta = util.uci_sec("sta","sta")
      nix.nanosleep(1,0)
    end
    logger.log(6,"{ net_status func } STA FOUND ... SWITCHING TO ONLINE MODE")
  end
    if (logger.log_lev > 2) then logger.log(6,"{net_status func} BEGINNING NETWORK STATUS TEST") end
    if (logger.log_lev > 2) then logger.log(7,"{net_status func} NETWORK: { WWAN }") end
    local net = net_up()
    if net then 
      if (logger.log_lev > 1 ) then logger.log(6,"{net_status func} NETWORK STATUS TEST RESULT: { PASSED }") end
      return true
    else
      if (logger.log_lev > 1 ) then logger.log(6,"{net_status func} WAITING FOR NETWORK TO COME UP ...") end
      while not net do
        net = net_up()
        nix.nanosleep(2,0)
      end
    end
    nix.nanosleep(2,0)
    --if (logger.log_lev >= 2 ) then logger.log(6,"{net_status func} NETWORK STATUS TEST RESULT: { PASSED }") end
 return true
end
M.net_status = net_status

--## TEST FOR INTERNET CONNECTION PART B ##--
local inet_test = function()
  if util.not_sane() then return false end
  if util.has_pending() then 
    logger.log(2,"{ inet_test function } A UCI CONFIG HAS PENDING CHANGES ")
    util.wait() 
  end
  local conn = false
  local addr = ping_addr()
  local cmd = string.format("ping -c 1 -W 1  %q 2>&1",addr )
  local util = io.popen(cmd)
  if util then
    while true do
      ln = util:read("*l")
      if not ln then break end
      if ln:find("time") then
       conn = true
      end
    end
    util:close()
  end
 return conn
end
M.inet_test = inet_test

--## TEST FOR INTERNET CONNECTION PART A ##--
local conn_test = function(int)
  if util.not_sane() then return false end
  if util.has_pending() then 
    logger.log(2,"{ conn_test function } A UCI CONFIG HAS PENDING CHANGES ")
    util.wait() 
  end
  if (logger.log_lev >= 2) then logger.log(7,"BEGINNING INTERNET CONNECTION TEST INTERVAL: "..int) end
  net_status()
  for i=1, int do
    local has_net = inet_test()
    if not has_net then
      logger.log(1,"INTERNET CONNECTION TEST [ "..i.." of "..int.." ] FAILED")
      nix.nanosleep(1,0)
      if (i >= int) then return false end
    else
      if (logger.log_lev >= 1) then logger.log(6,"INTERNET CONNECTION TEST [ "..i.." of "..int.." ] PASSED") end
      local ap_mode = get_apmode()
      local new_nets = get_newnets()
      if util.has_pending() then 
        logger.log(2,"{ conn_test function } A UCI CONFIG HAS PENDING CHANGES ")
        util.wait() 
      end
      if new_nets then sta.add_sta() end
      if ap_mode then if ap.add_ap() then network_reload() end end
      break
    end
  end
 return true
end
M.conn_test = conn_test

--## ADD THE NETWORK TO THE WIRELESS CONFIG ENABLE IT ##--
local set_client = function(ssid,enc,key,bssid,chn)
  if util.not_sane() then return end
  if util.has_pending() then 
    logger.log(2,"{ set_client function } A UCI CONFIG HAS PENDING CHANGES ")
    util.wait() 
  end
  if (logger.log_lev > 1) then logger.log(7,"{set_client func} SETTING UP NEW STA SSID: "..ssid) end
  if (logger.log_lev == 1) then logger.log(6,"{set_client func} SETTING UP STA CLIENT") end
  if ssid and enc and key and bssid and chn then
    local sec = util.uci_sec("sta","sta")
    local uci = uci.cursor()
    local dev = util.get_dev()
    if util.not_sane() then return false end
    if util.has_pending() then 
      logger.log(2,"{ set_client function } A UCI CONFIG HAS PENDING CHANGES ")
      util.wait() 
    end
    uci:set("wireless","radio0","channel","auto")
    uci:set("wireless.@wifi-iface["..sec.."]=wifi-iface")
    uci:set("wireless.@wifi-iface["..sec.."].network=wwan")
    uci:set("wireless.@wifi-iface["..sec.."].ssid="..ssid)
    uci:set("wireless.@wifi-iface["..sec.."].encryption="..enc)
    uci:set("wireless.@wifi-iface["..sec.."].device="..dev)
    uci:set("wireless.@wifi-iface["..sec.."].mode=".."sta")
    if bssid == "00:00:00:00:00:00" then 
      uci:delete("wireless.@wifi-iface["..sec.."].bssid")
    else
      uci:set("wireless.@wifi-iface["..sec.."].bssid="..bssid)
    end
    uci:set("wireless.@wifi-iface["..sec.."].key="..key)
    uci:set("wireless.@wifi-iface["..sec.."].disabled=0")
    uci:commit("wireless")
    if (logger.log_lev > 1) then logger.log(6,"{set_client func} SETTING UP NEW STA { PASSED } ") end
    return true
  else
    if (log_lev > 1) then logger.log(7,"{set_client func} SETTING UP NEW STA { FAILED } ") end
    return false
  end
end
M.set_client = set_client

--## PREPARE A NETWORK ENTRY TO BE ADDED ##--
local prep_client = function(ssid,bssid,chn)
  if util.not_sane() then return false end
  if util.has_pending() then 
    logger.log(2,"{ add_sta function } A UCI CONFIG HAS PENDING CHANGES ")
    util.wait() 
  end  local uci = uci.cursor()
  local sec = util.uci_sec("wmgr", ssid)
  if (logger.log_lev > 2) then logger.log(6,"{prep_client func} PREPARING NEW CLIENT [ "..ssid.." ]") end
  local enc = uci:get("wifimanager.@wifi["..sec.."].encrypt")
  local key = uci:get("wifimanager.@wifi["..sec.."].key")
  if (logger.log_lev > 2) then logger.log(7,"{prep_client func} SSID: "..ssid.."\tENCRYPTION: "..enc.."\tKEY: "..key) end
  if not bssid then bssid = "00:00:00:00:00:00" end
  if not chn then chn = "auto" end
  if set_client(ssid,enc,key,bssid,chn) then
    network_reload()
    nix.nanosleep(2,0)
    repeat
        local up = net_status()
    until up
    if conn_test(get_tries()) then
      return true
    end
  end
 return false
end
M.prep_client = prep_client

 --## SCAN FOR NETWORKS AND FIND A MATCH IF ANY ##--
local find_network = function(ssid)
  if util.not_sane() then return false end
  if util.has_pending() then 
    logger.log(2,"{ find_network function } A UCI CONFIG HAS PENDING CHANGES ")
    util.wait() 
  end
  local sec = util.uci_sec("sta","sta")
  local uci = uci.cursor()
  local dis = uci:get("wireless.@wifi-iface["..sec.."].disabled")
  local ssta = scan.net_scan("phy0") or {}
  local csta = util.config_sta()

  for i,v in ipairs(ssta) do
   if not ssid or v[1] ~= ssid then
    if lutil.contains(csta, v[1]) then
      nix.nanosleep(0,6)
      logger.log(1,"{find_network func} FOUND A MATCH [ SSID: "..v[1].." SIGNAL: "..v[4]:gsub("-",""))
      if prep_client(v[1],v[2],v[3]) then
        logger.log(1,"{find_network func} NETWORK: [ "..v[1].." ] HAS BEEN CONFIGURED SUCCESSFULLY")
        return true 
      else
        logger.log(2,"{find_network func} NETWORK [ "..v[1].." ] FAILED CONECTION TEST !!")
        logger.log(1,"{find_network func} SEARCHING FOR NEXT NETWORK !!")
      end
    end
   end      
  end
  logger.log(2,"{find_network func} NO TRUSTED NETWORKS FOUND !!")
 return false
end
M.find_network = find_network

local sta_disable = function()
  if util.not_sane() then return false end
    local ap_sec = util.uci_sec("ap","ap")
    if (ap_sec < 0) then return true end
    local sec = util.uci_sec("sta","sta")
    local uci = uci.cursor()
    local dis = tonumber(uci:get("wireless.@wifi-iface["..sec.."].disabled")) or 0
    logger.log(1,"{ find_network func } STA DISABLED UNTIL A USABLE NETWORK IS FOUND")
    if ( dis > 0 ) then return true end
    uci:set("wireless.@wifi-iface["..sec.."].disabled=1")
    uci:commit("wireless")
   network_reload()
 return true
end
M.sta_disable = sta_disable

return M
