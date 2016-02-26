--[[ NETWORK MANAGER MODULE ]]--

-- VERSION 1.01.1
-- By HOSTLE 2/17/2016

module("wifimanager.functions", package.seeall)

--## DEPENDANCIES ##--
require ("iwinfo")
require ("uci")
local nix = require ("nixio")
local util = require ("luci.util")
local sys = require ("luci.sys")

--## LOCAL BUFFERS ##--
local essid
local debug = 0

--## LOCAL VARS ##--
local uci = uci.cursor()
local ping_addr = uci:get("wifimanager", "conn", "PingLocation")
local boot_tries = tonumber(uci:get("wifimanager", "conn", "boot_tries"))
local net_tries = tonumber(uci:get("wifimanager", "conn", "net_tries"))
local new_nets = tonumber(uci:get("wifimanager", "conn", "new_nets"))
local ap_mode = tonumber(uci:get("wifimanager", "ap", "ap_mode"))

---------------------------------------[[ LOGGING ]]-------------------------------------

--## LOG LEVEL ##--
local log_lev = tonumber(uci:get("wifimanager", "conn", "log_lev"))

--## logger ##-- 
--[[ 1 = alert, 2 = crit, 3 = notice, 4 = warn, 5 = notice, 6 = info, 7 = debug, 8 = notice, 9 = alert ]]--
function logger(lev,msg)
  local log = sys.exec("logger -p daemon."..lev.." "..msg.." -t WifiManager")
 return
end
---------------------------------------[[ END LOGGING ]]---------------------------------


---------------------------------------[[ UTILITIES ]]-----------------------------------

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

