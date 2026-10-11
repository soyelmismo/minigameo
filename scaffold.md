# SCAFFOLD — ARCADE BLOCK: 5 MINUTE OVERDRIVE

> **Propósito de este archivo:** es el brief maestro del proyecto. Cualquier agente
> (humano o IA) debe leerlo completo antes de tocar código. Contiene la visión, la
> arquitectura, los contratos de implementación y las reglas duras. `AGENTS.md`
> contiene las directivas de trabajo; este archivo contiene el QUÉ y el PORQUÉ.

> **Idioma:** el JUEGO (nombres, HUD, objetivos, voz, flavor text) está en
> **inglés**. Los identificadores de código van en inglés; los docs de equipo
> (este archivo, GDD) están en español.

---

## 1. VISIÓN DEL JUEGO

**Nombre:** *ARCADE BLOCK: 5 MINUTE OVERDRIVE*

**Concepto:** un juego arcade 3D, fast-pace, sobre una única cuadra urbana
estilizada. El jugador corre libremente persiguiendo power-ups brillantes
repartidos por el mapa. Al recoger uno, se dispara una **ruleta** que elige al
azar uno de **36 micro-juegos** de 10–30 segundos. Cada micro-juego tiene un
**style pack** propio que transforma temporalmente la apariencia del mundo y
del personaje (paleta, cielo, materiales, post-proceso, música, HUD). La
partida dura **5 minutos exactos**; el objetivo es maximizar el puntaje.

**El giro de personalidad:** el barrio es un espejo satírico de la vida moderna
y de la cultura tech/IA. Los micro-juegos son ansiedades cotidianas y absurdos
de la era digital — notificaciones, commutes, deliveries, alucinaciones de
chatbots, GPUs derretidos, tech debt — presentados con humor hiperactivo y
auto-consciente tipo WarioWare / Nintendo Land. La fantasía: *"el mundo es un
videojuego caótico y yo soy el único que sabe jugarlo."*

**Pilares de diseño (no negociables):**

1. **ARCADE FEELING PURO** — respuesta inmediata, readable, ruidoso, con
   *juice* en cada acción. Referencia de sensación: Nintendo (Mario Kart, Wario
   Ware, Nintendo Land) — legibilidad sobre realismo, sorpresa sobre fidelidad.
2. **SORPRESA CONSTANTE** — nunca se sabe qué micro-juego toca; el mundo cambia
   de piel drásticamente cada 30-60s.
3. **SESIÓN DE 5 MINUTOS** — densidad de eventos altísima; cada segundo importa.
   Cero menús profundos, cero downtime muerto.
4. **HUMOR COMO MECÁNICA** — el chiste ES el gancho. Un micro-juego se recuerda
   porque te hizo reír ("el chatbot olvidó por qué existe"). El humor refuerza
   la legibilidad y la identidad; no es decoración.
5. **PUNTAJE COMO LENGUAJE** — combos, multiplicadores, ranks (D→C→B→A→S→S+).
   El jugador persigue el número y el récord.
6. **IMPACT FRAMES EN TODO** — cada acierto, choque o recogida debe sentirse:
   hitstop, shake, punch de FOV, flash, respuesta de audio.
7. **DATA-DRIVEN / ABSTRACCIÓN MÁXIMA** — un micro-juego son **datos, no
   código**. Los arquetipos son motores genéricos que se configuran con
   `.tres` (recipes). La UI se auto-genera desde los mismos datos. El objetivo
   de ingeniería: crear el micro-juego #37 debe costar **un archivo `.tres` y
   cero líneas de código** (salvo assets nuevos). Si hace falta código para un
   micro-juego, la abstracción está incompleta — se arregla el motor, no se
   parchea el micro-juego.

**Anti-goal explícito:** NO escribir 36 scripts de micro-juego. Si un cambio de
balance o un micro-juego nuevo requiere tocar código, el diseño ha fallado.

**Fantasy del jugador:** "Soy el dueño de la cuadra. Cada 30 segundos el barrio
entero se transforma y me reta a algo nuevo. Quiero más puntos que nadie."

**Público / sensibilidad:** humor absurdo e irreverente pero **amigable**
(familiar-adjacent). Sin groserías fuertes, sin contenido sexual, sin violencia
gráfica. Los chistes apuntan a *situaciones* (la burocracia tech, el commute,
la ansiedad de notificaciones), no a grupos de personas. Piensa: sátira suave
de "la vida moderna es absurda", no un roast.

---

## 2. VOZ Y TONO (Voice & Tone)

El juego tiene **una voz de locutor arcade** hiperactivo, auto-consciente y un
poco pasivo-agresivo — como un presentador de televisión que tuvo demasiada
azúcar. Es el pegamento cómico de todo el juego.

**Reglas de la voz:**
- Frases cortas. Ritmo rápido. Maiúsculas para énfasis.
- Auto-consciente: el locutor sabe que es un juego arcade y lo dice.
- Ironía suave sobre tech/IA: respeta la emoción, exagera el absurdo.
- Nunca cruel con el jugador; el "roast" es cariñoso ("casi. no.").

**Callouts del locutor (VO) — ejemplos canónicos:**

| Momento | Línea de VO |
|---|---|
| inicio de partida | "FIVE MINUTES. NO MERCY. GO!" |
| power-up recogido | "ROULETTE TIME! Fate is loading..." |
| ruleta girando | "What could it be? Who knows! Not me!" |
| micro-juego arranca | "GO GO GO!" |
| combo alto | "COMBO x{5}! Show off." |
| tiempo < 30s | "THIRTY SECONDS! PANIC!" |
| micro-juego fallado | "Oof. The bot is disappointed. It's a bot. It can't be. But it is." |
| micro-juego perfecto | "FLAWLESS. I'm telling everyone." |
| final de partida S-rank | "S-RANK! You absolute monster." |
| final de partida bajo | "Well. You tried. Did you though?" |

**Mensajes de fracaso por micro-juego:** cada uno tiene 2-3 variaciones cómicas
cortas (evita la repetición). Ver ficha de cada uno en `docs/design/minigames.md`.

---

## 3. STACK TECNOLÓGICO

| Capa | Elección | Notas |
|---|---|---|
| Motor | **Godot 4.3+** (objetivo 4.4 LTS) | Forward+ por defecto; perfil `Compatibility` opcional para low-end |
| Lenguaje | **GDScript** (tipado estático obligatorio) | Sin extensiones C#/GDExtension salvo necesidad crítica aprobada |
| Render 3D | Forward+, HDR, tonemap ACES/AgX, glow HDR, volumetrics | Ver §12 |
| Modelado | **Blender 4.x** → export `.glb` (glTF 2.0) | Ver §11 |
| Audio | Godot buses + `AudioStreamInteractive` (4.3+) para música dinámica beat-synced | Fallback: mezcla manual de stems cuantizada |
| Testing | **GUT** (Godot Unit Test) vía addon | Tests de contratos, RNG determinista, score |
| Control de versiones | git + Git LFS para assets binarios | Convención de commits: Conventional Commits |
| Target plataforma | PC (Win/Linux) primero; consola/portátil después | Export presets preparados desde día 1 |

**Regla de oro de arquitectura:** todo sistema de gameplay es un **contrato**.
Ningún micro-juego conoce al MatchManager; recibe un contexto inyectado.
Ningún sistema habla con otro directamente: vía `EventBus` (señales
desacopladas) o vía `GameServices` (service locator). Ver §5 y §7.

---

## 4. ESTRUCTURA DEL PROYECTO

