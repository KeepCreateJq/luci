--[[
LuCI - Lua Configuration Interface
$Id: wifimanager.lua 2/17/2016
$ hostle@fire-wrt.com
]]--

require ("uci")
local sys = require ("luci.sys")
local uci = uci.cursor()
local nets = {}
local i = 1 
local version = sys.exec("wifimanager -s")

uci:foreach("wifimanager", "wifi", function(s) nets[i]=s.ssid i = i + 1 end)
local m, s, o

m = Map("wifimanager", translate("Wifi Manager "..version), translate("Here you can configure your Wifi Manager Settings"))

m.on_after_commit = function()
  sys.exec("reload_config &")
end

s = m:section(NamedSection, "conn", "set")
s.anonymous = true
s.addremove = false

s:tab("gen",  translate("GENERAL SETTINGS"))
s:tab("wlan",  translate("WLAN SETTINGS"))
s:tab("wwan",  translate("WWAN SETTINGS"))


--
-- General Settings
--

o = s:taboption("gen", Value, "ConnCheckTimer", translate("Internet Check Interval"),
	translate("The frequency at which Wifi Manager looks to validate the current network is functioning or to re-enable it if it is not."))
o.default = 60
o.rmempty = false
for i=10, 60, 10 do
 o:value(i, i)
end

o = s:taboption("gen", Value, "net_tries", translate("Internet Check Retries"),
	translate("The number of times Wifi Manager will ping before it disables the STAtion connection."))
o.default = 3
o.rmempty = false
for i=1, 10 do
 o:value(i, i)
end

o = s:taboption("gen", Value, "boot_tries", translate("Boot Internet Retires"),
	translate("The number of times WifiManager will ping before it disables the STAtion connection at boot time."))
o.default = 5
o.rmempty = false
for i=1, 10 do
 o:value(i, i)
end

o = s:taboption("gen", ListValue, "log_lev", translate("Logging"),
	translate("Set the Level of logging messages"))
o.default = "OFF"
o:value("0", "OFF")
o:value("1", "BASIC")
o:value("2", "ADVANCED")
o:value("3", "DEBUGGING")

o = s:taboption("gen", Value, "PingLocation", translate("Ping Adddress"),
	translate("The web address used by Wifi Manager to test (ping) for a working connection."))
o.default = "www.google.com"
o.rmempty = false

o = s:taboption("wlan", Flag, "ap_mode", translate("Auto Add AP"),
	translate("Enables Wifi Manager to automatically replace a missing AP/Master configuration in the wireless config file"))
o.rmempty = false

o = s:taboption("wwan", Flag, "new_nets", translate("Auto Add Networks"),
	translate("Enables Wifi Manager to add a Luci-Wifi STAtion configuration to the Wifi Manager config, if not already included."))
o.rmempty = false

o = s:taboption("wwan", Flag, "randMac", translate("Random Mac Address"),
	translate("Creates a new random MAC address for the STAtion on each device reboot"))
o.rmempty = false

o = s:taboption("wwan", Flag, "fnet", translate("Force a Network"),
	translate("Enable Forcing a Network "))
o.rmempty = false

o = s:taboption("wwan", ListValue, "force", translate("Forced Network"),
	translate("Force a specified Network"))
o:depends("fnet", "1")
o.rmempty = true
for i,v in pairs(nets) do
 o:value(v, v)
end

return m
