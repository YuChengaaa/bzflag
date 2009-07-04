--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Test code for the bzfs lua plugin
--

local function printf(fmt, ...)
  print(fmt:format(...))
end

-- prefix all MaxWaitTime names with 'lua'
do
  local origGetMaxWaitTime = bz.GetMaxWaitTime
  local origSetMaxWaitTime = bz.SetMaxWaitTime
  bz.GetMaxWaitTime = function(name, ...)
    origGetMaxWaitTime('lua' .. name, ...)
  end
  bz.SetMaxWaitTime = function(name, ...)
    origSetMaxWaitTime('lua' .. name, ...)
  end
end


do
  local chunk, err = loadfile(bz.GetLuaDirectory() .. 'utils.lua')
  if (not chunk) then
    error(err)
  end
  chunk()
end


function bz.Print(...)
  print(...)
  local table = {...}
  local msg = ''
  for i = 1, #table do
    if (i ~= 1) then msg = msg .. '\t' end
    msg = msg .. tostring(table[i])
  end
  bz.SendMessage(BZ.PLAYER.SERVER, BZ.PLAYER.ALL, msg)
end


bz.Print('-- bzfs.lua --')


bz.Print('luaDir    = ' .. bz.GetLuaDirectory())


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
-- print everything in the global table
--

if (false) then
  print()
  print(string.rep('-', 80))
  table.print(_G, bz.Print)
  print(string.rep('-', 80))
  print()
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Call-Ins
--


function RawChatMessage(msg, src, dst, team)
  print('bzfs.lua', 'RawChatMessage', msg, src, dst, team)
  return msg .. ' -- lua tagged'
end


function FilteredChatMessage(msg, src, dst, team)
end


function GetPlayerSpawnPos(pid, team, px, py, pz, r)
  print('GetPlayerSpawnPos', pid, team, px, py, pz, r)
  return 0, 0, 10, 0
end



local function ExecuteLine(line)
  print('LUA STDIN: ' .. line)
  local chunk, err = loadstring(line, 'doline')
  if (chunk == nil) then
    print('COMPILE ERROR: ' .. err)
  else
    local success, err = tracepcall(chunk)
    if (not success) then
      print('CALL ERROR: ' .. err)
    end
  end
end


function Tick()

  bz.SetMaxWaitTime('luaTick', 0.05)

  if (bz.ReadStdin) then
    local data = bz.ReadStdin()
    if (data) then
      for line in data:gmatch('[^\n]+') do
        print()
        ExecuteLine(line)
        print()
      end
    end
  end

  if (false) then
    for _, pid in ipairs(bz.GetPlayerIDs()) do
      print(pid)
      print(bz.GetPlayerName(pid))
      print(bz.GetPlayerStatus(pid))
      print(bz.GetPlayerPosition(pid))
      print(bz.GetPlayerVelocity(pid))
      print(bz.GetPlayerRotation(pid))
      print(bz.GetPlayerAngVel(pid))
      print()
    end
  end
end


function UnknownSlashCommand(msg, playerID)
  print('bzfs.lua', 'UnknownSlashCommand', playerID, msg)
  local _, _, cmd = msg:find('/run%s+(.*)')
  if (cmd) then
    local chunk, err = loadstring(cmd, 'doline')
    if (chunk == nil) then
      print('doline error: ' .. err)
    else
      local success, err = pcall(chunk)
      if (not success) then
        print(err)
      end
    end
    return true
  end
  return false
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- setup the blocked event map
local blocked = {
  'Tick',
  'Logging',
  'PlayerUpdate',
  'NetDataSend',
  'NetDataReceive',
}
local tmpSet = {}
for _, name in ipairs(blocked) do
  tmpSet[name] = true
end
blocked = tmpSet


-- update the desired call-ins
for name, code in pairs(script.GetCallInInfo()) do
  if (type(_G[name]) == 'function') then
    script.SetCallIn(name, _G[name])
  elseif (not blocked[name]) then
    script.SetCallIn(name, function(...)
      print('bzfs.lua', name, ...)
    end)
  end
end


--script.SetCallIn('Tick', nil) -- annoying, but leave the function defined


