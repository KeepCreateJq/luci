--[[ NETWORK MANAGER MODULE ]]--

-- VERSION 1.00
-- By HOSTLE 2/17/2016

module("wifimanager.functions", package.seeall)

--## DEPENDANCIES ##--
require ("iwinfo")
require ("uci")

local nix = require ("nixio")
local util = require ("luci.util")
local sys = require ("luci.sys")
local uci = uci.cursor()

--## LOCAL BUFFERS ##--
local buf = {}
local ssta = {}
local csta = {}
local wsta = {}


--## LOCAL VARS ##--
local ping_addr = uci:get("wifimanager", "conn", "PingLocation")
local boot_tries = tonumber(uci:get("wifimanager", "conn", "boot_tries"))
local net_tries = tonumber(uci:get("wifimanager", "conn", "net_tries"))
local new_nets = tonumber(uci:get("wifimanager", "conn", "new_nets"))
local ap_mode = tonumber(uci:get("wifimanager", "ap", "ap_mode"))


--[[ LOGGING ]]--

--## LOG LEVEL ##--
local log_lev = tonumber(uci:get("wifimanager", "conn", "log_lev"))

--## logger ##-- 
--[[ 1 = alert, 2 = crit, 3 = notice, 4 = warn, 5 = notice, 6 = info, 7 = debug, 8 = notice, 9 = alert ]]--
function logger(lev,msg)
  local log = sys.exec("logger -p daemon."..lev.." "..msg.." -t WifiManager")
 return
end
--[[ END LOGGING ]]--


--[[ UTILITIES ]]--

--## PRINTF FUNCTION ##--
local function printf(fmt, ...)
	print(string.format(fmt, ...))
end

--## CHECK IF VAL IS A STRING ##--
local function str(x)
  if x == nil then
    return "?"
  else
    return tostring(x)
  end
end

--## CHECK IF VAL IS A NUMBER ##--
function num(x)
  if x == nil then
    return 0
  else
    return tonumber(x)
  end
end

--## RANDOM MAC ADDRESS ##--
local function randmac()
  local mac = sys.exec("dd if=/dev/urandom bs=1024 count=1 2>/dev/null|md5sum|sed 's/^\(..\)\(..\)\(..\)\(..\)\(..\)\(..\).*$/00:\2:\3:\4:\5:01/'")
  mac = string.format("%s:%s:%s:%s:%s:%s", mac:sub(0,2),mac:sub(3,4), mac:sub(6,7),mac:sub(9,10),mac:sub(12,13),mac:sub(15,16))
  mac = mac:upper()
 return mac
end

--## FIND THE CONFIG SECTION FOR A GIVEN FIELD AND VALUE ##--
local function conf_sec(field,val)
  if (log_lev > 2) then logger(7,"BEGINNING CONFIG SECTION TEST") end
  if (log_lev > 2) then logger(7,"SEARCH FOR SECTION: { "..field.." }") end
  if (log_lev > 2) then logger(7,"SEARCH FOR VALUE: { "..val.." }") end
  local i = 0
  local sec
  repeat
    sec = uci:get("wifimanager.@wifi["..i.."]."..field)
    i = i + 1
    if sec == nil then
       if (log_lev > 2) then logger(7,"NETWROK SECTION TEST RESULT: { FAILED }") end
       return 0 
     end
  until sec == val
  if sec then
    if (log_lev > 2) then logger(7,"NETWROK SECTION TEST RESULT: { PASSED }") end
    if (log_lev > 2) then logger(7,"NETWROK SECTION { "..i-1 .." }") end
    return i-1
  else
    return 0
  end
end

--## FIND THE STA SECTION IN THE WIFI CONFIG ##--
local function net_sec()
  if (log_lev > 2) then logger(7,"BEGINNING NETWROK SECTION TEST") end
  if (log_lev > 2) then logger(7,"SEARCH FOR SECTION: { sta }") end
  local i = 0
  local sec
  repeat
    sec = uci:get("wireless.@wifi-iface["..i.."].mode")
    i = i + 1
   if sec == nil then 
     if (log_lev > 2) then logger(7,"NETWROK SECTION TEST RESULT: { NOT FOUND }") end
     return 0
   end
  until sec == "sta"
 if sec then
  if (log_lev > 2) then logger(7,"NETWROK SECTION TEST RESULT: { PASSED }") end
  if (log_lev > 2) then logger(7,"NETWROK SECTION { "..i-1 .." }") end
  return i-1
 else
  return 0
 end