```
arcades/
├── AGENTS.md                     # Directivas de trabajo para agentes
├── scaffold.md                   # Este archivo (brief maestro)
├── README.md
├── project.godot
├── export_presets.cfg
├── icon.svg
├── .gitignore / .gitattributes
│
├── docs/
│   ├── design/
│   │   ├── GDD.md                # Game Design Document expandido
│   │   ├── minigames.md          # Ficha de los 36 micro-juegos (+ flavor/fallos)
│   │   ├── art-bible.md          # Dirección de arte, paletas, referencias
│   │   └── audio-design.md       # Diseño sonoro y musical detallado
│   └── architecture/
│       ├── contracts.md          # Referencia de contratos (copia canónica de §7)
│       └── roadmap.md            # Fases y tareas
│
├── assets/
│   ├── art/
│   │   ├── blender/              # FUENTES .blend (nunca editar .glb a mano)
│   │   │   ├── city/             # edificios, aceras, calle
│   │   │   ├── characters/       # jugador + NPCs/avatares
│   │   │   ├── props/            # props de cuadra
│   │   │   └── fx/               # props de efectos de micro-juegos
│   │   ├── models/               # .glb EXPORTADOS (importados por Godot)
│   │   │   └── (city/ characters/ props/ fx/)
│   │   ├── textures/             # paletas, atlas, emissive
│   │   └── materials/            # .tres de materiales compartidos
│   ├── audio/
│   │   ├── music/                # stems + loops por estado musical
│   │   ├── sfx/                  # (player/ world/ ui/ impact/ vo/)
│   │   └── ambience/             # capas de ambiente de cuadra
│   ├── ui/                       # sprites, iconos, fuentes
│   └── shaders/                  # .gdshader reutilizables
│
├── src/                          # TODO el código y escenas del juego
│   ├── core/
│   │   ├── event_bus.gd          # autoload
│   │   ├── game_services.gd      # autoload — Service Locator
│   │   ├── rng/seeded_rng.gd     # RNG determinista (tests/ruleta)
│   │   ├── pooling/object_pool.gd
│   │   ├── state_machine/state_machine.gd + state.gd
│   │   └── config/game_config.gd
│   │
│   ├── match/
│   │   ├── match_manager.gd      # autoload — timer 5 min, fases, score global
│   │   ├── states/               # boot, title, countdown, freeroam, roulette,
│   │   │                         # minigame, style_pop, results
│   │   ├── score/score_director.gd
│   │   └── score/score_popup.tscn
│   │
│   ├── player/
│   │   ├── player.gd
│   │   ├── player_motor.gd       # movimiento (CharacterBody3D)
│   │   ├── player_avatar.tscn
│   │   └── player_input.gd
│   │
│   ├── world/
│   │   ├── city_block.tscn       # la cuadra completa (modular)
│   │   ├── block_tile.tscn       # tile reutilizable de acera/calle
│   │   ├── buildings/            # variantes de edificios
│   │   └── props/                # props estáticos + spawn points
│   │
│   ├── styles/
│   │   ├── style_director.gd     # autoload — aplica/blend de style packs
│   │   ├── style_pack.gd         # Resource (contrato de datos)
│   │   ├── style_postfx.gd       # Resource (perfil de post-proceso)
│   │   └── packs/*.tres          # los 12 style packs
│   │
│   ├── juice/
│   │   ├── impact_director.gd    # autoload — hitstop, shake, flashes
│   │   ├── impact_frame.gd       # Resource (preset de impacto)
│   │   ├── camera_director.gd    # autoload — cámara, FOV punch, shake
│   │   ├── postfx_director.gd    # autoload — WorldEnvironment, overlays
│   │   └── screen_effects/       # flash, vignette, chromatic (fullscreen)
│   │
│   ├── audio/
│   │   ├── audio_director.gd     # autoload — buses, SFX pooling, ducking
│   │   ├── music_director.gd     # música dinámica, states beat-synced
│   │   ├── sfx_library.gd        # catálogo de SFX + reglas de voz
│   │   ├── sfx_player.gd         # pool de voces con límite y prioridad
│   │   └── voice_lines.gd        # catálogo de VO del locutor (por evento)
│   │
│   ├── powerups/
│   │   ├── powerup_spawner.gd
│   │   ├── powerup.tscn + .gd
│   │   └── roulette/
│   │       ├── roulette_controller.gd
│   │       └── roulette_wheel.tscn
│   │
│   ├── minigames/
│   │   ├── minigame.gd           # ★ CONTRATO BASE (abstracto)
│   │   ├── minigame_context.gd   # ★ inyección de dependencias
│   │   ├── minigame_metadata.gd  # ★ Resource de datos
│   │   ├── minigame_result.gd    # ★ resultado
│   │   ├── minigame_registry.gd  # registro (ID → escena/metadata)
│   │   ├── minigame_director.gd  # orquesta ciclo de vida
│   │   ├── slots/                # ★ CONTRATOS DE COMPOSICIÓN (recetas)
│   │   │   ├── spawn_recipe.gd       # qué aparece y cómo se comporta
│   │   │   ├── objective_recipe.gd   # qué hay que hacer para ganar
│   │   │   └── hud_recipe.gd         # cómo se comunica el objetivo
│   │   ├── archetypes/           # 14 motores genéricos (implementan slots)
│   │   │   ├── archetype_collect_rush.gd
│   │   │   ├── archetype_chase.gd
│   │   │   ├── archetype_dodge.gd
│   │   │   ├── archetype_tap_target.gd
│   │   │   ├── archetype_rhythm.gd
│   │   │   ├── archetype_zone_hold.gd
│   │   │   ├── archetype_gate_race.gd
│   │   │   ├── archetype_combo_chain.gd
│   │   │   ├── archetype_meter_stop.gd
│   │   │   ├── archetype_charge_blast.gd
│   │   │   ├── archetype_push_zone.gd
│   │   │   ├── archetype_memory.gd
│   │   │   ├── archetype_balance.gd
│   │   │   └── archetype_stack_timed.gd
│   │   └── catalog/              # 36 definiciones .tres (datos puros)
│   │
│   ├── ui/
│   │   ├── hud/hud.tscn + widgets (timer, score, combo, objective)
│   │   ├── roulette/roulette_ui.tscn
│   │   ├── screens/ (title, results, pause, settings)
│   │   └── theme/ (temas HUD por estilo)
│   │
│   └── systems/
│       ├── save_system.gd
│       ├── settings.gd          # accesibilidad incluida
│       └── leaderboard.gd
│
├── addons/                       # plugins de terceros (gut, etc.)
├── tests/
│   ├── unit/                     # contratos, score, rng, timers
│   └── integration/              # flujo match completo headless
└── tools/
    ├── blender/export_glb.py     # exportador .blend → .glb
    ├── audio/stem_mixer.py       # builder de AudioStreamInteractive
    └── validate/validate_assets.py
```

---

## 5. ARQUITECTURA GENERAL

```
                         ┌──────────────────────────────┐
                         │      GameServices (SL)       │
                         │  registro de todos los       │
                         │  sistemas (autoloads)        │
                         └──────────────┬───────────────┘
                                        │ resuelve
        ┌───────────────┬───────────────┼───────────────┬──────────────┐
        ▼               ▼               ▼               ▼              ▼
   MatchManager    StyleDirector   ImpactDirector   AudioDirector  MinigameDirector
   (estados)       (style packs)   (hitstop/shake)  (buses/música) (ciclo micro-juegos)
        │               │               │               │              │
        └───────┬───────┘               │               │              │
                ▼                       ▼               ▼              ▼
           EventBus ────────────► todos los sistemas escuchan, nadie acopla
```

**Flujo de una partida (máquina de estados del match):**

