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

Based on precise permissive FOV by Jonathon Duerig
]]

--[[
Orientation and quadrant number:

    +y
    2|1
-x--------+x
    3|4
    -y
]]

-- Obtain coordinates of other quadrants via transformation
local transform = {
	function(x,y) return x,y end,
	function(x,y) return -x,y end,
	function(x,y) return -x,-y end,
	function(x,y) return x,-y end,
}

local cross = function(a1,a2, b1,b2)
	return a1*b2 - a2*b1
end

local lineHeight = function(line,px,py)
	local dx2,dy2 = line[3] - px, line[4] - py
	local dx,dy   = line[3] - line[1], line[4] - line[2]
	return cross(dx,dy,dx2,dy2)
end

local lineAbovePoint = function(line,px,py)
	return lineHeight(line,px,py) > 0
end

local lineBelowPoint = function(line,px,py)
	return lineHeight(line,px,py) < 0
end

local pointCollinear = function(line,px,py)
	return lineHeight(line,px,py) == 0
end

local lineCollinear = function(line,line2)
	return cross(line[3]-line[1],line[4]-line[2],
	line2[3]-line2[1],line2[4]-line2[2]) == 0
end


local lineBelowOrCollinear = function(line,px,py)
	return lineHeight(line,px,py) <= 0
end

local lineAboveOrCollinear = function(line,px,py)
	return lineHeight(line,px,py) >= 0
end

local addSteepBump = function(view,x,y)
	local steep       = view.steep
	steep[3],steep[4] = x,y
	view.steep_bump   = {x,y,parent = view.steep_bump}
	-- Make sure that the steep line does not cross a previous shallow 
	-- bump
	local shallow_bump = view.shallow_bump
	while shallow_bump do
		-- The steep line of the view is below the shallow bump
		-- Reposition the origin of the steep line
		if lineBelowPoint(steep,shallow_bump[1],shallow_bump[2]) then
			steep[1],steep[2] = shallow_bump[1],shallow_bump[2]
		end
		shallow_bump = shallow_bump.parent
	end
end

local addShallowBump = function(view,x,y)
	local shallow        = view.shallow
	shallow[3],shallow[4]= x,y
	view.shallow_bump    = {x,y,parent = view.shallow_bump}
	-- Make sure that the shallow line does not cross a previous steep
	-- bump
	local steep_bump = view.steep_bump
	while steep_bump do
		if lineAbovePoint(shallow,steep_bump[1],steep_bump[2]) then
			shallow[1],shallow[2] = steep_bump[1],steep_bump[2]
		end
		steep_bump = steep_bump.parent
	end
end

-- Corners (0,1)/(1,0) cannot have the same line
local cornerCheck = function(view,view_index,views)
	if lineCollinear(view.steep,view.shallow) 
	and (pointCollinear(view.steep,0,1) or pointCollinear(view.steep,1,0))
   then
      table.remove(views,view_index)
   end
end

local tau           = 2*math.pi
local quadrant_angle= math.pi / 2
local epsilon       = 1e-5
local big_number    = 2^31

local fov = function(x0,y0,radius,isTransparent,onVisible,start_angle,last_angle,permissiveness)
	
	permissiveness = permissiveness or 10
	if permissiveness > 10 or permissiveness < 0 then
		error 'Permissiveness must be between 0 and 10'
	end
	permissiveness = permissiveness/10
	
	start_angle    = start_angle or 0
	last_angle     = last_angle or tau
	local arc_angle= (last_angle-start_angle)
	-- Clamp angles or else some checks won't work correctly
	if arc_angle - tau > epsilon or arc_angle < 0 then arc_angle = arc_angle % tau end
	start_angle = start_angle % tau
	last_angle  = last_angle % tau
	
	-- Touching the end of the interval moves onto the next quadrant
	local first_quadrant = (math.floor(start_angle / quadrant_angle) % 4) + 1
	-- Touching the beginning of the interval moves to the prev quadrant
	local last_quadrant = ((math.ceil(last_angle / quadrant_angle) - 1) % 4) + 1
	
	-- Hack to make large angles work when start/last are in the same quadrant
	if last_quadrant == first_quadrant and arc_angle > quadrant_angle then 
		first_quadrant = (first_quadrant % 4) + 1
	end
	
	local quadrant = first_quadrant - 1
	
	-- Always see the origin cell
	onVisible(x0,y0)
	
--[[	
Iterate in this order:
.
.
?
9 ?
5 8 ?
2 4 7 ?
@ 1 3 6 ?
 --]]
	
	repeat
		quadrant     = (quadrant % 4) + 1
		local coords = transform[quadrant]
		local views  = {}
		-- A view is represented by two lines (steep & shallow)
		-- The views are sorted from shallow to steepest
		views[1]    = {
			-- {x,y,x2,y2}
			steep    = {1*permissiveness,1-permissiveness,0,big_number},
			shallow  = {1-permissiveness,1*permissiveness,big_number,0},
		}
	
		-- i = x + y
		-- j = index along the diagonal (starts at 0)
		for i = 1,radius*2 do
			if not views[1] then break end
		
			local min_j = 0
			local max_j = i
			if i > radius then
				min_j = i - radius
				max_j = i - min_j
			end
			
			for j = min_j,max_j do
				if not views[1] then break end
				
				local y = j
				local x = i - j
			
				local view_index = 1
				local view = views[view_index]
				
				-- top left corner
				local tx,ty = x,y+1
				-- bottom right corner
				local bx,by = x+1,y
				
				while view and lineBelowOrCollinear(view.steep,bx,by) do
				-- The cell is above the view
				-- Try the steeper view
					view_index = view_index + 1
					view = views[view_index]
				end
				
				-- Cell is in view if the top left is also not below shallow 
				-- line
				if view 
					and not lineAboveOrCollinear(view.shallow,tx,ty) 
					then
					
					local real_x,real_y = coords(x,y)
					
					-- Visit the cell
					if arc_angle >= tau or arc_angle >= (math.atan2(real_y,real_x)-start_angle) % tau then
						onVisible(real_x+x0,real_y+y0)
					end
					
					-- Do additional checks if the cell is blocking
					if not isTransparent(real_x+x0,real_y+y0) then
						
						local intersectSteep,intersectShallow =
							lineBelowPoint(view.steep,tx,ty),
							lineAbovePoint(view.shallow,bx,by); 
						
						-- Both lines intersect the cell, destroy the view
						if intersectSteep and intersectShallow then
							
							table.remove(views,view_index)
							
						-- The cell intersects the steep line
						-- Lower the steep line
						elseif intersectSteep then
							
							addSteepBump(view,bx,by)
							cornerCheck(view,view_index,views)
						
						-- The cell intersects the shallow line
						-- Raise the shallow line
						elseif intersectShallow then
							
							addShallowBump(view,tx,ty)
							cornerCheck(view,view_index,views)
							
						-- The cell is completely between the view
						-- Split the view
						else
							
							-- Copy the view
							-- This is the top half
							local new_view = {
								steep       = {unpack(view.steep)},
								shallow     = {unpack(view.shallow)},
								steep_bump  = view.steep_bump,
								shallow_bump= view.shallow_bump,
							}
							addShallowBump(new_view,tx,ty)
							table.insert(views,view_index+1,new_view)
							cornerCheck(new_view,view_index+1,views)
							
							-- Lower the current view
							-- This is the bottom half
							addSteepBump(view,bx,by)
							cornerCheck(view,view_index,views)
						end
					end
				end
			end
		end
	until quadrant == last_quadrant
end

return fov