end
--[[ END UTILITIES ]]--

--[[ NETWORK ]]--

--## TEST IF NETWORK IS UP ##-- 
function net_status()
  if (log_lev > 2) then logger(7,"BEGINNING DEVICE STATUS TEST") end
  if (log_lev > 2) then logger(7,"DEVICE: { WWAN }") end
  local conn = ubus.connect(nil,600)
  if not conn then
    logger(1,"Failed to connect to ubusd")
    return false
  end

  local net = conn:call("network.device", "status", { name = "wlan0" })
  conn:close()
  if net then
    if (log_lev > 2) then logger(7,"DEVICE STATUS TEST RESULT: { PASSED }") end
    return net.up
  end
 return false
end

--## TEST FOR INTERNET CONNECTION PART B ##--
local function inet_test()
  if (log_lev > 2) then logger(7,"BEGINNING INTERNET CONNECTION TEST") end
  local conn = false
  local cmd = string.format("ping -c 1 -W 1 %q 2>&1", ping_addr) 
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
  if (log_lev > 2) then logger(7,"INTERNET CONNECTION TEST RESULT: { PASSED }") end
 return conn
end

--## TEST FOR INTERNET CONNECTION PART A ##--
function conn_test(int)
  if (log_lev > 2) then logger(7,"BEGINNING NETWORK CONNECTION TEST INTERVAL: "..int) end
  for i=1, int do 
    local has_net = inet_test()
    if not has_net then 
      logger(1,"NETWORK CONNECTION TEST [ "..i.." of "..int.." ] FAILED")
      nix.nanosleep(1,8)
      if (i >= int) then return false end
    else
      if (log_lev > 2) then logger(7,"NETWORK CONNECTION TEST COMPLETED SUCCESSFULY ON ATTEMPT: "..i) end
      if (log_lev > 1) then logger(6,"NETWORK CONNECTION TEST [ "..i.." of "..int.." ] PASSED") end
      break
    end
  end
 return true
end

--## RELOAD NETWORK ##--
function network_reload()
  if (log_lev > 0) then logger(7,"RELOADING NETWROK") end
  sys.exec("/etc/init.d/network reload")
  nix.nanosleep(3,0)
  if (log_lev > 0) then logger(7,"NETWROK RELAOADED SUCCESSFULLY") end
 return
end

--## SCAN AVAILABLE NETWORKS AND LOAD INTO TABLE, SSID IS KEY BSSID IS VALUE##--
function net_scan(dev)
  if (log_lev > 2) then logger(7,"NETWROK SCAN { "..dev.." }") end
  local api = iwinfo.type(dev)
  if not api then
    print("No such wireless device: " .. dev)
    os.exit(1)
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
    logger(1,"No scan results or scanning not possible")
  end
  for i,v in pairs(conns) do
    ssta[i]=conns[i]["bssid"]
  end
  if (log_lev > 2) then logger(7,"NETWROK SCAN COMPLETED") end
 return ssta
end
--[[ END NETWORK ]]--

--[[ CONFIGAURATION ]]--