```
BOOT → TITLE → COUNTDOWN(3-2-1) → FREE_ROAM ──┬── power-up recogido ──► ROULETTE (2-3s)
        ▲                                      │                              │
        │                                      │                    MINIGAME (10-30s)
        │                               tiempo sigue corriendo                  │
        │                                      │                              ▼
        │                                      ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄  STYLE_POP / SCORING (1-2s)
        │                                                                     │
        └────────────────────── vuelve a FREE_ROAM ◄─────────────────────────┘
                                              ... repetir hasta TIME_UP
TIME_UP → RESULTS (rank, récords) → TITLE
```

El timer de 5 min corre continuo (salvo countdown/results). Los micro-juegos se
ejecutan **dentro** del match, sin pausar el reloj global.

---

## 6. SISTEMAS CORE (autoloads)

Cada sistema se registra en `GameServices` al arrancar. Ningún sistema
referencia a otro directamente; usa `GameServices.get(&"nombre")` o escucha
señales del `EventBus`.

### 6.1 EventBus
Bus de señales global. Eventos definidos como constantes. Solo para
desacoplamiento de alta latencia (estados, audio, UI). Nunca para lógica de
gameplay frame-a-frame donde importe el orden de ejecución (ahí: llamada directa).

Señales canónicas (extensible):
```
powerup_collected(minigame_id)
roulette_started / roulette_result(id)
minigame_started(id) / minigame_finished(result)
style_applied(pack_id) / style_reverted()
score_changed(total, delta) / combo_changed(combo)
impact_requested(weight)      # pedido de impact frame
match_time_up() / match_started() / match_reset()
player_state_changed(state)   # idle/run/air/hurt/etc.
voice_requested(event_id)     # solicitud de línea de VO al locutor
```

### 6.2 MatchManager
- Timer global de 300s (configurable), fuente de verdad del tiempo restante.
- Orquesta la máquina de estados (§5).
- Acumula score global vía `ScoreDirector`.
- Emite `match_time_up()` y transición a RESULTS.
- No conoce micro-juegos: solo conoce a `MinigameDirector`.

### 6.3 ScoreDirector
- Score base + multiplicador de combo + bonus de tiempo restante + style bonus.
- Combo sube al encadenar éxitos (power-ups sin fallar, micro-juegos seguidos),
  se resetea al fallar o tras X segundos sin eventos.
- Rank final: D < C < B < A < S < S+ (umbrales en `.tres`, tuneables).
- Emite `score_changed` / `combo_changed`; spawnea `score_popup` (world-space).

### 6.4 StyleDirector
- Aplica un `StylePack` al mundo con transición (lerp de ~0.3-0.5s).
- Estrategias de swap: `FULL_SWAP` (materiales/modelos distintos),
  `SHADER_UNIFORM` (uniformes globales que el shader lee — preferido, barato),
  `OVERLAY` (material_overlay sobre meshes).
- Auto-revierte al estilo base cuando el micro-juego termina.
- Coordina con PostFX, Audio (música), Camera (FOV) y HUD (tema).

### 6.5 ImpactDirector
- API única: `impact(weight: ImpactWeight)` o `impact_frame(preset: ImpactFrame)`.
- Ejecuta hitstop global, camera shake, FOV punch, flash, chroma pulse,
  freeze de modelo, capa de audio de impacto.
- Todo parametrizado por presets `.tres` (nunca números hardcodeados en gameplay).

### 6.6 CameraDirector
- Cámara de seguimiento del jugador con lag suave (spring).
- `fov_punch(degrees, duration)`, `shake(trauma, freq, duration)`,
  `zoom_pulse(...)` para momentos dramáticos (ruleta, impacto).
- FOV base por style pack.

### 6.7 PostFXDirector
- Controla el `WorldEnvironment` (glow, color correction, fog, SSAO/SSIL,
  tonemap) y los efectos fullscreen (flash, vignette, chromatic, scanlines).
- Interpolación suave entre perfiles de estilo (transiciones sin pop).

### 6.8 AudioDirector
- Layout de buses (§10). Pool de SFX con límite de voces, prioridad e
  interrupción. Randomización de pitch/volumen por toma. Ducking automático
  (VO, impactos, música). Música delegada en MusicDirector.

### 6.9 MusicDirector
- Música dinámica por estados (§10.2): `CALM`, `TENSION`, `PEAK`, `TRIUMPH`,
  `FAIL`. Transiciones cuantizadas a compás. Reacciona a intensidad (cercanía
  de power-ups, combo alto, tiempo restante < 30s).

### 6.10 VoiceDirector (locutor arcade)
- Catálogo de líneas de VO por evento (`voice_lines.gd` + audios).
- Anti-spam: cooldown por evento, prioridad, nunca dos voces a la vez.
- Las líneas se eligen con variación aleatoria (2-3 por evento) para no cansar.
- Ducking alto: el locutor siempre se entiende sobre la música.

### 6.11 PowerUpDirector + RouletteController
- Spawner: power-ups brillantes distribuidos por la cuadra, reaparecen al
  recogerse tras cooldown; máximo N activos simultáneos (presión constante).
- Al recoger: `roulette_started` → rueda visual (~2.5s) → elige micro-juego
  aleatorio vía `SeededRNG` → entrega a `MinigameDirector`.

### 6.12 MinigameDirector
- Carga el micro-juego elegido desde `MinigameRegistry`, inyecta
  `MinigameContext`, ejecuta `setup → start`, delega `update/on_input`,
  recibe `MinigameResult`, ejecuta `teardown`, notifica al MatchManager.
- Gestiona cooldown entre micro-juegos y anti-repetición inmediata (evita el
  mismo micro-juego dos veces seguidas salvo catálogo agotado; además evita el
  mismo arquetipo 2 veces si hay alternativas).

---

## 7. CONTRATOS DE IMPLEMENTACIÓN

> Copia canónica en `docs/architecture/contracts.md`. Estos contratos son
> **estables**: cambiarlos requiere actualizar este archivo, el doc y los tests.

### 7.1 Minigame (contrato base)

```gdscript
# src/minigames/minigame.gd
class_name Minigame
extends Node
## Contrato base de TODO micro-juego. Los arquetipos lo extienden; las
## definiciones .tres lo configuran. Un micro-juego NUNCA referencia
## MatchManager, ScoreDirector ni otros sistemas directamente.

signal finished(result: MinigameResult)
signal progress_changed(normalized: float)   # 0..1, para HUD
signal event(kind: StringName, payload: Dictionary)  # hooks de juice/audio/voice

# --- Ciclo de vida (obligatorio respetar el orden) ---

## Inyección. Sin gameplay todavía. Leer del contexto.
func setup(ctx: MinigameContext) -> void:
    push_error("%s: setup() no implementado" % get_script().resource_path)

## Comienza el micro-juego: arrancar timers, spawnear entidades, pedir música.
func start() -> void:
    push_error("%s: start() no implementado" % get_script().resource_path)

## Frame lógico. NO usar _process/_physics_process directamente salvo
## que el arquetipo lo documente; el director llama a update().
func update(delta: float) -> void:
    pass

## Entrada cruda; cada micro-juego decide qué usa (teclas, ratón, stick).
func on_input(event: InputEvent) -> void:
    pass

## Cierre limpio: devolver objetos al pool, apagar música extra,
## dejar el mundo como se encontró.
func teardown() -> void:
    pass

# --- Metadata ---
func get_metadata() -> MinigameMetadata:
    push_error("%s: get_metadata() no implementado" % get_script().resource_path)
    return null
```

**Reglas del contrato:**
- Un micro-juego termina SOLO llamando `finished(result)` o cuando el director
  lo aborta (timeout del match).