--## SORT NETWORKS BY SIGNAL STRENGTH ##--
function spairs(t, order)
    -- collect the keys
    local keys = {}
    for k in pairs(t) do keys[#keys+1] = k end

    -- if order function given, sort by it by passing the table and keys a, b,
    -- otherwise just sort the keys 
    if order then
        table.sort(keys, function(a,b) return order(t, a, b) end)
    else
        table.sort(keys)
    end

    -- return the iterator function
    local i = 0
    return function()
        i = i + 1
        if keys[i] then
            return keys[i], t[keys[i]]
        end
    end
end

--## PREVENT COLLISIONS BETWEEN LUCI AND WIFIMANAGER ##--
function config_check(config)
  local uci = uci.cursor()
  local chg = uci:changes(config) or {}
  for i,v in pairs(chg) do
   if i == config then return false end
  end
 return true
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
  if (debug > 1) then logger(6,"BEGINNING CONFIG SECTION TEST") end
  if (debug > 2) then logger(7,"SEARCH FOR SECTION: { "..field.." }") end
  if (debug > 2) then logger(7,"SEARCH FOR VALUE: { "..val.." }") end
  local i = 0
  local sec
  local uci = uci.cursor()
  repeat
    sec = uci:get("wifimanager.@wifi["..i.."]."..field)
    i = i + 1
    if sec == nil then
       if (debug > 1) then logger(6,"NETWORK SECTION TEST RESULT: { FAILED }") end
       return 0 
     end
  until sec == val
  if sec then
    if ( debug > 1) then logger(6,"NETWORK SECTION TEST RESULT: { PASSED }") end
    if ( debug > 2) then logger(7,"NETWORK SECTION { "..i-1 .." }") end
    return i-1
  else
    return 0
  end
end

--## FIND THE STA SECTION IN THE WIFI CONFIG ##--
function sta_sec()
  if (debug > 1)  then logger(6,"BEGINNING STA SECTION TEST [ STA_SEC FUNCTION ]") end
  if (debug > 2) then logger(7,"SEARCH FOR SECTION: { STA } [ STA_SEC FUNCTION ]") end
  local i = 0
  local sec
  local uci = uci.cursor()
  repeat
    sec = uci:get("wireless.@wifi-iface["..i.."].mode")
    i = i + 1
   if sec == nil then 
     if (debug > 1) then logger(6,"NETWORK SECTION TEST FAILED: { NO STA FOUND } [ STA_SEC FUNCTION ]") end
     return false
   end
  until sec == "sta"
 if sec then
  if (debug > 1) then logger(6,"STA SECTION TEST PASSED: { STA FOUND } [ STA_SEC FUNCTION ]") end
  if (debug > 2) then logger(7,"STA SECTION { "..i-1 .." } [ STA_SEC FUNCTION ]") end
  return i-1
 else
  return false
 end
end

--## FIND THE AP SECTION IN THE WIFI CONFIG ##--
function ap_sec()
  if (debug > 1)  then logger(6,"BEGINNING AP SECTION TEST [ AP_SEC FUNCTION ]") end
  if (debug > 2) then logger(7,"SEARCH FOR SECTION: { AP } [ AP_SEC FUNCTION ]") end
  local i = 0
  local sec
  local uci = uci.cursor()
  repeat
    sec = uci:get("wireless.@wifi-iface["..i.."].mode")
    i = i + 1
   if sec == nil then 
     if (debug > 1) then logger(6,"AP SECTION TEST FAILED: { NO AP FOUND } [ AP_SEC FUNCTION ]") end
     return false
   end
  until sec == "ap"
 if sec then
  if (debug == 1) then logger(6,"AP SECTION TEST PASSED: { AP FOUND } [ AP_SEC FUNCTION ]") end
  if (debug == 2) then logger(7,"AP SECTION { "..i-1 .." } [ AP_SEC FUNCTION ]") end
  return i-1
 else
  return false
 end
end

--## GET THE SSID OF THE CURRENT NETWORK ##--
function get_ssid()
 local sec = sta_sec("sta") or 0
 local uci = uci.cursor()
 local is_up = uci:get("wireless.@wifi-iface["..sec.."].disabled")
 local ssid = uci:get("wireless.@wifi-iface["..sec.."].ssid")
 if is_up == "1" then return "disabled" end
 return ssid
end
---------------------------------------[[ END UTILITIES ]]------------------------------------


-----------------------------------------[[ NETWORK ]]----------------------------------------

--## TEST IF NETWORK IS UP ##-- 
function net_status()
  if (log_lev > 2) then logger(6,"BEGINNING DEVICE STATUS TEST") end
  if (log_lev > 2) then logger(7,"DEVICE: { WWAN }") end
  local conn = ubus.connect(nil,600)
  if not conn then
    logger(1,"Failed to connect to ubusd")
    return false
  end

  local net = conn:call("network.device", "status", { name = "wlan0" })
  conn:close()
  if net then
    if (debug > 1) then logger(6,"DEVICE STATUS TEST RESULT: { PASSED }") end
    return net.up
  end
 return false
end

--## TEST FOR INTERNET CONNECTION PART B ##--
local function inet_test()
  if (debug > 1) then logger(6,"BEGINNING INTERNET CONNECTION TEST") end
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
 return conn
end

--## TEST FOR INTERNET CONNECTION PART A ##--
function conn_test(int)
  if (log_lev > 2) then logger(7,"BEGINNING NETWORK CONNECTION TEST INTERVAL: "..int) end
  for i=1, int do 
    local has_net = inet_test()
    if not has_net then 
      logger(1,"NETWORK CONNECTION TEST [ "..i.." of "..int.." ] FAILED")
      nix.nanosleep(2,5)
      if (i >= int) then return false end
    else
      if (debug > 2) then logger(7,"NETWORK CONNECTION TEST COMPLETED SUCCESSFULY ON ATTEMPT: "..i) end
      if (log_lev > 1) then logger(6,"NETWORK CONNECTION TEST [ "..i.." of "..int.." ] PASSED") end
      break
    end
  end
 return true
end

--## RELOAD NETWORK ##--
function network_reload()
  if (log_lev > 0) then logger(6,"RELOADING NETWORK") end
  sys.exec("/etc/init.d/network reload")
  nix.nanosleep(3,0)
  if (log_lev > 0) then logger(6,"NETWORK RELOADED SUCCESSFULLY") end
 return
end

--## SCAN AVAILABLE NETWORKS AND LOAD INTO SORTED TABLE, SSID IS KEY BSSID IS VALUE##--
function net_scan(dev)
  if (debug > 2) then logger(7,"NETWORK SCAN { "..dev.." }") end
  local api = iwinfo.type(dev)
  if not api then
    print("No such wireless device: " .. dev)
    os.exit(1)
  end
  local iw = iwinfo[api]
  local sr = iw.scanlist(dev)
  local si, se
  local conns = {}
  local ssta = {}
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
    logger(1,"NO SCAN RESULTS OR SCANNING NOT POSSIBLE")
  end
  local x = 1
  local tbuf = {}
  for i,v in pairs(conns) do
    tbuf[conns[i]["essid"]] = conns[i]["signal"]
    --print(i,i["signal"])
  end
  for k,v in spairs(tbuf, function(t,a,b) return t[b] > t[a] end) do
    --print("--",k,v)
    ssta[x]={ k, conns[k]["bssid"], conns[k]["channel"] }
    x = x + 1
  end
  if (debug > 2) then logger(7,"NETWORK SCAN COMPLETED") end
 return ssta
end
---------------------------------------[[ END NETWORK ]]---------------------------------


---------------------------------------[[ CONFIGAURATION ]]------------------------------

--## LOAD KNOWN NETWORKS FROM CONFIG INTO TABLE ##--
local function config_sta()
  local csta = {}
  local uci = uci.cursor()
  uci:foreach("wifimanager", "wifi", function(s) if s.ssid ~= nil then csta[#csta+1]=s.ssid end end )
  return csta
end

local function wifi_sta()
  local wsta = {}
  local uci = uci.cursor()
  uci:foreach("wireless", "wifi-iface", function(s) if s.ssid ~= nil then wsta[#wsta+1]=s.ssid end end )
  return wsta
end

--## ADD THE NETWORK TO THE WIRELESS CONFIG ENABLE IT ##--
local function set_client(ssid,enc,key,bssid,chn)
 local sec = sta_sec("sta") or 0
 if (log_lev == 1) then logger(6,"SETTING UP NEW CLIENT") end
 if (log_lev > 1) then logger(7,"SETTING UP NEW CLIENT SSID: "..ssid) end
  if ssid and enc and key and bssid then
    local uci = uci.cursor()
    uci:set("wireless.@wifi-iface["..sec.."].ssid="..ssid)
    uci:set("wireless.@wifi-iface["..sec.."].encryption="..enc)
    uci:set("wireless.@wifi-iface["..sec.."].key="..key)
    uci:set("wireless.@wifi-iface["..sec.."].bssid="..bssid)
    uci:set("wireless.@wifi-iface["..sec.."].mode=".."sta")
    uci:set("wireless.@wifi-iface["..sec.."].channel=".."chn")
    uci:commit("wireless")
    if (log_lev > 2) then logger(6,"SETTING UP NEW CLIENT { PASSED } ") end
    return true
  else
    if (log_lev > 2) then logger(7,"SETTING UP NEW CLIENT { FAILED } ") end
    return false
  end
end

--## PREPARE A NETWORK ENTRY TO BE ADDED ##--
local function prep_client(ssid,bssid,chn)
  local sec = conf_sec("ssid", ssid)
  if (log_lev > 2) then logger(6,"PREPARING NEW CLIENT [ "..ssid.." ]") end
  local ssid = ssid
  local uci = uci.cursor()
  local enc = uci:get("wifimanager.@wifi["..sec.."].encrypt")
  local key = uci:get("wifimanager.@wifi["..sec.."].key")
   if (log_lev > 2) then logger(7,"SSID: "..ssid.."\tENCRYPTION: "..enc.."\tKEY: "..key) end
  if set_client(ssid,enc,key,bssid,chn) then
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

--## SCAN FOR NETWORKS AND FIND A MATCH IF ANY ##--
function find_network(ssid)
  local uci = uci.cursor()
  local sec = sta_sec("sta")
  local dis = uci:get("wireless.@wifi-iface["..sec.."].disabled")
  local ssta = net_scan("wlan0")
  local csta = config_sta()

  for i,v in ipairs(ssta) do
   if not ssid or v[1] ~= ssid then
    if util.contains(csta, v[1]) then
      logger(1,"FOUND A MATCH "..v[1].." [ FIND_NETWORK FUNCTION ]")
      if ssid == "disabled" then 
        uci:set("wireless.@wifi-iface["..sec.."].disabled=0")
        uci:commit("wireless")
      end
      if prep_client(v[1],v[2],v[3]) then
        logger(1,"NETWORK: [ "..v[1].." ] HAS BEEN CONFIGURED SUCCESFULLY [ FIND_NETWORK FUNCTION ]") 
        return true 
      else
        logger(2,"NETWORK [ "..v[1].." ] FAILED CONECTION TEST !! [ FIND_NETWORK FUNCTION ]")
        logger(1,"SEARCHING FOR NEXT NETWORK !! [ FIND_NETWORK FUNCTION ]")
      end
    end
   end      
  end
  logger(2,"NO TRUSTED NETWORKS FOUND !! [ FIND_NETWORK FUNCTION ]")
  if ssid ~= "disabled" then
    logger(1,"DISABLE STA UNTIL A USABLE NETWORK IS FOUND [ FIND_NETWORK FUNCTION ]")
    uci:set("wireless.@wifi-iface["..sec.."].disabled=1")
    uci:commit("wireless")
    network_reload()
  end
 return false
end

--## ADD AN AP TO THE NETWORK ##--
function add_ap()
  local ap_key
  local wsta = wifi_sta()
  local uci = uci.cursor()
  local ap_ssid = uci:get("wifimanager", "ap", "ap_ssid")
  local ap_enc = uci:get("wifimanager", "ap", "ap_encrypt")
  local dev = uci:get("wireless.@wifi-iface[-1].device")
  local sec = ap_sec() 
  
  if sec then return end 
  
  if ap_enc ~= "none" then
    ap_key = uci:get("wifimanager", "ap", "ap_key")
  end
  
  local sec = ap_sec() 
  local dev = uci:get("wireless.@wifi-iface[-1].device")
  
  if not sec and not util.contains(wsta, ap_ssid) then
    logger(1,"NO AP FOUND !! [ AP FUNCTION ]")
    logger(1,"ADDING AP { "..ap_ssid.." } [ AP FUNCTION ]")
    uci:add("wireless", "wifi-iface")
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
    logger(1,"AP [ "..ap_ssid.." ] CONFIGURED SUCCESSFULLY [ AP FUNCTION ]")
  end
end

--## ADD THE CURRENT NETWORK TO THE CONFIG IF IT DOESN'T EXIST ##--
function add_sta()
  local sec = sta_sec()
  
  if not sec then
	logger(2,"ERROR NOT STA PRESENT IN THE WIRELESS CONFIG !! [ ADD_STA FUNCTION ]")
	return
  end

  local csta = config_sta()
  local uci = uci.cursor()
  local essid = uci:get("wireless.@wifi-iface["..sec.."].ssid")
  local enc = uci:get("wireless.@wifi-iface["..sec.."].encryption")
  local key = uci:get("wireless.@wifi-iface["..sec.."].key")
  if not util.contains(csta, essid) then
    csta = {}
    uci:add("wifimanager", "wifi")
    uci:commit("wifimanager")
    uci:set("wifimanager.@wifi[-1].ssid="..essid)
    uci:set("wifimanager.@wifi[-1].encrypt="..enc)
    uci:set("wifimanager.@wifi[-1].key="..key)
    uci:commit("wifimanager")
    logger(1,"SSID: "..essid.." ADDED TO TRUSTED NETWORKS [ ADD_STA FUNCTION ]")
  end 
 return
end
---------------------------------------[[ END CONFIGUARATION ]]--------------------------
