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

--[[ Attempt to connect to the server ]]
ttrts.ConnectToHost = function (host)
	print( "Connecting to " .. host )

	ttrts.socket = socket.connect( host, 11715 )
	if not ttrts.socket then error("Failed to connect to " .. host .. " on port 11715") end

	print( "Connected to " .. host )

	-- Porform the hanshake
	local line = ttrts.socket:receive('*l')

	local player, name = string.match(line, "player (%d+) name ([%a%d]+)")

	-- bail out if handshake information failed
	assert( player and name , "Handshake failed with incorrect player and name")

	print( "Player: " .. player )
	print( "Name: " .. name )

	-- return the handshake line with a new line (removed by the *l call to receive) and string end
	ttrts.socket:send( line .. "\n" .. "\0" )

	return player, name
end

-- [[ Recieve gamestate info ]]
ttrts.GetStateFromHost = function ()

	if not ttrts.socket then error("ttrts.socket must be set") end

	function newLine()
		return ttrts.socket:receive('*l')
	end

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
ttrts.SendOrdersToHost = function( orders )
	assert( string.match(orders,"END"), "Cannot send orders without END" )
	ttrts.socket:send( orders .. "\0" )
end

-- [[ using method from http://lua-users.org/wiki/AlternativeGetOpt  ]]
ttrts.getopt function ( arg, options ) 
	local tab = {} 
	for k, v in ipairs(arg) do if string.sub( v, 1, 2) == "--" then local x = string.find( v, "=", 1, true ) if x then tab[ string.sub( v, 3, x-1 ) ] = string.sub( v, x+1 ) else tab[ string.sub( v, 3 ) ] = true end 
	elseif string.sub( v, 1, 1 ) == "-" then local y = 2 local l = string.len(v) local jopt while ( y <= l ) do jopt = string.sub( v, y, y ) if string.find( options, jopt, 1, true ) then if y < l then tab[ jopt ] = string.sub( v, y+1 ) y = l else tab[ jopt ] = arg[ k + 1 ] end 
	else tab[ jopt ] = true end 
	y = y + 1 end 
	end end 
	return tab 
end

end -- end ttrts




-- [[ =================== Program Start ======================= ]]

-- [[ Get our options and set up state ]]
local opts = ttrts.getopt(arg, "host")

-- if no host or host not set
if not opts.host or opts.host == true then 
	print(USAGE) return
end

-- [[ Connect to the host ]]
local player, name = ttrts.ConnectToHost(opts.host)

--[[ Main Loop ]]
while true do

	-- Grab the current gamestate
	local gamestate = ttrts.GetStateFromHost()

	print("TURN " .. gamestate.turn )

	-- get the orders
	local orders = ttrts.GetRandomOrders( player, gamestate )

	-- send the orders
	ttrts.SendOrdersToHost( orders )

end