- Debe ser determinista dado el mismo `SeededRNG` y la misma semilla.
- Debe funcionar con entrada de teclado, ratón Y mando (ver §13).
- No debe dejar entidades huérfanas ni estados globales sucios.

### 7.2 MinigameContext (inyección)

```gdscript
# src/minigames/minigame_context.gd
class_name MinigameContext
extends RefCounted

var match_manager: MatchManager
var score: ScoreDirector
var style: StyleDirector
var impact: ImpactDirector
var camera: CameraDirector
var postfx: PostFXDirector
var audio: AudioDirector
var music: MusicDirector
var voice: VoiceDirector
var player: Player
var world_root: Node3D          # padre para spawnear entidades del micro-juego
var arena_center: Vector3       # centro de la cuadra
var rng: SeededRNG              # determinista por micro-juego
var difficulty: float           # 0..1, sube con el tiempo restante bajo
var time_left_in_match: float   # el micro-juego nunca debe exceder esto
```

### 7.3 MinigameMetadata (Resource — LA RECETA)

Este Resource es el **corazón del data-driven design**. Un micro-juego es un
`.tres` de este tipo. NO se le añaden campos específicos de micro-juego: la
variedad vive en los `slots` (composición), no en campos nuevos. Ver §8.0.

```gdscript
# src/minigames/minigame_metadata.gd
class_name MinigameMetadata
extends Resource

# --- Identidad (UI + catálogo) ---
@export var id: StringName                 # "token_rush"
@export var display_name: String           # "Token Rush"
@export var archetype: StringName           # "COLLECT_RUSH"
@export var duration_s: float = 20.0        # 10..30
@export var base_score: int = 1000
@export var weight: float = 1.0             # frecuencia en la ruleta
@export var theme_tag: StringName           # AI | LIFE | HYBRID (balance/filtro)

# --- Contenido del jugador (inglés) ---
@export var objective_text: String          # "Grab tokens before it forgets!"
@export var flavor_text: String             # chiste/descripción cómica (1 línea)
@export var fail_lines: PackedStringArray   # 2-3 mensajes de fracaso con humor

# --- Look & sonido (reutiliza contratos globales, no duplica) ---
@export var style_pack_id: StringName = &"" # "" = estilo base del mundo
@export var music_state: StringName = &"PEAK"

# --- Slots de composición (ver §8.0) ---
@export var input_mode: StringName          # RUN | BUTTON | STICK | LOOK | TAP
@export var spawn_recipe: SpawnRecipe       # QUÉ entidades aparecen y cómo
@export var objective_recipe: ObjectiveRecipe # QUÉ hay que hacer para ganar
@export var hud_recipe: HUDRecipe           # CÓMO se presenta el objetivo en HUD
@export var difficulty_curve: Curve         # cómo escala con ctx.difficulty

# --- Etiquetas ---
@export var tags: PackedStringArray         # filtros/balance
```

### 7.3.1 Slots: contratos de composición

La variedad de los 36 micro-juegos NO sale de 36 scripts; sale de combinar
estos 5 contratos modulares. Un micro-juego nuevo = elegir arquetipo + llenar
slots en un `.tres`. Si un micro-juego no cabe en los slots, se extiende el
slot correspondiente (una vez) en lugar de crear un script por micro-juego.

```gdscript
# src/minigames/slots/spawn_recipe.gd
class_name SpawnRecipe
extends Resource
## QUÉ aparece en la arena y cómo se comporta.
@export var entity_scene: PackedScene      # prop del micro-juego (token, GPU...)
@export var count: int = 12
@export var count_scales_with_difficulty: bool = true
@export var spawn_radius: float = 18.0      # metros alrededor del jugador
@export var spawn_pattern: StringName       # SCATTER | RING | GRID | LINE | WAVE
@export var motion: StringName              # STATIC | ORBIT | FLEE | CHASE | FALL
@export var speed: float = 4.0
@export var lifetime_s: float = -1.0        # -1 = hasta recogerse/impactar
@export var respawn: bool = false           # reaparición tras recogerse
@export var pool_group: StringName = &"mg_entity"

# src/minigames/slots/objective_recipe.gd
class_name ObjectiveRecipe
extends Resource
## QUÉ hay que hacer. El arquetipo evalúa esta condición cada frame.
@export var kind: StringName                # COLLECT_N | SURVIVE_T | TAP_N | HOLD_ZONE_T
                                             # GATES_IN_ORDER | CHAIN_N | STOP_IN_ZONE | ...
@export var target: int = 12                # N objetos / N segundos / N gates
@export var tolerance: float = 0.0          # ventana de acierto (seg/beat/unidades)
@export var fail_on: StringName             # TIMEOUT | TOUCH_HAZARD | WRONG_INPUT | NONE
@export var time_bonus_per_s: int = 100     # puntos por segundo sobrante al ganar
@export var combo_step: float = 0.25        # incremento de multiplicador por acierto

# src/minigames/slots/hud_recipe.gd
class_name HUDRecipe
extends Resource
## CÓMO se comunica el objetivo. La UI se auto-construye desde aquí
## (ver §13): cero código de HUD por micro-juego.
@export var primary_widget: StringName      # COUNTER | TIMER | PROGRESS | SEQUENCE
@export var icon: Texture2D                 # icono del objetivo (silueta legible)
@export var color_hint: StringName = &""    # color semántico del objetivo
@export var show_flavor: bool = true        # mostrar el chiste durante el arranque
@export var callout_on_start: StringName = &"GO GO GO!"
```

**Renderer por arquetipo (no por micro-juego):** cada arquetipo sabe renderizar
sus slots. El `MinigameRegistry` resuelve `archetype → escena base`; la escena
lee la recipe y auto-configura spawns, objetivo y HUD. Por eso el micro-juego
#37 es un `.tres` y nada más.

### 7.4 MinigameResult

```gdscript
# src/minigames/minigame_result.gd
class_name MinigameResult
extends RefCounted

var success: bool = false
var base_score: int = 0
var time_bonus: int = 0        # proporcional al tiempo sobrante
var combo_max: int = 0
var total_score: int = 0
var grade: StringName = &"D"   # D C B A S S+
var fail_reason: StringName = &""  # TIMEOUT | WRONG_INPUT | HIT | ...
```

### 7.5 StylePack (Resource)

```gdscript
# src/styles/style_pack.gd
class_name StylePack
extends Resource

@export var id: StringName
@export var display_name: String

# --- Mundo ---
@export var sky_top: Color
@export var sky_horizon: Color
@export var fog_color: Color
@export var fog_density: float
@export var sun_color: Color
@export var sun_energy: float
@export var ambient_color: Color
@export var ambient_energy: float

# --- Look ---
@export var material_mode: StringName      # FULL_SWAP | SHADER_UNIFORM | OVERLAY
@export var character_material: Material   # material del jugador/NPCs
@export var environment_material: Material # materiales del mundo
@export var postfx: StylePostFX            # bloom, chroma, vignette, scanline...
@export var fov_override: float = -1.0     # -1 = no override
@export var camera_offset: Vector3 = Vector3.ZERO

# --- Feedback ---
@export var music_state: StringName = &""
@export var hud_theme: Theme
@export var transition_s: float = 0.4
@export var revert_to_base_on_end: bool = true
```

### 7.6 ImpactFrame (Resource)

```gdscript
# src/juice/impact_frame.gd
class_name ImpactFrame
extends Resource

@export var hitstop_s: float = 0.06        # 40..120ms típico
@export var time_scale: float = 0.05       # escala durante el hitstop
@export var shake_amplitude: float = 0.3   # trauma 0..1
@export var shake_frequency: float = 24.0
@export var shake_duration_s: float = 0.4
@export var fov_punch: float = -6.0        # grados (negativo = punch-in)
@export var chromatic_pulse: float = 0.5
@export var flash_color: Color = Color.WHITE
@export var flash_alpha: float = 0.3
@export var desaturate: float = 0.3
@export var model_freeze: bool = false     # congela el modelo, el mundo sigue
@export var slow_mo_curve: Curve            # curva de time_scale post-hitstop
@export var impact_sfx: AudioStream
```

