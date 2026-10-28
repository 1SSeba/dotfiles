import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Effects

Canvas { // Visualizer
    id: root
    property list<var> points
    property list<var> smoothPoints
    property real maxVisualizerValue: 1000
    property int smoothing: 2
    property bool live: true
    property color color: Appearance.m3colors.m3primary

    onPointsChanged: () => {
        // Repintar una Canvas cuesta un raster en el hilo de GUI: si no se ve
        // (popup cerrado, otra pestaña) no hay nada que dibujar.
        if (!root.visible) return;
        root.requestPaint()
    }

    anchors.fill: parent
    onPaint: {
        var ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);

        var points = root.points;
        var maxVal = root.maxVisualizerValue || 1;
        var h = height;
        var w = width;
        var n = points.length;
        if (n < 2) return;

        // Smoothing: simple moving average (optional)
        // El promedio se arma en un array de JS local y recién al final se
        // publica en la propiedad: hacer `push` sobre un `list<var>` de QML
        // cruza la frontera QML/JS una vez por punto y por cuadro.
        var smoothWindow = root.smoothing; // adjust for more/less smoothing
        var smoothed = new Array(n);
        for (var i = 0; i < n; ++i) {
            var sum = 0, count = 0;
            for (var j = -smoothWindow; j <= smoothWindow; ++j) {
                var idx = Math.max(0, Math.min(n - 1, i + j));
                sum += points[idx];
                count++;
            }
            smoothed[i] = sum / count;
        }
        if (!root.live) smoothed.fill(0); // If not playing, show no points
        root.smoothPoints = smoothed;

        ctx.beginPath();
        ctx.moveTo(0, h);
        for (var i = 0; i < n; ++i) {
            var x = i * w / (n - 1);
            var y = h - (smoothed[i] / maxVal) * h;
            ctx.lineTo(x, y);
        }
        ctx.lineTo(w, h);
        ctx.closePath();

        ctx.fillStyle = Qt.rgba(
            root.color.r,
            root.color.g,
            root.color.b,
            0.15
        );
        ctx.fill();
    }

    layer.enabled: true
    layer.effect: MultiEffect { // Blur a bit to obscure away the points
        source: root
        saturation: 0.2
        blurEnabled: true
        blurMax: 7
        blur: 1
    }
}