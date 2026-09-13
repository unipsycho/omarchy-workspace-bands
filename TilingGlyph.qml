import QtQuick
import qs.Commons

// Four offset tiles — reads as a dwindle/grid tiling layout.
Item {
  id: root

  property color color: Color.foreground
  property real glyphWidth: Style.space(15)
  property real glyphHeight: Style.space(12)
  // Which band is active: "full" | "left" | "right" | "top" | "bottom"
  property string align: "full"
  property real fraction: 1

  implicitWidth: glyphWidth
  implicitHeight: glyphHeight

  readonly property real inset: Math.max(1, Math.round(Math.min(glyphWidth, glyphHeight) * 0.08))
  readonly property real gap: Math.max(1, Math.round(Math.min(glyphWidth, glyphHeight) * 0.08))

  // Outer frame
  Rectangle {
    id: frame
    anchors.fill: parent
    radius: Math.max(1, Math.round(root.glyphWidth * 0.08))
    color: "transparent"
    border.width: 1
    border.color: root.color
    opacity: 0.4
  }

  // Active tiling band (highlighted region)
  Rectangle {
    id: band
    readonly property real trackW: Math.max(0, frame.width - root.inset * 2)
    readonly property real trackH: Math.max(0, frame.height - root.inset * 2)

    y: {
      if (root.align === "bottom") return root.inset + Math.round(trackH * (1 - root.fraction))
      return root.inset
    }
    x: {
      if (root.align === "right") return root.inset + Math.round(trackW * (1 - root.fraction))
      return root.inset
    }
    width: {
      if (root.align === "left" || root.align === "right") return Math.max(2, Math.round(trackW * root.fraction))
      return trackW
    }
    height: {
      if (root.align === "top" || root.align === "bottom") return Math.max(2, Math.round(trackH * root.fraction))
      return trackH
    }
    radius: Math.max(1, Math.round(root.glyphWidth * 0.05))
    color: root.color
    opacity: root.align === "full" ? 0.2 : 0.22

    Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    Behavior on y { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
  }

  // 2x2 tile grid inside the band (slightly staggered sizes = "offset tiles")
  Item {
    id: tiles
    anchors.fill: band
    anchors.margins: root.gap

    readonly property real cellW: Math.max(1, (width - root.gap) / 2)
    readonly property real cellH: Math.max(1, (height - root.gap) / 2)

    // Top-left — slightly larger
    Rectangle {
      x: 0
      y: 0
      width: tiles.cellW + root.gap * 0.35
      height: tiles.cellH + root.gap * 0.2
      radius: 1
      color: root.color
      opacity: 0.95
    }
    // Top-right
    Rectangle {
      x: tiles.cellW + root.gap
      y: root.gap * 0.35
      width: Math.max(1, tiles.width - x)
      height: Math.max(1, tiles.cellH - root.gap * 0.35)
      radius: 1
      color: root.color
      opacity: 0.7
    }
    // Bottom-left
    Rectangle {
      x: root.gap * 0.25
      y: tiles.cellH + root.gap
      width: Math.max(1, tiles.cellW - root.gap * 0.25)
      height: Math.max(1, tiles.height - y)
      radius: 1
      color: root.color
      opacity: 0.7
    }
    // Bottom-right — offset inward
    Rectangle {
      x: tiles.cellW + root.gap * 0.6
      y: tiles.cellH + root.gap * 0.6
      width: Math.max(1, tiles.width - x)
      height: Math.max(1, tiles.height - y)
      radius: 1
      color: root.color
      opacity: 0.85
    }
  }
}