### 7.7 MinigameRegistry

- Registro central ID → {escena `.tscn`, `MinigameMetadata`}.
- Poblado por escaneo de `src/minigames/catalog/*.tres` al arrancar.
- El director resuelve `id → instancia`, inyecta contexto, ejecuta.
- Garantiza que todo micro-juego del catálogo tenga escena y metadata válidas
  (validación al boot; falla ruidosa, no silenciosa).

---

## 8. MICRO-JUEGOS: ARQUETIPOS Y CATÁLOGO

### 8.0 Principio de abstracción: composición, no herencia

**La regla que ahorra el 90% del código de micro-juegos:**

> Un micro-juego NO es una clase. Es **datos** (una `MinigameMetadata` con sus
> slots llenos) ejecutados por un **arquetipo genérico**. La variedad viene de
> *combinar* slots, no de *heredar* clases.

```
Micro-juego #37  =  Arquetipo (motor genérico, 14 total)
                 +  SpawnRecipe        (.tres — qué aparece)
                 +  ObjectiveRecipe    (.tres — qué hay que hacer)
                 +  HUDRecipe          (.tres — cómo se muestra)
                 +  InputMode          (RUN/BUTTON/STICK/LOOK/TAP)
                 +  contenido/flavor   (.tres — el chiste)
                 ─────────────────────────────────────────────
                 =  UN archivo .tres. CERO líneas de código.
```

**Cómo mutar un micro-juego (rápido, sin tocar código):**
- Cambiar dificultad → editar `target` / `speed` / `difficulty_curve`.
- Cambiar de tema (de IA a vida) → cambiar `entity_scene` + `flavor_text`.
- Cambiar de look → cambiar `style_pack_id`.
- Cambiar de control → cambiar `input_mode`.
- Nuevo micro-juego con mecánica existente → duplicar el `.tres` y ajustar.

**Cuándo SÍ se toca código (raro, y es una decisión de arquitectura):**
1. Una mecánica que **ningún** arquetipo cubre → se crea UN arquetipo nuevo
   (motor genérico reutilizable), no un script de micro-juego.
2. Un slot que no expresa la variación necesaria → se extiende ESE slot
   (p. ej. añadir `spawn_pattern: SPIRAL`), beneficiando a todos los
   micro-juegos que lo usen.
3. Nunca: un `if minigame_id == "token_rush"` en gameplay. Eso es el anti-
   patrón que este diseño existe para eliminar.

**Estructura de `archetypes/`:** cada arquetipo es UNA escena + UNA clase que
implementa el `Minigame` leyendo sus slots. 14 arquetipos cubren los 36
micro-juegos. Un arquetipo se testea una vez (test de ciclo de vida + test de
slots) y todos sus micro-juegos heredan esa garantía.

---

**Estrategia:** 14 arquetipos (contratos base implementados) + 36 micro-juegos
concretos como **configuraciones** de esos arquetipos. Así se cumplen los 30+
con contratos fáciles de implementar y de testear. Ficha completa de cada uno
(con tuning por dificultad, flavor text, mensajes de fallo y style pack) en
`docs/design/minigames.md`.

### 8.1 Arquetipos (contratos base)

| # | Arquetipo | Gancho de control | Condición de éxito |
|---|---|---|---|
| 1 | COLLECT_RUSH | correr y tocar | recoger N objetos antes del tiempo |
| 2 | CHASE | perseguir/huir de un móvil | alcanzar/esquivar objetivo móvil |
| 3 | DODGE | esquivar obstáculos | sobrevivir sin recibir daño |
| 4 | TAP_TARGET | pulsar/golpear objetivos | acertar N objetivos |
| 5 | RHYTHM | pulsar al beat | aciertos en ventana de tiempo musical |
| 6 | ZONE_HOLD | mantener una zona | acumular X segundos en zona |
| 7 | GATE_RACE | pasar por gates en orden | completar recorrido en orden |
| 8 | COMBO_CHAIN | encadenar acciones sin fallar | cadena de N sin fallo |
| 9 | METER_STOP | parar medidor en zona | parar en zona válida N veces |
| 10 | CHARGE_BLAST | cargar y soltar | soltar en ventana/potencia óptima |
| 11 | PUSH_ZONE | empujar objetos a zona | meter N objetos en zona |
| 12 | MEMORY | repetir secuencia | replicar patrón (Simon) |
| 13 | BALANCE | mantener trayectoria | recorrer camino que se estrecha |
| 14 | STACK_TIMED | apilar con timing | apilar N en altura objetivo |

### 8.2 Catálogo de 36 micro-juegos

`theme_tag`: **AI** (cultura tech/IA) · **LIFE** (vida moderna) · **HYBRID**
(ambas). El chiste va en `flavor_text`; el gancho en la columna "Gancho".

| # | ID | Nombre | Arquetipo | Tag | Gancho (1 línea) |
|---|---|---|---|---|---|
| 1 | token_rush | Token Rush | COLLECT_RUSH | AI | Grab tokens before the chatbot forgets why it exists |
| 2 | data_diet | Data Diet | COLLECT_RUSH | AI | Clean data good, junk data bad. You are the filter |
| 3 | grocery_getaway | Grocery Getaway | COLLECT_RUSH | LIFE | Grab groceries; don't let the self-checkout catch you |
| 4 | porch_pirate | Porch Pirate | COLLECT_RUSH | LIFE | Packages appear. Pirates appear. Grab first |
| 5 | hallucination_highway | Hallucination Highway | DODGE | AI | Dodge confidently-wrong answers. They're SO sure |
| 6 | gpu_meltdown | GPU Meltdown | DODGE | AI | Overheating GPUs are raining. Find shade |
| 7 | commuter_chaos | Commuter Chaos | DODGE | LIFE | 8:47 AM. Umbrellas everywhere. Good luck |
| 8 | laundry_landmine | Laundry Landmine | DODGE | LIFE | The dryer eats socks. And apparently you now |
| 9 | bias_bug_bash | Bias Bug Bash | TAP_TARGET | AI | Whack the bias bugs. They keep popping up |
| 10 | spam_smash | Spam Smash | TAP_TARGET | LIFE | "YOU WON A CRUISE!" Smash it. Smash them all |
| 11 | autocomplete_alley | Autocomplete Alley | TAP_TARGET | AI | Tap what it predicts. Or rebel. Rebelling loses points |
| 12 | notification_nuke | Notification Nuke | TAP_TARGET | LIFE | 47 notifications. Tap them before they breed |
| 13 | beat_of_the_bot | Beat of the Bot | RHYTHM | AI | Pulse to the synthetic rhythm. You can tell. Barely |
| 14 | barista_blitz | Barista Blitz | RHYTHM | LIFE | Espresso machine rhythm. Tap on the hiss |
| 15 | flow_state | Flow State | ZONE_HOLD | LIFE | Hold the focus zone. The world wants you distracted |
| 16 | silent_disco | Silent Disco | ZONE_HOLD | LIFE | Hold your headphone bubble. Everyone's screaming. Not you |
| 17 | merge_merge_merge | Merge Merge Merge | GATE_RACE | LIFE | Highway merge. Nobody zips. Nobody cares |
| 18 | prompt_chain | Prompt Chain | COMBO_CHAIN | AI | Chain the prompt words. Order matters. Obviously |
| 19 | combo_commute | Combo Commute | COMBO_CHAIN | LIFE | Transfer, transfer, transfer. Don't miss the line |
| 20 | stack_overflow | Stack Overflow | BALANCE | HYBRID | Balance the overloaded stack. Don't drop the frame |
| 21 | context_recall | Context Recall | MEMORY | AI | Remember the context. Before it's evicted |
| 22 | password_palace | Password Palace | MEMORY | LIFE | Remember the password. It was the good one |
| 23 | learning_rate | Learning Rate | METER_STOP | AI | Stop the LR in the sweet spot. Too high = explode |
| 24 | push_and_pray | Push & Pray | CHARGE_BLAST | HYBRID | Time the git push. Main branch is watching |
| 25 | feature_freeze | Feature Freeze | PUSH_ZONE | HYBRID | Push features to the release zone. Or scope creep |
| 26 | inference_inferno | Inference Inferno | CHASE | AI | Chase the runaway inference. It's fast. Too fast |
| 27 | delivery_dash | Delivery Dash | CHASE | LIFE | Chase the driver. They saw you. They keep driving |
| 28 | tech_debt_tower | Tech Debt Tower | STACK_TIMED | HYBRID | Stack the debt. It'll fall. It always falls |
| 29 | elevator_endurance | Elevator Endurance | ZONE_HOLD | LIFE | Hold the door. Someone's coming. Always |
| 30 | circular_referencing | Circular Referencing | GATE_RACE | AI | Break the infinite loop. Find the exit. There is no exit |
| 31 | agile_sprint | Agile Sprint | GATE_RACE | LIFE | Sprint through the sprint. Retrospective at the end |
| 32 | sudo_smash | Sudo Smash | TAP_TARGET | HYBRID | Type the sudo password. Fast. Before the timeout |
| 33 | not_found | 404 Not Found | DODGE | AI | Dodge the 404s. They're lost and confused. So are you |
| 34 | overfitting_olympics | Overfitting Olympics | MEMORY | AI | Memorize the training set. It won't generalize |
| 35 | fire_drill | Fire Drill | DODGE | LIFE | Office fire drill. Again. Walk, don't run. Or do. Points |
| 36 | server_room_scramble | Server Room Scramble | DODGE | HYBRID | The servers are hot. The room is hot. Everything is hot |