--## LOAD KNOWN NETWORKS FROM CONFIG INTO TABLE ##--
local function config_sta()
  uci:foreach("wifimanager", "wifi", function(s) if s.ssid ~= nil then csta[#csta+1]=s.ssid end end )
end

local function wifi_sta()
  uci:foreach("wireless", "wifi-face", function(s) if s.ssid ~= nil then wsta[#wsta+1]=s.ssid end end )
end

--## ADD THE NETWORK TO THE WIRELESS CONFIG ##--
local function set_client(ssid,enc,key)
 local sec = net_sec() or 0
 local bssid = ssta[ssid]
 if (log_lev > 1) then logger(6,"SETTING UP NEW CLIENT") end
 if (log_lev > 2) then logger(7,"SETTING UP NEW CLIENT "..ssid.." "..enc.." "..key.." "..bssid) end
  if ssid and enc and key and bssid then
    uci:set("wireless.@wifi-iface["..sec.."].ssid="..ssid)
    uci:set("wireless.@wifi-iface["..sec.."].encryption="..enc)
    uci:set("wireless.@wifi-iface["..sec.."].key="..key)
    uci:set("wireless.@wifi-iface["..sec.."].bssid="..bssid)
    uci:set("wireless.@wifi-iface["..sec.."].mode=".."sta")
    uci:commit("wireless")
    if (log_lev > 2) then logger(7,"SETTING UP NEW CLIENT { OK } ") end
    return true
  else
    if (log_lev > 2) then logger(7,"SETTING UP NEW CLIENT WAS { FAILED } ") end
    return false
  end
end

--## PREPARE A NETWORK ENTRY AND SEND IT TO SET_NETWORK TO BE ADDED ##--
local function prep_client(ssid)
  local sec = conf_sec("ssid", ssid)
  if (log_lev > 1) then logger(6,"PREPARING NEW CLIENT") end
  local ssid = ssid
  local enc = uci:get("wifimanager.@wifi["..sec.."].encrypt")
  local key = uci:get("wifimanager.@wifi["..sec.."].key")
   if (log_lev > 2) then logger(7,"SSID: "..ssid.."\tENCRYPTION: "..enc.."\tKEY: "..key) end
  if set_client(ssid,enc,key) then
    network_reload()
    repeat
        local up = net_status()
    until up
    if conn_test(net_tries) then
      return true 
    end
  end
 return false
end


--## SCAN FOR NETWORKS AND FFIND A MATCH IF ANY ##--
function find_network()
  net_scan("wlan0")
  config_sta()

  for i,v in pairs(ssta) do
    if util.contains(csta, i) then
      logger(1,"FOUND A MATCH "..i)
      if prep_client(i) then
        logger(1,"NETWORK: [ "..i.." ] HAS BEEN CONFIGURED SUCCESFULLY") 
        if (new_nets > 0) then
            if not util.contains(csta, ssid) then
              add_network()
            end
        end
        return true 
      else
        logger(2,"NETWORK [ "..i.." ] FAILED CONECTION TEST !!")
        logger(1,"SEARCHING FOR NEXT NETWORK !!")
      end
    end      
  end
 logger(2,"NO TRUSTED NETWORKS FOUND !!")
 return false
end

--## ADD AN AP TO THE NETWORK ##--
function add_ap()
  if ap_mode ~= 1 then return end
  wifi_sta()
  local ap_ssid = uci:get("wifimanager", "ap", "ap_ssid")
  local ap_enc = uci:get("wifimanager", "ap", "ap_encrypt")
  if ap_enc ~= "none" then
    local ap_key = uci:get("wifimanager", "ap", "ap_key")
  end
  local sec = net_sec()
  local dev = uci:get("wireless.@wifi-iface["..sec.."].device")
  if not util.contains(wsta, ap_ssid) then
    uci:add("wireless", "wifi-iface")
    uci:commit("wireless")
    uci:set("wireless.@wifi-iface[-1].device="..dev)
    uci:set("wireless.@wifi-iface[-1].mode=ap")
    uci:set("wireless.@wifi-iface[-1].ssid="..ap_ssid)
    uci:set("wireless.@wifi-iface[-1].encryption="..ap_enc)
    if ap_enc ~= "none" then 
      uci:set("wireless.@wifi-iface[-1].key="..ap_key)
    end
    uci:set("wireless.@wifi-iface[-1].network=lan")
    uci:commit("wireless")
    network_reload()
    logger(1,"ADDED AP [ "..ap_ssid.." ]")
  end
end

--## ADD THE CURRENT NETWORK TO THE CONFIG IF IT DOESN'T EXIST ##--
function add_network()
  local sec = net_sec()
  config_sta()
  local ssid = uci:get("wireless.@wifi-iface["..sec.."].ssid")
  local enc = uci:get("wireless.@wifi-iface["..sec.."].encryption")
  local key = uci:get("wireless.@wifi-iface["..sec.."].key")
  if not util.contains(csta, ssid) then
    uci:add("wifimanager", "wifi")
    uci:commit("wifimanager")
    uci:set("wifimanager.@wifi[-1].ssid="..ssid)
    uci:set("wifimanager.@wifi[-1].encrypt="..enc)
    uci:set("wifimanager.@wifi[-1].key="..key)
    uci:commit("wifimanager")
    logger(1,"SSID: "..ssid.." ADDED TO TRUSTED NETWORKS")
  end 
 return
end