rot = require 'rotLove/rotLove/rotLove'
fov_list = {
	{require 'ppfov','precise permissive'},
	{require 'rsfov','recursive shadowcast'},
}

fov_index = 1
fov = fov_list[fov_index][1]

tw,th      = 8,8
px,py      = 1,1
radius     = 20
radius_type= 'square'
perm       = 5
angle      = 0
angle_size = 360
delta      = 5
show_help  = true
width      = 98
height     = 60

run_symmetry_test = false
fail_visible      = {}

function generateMap()
	bmap    = rot.Map.Cellular(width,height)
	bmap:randomize(0.35)
	map     = {}
	
	bmap:create(function(x,y,type)
		map[x]    = map[x] or {}
		map[x][y] = type
	end,false)
	
	repeat
		px,py = math.random(1,width),math.random(1,height)
	until map[px][py] == 0
end

function generateVisible()
	visible = {}
	
	local isTransparent = function(x,y)
		return map[x] and map[x][y] == 0
	end
	
	local onVisible = function(x,y)
		local dx,dy = x-px,y-py
		if (dx*dx + dy*dy) > radius*radius + radius and radius_type == 'circle' then 
			return 
		end
		
		visible[x]    = visible[x] or {}
		visible[x][y] = 1
	end
		
	fov(px,py,radius,isTransparent,onVisible,math.rad(angle-angle_size/2),math.rad(angle+angle_size/2),perm)
	
	if run_symmetry_test then
		local ex,ey        = 0,0
		fail_visible       = {}
		
		local onEnemyVision = function(x,y)
			local dx,dy = x-ex,y-ey
			if (dx*dx + dy*dy) > radius*radius + radius and radius_type == 'circle' then 
				return 
			end
			
			enemyVision[x]    = enemyVision[x] or {}
			enemyVision[x][y] = 1
		end
		
		for x,t in pairs(visible) do
			for y,vis in pairs(t) do
				enemyVision = {}
				ex,ey       = x,y
				fov(x,y,radius,isTransparent,onEnemyVision,nil,nil,perm)
				if not (enemyVision[px] and enemyVision[px][py]) then
					fail_visible[x]    = fail_visible[x] or {}
					fail_visible[x][y] = 1
				end
			end
		end
	end
end

function love.load()
	math.randomseed(os.time())
	generateMap()
	generateVisible()
	
	if love.keyboard.setKeyRepeat then 
		love.keyboard.setKeyRepeat(0.3,0.1)
	end
end

function love.keypressed(k)
	local dx,dy = 0,0
	if k == 'f1' then
		show_help = not show_help
	end
	if k == 'f2' then
		run_symmetry_test = not run_symmetry_test
	end
	if k == 'f3' then
		fov_index = fov_index + 1
		if fov_index > #fov_list then fov_index = 1 end
		fov = fov_list[fov_index][1]
	end
	if k == 'tab' then
		radius_type = radius_type == 'circle' and 'square' or 'circle'
	end
	if k == '1' then
		radius = math.max(0,radius-1)
	end
	if k == '2' then
		radius = radius+1
	end
	if k == 'a' then
		angle = angle - delta
	end
	if k == 'd' then
		angle = angle + delta
	end
	if k == 's' then
		angle_size = angle_size - delta
	end
	if k == 'w' then
		angle_size = angle_size + delta
	end
	if k == 'kp4' or k == 'left' then
		dx = -1
	end
	if k == 'kp6' or k == 'right' then
		dx = 1
	end
	if k == 'kp8' or k == 'up' then
		dy = -1
	end
	if k == 'kp2' or k == 'down' then
		dy = 1
	end
	if k == 'kp1' then
		dx,dy = -1,1
	end
	if k == 'kp3' then
		dx,dy = 1,1
	end
	if k == 'kp7' then
		dx,dy = -1,-1
	end
	if k == 'kp9' then
		dx,dy = 1,-1
	end
	if k == 'insert' then
		map[px][py] = 1
	end
	if k == '+' or k == 'kp+' then
		perm = perm + 1
		perm = math.min(math.max(0,perm),10)
	end
	if k == '-' or k == 'kp-' then
		perm = perm - 1
		perm = math.min(math.max(0,perm),10)
	end
	if k == 'delete' then
		map[px-1][py] = 0
		map[px+1][py] = 0
		map[px][py-1] = 0
		map[px][py+1] = 0
	end
	if k == ' ' then generateMap() end
	
	if map[px+dx] and map[px+dx][py+dy] then
		px,py = px+dx,py+dy
	end
	
	angle = angle % 360
	angle_size = math.max(math.min(angle_size,360),0)
	
	generateVisible()
end

function love.draw()
	for x = 1,width do
		local col = map[x]
		for y = 1,height do
			-- draw map
			if map[x] and map[x][y] == 1 then
				love.graphics.setColor(0,0,0)
			else
				love.graphics.setColor(64,64,64)
			end
			love.graphics.rectangle('fill',x*tw,y*th,tw,th)
			
			-- vision color overlay
			if visible[x] and visible[x][y] == 1 then
				local dx,dy = x-px,y-py
				if map[x][y] == 1 then
					love.graphics.setColor(255,255,0,255) 
				else
					love.graphics.setColor(255,255,0,64) 
				end
				-- non-symmetric cell color overlay
				if run_symmetry_test and fail_visible[x] and fail_visible[x][y] then
					love.graphics.setColor(255,0,0)
				end
			end
			love.graphics.rectangle('fill',x*tw,y*th,tw,th)
		end
	end
	
	-- draw player
	love.graphics.setColor(0,255,0)
	love.graphics.rectangle('fill',px*tw,py*th,tw,th)
	
	if show_help then
		local t = {
			'Press f1 to toggle help',
			'Press f2 to enable symmetry test: '..tostring(run_symmetry_test),
			'Press f3 to switch algorithm: '..fov_list[fov_index][2],
			'Permissive level: '..perm,
			'Press +/- to change permissiveness',
			'Press space to randomize',
			'Press insert/delete to insert/dig blocks',
			'Press arrow keys or numpad to move',
			'Press 1/2 to decrease/increase FOV radius: '..radius,
			'Press tab to toggle FOV type: '..radius_type,
			'Press a/d to change viewing angle: '..angle,
			'Press s/w to change cone size: '..angle_size,
		}
		
		love.graphics.setColor(255,255,255)
		love.graphics.print(table.concat(t,'\n'),0,0)
	end
end