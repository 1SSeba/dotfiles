import QtQuick
import QtQuick.Effects

/**
 * MultiEffect que recolorea su fuente.
 *
 * Sin importar qs.modules.common: la animación del color se dejó afuera porque
 * ese import hacía que el tipo no resolviera dentro del módulo de widgets.
 */
MultiEffect {
    property color sourceColor: "black"

    colorization: 1
    brightness: 1 - sourceColor.hslLightness
}
