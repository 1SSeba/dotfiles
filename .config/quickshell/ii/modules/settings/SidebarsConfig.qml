import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/**
 * Ajustes de los sidebars (izquierdo y derecho): comportamiento (quick
 * toggles, sliders, esquinas calientes) y el contenido de cada pestaña del
 * sidebar izquierdo (Intelligence, Traductor, Inspo, Música, Social, Anime).
 */

ContentPage {
    id: page
    forceWidth: true

    /**
     * Acciones que puede disparar una esquina caliente. Vive acá y no en GlobalStates
     * porque este fork todavía no la tiene centralizada; los valores son los nombres de
     * las propiedades de GlobalStates, así quien las consuma solo hace toggle por nombre.
     */
    readonly property var hotCornerActions: [
        { displayName: Translation.tr("Nada"), value: "none" },
        { displayName: Translation.tr("Sidebar izquierdo"), value: "sidebarLeftOpen" },
        { displayName: Translation.tr("Sidebar derecho"), value: "sidebarRightOpen" },
        { displayName: Translation.tr("Overview"), value: "overviewOpen" },
        { displayName: Translation.tr("Selector de wallpaper"), value: "wallpaperSelectorOpen" },
        { displayName: Translation.tr("Controles de música"), value: "mediaControlsOpen" },
        { displayName: Translation.tr("Overlay"), value: "overlayOpen" },
        { displayName: Translation.tr("Captura de región"), value: "regionSelectorOpen" },
        { displayName: Translation.tr("Traductor de pantalla"), value: "screenTranslatorOpen" },
        { displayName: Translation.tr("Teclado en pantalla"), value: "oskOpen" },
        { displayName: Translation.tr("Menú de sesión"), value: "sessionOpen" },
    ]

    // Los providers y las fuentes los publican los propios servicios, así que
    // los combos se arman solos y no se desincronizan si cambia la lista.
    readonly property var booruProviderOptions: Booru.providerList.map(provider => ({
        displayName: Booru.providers[provider]?.name ?? provider,
        value: provider
    }))
    readonly property var inspoSourceOptions: InspoService.sourceList.map(source => ({
        displayName: InspoService.sources[source]?.name ?? source,
        value: source
    }))

    ContentSection {
        icon: "side_navigation"
        title: Translation.tr("Sidebars")
        // Comportamiento del sidebar derecho. El contenido del sidebar izquierdo
        // (pestañas, AI, traductor, inspo, música, social, anime) está más abajo
        // en esta misma página.

        // Franja con imagen arriba del sidebar derecho
        ConfigSwitch {
            buttonIcon: "planner_banner_ad_pt"
            text: Translation.tr("Banner")
            checked: Config.options.sidebar.banner
            onCheckedChanged: {
                Config.options.sidebar.banner = checked;
            }
        }

        // Vacío = la imagen que viene por defecto
        ConfigTextArea {
            id: bannerImageField
            Layout.fillWidth: true
            enabled: Config.options.sidebar.banner
            buttonIcon: "imagesmode"
            text: Translation.tr("Imagen del banner")
            placeholderText: Translation.tr("Ruta (vacío = la de siempre)")
            fieldWidth: 300
            value: Config.options.sidebar.bannerImage ?? ""
            onValueChanged: {
                bannerImageDebounce.restart();
            }
            // Escribir en cada tecla haría que Config guarde el archivo decenas de veces
            Timer {
                id: bannerImageDebounce
                interval: 1000
                onTriggered: {
                    Config.options.sidebar.bannerImage = bannerImageField.value;
                }
            }
        }

        ConfigSwitch {
            buttonIcon: "music_note"
            text: Translation.tr("Reproductor en el sidebar derecho")
            checked: Config.options.sidebar.mediaPlayer
            onCheckedChanged: {
                Config.options.sidebar.mediaPlayer = checked;
            }
        }

        ConfigSwitch {
            buttonIcon: "memory"
            text: Translation.tr('Keep right sidebar loaded')
            checked: Config.options.sidebar.keepRightSidebarLoaded
            onCheckedChanged: {
                Config.options.sidebar.keepRightSidebarLoaded = checked;
            }
            StyledToolTip {
                text: Translation.tr("When enabled keeps the content of the right sidebar loaded to reduce the delay when opening,\nat the cost of around 15MB of consistent RAM usage. Delay significance depends on your system's performance.\nUsing a custom kernel like linux-cachyos might help")
            }
        }

        ContentSubsection {
            title: Translation.tr("Quick toggles")
            
            ConfigSelectionArray {
                Layout.fillWidth: false
                currentValue: Config.options.sidebar.quickToggles.style
                onSelected: newValue => {
                    Config.options.sidebar.quickToggles.style = newValue;
                }
                options: [
                    {
                        displayName: Translation.tr("Classic"),
                        icon: "password_2",
                        value: "classic"
                    },
                    {
                        displayName: Translation.tr("Android"),
                        icon: "action_key",
                        value: "android"
                    }
                ]
            }

            ConfigSpinBox {
                enabled: Config.options.sidebar.quickToggles.style === "android"
                icon: "splitscreen_left"
                text: Translation.tr("Columns")
                value: Config.options.sidebar.quickToggles.android.columns
                from: 1
                to: 8
                stepSize: 1
                onValueChanged: {
                    Config.options.sidebar.quickToggles.android.columns = value;
                }
            }
        }

        ContentSubsection {
            title: Translation.tr("Sliders")

            ConfigSwitch {
                buttonIcon: "check"
                text: Translation.tr("Enable")
                checked: Config.options.sidebar.quickSliders.enable
                onCheckedChanged: {
                    Config.options.sidebar.quickSliders.enable = checked;
                }
            }
            
            ConfigSwitch {
                buttonIcon: "brightness_6"
                text: Translation.tr("Brightness")
                enabled: Config.options.sidebar.quickSliders.enable
                checked: Config.options.sidebar.quickSliders.showBrightness
                onCheckedChanged: {
                    Config.options.sidebar.quickSliders.showBrightness = checked;
                }
            }

            ConfigSwitch {
                buttonIcon: "volume_up"
                text: Translation.tr("Volume")
                enabled: Config.options.sidebar.quickSliders.enable
                checked: Config.options.sidebar.quickSliders.showVolume
                onCheckedChanged: {
                    Config.options.sidebar.quickSliders.showVolume = checked;
                }
            }

            ConfigSwitch {
                buttonIcon: "mic"
                text: Translation.tr("Microphone")
                enabled: Config.options.sidebar.quickSliders.enable
                checked: Config.options.sidebar.quickSliders.showMic
                onCheckedChanged: {
                    Config.options.sidebar.quickSliders.showMic = checked;
                }
            }
        }

        ContentSubsection {
            title: Translation.tr("Corner open")
            tooltip: Translation.tr("Allows you to open sidebars by clicking or hovering screen corners regardless of bar position")
            ConfigRow {
                uniform: true
                ConfigSwitch {
                    buttonIcon: "check"
                    text: Translation.tr("Enable")
                    checked: Config.options.sidebar.cornerOpen.enable
                    onCheckedChanged: {
                        Config.options.sidebar.cornerOpen.enable = checked;
                    }
                }
            }
            ConfigSwitch {
                buttonIcon: "highlight_mouse_cursor"
                text: Translation.tr("Hover to trigger")
                checked: Config.options.sidebar.cornerOpen.clickless
                onCheckedChanged: {
                    Config.options.sidebar.cornerOpen.clickless = checked;
                }

                StyledToolTip {
                    text: Translation.tr("When this is off you'll have to click")
                }
            }
            Row {
                ConfigSwitch {
                    enabled: !Config.options.sidebar.cornerOpen.clickless
                    text: Translation.tr("Force hover open at absolute corner")
                    checked: Config.options.sidebar.cornerOpen.clicklessCornerEnd
                    onCheckedChanged: {
                        Config.options.sidebar.cornerOpen.clicklessCornerEnd = checked;
                    }

                    StyledToolTip {
                        text: Translation.tr("When the previous option is off and this is on,\nyou can still hover the corner's end to open sidebar,\nand the remaining area can be used for volume/brightness scroll")
                    }
                }
                ConfigSpinBox {
                    icon: "arrow_cool_down"
                    text: Translation.tr("with vertical offset")
                    value: Config.options.sidebar.cornerOpen.clicklessCornerVerticalOffset
                    from: 0
                    to: 20
                    stepSize: 1
                    onValueChanged: {
                        Config.options.sidebar.cornerOpen.clicklessCornerVerticalOffset = value;
                    }
                    // Antes esto era un MouseArea con anchors.fill adentro de un
                    // layout (comportamiento indefinido segun Qt). ConfigSpinBox ya
                    // expone `hovered`, asi que el tooltip solo alcanza.
                    StyledToolTip {
                        text: Translation.tr("Why this is cool:\nFor non-0 values, it won't trigger when you reach the\nscreen corner along the horizontal edge, but it will when\nyou do along the vertical edge")
                    }
                }
            }
            
            ConfigRow {
                uniform: true
                ConfigSwitch {
                    buttonIcon: "vertical_align_bottom"
                    text: Translation.tr("Place at bottom")
                    checked: Config.options.sidebar.cornerOpen.bottom
                    onCheckedChanged: {
                        Config.options.sidebar.cornerOpen.bottom = checked;
                    }

                    StyledToolTip {
                        text: Translation.tr("Place the corners to trigger at the bottom")
                    }
                }
                ConfigSwitch {
                    buttonIcon: "unfold_more_double"
                    text: Translation.tr("Value scroll")
                    checked: Config.options.sidebar.cornerOpen.valueScroll
                    onCheckedChanged: {
                        Config.options.sidebar.cornerOpen.valueScroll = checked;
                    }

                    StyledToolTip {
                        text: Translation.tr("Brightness and volume")
                    }
                }
            }
            ConfigSwitch {
                buttonIcon: "visibility"
                text: Translation.tr("Visualize region")
                checked: Config.options.sidebar.cornerOpen.visualize
                onCheckedChanged: {
                    Config.options.sidebar.cornerOpen.visualize = checked;
                }
            }
            ConfigRow {
                ConfigSpinBox {
                    icon: "arrow_range"
                    text: Translation.tr("Region width")
                    value: Config.options.sidebar.cornerOpen.cornerRegionWidth
                    from: 1
                    to: 300
                    stepSize: 1
                    onValueChanged: {
                        Config.options.sidebar.cornerOpen.cornerRegionWidth = value;
                    }
                }
                ConfigSpinBox {
                    icon: "height"
                    text: Translation.tr("Region height")
                    value: Config.options.sidebar.cornerOpen.cornerRegionHeight
                    from: 1
                    to: 300
                    stepSize: 1
                    onValueChanged: {
                        Config.options.sidebar.cornerOpen.cornerRegionHeight = value;
                    }
                }
            }
        }

        ContentSubsection {
            title: Translation.tr("Esquinas de abajo")
            tooltip: Translation.tr("Qué abre cada esquina inferior cuando el corner open está abajo")

            ConfigComboBox {
                Layout.fillWidth: true
                buttonIcon: "position_bottom_left"
                text: Translation.tr("Abajo a la izquierda")
                model: page.hotCornerActions
                currentValue: Config.options.sidebar.cornerOpen.bottomLeftAction
                onSelected: newValue => {
                    Config.options.sidebar.cornerOpen.bottomLeftAction = newValue;
                }
            }

            ConfigComboBox {
                Layout.fillWidth: true
                buttonIcon: "position_bottom_right"
                text: Translation.tr("Abajo a la derecha")
                model: page.hotCornerActions
                currentValue: Config.options.sidebar.cornerOpen.bottomRightAction
                onSelected: newValue => {
                    Config.options.sidebar.cornerOpen.bottomRightAction = newValue;
                }
            }
        }
    }

    ContentSection {
        icon: "tab"
        title: Translation.tr("Pestañas")

        /**
         * Los seis switches van en el mismo orden en que salen las pestañas en
         * SidebarLeftContent.qml. Intelligence y Anime no tienen un `enable` propio:
         * se prenden desde policies.ai / policies.weeb, que además tienen un tercer
         * valor (Local / Placard) que se elige abajo, en "Modo".
         */
        ConfigSwitch {
            buttonIcon: "neurology"
            text: Translation.tr("Chat de IA")
            checked: Config.options.policies.ai !== 0
            onCheckedChanged: {
                // Al reactivar se vuelve a "Sí"; si estaba en Local, "Modo" lo recupera
                if (checked && Config.options.policies.ai === 0)
                    Config.options.policies.ai = 1;
                else if (!checked)
                    Config.options.policies.ai = 0;
            }
            StyledToolTip {
                text: Translation.tr("Apagado saca la pestaña del sidebar por completo")
            }
        }

        ConfigSwitch {
            buttonIcon: "translate"
            text: Translation.tr("Traductor")
            checked: Config.options.sidebar.translator.enable
            onCheckedChanged: {
                Config.options.sidebar.translator.enable = checked;
            }
        }

        ConfigSwitch {
            buttonIcon: "palette"
            text: Translation.tr("Inspo")
            checked: Config.options.sidebar.inspo.enable
            onCheckedChanged: {
                Config.options.sidebar.inspo.enable = checked;
            }
        }

        ConfigSwitch {
            buttonIcon: "music_note"
            text: Translation.tr("Música")
            checked: Config.options.sidebar.music.enable
            onCheckedChanged: {
                Config.options.sidebar.music.enable = checked;
            }
        }

        ConfigSwitch {
            buttonIcon: "public"
            text: Translation.tr("Social")
            checked: Config.options.sidebar.social.enable
            onCheckedChanged: {
                Config.options.sidebar.social.enable = checked;
            }
        }

        ConfigSwitch {
            buttonIcon: "bookmark_heart"
            text: Translation.tr("Anime")
            checked: Config.options.policies.weeb !== 0
            onCheckedChanged: {
                if (checked && Config.options.policies.weeb === 0)
                    Config.options.policies.weeb = 1;
                else if (!checked)
                    Config.options.policies.weeb = 0;
            }
            StyledToolTip {
                text: Translation.tr("Apagado saca la pestaña del sidebar por completo")
            }
        }

        ContentSubsection {
            title: Translation.tr("Modo")
            tooltip: Translation.tr("Son las mismas opciones que Interface → Políticas.\n\"Local\" deja el chat pero sólo con modelos que corran en la máquina.\n\"Placard\" deja Anime funcionando pero sin que la pestaña salte a la vista.")

            ConfigSelectionArray {
                Layout.fillWidth: false
                enabled: Config.options.policies.ai !== 0
                currentValue: Config.options.policies.ai
                onSelected: newValue => {
                    Config.options.policies.ai = newValue;
                }
                options: [
                    { displayName: Translation.tr("IA: Sí"), icon: "check", value: 1 },
                    { displayName: Translation.tr("IA: Local"), icon: "sync_saved_locally", value: 2 }
                ]
            }

            ConfigSelectionArray {
                Layout.fillWidth: false
                enabled: Config.options.policies.weeb !== 0
                currentValue: Config.options.policies.weeb
                onSelected: newValue => {
                    Config.options.policies.weeb = newValue;
                }
                options: [
                    { displayName: Translation.tr("Anime: Sí"), icon: "check", value: 1 },
                    { displayName: Translation.tr("Anime: Placard"), icon: "ev_shadow", value: 2 }
                ]
            }
        }
    }

    ContentSection {
        icon: "neurology"
        title: Translation.tr("Intelligence")

        ConfigSwitch {
            buttonIcon: "animation"
            text: Translation.tr("Aparición gradual del texto")
            checked: Config.options.sidebar.ai.textFadeIn
            onCheckedChanged: {
                Config.options.sidebar.ai.textFadeIn = checked;
            }
            StyledToolTip {
                text: Translation.tr("Anima cada fragmento de la respuesta a medida que llega,\nen vez de que aparezca de golpe")
            }
        }

        ContentSubsection {
            title: Translation.tr("Qué se muestra")
            tooltip: Translation.tr("Sacar lo que no usás deja más alto libre para los mensajes.\nTodo lo que se esconde acá se sigue pudiendo cambiar por comando (/model, /tool, /clear...).")

            ConfigSwitch {
                buttonIcon: "tab"
                text: Translation.tr("Barra de pestañas de agentes")
                checked: Config.options.sidebar.ai.showTabBar
                onCheckedChanged: {
                    Config.options.sidebar.ai.showTabBar = checked;
                }
            }

            ConfigSwitch {
                buttonIcon: "readiness_score"
                text: Translation.tr("Barra de estado")
                checked: Config.options.sidebar.ai.showStatusBar
                onCheckedChanged: {
                    Config.options.sidebar.ai.showStatusBar = checked;
                }
                StyledToolTip {
                    text: Translation.tr("La pastilla flotante de arriba con la API key,\nla temperatura y el conteo de tokens")
                }
            }

            ConfigSwitch {
                buttonIcon: "api"
                text: Translation.tr("Indicadores del cuadro de texto")
                checked: Config.options.sidebar.ai.showInputIndicators
                onCheckedChanged: {
                    Config.options.sidebar.ai.showInputIndicators = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Los chips de modelo, esfuerzo y herramienta")
                }
            }

            ConfigSwitch {
                buttonIcon: "terminal"
                text: Translation.tr("Botones de comando")
                checked: Config.options.sidebar.ai.showCommandButtons
                onCheckedChanged: {
                    Config.options.sidebar.ai.showCommandButtons = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Los atajos \"/\" y \"/clear\" al lado de los indicadores")
                }
            }

            ConfigSwitch {
                buttonIcon: "badge"
                text: Translation.tr("Encabezado de cada mensaje")
                checked: Config.options.sidebar.ai.showMessageHeader
                onCheckedChanged: {
                    Config.options.sidebar.ai.showMessageHeader = checked;
                }
                StyledToolTip {
                    text: Translation.tr("La franja con el ícono y el nombre del modelo.\nOjo: los botones de copiar, editar y regenerar viven ahí.")
                }
            }
        }

        ContentSubsection {
            title: Translation.tr("Cómo se ven los mensajes")

            ConfigSelectionArray {
                Layout.fillWidth: false
                currentValue: Config.options.sidebar.ai.messageStyle
                onSelected: newValue => {
                    Config.options.sidebar.ai.messageStyle = newValue;
                }
                options: [
                    { displayName: Translation.tr("Burbuja"), icon: "chat_bubble", value: "bubble" },
                    { displayName: Translation.tr("Plano"), icon: "notes", value: "flat" }
                ]
            }

            ConfigSelectionArray {
                Layout.fillWidth: false
                currentValue: Config.options.sidebar.ai.density
                onSelected: newValue => {
                    Config.options.sidebar.ai.density = newValue;
                }
                options: [
                    { displayName: Translation.tr("Compacto"), icon: "density_small", value: "compact" },
                    { displayName: Translation.tr("Normal"), icon: "density_medium", value: "normal" },
                    { displayName: Translation.tr("Cómodo"), icon: "density_large", value: "comfortable" }
                ]
            }
        }

        ContentSubsection {
            title: Translation.tr("Texto")

            ConfigSwitch {
                buttonIcon: "markdown"
                text: Translation.tr("Renderizar Markdown")
                checked: Config.options.sidebar.ai.renderMarkdown
                onCheckedChanged: {
                    Config.options.sidebar.ai.renderMarkdown = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Es el valor inicial: cada mensaje tiene su propio botón\npara alternar entre Markdown y texto crudo")
                }
            }

            ConfigSwitch {
                buttonIcon: "text_select_start"
                text: Translation.tr("Seleccionar texto con el mouse")
                checked: Config.options.sidebar.ai.mouseSelection
                onCheckedChanged: {
                    Config.options.sidebar.ai.mouseSelection = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Con esto prendido, arrastrar sobre un mensaje selecciona\ntexto en vez de scrollear la conversación")
                }
            }

            ConfigSwitch {
                buttonIcon: "unfold_less"
                text: Translation.tr("Razonamiento colapsado")
                checked: Config.options.sidebar.ai.collapseThinkBlocks
                onCheckedChanged: {
                    Config.options.sidebar.ai.collapseThinkBlocks = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Los bloques de \"pensamiento\" arrancan cerrados")
                }
            }
        }

        ContentSubsection {
            title: Translation.tr("Herramienta por defecto")
            tooltip: Translation.tr("La que usan las pestañas nuevas. Cambiarla con /tool dentro del chat también actualiza esto.")

            ConfigSelectionArray {
                Layout.fillWidth: false
                currentValue: Config.options.ai.tool
                onSelected: newValue => {
                    Config.options.ai.tool = newValue;
                }
                options: [
                    { displayName: Translation.tr("Búsqueda"), icon: "travel_explore", value: "search" },
                    { displayName: Translation.tr("Funciones"), icon: "function", value: "functions" },
                    { displayName: Translation.tr("Ninguna"), icon: "block", value: "none" }
                ]
            }
        }
    }

    ContentSection {
        icon: "translate"
        title: Translation.tr("Traductor")

        ConfigSwitch {
            buttonIcon: "check"
            text: Translation.tr("Activar")
            checked: Config.options.sidebar.translator.enable
            onCheckedChanged: {
                Config.options.sidebar.translator.enable = checked;
            }
        }

        // Cuanto más alto, menos pedidos se mandan mientras se escribe.
        ConfigSpinBox {
            enabled: Config.options.sidebar.translator.enable
            icon: "timer"
            text: Translation.tr("Espera antes de traducir (ms)")
            value: Config.options.sidebar.translator.delay
            from: 0
            to: 3000
            stepSize: 50
            onValueChanged: {
                Config.options.sidebar.translator.delay = value;
            }
            StyledToolTip {
                text: Translation.tr("Subilo si te comen rate limits o si se pone lento al tipear")
            }
        }
    }

    ContentSection {
        icon: "palette"
        title: Translation.tr("Inspo")

        ConfigSwitch {
            buttonIcon: "check"
            text: Translation.tr("Activar")
            checked: Config.options.sidebar.inspo.enable
            onCheckedChanged: {
                Config.options.sidebar.inspo.enable = checked;
            }
        }

        /**
         * La fuente activa vive en Persistent.states.inspo.source, no en Config:
         * InspoService.currentSource lee de ahí y Inspo.qml la escribe cuando el
         * usuario cambia de fuente. Config.options.sidebar.inspo.defaultSource no
         * lo lee nadie, así que escribir ahí no haría nada.
         */
        ConfigComboBox {
            Layout.fillWidth: true
            enabled: Config.options.sidebar.inspo.enable
            buttonIcon: "photo_library"
            text: Translation.tr("Fuente")
            description: InspoService.sources[Persistent.states.inspo.source]?.description ?? ""
            model: page.inspoSourceOptions
            currentValue: Persistent.states.inspo.source
            onSelected: newValue => {
                Persistent.states.inspo.source = newValue;
            }
        }

        ConfigSpinBox {
            enabled: Config.options.sidebar.inspo.enable
            icon: "view_column"
            text: Translation.tr("Columnas de la grilla")
            value: Config.options.sidebar.inspo.columns
            from: 1
            to: 5
            stepSize: 1
            onValueChanged: {
                Config.options.sidebar.inspo.columns = value;
            }
        }
    }

    ContentSection {
        icon: "music_note"
        title: Translation.tr("Música")

        ConfigSwitch {
            buttonIcon: "check"
            text: Translation.tr("Activar")
            checked: Config.options.sidebar.music.enable
            onCheckedChanged: {
                Config.options.sidebar.music.enable = checked;
            }
        }

        ConfigSwitch {
            buttonIcon: "lyrics"
            text: Translation.tr("Buscar la letra")
            enabled: Config.options.sidebar.music.enable
            checked: Config.options.sidebar.music.lyrics
            onCheckedChanged: {
                Config.options.sidebar.music.lyrics = checked;
            }
            StyledToolTip {
                text: Translation.tr("Usa LRCLIB, que es una API pública y no pide cuenta")
            }
        }

        ContentSubsection {
            title: Translation.tr("Reproductor del sidebar")

            ConfigSwitch {
                buttonIcon: "play_circle"
                text: Translation.tr("Mostrar la tarjeta del reproductor")
                checked: Config.options.sidebar.media.enable
                onCheckedChanged: {
                    Config.options.sidebar.media.enable = checked;
                }
            }

            // Tiñe la tarjeta con la paleta de la carátula en vez de la del wallpaper
            ConfigSwitch {
                buttonIcon: "radio_button_partial"
                text: Translation.tr("Seguir los colores de la carátula")
                enabled: Config.options.sidebar.media.enable
                checked: Config.options.sidebar.media.artColors
                onCheckedChanged: {
                    Config.options.sidebar.media.artColors = checked;
                }
            }
        }

        ContentSubsection {
            title: Translation.tr("Spotify")
            tooltip: Translation.tr("Creá una app en developer.spotify.com (es gratis y no necesita secret,\nel login usa PKCE) y agregale como Redirect URI exactamente:\nhttp://127.0.0.1:8888/callback\nLos tokens se guardan en el keyring, nunca en config.json.")

            ConfigTextArea {
                id: spotifyClientIdField
                Layout.fillWidth: true
                enabled: Config.options.sidebar.music.enable
                buttonIcon: "key"
                text: Translation.tr("Client ID")
                placeholderText: Translation.tr("El Client ID de tu app de Spotify")
                fieldWidth: 300
                value: Config.options.sidebar.music.spotify.clientId ?? ""
                onValueChanged: {
                    spotifyClientIdDebounce.restart();
                }
                // Escribir en cada tecla haría que Config guarde el archivo decenas de veces
                Timer {
                    id: spotifyClientIdDebounce
                    interval: 1000
                    onTriggered: {
                        Config.options.sidebar.music.spotify.clientId = spotifyClientIdField.value;
                    }
                }
            }

            ConfigSpinBox {
                enabled: Config.options.sidebar.music.enable
                icon: "lan"
                text: Translation.tr("Puerto del callback")
                value: Config.options.sidebar.music.spotify.callbackPort
                from: 1024
                to: 65535
                stepSize: 1
                onValueChanged: {
                    Config.options.sidebar.music.spotify.callbackPort = value;
                }
                StyledToolTip {
                    text: Translation.tr("Tiene que coincidir con el puerto del Redirect URI cargado en la app de Spotify")
                }
            }
        }
    }

    ContentSection {
        icon: "public"
        title: Translation.tr("Social")

        ConfigSwitch {
            buttonIcon: "check"
            text: Translation.tr("Activar")
            checked: Config.options.sidebar.social.enable
            onCheckedChanged: {
                Config.options.sidebar.social.enable = checked;
            }
        }

        ContentSubsection {
            title: Translation.tr("Matrix")
            tooltip: Translation.tr("Matrix es el pegamento para meter otras redes acá adentro:\nlos puentes (mautrix-whatsapp y compañía) publican cada chat como\nuna sala, así que la shell no necesita saber nada de WhatsApp en particular.")

            ConfigSwitch {
                buttonIcon: "chat"
                text: Translation.tr("Activar los chats de Matrix")
                enabled: Config.options.sidebar.social.enable
                checked: Config.options.sidebar.social.matrix.enable
                onCheckedChanged: {
                    Config.options.sidebar.social.matrix.enable = checked;
                }
            }

            ConfigTextArea {
                id: homeserverField
                Layout.fillWidth: true
                enabled: Config.options.sidebar.social.matrix.enable
                buttonIcon: "dns"
                text: Translation.tr("Homeserver")
                placeholderText: "http://localhost:8008"
                fieldWidth: 300
                value: Config.options.sidebar.social.matrix.homeserver ?? ""
                onValueChanged: {
                    homeserverDebounce.restart();
                }
                Timer {
                    id: homeserverDebounce
                    interval: 1000
                    onTriggered: {
                        Config.options.sidebar.social.matrix.homeserver = homeserverField.value;
                    }
                }
            }
        }

        ContentSubsection {
            id: linksSubsection
            title: Translation.tr("Links")
            tooltip: Translation.tr("Una pestaña por red, y adentro la webapp embebida.\nEl nombre es lo que va en la pestaña; la URL, lo que se carga.")

            /**
             * Se edita sobre una copia y se escribe el array entero, porque Config
             * solo persiste cuando la propiedad list<var> se reasigna: mutar un
             * elemento in-place no dispara el guardado.
             */
            property var draft: []

            function loadDraft() {
                const stored = Config.options.sidebar.social.links ?? [];
                linksSubsection.draft = stored.map(link => ({
                    name: link.name ?? "",
                    url: link.url ?? ""
                }));
            }

            function commit() {
                Config.options.sidebar.social.links = linksSubsection.draft.map(link => ({
                    name: link.name,
                    url: link.url
                }));
            }

            function setField(index, key, value) {
                if (linksSubsection.draft[index]?.[key] === value)
                    return;
                const next = linksSubsection.draft.slice();
                next[index] = Object.assign({}, next[index]);
                next[index][key] = value;
                linksSubsection.draft = next;
                commitDebounce.restart();
            }

            Component.onCompleted: linksSubsection.loadDraft()

            Timer {
                id: commitDebounce
                interval: 1000
                onTriggered: linksSubsection.commit()
            }

            Repeater {
                model: linksSubsection.draft

                delegate: RowLayout {
                    id: linkRow
                    required property int index
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.leftMargin: 8
                    Layout.rightMargin: 8
                    spacing: 8
                    enabled: Config.options.sidebar.social.enable

                    MaterialTextField {
                        Layout.preferredWidth: 140
                        placeholderText: Translation.tr("Nombre")
                        text: linkRow.modelData.name
                        onTextChanged: linksSubsection.setField(linkRow.index, "name", text)
                    }

                    MaterialTextField {
                        Layout.fillWidth: true
                        placeholderText: "https://..."
                        text: linkRow.modelData.url
                        onTextChanged: linksSubsection.setField(linkRow.index, "url", text)
                    }

                    RippleButtonWithIcon {
                        materialIcon: "delete"
                        mainText: ""
                        onClicked: {
                            const next = linksSubsection.draft.slice();
                            next.splice(linkRow.index, 1);
                            linksSubsection.draft = next;
                            linksSubsection.commit();
                        }
                        StyledToolTip {
                            text: Translation.tr("Borrar este link")
                        }
                    }
                }
            }

            RippleButtonWithIcon {
                Layout.leftMargin: 8
                Layout.topMargin: 4
                enabled: Config.options.sidebar.social.enable
                materialIcon: "add"
                mainText: Translation.tr("Agregar link")
                onClicked: {
                    linksSubsection.draft = linksSubsection.draft.concat([{ name: "", url: "" }]);
                }
            }
        }
    }

    ContentSection {
        icon: "bookmark_heart"
        title: Translation.tr("Anime")

        // Igual que Inspo: el provider activo es Persistent.states.booru.provider
        // (Booru.currentProvider lee de ahí). defaultProvider en Config es letra muerta.
        ConfigComboBox {
            Layout.fillWidth: true
            buttonIcon: "api"
            text: Translation.tr("Provider")
            description: Booru.providers[Persistent.states.booru.provider]?.description ?? ""
            model: page.booruProviderOptions
            currentValue: Persistent.states.booru.provider
            onSelected: newValue => {
                Persistent.states.booru.provider = newValue;
            }
        }

        ConfigSpinBox {
            icon: "format_list_numbered"
            text: Translation.tr("Resultados por búsqueda")
            value: Config.options.sidebar.booru.limit
            from: 1
            to: 100
            stepSize: 1
            onValueChanged: {
                Config.options.sidebar.booru.limit = value;
            }
        }

        // Es el mismo switch que el del pie de la pestaña Anime del sidebar.
        // Zerochan no sirve contenido NSFW, así que ahí el toggle queda inerte.
        ConfigSwitch {
            buttonIcon: "18_up_rating"
            text: Translation.tr("Permitir NSFW")
            checked: Persistent.states.booru.allowNsfw
            onCheckedChanged: {
                Persistent.states.booru.allowNsfw = checked;
            }
        }

        ContentSubsection {
            title: Translation.tr("Grilla")
            tooltip: Translation.tr("Las filas se llenan de imágenes mientras no bajen del alto mínimo,\nasí que subirlo da imágenes más grandes y menos por fila.")

            ConfigSpinBox {
                icon: "photo_size_select_large"
                text: Translation.tr("Alto mínimo de fila (px)")
                value: Config.options.sidebar.booru.imageSize
                from: 80
                to: 500
                stepSize: 10
                onValueChanged: {
                    Config.options.sidebar.booru.imageSize = value;
                }
            }

            ConfigSpinBox {
                icon: "space_bar"
                text: Translation.tr("Separación entre imágenes (px)")
                value: Config.options.sidebar.booru.imageSpacing
                from: 0
                to: 30
                stepSize: 1
                onValueChanged: {
                    Config.options.sidebar.booru.imageSpacing = value;
                }
            }
        }

        ContentSubsection {
            title: Translation.tr("Qué se muestra")

            ConfigSwitch {
                buttonIcon: "sell"
                text: Translation.tr("Tags de la búsqueda")
                checked: Config.options.sidebar.booru.showTags
                onCheckedChanged: {
                    Config.options.sidebar.booru.showTags = checked;
                }
                StyledToolTip {
                    text: Translation.tr("La tira de tags arriba de cada tanda de resultados")
                }
            }

            ConfigSwitch {
                buttonIcon: "toggle_on"
                text: Translation.tr("Switch de NSFW en el pie")
                checked: Config.options.sidebar.booru.showNsfwToggle
                onCheckedChanged: {
                    Config.options.sidebar.booru.showNsfwToggle = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Escondelo si no querés el switch a mano.\nSe sigue pudiendo cambiar desde acá arriba o con /mode.")
                }
            }

            ConfigSwitch {
                buttonIcon: "blur_on"
                text: Translation.tr("Difuminar miniaturas NSFW")
                checked: Config.options.sidebar.booru.blurNsfw
                onCheckedChanged: {
                    Config.options.sidebar.booru.blurNsfw = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Se ven borrosas hasta que les pasás el mouse por encima")
                }
            }
        }

        ContentSubsection {
            title: Translation.tr("Búsqueda y carga")

            ConfigSpinBox {
                icon: "timer"
                text: Translation.tr("Espera de las sugerencias de tags (ms)")
                value: Config.options.sidebar.booru.tagSuggestionDelay
                from: 0
                to: 2000
                stepSize: 10
                onValueChanged: {
                    Config.options.sidebar.booru.tagSuggestionDelay = value;
                }
                StyledToolTip {
                    text: Translation.tr("Cuánto espera después de que dejás de tipear antes de pedir sugerencias")
                }
            }

            ConfigSwitch {
                buttonIcon: "swipe_down"
                text: Translation.tr("Arrastrar para cargar más")
                checked: Config.options.sidebar.booru.pullToLoadMore
                onCheckedChanged: {
                    Config.options.sidebar.booru.pullToLoadMore = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Tirar hacia abajo al final de los resultados trae la página siguiente.\nCon esto apagado queda sólo el botón de página siguiente.")
                }
            }
        }

        ContentSubsection {
            title: Translation.tr("Zerochan")
            tooltip: Translation.tr("Zerochan pide identificarse con un usuario en el User-Agent de cada pedido")

            ConfigTextArea {
                id: zerochanUsernameField
                Layout.fillWidth: true
                buttonIcon: "person"
                text: Translation.tr("Usuario")
                placeholderText: "[unset]"
                fieldWidth: 300
                value: Config.options.sidebar.booru.zerochan.username ?? ""
                onValueChanged: {
                    zerochanUsernameDebounce.restart();
                }
                Timer {
                    id: zerochanUsernameDebounce
                    interval: 1000
                    onTriggered: {
                        Config.options.sidebar.booru.zerochan.username = zerochanUsernameField.value;
                    }
                }
            }
        }
    }
}
