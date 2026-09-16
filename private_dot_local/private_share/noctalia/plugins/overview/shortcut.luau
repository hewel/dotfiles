--!nonstrict
-- Control-center tile: open the workspace overview panel.

local function render()
	shortcut.setLabel(noctalia.tr("ui.title"))
	shortcut.setIcon("layout-board")
	shortcut.setActive(false)
	shortcut.setEnabled(true)
end

function onClick()
	noctalia.togglePanel("hewel/overview:panel")
end

render()
