-- luci/openwrt multi user implementation V2 --
-- users.lua by Hostle 01/13/2016 --

module("luci.users", package.seeall)

--## General dependents ##--
require "luci.sys"
require("uci")

--## Add/Remove User files and dependants ##--
local fs = require "nixio.fs"
local util = require ("luci.util")
local uci = uci.cursor()
local passwd = "/etc/passwd"
local passwd2 = "/etc/passwd-"
local shadow = "/etc/shadow"
local shadow2 = "/etc/shadow-"
local groupy = "/etc/group"
local users_file = "/etc/config/users"
local homedir

--## global User buffers ##--
local ui_users = {}
local ui_usernames = {}
local sys_usernames = {}
local valid_users = {}

--## global menu buffers ##--
local status = {}
local system = {}
local network = {}

--## debugging ##--
local debug = 0
local logfile = "/tmp/users.log"

--## users model boiler plate ##--
users = {}
users.prototype = { name = "new user", user_group = "default", shell = "none", menu_items = "none" }
users.metatable = { __index = users.prototype }

function users:new(user)
	setmetatable(users, users.metatable)
	return user
end

--## login function to provide valid usernames, used by dispatcher,index and serviceclt ##--
function login()
local i, pwent
for i, pwent in ipairs(nixio.getpw()) do
  if pwent.uid == 0 or (pwent.uid >= 1000 and pwent.uid < 65534) then
    valid_users[i] = pwent.name
  end
end
  return valid_users
end

--########################################### File parsing fuctions ########################################--

