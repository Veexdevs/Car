# Procedural animation

The pilot uses `MotionSpring.gd` (analytic critically damped springs) and `RobotDriver.gd`
(two-bone IK, independent finger chains, reach/return state blending). Motion is driven by
measured vehicle acceleration, steering, RPM, impacts and actual control state—not by a
decorative loop. The physical lever and handbrake follow the same state in `Cockpit.gd`.
