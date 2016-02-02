--[[
FireWrt - Lua Configuration Interface
$Id: ftpLogger.lua 8382 2013-03-03 19:44:20
$ Hostle : hostle@fire-wrt.com
]]--

module("ftp.libftp", package.seeall)

require("luci.sys")
require("nixio")

local line_cnt = 0
local log_file = "/tmp/ftp.log"

local function create_log()
  luci.sys.exec("echo Ftp Server is Not Running > " ..log_file)
 return
end

if not nixio.fs.stat("/tmp/ftp.log") then create_log() end

local function trun_file(data)
  local file = io.open(log_file, "w")
  file:write(data)
  file:close()
  return
end

local function get_size()
  local line_cnt = 1
  local file = io.open(log_file, "r")
  for line in file:lines() do
    if line and line ~= "" then line_cnt = line_cnt + 1 end
  end
  file:close()
 return line_cnt
end

local function read_log(maxlines,ln)
  local lines = get_size()
  local file = io.open(log_file, "r")

  if(tonumber(lines) > tonumber(maxlines)) then
    for i=1, (lines - maxlines) do
      local line = file:read("*l")
      ln[i] = line
    end
    local data = file:read("*a")
    file:close()
    for j,v in pairs(ln) do
      data:gsub(v, "")
    end
    trun_file(data)
  end

  local file = io.open(log_file, "r")
  for i=1, lines do
    local line = file:read("*l")
    ln[i] = line
  end
  file:close()
 return ln
end

function log()
  local rv = { }
  local ln = { }
  local maxlines = 19
  
  read_log(maxlines,ln)
  if (ln) then
    rv[#rv+1] = {
		 ln = {
		 	ln[1] or '',
		 	ln[2] or '',
		 	ln[3] or '',
		 	ln[4] or '',
		 	ln[5] or '',
		 	ln[6] or '',
		 	ln[7] or '',
		 	ln[8] or '',
		 	ln[9] or '',
		 	ln[10] or '',
		 	ln[11] or '',
		 	ln[12] or '',
		 	ln[13] or '',
		 	ln[14] or '',
		 	ln[15] or '',
		 	ln[16] or '',
			ln[17] or '',
		 	ln[18] or '',
		 	ln[19] or ''
		       }
		  }
    end
  return rv
end

function clear_log()
  luci.sys.exec("echo '' > /tmp/ftp.log &>/dev/null")
 return
end

function start_ftp()
  luci.sys.exec("/etc/init.d/ftp start &>/dev/null")
 return
end

function restart_ftp()
  luci.sys.exec("/etc/init.d/ftp restart &>/dev/null")
 return
end

function stop_ftp()
  luci.sys.exec("/etc/init.d/ftp stop &>/dev/null")
 return
end

function ftp_running()
  local file = io.popen("pidof ftp-server")
  local pid = file:read("*l")
  file:close()
  if pid then return true end
 return false
end
