--[[
LuCI - Lua Configuration Interface
$Id: ftp.lua 12/12/2014 by Hostle 
]]--

module("luci.controller.admin.ftp", package.seeall)

require ("uci")
require ("luci.sys")
local ftp = require ("ftp.libftp")


function index()
        local uci = uci.cursor()
	entry({"admin", "ftp"}, alias("admin", "ftp", "ftp"), _("FTP"), 66).index = true
	entry({"admin", "ftp", "ftp"}, cbi("admin_ftp/ftp"), _("FTP Options"), 60)

      if uci:get("ftp", "ftp", "console_set") == "1" then
	entry({"admin", "ftp", "log"}, template("admin_ftp/ftp"), _("FTP Log"),61 )
      end

	entry({"admin", "ftp", "start"}, call("action_start"), _(""),62 )
	entry({"admin", "ftp", "restart"}, call("action_restart"), _(""),63 )
	entry({"admin", "ftp", "clear"}, call("action_clear"), _(""),64 )
	entry({"admin", "ftp", "stop"}, call("action_stop"), _(""),65 )
end

function action_start()
  ftp.start_ftp()
 return
end

function action_restart()
  ftp.restart_ftp()
 return
end

function action_clear()
  ftp.clear_log()
 return
end

function action_stop()
  ftp.stop_ftp()
 return
end

function main (...)
  if arg[1] == "log" then
    log()
  end
 return
end

main ( ...)