**Balance de temas:** ~11 AI · ~15 LIFE · ~10 HYBRID. La ruleta puede ponderar
por `theme_tag` si se detecta saturación de un tema (evita 5 de IA seguidas).

**Reglas transversales de micro-juegos:**
- Todo micro-juego tiene **condición de victoria y de fracaso claras y
  legibles** (HUD con objetivo y progreso).
- Fallar NO termina la partida: pierdes el bonus, el combo se resetea y sigues.
- El tiempo sobrante al ganar convierte en bonus (incentiva velocidad).
- Cada micro-juego tiene al menos 3 picos de impacto (inicio, aciertos, final).
- `flavor_text` + `fail_lines` son obligatorios (el humor es mecánica, pilar 4).

### 8.3 Mapeo arquetipo → slots (referencia de implementación)

Cada arquetipo declara qué slots necesita y cómo los interpreta. Esta tabla es
la guía para implementar los 14 motores genéricos:

| Arquetipo | SpawnRecipe típico | ObjectiveRecipe (kind) | InputMode | HUDRecipe |
|---|---|---|---|---|
| COLLECT_RUSH | SCATTER, STATIC/FLEE | COLLECT_N | RUN | COUNTER |
| CHASE | motion: CHASE, target móvil | CHASE_CATCH / SURVIVE_T | RUN | TIMER |
| DODGE | WAVE/FALL, motion: FALL | SURVIVE_T, fail_on: TOUCH_HAZARD | RUN | TIMER |
| TAP_TARGET | SCATTER, lifetime corto | TAP_N | LOOK/TAP | COUNTER |
| RHYTHM | en beat, motion: ORBIT | TAP_N, tolerance: beat | BUTTON | PROGRESS |
| ZONE_HOLD | 1 zona (no entidades) | HOLD_ZONE_T | RUN | TIMER |
| GATE_RACE | LINE, gates numerados | GATES_IN_ORDER | RUN | SEQUENCE |
| COMBO_CHAIN | orden secuencial | CHAIN_N | BUTTON | SEQUENCE |
| METER_STOP | medidor animado | STOP_IN_ZONE, tolerance | BUTTON | PROGRESS |
| CHARGE_BLAST | 1 proyectil | CHARGE_RELEASE, tolerance | BUTTON | PROGRESS |
| PUSH_ZONE | física, motion: STATIC | PUSH_N_TO_ZONE | RUN/STICK | COUNTER |
| MEMORY | secuencia que se revela | MEMORY_REPLAY | BUTTON | SEQUENCE |
| BALANCE | camino que se estrecha | BALANCE_T, fail_on: FALL | RUN | TIMER |
| STACK_TIMED | caída con timing | STACK_N | BUTTON | COUNTER |

Con esta tabla, los 36 micro-juegos del catálogo se implementan llenando
`.tres` sobre estos 14 motores. Coste por micro-juego: **un `.tres`**.

---

## 9. STYLE PACKS (cambios temporales de apariencia)

Cada power-up/ruleta aplica un style pack que transforma temporalmente mundo +
personaje. Implementación preferente: **SHADER_UNIFORM** — el shader del mundo
lee uniformes globales (`u_style_top`, `u_style_fog`, `u_style_saturation`,
`u_style_scanline`...) que el StyleDirector interpola. Barato, sin pops,
reversible. FULL_SWAP solo para cambios drásticos de modelo.

| Style pack | Paleta/atmósfera | Look | Música |
|---|---|---|---|
| NEON_DRIFT | cian/magenta noche | emisivo, lluvia, reflejos | synthwave |
| INK_NOIR | blanco y negro alto contraste | contornos tinta, grano | noir jazz |
| TOON_POP | primarios brillantes | cel-shading Nintendo-like | pop orquestal |
| VHS_90 | saturado con bleeding | scanlines, chroma shift | retro chiptune |
| BIT_CRUSH | paleta 8-bit limitada | dither, pasos de color | chiptune puro |
| CHROME_BEAM | gris espejo + luz | metal pulido, reflejos HDR | techno |
| CANDY_PLASTIC | pastel plástico | plástico suave, brillos | bubblegum pop |
| KAIJU_SOFVI | colores sólidos mate | vinilo sofvi, escala exagerada | kaiju march |
| SPRITE_25D | pixel art parcial | mezcla 3D/sprites 2D | 16-bit |
| PAPER_CRAFT | papel recortado | recorte, sombras duras | folk acústico |
| GOLD_RUSH | dorado/negro | brillo metal, lentejuelas | big band |
| WATERCOLOR | aguadas suaves | bordes difusos, lavados | ambient piano |

Definición completa (colores exactos, materiales, postfx, transición) en
`docs/design/art-bible.md` y `src/styles/packs/*.tres`.

---

## 10. IMPACT FRAMES Y AUDIO

### 10.1 Impact frames (juice)

Regla: **toda acción del jugador y todo evento de micro-juego emite impacto**.
Escala por `ImpactWeight` (LIGHT / MEDIUM / HEAVY / CRITICAL), resuelto a un
preset `ImpactFrame.tres`:

