# __Field of view algorithms in Lua.__

Two algorithms are available: 
* Recursive shadowcasting 
* Precise permissive 

**The demo requires LOVE.**

__Example code:__
```lua
	fov = require 'fov'
	
	-- Required callbacks:
	function isTransparent(x,y)
		-- return true if the cell is non-blocking
	end
	
	function onVisible(x,y)
		-- gets called when a square is visible
	end
	
	-- Required:
	radius        = 5   -- sight radius
	px,py         = 0,0 -- position of light origin
	
	-- Optional:
	start_angle   = 0         -- starting angle for FOV arc
	last_angle    = math.pi*2 -- last angle for FOV arc
	                          -- default: 360 degrees FOV
	                          
	permissiveness= 10 -- 0-10, 10 being perfectly symmetric FOV
	                   -- default: 10
	                   -- not available for Recursive Shadowcasting
	                   
	-- Calculate fov:
	fov(px,py,radius,isTransparent,onVisible,
	start_angle,last_angle,permissiveness)
```

More information can be found by searching:
FOV using recursive shadowcasting - Björn Bergström
Precise permissive field of view - Jonathon Duerig
