# AGENTS.md — Directivas para Agentes

> Este archivo gobierna CÓMO trabaja cualquier agente (IA o humano) en este
> repo. Léelo junto a `scaffold.md` (el QUÉ/PORQUÉ). Si hay conflicto entre
> ambos, `scaffold.md` gana en arquitectura y contratos; este archivo gana en
> proceso y disciplina.

> **Idioma del juego:** todo contenido visible al jugador (nombres, HUD,
> objetivos, flavor text, mensajes de fallo, VO) va en **inglés**. Los docs de
> equipo y los identificadores internos siguen las convenciones de
> `scaffold.md` §16.

---

## 0. ANTES DE ESCRIBIR UNA LÍNEA

1. **Lee `scaffold.md` completo.** Sin excepciones. Es el brief maestro.
2. **Localiza tu tarea en el roadmap** (§14) y respeta el gate de la fase.
3. **No inventes contratos.** Todo sistema de gameplay es un contrato (§7).
   Si tu tarea necesita un contrato nuevo o un cambio a uno existente:
   - documéntalo en `docs/architecture/contracts.md`,
   - actualiza `scaffold.md` §7,
   - añade/ajusta el test GUT del contrato,
   - y dilo explícitamente en tu PR/commit.
4. **Determinismo.** Toda lógica con aleatoriedad (ruleta, spawns, micro-juegos)
   debe ser reproducible con `SeededRNG` y una semilla fija. Tests primero.
5. **Abstracción primero (§8.0).** Un micro-juego es DATOS, no código. Si tu
   tarea te lleva a escribir lógica específica de un micro-juego, PARA: la
   abstracción está incompleta. Extiende el arquetipo o el slot, no el
   micro-juego. El gate de la Fase 4.5 lo verifica.

---

## 1. REGLAS DURAS (violarlas = rechazo de la entrega)

### 1.1 Aislamiento de sistemas
- **Ningún micro-juego** referencia a `MatchManager`, `ScoreDirector`,
  `StyleDirector`, etc. directamente. Usa el `MinigameContext` inyectado.
- **Ningún autoload** referencia a otro autoload directamente: usa
  `GameServices.get(&"nombre")` o `EventBus`.
- **Nada de gameplay frame-a-frame por señales** si el orden importa; ahí la
  llamada es directa. Las señales son para desacoplamiento de eventos.

### 1.2 Contratos
- `Minigame`, `MinigameContext`, `MinigameMetadata`, `MinigameResult`,
  `StylePack`, `StylePostFX`, `ImpactFrame` son **estables**. Cambiarlos
  requiere actualizar doc + tests + scaffold, y decirlo en el commit.
- Un micro-juego termina SOLO vía `finished(result)` o aborto del director.
- Todo micro-juego se ejecuta con el mismo ciclo: `setup → start → update →
  on_input → teardown`. No uses `_process`/`_physics_process` directos salvo
  que el arquetipo lo documente.

### 1.3 Datos, no magia
- **Cero números de balance hardcodeados** en gameplay. Todo tuning vive en
  `.tres` (metadata de micro-juego, style packs, impact frames, configs).
- Si ajustas un valor "porque se sentía bien", va a un `.tres` con comentario.

### 1.4 Limpieza
- Tras `teardown()` de un micro-juego: **ni una entidad huérfana**, ni estado
  global sucio, ni timers colgando. El mundo queda como se encontró.
- Devuelve objetos al pool; nunca `queue_free()` en caliente sin necesidad.

### 1.5 Assets
- **Nunca edites `.glb`, `.wav` mezclados ni assets exportados a mano.** La
  fuente es Blender/el DAW; se re-exporta. Godot solo importa.
- Fuentes en `assets/art/blender/`, exports en `assets/art/models/`.

### 1.6 No rompas el build
- Cada entrega debe importar/compilar sin warnings nuevos.
- Si el proyecto no compila, tu tarea no está terminada.

### 1.8 Abstracción (regla dura de arquitectura)
- **Ningún `if minigame_id == "..."` / switch por ID en gameplay.** La variedad
  de micro-juegos vive en los **slots** (`SpawnRecipe`, `ObjectiveRecipe`,
  `HUDRecipe`), no en código condicional.