| Evento | Weight | Hitstop | Shake | FOV | Flash | Audio |
|---|---|---|---|---|---|---|
| recoger power-up | HEAVY | 90ms | 0.35 | -8° | blanco 0.3 | sub drop + click |
| acierto micro-juego | MEDIUM | 60ms | 0.25 | -5° | color estilo | pop + tono |
| combo sube | LIGHT | 40ms | 0.15 | -3° | - | arpegio corto |
| fallo/daño | HEAVY | 80ms | 0.4 | +4° | rojo 0.25 | thud + línea de fallo |
| ruleta resultado | CRITICAL | 120ms | 0.5 | -10° | blanco 0.4 | impact + stinger |
| final de partida | CRITICAL | 150ms | 0.6 | -12° | flash estilo | fanfarria |

Además de hitstop global, soportar **model freeze** (el modelo del jugador se
congela mientras el mundo sigue — sensación de "fotograma congelado") y
**chromatic pulse** en impactos CRITICAL. Presets en `src/juice/impact_frame*.tres`.

### 10.2 Música dinámica

Diseño por **estados musicales** + **capas verticales**:

- Estados: `CALM` (freeroam base), `TENSION` (ruleta / tiempo bajo),
  `PEAK` (micro-juego activo), `TRIUMPH` (resultados), `FAIL` (fallo grave).
- Cada estado tiene un loop base; la **intensidad** controla cuántas capas
  (stems) suenan: `drums` siempre, `bass` desde intensidad 0.3, `lead` desde
  0.6, `harmony+fx` desde 0.85.
- Implementación: `AudioStreamInteractive` (4.3+) con transiciones
  **cuantizadas a compás** (2 compases). Fallback: `AudioStreamPolyphonic` con
  crossfade manual en el siguiente boundary de compás (marcador de beat).
- Tempo bloqueado (p. ej. 128 BPM) para que todo el juego "respire" igual.
- Sidechain/ducking: VO e impactos bajan la música momentáneamente (bus duck).

**Buses de audio:**

```
Master (Limiter)
├── Music      (Compressor, EQ, duck)
├── SFX        (Limiter)
│   ├── Player │   (pitch random ±5%)
│   ├── World
│   ├── UI
│   └── Impact │   (lowpass en hitstop, duck alto)
├── Ambience   (Reverb send)
├── VO         (Compressor, duck alto)   # locutor arcade
└── UI         (limpio, sin reverb)
```

**Reglas de SFX:** layered (transient/body/tail), 3-5 variaciones por evento,
voice-limit por grupo, prioridad + interrupción para no saturar. Locutor (VO)
con callouts arcade por evento (§2), con variación aleatoria y cooldown.

---

## 11. PIPELINE DE ARTE 3D (Blender → Godot)

**Convenciones duras:**
- Escala **1 unidad Blender = 1 metro** en Godot; origen del modelo en la base
  (Godot-friendly, Y-up).
- Naming: `sm_*` (static mesh), `sk_*` (skinned), `col_*` (collision),
  `nav_*` (navmesh), `prop_*`, `bld_*` (edificio).
- Aplicar transforms (escala/rotación) antes de exportar.
- Un `.blend` por asset lógico (o por familia en `lib/`); exports individuales
  vía script `tools/blender/export_glb.py` → `assets/art/models/<cat>/`.
- Formato: glTF 2.0 `.glb`; Godot re-importa; **nunca editar el .glb**.
- Baking de AO a vertex colors; atlas por edificio para minimizar materiales.
- LODs para edificios; low-poly estilizado prioriza silueta legible.
- Presupuestos: edificio < 2k tris, prop < 300 tris, personaje < 8k tris.

**Bloque urbano modular:** tiles de acera/calle componen la cuadra; variantes
de edificios y props se instancian; spawn points y navmesh definidos en escena.
El greyblock (Fase 1) usa primitivas; el arte final (Fase 7) las reemplaza.

**Personaje:** modelo stylized ~6k tris, rig sencillo, animaciones
(idle, run, sprint, jump, land, turn, pick_up, celebrate, hurt, dance).
Animación aditiva de compensación (lean, squash/stretch) para juice.

**Props temáticos (IA/vida):** tokens, GPUs, burbujas de diálogo flotantes,
notificaciones, paquetes, paraguas, latas, cajas — pensados para leerse en
<1s (silueta + color). La legibilidad del chiste depende de la silueta.

---

## 12. RENDER Y POST-PROCESADO

`project.godot` recomendado:
- Renderizador `forward_plus`, HDR 2D/3D activado, tonemap `ACES` (o AgX),
  glow HDR con `blend_mode=softlight` suave, `bloom` discreto (estilo arcade,
  no borroso).
- MSAA 2x/4x (o TAA si se controla el ghosting); antialiasing por estilo.
- Volumetric fog ligero para atmósfera de cuadra; SSAO/SSIL suaves.
- DOF solo en momentos dramáticos (ruleta), no permanente.
- Escalado por resolución para low-end; render scale configurable.
- Shaders globales de estilo: `u_style_*` uniformes leídos por el shader base
  del mundo (§9). Shaders reutilizables en `assets/shaders/`.
- PostFX por estilo en `StylePostFX.tres`: bloom extra, chromatic, scanlines,
  vignette, saturation, desaturation en hitstop.

---

## 13. UI / HUD / UX — DISEÑO DE INTERFACES

> Principio rector: **la UI es data-driven igual que el gameplay**. El HUD se
> auto-construye desde `HUDRecipe` + `MinigameMetadata`. Cero widgets
> hardcodeados por micro-juego. Un micro-juego nuevo muestra su objetivo sin
> que nadie toque la UI.

### 13.1 Sistema de widgets auto-generados

El HUD tiene una **biblioteca fija de widgets genéricos**. Cada uno es un
`.tscn` parametrizable; el `HUDRecipe` elige cuál mostrar y con qué datos:

| Widget | Muestra | Lo dispara (HUDRecipe) | Feedback visual |
|---|---|---|---|
| COUNTER | "7 / 12" + icono | COLLECT_N, TAP_N | pop + scale al subir |
| TIMER | cuenta atrás / acumulado | SURVIVE_T, HOLD_ZONE_T | pulso rojo < 5s |
| PROGRESS | barra con zona válida | STOP_IN_ZONE, RHYTHM | marca que barre |
| SEQUENCE | pasos en orden | GATES, MEMORY, CHAIN | tick al acertar, shake al fallar |
| MULTIPLIER | "x3.5" | combo activo | escala + ruido al subir |

**Regla:** si el objetivo de un micro-juego no se puede expresar con estos 5
widgets, se añade UN widget genérico nuevo (no un widget ad-hoc). Los widgets
leen su configuración del slot, así que un micro-juego nuevo "solo funciona".

**Layout (zona segura, 16:9 y ultrawide):**
- Esquina superior-izquierda: **TIMER de partida** (siempre, el más prominente).
- Esquina superior-derecha: **SCORE** + **MULTIPLIER** (contador animado).
- Centro-superior: **objetivo del micro-juego** (COUNTER/TIMER/PROGRESS/SEQUENCE)
  + flavor text breve durante el arranque (~2s).
- Borde de pantalla: **brújula de power-ups** (flechas off-screen).
- Centro: **callouts de VO** subtitulados (accesibilidad).
- Nunca ocultar el HUD durante micro-juegos: la información es la mecánica.

### 13.2 Estética visual (art direction de UI)

- **Estilo arcade Nintendo:** formas redondeadas, contornos gruesos (outline
  de 2-3px equivalente), colores saturados de alta legibilidad, tipografía
  bold con sombra suave. Legible a un golpe de vista (<1s).
- **Jerarquía por tamaño y movimiento:** lo que el jugador debe mirar AHORA
  (timer, objetivo) es grande y se anima; lo secundario (score) es estable.
- **Feedback en cada cambio:** todo número que cambia hace pop (scale + color),
  todo logro hace ruido (juice + audio). La UI está viva, no es un panel.
