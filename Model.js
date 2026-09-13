// Shared logic for Workspace Bands.
//
// Scrolling: global scrolling:column_width (one / two / three columns).
// Dwindle: per-workspace asymmetric gaps_out — left-locked (right open) or
// top-locked (bottom open) at 50% / 75%. Never centered.

function clampWidth(value, fallback) {
  var n = Number(value)
  if (!isFinite(n) || n <= 0) return fallback
  return Math.max(0.15, Math.min(1, n))
}

function clampFraction(value, fallback) {
  var n = Number(value)
  if (!isFinite(n) || n <= 0) return fallback
  return Math.max(0.25, Math.min(1, n))
}

function columnPresets(oneWidth, twoWidth, threeWidth) {
  return [
    { id: 1, key: "one", label: "One column", width: clampWidth(oneWidth, 0.96) },
    { id: 2, key: "two", label: "Two columns", width: clampWidth(twoWidth, 0.49) },
    { id: 3, key: "three", label: "Three columns", width: clampWidth(threeWidth, 0.32) }
  ]
}

function findColumnPreset(list, id) {
  var n = Number(id)
  for (var i = 0; i < list.length; i++) if (list[i].id === n) return list[i]
  return null
}

function nearestColumnPreset(list, width) {
  var w = Number(width)
  if (!isFinite(w)) return list[1] || list[0]
  var best = list[0]
  var bestDist = Math.abs(w - best.width)
  for (var i = 1; i < list.length; i++) {
    var d = Math.abs(w - list[i].width)
    if (d < bestDist) {
      best = list[i]
      bestDist = d
    }
  }
  return best
}

function parseWidth(rawJson) {
  try {
    var n = Number(JSON.parse(rawJson).float)
    return isFinite(n) ? n : NaN
  } catch (e) {
    return NaN
  }
}

function parseColumns(text) {
  var n = Number(String(text || "").trim())
  if (n === 1 || n === 2 || n === 3) return n
  return 0
}

// halfFraction default 0.5, largeFraction default 0.75
function bandModes(halfFraction, largeFraction) {
  var half = clampFraction(halfFraction, 0.5)
  var large = clampFraction(largeFraction, 0.75)
  return [
    { id: "full", label: "Full", align: "full", fraction: 1 },
    { id: "left-75", label: "Left 75%", align: "left", fraction: large },
    { id: "left-50", label: "Left 50%", align: "left", fraction: half },
    { id: "top-75", label: "Top 75%", align: "top", fraction: large },
    { id: "top-50", label: "Top 50%", align: "top", fraction: half }
  ]
}

function findBandMode(list, id) {
  for (var i = 0; i < list.length; i++) if (list[i].id === id) return list[i]
  return null
}

function indexOfBandMode(list, id) {
  for (var i = 0; i < list.length; i++) if (list[i].id === id) return i
  return 0
}

function isScrollingLayout(layout) {
  return String(layout || "") === "scrolling"
}

function parseLayouts(rawJson) {
  var layouts = {}
  try {
    var list = JSON.parse(rawJson)
    for (var i = 0; i < list.length; i++) layouts[String(list[i].id)] = String(list[i].tiledLayout || "")
  } catch (e) {}
  return layouts
}

function logicalWidth(monitor) {
  if (!monitor) return 0
  var scale = Number(monitor.scale) || 1
  var ipc = monitor.lastIpcObject || {}
  var transform = Number(ipc.transform) || 0
  var px = (transform % 2 === 1) ? Number(monitor.height) : Number(monitor.width)
  if (!isFinite(px) || px <= 0) return 0
  return Math.round(px / scale)
}

function logicalHeight(monitor) {
  if (!monitor) return 0
  var scale = Number(monitor.scale) || 1
  var ipc = monitor.lastIpcObject || {}
  var transform = Number(ipc.transform) || 0
  var px = (transform % 2 === 1) ? Number(monitor.width) : Number(monitor.height)
  if (!isFinite(px) || px <= 0) return 0
  return Math.round(px / scale)
}

function parseCssGap(css, fallback) {
  var parts = String(css || "").trim().split(/\s+/).map(Number).filter(function(n) { return isFinite(n) })
  if (parts.length === 0) return fallback
  if (parts.length === 1) return { top: parts[0], right: parts[0], bottom: parts[0], left: parts[0] }
  if (parts.length === 2) return { top: parts[0], right: parts[1], bottom: parts[0], left: parts[1] }
  if (parts.length === 3) return { top: parts[0], right: parts[1], bottom: parts[2], left: parts[1] }
  return { top: parts[0], right: parts[1], bottom: parts[2], left: parts[3] }
}

function parseBaseGaps(rawJson, fallback) {
  try {
    return parseCssGap(JSON.parse(rawJson).css, fallback)
  } catch (e) {
    return fallback
  }
}

