# 🌟 VirtuXperience

> **Plataforma lúdico-educativa 2D Top-Down desarrollada en Godot Engine 4** orientada a la evaluación formativa y el entrenamiento de competencias cognitivas, ciudadanas y transversales de educación superior.

---

## 🧭 ¿Qué es VirtuXperience?

**VirtuXperience** transforma la preparación y evaluación académica tradicional en una aventura de rol y exploración en 2D. 

El jugador encarna a un estudiante-explorador que llega al **Campus Nexus**, un espacio central interdimensional donde el conocimiento universal se ha dispersado. A través de portales de teletransporte, debe viajar a **6 Biomas Temáticos**, interactuar con estaciones tecnológicas o altares de desafío, responder preguntas de razonamiento contextualizado y recuperar los **6 Fragmentos del Nexo** para restaurar el Altar Central y obtener su diagnóstico formativo integral.

---

## 🗺️ Los 6 Biomas Temáticos y sus Ejes Formativos

Cada bioma del juego representa un eje fundamental del pensamiento crítico y las competencias universitarias (alineadas con estándares internacionales y pruebas Saber Pro):

| Icono | Bioma | Eje de Pensamiento | Estación Interactiva | Temática y Enfoque |
| :---: | :--- | :--- | :--- | :--- |
| 🧠 | **NeuroMath** | *Pensamiento Lógico y Numérico* | Terminal Cuántica | Modelado cuantitativo, análisis de funciones, probabilidades, interpretación de gráficos y lógica formal. |
| 📖 | **ComunicArte** | *Competencia Léxica y Lectura Crítica* | Atriles Tipográficos | Comprensión lectora, coherencia textual, morfología, etimología e identificación de premisas y falacias. |
| 📊 | **Gerencia+** | *Pensamiento Estratégico y Organizacional* | Mesa de Directorio | Toma de decisiones bajo incertidumbre, priorización de recursos, liderazgo ágil y gestión operativa. |
| 💡 | **ActivaTuIdea** | *Innovación y Modelado de Emprendimiento* | Banco de Prototipado | Metodologías ágiles (Design Thinking, Lean), detección de oportunidades de mercado y diseño de modelos de negocio. |
| 🤝 | **LatidoSocial** | *Compromiso Ético y Responsabilidad Social* | Pozo Comunitario | Resolución de dilemas éticos, empatía, sostenibilidad ambiental e impacto comunitario positivo. |
| 🏛️ | **VoxCivitas** | *Ciudadanía Activa y Habilidades para la Vida* | Tribuna del Ágora | Constitución, derechos fundamentales, mecanismos de participación democrática y resolución no violenta de conflictos. |

---

## 🏗️ Arquitectura Técnica del Software

El proyecto fue diseñado bajo los principios de **modularidad, desacoplamiento de datos y arquitectura orientada a eventos (Signal-Driven)** en GDScript 2.0.

```
                  ┌───────────────────────────────┐
                  │    GameState (Autoload)       │
                  │  - Estado global (XP / Nivel) │
                  │  - Fragmentos e Insignias     │
                  │  - Persistencia Atómica JSON  │
                  └──────▲─────────────────▲──────┘
                         │                 │
            (Escucha/Emite señales)        │ (Actualiza progreso)
                         │                 │
    ┌────────────────────▼─────┐     ┌─────┴──────────────────┐
    │     HUD y Modales UI     │     │     MinigameBase       │
    │  - Barra de XP reactiva  │     │  - Lógica de preguntas │
    │  - DialogModal (NPCs)    │     │  - Racha y Dificultad  │
    │  - Badges / Cosmetics    │     │  - Retroalimentación   │
    └──────────────────────────┘     └─────▲──────────────────┘
                                           │ (Carga preguntas)
    ┌──────────────────────────┐     ┌─────┴──────────────────┐
    │   CampusHub (Mundo)      │     │    BiomeDataLoader     │
    │  - Portales de bioma     │     │  - Lectura data/*.json │
    │  - GuardianNPC / Altar   │     └────────────────────────┘
    └──────────▲───────────────┘
               │
    ┌──────────┴───────────────┐
    │  SceneManager (Autoload) │
    │  - Transición de escenas │
    │  - Memoria de Spawn      │
    └──────────────────────────┘
```

---

## 🧩 Componentes Principales Explicados de Forma Sencilla

### 1. `GameState.gd` *(El Cerebro y Memoria Central)*
Es un **Singleton / Autoload** que siempre está activo en segundo plano:
* **Progreso del Jugador:** Lleva la cuenta de los puntos de experiencia (XP), el nivel del personaje (`1 + floor(XP/100)`), y el XP acumulado por cada eje formativo individual.
* **Control de Fragmentos:** Garantiza que existan exactamente 6 fragmentos canónicos (evitando duplicados o inconsistencias al sincronizar "LatidoSocial" y misiones).
* **Coleccionables y Logros:** Administra qué skins/cosméticos e insignias se han desbloqueado.
* **Persistencia Atómica:** Guarda la partida de forma segura en `user://virtuxperience_save.json` cada vez que ocurre un avance importante. Si el juego se cierra de imprevisto, no se pierde progreso.

### 2. `SceneManager.gd` *(El Navegador de Escenas)*
Se encarga de las transiciones entre mundos sin perder el rastro del jugador:
* Permite viajar del Campus central a un Laboratorio o Minijuego, **recordando la posición exacta previa** del jugador para que al volver no reaparezca forzosamente al inicio del mapa.
* Modifica de manera dinámica el nombre de la zona actual para que la interfaz muestre en qué lugar te encuentras.

