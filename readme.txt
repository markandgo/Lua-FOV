Permissive field of view in Lua

This module borrows from recursive shadowcasting and precise permissive 
FOV. The demo requires LOVE.

The FOV is a square for easy of computation. This is acceptable when 
using Chebyshev distance. Permissiveness is from 0 to 10, with 10 being 
the most permissive field of view. The fov function accepts two callbacks. 
The first callback is to check if a cell blocks light. The second callback 
gets called when a cell is visible. A light origin and radius is also 
required for input.

At permissiveness level 5, the light source acts as a point at the center of
the square, and at permissiveness level 10, the entire square is the light 
source.

More information can be found by searching:
FOV using recursive shadowcasting - Björn Bergström
Precise permissive field of view - Jonathon Duerig