- **Tematización por style pack:** el `hud_theme` del StylePack recolorea la UI
  con el mundo (NEON_DRIFT → HUD cian/magenta; INK_NOIR → monocromo). La UI
  muta con el escenario, reforzando la transformación.
- **Ruleta:** pantalla propia a cámara dramática, nombre + objetivo + flavor
  del micro-juego antes del arranque. Es el momento "anuncio" del juego.
- **Resultados:** rank final (D→S+) grande, desglose de score, récord local,
  "Play Again". Celebratorio según rank (fuegos artificiales en S+, silencio
  incómodo en D — el humor también vive aquí).

### 13.3 Accesibilidad

- Remapeo de controles completo (teclado / ratón / mando).
- Intensidad de shake ajustable y opción de desactivar flashes.
- Indicadores de daltonismo para objetivos/peligros (forma + color, no solo
  color).
- Subtítulos/callouts visuales además de voz (VO siempre legible sin sonido).
- Velocidades de texto y legibilidad HUD configurables.

### 13.4 Controles

- Mando primero (Xbox/PS/Switch Pro), teclado/ratón soportados.
- Detección de dispositivo y glyphs correctos en la UI.
- Todos los micro-juegos jugables con cualquiera de los tres (el `input_mode`
  del metadata define el modo; ver §13.1).

---

## 14. ROADMAP POR FASES

| Fase | Entregable | Gate de salida |
|---|---|---|
| 0. Fundación | repo, project.godot, autoloads, contratos, buses audio | boot headless sin errores; tests de contratos pasan |
| 1. Greybox | cuadra jugable, motor movimiento, cámara, HUD, timer 5min | jugar 5 min completos con movimiento fluido |
| 2. Juice core | impact frames, shake, FOV punch, postfx, flashes | presets aplican sin pop; 60fps |
| 3. Audio core | buses, SFX pool, música dinámica, VoiceDirector | transiciones beat-synced audibles; sin clipping; VO se entiende |
| 4. Power-ups + ruleta | spawner, recogida, rueda, selección | loop completo power-up→micro-juego |
| 4.5 Slots + render data-driven | SpawnRecipe/ObjectiveRecipe/HUDRecipe + 1 arquetipo completo | un micro-juego nuevo es SOLO un `.tres` (verificado) |
| 5. Micro-juegos | 1 por arquetipo → los 36 | cada uno jugable punta a punta + test de contrato + humor revisado; cada uno es un `.tres` sin código nuevo |
| 6. Style packs | 12 packs, swap/blend | transformación reversible sin artefactos |
| 7. Arte final | modelado Blender, texturas, entorno | reemplaza greyblock sin romper gameplay |
| 8. Pulido | balance, accesibilidad, leaderboard, export | gates de DoD aprobados |

---

## 15. DEFINITION OF DONE (gates de calidad)

Todo entregable de gameplay debe pasar:

- [ ] Contrato respetado (setup/start/update/input/teardown).
- [ ] Determinismo con semilla fija (test GUT).
- [ ] Jugable con teclado, ratón y mando.
- [ ] Al menos 3 picos de impacto (juice + audio).
- [ ] Condición de victoria/fracaso clara y legible en HUD.
- [ ] `flavor_text` + `fail_lines` escritos y revisados (humor = mecánica).
- [ ] **Abstracción:** el micro-juego es un `.tres` sin código de gameplay
      nuevo (si tuvo que escribir código, el arquetipo/slot se extendió y eso
      quedó documentado). Ver §8.0.
- [ ] **UI auto-generada:** el HUD del objetivo sale del `HUDRecipe`, sin
      widgets ad-hoc. Ver §13.1.
- [ ] Sin entidades huérfanas ni estado global sucio tras teardown.
- [ ] Presupuestos: < 400 draw calls, < 250k tris/frame, < 32 voces SFX
      simultáneas, texturas < 512MB (ajustables; verificar en perfilador).
- [ ] Sin warnings de import ni de runtime en consola.
- [ ] 60fps estables en hardware target (verificado en monitor).
- [ ] Balanceable por datos (.tres), sin números hardcodeados.
- [ ] Documentado (ficha en docs/ + comentario de contrato).

---

## 16. CONVENCIONES Y ANTI-PATRONES

**Código:** GDScript tipado, tabs, `snake_case` vars/funcs, `PascalCase`
clases/Resources, `SCREAMING_SNAKE` constantes. Identificadores en inglés.

**Contenido del juego (inglés):** nombres, HUD, objetivos, flavor text,
mensajes de fallo, VO — todo en inglés. Tone guide en §2.

**Docs de equipo (español):** este scaffold, AGENTS.md, GDD y docs internos se
mantienen en español para el equipo de desarrollo.

**Prohibido:**
- Hardcodear valores de balance en código (van a `.tres`).
- **`if minigame_id == "..."` (o cualquier switch por ID) en gameplay.** Ese
  switch es la señal de que la abstracción falló; la variación va en slots.
- Nuevos autoloads sin actualizar este scaffold y AGENTS.md.
- Acoplar un micro-juego a otro sistema directamente (usa el contexto inyectado).
- Usar señales para gameplay frame-a-frame donde el orden importe.
- Editar assets exportados (.glb, .wav mezclados) a mano.
- Dejar el proyecto en estado que no compila/importa.
- Romper un contrato sin actualizar `docs/architecture/contracts.md` y tests.
- Micro-juego sin `flavor_text`/`fail_lines` (el humor es parte del DoD).
- Widgets de HUD ad-hoc por micro-juego (usa la biblioteca de widgets, §13.1).
- Humor que viole la sensibilidad de §1 (groserías fuertes, violencia gráfica,
  bullying a grupos).

**Árbol de decisión de implementación de un micro-juego:**
1. ¿Existe un arquetipo que cubra la mecánica? → configurar su `.tres` (slots).
2. ¿La mecánica es nueva? → crear arquetipo en `archetypes/` + test + doc
   (un motor genérico reutilizable, NO un script de micro-juego).
3. ¿Un slot no expresa la variación? → extender ESE slot, no el micro-juego.
4. ¿Necesita assets nuevos? → Blender (§11) → glb → import → escena.
5. ¿Cambia look/música? → definir/extender StylePack (§9).

---

## 17. PLANTILLA RÁPIDA DE MICRO-JUEGO

**Caso normal (mecánica cubierta por un arquetipo) — CERO código:**

```
src/minigames/catalog/mi_microjuego.tres
├── id = "mi_microjuego", archetype = "COLLECT_RUSH"
├── spawn_recipe:      entity_scene = token.tscn, count = 12, pattern = SCATTER
├── objective_recipe:  kind = COLLECT_N, target = 12
├── hud_recipe:        primary_widget = COUNTER, icon = token_icon.png
├── objective_text = "Grab tokens before it forgets!"
├── flavor_text  = "It has the memory of a goldfish. A GPU goldfish."
├── fail_lines   = ["Out of context.", "The bot forgot you existed."]
└── style_pack_id = "NEON_DRIFT", music_state = "PEAK", input_mode = RUN
```

Eso es todo. El `MinigameRegistry` lo registra, el arquetipo lo ejecuta, el HUD
se auto-genera. **Coste: un archivo, cero líneas de código.**

**Caso excepcional (mecánica nueva) — se extiende el motor, no el micro-juego:**
crear UN arquetipo genérico en `archetypes/` (reutilizable por futuros
micro-juegos) + su test de slots + doc. Nunca un script `token_rush.gd` con
lógica específica de ese micro-juego. El caso normal solo añade ficha en
`docs/design/minigames.md` (el `.tres` se auto-documenta con comentarios).
