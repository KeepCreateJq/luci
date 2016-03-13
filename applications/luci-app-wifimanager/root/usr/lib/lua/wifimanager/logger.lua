--[[ WIFI MANAGER LOGGING MODULE ]]--

-- By Hostle 3/13/2016 { hostle@fire-wrt.com }

local M = {}

require ("uci")
local sys = require ("luci.sys")
local uci = uci.cursor()

--## LOG LEVEL ##--
local log_lev = tonumber(uci:get("wifimanager", "conn", "log_lev"))
M.log_lev = log_lev

--## logger ##--
--[[ 1 = alert, 2 = crit, 3 = notice, 4 = warn, 5 = notice, 6 = info, 7 = debug, 8 = notice, 9 = alert ]]--
local log = function(lev,msg)
  local log = sys.exec("logger -p daemon."..lev.." "..msg.." -t WifiManager")
 return
end
M.log = log

return M
