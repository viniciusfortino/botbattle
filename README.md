# BotBattle

Protótipo de RPG de batalha por turnos para **Android e iOS**, feito em **Godot 4.7**.

A câmera fica atrás do personagem do jogador (visão de costas): você vê o R-7 em
primeiro plano e dá as ordens; o oponente aparece à frente, na arena. Tudo é
desenhado por código — o projeto ainda não depende de nenhum asset de imagem.

A dinâmica do combate está documentada em **[feature_battle.md](feature_battle.md)**.

---

## Requisitos

| | |
| --- | --- |
| **Godot 4.7** ou superior | é a única dependência para rodar no desktop |
| JDK 17 + Android SDK | só para exportar `.apk`/`.aab` |
| macOS + Xcode | só para exportar para iOS |

Instalar o Godot no macOS:

```bash
brew install --cask godot
```

O executável fica em `/Applications/Godot.app/Contents/MacOS/Godot`. Em Linux/Windows,
troque esse caminho pelo binário do Godot nos comandos abaixo (ou use `godot` se ele
estiver no `PATH`).

---

## Como executar

Todos os comandos rodam a partir da raiz do projeto.

### Jogar

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

Abre direto a cena principal (`scenes/battle/battle.tscn`). No desktop a janela abre
em 540×960 e o jogo é controlado com o mouse — `pointing/emulate_touch_from_mouse`
está ligado, então o clique se comporta como toque.

### Abrir no editor

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . --editor
```

Na primeira vez o Godot importa os recursos e cria a pasta `.godot/` (ignorada pelo git).

### Teste de fumaça

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . -s tools/smoke_test.gd
```

Joga uma batalha inteira sozinho, imprime o log de combate no terminal e salva um PNG
de cada rodada em `.captures/`. Sai com código **0** se a batalha terminou e **1** se
travou — dá para usar em CI para pegar regressão de regra ou deadlock de turno.

### Modo de depuração

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . -- --debug-on
```

Liga a flag global `Debug` já na abertura. Com ela ativa, aparece abaixo da barra de
vida do oponente o painel com a vida de cada hitbox. **F3** alterna a qualquer momento
(no celular, toque com três dedos). O valor padrão vem de `botbattle/debug/enabled`
em `project.godot`.

### Simular balanceamento

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/simulate.gd
```

Roda 200 batalhas por estratégia só no modelo — sem cena, sem animação, em segundos — e
reporta vitórias, quantas terminam por desarme e a duração média. É a ferramenta para
mexer em números com dados em vez de intuição; a política do jogador simulado está em
`_player_move()`.

### Verificar que a cena sobe sem erro

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . --quit-after 240
```

Roda 240 frames e fecha. Qualquer erro de script aparece na saída.

---

## Resolução e orientação

O viewport lógico é **1080×1920 (retrato)**, com `stretch/mode = canvas_items` e
`aspect = expand`: a interface se adapta a telas mais largas ou mais estreitas sem
deformar. Em desktop a janela é reduzida para 540×960 pelo
`window_width_override`/`window_height_override` em `project.godot` — isso não afeta
o build mobile.

O renderer é `gl_compatibility` (OpenGL ES 3), que é o recomendado para alcançar
aparelhos Android mais antigos.

---

## Estrutura

| Caminho | Papel |
| --- | --- |
| `globals/debug.gd` | Autoload `Debug`: a flag global de depuração do app. |
| `combat/unit_stats.gd` | Ficha de uma unidade (vida por hitbox, energia, ataque, defesa, velocidade, cores). |
| `combat/body_part.gd` | Uma hitbox: cabeça, tórax, braço ou perna. |
| `combat/body.gd` | O corpo inteiro: sorteio de acerto, transbordo de dano e reparo. |
| `combat/actions.gd` | Catálogo de ações, o braço que empunha cada arma e a curva de eficiência. |
| `combat/actions.gd` | Catálogo de ações — a fonte da verdade sobre custos e fórmulas. |
| `combat/combatant.gd` | Estado de combate de um lutador + animações do corpo. |
| `combat/battle_manager.gd` | Regras da batalha. Não conhece a UI: só emite sinais. |
| `actors/robot_sprite.gd` | Corpo do robô desenhado com `_draw()` (de frente ou de costas). |
| `scenes/battle/battle.tscn` | Cena principal: arena, lutadores e HUD. |
| `scenes/battle/battle.gd` | Camada visual: liga o manager à cena, à UI e às animações. |
| `scenes/battle/arena_background.gd` | Céu, piso em perspectiva e plataformas. |
| `ui/battle_theme.tres` | Tema da interface (botões grandes, pensados para toque). |
| `ui/damage_number.gd` | Números flutuantes de dano e cura. |
| `ui/hitbox_debug_panel.gd` | Painel de hitboxes do oponente (só com o debug ligado). |
| `ui/target_picker.gd` | Seletor de alvo do segundo toque. |
| `units/*.tres` | Fichas prontas. Duplique um arquivo para criar uma unidade nova. |
| `tools/smoke_test.gd` | Teste de fumaça descrito acima. |
| `tools/simulate.gd` | Simulador de balanceamento (200 batalhas por estratégia). |

---

## Exportar para mobile

O `export_presets.cfg` é gerado pelo editor e costuma guardar caminho de keystore,
por isso está no `.gitignore` — cada máquina cria o seu.

### Android

1. Instale o JDK 17 e o Android SDK (o caminho mais simples é via Android Studio).
2. No Godot: *Editor → Editor Settings → Export → Android* e aponte o caminho do SDK.
3. Gere a chave de debug:
   ```bash
   keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android \
     -keystore debug.keystore -storepass android \
     -dname "CN=Android Debug,O=Android,C=US" -validity 9999 -deststoretype pkcs12
   ```
4. *Project → Export → Add… → Android*. Marque *Use Gradle Build* se for usar plugins.
5. Para a Play Store, use uma keystore de release e exporte como `.aab`.

### iOS

1. Precisa de macOS com Xcode e uma conta de Apple Developer.
2. *Project → Export → Add… → iOS*, preencha Bundle Identifier e Team ID.
3. O Godot gera um projeto Xcode; abra, assine e rode no dispositivo.

---

## Próximos passos

- Vários inimigos por batalha e escolha de alvo por toque (o manager já trabalha com listas).
- Efeitos de status (queimadura, lentidão) e itens consumíveis.
- Tela de título, progressão entre batalhas e persistência em `user://`.
- Áudio (`.ogg`) e vibração no impacto.
- Trocar os robôs desenhados por sprites: basta substituir o `RobotSprite` por um
  `AnimatedSprite2D` dentro de cada `Combatant`.
