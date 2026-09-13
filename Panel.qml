import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "agileautomation.workspace-bands"
  ipcTarget: "agileautomation.workspace-bands"
  manageIpc: false

  readonly property real oneWidth: Model.clampWidth(setting("oneWidth", 0.96), 0.96)
  readonly property real twoWidth: Model.clampWidth(setting("twoWidth", 0.49), 0.49)
  readonly property real threeWidth: Model.clampWidth(setting("threeWidth", 0.32), 0.32)
  readonly property real halfFraction: Model.clampFraction(setting("halfFraction", 0.5), 0.5)
  readonly property real largeFraction: Model.clampFraction(setting("largeFraction", 0.75), 0.75)

  readonly property var columnModes: Model.columnPresets(oneWidth, twoWidth, threeWidth)
  readonly property var bandModeList: Model.bandModes(halfFraction, largeFraction)

  property int activeColumns: 2
  property string activeBandId: "full"
  property bool menuOpen: false
  property var layouts: ({})
  property var bandAssigned: ({})
  property var baseGaps: ({ top: 10, right: 10, bottom: 10, left: 10 })
  property string pendingScript: ""
  property double ignoreWidthUntil: 0

  readonly property var workspace: Hyprland.focusedWorkspace
  readonly property int workspaceId: workspace ? workspace.id : 0
  readonly property var monitor: workspace && workspace.monitor ? workspace.monitor : Hyprland.focusedMonitor
  readonly property int monitorWidth: Model.logicalWidth(monitor)
  readonly property int monitorHeight: Model.logicalHeight(monitor)
  readonly property string workspaceLayout: layouts[String(workspaceId)] || ""
  readonly property bool scrolling: Model.isScrollingLayout(workspaceLayout)
  readonly property var activeColumnMode: Model.findColumnPreset(columnModes, activeColumns) || columnModes[1]
  readonly property var activeBandMode: Model.findBandMode(bandModeList, activeBandId) || bandModeList[0]

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color accent: Color.accent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property string pluginDir: Quickshell.env("HOME") + "/.config/omarchy/plugins/agileautomation.workspace-bands"
  readonly property string cliPath: root.pluginDir + "/bin/omarchy-workspace-bands"
  readonly property string bandStateDir: Quickshell.env("HOME") + "/.local/state/omarchy/workspace-layouts"
  readonly property string tooltipText: "Workspace Bands"

  function close() {
    menuOpen = false
    panelController.hide()
  }

  function reloadState() {
    if (widthProc.running) widthProc.running = false
    widthProc.running = true
    if (!layoutProc.running) layoutProc.running = true
    if (!bandLoadProc.running) bandLoadProc.running = true
    if (!gapsProc.running) gapsProc.running = true
  }

  function runScript(script) {
    if (script === "") return
    if (applyProc.running) {
      pendingScript = script
      return
    }
    applyProc.command = ["bash", "-c", script]
    applyProc.running = true
  }

  function syncBandAssignment(modeId) {
    var key = String(workspaceId)
    var next = {}
    for (var k in bandAssigned) next[k] = bandAssigned[k]
    if (modeId === "full") delete next[key]
    else next[key] = { mode: modeId }
    bandAssigned = next
  }

  function markLayout(layoutName) {
    var nextLayouts = {}
    for (var k in layouts) nextLayouts[k] = layouts[k]
    nextLayouts[String(workspaceId)] = layoutName
    layouts = nextLayouts
  }

  function setColumns(cols) {
    var n = Number(cols)
    root.menuOpen = false
    root.activeColumns = n
    root.ignoreWidthUntil = Date.now() + 1500
    syncBandAssignment("full")
    activeBandId = "full"
    markLayout("scrolling")
    runScript(Model.applyColumnsScript(
      cliPath, cols, bandStateDir, workspaceId, baseGaps,
      oneWidth, twoWidth, threeWidth
    ))
  }

  function cycleColumns() {
    setColumns((activeColumns % 3) + 1)
  }

  function applyBand(modeId) {
    var mode = Model.findBandMode(bandModeList, modeId)
    if (!mode || workspaceId === 0) return

    syncBandAssignment(modeId)
    activeBandId = modeId
    root.menuOpen = false
    markLayout("dwindle")

    var gaps = Model.gapsFor(mode, monitorWidth, monitorHeight, baseGaps)
    var parts = []
    var layout = Model.setLayoutScript(bandStateDir, workspaceId, "dwindle")
    if (layout) parts.push(layout)
    var band = Model.applyBandScript(bandStateDir, workspaceId, mode, gaps)
    if (band) parts.push(band)
    runScript(parts.join("\n"))
  }

  function cycleBand() {
    var index = Model.indexOfBandMode(bandModeList, activeBandId)
    applyBand(bandModeList[(index + 1) % bandModeList.length].id)
  }

  function openMenu() {
    root.menuOpen = true
    reloadState()
  }

  function toggleMenu() {
    if (root.menuOpen) root.menuOpen = false
    else openMenu()
  }

  onWorkspaceIdChanged: {
    var entry = bandAssigned[String(workspaceId)]
    activeBandId = entry ? entry.mode : "full"
    reloadState()
  }

  IpcHandler {
    target: root.ipcTarget

    function set(columns: string): string {
      var n = Number(columns)
      if (n !== 1 && n !== 2 && n !== 3) return "unknown columns: " + columns
      root.setColumns(n)
      return String(n)
    }
    function sync(columns: string): string {
      var n = Number(columns)
      if (n === 1 || n === 2 || n === 3) {
        root.activeColumns = n
        root.ignoreWidthUntil = Date.now() + 1500
        root.markLayout("scrolling")
      }
      return String(root.activeColumns)
    }
    function cycle(): string {
      root.cycleColumns()
      return String(root.activeColumns)
    }
    function cycleBand(): string {
      root.cycleBand()
      return root.activeBandId
    }
    function band(mode: string): string {
      if (!Model.findBandMode(root.bandModeList, mode)) return "unknown band: " + mode
      root.applyBand(mode)
      return mode
    }
    function current(): string {
      return root.scrolling ? ("columns:" + root.activeColumns) : ("band:" + root.activeBandId)
    }
    function open(): void { root.openMenu() }
    function close(): void { root.menuOpen = false }
    function toggle(): void { root.toggleMenu() }
  }

  Process {
    id: widthProc
    running: true
    command: ["hyprctl", "-j", "getoption", "scrolling:column_width"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (Date.now() < root.ignoreWidthUntil) return
        var w = Model.parseWidth(text)
        root.activeColumns = Model.nearestColumnPreset(root.columnModes, w).id
      }
    }
  }

  Process {
    id: layoutProc
    running: true
    command: ["hyprctl", "-j", "workspaces"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.layouts = Model.parseLayouts(text)
    }
  }

  Process {
    id: gapsProc
    running: true
    command: ["hyprctl", "-j", "getoption", "general:gaps_out"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.baseGaps = Model.parseBaseGaps(text, root.baseGaps)
    }
  }

  Process {
    id: bandLoadProc
    running: true
    command: ["bash", "-c", Model.loadBandScript(root.bandStateDir)]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.bandAssigned = Model.parseBandState(text)
        var entry = root.bandAssigned[String(root.workspaceId)]
        root.activeBandId = entry ? entry.mode : "full"
      }
    }
  }

  Process {
    id: applyProc
    onExited: {
      Qt.callLater(root.reloadState)
      if (root.pendingScript === "") return
      var script = root.pendingScript
      root.pendingScript = ""
      root.runScript(script)
    }
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      var name = event.name
      if (name === "configreloaded" || name === "workspace" || name === "workspacev2"
          || name === "openwindow" || name === "closewindow")
        Qt.callLater(root.reloadState)
    }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    tooltipText: root.tooltipText
    iconComponent: Component {
      Item {
        ColumnsGlyph {
          anchors.centerIn: parent
          visible: root.scrolling
          activeColumns: root.activeColumns
          color: root.foreground
        }
        TilingGlyph {
          anchors.centerIn: parent
          visible: !root.scrolling
          color: root.foreground
          align: root.activeBandMode.align
          fraction: root.activeBandMode.fraction
        }
      }
    }
    onPressed: function(buttonCode) { root.toggleMenu() }
  }

  PopupCard {
    id: menu
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.menuOpen
    contentWidth: menu.fittedContentWidth(Style.space(260))
    contentHeight: menu.fittedContentHeight(menuColumn.implicitHeight)

    Column {
      id: menuColumn
      anchors.fill: parent
      spacing: Style.space(4)

      Text {
        text: "Workspace Bands"
        color: root.accent
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
      }

      Text {
        text: "Shape the usable area of the focused workspace"
        color: Qt.darker(root.foreground, 1.5)
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        width: parent.width
        wrapMode: Text.WordWrap
      }

      Item { width: 1; height: Style.space(4) }

      RowLayout {
        width: parent.width
        spacing: Style.space(8)

        Text {
          Layout.fillWidth: true
          text: "Dwindle"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          font.bold: true
        }

        Text {
          text: "Super+Alt+L"
          color: Qt.darker(root.foreground, 1.45)
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
      }

      Text {
        text: "Tiling area — right or bottom open. Super+L toggles layout."
        color: Qt.darker(root.foreground, 1.5)
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        width: parent.width
        wrapMode: Text.WordWrap
      }

      Repeater {
        model: root.bandModeList
        delegate: Item {
          id: bandRow
          required property var modelData
          width: menuColumn.width
          implicitHeight: Style.space(28)
          readonly property bool selected: !root.scrolling && modelData.id === root.activeBandId

          Rectangle {
            anchors.fill: parent
            radius: Style.space(4)
            color: bandRow.selected ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.14) : "transparent"
          }

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.space(6)
            anchors.rightMargin: Style.space(6)
            spacing: Style.space(8)

            TilingGlyph {
              color: root.foreground
              align: bandRow.modelData.align
              fraction: bandRow.modelData.fraction
              glyphWidth: Style.space(14)
              glyphHeight: Style.space(11)
            }

            Text {
              Layout.fillWidth: true
              text: bandRow.modelData.label
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.applyBand(bandRow.modelData.id)
          }
        }
      }

      Item { width: 1; height: Style.space(6) }

      Rectangle {
        width: parent.width
        height: 1
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.2)
      }

      Item { width: 1; height: Style.space(2) }

      RowLayout {
        width: parent.width
        spacing: Style.space(8)

        Text {
          Layout.fillWidth: true
          text: "Scrolling"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          font.bold: true
        }

        Text {
          text: "Super+Shift+L"
          color: Qt.darker(root.foreground, 1.45)
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
      }

      Text {
        text: "How many columns fit on screen. Super+L toggles layout."
        color: Qt.darker(root.foreground, 1.5)
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        width: parent.width
        wrapMode: Text.WordWrap
      }

      Repeater {
        model: root.columnModes
        delegate: Item {
          id: colRow
          required property var modelData
          width: menuColumn.width
          implicitHeight: Style.space(28)
          readonly property bool selected: root.scrolling && modelData.id === root.activeColumns

          Rectangle {
            anchors.fill: parent
            radius: Style.space(4)
            color: colRow.selected ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.14) : "transparent"
          }

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.space(6)
            anchors.rightMargin: Style.space(6)
            spacing: Style.space(8)

            ColumnsGlyph {
              activeColumns: colRow.modelData.id
              color: root.foreground
              glyphWidth: Style.space(14)
              glyphHeight: Style.space(11)
            }

            Text {
              Layout.fillWidth: true
              text: colRow.modelData.label
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.setColumns(colRow.modelData.id)
          }
        }
      }
    }
  }
}
