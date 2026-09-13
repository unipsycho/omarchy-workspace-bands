import QtQuick
import qs.Commons

// Three vertical bars — a sideways hamburger / columns glyph.
// `activeColumns` brightens that many bars from the left to hint density.
Item {
  id: root

  property int activeColumns: 2
  property color color: Color.foreground
  property real glyphWidth: Style.space(15)
  property real glyphHeight: Style.space(12)

  implicitWidth: glyphWidth
  implicitHeight: glyphHeight

  readonly property int barCount: 3
  readonly property real gap: Math.max(1, Math.round(glyphWidth * 0.12))
  readonly property real barWidth: Math.max(2, Math.round((glyphWidth - gap * (barCount - 1)) / barCount))

  Row {
    anchors.centerIn: parent
    spacing: root.gap

    Repeater {
      model: root.barCount
      Rectangle {
        required property int index
        width: root.barWidth
        height: root.glyphHeight
        radius: Math.max(1, Math.round(root.barWidth * 0.35))
        color: root.color
        opacity: (index + 1) <= root.activeColumns ? 1.0 : 0.35

        Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
      }
    }
  }
}
