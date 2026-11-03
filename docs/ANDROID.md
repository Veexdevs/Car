# Exportar para Android — Godot 4

1. Instale **Godot 4.4.1+** (Standard, não .NET) e abra `project.godot`.
2. Em **Editor → Manage Export Templates**, instale os templates da mesma versão.
3. Em **Editor → Editor Settings → Export → Android**, configure Android SDK/Java conforme a documentação oficial do Godot. Para exportação simples, use o APK padrão; para Play Store, configure AAB e assinatura própria.
4. O preset `Android` já está em `export_presets.cfg`: arm64-v8a, landscape, immersive, sem internet.
5. **Project → Export → Android → Export Project**. Para teste local, exporte APK debug; para distribuição, release assinado.
6. Instale no aparelho e teste: primeira marcha, acelerador, direção, frenagem, ré, freio de mão, buzina, troca com a mão direita, olhar para baixo e pausa ao perder foco.

## Desempenho

- Renderer padrão: `mobile`. Em GPUs antigas, use `gl_compatibility` no export ou no projeto.
- Qualidade **Baixa** reduz escala 3D, desliga sombras e limita espelhos; **Média** é o padrão; **Alta** aumenta sombras/espelhos.
- Física fixa em 60 Hz. Quatro rodas raycast, cenário batching com MultiMesh, LODs de importação e espelhos em baixa resolução.
- O alvo é 30–60 FPS conforme o aparelho. Meça no dispositivo real; não há benchmark Android físico neste ambiente.
- Texturas PNG são fontes editáveis; o Godot as comprime na importação/exportação (ETC2/ASTC habilitado).

## Limitações conhecidas

- Sem APK assinado pronto: o entregável principal é o projeto Godot completo em ZIP.
- Sem teste em dispositivo físico neste ambiente.
- Retrovisores são render textures escalonadas, não ray tracing.
- O modelo é artistico, não CAD oficial; a gaiola/câmbio H são uma conversão de pista experimental.