- Un micro-juego nuevo mecánicamente cubierto es **un `.tres`, cero código**.
- Si hace falta código: es un arquetipo nuevo (motor genérico reutilizable) o
  la extensión de un slot — nunca un script con lógica de un solo micro-juego.
- Toda la UI de objetivo se auto-genera desde `HUDRecipe`. **Cero widgets
  ad-hoc** por micro-juego (biblioteca fija de 5 widgets, §13.1).

### 1.9 Idioma y tono del contenido (regla dura)
- **Todo texto del jugador en inglés** (nombres, HUD, objetivos, flavor text,
  fail lines, VO). No mezcles español en strings del juego.
- El tono sigue la guía de voz de `scaffold.md` §2: corto, rápido,
  auto-consciente, humor amigable. El locutor es sarcástico pero NUNCA cruel.
- **Sensibilidad:** humor absurdo, sin groserías fuertes, sin violencia
  gráfica, sin chistes dirigidos a grupos de personas. Los chistes apuntan a
  *situaciones* (burocracia tech, commute, ansiedad de notificaciones).

---

## 2. FLUJO DE TRABAJO DE UNA TAREA

1. **Entiende** el contrato/arquitectura implicada (scaffold §6, §7).
2. **Escribe el test primero** si la tarea tiene lógica testeable
   (score, ruleta, RNG, timers, contratos de arquetipo). RED antes de GREEN.
3. **Implementa** el mínimo que satisface el contrato.
4. **Verifica** con el gate de la fase del roadmap (§14) y, si aplica, con los
   gates de DoD (§15).
5. **Documenta**: ficha en `docs/design/minigames.md` (si es micro-juego),
   comentario de contrato en el código, y nota en el commit si tocaste un
   contrato.
6. **Perfila** si tu tarea toca gameplay de frame: 60fps estables, presupuestos
   de §15.

---

## 3. IMPLEMENTAR UN MICRO-JUEGO (checklist)

- [ ] Existe arquetipo (§8.1) que cubra la mecánica? → si sí, solo `.tres`.
- [ ] Si no: crear/extender arquetipo en `src/minigames/archetypes/` + test
      (motor genérico reutilizable, NO un script de micro-juego).
- [ ] Definir `MinigameMetadata.tres` llenando los slots:
      - `spawn_recipe`: entity_scene, count, pattern, motion, speed.
      - `objective_recipe`: kind, target, tolerance, fail_on, time_bonus.
      - `hud_recipe`: primary_widget (de los 5 genéricos), icon, color_hint.
      - `input_mode`, `style_pack_id`, `music_state`.
- [ ] Contenido en inglés: `objective_text`, `flavor_text` (chiste 1 línea),
      `fail_lines` (2-3 variaciones cómicas), `theme_tag` (AI/LIFE/HYBRID).
- [ ] El chiste funciona en <2s de lectura y refuerza la legibilidad.
- [ ] Condición de victoria Y de fracaso claras, legibles en HUD.
- [ ] Al menos 3 picos de impacto (inicio / aciertos / final) con preset
      `ImpactFrame` (no números hardcodeados).
- [ ] Jugable con teclado, ratón Y mando (ver `input_mode`).
- [ ] Determinismo con semilla fija (test GUT).
- [ ] Teardown limpio (pool, timers, entidades).
- [ ] **CERO código de gameplay nuevo** (si lo hay, se extendió arquetipo/slot
      y quedó documentado — ver §1.8).
- [ ] Ficha en `docs/design/minigames.md` (con flavor text y fail lines).
- [ ] Pasa los gates de DoD (§15), incluidos abstracción (§8.0), UI (§13.1)
      e idioma/tono (§1.9).

---

## 4. IMPLEMENTAR UN STYLE PACK (checklist)

- [ ] `StylePack.tres` en `src/styles/packs/` con paleta, materiales, postfx,
      música, tema HUD, transición.
- [ ] Reversible: al terminar el micro-juego vuelve al estilo base sin
      artefactos.
- [ ] Coordina: mundo (materiales/uniformes), postfx, cámara (FOV/offset),
      música (music_state), HUD (tema).
- [ ] Preferente `SHADER_UNIFORM` (barato, sin pop); `FULL_SWAP` solo si el
      cambio de look es drástico.
- [ ] Documentado en `docs/design/art-bible.md`.

---

## 5. JUICE Y AUDIO

