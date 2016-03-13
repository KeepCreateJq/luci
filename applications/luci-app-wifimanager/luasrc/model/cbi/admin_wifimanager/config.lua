--[[
LuCI - Lua Configuration Interface
$Id: wifimanager.lua 3/13/2016
$ hostle@fire-wrt.com
]]--

local m, s, t, o

m = Map("wifimanager", translate("Wifi Manager"), translate("Here you can configure the Networks to be used by Wifi Manager"))

--
-- AP
--

t = m:section(TypedSection, "ap", translate("AP Network"),
		translate("Enter the default device AP information here"))
t.anonymous = true

t:tab("apn",  translate("Access Point"))

t.template = "cbi/tblsection"

o = t:taboption("apn", Value, "ap_ssid", translate("SSID"))
o.default = "Dummy"
o.rmempty = false

o = t:taboption("apn", ListValue, "ap_encrypt", translate("Encyption Type"))
o.default = "none"
o.rmempty = false
o:value("none", "No Encryption")
o:value("wep-open", "Wep Open")
o:value("wep-shared", "No Wep Shared")
o:value("psk", "WPA-PSK")
o:value("psk2", "WPA-PSK2")
o:value("psk-mixed", "WPA-PSK/WPA2-PSK Mixed Mode")

o = t:taboption("apn", Value, "ap_key", translate("Password"))
o.rmempty = true
o.password = true
o:depends("ap_encrypt", "wep-open")
o:depends("ap_encrypt", "wep-shared")
o:depends("ap_encrypt", "psk")
o:depends("ap_encrypt", "psk2")
o:depends("ap_encrypt", "psk-mixed")

--
-- Trusted Networks
--

s = m:section(TypedSection, "wifi", translate("Trusted Networks"),
		translate("Enter connection data for frequently visited Access Points and HotSpots."))
s.anonymous = true
s.addremove = true

s:tab("networks",  translate("Network"))

function s.parse(self, ...)
	TypedSection.parse(self, ...)
end

s.template = "cbi/tblsection"

o = s:taboption("networks", Value, "ssid", translate("SSID"))
o.default = "Dummy"
o.rmempty = false

o = s:taboption("networks", ListValue, "encrypt", translate("Encyption Type"))
o.default = "none"
o.rmempty = false
o:value("none", "No Encryption")
o:value("wep-open", "Wep Open")
o:value("wep-shared", "No Wep Shared")
o:value("psk", "WPA-PSK")
o:value("psk2", "WPA-PSK2")
o:value("psk-mixed", "WPA-PSK/WPA2-PSK Mixed Mode")

o = s:taboption("networks", Value, "key", translate("Password"))
o.rmempty = true
o.password = true
o:depends("encrypt", "wep-open")
o:depends("encrypt", "wep-shared")
o:depends("encrypt", "psk")
o:depends("encrypt", "psk2")
o:depends("encrypt", "psk-mixed")

return m
