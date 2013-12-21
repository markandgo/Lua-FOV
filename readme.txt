Permissive field of view in Lua

This module borrows from recursive shadowcasting and precise permissive 
FOV. The demo requires LOVE.

The FOV is a square for ease of computation. This is acceptable when 
using Chebyshev distance. Permissiveness is from 0 to 10, with 10 being 
the most permissive field of view. The fov function accepts two callbacks. 
The first callback is to check if a cell blocks light. The second callback 
gets called when a cell is visible. A light origin and radius is also 
required for input.

At permissiveness level 5 (default), the light source acts as a point at 
the center of the square, and at permissiveness level 10, the entire 
square is the light source.

The user can specify the starting angle and last angle as optional 
arguments to set the size of the viewing cone. The default field of view 
is 360 degrees. One may get unexpected results with large or "odd" 
angles. This is due to rounding errors with floats so it's best to clamp
angles to 0-360 degrees.

More information can be found by searching:
FOV using recursive shadowcasting - Björn Bergström
Precise permissive field of view - Jonathon Duerig