--[[
The MIT License (MIT)

Copyright (c) 2013 Minh Ngo

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

]]

-- Based on recursive shadowcasting by Björn Bergström
-- and precise permissive FOV by Jonathon Duerig

-- Obtain coordinates of other octants via transformation
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

local cross = function(a1,a2, b1,b2)
	return a1*b2 - a2*b1
end

local printf= function(...) print(string.format(...)) end


local fov = function(x0,y0,radius,isTransparent,onVisible,permissiveness)
	-- print '=== Begin fov calculation ==='

	-- **NOTE** Assumed orientation in notes is x+ right, y+ up
	
	--[[
	Quadrant designation
	   \  |  /
	   4\3|2/1
	 ____\|/____
	     /|\
	   5/6|7\8
	   /  |  \
	   
	   All calculations is done on the first quadrant
	   To calculate FOV on other quadrants, reflect the cells onto the first quadrant
	   
	   The bottom left corner is the coordinates of a cell:
	   
	   (0,1)------(1,1)
	        |Cell|
	        |0,0 |
	   (0,0)------(1,0)
	   
	   Permissiveness is from 0 to 10 with 0 being the least permissive
	]]
	permissiveness = permissiveness/10 or 0.5
	if permissiveness > 10 or permissiveness < 0 then
		error 'Permissiveness must be between 0 and 10'
	end

	-- Calculate the FOV by dividing it into octants
	for octant = 1,8 do
		-- printf('Octant %d',octant)
		
		local coords = octants[octant]
		local views  = {}
		-- A view is represented by two lines (steep & shallow)
		-- The bottom left of cell (0,0) is point (0,0)
		views[1]    = {
			-- {x,y,x2,y2}
			steep    = {1*permissiveness,1-permissiveness,0,radius},
			shallow  = {1-permissiveness,1*permissiveness,radius,0},
		}
		-- Scan column by column
		-- Note that the FOV is square
		for x = 1,radius do
			-- printf('Processing column %d',x)
			-- Process all remaining views
			-- Iterate backward to be able to delete views
			for i = #views,1,-1 do
				local prev_cell_solid = false
				local view = views[i]
				local steep,shallow = view.steep,view.shallow
				
				-- print 'Processing view...'
				-- printf('View steep: (%d,%d) to (%d,%d)',unpack(view.steep))
				-- printf('View shallow: (%d,%d) to (%d,%d)',unpack(view.shallow))
				
				-- Calculate the maxmimum and minimum height of the column to scan
				-- y = slope * dx + y0
				local yi,yf
				-- Only calculate yi if the steep slope has changed because
				-- it is initially "vertical"
				if steep[3] > steep[1] then
					local steep_slope  = (steep[4]-steep[2]) / (steep[3]-steep[1])
					yi = math.floor( steep[2] + steep_slope*(x-steep[1]) )
				else
					yi = x
				end
				
				local shallow_slope = (shallow[4]-shallow[2]) / (shallow[3]-shallow[1])
				yf = math.floor( shallow[2] + shallow_slope*(x-shallow[1]) )
				-- Process column from top to bottom
				-- printf('Column range is %d to %d',yi,yf)
				for y = yi,yf,-1 do
					-- printf('Processing row %d',y)
					
					local tx,ty = coords(x,y)
					onVisible( x0+tx,y0+ty )
					
					-- printf('Checking cell (%d,%d)',x0+tx,y0+ty)
					
					-- Found a blocking cell
					if not isTransparent( x0+tx,y0+ty ) then
						-- print 'Cell is blocking'
						-- If the previous cell is non blocking 
						-- and it is not the first cell then
						-- add a another view for the next column
						if not prev_cell_solid and y < yi then
							-- print 'Creating a new view...'
							local bx,by = x,y+1
							local new_view = {
								-- Inherit the current view steep line
								steep       = {steep[1],steep[2],steep[3],steep[4]},
								steepBump   = view.steepBump,
								-- Shallow line bumps into top left corner of block
								-- Shallow line also starts at top left corner of origin cell
								shallow     = {1-permissiveness,1*permissiveness,bx,by},
								shallowBump = {bx,by,parent = view.shallowBump},
							}
							
							table.insert(views,new_view)
							-- printf('New view steep: (%d,%d) to (%d,%d)',unpack(new_view.steep))
							-- printf('New view shallow: (%d,%d) to (%d,%d)',unpack(new_view.shallow))
							
							local shallow   = new_view.shallow
							local steepBump = new_view.steepBump
							-- Make sure that the shallow line does not cross a previous steep bump
							-- If it does, raise the slope of the shallow line to restrict the viewing cone
							---[[
							while steepBump do
								-- printf('Checking steep bump (%d,%d) against shallow line...',steepBump[1],steepBump[2])
								-- Vector fromp steep bump to shallow end
								local dx2,dy2 = shallow[3] - steepBump[1], shallow[4] - steepBump[2]
								local dx,dy   = shallow[3] - shallow[1], shallow[4] - shallow[2]
								-- The shallow line of the view is above the steep bump...
								if cross(dx,dy,dx2,dy2) > 0 then
									-- print 'Shallow line is above the steep bump, readjusting...'
									-- Reposition the origin of the shallow line
									shallow[1],shallow[2] = steepBump[1],steepBump[2]
								end
								steepBump = steepBump.parent
							end
							--]]
						end
						
						prev_cell_solid = true
					elseif prev_cell_solid then
						-- print 'Moving from blocking to non-blocking...'
						-- Cell is transparent
						-- If moving from blocking to non-blocking...
						-- Then readjust steep line to steep bump
						steep[3],steep[4]= x+1,y+1
						prev_cell_solid  = false
						local bump       = {steep[3],steep[4],parent = view.steepBump}
						view.steepBump   = bump
						-- printf('Adding steep bump (%d,%d)',steep[3],steep[4])
						
						-- Make sure that the steep line does not cross a previous shallow bump
						---[[
						local shallowBump = view.shallowBump
						while shallowBump do
							-- printf('Checking shallow bump (%d,%d) against steep line...',shallowBump[1],shallowBump[2])
							-- Vector fromp shallow bump to steep end
							local dx2,dy2 = steep[3] - shallowBump[1], steep[4] - shallowBump[2]
							local dx,dy   = steep[3] - steep[1], steep[4] - steep[2]
							-- The steep line of the view is below the shallow bump...
							if cross(dx,dy,dx2,dy2) < 0 then
								-- print 'Steep line is below the shallow bump, readjusting...'
								-- Reposition the origin of the steep line
								steep[1],steep[2] = shallowBump[1],shallowBump[2]
							end
							shallowBump = shallowBump.parent
						end
						--]]
					end
				end
				
				-- Remove the view if the last cell is blocking
				if prev_cell_solid then
					table.remove(views,i)
				end
			end
		end
	end
end

return fov