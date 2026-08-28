import qs
import qs.services
import qs.modules.common
import QtQuick

/** Volumen: la rueda sube y baja, el click silencia. */
ScrollControl {
    id: root

    readonly property real volume: Audio.sink?.audio.volume ?? 0
    readonly property bool muted: Audio.sink?.audio.muted ?? false

    value: root.volume
    icon: root.muted ? "volume_off" : root.volume < 0.01 ? "volume_mute" : root.volume < 0.5 ? "volume_down" : "volume_up"
    accentColor: root.muted ? Appearance.colors.colSubtext : Appearance.colors.colOnLayer1
    tooltipText: Translation.tr("Scroll to change volume, click to mute")

    onIncrease: Audio.incrementVolume()
    onDecrease: Audio.decrementVolume()
    onActivated: Audio.toggleMute()
    // El OSD se abre solo al cambiar el volumen; esto lo cierra al irse el mouse.
    onMovedAway: GlobalStates.osdVolumeOpen = false
}
