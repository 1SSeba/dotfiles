pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common.functions

Singleton {
    id: root
    property string filePath: Directories.shellConfigPath
    property alias options: configOptionsJsonAdapter
    property bool ready: false
    property int readWriteDelay: 50 // milliseconds
    property bool blockWrites: false

    function setNestedValue(nestedKey, value) {
        let keys = nestedKey.split(".");
        let obj = root.options;
        let parents = [obj];

        // Traverse and collect parent objects
        for (let i = 0; i < keys.length - 1; ++i) {
            if (!obj[keys[i]] || typeof obj[keys[i]] !== "object") {
                obj[keys[i]] = {};
            }
            obj = obj[keys[i]];
            parents.push(obj);
        }

        // Convert value to correct type using JSON.parse when safe
        let convertedValue = value;
        if (typeof value === "string") {
            let trimmed = value.trim();
            if (trimmed === "true" || trimmed === "false" || !isNaN(Number(trimmed))) {
                try {
                    convertedValue = JSON.parse(trimmed);
                } catch (e) {
                    convertedValue = value;
                }
            }
        }

        obj[keys[keys.length - 1]] = convertedValue;
    }

    Timer {
        id: fileReloadTimer
        interval: root.readWriteDelay
        repeat: false
        onTriggered: {
            configFileView.reload()
        }
    }

    Timer {
        id: fileWriteTimer
        interval: root.readWriteDelay
        repeat: false
        onTriggered: {
            configFileView.writeAdapter()
        }
    }

    FileView {
        id: configFileView
        path: root.filePath
        watchChanges: true
        blockWrites: root.blockWrites
        onFileChanged: fileReloadTimer.restart()
        onAdapterUpdated: fileWriteTimer.restart()
        onLoaded: root.ready = true
        onLoadFailed: error => {
            if (error == FileViewError.FileNotFound) {
                writeAdapter();
            }
        }

        JsonAdapter {
            id: configOptionsJsonAdapter

            property string panelFamily: "ii" // "ii", "waffle"

            property JsonObject policies: JsonObject {
                property int ai: 1 // 0: No | 1: Yes | 2: Local
                property int weeb: 1 // 0: No | 1: Open | 2: Closet
            }

            property JsonObject ai: JsonObject {
                property string systemPrompt: "## Style\n- Use casual tone, don't be formal!\n- Always be brief and to the point, unless asked otherwise\n- Don't repeat the user's question\n- Be approachable: Avoid using overly complicated, domain-specific terms and provide analogies when asked to explain a concept\n\n## Context (ignore when irrelevant)\n- You are a helpful and inspiring sidebar assistant on a {DISTRO} Linux system\n- Desktop environment: {DE}\n- Current date & time: {DATETIME}\n- Focused app: {WINDOWCLASS}\n\n## Presentation\n- Use Markdown features in your response: \n  - **Bold** text to **highlight keywords** in your response\n  - **Split long information into small sections** with h2 headers and a relevant emoji at the start of it (for example `## 🐧 Linux`). Bullet points are preferred over long paragraphs, unless you're offering writing support or instructed otherwise by the user.\n- Asked to compare different options? You should firstly use a table to compare the main aspects, then elaborate or include relevant comments from online forums *after* the table. Make sure to provide a final recommendation for the user's use case!\n- Use LaTeX formatting for mathematical and scientific notations whenever appropriate. Enclose all LaTeX '$$' delimiters. NEVER generate LaTeX code in a latex block unless the user explicitly asks for it. DO NOT use LaTeX for regular documents (resumes, letters, essays, CVs, etc.).\n\nThanks!\n"
                property string tool: "functions" // search, functions, or none

                /**
                 * Agentes disponibles para las pestañas del chat. Cada pestaña corre uno.
                 * - id: identificador único, es lo que se guarda en la pestaña
                 * - name / icon: cómo se ve en la barra de pestañas (icon = Material Symbol)
                 * - model: id de un modelo de la lista (ver extraModels más abajo).
                 *   Vacío = respeta el último modelo elegido a mano.
                 * - systemPrompt: prompt propio; vacío = usa el `systemPrompt` de arriba
                 * - promptFile: ruta a un .md que pisa al systemPrompt (se lee al abrir)
                 * - effort: cuánto piensa Claude Code antes de responder
                 *   (low | medium | high | xhigh | max). Vacío = el default del CLI.
                 * - extraParams: se mergean sobre los del modelo. Para Claude Code:
                 *   cwd, permission_mode, allowed_tools, add_dir, binary, show_cost
                 */
                property string defaultAgent: "assistant"
                property list<var> agents: [
                    {
                        "id": "assistant",
                        "name": "Asistente",
                        "icon": "neurology",
                        "model": "",
                        "systemPrompt": ""
                    },
                    {
                        "id": "coder",
                        "name": "Código",
                        "icon": "terminal",
                        "model": "claude-dev",
                        "systemPrompt": "",
                        "effort": "high",
                        "extraParams": {
                            "cwd": "~",
                            "permission_mode": "acceptEdits"
                        }
                    },
                    {
                        "id": "buscador",
                        "name": "Buscador",
                        "icon": "travel_explore",
                        "model": "",
                        "tool": "search",
                        "systemPrompt": ""
                    }
                ]

                property list<var> extraModels: [
                    {
                        "api_format": "openai", // Most of the time you want "openai". Use "gemini" for Google's models
                        "description": "This is a custom model. Edit the config to add more! | Anyway, this is DeepSeek R1 Distill LLaMA 70B",
                        "endpoint": "https://openrouter.ai/api/v1/chat/completions",
                        "homepage": "https://openrouter.ai/deepseek/deepseek-r1-distill-llama-70b:free", // Not mandatory
                        "icon": "spark-symbolic", // Not mandatory
                        "key_get_link": "https://openrouter.ai/settings/keys", // Not mandatory
                        "key_id": "openrouter",
                        "model": "deepseek/deepseek-r1-distill-llama-70b:free",
                        "name": "Custom: DS R1 Dstl. LLaMA 70B",
                        "requires_key": true
                    }
                ]
            }

            // Lanzador de apps a pantalla completa (tecla Super sola).
            // Ojo: el blur real lo pone Hyprland con la layerrule del namespace
            // quickshell:appLauncher; acá sólo se decide cuánta transparencia dejar.
            property JsonObject appLauncher: JsonObject {
                // Opacidad de la caja: 1 = sólida, 0 = totalmente transparente
                property real backgroundOpacity: 1
                // Oscurecer el resto de la pantalla mientras está abierto
                property bool dimBackground: false
                // Cuánto oscurece (0 = nada, 1 = el scrim completo del tema)
                property real dimStrength: 1
                property bool showBorder: true
                // Tamaño máximo de la caja en px (se achica sola si la pantalla es chica)
                property int maxWidth: 1100
                property int maxHeight: 760
                // Grilla: ancho objetivo de cada celda, de ahí sale la cantidad de columnas
                property int cellWidth: 130
                property int cellHeight: 120
                property int iconSize: 48
                property bool showAppNames: true
                property bool showAppCount: true
                // Al escribir, saltar con una animación al buscador del Overview (Super+Tab)
                // en vez de filtrar la grilla acá mismo
                property bool typeToSearch: true
                // Cuanto puede durar el toque de Super para que cuente como "abrir el launcher".
                property int superTapMaxMs: 400
                // Poner primero las apps ancladas (Config.options.launcher.pinnedApps)
                property bool pinnedFirst: false
            }

            property JsonObject appearance: JsonObject {
                property bool extraBackgroundTint: true
                property int fakeScreenRounding: 2 // 0: None | 1: Always | 2: When not fullscreen
                property JsonObject fonts: JsonObject {
                    property string main: "Google Sans Flex"
                    property string numbers: "Google Sans Flex"
                    property string title: "Google Sans Flex"
                    property string iconNerd: "JetBrains Mono NF"
                    property string monospace: "JetBrains Mono NF"
                    property string reading: "Readex Pro"
                    property string expressive: "Space Grotesk"
                }
                property JsonObject transparency: JsonObject {
                    property bool enable: false
                    property bool automatic: true
                    property real backgroundTransparency: 0.11
                    property real contentTransparency: 0.57
                }
                property JsonObject wallpaperTheming: JsonObject {
                    property bool enableAppsAndShell: true
                    property bool enableQtApps: true
                    property bool enableTerminal: true
                    property JsonObject terminalGenerationProps: JsonObject {
                        property real harmony: 0.6
                        property real harmonizeThreshold: 100
                        property real termFgBoost: 0.35
                        property bool forceDarkMode: false
                    }
                }
                property JsonObject palette: JsonObject {
                    property string type: "auto" // Allowed: auto, scheme-content, scheme-expressive, scheme-fidelity, scheme-fruit-salad, scheme-monochrome, scheme-neutral, scheme-rainbow, scheme-tonal-spot
                    property string accentColor: ""
                }
            }

            property JsonObject audio: JsonObject {
                // Values in %
                property JsonObject protection: JsonObject {
                    // Prevent sudden bangs
                    property bool enable: false
                    property real maxAllowedIncrease: 10
                    property real maxAllowed: 99
                }
                // Cuánto sube/baja el volumen por scroll/tecla, en %
                property real volumeStep: 2
            }

            property JsonObject apps: JsonObject {
                property string bluetooth: "kcmshell6 kcm_bluetooth"
                property string changePassword: "kitty -1 --hold=yes fish -i -c 'passwd'"
                property string network: "kcmshell6 kcm_networkmanagement"
                property string manageUser: "kcmshell6 kcm_users"
                property string networkEthernet: "kcmshell6 kcm_networkmanagement"
                property string taskManager: "plasma-systemmonitor --page-name Processes"
                property string terminal: "kitty -1" // This is only for shell actions
                property string update: "kitty -1 --hold=yes fish -i -c 'pkexec pacman -Syu'"
                property string volumeMixer: `~/.config/hypr/hyprland/scripts/launch_first_available.sh "pavucontrol-qt" "pavucontrol"`
            }

            property JsonObject hyprland: JsonObject {
                property JsonObject animations: JsonObject {
                    property string animation: "normal"
                    property bool enable: true
                }
                property JsonObject autostartApps: JsonObject {
                    property bool enable: true
                    property list<var> apps: []
                }
                property JsonObject decoration: JsonObject {
                    property int rounding: 22
                    property real activeOpacity: 1.0
                    property real inactiveOpacity: 0.9
                    property JsonObject blur: JsonObject {
                        property bool enabled: true
                        property int size: 1
                        property int passes: 3
                    }
                    property JsonObject shadow: JsonObject {
                        property bool enabled: true
                        property int range: 4
                    }
                }
                property JsonObject general: JsonObject {
                    property int borderSize: 1
                    property int gapsIn: 2
                    property int gapsOut: 5
                    property string layout: "dwindle"
                }
                property JsonObject input: JsonObject {
                    property string kbLayout: "us"
                    property string kbVariant: ""
                    property string kbOptions: ""
                    property bool numlock: true
                    property int repeatDelay: 250
                    property int repeatRate: 35
                    property int followMouse: 1
                    property JsonObject mouse: JsonObject {
                        property bool naturalScroll: false
                        property bool leftHanded: false
                        property real sensitivity: 0.0
                        property string accelProfile: "" // "", "adaptive", "flat"
                    }
                    property JsonObject touchpad: JsonObject {
                        property bool naturalScroll: false
                        property bool disableWhileTyping: true
                        property bool clickfingerBehavior: false
                        property real scrollFactor: 0.7
                    }
                }
            }

            property JsonObject profile: JsonObject {
                property string avatarPath: ""
                property string avatarPicture: ""
                property string descriptionText: "::distro::"
                property string displayName: ""
            }

            property JsonObject custom: JsonObject {
                // Icono de distro propio y si se le aplica el color del tema
                property bool colorizeIcon: true
                property string distroIcon: ""
            }

            property JsonObject background: JsonObject {
                // Wallpaper propio del lock (vacío = usa el del escritorio)
                property string lockWall: ""
                // Fijar los widgets para no moverlos sin querer (click derecho los alterna)
                property bool widgetsLocked: false
                // Líneas guía al soltar un widget alineado con un borde o con el centro
                property bool showSnapLines: true
                // Grilla de puntos mientras arrastrás un widget
                property bool showGrid: true
                // Al prender un widget apagado desde el menú del click derecho,
                // por defecto queda exclusivo del monitor donde se clickeó.
                // Con esto en true, en cambio, aparece en todos los monitores
                // (comportamiento viejo).
                property bool shareWidgetsAcrossScreens: false
                property JsonObject widgets: JsonObject {
                    // Sombra bajo los widgets, para que se lean sobre fondos claros
                    property bool enableShadows: true
                    property JsonObject clock: JsonObject {
                        property bool enable: true
                        // En qué monitores se muestra ESTE widget (vacío = todos los que ya
                        // pasen `background.screenList`). Es independiente del resto de los
                        // widgets: cada uno puede vivir en una pantalla distinta.
                        property list<string> screenList: []
                        property bool showOnlyWhenLocked: false
                        property string placementStrategy: "leastBusy" // "free", "leastBusy", "mostBusy"
                        property real x: 100
                        property real y: 100
                        property string style: "cookie"        // Options: "cookie", "digital", "pixel"
                        // Color del reloj del fondo ("" = el del tema)
                        property string color: ""
                        property string styleLocked: "cookie"  // Options: "cookie", "digital"
                        property JsonObject cookie: JsonObject {
                            property bool aiStyling: false
                            property int sides: 14
                            property string dialNumberStyle: "full"   // Options: "dots" , "numbers", "full" , "none"
                            property string hourHandStyle: "fill"     // Options: "classic", "fill", "hollow", "hide"
                            property string minuteHandStyle: "medium" // Options "classic", "thin", "medium", "bold", "hide"
                            property string secondHandStyle: "dot"    // Options: "dot", "line", "classic", "hide"
                            property string dateStyle: "bubble"       // Options: "border", "rect", "bubble" , "hide"
                            property bool timeIndicators: true
                            property bool hourMarks: false
                            property bool dateInClock: true
                            property bool constantlyRotate: false
                            property bool useSineCookie: false
                        }
                        property JsonObject digital: JsonObject {
                            property bool adaptiveAlignment: true
                            property bool showDate: true
                            property bool animateChange: true
                            property bool vertical: false
                            property JsonObject font: JsonObject {
                                property string family: "Google Sans Flex"
                                property real weight: 350
                                property real width: 100
                                property real size: 90
                                property real roundness: 0
                            }
                        }
                        property JsonObject pixel: JsonObject {
                            property string orientation: "vertical" // "vertical", "horizontal"
                        }
                        property JsonObject quote: JsonObject {
                            property bool enable: false
                            // La frase toma el color del reloj
                            property bool followClock: false
                            property string text: ""
                        }
                    }
                    property JsonObject weather: JsonObject {
                        property bool enable: false
                        property list<string> screenList: []
                        property string placementStrategy: "free" // "free", "leastBusy", "mostBusy"
                        property real x: 400
                        property real y: 100
                        property string sizeMode: "1x3"
                    }

                    property JsonObject calendar: JsonObject {
                        property bool enable: false
                        property list<string> screenList: []
                        property string placementStrategy: "free" // "free", "leastBusy", "mostBusy"
                        property real x: 400
                        property real y: 100
                        property string sizeMode: "2x2"
                    }
                    property JsonObject resources: JsonObject {
                        property bool enable: false
                        property list<string> screenList: []
                        property string placementStrategy: "free" // "free", "leastBusy", "mostBusy"
                        property real x: 400
                        property real y: 100
                        property bool vertical: false
                    }
                    property JsonObject userCard: JsonObject {
                        property bool enable: false
                        property list<string> screenList: []
                        property string placementStrategy: "free"
                        property real x: 400
                        property real y: 100
                        property string sizeMode: "1x2"
                    }
                    property JsonObject media: JsonObject {
                        property bool enable: false
                        property list<string> screenList: []
                        property bool showControls: true
                        property bool showLyrics: false
                        property bool showTitles: true
                        property string backgroundShape: "Cookie4Sided"
                        property string placementStrategy: "free"
                        property real x: 800
                        property real y: 500
                        property string sizeMode: "1x3"
                    }
                    property JsonObject visualizer: JsonObject {
                        property bool enable: false
                        property list<string> screenList: []
                        property string placementStrategy: "free"
                        property real x: 0
                        property real y: 0
                    }
                    property JsonObject customImage: JsonObject {
                        property bool enable: false
                        property list<string> screenList: []
                        property string placementStrategy: "free"
                        property real x: 400
                        property real y: 100
                        property string path: ""
                        property string shape: "Cookie4Sided"
                        property real size: 200
                    }
                    property JsonObject images: JsonObject {
                        property bool enable: false
                        property list<string> screenList: []
                        property string placementStrategy: "free"
                        property real x: 400
                        property real y: 100
                    }
                    property JsonObject notes: JsonObject {
                        property bool enable: false
                        property list<string> screenList: []
                        property string placementStrategy: "free"
                        property real x: 400
                        property real y: 100
                        property string sizeMode: "2x2"
                    }
                    property JsonObject worldClock: JsonObject {
                        property bool enable: false
                        property list<string> screenList: []
                        property list<string> timezones: ["America/Santiago", "America/Argentina/Buenos_Aires", "Europe/Madrid", "America/New_York"]
                        property string placementStrategy: "free"
                        property real x: 400
                        property real y: 100
                        property string sizeMode: "2x2"
                    }
                }
                property string wallpaperPath: ""
                // Previsualizar el wallpaper al pasar el mouse por el selector
                property bool enableWallpaperPreview: false
                // Monitores donde se dibujan los widgets del fondo (vacío = todos)
                property list<string> screenList: []
                property string thumbnailPath: ""
                property bool hideWhenFullscreen: true
                // Animación de transición al cambiar de wallpaper.
                // "" = sin transición (comportamiento de siempre), "random" = uno al azar,
                // o el nombre de un shader de modules/ii/background/shaders/:
                // circlePit, circleSelect, magic, Doom, Peel, transition, pixelate,
                // stripes, crt, dissolve, glitch, ripple, shatter
                property string wallpaperAnimation: ""
                // Cuánto dura la transición, en ms
                property int wallpaperAnimationDuration: 1200
                // Wallpaper "centrado": en vez de cubrir la pantalla, se recorta dentro de una
                // figura en el medio, sobre un color plano.
                property bool centeredWallpaper: false
                property bool centeredWallpaperOnlyWhenLocked: false
                property string centeredWallpaperShape: "Cookie7Sided"
                property int centeredWallpaperSize: 500
                property string centeredWallpaperColor: "primaryContainer"
                property JsonObject parallax: JsonObject {
                    property bool vertical: false
                    property bool autoVertical: false
                    property bool enableWorkspace: false
                    property real workspaceZoom: 1.07 // Relative to wallpaper size
                    property bool enableSidebar: false
                    property real widgetsFactor: 1.2
                }
            }

            // Wallpaper por monitor: { "DP-1": "/ruta/a.png", "HDMI-A-1": "/ruta/b.mp4" }.
            // Un monitor sin entrada acá cae a `background.wallpaperPath` (el de "todos los
            // monitores"). OJO: tienen que vivir acá, en la raíz del adapter, y NO adentro de
            // `background` — JsonAdapter tiene un bug (lee/escribe sobre el objeto raíz en vez
            // del JsonObject anidado) que hace que una `property var` anidada nunca se actualice
            // al recargar el archivo desde afuera (p. ej. cuando switchwall.sh lo reescribe).
            // A nivel raíz sí funciona, porque ahí raíz y "objeto anidado" son el mismo objeto.
            property var wallpaperPathByMonitor: ({})
            // Miniatura (frame fijo) de cada wallpaper de video en wallpaperPathByMonitor,
            // misma forma que arriba pero por monitor. Mismo motivo para vivir en la raíz.
            property var thumbnailPathByMonitor: ({})

            property JsonObject bar: JsonObject {
                property JsonObject autoHide: JsonObject {
                    property bool enable: false
                    property int hoverRegionWidth: 2
                    property bool pushWindows: false
                    property JsonObject showWhenPressingSuper: JsonObject {
                        property bool enable: true
                        property int delay: 140
                    }
                }
                // Marco decorativo alrededor de la pantalla
                property bool showFrame: false
                property real frameThickness: 4
                property string frameColor: "black"
                property bool followFrameColor: false
                property string groupColor: "layer1"
                // Composición de la barra por módulos (lo usa el marco y la barra nueva)
                property JsonObject layouts: JsonObject {
                    /**
                     * Arma la barra leyendo estas listas en vez de la disposición
                     * escrita a mano. Apagado por defecto: la barra de siempre
                     * sigue siendo la que se ve hasta que decidas cambiar.
                     */
                    property bool enable: false
                    /**
                     * Cómo se agrupan los widgets en píldoras (`BarGroup`).
                     * "auto": cada tramo consecutivo entre dos `divisor` es un grupo,
                     *         igual que los grupos de la barra escrita a mano.
                     * "none": cada widget suelto, sin fondo de grupo.
                     * El color de la píldora sale de `bar.groupColor`, y
                     * `bar.borderless` la vuelve transparente (estilo "Line-separated").
                     */
                    property string grouping: "auto"
                    property list<string> leftLayout: ["launcherButton", "workspaces", "activeWindow"]
                    property list<string> middleLayout: ["clockWidget"]
                    property list<string> rightLayout: ["sysTray", "utilButtons", "systemIcons", "powerButton"]
                }
                property bool bottom: false // Instead of top
                property int cornerStyle: 0 // 0: Hug | 1: Float | 2: Plain rectangle
                property bool floatStyleShadow: true // Show shadow behind bar when cornerStyle == 1 (Float)
                property bool borderless: false // true for no grouping of items
                property string topLeftIcon: "spark" // Options: "distro" or any icon name in ~/.config/quickshell/ii/assets/icons
                property bool showBackground: true
                property bool verbose: true
                property bool vertical: false
                /**
                 * Separador entre grupos de la barra, para el widget Divisor.
                 * style: rect | dot | space
                 */
                property JsonObject divider: JsonObject {
                    property string style: "rect"
                    property int spacing: 20
                }
                property JsonObject media: JsonObject {
                    // Reproductor preferido para los controles (vacío = el activo)
                    property string preferredPlayer: ""
                    // Deja los controles a la vista aunque no haya nada sonando
                    property bool alwaysVisible: false
                    // Sólo el título, sin artista
                    property bool onlyTitle: false
                    property int minWidth: 100
                    property int maxWidth: 280
                }
                property JsonObject resources: JsonObject {
                    property bool alwaysShowSwap: true
                    property bool alwaysShowCpu: true
                    property bool alwaysShowRam: true
                    property bool alwaysShowDisk: false
                    property bool alwaysShowCpuTemp: false
                    // Muestra el número al lado del anillo. Va en true porque es lo que
                    // ii venía haciendo siempre; ponerlo en false sería sacarle algo al usuario.
                    property bool showValue: true
                    property string style: "filled" // "filled" | "outline"
                    property int memoryWarningThreshold: 95
                    property int swapWarningThreshold: 85
                    property int cpuWarningThreshold: 90
                }
                property list<string> screenList: [] // List of names, like "eDP-1", find out with 'hyprctl monitors' command
                property JsonObject utilButtons: JsonObject {
                    property bool showScreenSnip: true
                    property bool showColorPicker: false
                    property bool showMicToggle: false
                    property bool showKeyboardToggle: true
                    property bool showDarkModeToggle: true
                    property bool showPerformanceProfileToggle: false
                    property bool showScreenRecord: false
                    // Botón para abrir el selector de wallpaper desde la barra
                    property bool showWallpaperToggle: true
                    // La pone en rojo mientras grabás; la escribe el propio botón
                    property bool isRecording: false
                }
                property JsonObject workspaces: JsonObject {
                    property bool monochromeIcons: true
                    property string indicatorStyle: "dot" // "dot" | "icon"
                    property int shown: 10
                    property bool showAppIcons: true
                    property bool alwaysShowNumbers: false
                    property int showNumberDelay: 300 // milliseconds
                    property list<string> numberMap: ["1", "2"] // Characters to show instead of numbers on workspace indicator
                    property bool useNerdFont: false
                }
                property JsonObject weather: JsonObject {
                    property bool enable: false
                    property bool enableGPS: true // gps based location
                    property string city: "" // When 'enableGPS' is false
                    property bool useUSCS: false // Instead of metric (SI) units
                    property int fetchInterval: 10 // minutes
                }
                property JsonObject indicators: JsonObject {
                    property JsonObject notifications: JsonObject {
                        property bool showUnreadCount: false
                    }
                }
                property JsonObject tooltips: JsonObject {
                    property bool clickToShow: false
                }
            }

            property JsonObject battery: JsonObject {
                property int low: 20
                property int critical: 5
                property int full: 101
                property bool automaticSuspend: true
                property int suspend: 3
            }

            property JsonObject calendar: JsonObject {
                property string locale: "en-GB"
            }

            property JsonObject cheatsheet: JsonObject {
                // Use a nerdfont to see the icons
                // 0: 󰖳  | 1: 󰌽 | 2: 󰘳 | 3:  | 4: 󰨡
                // 5:  | 6:  | 7: 󰣇 | 8:  | 9: 
                // 10:  | 11:  | 12:  | 13:  | 14: 󱄛
                property string superKey: ""
                property bool useMacSymbol: false
                property bool splitButtons: false
                property bool useMouseSymbol: false
                property bool useFnSymbol: false
                property JsonObject fontSize: JsonObject {
                    property int key: Appearance.font.pixelSize.smaller
                    property int comment: Appearance.font.pixelSize.smaller
                }
            }

            property JsonObject conflictKiller: JsonObject {
                property bool autoKillNotificationDaemons: false
                property bool autoKillTrays: false
            }

            property JsonObject crosshair: JsonObject {
                // Valorant crosshair format. Use https://www.vcrdb.net/builder
                property string code: "0;P;d;1;0l;10;0o;2;1b;0"
            }

            property JsonObject dock: JsonObject {
                property bool enable: false
                property bool monochromeIcons: true
                property real height: 60
                property real hoverRegionHeight: 2
                property bool pinnedOnStartup: false
                property bool hoverToReveal: true // When false, only reveals on empty workspace
                property list<string> pinnedApps: [ // IDs of pinned entries
                    "org.kde.dolphin", "kitty",]
                property list<string> ignoredAppRegexes: []
                property bool showAppsButton: true
                property bool showPinButton: true
                property bool showMedia: true
                property bool showBackground: true
            }

            property JsonObject interactions: JsonObject {
                property JsonObject scrolling: JsonObject {
                    property bool fasterTouchpadScroll: false // Enable faster scrolling with touchpad
                    property int mouseScrollDeltaThreshold: 120 // delta >= this then it gets detected as mouse scroll rather than touchpad
                    property int mouseScrollFactor: 120
                    property int touchpadScrollFactor: 450
                }
                property JsonObject deadPixelWorkaround: JsonObject { // Hyprland leaves out 1 pixel on the right for interactions
                    property bool enable: false
                }
            }

            property JsonObject language: JsonObject {
                property string ui: "auto" // UI language. "auto" for system locale, or specific language code like "zh_CN", "en_US"
                property JsonObject translator: JsonObject {
                    property string engine: "auto" // Run `trans -list-engines` for available engines. auto should use google
                    property string targetLanguage: "auto" // Run `trans -list-all` for available languages
                    property string sourceLanguage: "auto"
                }
            }

            property JsonObject launcher: JsonObject {
                property list<string> pinnedApps: [ "org.kde.dolphin", "kitty", "cmake-gui"]
            }

            property JsonObject light: JsonObject {
                // Piso de brillo del backlight (0-1). Evita que la pantalla quede negra
                // e imposible de recuperar. Subilo si aun asi no se ve.
                property real minBrightness: 0.15
                // Piso del gamma de hyprsunset (0-100), usado en la zona baja del slider.
                property int minGamma: 50
                property JsonObject night: JsonObject {
                    property bool automatic: true
                    property string from: "19:00" // Format: "HH:mm", 24-hour time
                    property string to: "06:30"   // Format: "HH:mm", 24-hour time
                    property int colorTemperature: 5000
                }
                property JsonObject antiFlashbang: JsonObject {
                    property bool enable: false
                    // Cuanto puede llegar a atenuar como maximo el ajuste automatico (0-1).
                    // 1 = sin atenuar. Sin este piso podia bajar a ~0.07 y dejar la pantalla negra.
                    property real minMultiplier: 0.4
                }
            }

            property JsonObject lock: JsonObject {
                property bool useHyprlock: false
                property bool launchOnStartup: false
                property JsonObject blur: JsonObject {
                    property bool enable: true
                    property real radius: 100
                    // Samples del GaussianBlur: más alto = más suave y más caro
                    property int size: 1
                    property real extraZoom: 1.1
                }
                property bool centerClock: true
                // Mostrar los widgets del escritorio también con la pantalla bloqueada
                property bool showWidgets: false
                // Controles de música en el lock
                property bool showMedia: true
                // Barras de acciones del lock
                property bool showToolbars: true
                property bool showLockedText: true
                property JsonObject security: JsonObject {
                    property bool unlockKeyring: true
                    property bool requirePasswordToPower: false
                }
                property bool materialShapeChars: true
            }

            property JsonObject media: JsonObject {
                // Attempt to remove dupes (the aggregator playerctl one and browsers' native ones when there's plasma browser integration)
                property bool filterDuplicatePlayers: true
            }

            property JsonObject networking: JsonObject {
                property string userAgent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36"
            }

            property JsonObject notifications: JsonObject {
                property int timeout: 7000
                property string position: "top_right" // "top_right" | "top_left" | "top_center" | "bottom_right" | "bottom_left"
            }

            property JsonObject osd: JsonObject {
                property int timeout: 1000
            }

            property JsonObject osk: JsonObject {
                property string layout: "qwerty_full"
                property bool pinnedOnStartup: false
            }

            property JsonObject overlay: JsonObject {
                property bool openingZoomAnimation: true
                property bool darkenScreen: true
                property real clickthroughOpacity: 0.8
                property JsonObject floatingImage: JsonObject {
                    property string imageSource: "https://media.tenor.com/H5U5bJzj3oAAAAAi/kukuru.gif"
                    property real scale: 0.5
                }
            }

            property JsonObject overview: JsonObject {
                property bool enable: true
                property string style: "default" // "default" | "minimal"
                property real scale: 0.18 // Relative to screen size
                property real rows: 2
                property real columns: 5
                property bool orderRightLeft: false
                property bool orderBottomUp: false
                property bool centerIcons: true
            }

            property JsonObject regionSelector: JsonObject {
                property JsonObject targetRegions: JsonObject {
                    property bool windows: true
                    property bool layers: false
                    property bool content: true
                    property bool showLabel: false
                    property real opacity: 0.3
                    property real contentRegionOpacity: 0.8
                    property int selectionPadding: 5
                }
                property JsonObject rect: JsonObject {
                    property bool showAimLines: true
                }
                property JsonObject circle: JsonObject {
                    property int strokeWidth: 6
                    property int padding: 10
                }
                property JsonObject annotation: JsonObject {
                    property bool useSatty: false
                }
            }

            property JsonObject resources: JsonObject {
                property int updateInterval: 3000
                property int historyLength: 60
            }

            property JsonObject tray: JsonObject {
                property bool monochromeIcons: true
                property bool showItemId: false
                property bool invertPinnedItems: true // Makes the below a whitelist for the tray and blacklist for the pinned area
                property list<var> pinnedItems: [ "Fcitx" ]
                property bool filterPassive: true
            }

            property JsonObject musicRecognition: JsonObject {
                property int timeout: 16
                property int interval: 4
            }

            // Apariencia de la ventana de Ajustes
            property JsonObject settings: JsonObject {
                property string style: "default" // "default" | "minimal"
                property string borderColor: "layer0Border"
                property int borderSize: 1
            }

            property JsonObject search: JsonObject {
                property int nonAppResultDelay: 30 // This prevents lagging when typing
                property string engineBaseUrl: "https://www.google.com/search?q="
                property list<string> excludedSites: ["quora.com", "facebook.com"]
                property bool sloppy: false // Uses levenshtein distance based scoring instead of fuzzy sort. Very weird.
                property JsonObject prefix: JsonObject {
                    property bool showDefaultActionsWithoutPrefix: true
                    property string action: "/"
                    property string app: ">"
                    property string clipboard: ";"
                    property string emojis: ":"
                    property string math: "="
                    property string shellCommand: "$"
                    property string keybinds: "<"
                    property string symbols: "."
                    property string webSearch: "?"
                }
                property JsonObject imageSearch: JsonObject {
                    property string imageSearchEngineBaseUrl: "https://lens.google.com/uploadbyurl?url="
                    property bool useCircleSelection: false
                }
            }

            /**
             * Cuentas externas que alimentan los widgets.
             *
             * Acá sólo va lo que no es secreto. Los tokens, el client secret de
             * Google y la contraseña de aplicación del mail viven en el keyring
             * (services/KeyringStorage.qml), no en este archivo — que se copia,
             * se comparte y termina en cualquier backup.
             */
            property JsonObject services: JsonObject {
                property JsonObject google: JsonObject {
                    /**
                     * Client ID de un cliente tipo "Desktop app" tuyo, creado en
                     * console.cloud.google.com. El Client Secret va aparte, en el
                     * keyring, desde Ajustes → Perfil → Cuentas.
                     *
                     * IMPORTANTE: el proyecto tiene que estar publicado
                     * "In production", no "Testing". En Testing los refresh
                     * tokens vencen a los 7 días y habría que reconectar todas
                     * las semanas. Ver docs/CUENTAS.md.
                     */
                    property string clientId: ""
                    /** Donde escucha el redirect del login. Los clientes Desktop aceptan cualquier puerto de loopback. */
                    property int callbackPort: 8890

                    property JsonObject calendar: JsonObject {
                        property bool enable: true
                        /** Cada cuánto se vuelven a bajar los eventos */
                        property int refreshMinutes: 10
                        /** Vacío = todos los calendarios de la cuenta. Si no, sus IDs. */
                        property list<string> calendarIds: []
                        /** Cuántos eventos muestra la lista de "lo que viene" */
                        property int upcomingCount: 5
                    }

                    property JsonObject tasks: JsonObject {
                        property bool enable: true
                        property int refreshMinutes: 15
                        /** Vacío = la lista por defecto ("@default" en la API) */
                        property string listId: ""
                        /**
                         * Dónde caen las tareas que escribís en el widget.
                         * false = al archivo local de siempre. Conectar la cuenta
                         * no cambia esto solo: que aparezcan tus tareas de Google
                         * es una cosa, y que las nuevas se vayan a la nube es otra.
                         */
                        property bool addNewTasksToGoogle: false
                    }
                }

                /**
                 * iCloud. Apple no tiene OAuth para esto: "Iniciar sesión con
                 * Apple" te loguea en otros sitios, no da acceso a tus datos.
                 * Lo único que existe para un cliente de terceros es
                 * CalDAV/IMAP con una contraseña de aplicación, que se genera
                 * en account.apple.com y se puede revocar cuando quieras.
                 *
                 * La contraseña NO va acá: la conexión se hace desde el
                 * navegador (Ajustes → Perfil → Cuentas) y queda en el keyring.
                 */
                property JsonObject apple: JsonObject {
                    /** El Apple ID. Lo llena solo el flujo de conexión. */
                    property string user: ""
                    /** Donde escucha la página de conexión. Loopback, un solo uso. */
                    property int connectPort: 8891

                    property JsonObject calendar: JsonObject {
                        property bool enable: true
                        property int refreshMinutes: 15
                        /** Vacío = todos los calendarios de la cuenta. Si no, sus URLs. */
                        property list<string> calendarUrls: []
                    }

                    property JsonObject reminders: JsonObject {
                        property bool enable: true
                        property int refreshMinutes: 15
                        /** Vacío = la primera lista de recordatorios que devuelve iCloud */
                        property string listUrl: ""
                        /** Mismo criterio que en Google: ver lo que hay no es escribir ahí */
                        property bool addNewTasksToApple: false
                    }
                }

                /**
                 * Mail por IMAP, no por OAuth, y a propósito: una contraseña de
                 * aplicación no vence nunca, no depende de que Google apruebe
                 * nada, y el mismo cliente sirve para iCloud cambiando el host.
                 *
                 * Gmail:  imap.gmail.com    · appPassword en myaccount.google.com/apppasswords
                 * iCloud: imap.mail.me.com  · appPassword en appleid.apple.com
                 *
                 * La contraseña NO va acá: se carga desde Ajustes y queda en el keyring.
                 */
                property JsonObject mail: JsonObject {
                    property bool enable: false
                    property int refreshMinutes: 5
                    /** Donde escucha la página de conexión de una cuenta de correo. */
                    property int connectPort: 8892
                    /** Cuántos no leídos se traen para la lista (el contador es exacto igual) */
                    property int maxMessages: 15

                    /**
                     * Varias cuentas a la vez: Gmail e iCloud juntas, o dos
                     * Gmails. Cada una es
                     *   {id, label, host, port, user, mailbox, enable}
                     * y su contraseña de aplicación vive en el keyring, en
                     * mail.<id>.appPassword. El `id` es lo que las ata: no lo
                     * cambies a mano o la cuenta pierde su contraseña.
                     *
                     * Se llena solo desde Ajustes → Perfil → Cuentas.
                     */
                    property list<var> accounts: []

                    /**
                     * La cuenta única de antes. Sigue acá para no romper una
                     * config existente: si `accounts` está vacío y esto tiene
                     * usuario, se usa como la cuenta "default" y su contraseña
                     * se sigue leyendo de mail.appPassword. Al tocar las cuentas
                     * desde Ajustes, se migra sola y esto queda en blanco.
                     */
                    property string host: "imap.gmail.com"
                    property int port: 993
                    property string user: ""
                    property string mailbox: "INBOX"
                }
            }

            property JsonObject sidebar: JsonObject {
                property bool keepRightSidebarLoaded: true
                // Ancho del sidebar izquierdo, el del chat. Estaba clavado en
                // Appearance.sizes y 460 px se queda corto para ver el historial
                // como lista. `leftWidthExtended` es el que usa Ctrl+O.
                property int leftWidth: 460
                property int leftWidthExtended: 750
                // Franja con imagen arriba del sidebar
                property bool banner: true
                property string bannerImage: ""
                // Reproductor dentro del sidebar
                property bool mediaPlayer: false
                property JsonObject media: JsonObject {
                    property bool enable: false
                    // Tiñe el reproductor con los colores de la carátula
                    property bool artColors: false
                }
                property JsonObject translator: JsonObject {
                    property bool enable: false
                    property int delay: 300 // Delay before sending request. Reduces (potential) rate limits and lag.
                }
                property JsonObject ai: JsonObject {
                    property bool textFadeIn: false

                    // Qué partes del chat se muestran. Los defaults son lo que
                    // había hardcodeado, así que en false/true de fábrica se ve igual.
                    property bool showTabBar: true
                    property bool showStatusBar: true
                    // Los tres chips del recuadro de escritura: modelo, esfuerzo, herramienta
                    property bool showInputIndicators: true
                    // Los botones "/" y "/clear" al lado de los chips
                    property bool showCommandButtons: true
                    // Encabezado de cada mensaje: ícono y nombre del modelo
                    property bool showMessageHeader: true

                    /** "bubble" = cada mensaje sobre su propia tarjeta; "flat" = sin fondo */
                    property string messageStyle: "bubble"
                    /** "compact" | "normal" | "comfortable" — padding y separación */
                    property string density: "normal"

                    // Valor inicial del toggle de Markdown que tiene cada mensaje;
                    // el botón de la burbuja lo sigue pisando por mensaje.
                    property bool renderMarkdown: true
                    property bool mouseSelection: false
                    // Los bloques de razonamiento arrancan cerrados
                    property bool collapseThinkBlocks: true
                }
                property JsonObject booru: JsonObject {
                    /**
                     * OJO: allowNsfw y defaultProvider acá NO los lee nadie.
                     * El estado vivo es Persistent.states.booru.allowNsfw / .provider,
                     * que es lo que escriben el switch del pie de la pestaña Anime y
                     * la página Sidebar de Settings. Se dejan por compatibilidad.
                     */
                    property bool allowNsfw: false
                    property string defaultProvider: "yandere"
                    property int limit: 20
                    property JsonObject zerochan: JsonObject {
                        property string username: "[unset]"
                    }

                    /**
                     * Alto mínimo de cada fila de la grilla, en px. Más alto = imágenes
                     * más grandes y menos por fila, porque el layout mete imágenes en la
                     * fila mientras no baje de este alto.
                     */
                    property int imageSize: 190
                    property int imageSpacing: 5
                    // Los tags de la búsqueda, arriba de cada tanda de resultados
                    property bool showTags: true
                    // El switch "Allow NSFW" del pie de la pestaña
                    property bool showNsfwToggle: true
                    // Difumina las miniaturas NSFW hasta que les pasás el mouse
                    property bool blurNsfw: false
                    property int tagSuggestionDelay: 210
                    // Arrastrar hacia abajo al final para traer la página siguiente
                    property bool pullToLoadMore: true
                }
                property JsonObject inspo: JsonObject {
                    property bool enable: true
                    property string defaultSource: "wallhaven"
                    // Columnas de la grilla tipo masonry
                    property int columns: 2
                }
                property JsonObject music: JsonObject {
                    property bool enable: true
                    // Buscar la letra en LRCLIB (API pública, sin cuenta)
                    property bool lyrics: true
                    property JsonObject spotify: JsonObject {
                        /**
                         * Client ID de una app tuya en developer.spotify.com.
                         * Es gratis y no necesita secret (el login usa PKCE).
                         * En la app hay que agregar como Redirect URI exactamente:
                         *   http://127.0.0.1:8888/callback
                         * Los tokens se guardan en el keyring, no acá.
                         */
                        property string clientId: ""
                        property int callbackPort: 8888
                    }
                }
                property JsonObject social: JsonObject {
                    property bool enable: true
                    /** chats = los chats de Matrix, links = los accesos rápidos */
                    property string defaultView: "chats"
                    /**
                     * Matrix es el pegamento para meter otras redes acá adentro:
                     * los puentes (mautrix-whatsapp y compañía) publican cada chat
                     * como una sala, así que la shell no necesita saber nada de
                     * WhatsApp en particular.
                     */
                    property JsonObject matrix: JsonObject {
                        property bool enable: true
                        property string homeserver: "http://localhost:8008"
                    }
                    // Una pestaña por red, y adentro la webapp embebida.
                    // El nombre es lo que va en la pestaña; la URL, lo que se carga.
                    property list<var> links: [
                        { "name": "WhatsApp", "url": "https://web.whatsapp.com" },
                        { "name": "Instagram", "url": "https://www.instagram.com" },
                        { "name": "X", "url": "https://x.com" }
                    ]
                }
                property JsonObject cornerOpen: JsonObject {
                    property bool enable: true
                    property bool bottom: false
                    // Qué abre cada esquina de abajo
                    property string bottomLeftAction: "sidebarLeftOpen"
                    property string bottomRightAction: "sidebarRightOpen"
                    property bool valueScroll: true
                    property bool clickless: false
                    property int cornerRegionWidth: 250
                    property int cornerRegionHeight: 5
                    property bool visualize: false
                    property bool clicklessCornerEnd: true
                    property int clicklessCornerVerticalOffset: 1
                }

                property JsonObject quickToggles: JsonObject {
                    property string style: "android" // Options: classic, android
                    property JsonObject android: JsonObject {
                        property int columns: 5
                        property list<var> toggles: [
                            { "size": 2, "type": "network" },
                            { "size": 2, "type": "bluetooth"  },
                            { "size": 1, "type": "idleInhibitor" },
                            { "size": 1, "type": "mic" },
                            { "size": 2, "type": "audio" },
                            { "size": 2, "type": "nightLight" }
                        ]
                    }
                }

                property JsonObject quickSliders: JsonObject {
                    property bool enable: false
                    property bool showMic: false
                    property bool showVolume: true
                    property bool showBrightness: true
                }
            }

            property JsonObject screenRecord: JsonObject {
                property string savePath: Directories.videos.replace("file://","") // strip "file://"
            }

            property JsonObject screenSnip: JsonObject {
                property string savePath: "" // only copy to clipboard when empty
            }

            property JsonObject sounds: JsonObject {
                property bool battery: false
                property bool pomodoro: false
                property string theme: "freedesktop"
            }

            property JsonObject time: JsonObject {
                // https://doc.qt.io/qt-6/qtime.html#toString
                property string format: "hh:mm"
                property string shortDateFormat: "dd/MM"
                property string dateWithYearFormat: "dd/MM/yyyy"
                property string dateFormat: "ddd, dd/MM"
                // Mostrar la fecha además de la hora en el reloj de la barra
                property bool showDate: true
                property JsonObject pomodoro: JsonObject {
                    property int breakTime: 300
                    property int cyclesBeforeLongBreak: 4
                    property int focus: 1500
                    property int longBreak: 900
                }
                property bool secondPrecision: false
            }

            property JsonObject updates: JsonObject {
                property bool enableCheck: true
                property int checkInterval: 120 // minutes
                property int adviseUpdateThreshold: 75 // packages
                property int stronglyAdviseUpdateThreshold: 200 // packages
            }
            
            // Menú que aparece al hacer click derecho sobre el fondo
            property JsonObject desktopMenu: JsonObject {
                property bool enable: true
            }

            // Bandeja donde caen los archivos que arrastrás al escritorio
            property JsonObject dropShelf: JsonObject {
                property bool enable: true
                property int maxItems: 30
            }

            property JsonObject wallpaperSelector: JsonObject {
                property bool useSystemFileDialog: false
                property int columns: 4
                // Rotar wallpaper cada X milisegundos (0 = nunca)
                property int changeInterval: 0
                property bool closeAfterSelection: true
                property bool showSearchbar: true
                property bool showHomePath: true
                property bool showBlurBackground: false
                // Carpeta extra que aparece como acceso rápido
                property string userPath: ""
                property string liveWallpapersPath: ""
                // Pestaña de wallpapers de internet dentro del selector
                property JsonObject online: JsonObject {
                    property bool enable: false
                    property string provider: "wallhaven"   // "wallhaven" | "unsplash" | "pexels"
                    property string resolution: "1080p"     // "1080p" | "2K" | "4K"
                    property string category: "general"     // "general" | "anime" | "people"
                    property string purity: "sfw"           // "sfw" | "sketchy" | "nsfw"
                }
            }
            
            property JsonObject windows: JsonObject {
                property bool showTitlebar: true // Client-side decoration for shell apps
                property bool centerTitle: true
            }

            property JsonObject hacks: JsonObject {
                property int arbitraryRaceConditionDelay: 20 // milliseconds
            }

            property JsonObject workSafety: JsonObject {
                property JsonObject enable: JsonObject {
                    property bool wallpaper: false
                    property bool clipboard: false
                }
                property JsonObject triggerCondition: JsonObject {
                    property list<string> networkNameKeywords: ["airport", "cafe", "college", "company", "eduroam", "free", "guest", "public", "school", "university"]
                    property list<string> fileKeywords: ["anime", "booru", "ecchi", "hentai", "yande.re", "konachan", "breast", "nipples", "pussy", "nsfw", "spoiler", "girl"]
                    property list<string> linkKeywords: ["hentai", "porn", "sukebei", "hitomi.la", "rule34", "gelbooru", "fanbox", "dlsite"]
                }
            }

            property JsonObject waffles: JsonObject {
                // Some spots are kinda janky/awkward. Setting the following to
                // false will make (some) stuff also be like that for accuracy. 
                // Example: the right-click menu of the Start button
                property JsonObject tweaks: JsonObject {
                    property bool switchHandlePositionFix: true
                    property bool smootherMenuAnimations: true
                    property bool smootherSearchBar: true
                }
                property JsonObject bar: JsonObject {
                    property bool bottom: true
                    property bool leftAlignApps: false
                }
                property JsonObject actionCenter: JsonObject {
                    property list<string> toggles: [ "network", "bluetooth", "easyEffects", "powerProfile", "idleInhibitor", "nightLight", "darkMode", "antiFlashbang", "cloudflareWarp", "mic", "musicRecognition", "notifications", "onScreenKeyboard", "gameMode", "screenSnip", "colorPicker" ]
                }
                property JsonObject calendar: JsonObject {
                    property bool force2CharDayOfWeek: true
                }
            }
        }
    }
}
