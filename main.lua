rot = require 'rotLove/rotLove/rotLove'
fov = require 'pfov'

tw,th = 16,16
px,py = 1,1
radius= 20
perm  = 0

function generateMap()
	bmap    = rot.Map.Brogue(49,30)
	map     = {}
	
	bmap:create(function(x,y,type)
		map[x]    = map[x] or {}
		map[x][y] = type
		rand = math.random(1,2)
		if rand == 1 and type == 0 then
			px,py = x,y
		end
	end,false)
	
	generateVisible()
end

function generateVisible()
	visible = {}
	
	local isTransparent = function(x,y)
		return map[x] and map[x][y] == 0
	end
	
	local onVisible = function(x,y)
		visible[x]    = visible[x] or {}
		visible[x][y] = 1
	end
	
	fov(px,py,radius,isTransparent,onVisible,perm)
end

function love.load()
	generateMap()
	
	if love.keyboard.setKeyRepeat then 
		love.keyboard.setKeyRepeat(0.3,0.1)
	end
end

function love.keypressed(k)
	local dx,dy = 0,0
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
	if map[px+dx][py+dy] == 0 then
		px,py = px+dx,py+dy
	end
	
	generateVisible()
end

function love.draw()
	for x = 1,#map do
		local col = map[x]
		for y = 1,#col do
			if visible[x] and visible[x][y] == 1 then
				love.graphics.setColor(0,255,0)
			else
				love.graphics.setColor(64,64,64)
			end
			if x == px and y == py then
				love.graphics.setColor(255,255,255)
				love.graphics.print('@',x*tw,y*th)
			elseif col[y] == 0 then
				love.graphics.print('.',x*tw,y*th)
			else
				love.graphics.print('#',x*tw,y*th)
			end
		end
	end
	
	local t = {
		'Permissive level: '..perm,
		'Press +/- to change permissiveness',
		'Press space to randomize',
		'Press insert/delete to insert/dig blocks',
		'Press arrow keys or numpad to move',
	}
	
	love.graphics.setColor(255,255,255)
	love.graphics.print(table.concat(t,'\n'),0,0)
end