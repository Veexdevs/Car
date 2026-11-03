# Car

## SERRA RS — Cockpit

Simulador experimental de condução automotiva em **primeira pessoa**, feito exclusivamente em **Godot 4 / GDScript**, com alvo em **Android na horizontal**. Não é uma página web e não usa Unity, Unreal, plugins pagos ou serviços online.

### Download

**[Baixar o projeto completo em ZIP](Releases/SERRA-RS-Godot4.zip)**

O ZIP também está versionado neste repositório. Abra `project.godot` no **Godot 4.4.1 ou superior** e pressione **F5**.

### O que está implementado

- Cockpit permanente dentro de um esportivo detalhado, com volante físico, painel digital, LEDs de RPM, banco, portas, gaiola, cintos, câmbio, freio de mão e retrovisores com renderização real em baixa resolução.
- Piloto robótico sentado, com tronco, pernas, braços articulados por IK, mãos e cadeias de dedos individuais. O corpo reage a aceleração, frenagem, curvas e impactos.
- Mãos acompanham o volante; a mão direita alcança o câmbio, a buzina ou o freio de mão e retorna.
- Câmbio manual em H: **1–6, N e R**, com embreagem automática curta, corte de torque na troca, RPM acoplado à velocidade e intertravamento de ré.
- Física `VehicleBody3D`: quatro rodas com suspensão, tração traseira, aderência, freios, arrasto, downforce, inércia, derrapagem e freio de mão traseiro.
- Circuito fechado original com zebras, linhas, grid, brita/asfalto de escape, Armco, boxes, arquibancada, vegetação e voltas cronometradas com recorde local.
- Áudio espacial de motor por RPM/carga, pneus, vento, buzina, troca, freio de mão e impactos.
- HUD multitoque com velocímetro, RPM, marcha, volante, pedais, câmbio H, ré, freio de mão, buzina, minimapa, pausa e configurações.

### Controles Android

| Controle | Ação |
|---|---|
| Área **DIREÇÃO** ou o próprio volante 3D | Toque e arraste horizontalmente; solte para centralizar |
| **ACELERAR** | Segure para acelerar progressivamente |
| **FREIO** | Segure para frenagem progressiva |
| **CÂMBIO H** | Arraste entre as posições; o corredor central é N |
| **R / ENGATAR RÉ** | Pare e segure o freio; depois selecione R e use ACELERAR |
| **P / FREIO MÃO** | Segure para travar as rodas traseiras |
| **SOM / BUZINA** | Segure para buzinar; solte para parar |
| Área livre do para-brisa | Arraste para olhar, inclusive para baixo para ver o corpo |
| Botão circular no topo | Centralizar o olhar |
| Botão de pausa | Continuar, reposicionar, reiniciar, qualidade, movimento e volume |

No desktop: `W/S` ou setas aceleram/freiam, `A/D` direcionam, `1–6` trocam marcha, `N` neutro, `R` ré, `Espaço` freio de mão, `H` buzina, `C` centraliza o olhar e `Esc` pausa. O mouse simula toque.

### Android

O renderer padrão é **Mobile**, com fallback **Compatibility** configurável. Há três níveis de qualidade, espelhos escalonados, LODs de importação, texturas comprimíveis para Android e nenhuma permissão de internet. Consulte [docs/ANDROID.md](docs/ANDROID.md) para exportar o APK.

### Escopo e realismo

Esta é uma **base experimental funcional de condução**, não uma promessa de paridade com simuladores comerciais AAA. A física usa rodas raycast do Godot com ajustes de aderência/carga, não um modelo Pacejka completo; a embreagem é assistida; o áudio do motor usa camadas em loop por RPM, não síntese granular de cilindros; SSAO não é habilitado no renderer Mobile. O modelo do carro é um asset artistico licenciado, adaptado para o cockpit. O piloto e o circuito são geometria procedural original com materiais PBR.

### Estrutura

```text
Scenes/       Main e Vehicle
Scripts/      Core, Vehicle, Driver, Track
Assets/       Models, Textures, Materials, Audio
UI/           HUD, fonte e cena
Animations/   molas e animação procedural
Tests/        testes de gameplay e capturas
Tools/        geração opcional de texturas/áudio
docs/         Android, arquitetura, controles e verificação
Releases/     ZIP completo para download
```

### Verificação

Os testes automatizados executam no player Godot real via GitHub Actions: importação, transmissão, multitoque, aceleração, frenagem, ré, freio de mão, animações, câmera e pausa. Evidências ficam em [docs/verification/TEST_RESULTS.md](docs/verification/TEST_RESULTS.md). A validação em celular Android físico ainda deve ser feita no aparelho alvo; este ambiente não possui um dispositivo Android conectado.

### Licenças

Código e assets originais: MIT (`LICENSE`). Modelo Ferrari 458: **vicent091036, CC BY 4.0**. Áudio: **Kenney, CC0**. Fonte: **SIL OFL 1.1**. Atribuições completas em [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). Sem afiliação à Ferrari.
