local Device = require("device")
local InfoMessage = require("ui/widget/infomessage")
local InputContainer = require("ui/widget/container/inputcontainer")
local FileManager = require("apps/filemanager/filemanager")
local UIManager = require("ui/uimanager")
local logger = require("logger")
local _ = require("gettext")
local OfflineAlertDialog = require("OfflineAlertDialog")

local Backend = require("Backend")
local ErrorDialog = require("ErrorDialog")
local LibraryView = require("LibraryView")
local MangaReader = require("MangaReader")
local Testing = require("testing")

logger.info("Loading Yuruyomi plugin...")
local backendInitialized, logs = Backend.initialize()

local Yuruyomi = InputContainer:extend({
  name = "yuruyomi"
})

-- We can get initialized from two contexts:
-- - when the `FileManager` is initialized, we're called
-- - when the `ReaderUI` is initialized, we're also called
-- so we should register to the menu accordingly
function Yuruyomi:init()
  logger.info("Yuruyomi:init() called, UI name:", self.ui.name)
  
  if self.ui.name == "ReaderUI" then
    logger.info("Initializing MangaReader from ReaderUI")
    MangaReader:initializeFromReaderUI(self.ui)
    logger.info("MangaReader initialization complete")
  else
    logger.info("Registering to main menu")
    self.ui.menu:registerToMainMenu(self)
    logger.info("Main menu registration complete")
  end

  logger.info("Initializing Testing module")
  Testing:init()
  logger.info("Emitting initialized event")
  Testing:emitEvent('initialized')
  logger.info("Yuruyomi:init() complete")
end

function Yuruyomi:addToMainMenu(menu_items)
  menu_items.yuruyomi = {
    text = _("Yuruyomi"),
    sorting_hint = "search",
    callback = function()
      if not backendInitialized then
        self:showErrorDialog()

        return
      end

      self:openLibraryView()
    end
  }
end

function Yuruyomi:showErrorDialog()
  ErrorDialog:show(
    "Oops! Yuruyomi encountered an issue while starting up!\n" ..
    "Here are some messages that might help identify the problem:\n\n" ..
    logs
  )
end

function Yuruyomi:openLibraryView()
  LibraryView:fetchAndShow()
  OfflineAlertDialog:showIfOffline()
end

return Yuruyomi