- Todo impacto pasa por `ImpactDirector` con un preset `.tres`
  (`ImpactFrame`). No insertes hitstop/shake/flash ad-hoc en gameplay.
- La música es gobernada por `MusicDirector` (estados + intensidad). No
  reproduzcas música fuera de él.
- SFX siempre por `SFXLibrary`/`SFXPlayer` (pool, prioridad, límite de voces).
- Locutor (VO) solo por `VoiceDirector`, solo en eventos de estado del match
  (ruleta, GO, combo, tiempo, rank, fallos). Respeta el catálogo de
  `voice_lines.gd`; no satures (cooldown por evento, nunca dos voces a la vez).

---

## 6. TESTS (GUT)

- Lógica pura (score, combo, RNG determinista, timers, registry) → tests
  unitarios en `tests/unit/`.
- Flujo de match completo (boot → countdown → freeroam → roulette →
  micro-juego → results) → integración headless en `tests/integration/`.
- Cada contrato (arquetipo) tiene un test de ciclo de vida.
- Los tests son rápidos y deterministas; sin dependencias de GPU si se puede.

---

## 7. RENDIMIENTO Y PRESUPUESTOS

Antes de dar por terminada una tarea de gameplay/visual:
- 60fps estables en hardware target (verificado con el monitor de Godot).
- < 400 draw calls, < 250k tris/frame, < 32 voces SFX simultáneas.
- Sin picos de GC por `queue_free()` masivo (usa pooling).
- Texturas y audio dentro de presupuesto (ver §15).
- Si no cumple: perfila, optimiza (LOD, instancing, pooling, materials
  compartidos) y vuélvelo a medir.

---

## 8. ACCESIBILIDAD (parte del DoD, no un extra)

Todo contenido debe funcionar con:
- Entrada remapeable (teclado / ratón / mando).
- Intensidad de shake ajustable y opción de desactivar flashes.
- Indicadores de daltonismo para objetivos/peligros.
- Señales visuales además de voz (callouts subtitulados).
- Velocidades de texto y legibilidad HUD.

---

## 9. GIT Y COMUNICACIÓN

- Conventional Commits: `feat:`, `fix:`, `docs:`, `test:`, `refactor:`,
  `perf:`, `art:`, `chore:`.
- Un commit = un cambio cohesionado. No mezcles refactor con feature.
- Si tocaste un contrato: dilo en el cuerpo del commit y actualiza
  `docs/architecture/contracts.md` + `scaffold.md` §7.
- Git LFS para assets binarios (`.blend`, `.glb`, `.wav` grandes, texturas).
- No subas assets generados/provisionales que ensucien el repo.

---

## 10. CUANDO TENGAS DUDAS

- **Arquitectura/contrato** → `scaffold.md` §6/§7. Sigue el contrato; no
  improvises uno paralelo.
- **Mecánica de un micro-juego** → `docs/design/minigames.md`.
- **Tono/humor de un texto** → guía de voz de `scaffold.md` §2.
- **Look/estilo** → `docs/design/art-bible.md` + `src/styles/packs/`.
- **Audio** → `docs/design/audio-design.md`.
- **Balance** → los `.tres` son la fuente; no toques código para rebalancear.
- **Si nada de lo anterior responde tu duda y la decisión es irreversible**
  (cambia un contrato, un pipeline, una plataforma): **pregunta antes de
  implementar.**

---

## 11. DEFINICIÓN DE "TERMINADO"

Una tarea está terminada cuando:
1. El código importa/compila sin warnings nuevos.
2. Los tests relevantes pasan (y los nuevos están escritos).
3. Pasa los gates de DoD (§15) que apliquen a su tipo.
4. Cumple las reglas duras de §1 (aislamiento, contratos, datos, limpieza,
   abstracción, idioma/tono).
5. Está documentada (docs/ + comentarios de contrato).
6. Rendimiento verificado (si toca frame/perf).
7. Accesibilidad cubierta (§8).

**Test de abstracción (para tareas de micro-juego):** el micro-juego funciona
siendo solo su `.tres`, sin código de gameplay nuevo ni widgets de UI ad-hoc.
Si no cumple esto, no está terminado — la abstracción se arregla primero.

Si no puedes cumplir algo, **dilo explícitamente** en la entrega con el motivo
y el plan para resolverlo. No entregues trabajo "casi terminado" en silencio.
