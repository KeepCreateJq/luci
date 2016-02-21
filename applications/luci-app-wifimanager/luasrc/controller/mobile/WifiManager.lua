--[[
LuCI - Lua Configuration Interface
$Id: wifimanager.lua 2/17/2016 by Hostle 
]]--

module("luci.controller.mobile.WifiManager", package.seeall)


function index()
--## Multi User ##--
local fs = require "nixio.fs"
local valid_users = {}

--## load system users into tbl ##--
  if fs.stat("/usr/lib/lua/luci/users.lua") then
    local usw = require "luci.users"
    valid_users = usw.login()
  else
--## no multi user so root is only valid user ##--
    valid_users = { "root" }
  end

	local root = node()
	if not root.target then
		root.target = alias("mobile")
		root.index = true
	end

	local page   = node("mobile")
	page.target  = firstchild()
	page.title   = _("Mobile")
	page.order   = 10
	page.sysauth = valid_users
	page.sysauth_authenticator = "htmlauth"
	page.ucidata = true
	page.index = true

	-- Empty services menu to be populated by addons
	entry({"mobile", "WifiManager"}, alias("mobile","WifiManager", "WifiManager"), _("WifiManger"), 66).index = true
	entry({"mobile","WifiManager", "WifiManager"}, cbi("mobile_WifiManager/WifiManager"), _("Config"), 60)
	entry({"mobile","WifiManager", "Networks"}, cbi("mobile_WifiManager/Networks"), _("Networks"), 61)
	entry({"mobile", "logout"}, call("action_logout"), _("Logout"), 90)
end

function action_logout()
	local dsp = require "luci.dispatcher"
	local utl = require "luci.util"
	local sid = dsp.context.authsession

	if sid then
		utl.ubus("session", "destroy", { ubus_rpc_session = sid })

		luci.http.header("Set-Cookie", "sysauth=%s; expires=%s; path=%s/" %{
			sid, 'Thu, 01 Jan 1970 01:00:00 GMT', dsp.build_url()
		})
	end

	luci.http.redirect(dsp.build_url())
end

function action_start()
  wm.start_wifiMgr()
 return
end

function action_restart()
  wm.restart_wifiMgr()
 return
end

function action_clear()
  wm.clear_log()
 return
end

function action_stop()
  wm.stop_wifiMgr()
 return
end