// Shrink the tiling area by parking slack in gaps_out on the unused sides.
function gapsFor(mode, monitorWidth, monitorHeight, base) {
  var gaps = { top: base.top, right: base.right, bottom: base.bottom, left: base.left }
  if (!mode || mode.id === "full") return gaps

  if (mode.align === "left" || mode.align === "right") {
    if (monitorWidth <= 0) return gaps
    var hSlack = Math.round(monitorWidth * (1 - mode.fraction))
    if (hSlack <= 0) return gaps
    if (mode.align === "left") gaps.right = Math.max(base.right, hSlack)
    else gaps.left = Math.max(base.left, hSlack)
    return gaps
  }

  if (mode.align === "top" || mode.align === "bottom") {
    if (monitorHeight <= 0) return gaps
    var vSlack = Math.round(monitorHeight * (1 - mode.fraction))
    if (vSlack <= 0) return gaps
    if (mode.align === "top") gaps.bottom = Math.max(base.bottom, vSlack)
    else gaps.top = Math.max(base.top, vSlack)
  }
  return gaps
}

function asInt(value) {
  var n = parseInt(value, 10)
  return isFinite(n) ? n : null
}

function luaRule(workspaceId, gaps) {
  var id = asInt(workspaceId)
  if (id === null) return ""
  var top = asInt(gaps.top), right = asInt(gaps.right)
  var bottom = asInt(gaps.bottom), left = asInt(gaps.left)
  if (top === null || right === null || bottom === null || left === null) return ""
  return "hl.workspace_rule({ workspace = \"" + id + "\", gaps_out = { top = " + top
    + ", right = " + right + ", bottom = " + bottom + ", left = " + left + " } })"
}

var STATE_MARKER = "-- agileautomation-workspace-bands:"

function stateHeader(mode) {
  return STATE_MARKER + " mode=" + mode.id
}

function shellQuote(value) {
  return "'" + String(value).replace(/'/g, "'\\''") + "'"
}

function stateFile(stateDir, workspaceId) {
  return stateDir + "/band-" + asInt(workspaceId) + ".lua"
}

function persistable(workspaceId) {
  return workspaceId >= 1
}

// Persist into workspace-layouts so Omarchy reloads restore the band.
// Filenames are band-*.lua so they do not collide with rogergdot.panes.
function applyBandScript(stateDir, workspaceId, mode, gaps) {
  var rule = luaRule(workspaceId, gaps)
  if (rule === "") return ""
  var file = stateFile(stateDir, workspaceId)
  var lines = []

  if (mode.id === "full") {
    if (persistable(workspaceId)) lines.push("rm -f " + shellQuote(file))
  } else if (persistable(workspaceId)) {
    lines.push("mkdir -p " + shellQuote(stateDir))
    lines.push("printf '%s\\n%s\\n' " + shellQuote(stateHeader(mode)) + " " + shellQuote(rule) + " > " + shellQuote(file))
  }

  lines.push("hyprctl eval " + shellQuote(rule) + " >/dev/null")
  return lines.join("\n")
}

function loadBandScript(stateDir) {
  // Also match the pre-rename marker so existing band-*.lua files still load.
  return "grep -H -E " + shellQuote("^(-- agileautomation-workspace-bands:|-- mike-workspace-bands:|-- mike-scrolling-columns-band:)")
    + " " + shellQuote(stateDir) + "/band-*.lua 2>/dev/null || true"
}

function parseBandState(raw) {
  var state = {}
  var lines = String(raw || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i]
    var fileMatch = line.match(/band-(-?\d+)\.lua:/)
    var modeMatch = line.match(/mode=([a-z0-9-]+)/)
    if (!fileMatch || !modeMatch) continue
    state[fileMatch[1]] = { mode: modeMatch[1] }
  }
  return state
}

function setLayoutScript(stateDir, workspaceId, layout) {
  var id = asInt(workspaceId)
  if (id === null) return ""
  if (layout !== "dwindle" && layout !== "scrolling") return ""
  var file = stateDir + "/" + id + ".lua"
  var rule = "hl.workspace_rule({ workspace = \"" + id + "\", layout = \"" + layout + "\" })"
  var lines = []
  lines.push("mkdir -p " + shellQuote(stateDir))
  lines.push("printf '%s\\n' " + shellQuote(rule) + " > " + shellQuote(file))
  lines.push("hyprctl eval " + shellQuote(rule) + " >/dev/null")
  return lines.join("\n")
}

// Apply scrolling column width using schema widths, clear bands, switch layout.
function applyColumnsScript(cliPath, columns, stateDir, workspaceId, baseGaps, oneWidth, twoWidth, threeWidth) {
  var cols = asInt(columns)
  if (cols === null || cols < 1 || cols > 3) return ""
  var full = { id: "full", align: "full", fraction: 1 }
  var gaps = gapsFor(full, 0, 0, baseGaps)
  var lines = []
  var layout = setLayoutScript(stateDir, workspaceId, "scrolling")
  if (layout) lines.push(layout)
  var clear = applyBandScript(stateDir, workspaceId, full, gaps)
  if (clear) lines.push(clear)
  lines.push(
    "SCROLLING_COLUMNS_ONE=" + shellQuote(String(clampWidth(oneWidth, 0.96)))
    + " SCROLLING_COLUMNS_TWO=" + shellQuote(String(clampWidth(twoWidth, 0.49)))
    + " SCROLLING_COLUMNS_THREE=" + shellQuote(String(clampWidth(threeWidth, 0.32)))
    + " " + shellQuote(cliPath) + " set " + cols
  )
  return lines.join("\n")
}
