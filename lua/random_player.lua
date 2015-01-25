#! /usr/bin/lua

-- use socket to communicate with the server directly
require "socket"

-- usage text
local USAGE = [[
NAME
	random_player.lua

USAGE
	random_player.lua --host=HOSTNAME

SUMMARY
	Random ttrts player using lua Connects directly to ttrts server

OPTIONS
	HOSTNAME - host to connect to
]]

-- [[ Perform the handshake to connect ]]
ttrts = {}
do 

ttrts.PerformHandshake = function (sock)

	if not sock then error("Must pass PerformHandshake a socket") end

	local line = sock:receive('*l')

	local player, name = string.match(line, "player (%d+) name ([%a%d]+)")

	-- bail out if handshake information failed
	assert( player and name , "Handshake failed with incorrect player and name")

	print( "Player: " .. player )
	print( "Name: " .. name )

	-- return the handshake line with a new line (removed by the *l call to receive) and string end
	sock:send( line .. "\n" .. "\0" )

	return player, name
end

-- [[ Recieve gamestate info ]]
ttrts.GetState = function (newLine)

	if not newLine then error("Must pass GetState a method") end

	local line = ""
	local state = {}

	-- INVESTIGATE WHY THIS IS NEEDED
	newLine()

	local thename = newLine()
	state.name = string.match( thename, "NAME:([%a%d]+)" )
	assert( state.name, "Gamestate file format missmatch (no name)")

	state.size = {}
	local sizes = newLine()
	state.size.x, state.size.y = string.match( sizes, "SIZE:%[(%d+),(%d+)%]" )
	assert( state.size.x and state.size.y , "Gamestate file format missmatch (size failure)")

	state.turn = string.match( newLine(), "TURN:(%d+)" )
	assert( state.turn, "Gamestate file format missmatch (no turn)")

	-- Get the wall line
	state.walls = {}
	local wallline = newLine()

	assert(string.match( wallline, "WALL:"), "Gamestate file format missmatch (no wall line)")

	-- Grab all walls on the line
	for wallstring in string.gmatch(wallline, "%[%d+,%d+%]") do 
		local wall = {}
		wall.x, wall.y = string.match( wallstring, "%[(%d+),(%d+)%]" )
		table.insert(state.walls,wall)
	end

	assert( newLine() == "~~~~", "Gamestate file format missmatch (missing ~~~~)" )

	-- get the units
	state.units = {}

	local unitline = newLine()
	while unitline ~= "END" do

		local unit = {}
		unit.pos = {}

		-- Parse the unit line
		unit.id, unit.player, unit.vis, unit.dir, unit.pos.x, unit.pos.y = 
			string.match( unitline, "UNIT:(%d+) pl:(%d+) vs:([^%s]+) dr:(%a+) ps:%[(%d+),(%d+)%]")

		assert(unit.id and unit.player and unit.vis and unit.dir and unit.pos.x and unit.pos.y, "gamestate file format missmatch (error with unit)")

		table.insert(state.units,unit)

		unitline = newLine()
	end

	assert(unitline == "END", "Gamestate file format missmatch (didn't end in END)")

	return state
end

-- [[ Get Random Orders from gamestate for a particular player ]]
ttrts.GetRandomOrders = function( id, state )
  
	local orders = ""
	local possibleorders = { "F", "L", "R", "A" }

	local units = state.units
	for key,unit in pairs(units) do
		if unit.id == id then
			local order = "F" -- TODO MAKE RANDOM
			orders = orders .. "ORDER:" .. order .. " id:" .. tostring(id) .. "\n"
		end
	end

	orders = orders .. "END\n"

	return orders
end

-- [[ Send the orders to the server through the socket ]]
ttrts.SendOrders = function( socket, orders )
	assert( string.match(orders,"END"), "Cannot send orders without END" )
	socket:send( orders .. "\0" )
end

end -- end ttrts

-- [[ http://lua-users.org/wiki/AlternativeGetOpt  ]]
function getopt( arg, options ) 
	local tab = {} 
	for k, v in ipairs(arg) do if string.sub( v, 1, 2) == "--" then local x = string.find( v, "=", 1, true ) if x then tab[ string.sub( v, 3, x-1 ) ] = string.sub( v, x+1 ) else tab[ string.sub( v, 3 ) ] = true end 
	elseif string.sub( v, 1, 1 ) == "-" then local y = 2 local l = string.len(v) local jopt while ( y <= l ) do jopt = string.sub( v, y, y ) if string.find( options, jopt, 1, true ) then if y < l then tab[ jopt ] = string.sub( v, y+1 ) y = l else tab[ jopt ] = arg[ k + 1 ] end 
	else tab[ jopt ] = true end 
	y = y + 1 end 
	end end 
	return tab 
end


-- [[ =================== Program Start ======================= ]]

-- [[ Get our options and set up state ]]
local opts = getopt(arg, "host")

-- if no host or host not set
if 	not opts.host 
	or opts.host == true 
then 
	print(USAGE)
	return
end

--[[ Attempt to connect to the server ]]
print( "Connecting to " .. opts.host )

local sock = socket.connect( opts.host, 11715 )
if not sock then error("Failed to connect to " .. opts.host .. " on port 11715") end

print( "Connected to " .. opts.host )

local function GetNewLineFromSocket() 
	return sock:receive('*l')
end

--[[ Perform handshake ]]

-- receive the handshake line
local player, name = ttrts.PerformHandshake(sock)

--[[ Begin main loop ]]
while not gameover do

	-- Grab the current gamestate
	local gamestate = ttrts.GetState( GetNewLineFromSocket )

	-- get the orders
	local orders = ttrts.GetRandomOrders( player, gamestate )

	-- send the orders
	ttrts.SendOrders( sock, orders )

	if table.getn( gamestate.units ) == 0 then gameover = true end
end