function ui_user()
  local i = 0
  local nbuf = { }
  local user = users:new()
  
  repeat
    local uname = uci:get("users.@user["..i.."].name")
    if uname ~= nil then
      nbuf["name"] = uci:get("users.@user["..i.."].name")
      nbuf["user_group"] = uci:get("users.@user["..i.."].user_group")
      nbuf["shell"] = uci:get("users.@user["..i.."].shell")
      user = users:new({ name = nbuf.name, user_group = nbuf.user_group, shell = nbuf.shell })
      ui_users[user.name] = { user_group = nbuf.user_group, shell = nbuf.shell }
      ui_usernames[#ui_usernames+1]=user.name
    end
    i = i + 1
  until uname == nil
end

--## function to find new users and add them to the system (checks if shell has changed too) ##--
function add_users()
  for i,v in pairs(ui_usernames) do
    if util.contains(valid_users,v) then
      if ui_users[v].shell == "1" then
        check_shell(v,true)
      else
        check_shell(v,false)
      end
    else
      create_user(v,ui_users[v].shell,ui_users[v].user_group)
    end
  end
end

--## function to find deleted ui users and remove them from the system ##--
function del_users()
  for i,v in pairs(valid_users) do
    if not util.contains(ui_usernames,v) then
      remove_user(v)
    end
  end
end

--## function to add user to system ##--
function create_user(user,shell,group)
  if shell == '1' then 
    shell = "/bin/ash" 
  else 
    shell = "/bin/false" 
  end
  check_user(user, group, shell)
  setpasswd(user)
end

--## function to remove user from system ##--
function remove_user(user)
  if user == "root" then return end
  delete_user(user)
end

--## function to check if user gets ssh access (shell or not) ##--
function check_shell(user,has_shell)
  local file = assert(io.open(passwd, "r"))
  local line = ""
  local shell
  local i = 1
  local buf = {}

  for line in file:lines() do
    if line and line ~= "" then
      buf[i]=line
      if line:find(user) then
        shell = line:sub(line:find(":/bin/")+1,-1)
      end
      i = i + 1
    end
  end
  file:close()
  if has_shell and shell ~= "/bin/ash" then
    for i = 1, #buf do
      if buf[i]:find(user) then
        buf[i]=buf[i]:gsub("/bin/false", "/bin/ash")
      end
    end
  elseif not has_shell and shell ~= "/bin/false" then
    for i = 1, #buf do
      if buf[i]:find(user) then
        buf[i]=buf[i]:gsub("/bin/ash", "/bin/false")
      end
    end
  end
  file = assert(io.open(passwd, "w+"))
  for k,v in pairs(buf) do
    file:write(v.."\n")
  end
  file:close()
end

--## DETERMINE THE SECTION NUMBER OF USER ##--
local function get_section(username)
  local i = 0
  repeat
    name = uci:get("users.@user["..i.."].name")
    i = i + 1
  until name == username
  section = i - 1 
 return section
end

--## SPLIT STR INDIVIDUAL TABLE ELEMENTS ##--
local function load_buf(str)
  local buf = {}
  for word in string.gmatch(str, "[^%s]+") do
   buf[#buf+1] = word
  end
 return buf
end

--## GET MENU SUB ##--
local function get_menu_subs(user,sec,menu)
  local menu_name = menu .."_subs"
  local str = uci:get("users.@user["..sec.."]."..menu_name)
 return str
end

--## GET MENU STATUS ##--
function get_menu_status(user,sec,menu)
  local menu_name = menu .."_menus"
  local str = uci:get("users.@user["..sec.."]."..menu_name)
 return str
end

--## GET A TABLE LOADED WITH USERS AVAILABLE MENU ITEMS ##--
function hide_menus(user,menu)
  local buf = {}
  local str
  local menu_name = menu .."_menus"
  if user == "nobody" then return buf end
  local sec = get_section(user)
  local str_menus = get_menu_status(user,sec,menu)
  local str_subs = get_menu_subs(user,sec,menu)
  if str_menus then str = str_menus end
  if str_subs then str = str .. " "..str_subs end
  if str ~= nil then
    buf = load_buf(str)
   return buf
  else
    return buf
  end
end

--## function to set default password for new users ##--
function setpasswd(username,password)
  luci.sys.user.setpasswd(username, "openwrt")
end

--####################################### Ulitlity functions ###############################################--

--## function to check if user exists ##--
function user_exist(username)
 if nixio.getsp(username) ~= nil then return true else return false end
end

--## function to check if path is a file ##--
local function isFile(path)
  if nixio.fs.stat(path, "type") == "reg" then return true else return false end
end

--## function to check if path is a directory ##--
local function isDir(path)
  if nixio.fs.access(path) then return true else return false end
end

--## function to get next available uid ##--
local function get_uid()
local uid = 1000
  while nixio.getpw(uid) do
    uid = uid + 1
  end
 return uid
end

--## function load file into buffer ##--
function load_file(name, buf)
  local i = 1
  local file = io.open(name, "r")

  for line in file:lines() do
    buf[i] = line
    if debug > 0 then print(buf[i]) end
    i = i + 1
  end
  file:close()
 return(buf)
end

--## function to add new item to buffer ##--
function new_item(item, buf)
 buf[#buf+1]=item
 return buf
end

--## function to remove user from buffer ##--
function rem_user(user, buf)
  for i,v in pairs(buf) do
    if v:find(user) then
      table.remove(buf,i)
    end
  end
 return(buf)
end

--## function to write buffer back to file ##--
function write_file(name, buf)
  local file = io.open(name, "w")

  for i,v in pairs(buf) do
    if debug > 0 then print(v) end
    if(i < #buf) then
      file:write(v.."\n")
    else
      file:write(v)
    end
  end
  file:close()
end

--############################################### Add User Functions ######################################--

--## functio to prepare users home dir ##--
function create_homedir(name)
  local home = "/home/"
  local homedir = home .. name
 return homedir
end

--## function add user to passwds ##--
function add_passwd(name,uid,shell,homedir)
  local nuser = name..":x:"..uid..":"..uid..":"..name..":"..homedir..":"..shell
  local nuser2 = name..":*:"..uid..":"..uid..":"..name..":"..homedir..":"..shell
  local buf = {}

  if not user_exist(name) then
    load_file(passwd,buf)
    new_item(nuser,buf)
    write_file(passwd,buf)
    buf = { }
    load_file(passwd2,buf)
    new_item(nuser2,buf)
    write_file(passwd2,buf)
  else
    if(debug > 0) then print("Error { User Already Exists !! }") end
    fs.writefile("/tmp/multi.stderr", "Error add_passwd() { User Already Exist !! }\n")
    return 1
  end
end

--## function add user to shadows ##--
function add_shadow(name)
  local shad = name..":*:11647:0:99999:7:::"
  local buf = { }
  
  if name then
    load_file(shadow,buf)
    new_item(shad,buf)
    write_file(shadow,buf)
    buf = { }
    load_file(shadow2,buf)
    new_item(shad,buf)
    write_file(shadow2,buf)
  else
    if(debug > 0) then print("Error { User Already Exists !! }") end
    fs.writefile("/tmp/multi.stderr", "Error add_shadow() "..name.." { User Already Exists !! }\n")
    return 1
  end
end

--## function to add user to group ##--
function add_group(name,group,uid)
  local grp = group..":x:"..uid..":"
  local buf = { }
  return
  --if user_exist(name) then
    --load_file(groupy,buf)
    --new_item(grp,buf)
    --write_file(groupy,buf)
  --end
end

--## make the users home directory and set permissions to (755) ##--
function make_home_dirs(homedir,name,group)
  local home = "/home"
  if not isDir(home) then
    fs.mkdir(home, 755)
  end
  if not isDir(homedir) then
    fs.mkdir(homedir, 755)
  end
  local cmd = "find "..homedir.." -print | xargs chown "..name..":"..group
  os.execute(cmd)
end

--## function to check if user is valid ##--
function check_user(name, group, shell)
  if user_exist(name) then
    if(debug > 0) then print("Error { User Already Exists !! }") end
    fs.writefile("/tmp/multi.stderr", "Error check_user() { User Already Exists !! }\n")
    return 1
  elseif not name or not group or not shell then
    if(debug > 0) then print("Error { Not Enough Parameters !! }") end
    fs.writefile("/tmp/multi.stderr", "Error check_user2(){ Not Enough Parameters !! }\n")
    return 1
  else
    add_user(name, group, shell)
  end
end

--## function to add user to the system  ##--
function add_user(name, group, shell)
   local name = name
   local uid = get_uid()
   homedir = create_homedir(name,group)
   add_passwd(name,uid,shell,homedir)
   add_shadow(name)
   add_group(name,group,uid)
   make_home_dirs(homedir,name,group)
end

--################################### Remove User functions ###########################################--

--## function remove user from the system ##--
function delete_user(user)
  local buf = { ["passwd"] = {}, ["shadow"] = {}, ["group"] = {} }

  --## load files into indexed buffers ##--
  load_file(passwd, buf.passwd)
  load_file(shadow, buf.shadow)
  load_file(groupy, buf.group)

  --## remove user from buffers ##--
  rem_user(user, buf.passwd)
  rem_user(user, buf.shadow)
  rem_user(user, buf.group)

  --## write edited buffers back to the files ##--
  write_file(passwd, buf.passwd)
  write_file(passwd2, buf.passwd)
  write_file(shadow, buf.shadow)
  write_file(shadow2, buf.shadow)
  write_file(groupy, buf.group)
  luci.sys.call("rm -r -f /home/"..user.."/")
  fs.rmdir("/home/"..user)
end
