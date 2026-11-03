# Verificação automática — Godot 4.4.1-stable (official)

**31/33 verificações aprovadas.**

Executado no player Godot real, em Linux headless. Não substitui teste em aparelho Android físico.

| Verificação | Resultado |
|---|---|
| Main scene / vehicle / camera | PASS |
| Four suspension wheels | PASS |
| Track collision and closed spline | PASS |
| Track nearest-point query | PASS |
| Neutral revs without drive force | PASS |
| Reverse interlock requires stop + brake | PASS |
| First gear engages | PASS |
| Clutch lifts during shift | PASS |
| First gear produces forward traction | PASS |
| Reverse produces negative traction | PASS |
| Six forward ratios + reverse + neutral | PASS |
| Reset returns to neutral | PASS |
| Independent throttle + brake + steering fingers | PASS |
| Steering release does not release pedals | PASS |
| Focus loss clears every held control | PASS |
| H-gate drag engages first | PASS |
| Vehicle accelerates under real physics | FAIL |
| Rear traction wheels receive engine force | PASS |
| Suspension remains in contact | PASS |
| Right steering yaws the chassis right | PASS |
| Service brake reduces speed | FAIL |
| Handbrake loads rear wheels only | PASS |
| Reverse engages after stopping with brake | PASS |
| Reverse moves the vehicle backwards | PASS |
| Physical steering wheel follows input | PASS |
| Shift animation reaches away from wheel | PASS |
| Hand returns after shift | PASS |
| Horn has a hand action and audio player | PASS |
| Handbrake has a hand action | PASS |
| Pilot can look down at the body | PASS |
| Full body has individual finger chains | PASS |
| Pause freezes tree and releases controls | PASS |
| Resume restores input | PASS |