-- print the current call-in map
if (true or false) then
  for name, state in pairs(script.GetCallInInfo()) do
    print(name, state.loopType, state.func)
  end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

script.SetCallIn('AllowFlagGrab',
  function(playerID, flagID, flagType, shotType, px, py, pz)
    if (bz.GetPlayerTeam(playerID) == bz.TEAM.RED) then
      return false
    end
  end
)


script.SetCallIn('BZDBChange',
  function(key, value)
--    print('BZDBChange: ' .. key .. ' = ' .. value)
  end
)


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


local lua_block_env = {}
setmetatable(lua_block_env, { __index = _G })

local function CustomMapObject(name, args, data, file, line)
  printf('CustomMapObject:  (%s:%i)  type:"%s"  args:"%s"  ',
         file, line, name, args)
--[[
  for d = 1, #data do
    print('CustomMapObject:    ' .. data[d])
  end
--]]

  if (name == 'lua') then
    local text = ''
    for d = 1, #data do
      text = text .. data[d] .. '\n'
    end
    local chunk, err = loadstring(text, 'lua_block')
    if (not chunk) then
      print(err)
    else
      setfenv(chunk, lua_block_env)
      local success, mapText = pcall(chunk)
      if (not success) then
        print(err)
      else
        if (bz.GetDebugLevel() >= 4) then
          if (type(mapText) == 'string') then
            print('MAPTEXT: ' .. tostring(mapText))
          elseif (type(mapText) == 'table') then
            print('MAPTEXT: ' .. table.concat(mapText, '\n'))
          end
        end
        return mapText
      end
    end
  end
end


bz.AttachMapObject('custom_block',  CustomMapObject)
bz.AttachMapObject('custom_block1', CustomMapObject)
bz.AttachMapObject('custom_block2', CustomMapObject)
bz.AttachMapObject('custom_block3', CustomMapObject)
bz.AttachMapObject('lua',       'endlua',     CustomMapObject)
bz.AttachMapObject('luaplugin', 'endplugin',  CustomMapObject)


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if (false) then
  for _, name in pairs(bz.DB.GetList()) do
    print(name,
          bzdb.GetInt(name),
          bzdb.GetBool(name),
          bzdb.GetFloat(name),
          bzdb.GetString(name))
  end
end

--bzdb.SetString('_mirror', 'black 0.5')
--bzdb.SetString('_skyColor', 'red')
bzdb.SetFloat('_tankSpeed', '50.0')


-- this can override the default, shame
--bz.AttachSlashCommand('luaserver', 'bzfs lua plugin command',
--function(playerID, cmd, msg)
--  print('luaserver command received: '..playerID..' '..cmd..' '..msg)
--end)


include('modules.lua')


--script.SetCallIn('GetWorld',
--  function(mode)


do
  local timers = {}
  setmetatable(timers, { __mode = 'kv' }) -- weak table

  function AddTimer(period, func)
    local timer = { period = period, func = func }
    timers[timer] = bz.GetTimer()
  end

  local function RemoveTimer(period, func)
    for k in pairs(timers) do
      if ((func == k.func) and (k.period == period)) then
        timers[k] = nil
      end
    end
  end

  local function HandleTick()

    if (bz.ReadStdin) then
      local data = bz.ReadStdin()
      if (data) then
        for line in data:gmatch('[^\n]+') do
          print()
          ExecuteLine(line)
          print()
        end
      end
    end

    local maxTime = 0.1
    local nowTime = bz.GetTimer()
    for timer, last in pairs(timers) do
--      print(timer, last)
      local wait = bz.DiffTimers(nowTime, last)
      if (wait >= timer.period) then
        timers[timer] = nowTime
        local mt = 2 * timer.period - wait
        if (mt < maxTime) then
          maxTime = mt
        end
        timer.func()
      else
        local mt = timer.period - wait
        if (mt < maxTime) then
          maxTime = mt
        end
      end
    end
    bz.SetMaxWaitTime('luaTimerTick', maxTime)
--    print('maxTime = ' .. maxTime)
  end

  script.SetCallIn('Tick', HandleTick)
end

@#&*$^@*#&$*&error('FIXME')
