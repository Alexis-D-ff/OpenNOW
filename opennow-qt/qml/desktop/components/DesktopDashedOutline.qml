import QtQuick
import QtQuick.Shapes

Shape {
    id: outline
    property color stroke: "#33FFFFFF"
    property real radius: 0
    ShapePath {
        strokeColor: outline.stroke
        strokeWidth: 1
        strokeStyle: ShapePath.DashLine
        dashPattern: [3, 2]
        fillColor: "transparent"
        PathRectangle {
            x: 0.5; y: 0.5
            width: Math.max(0, outline.width - 1); height: Math.max(0, outline.height - 1)
            radius: outline.radius
        }
    }
}
