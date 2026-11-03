# Arquitetura

- `Game.gd`: composição, ambiente, pausa, configurações e qualidade.
- `DrivingInput`: estado único de acelerador, freio, direção, olhar, buzina e marcha.
- `InputRouter`: propriedade por pointer ID, multitoque, emulação mouse→toque, portão H e raycast no volante 3D.
- `Powertrain`: modelo determinístico de motor, embreagem, relações, RPM, limiter e intertravamentos.
- `VehicleController`: VehicleBody3D, suspensão, forças de pneu, freios por roda, arrasto, downforce, impacto e fumaça.
- `Cockpit`: volante físico, alavanca H, freio de mão, buzina, painel, LEDs e gaiola.
- `RobotDriver`: corpo completo, IK de dois ossos, dedos, alcance/retorno de mãos, molas de tronco/cabeça e câmera.
- `MirrorSystem`: três SubViewports pequenos, atualização escalonada.
- `VehicleAudio`: camadas de motor, pneus, vento e one-shots espaciais.
- `SerraTrack`: spline fechada, malhas de pista/zebras/Armco, colisão, cenário e consulta de progresso.
- `RaceDirector`: progresso assinado, volta válida, recorde local e invalidação por reposicionamento/fora da pista.
- `RaceHUD`: desenho immediate-mode, painéis de toque e menu de pausa.

## Unidades

Metros, segundos, newtons, kg. Frente do veículo: `-Z`. Rodas dianteiras em `z=-1.155`, traseiras em `z=1.495`. Massa: 1350 kg. Raio: 0.34 m. RPM idle: 950; limiter: 9000.

## Persistência

`user://serra_rs_records.cfg` e `user://serra_rs_settings.cfg`. Nenhum dado sai do dispositivo.
