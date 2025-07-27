local InfoMessage = require("ui/widget/infomessage")
local ButtonDialog = require("ui/widget/buttondialog")
local UIManager = require("ui/uimanager")
local Trapper = require("ui/trapper")
local _ = require("gettext")


local LoadingDialog = {}

--- Shows a message in a info dialog, while running the given `runnable` function.
--- Must be called from inside a function wrapped with `Trapper:wrap()`.
---
--- @generic T: any
--- @param message string The message to be shown on the dialog.
--- @param runnable fun(): T The function to be ran while showing the dialog.
--- @param dismissable boolean Whether the dialog can be dismissed by the user.
--- @return T
function LoadingDialog:showAndRun(message, runnable, dismissable)
  assert(Trapper:isWrapped(), "expected to be called inside a function wrapped with `Trapper:wrap()`")

  local message_dialog = InfoMessage:new {
    text = _(message),
    dismissable = dismissable,
  }

  UIManager:show(message_dialog)
  UIManager:forceRePaint()

  local completed, return_values = Trapper:dismissableRunInSubprocess(runnable, message_dialog)
  if not dismissable then
    assert(completed, "expected runnable to complete without being cancelled")
  end

  if not completed then
    return nil
  end

  UIManager:close(message_dialog)

  return return_values
end

return LoadingDialog
