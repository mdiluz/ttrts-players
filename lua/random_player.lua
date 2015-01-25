#! /usr/bin/lua

-- use socket to communicate with the server directly
ttrts = require "ttrts"

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

-- [[ Get our options and set up state ]]
local opts = ttrts.getopt(arg, "host")

-- if no host or host not set
if not opts.host or opts.host == true then 
	print(USAGE) return
end

-- [[ Connect to the host ]]
print( "Connecting to " .. opts.host )
local player, name = ttrts.ConnectToHost(opts.host)

print( "Player: " .. player )
print( "Name: " .. name )

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