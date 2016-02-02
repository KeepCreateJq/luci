--[[
LuCI - Lua Configuration Interface
$Id: FTP.lua 21/12/2014
$ hostle@fire-wrt.com
]]--

require ("uci")
require("luci.sys")

local uci = uci.cursor()
local ntm = require "luci.model.network".init()
local wan = ntm:get_wannet()
local lan_ip = uci:get("network", "lan", "ipaddr")
local wan_ip = uci:get("network", "wan", "ipaddr")
local wwan_ip = wan:ipaddr()
local m, s, o

m = Map("ftp", translate("FTP SERVER"), translate("Here you can configure the FTP server Settings"))

m.on_after_commit = function()
		        luci.sys.exec("/etc/init.d/ftp restart &>/dev/null")
                    end

s = m:section(NamedSection, "ftp", "ftp",  translate("Server Settings"))
s.anonymous = true
s.addremove = false

--
-- FTP Server
--

o = s:option(ListValue, "ipaddr", translate("FTP Server Addr"))
if lan_ip ~= nil then
  o:value(lan_ip)
end
if wan_ip ~= nil then
  o:value(Wan_ip)
end
if wwan_ip ~= nil then
  o:value(wwan_ip)
end
o.default = lan_ip
o.rmempty = false

o = s:option(Value, "server_port", translate("FTP Server Port"))
o.default = 8383
o.placeholder = "%d%d%d%d"
o.datatype    = "uinteger"
o.rmempty = false

--
-- Log Settings
--

s = m:section(TypedSection, "ftp", translate("Log Settings"))
s.anonymous = true
s.addremove = false

o = s:option(ListValue, "console_set", translate("Console Log"))
o.rmempty = false
o.default = 0
o:value(0, translate("Off"))
o:value(1, translate("On"))
o.rmempty = false

o = s:option(ListValue, "log_level", translate("Log Level"))
o.default = 1
o:value(1, translate("Level 1"))
o:value(2, translate("Level 2"))
o:value(3, translate("Level 3"))
o:value(4, translate("Level 4"))

--
-- Pasv Settings
--

s = m:section(TypedSection, "ftp", translate("Passive Settings"))
s.anonymous = true
s.addremove = false

o = s:option(ListValue, "enable_pasv", translate("Passive Mode"))
o.default = true
o:value("false", translate("Off"))
o:value("true", translate("On"))
o.rmempty = false

o = s:option(ListValue, "pasv_port", translate("Pasv Port"),translate("<code><b>Range:</b> 85xx - 88xx</code>"))
o:depends("enable_pasv", "true")
o.default = 85
o:value(85, translate("85XX"))
o:value(86, translate("86XX"))
o:value(87, translate("87XX"))
o:value(88, translate("88XX"))

m.redirect = luci.dispatcher.build_url("admin/ftp/ftp")

return m
