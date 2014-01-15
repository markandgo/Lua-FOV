--[[
zlib License:

Copyright (c) 2014 Minh Ngo

This software is provided 'as-is', without any express or implied
warranty. In no event will the authors be held liable for any damages
arising from the use of this software.

Permission is granted to anyone to use this software for any purpose,
including commercial applications, and to alter it and redistribute it
freely, subject to the following restrictions:

   1. The origin of this software must not be misrepresented; you must not
   claim that you wrote the original software. If you use this software
   in a product, an acknowledgment in the product documentation would be
   appreciated but is not required.

   2. Altered source versions must be plainly marked as such, and must not be
   misrepresented as being the original software.

   3. This notice may not be removed or altered from any source
   distribution.
--]]

-- Based on recursive shadowcasting by Björn Bergström

local octants = {
	function(x,y) return x,y end,
	function(x,y) return y,x end,
	function(x,y) return -y,x end,
	function(x,y) return -x,y end,
	function(x,y) return -x,-y end,
	function(x,y) return -y,-x end,
	function(x,y) return y,-x end,
	function(x,y) return x,-y end,
}

local tau         = 2*math.pi
local octant_angle= math.pi / 4
local epsilon     = 1e-5


local fov = function(x0,y0,radius,isTransparent,onVisible,start_angle,last_angle)
	-- **NOTE** Assumed orientation in notes is x+ right, y+ up
	
	--[[
	Octant designation
	   \  |  /
	   4\3|2/1
	 ____\|/____
	     /|\
	   5/6|7\8
	   /  |  \
	   
	   All calculations are done on the first octant
	   To calculate FOV on other octants, reflect the cells onto the first octant
	   
	   The bottom left corner is the coordinates of a cell:
	   
	   (0,1)------(1,1)
	        |Cell|
	        |0,0 |
	   (0,0)------(1,0)
	   
	   **ARC NOTE**
	   
	   The arc angle of vision defaults to 360 degrees.
	   Arc angle is measured counterclockwise from starting to last.
	   The shortest arc is used so if start = 0 and last = 370 deg then arc angle = 10 deg.
	   To get full field of view, add 2*math.pi to starting angle. This is 
	   the only way to get a full view. Any other case will result in the 
	   smallest arc possible.
	   
	   For example:
	   start = 0 ; last = 0         --> line field of view
	   start = 0 ; last = 2*math.pi --> full field of view
	]]
	
	start_angle    = start_angle or 0
	last_angle     = last_angle or tau
	local arc_angle= (last_angle-start_angle)
	-- Clamp angles or else some checks won't work correctly
	if arc_angle - tau > epsilon or arc_angle < 0 then arc_angle = arc_angle % tau end
	start_angle = start_angle % tau
	last_angle  = last_angle % tau
	
	-- Angle interval of first octant [inclusive,exclusive)
	-- Touching the end of the interval moves onto the next octant
	-- Example: [0,pi/4)
	local first_octant = (math.floor(start_angle / octant_angle) % 8) + 1
	-- Angle interval of last octant (exclusive,inclusive]
	-- Touching the beginning of the interval moves to the prev octant
	-- Example: (0,pi/4]
	local last_octant  = ((math.ceil(last_angle / octant_angle) - 1) % 8) + 1
	
	-- Hack to make large angles work when start/last are in the same octant
	if last_octant == first_octant and arc_angle > octant_angle then 
		first_octant = (first_octant % 8) + 1
	end
	
	local octant = first_octant - 1
	
	-- Always see the origin
	onVisible(x0,y0)
	
	repeat
		octant       = (octant % 8) + 1
		local coords = octants[octant]
		local views  = {}
		-- A view is represented by two lines (steep & shallow)
		views[1]    = {
			-- {x,y,x2,y2}
			steep    = {0.5,0.5,0,radius},
			shallow  = {0.5,0.5,radius,0},
		}
		for x = 1,radius do
			if not views[1] then break end
			-- Process all remaining views
			-- Iterate backward to be able to delete views
			for i = #views,1,-1 do
				local prev_cell_solid= false
				local view           = views[i]
				local steep,shallow  = view.steep,view.shallow
				
				-- Calculate the maxmimum and minimum height of the column to scan
				-- y = slope * dx + y0
				local yi,yf
				
				-- Don't calculate if the view lines didn't change
				if steep[3] > steep[1] then
					local steep_slope  = (steep[4]-steep[2]) / (steep[3]-steep[1])
					yi = math.floor( steep[2] + steep_slope*(x-steep[1]) )
				else
					yi = x
				end
				
				if shallow[4] > shallow[2] then
					local shallow_slope = (shallow[4]-shallow[2]) / (shallow[3]-shallow[1])
					yf = math.floor( shallow[2] + shallow_slope*(x-shallow[1]) )
				else
					yf = 0
				end
				
				for y = yi,yf,-1 do
					local tx,ty = coords(x,y)
					
					-- The tile is visible if it is within the cone field of view
					if arc_angle >= tau or arc_angle >= (math.atan2(ty,tx)-start_angle) % tau then
						onVisible( x0+tx,y0+ty )
					end
					-- Found a blocking cell
					if not isTransparent( x0+tx,y0+ty ) then
						-- If the previous cell is non blocking 
						-- and it is not the first cell then
						-- add another view for the remaining columns
						if not prev_cell_solid and y < yi then
							local new_view = {
								-- Inherit the current view steep line
								steep       = {steep[1],steep[2],steep[3],steep[4]},
								-- Shallow line bumps into top left corner of block
								shallow     = {shallow[1],shallow[2],x,y+1},
							}
							
							table.insert(views,new_view)
						end
						
						prev_cell_solid = true
					elseif prev_cell_solid then
						-- Cell is transparent and moving from blocking to non-blocking
						-- Readjust steep line to steep bump
						steep[3],steep[4]= x+1,y+1
						prev_cell_solid  = false
					end
				end
				
				-- Remove the view if the last cell is blocking
				if prev_cell_solid then
					table.remove(views,i)
				end
			end
		end
	until octant == last_octant
end

return fov