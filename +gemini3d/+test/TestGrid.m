classdef TestGrid < matlab.unittest.TestCase
methods (Test)


function test_grid(tc)

parm = struct("lq", 4, "lp", 6, "lphi", 1, ...
  "dtheta", 7.5, "dphi", 12, "altmin", 80e3, ...
  "gridflag", 1, "glon", 143.4, "glat", 42.45);

xg = gemini3d.grid.tilted_dipole(parm);

tc.verifySize(xg.e1, [parm.lq, parm.lp, parm.lphi, 3])
tc.verifyEqual(xg.e1(1,1,1,1), -0.847576545732110, RelTol=1e-6)

end

end

end
