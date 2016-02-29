--[[ WIFIMANGER FUNCTIONS MODULE ]]--

-- VERSION 1.01.1
-- By HOSTLE 2/29/2016

module("WifiManager.functions", package.seeall)

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

--## FIND A SECTION IN A UCI CONFIG FILE ##--
function uci_sec(conf,val)
  if (debug > 2) then logger(6,"{"..conf.."_sec func} BEGINNING "..conf:upper().." SECTION TEST") end
  if (debug > 2) then logger(7,"{"..conf.."_sec func} SEARCH FOR SECTION: { "..val:upper().." }") end
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
     if (debug > 1) then logger(6,"{"..conf.."_sec func} "..conf:upper().." SECTION TEST FAILED: { NO "..val:upper().."FOUND }") end
     return -1
   end
  until sec == val
 if sec then
  if (debug == 1) then logger(6,"{"..val.."_sec func}  "..conf:upper().." SECTION TEST PASSED: { "..val:upper().." FOUND }") end
  if (debug == 2) then logger(7,"{"..val.."_sec func} "..conf:upper().." SECTION { "..i-1 .." }") end
  return i-1
 else
  return -1
 end
end


--## GET THE SSID OF THE CURRENT NETWORK ##--
function get_ssid()
 local sec = uci_sec("sta","sta")
 if (sec < 0) then return "disabled" end
 local uci = uci.cursor()
 local dis = uci:get("wireless.@wifi-iface["..sec.."].disabled")
 local ssid = uci:get("wireless.@wifi-iface["..sec.."].ssid")
 if dis == "1" then return "disabled" end
 return ssid
end
---------------------------------------[[ END UTILITIES ]]------------------------------------


-----------------------------------------[[ NETWORK ]]----------------------------------------

--## TEST IF NETWORK IS UP ##-- 
function net_status()
  if (log_lev >= 2) then logger(6,"{net_status func} BEGINNING DEVICE STATUS TEST") end
  if (log_lev >= 2) then logger(7,"{net_status func} DEVICE: { WWAN }") end

  local conn = ubus.connect(nil,600)
  if not conn then
    logger(1,"{net_status func} Failed to connect to ubusd")
     sane_config()
     nix.nanosleep(5,0)
    return false
  end

  local net = conn:call("network.device", "status", { name = "wlan0" })
  conn:close()
  if net and net.up then
    if (debug > 1) then logger(6,"{net_status func} DEVICE STATUS TEST RESULT: { PASSED }") end
    return net.up
  else
    sane_config()
    nix.nanosleep(5,0)
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
  if (log_lev > 0) then logger(6,"{network_reload func} RELOADING NETWORK") end
  sys.exec("/etc/init.d/network reload")
  nix.nanosleep(3,0)
  if (log_lev > 0) then logger(6,"{network_reload func} NETWORK RELOADED SUCCESSFULLY") end
 return
end

--## SCAN AVAILABLE NETWORKS AND LOAD INTO SORTED TABLE, SSID IS KEY BSSID IS VALUE##--
function net_scan(dev)
  if (debug > 2) then logger(7,"{net_scan func} NETWORK SCAN { "..dev.." }") end
  local api = iwinfo.type(dev)
  local ssta = {}
  if not api then
    print("{net_scan func} No such wireless device: " .. dev)
    return ssta
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
    logger(1,"{net_scan func} NO SCAN RESULTS OR SCANNING NOT POSSIBLE")
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
  if (debug > 2) then logger(7,"{net_scan func} NETWORK SCAN COMPLETED") end
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

local function get_dev()
  local uci = uci.cursor()
  local sec
  for sec=0, 5 do
    if uci:get("wireless", "radio"..sec) ~= nil then return "radio"..sec end
  end
 return "radio0"
end

--## ADD A DUMMY STA TO WIRELESS CONFIG ##
local function add_dummy(net_type) 
  if net_type == "sta" then
    uci:add("wireless", "wifi-iface")
    uci:set("wireless.@wifi-iface[-1]=wifi-iface")
    uci:set("wireless.@wifi-iface[-1].network=wwan")
    uci:set("wireless.@wifi-iface[-1].ssid=OpenWrt")
    uci:set("wireless.@wifi-iface[-1].encryption=psk")
    uci:set("wireless.@wifi-iface[-1].device="..get_dev())
    uci:set("wireless.@wifi-iface[-1].mode=sta")
    uci:set("wireless.@wifi-iface[-1].bssid="..randmac())
    uci:set("wireless.@wifi-iface[-1].key=abcd12345678")
    uci:set("wireless.@wifi-iface[-1].disabled=1")
    uci:commit("wireless")
  end
end

--## CHECK IF THE CONFIGS ARE SANE ##--
function sane_config()
  local uci = uci.cursor()
  logger(1,"{sane_config func} CHECK IF CONFIGS ARE SANE")
  local wwan = uci:get("network.wwan")
  local sta = uci_sec("sta","sta")
  local hc = 0
  if not wwan then
    logger(1,"{sane_config func} NO WWAN NETWORK FOUND")
    uci:set("network.wwan=interface")
    uci:set("network.wwan.proto=dhcp")
    uci:commit("network")
    hc = 1
    logger(1,"{sane_config func} WWAN NETWORK ADDED SUCCESSFULLY")
  end
  if (sta < 0) then
    logger(1,"{sane_config func} NO STA NETWORK FOUND")
    add_dummy("sta")
    hc = 1
    logger(1,"{sane_config func} STA NETWORK ADDED SUCCESSFULLY")
  end
  if (hc > 0) then 
    network_reload()
    nix.nanosleep(3,0)
    sys.exec("ifup wwan")
    nix.nanosleep(3,0)
  end
 return true