### 3. La Base de los Biomas: `BiomeLab`, `BiomeTerminal` y `MinigameBase`
Para no duplicar código en los 6 mundos, se implementó una jerarquía reutilizable:
* **`BiomeLab.gd`:** Es el molde común de cada laboratorio. Controla las zonas de teletransporte hacia el Hub y genera al jugador en el punto de inicio correspondiente.
* **`BiomeTerminal.gd`:** Es el objeto interactivo de cada laboratorio (la consola cuántica, el atril o la mesa). Cuando el jugador se aproxima y pulsa interactuar (`E` / `Espacio`), abre el minijuego.
* **`MinigameBase.gd`:** Maneja toda la lógica del desafío formativo:
  - Carga aleatoria de desafíos desde un archivo JSON.
  - Temporizador de respuesta.
  - Gestión de opciones múltiples y retroalimentación inmediata (explicación pedagógica de por qué una respuesta es correcta o incorrecta).
  - Cálculo de rachas de aciertos y entrega de fragmentos al completar la meta.
* **`BiomeDataLoader.gd`:** Un cargador estático que valida y lee los datos limpios en `data/` sin atar las preguntas al código fuente del juego.

### 4. `Player.tscn` *(El Personaje Jugador)*
* **Control Físico:** Implementado mediante `CharacterBody2D` con aceleración suave, desaceleración natural (fricción) y colisiones pulidas para navegación en cuadrícula o libre.
* **Sistema de Interacción:** Utiliza un detector de proximidad (`Area2D`) que emite señales hacia terminales, NPCs o puertas cercanas.
* **Skins Dinámicas:** Soporta cambio de apariencia en caliente (skin azul, roja, verde, etc.) aplicando spritesheets y paletas desde el vestidor.

### 5. `CampusHub.tscn` *(El Centro del Mundo)*
* Diseñado con un sistema de capas de `TileMapLayer` (suelo base, caminos, muros y adornos decorativos).
* Contiene los **6 Portales Interdimensionales** (`BiomePortal.tscn`) que conducen a cada laboratorio.
* Alberga al **Guardián Nexus** (`GuardianNPC.tscn`) que da la bienvenida y explica la misión mediante diálogos interactivos, y al **Altar Nexus** (`NexusAltar.tscn`), que reacciona e ilumina pedestales a medida que consigues fragmentos.

### 6. Sistema de Interfaz de Usuario (UI) Reactiva
* **`HUD.tscn`:** Barra superior permanente que se actualiza automáticamente al escuchar señales de `GameState` (muestra nivel, XP animada, 6 íconos de fragmentos y botón de menú).
* **`DialogModal.tscn`:** Ventana emergente con estilo pixel art que escribe texto poco a poco y presenta opciones de respuesta al hablar con personajes.
* **`BadgesModal.tscn`:** Álbum de trofeos donde el jugador revisa qué insignias ha conquistado y cuáles le faltan.
* **`CosmeticsModal.tscn`:** Vestidor virtual donde se seleccionan y equipan los aspectos desbloqueados.
* **`FinalSummaryModal.tscn`:** Informe final que se activa al completar los 6 biomas; desglosa los puntos fuertes del estudiante en cada uno de los 6 ejes formativos.

---

## 📂 Organización de Carpetas

```text
virtuxperience/
├── assets/                     # Sprites, spritesheets de personajes, tilesets, fuentes y audios
├── autoload/                   # Singletons globales (GameState.gd, SceneManager.gd)
├── data/                       # Archivos JSON con el banco de preguntas por bioma y cosméticos
│   ├── activatuidea.json
│   ├── comunicarte.json
│   ├── cosmetics_catalog.json
│   ├── gerencia.json
│   ├── latidosocial.json
│   ├── neuromath.json
│   └── voxcivitas.json
├── resources/                  # Temas visuales de interfaz (.tres) y recursos de TileSet
├── scenes/
│   ├── biomes/                 # Escenas y scripts de los 6 biomas temáticos
│   │   ├── common/             # Clases base compartidas (BiomeLab, MinigameBase, Terminal)
│   │   ├── neuromath/
│   │   ├── comunicarte/
│   │   ├── gerencia/
│   │   ├── activatuidea/
│   │   ├── latidosocial/
│   │   └── voxcivitas/
│   ├── hub/                    # Campus Nexus (mundo central), portales, NPCs y altar
│   ├── player/                 # Controlador del jugador (Player.tscn / Player.gd)
│   └── ui/                     # HUD, diálogos, guardarropa, insignias y resumen final
└── project.godot               # Configuración central del motor Godot 4
```

---

## 🎮 Controles del Juego

| Acción | Teclado | Mando (Gamepad) |
| :--- | :--- | :--- |
| **Moverse** | `W`, `A`, `S`, `D` o `Flechas` | `Stick izquierdo` / `D-Pad` |
| **Interactuar** | `E` o `Barra Espaciadora` | `Botón A` / `Cruz (X)` |
| **Abrir Menú / Pausa** | `Escape` | `Botón Start / Options` |

---

## 🚀 Cómo Ejecutar el Proyecto

1. **Requisitos:** Descargar e instalar **Godot Engine 4.x** (versión Standard).
2. **Abrir el proyecto:**
   - Abre Godot y selecciona el botón **Importar**.
   - Navega hasta la carpeta del repositorio (`c:\Users\Steven\Desktop\Projects\virtuxperience`) y selecciona el archivo `project.godot`.
   - Haz clic en **Importar y Editar**.
3. **Probar el juego:** Presiona `F5` o el botón de **Play (▶)** en la esquina superior derecha del editor para iniciar directamente en el Campus Nexus.
