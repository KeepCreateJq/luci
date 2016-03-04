--[[
LuCI - Lua Configuration Interface
$Id: wifimanager.lua 2/17/2016
$ hostle@fire-wrt.com
]]--

local sys = require ("luci.sys")

local m, s, o

m = Map("wifimanager", translate("Wifi Manager"), translate("Here you can configure your Wifi Manager Settings"))

m.on_after_commit = function()
  sys.exec("reload_config &")
end

s = m:section(NamedSection, "conn", "set",  translate("General Settings"))
s.anonymous = true
s.addremove = false

--
-- General Settings
--

o = s:option(Value, "ConnCheckTimer", translate("Internet Check Interval"))
o.default = 60
o.rmempty = false
for i=10, 60, 10 do
 o:value(i, i)
end

o = s:option(Value, "net_tries", translate("Internet Check Retries"))
o.default = 3
o.rmempty = false
for i=1, 10 do
 o:value(i, i)
end

o = s:option(Value, "boot_tries", translate("Boot Internet Retires"))
o.default = 5
o.rmempty = false
for i=1, 10 do
 o:value(i, i)
end

o = s:option(ListValue, "log_lev", translate("Logging"))
o.default = "OFF"
o:value("0", "OFF")
o:value("1", "BASIC")
o:value("2", "ADVANCED")
o:value("3", "DEBUGGING")

o = s:option(Value, "PingLocation", translate("Ping Adddress"))
o.default = "www.google.com"
o.rmempty = false

o = s:option(Flag, "ap_mode", translate("Auto Add AP"))
o.rmempty = false

o = s:option(Flag, "new_nets", translate("Auto Add Networks"))
o.rmempty = false

o = s:option(Flag, "randMac", translate("Random Mac Address"))
o.rmempty = false

return m
