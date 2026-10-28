import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ToolTip {
    id: root
    property bool extraVisibleCondition: true
    property bool alternativeVisibleCondition: false

    readonly property bool internalVisibleCondition: (extraVisibleCondition && (parent.hovered === undefined || parent?.hovered)) || alternativeVisibleCondition
    verticalPadding: 5
    horizontalPadding: 10
    background: null
    font {
        family: Appearance.font.family.main
        variableAxes: Appearance.font.variableAxes.main
        pixelSize: Appearance?.font.pixelSize.smaller ?? 14
        hintingPreference: Font.PreferNoHinting // Prevent shaky text
    }

    delay: 0

    // Un ToolTip es un Popup, y un Popup visible se cierra solo cuando presionás
    // afuera... COMIÉNDOSE ese clic. Con el tooltip abierto por hover, el primer
    // clic sobre el botón se gastaba en cerrar el globito y nunca llegaba al
    // botón: se sentía como un botón muerto. Un tooltip no tiene por qué
    // interceptar nada, así que no cierra por su cuenta.
    closePolicy: Popup.NoAutoClose

    // ...y no cerrarse no alcanzaba. Un Popup no es un dibujo flotante: Qt le
    // arma un `popupItem` que es un Item de verdad en la escena de la ventana,
    // creado con `setAcceptedMouseButtons(Qt::AllButtons)` y su propio cursor.
    // O sea: TODO el rectángulo del globito (fácil 300x30 px, centrado sobre un
    // botón de 28) se traga los clics y el hover de lo que haya debajo.
    //
    // Y ese rectángulo casi nunca cae en un lugar vacío. La posición por
    // omisión es "centrado y arriba del padre", pero si no entra arriba Qt lo
    // VOLTEA abajo (comprobado: un botón en y=20 termina con el globito en
    // y=51, tapando lo que sigue). En una lista como la del historial, donde
    // cada fila tiene tres botoncitos con tooltip, el globito de uno queda
    // encima de los botones de la fila de al lado y esos dejan de responder.
    //
    // Es el mismo mecanismo que ya mató los botones de historial/+/settings de
    // AiTabBar dos veces; ahí se resolvió borrando esos tooltips. Acá se ataca
    // la causa: un Item deshabilitado queda FUERA del reparto de eventos de Qt
    // pero se sigue dibujando igual, así que el globito pasa a ser lo que
    // siempre debió ser — pintura, no una superficie clickeable.
    enabled: false

    visible: internalVisibleCondition
    
    contentItem: StyledToolTipContent {
        id: contentItem
        font: root.font
        text: root.text
        shown: root.internalVisibleCondition
        horizontalPadding: root.horizontalPadding
        verticalPadding: root.verticalPadding
    }
}