end
  
--## ADD THE NETWORK TO THE WIRELESS CONFIG ENABLE IT ##--
local function set_client(ssid,enc,key,bssid,chn)
  if (log_lev > 1) then logger(7,"{set_client func} SETTING UP NEW CLIENT SSID: "..ssid) end
  if (log_lev == 1) then logger(6,"{set_client func} SETTING UP NEW CLIENT") end
  if ssid and enc and key and bssid and chn then
    local sec = uci_sec("sta","sta")
    local uci = uci.cursor()
    local dev = get_dev()
    --uci:set("wireless", dev, "channel="..chn)
    uci:set("wireless.@wifi-iface["..sec.."]=wifi-iface")
    uci:set("wireless.@wifi-iface["..sec.."].network=wwan")
    uci:set("wireless.@wifi-iface["..sec.."].ssid="..ssid)
    uci:set("wireless.@wifi-iface["..sec.."].encryption="..enc)
    uci:set("wireless.@wifi-iface["..sec.."].device="..dev)
    uci:set("wireless.@wifi-iface["..sec.."].mode=".."sta")
    uci:set("wireless.@wifi-iface["..sec.."].bssid="..bssid)
    uci:set("wireless.@wifi-iface["..sec.."].key="..key)
    uci:set("wireless.@wifi-iface["..sec.."].disabled=0")
    uci:commit("wireless")
    if (log_lev > 1) then logger(6,"{set_client func} SETTING UP NEW CLIENT { PASSED } ") end
    return true
  else
    if (log_lev > 1) then logger(7,"{set_client func} SETTING UP NEW CLIENT { FAILED } ") end
    return false
  end
end

--## PREPARE A NETWORK ENTRY TO BE ADDED ##--
local function prep_client(ssid,bssid,chn)
  local uci = uci.cursor()
  local sec = uci_sec("wmgr", ssid)
  if (log_lev > 2) then logger(6,"{prep_client func} PREPARING NEW CLIENT [ "..ssid.." ]") end
  local enc = uci:get("wifimanager.@wifi["..sec.."].encrypt")
  local key = uci:get("wifimanager.@wifi["..sec.."].key")
  if (log_lev > 2) then logger(7,"{prep_client func} SSID: "..ssid.."\tENCRYPTION: "..enc.."\tKEY: "..key) end
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
  local sec = uci_sec("sta","sta")
  local dis = uci:get("wireless.@wifi-iface["..sec.."].disabled")
  local ssta = net_scan("wlan0")
  local csta = config_sta()

  for i,v in ipairs(ssta) do
   if not ssid or v[1] ~= ssid then
    if util.contains(csta, v[1]) then
      logger(1,"{find_network func} FOUND A MATCH "..v[1])
      if prep_client(v[1],v[2],v[3]) then
        logger(1,"{find_network func} NETWORK: [ "..v[1].." ] HAS BEEN CONFIGURED SUCCESFULLY")
        return true 
      else
        logger(2,"{find_network func} NETWORK [ "..v[1].." ] FAILED CONECTION TEST !!")
        logger(1,"{find_network func} SEARCHING FOR NEXT NETWORK !!")
      end
    end
   end      
  end
  logger(2,"{find_network func} NO TRUSTED NETWORKS FOUND !!")
  if dis ~= "1" then
    logger(1,"{find_network func} STA DISABLED UNTIL A USABLE NETWORK IS FOUND")
    uci:set("wireless.@wifi-iface["..sec.."].disabled=1")
    uci:commit("wireless")
    network_reload()
  end
 return false
end

--## ADD AN AP TO THE NETWORK ##--
function add_ap()
  local sec = uci_sec("ap","ap") 
  if (sec >= 0) then return end
  local uci = uci.cursor()
  local ap_ssid = uci:get("wifimanager", "ap", "ap_ssid")
  local ap_enc = uci:get("wifimanager", "ap", "ap_encrypt")
  local ap_key = uci:get("wifimanager", "ap", "ap_key")
  local dev = get_dev()
  local wsta = wifi_sta()

  if not util.contains(wsta, ap_ssid) then
    logger(1,"{add_ap func} NO AP FOUND !!")
    logger(1,"{add_ap func} ADDING AP { "..ap_ssid.." }")
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
    nix.nanosleep(1,0)
    logger(1,"{add_ap func} AP [ "..ap_ssid.." ] CONFIGURED SUCCESSFULLY")
    return true
  end
end

--## ADD THE CURRENT NETWORK TO THE CONFIG IF IT DOESN'T EXIST ##--
function add_sta()
  local uci = uci.cursor()
  local sec = uci_sec("sta","sta")
  local csta = config_sta()
  local essid = uci:get("wireless.@wifi-iface["..sec.."].ssid")
  local enc = uci:get("wireless.@wifi-iface["..sec.."].encryption")
  local key = uci:get("wireless.@wifi-iface["..sec.."].key")
  
  if not util.contains(csta, essid) then
    uci:add("wifimanager", "wifi")
    uci:commit("wifimanager")
    uci:set("wifimanager.@wifi[-1].ssid="..essid)
    uci:set("wifimanager.@wifi[-1].encrypt="..enc)
    uci:set("wifimanager.@wifi[-1].key="..key)
    uci:commit("wifimanager")
    logger(1,"{add_sta func} SSID: "..essid.." ADDED TO TRUSTED NETWORKS")
  end 
 return
end
---------------------------------------[[ END CONFIGUARATION ]]--------------------------
