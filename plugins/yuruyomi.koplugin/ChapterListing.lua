local time = require("ui/time")
local BD = require("ui/bidi")
local ButtonDialog = require("ui/widget/buttondialog")
local InfoMessage = require("ui/widget/infomessage")
local InputDialog = require("ui/widget/inputdialog")
local UIManager = require("ui/uimanager")
local Trapper = require("ui/trapper")
local Screen = require("device").screen
local logger = require("logger")
local LoadingDialog = require("LoadingDialog")
local util = require("util")

local Backend = require("Backend")
local CancellableJob = require("jobs/CancellableJob")
local DownloadChapter = require("jobs/DownloadChapter")
local DownloadUnreadChapters = require("jobs/DownloadUnreadChapters")
local DownloadUnreadChaptersJobDialog = require("DownloadUnreadChaptersJobDialog")
local Icons = require("Icons")
local Menu = require("widgets/Menu")
local ErrorDialog = require("ErrorDialog")
local MangaReader = require("MangaReader")
local Testing = require("testing")

local findNextChapter = require("chapters/findNextChapter")

--- @class ChapterListing : { [any]: any }
--- @field manga Manga
--- @field chapters Chapter[]
--- @field chapter_sorting_mode ChapterSortingMode
local ChapterListing = Menu:extend {
  name = "chapter_listing",
  is_enable_shortcut = false,
  is_popout = false,
  title = "Chapter listing",
  align_baselines = true,

  -- the manga we're listing
  manga = nil,
  -- list of chapters
  chapters = {},
  chapter_sorting_mode = nil,
  -- callback to be called when pressing the back button
  on_return_callback = nil,
  -- scanlator filtering
  selected_scanlator = nil,
  available_scanlators = {},
}

function ChapterListing:init()
  self.title_bar_left_icon = "appbar.menu"
  self.onLeftButtonTap = function()
    self:openMenu()
  end

  self.width = Screen:getWidth()
  self.height = Screen:getHeight()

  -- FIXME `Menu` calls `updateItems()` during init, but we haven't fetched any items yet, as
  -- we do it in `updateChapterList`. Not sure if there's any downside to it, but here's a notice.
  Menu.init(self)

  -- we need to fill this with *something* in order to Koreader actually recognize
  -- that the back button is active, so yeah
  -- we also need to set this _after_ the `Menu.init` call, because it changes
  -- this value to {}
  self.paths = {
    { callback = self.on_return_callback },
  }
  -- idk might make some gc shenanigans actually work
  self.on_return_callback = nil

  -- we need to do this after updating
  self:updateChapterList()
end

--- Fetches the cached chapter list from the backend and updates the menu items.
function ChapterListing:updateChapterList()
  local response = Backend.listCachedChapters(self.manga.source.id, self.manga.id)

  if response.type == 'ERROR' then
    ErrorDialog:show(response.message)

    return
  end

  local chapter_results = response.body
  self.chapters = chapter_results

  self:extractAvailableScanlators()

  self:loadSavedScanlatorPreference()

  self:updateItems()
end

-- Load saved scanlator preference from backend
function ChapterListing:loadSavedScanlatorPreference()
  local response = Backend.getPreferredScanlator(self.manga.source.id, self.manga.id)

  self.selected_scanlator = nil

  if response.type == 'SUCCESS' and response.body then
    for _, available_scanlator in ipairs(self.available_scanlators) do
      if available_scanlator == response.body then
        self.selected_scanlator = response.body
        break
      end
    end
  end
end

-- Extract unique scanlators
function ChapterListing:extractAvailableScanlators()
  local scanlators = {}
  local scanlator_set = {}

  for _, chapter in ipairs(self.chapters) do
    local scanlator = chapter.scanlator or "Unknown"
    if not scanlator_set[scanlator] then
      scanlator_set[scanlator] = true
      table.insert(scanlators, scanlator)
    end
  end

  table.sort(scanlators)

  self.available_scanlators = scanlators
end

--- Updates the menu item contents with the chapter information
--- @private
function ChapterListing:updateItems()
  if #self.chapters > 0 then
    self.item_table = self:generateItemTableFromChapters(self.chapters)
    self.multilines_show_more_text = false
    self.items_per_page = nil
  else
    self.item_table = self:generateEmptyViewItemTable()
    self.multilines_show_more_text = true
    self.items_per_page = 1
  end

  Menu.updateItems(self)
end

--- @private
function ChapterListing:generateEmptyViewItemTable()
  return {
    {
      text = "No chapters found. Try swiping down to refresh the chapter list.",
      dim = true,
      select_enabled = false,
    }
  }
end

--- Compares whether chapter `a` is before `b`. Expects the `index` of the chapter in the
--- chapter array to be present inside the chapter object.
---
--- @param a Chapter|{ index: number }
--- @param b Chapter|{ index: number }
--- @return boolean `true` if chapter `a` should be displayed before `b`, otherwise `false`.
local function isBeforeChapter(a, b)
  if a.volume_num ~= nil and b.volume_num ~= nil and a.volume_num ~= b.volume_num then
    return a.volume_num < b.volume_num
  end

  if a.chapter_num ~= nil and b.chapter_num ~= nil and a.chapter_num ~= b.chapter_num then
    return a.chapter_num < b.chapter_num
  end

  -- This is _very_ flaky, but we assume that source order is _always_ from newer chapters -> older chapters.
  -- Unfortunately we need to make some kind of assumptions here to handle edgecases (e.g. chapters without a chapter number)
  return a.index > b.index
end

--- @private
function ChapterListing:generateItemTableFromChapters(chapters)
  -- Filter chapters by selected scanlator
  local filtered_chapters = chapters
  if self.selected_scanlator then
    filtered_chapters = {}
    for _, chapter in ipairs(chapters) do
      local chapter_scanlator = chapter.scanlator or "Unknown"
      if chapter_scanlator == self.selected_scanlator then
        table.insert(filtered_chapters, chapter)
      end
    end
  end

  --- @type table
  --- @diagnostic disable-next-line: assign-type-mismatch
  local sorted_chapters_with_index = util.tableDeepCopy(filtered_chapters)
  for index, chapter in ipairs(sorted_chapters_with_index) do
    chapter.index = index
  end

  if self.chapter_sorting_mode == 'chapter_ascending' then
    table.sort(sorted_chapters_with_index, isBeforeChapter)
  else
    table.sort(sorted_chapters_with_index, function(a, b) return not isBeforeChapter(a, b) end)
  end

  local item_table = {}

  for _, chapter in ipairs(sorted_chapters_with_index) do
    local text = ""
    if chapter.volume_num ~= nil then
      -- FIXME we assume there's a chapter number if there's a volume number
      -- might not be true but who knows
      text = text .. "Volume " .. chapter.volume_num .. ", "
    end

    if chapter.chapter_num ~= nil then
      text = text .. "Chapter " .. chapter.chapter_num .. " - "
    end

    text = text .. chapter.title

    -- Only show scanlator if not filtering by scanlator
    if chapter.scanlator ~= nil and not self.selected_scanlator then
      text = text .. " (" .. chapter.scanlator .. ")"
    end

    -- The text that shows to the right of the menu item
    local mandatory = ""
    if chapter.read then
      mandatory = mandatory .. Icons.FA_BOOK
    end

    if chapter.downloaded then
      mandatory = mandatory .. Icons.FA_DOWNLOAD
    end

    table.insert(item_table, {
      chapter = chapter,
      text = text,
      mandatory = mandatory,
    })
  end

  return item_table
end

--- @private
function ChapterListing:onReturn()
  local path = table.remove(self.paths)

  self:onClose()
  path.callback()
end

--- Shows the chapter list for a given manga. Must be called from a function wrapped with `Trapper:wrap()`.
---
--- @param manga Manga
--- @param onReturnCallback fun(): nil
--- @param accept_cached_results? boolean If set, failing to refresh the list of chapters from the source
--- will not show an error. Defaults to false.
function ChapterListing:fetchAndShow(manga, onReturnCallback, accept_cached_results)
  accept_cached_results = accept_cached_results or false

  local refresh_chapters_response = LoadingDialog:showAndRun(
    "Refreshing chapters...",
    function()
      return Backend.refreshChapters(manga.source.id, manga.id)
    end
  )

  if not accept_cached_results and refresh_chapters_response.type == 'ERROR' then
    ErrorDialog:show(refresh_chapters_response.message)

    return
  end

  local response = Backend.getSettings()

  if response.type == 'ERROR' then
    ErrorDialog:show(response.message)

    return
  end

  local settings = response.body

  UIManager:show(ChapterListing:new {
    manga = manga,
    chapter_sorting_mode = settings.chapter_sorting_mode,
    on_return_callback = onReturnCallback,
    covers_fullscreen = true, -- hint for UIManager:_repaint()
  })

  Testing:emitEvent("chapter_listing_shown")
end

--- @private
function ChapterListing:onPrimaryMenuChoice(item)
  local chapter = item.chapter

  self:openChapterOnReader(chapter)
end

--- @private
function ChapterListing:onSwipe(arg, ges_ev)
  local direction = BD.flipDirectionIfMirroredUILayout(ges_ev.direction)
  if direction == "south" then
    self:refreshChapters()

    return
  end

  Menu.onSwipe(self, arg, ges_ev)
end

--- @private
function ChapterListing:refreshChapters()
  Trapper:wrap(function()
    local refresh_chapters_response = LoadingDialog:showAndRun(
      "Refreshing chapters...",
      function()
        return Backend.refreshChapters(self.manga.source.id, self.manga.id)
      end
    )

    if refresh_chapters_response.type == 'ERROR' then
      ErrorDialog:show(refresh_chapters_response.message)

      return
    end

    self:updateChapterList()
  end)
end

--- @private
--- @param chapter Chapter
--- @param download_job DownloadChapter|nil
function ChapterListing:openChapterOnReader(chapter, download_job)
  Trapper:wrap(function()
    self:_openChapterOnReaderV2(chapter, download_job)
  end)
end


--- @private
--- @param chapter Chapter
--- @param download_job CancellableJob|nil
function ChapterListing:_openChapterOnReaderV2(chapter, download_job)

    -- If the download job we have is already invalid (internet problems, for example),
    -- spawn a new job before proceeding.
    if download_job == nil or download_job:poll().type == 'ERROR' then
      download_job = CancellableJob:new(1.5,15,3)
    end

    if download_job == nil then
      ErrorDialog:show('Could not download chapter.')
      return
    end

    local start_time = time.now()

    local progress_dialog
    progress_dialog = ButtonDialog:new {
      title = ("Downloading chapter ..."),
      title_align = "center",
      buttons = {
        {
          {
            text = "Cancel",
            callback = function()
              -- download_job:cancel()
              UIManager:close(progress_dialog)
            end,
          },
        }
      }
    }

    UIManager:show(progress_dialog)


    -- TODO: basically it doesn't have startDownload method
    if not download_job.startDownload or type(download_job.startDownload) ~= "function" then
      logger.err("Download job missing startDownload method:", type(download_job.startDownload))
      return
    end

    download_job:startDownload(
      chapter.source_id,
      chapter.manga_id,
      chapter.id,
      chapter.chapter_num,
      -- onProgress callback
      function(progress)
        progress_dialog:setText(("Downloading chapter... %d%%"):format(progress))
        UIManager:setDirty(progress_dialog, "ui")
      end,
      -- onComplete
      function(manga_path)
        -- Ensure dialog is closed before proceeding
        UIManager:close(progress_dialog)
        self:_openReaderWithPathV2(self.chapters, chapter, manga_path)

        logger.info("Download completed in ", time.to_ms(time.since(start_time)), "ms.")
      end,
      -- onError callback
      function(error_message)
        -- Ensure dialog is closed before showing error
        UIManager:close(progress_dialog)
        ErrorDialog:show("Download failed. Please try again.")
        logger.warn("Chapter download failed for security reasons")
      end,
      -- onCancel callback
      function()
        -- Ensure dialog is closed (although the cancel button already does this)
        UIManager:close(progress_dialog)
        logger.info("Chapter download cancelled by user")
      end
    )
end


--- @private
--- @param chapter Chapter
--- @param download_job DownloadChapter|nil
function ChapterListing:_openChapterOnReader(chapter, download_job)
    -- If the download job we have is already invalid (internet problems, for example),
    -- spawn a new job before proceeding.
    if download_job == nil or download_job:poll().type == 'ERROR' then
      download_job = DownloadChapter:new(chapter.source_id, chapter.manga_id, chapter.id, chapter.chapter_num)
    end

    if download_job == nil then
      ErrorDialog:show('Could not download chapter.')

      return
    end

    local time = require("ui/time")
    local start_time = time.now()
    local response = LoadingDialog:showAndRun(
      "Downloading chapter...",
      function()
        return download_job:runUntilCompletion()
      end
    )

    if response.type == 'ERROR' then
      ErrorDialog:show(response.message)

      return
    end

    -- FIXME Mutating here _still_ sucks, we gotta think of a better way.
    chapter.downloaded = true

    local manga_path = response.body

    logger.info("Waited ", time.to_ms(time.since(start_time)), "ms for download job to finish.")

    self:_openReaderWithPath(self.chapters, chapter, manga_path)

end

--- @private
--- @param chapter Chapter
--- @param manga_path string
function ChapterListing:_openReaderWithPath(all_chapters, chapter, manga_path)
  -- Preload next chapter download job (non-blocking)
  local nextChapter = findNextChapter(all_chapters, chapter)
  local nextChapterDownloadJob = nil

  if nextChapter ~= nil then
    nextChapterDownloadJob = DownloadChapter:new(
      nextChapter.source_id,
      nextChapter.manga_id,
      nextChapter.id,
      nextChapter.chapter_num
    )
  end

  local onReturnCallback = function()
    self:updateItems()
    UIManager:show(self)
  end

  local onEndOfBookCallback = function()
    -- Secure API call with timeout
    local mark_read_response = Backend.markChapterAsRead(chapter.source_id, chapter.manga_id, chapter.id)

    if mark_read_response.type == 'ERROR' then
      logger.warn("Failed to mark chapter as read:", mark_read_response.message)
      -- Continue anyway - don't block user experience
    end

    self:updateChapterList()

    -- TODO: instead of opening a download job, should immediately verify if file exist / not
    if nextChapter ~= nil then
      logger.info("opening next chapter", nextChapter)
      self:openChapterOnReader(nextChapter, nextChapterDownloadJob)
    else
      MangaReader:closeReaderUi(function()
        UIManager:show(self)
      end)
    end
  end

  MangaReader:show({
    path = manga_path,
    on_end_of_book_callback = onEndOfBookCallback,
    on_return_callback = onReturnCallback,
  })

  self:onClose()
end


--- @private
--- @param chapter Chapter
--- @param manga_path string
function ChapterListing:_openReaderWithPathV2(all_chapters, chapter, manga_path)
  -- Preload next chapter download job (non-blocking)
  local nextChapter = findNextChapter(all_chapters, chapter)
  local nextChapterDownloadJob = nil
  local nextChapterPath = nil -- Store the downloaded path when ready

  if nextChapter ~= nil then
    nextChapterDownloadJob = CancellableJob:new(2,30,3)
    nextChapterDownloadJob:startDownload(
      nextChapter.source_id,
      nextChapter.manga_id,
      nextChapter.id,
      nextChapter.chapter_num,
      -- onProgress callback (should be empty for next chapter)
      function(msg)
        logger.info("Preloading next chapter download progress: " .. msg)
      end,
      -- onComplete callback - STORE PATH for later use
      function(manga_path_result)
        if manga_path_result and not manga_path_result:find("%.%.") then
          nextChapterPath = manga_path_result
          nextChapter.downloaded = true
          logger.info("Background download completed for next chapter:", nextChapter.title or "unknown")
        else
          logger.warn("Invalid background download path received")
          nextChapterDownloadJob = nil -- Mark as failed
        end
      end,
      -- onError callback - SILENT ERROR HANDLING (don't interrupt reading)
      function(error_message)
        logger.warn("Background download failed for next chapter:", error_message)
        nextChapterDownloadJob = nil -- Mark as failed, will fall back to on-demand download
      end,
      -- onCancel callback - SILENT CANCELLATION
      function()
        logger.info("Background download cancelled for next chapter")
        nextChapterDownloadJob = nil
      end
    )
  end


  local onReturnCallback = function()
    self:updateItems()
    UIManager:show(self)
  end

  local onEndOfBookCallback = function()
    -- Secure API call with timeout
    local mark_read_response = Backend.markChapterAsRead(chapter.source_id, chapter.manga_id, chapter.id)

    if mark_read_response.type == 'ERROR' then
      logger.warn("Failed to mark chapter as read:", mark_read_response.message)
      -- Continue anyway - don't block user experience
    end

    self:updateChapterList()

    if nextChapter ~= nil then
      if nextChapterPath then
        -- If we have a predownloaded path, show choice dialog
        self:_showNextChapterChoiceWithPredownload(nextChapter, nextChapterPath)
      else
        -- Otherwise, show download choice dialog
        self:_showNextChapterChoiceWithDownload(nextChapter)
      end
    else
      MangaReader:closeReaderUi(function()
        UIManager:show(self)
      end)
    end
  end

  MangaReader:show({
    path = manga_path,
    on_end_of_book_callback = onEndOfBookCallback,
    on_return_callback = onReturnCallback,
  })

  self:onClose()
end


--- Shows choice dialog when next chapter is already downloaded in background
--- @private
--- @param nextChapter Chapter
--- @param predownloadedPath string
function ChapterListing:_showNextChapterChoiceWithPredownload(nextChapter, predownloadedPath)
  -- SECURITY: Input validation
  if not nextChapter or not predownloadedPath then
    logger.err("Invalid parameters for predownloaded chapter choice")
    self:_showNextChapterChoiceWithDownload(nextChapter) -- Fallback
    return
  end

  local choice_dialog
  choice_dialog = ButtonDialog:new{
    title = "Chapter finished!" .. "\n" .. "(Next chapter ready)",
    title_align = "center",
    buttons = {
      {
        {
          text = "Read Next Chapter" .. " " .. Icons.FA_BOLT, -- Lightning bolt indicates instant
          callback = function()
            UIManager:close(choice_dialog)
            -- Instantly open - no download needed!
            self:_openReaderWithPathV2(self.chapters, nextChapter, predownloadedPath)
          end,
        },
      },
      {
        {
          text = "Back to Chapter List",
          callback = function()
            UIManager:close(choice_dialog)
            MangaReader:closeReaderUi(function()
              UIManager:show(self)
            end)
          end,
        },
      },
    },
  }

  UIManager:show(choice_dialog)
end

--- Shows choice dialog when next chapter needs to be downloaded
--- @private
--- @param nextChapter Chapter
function ChapterListing:_showNextChapterChoiceWithDownload(nextChapter)
  -- SECURITY: Input validation
  if not nextChapter or not nextChapter.source_id or not nextChapter.manga_id or not nextChapter.id then
    logger.err("Invalid next chapter data")
    ErrorDialog:show("Invalid next chapter data")
    return
  end

  local choice_dialog
  choice_dialog = ButtonDialog:new{
    title = "Chapter finished!",
    title_align = "center",
    buttons = {
      {
        {
          text = "Read Next Chapter",
          callback = function()
            UIManager:close(choice_dialog)
            -- Start cancellable download for next chapter
            self:_downloadAndOpenNextChapter(nextChapter)
          end,
        },
      },
      {
        {
          text = "Back to Chapter List",
          callback = function()
            UIManager:close(choice_dialog)
            MangaReader:closeReaderUi(function()
              UIManager:show(self)
            end)
          end,
        },
      },
    },
  }

  UIManager:show(choice_dialog)
end

--- Downloads and opens next chapter with cancellable progress dialog (when background download failed)
--- @private
--- @param nextChapter Chapter
function ChapterListing:_downloadAndOpenNextChapter(nextChapter)
  -- SECURITY: Input validation
  if not nextChapter then
    logger.err("No next chapter to download")
    ErrorDialog:show("Invalid next chapter")
    return
  end

  -- Create secure cancellable download instance
  local cancellable_download = CancellableJob:new(1.5, 15, 3)
  local time = require("ui/time")
  local start_time = time.now()

  -- Create progress dialog with cancel button - ONLY SHOWN DURING DOWNLOAD
  local progress_dialog = ButtonDialog:new{
    title = "Downloading next chapter...",
    title_align = "center",
    buttons = {
      {
        {
          text = "Cancel",
          callback = function()
            cancellable_download:cancel()
            UIManager:close(progress_dialog)
            logger.info("User cancelled next chapter download")

            -- Return to chapter list on cancellation
            MangaReader:closeReaderUi(function()
              UIManager:show(self)
            end)
          end,
        },
      },
    },
  }

  UIManager:show(progress_dialog)

  -- Start the secure cancellable download
  cancellable_download:startDownload(
    nextChapter.source_id,
    nextChapter.manga_id,
    nextChapter.id,
    nextChapter.chapter_num,
    -- onProgress callback - SECURE UI UPDATES
    function(message)
      if progress_dialog then
        -- SECURITY: Sanitize message to prevent injection attacks
        local safe_message = util.htmlEscape(tostring(message or ""))
        progress_dialog:setTitle(safe_message)
        UIManager:setDirty(progress_dialog, "ui")
      end
    end,
    -- onComplete callback - SECURE SUCCESS HANDLING
    function(manga_path)
      UIManager:close(progress_dialog)

      -- SECURITY: Validate file path - prevent path traversal
      if not manga_path or manga_path == "" or manga_path:find("%.%.") then
        ErrorDialog:show("Invalid download path received")
        logger.warn("Suspicious download path received:", util.getSafeFilename(manga_path or "nil", "", 20))

        -- Return to chapter list on error
        MangaReader:closeReaderUi(function()
          UIManager:show(self)
        end)
        return
      end

      -- SECURITY: Secure state mutation
      if nextChapter and type(nextChapter) == "table" then
        nextChapter.downloaded = true
      end

      logger.info("Next chapter download completed in", time.to_ms(time.since(start_time)), "ms")

      -- Recursively open next chapter (this will handle the next-next chapter when finished)
      self:_openReaderWithPathV2(self.chapters, nextChapter, manga_path)
    end,
    -- onError callback - SECURE ERROR HANDLING
    function(error_message)
      UIManager:close(progress_dialog)
      -- SECURITY: Show generic error to user
      ErrorDialog:show("Download failed. Returning to chapter list.")
      logger.warn("Next chapter download failed:", error_message)

      -- Return to chapter list on error
      MangaReader:closeReaderUi(function()
        UIManager:show(self)
      end)
    end,
    -- onCancel callback - SECURE CANCELLATION HANDLING
    function()
      UIManager:close(progress_dialog)
      logger.info("Next chapter download cancelled by user")

      -- Return to chapter list on cancellation
      MangaReader:closeReaderUi(function()
        UIManager:show(self)
      end)
    end
  )
end

--- @private
function ChapterListing:openMenu()
  local dialog

  local buttons = {
    {
      -- TODO: add few custom to buttons here (following Mihon)
      -- 1. Quickly download unread chapters on various numbers
      -- 2. Quickly change the sorting
      -- 3. Only show unread chapters
      {
        text = Icons.FA_DOWNLOAD .. " Download unread chapters…",
        callback = function()
          UIManager:close(dialog)

          self:onDownloadUnreadChapters()
        end
      }
      -- TODO: add to library button
      -- TODO: add make unread / remove read chapters
    }
  }

  -- Add scanlator filter button if multiple scanlators exist
  if #self.available_scanlators > 1 then
    local scanlator_text = self.selected_scanlator and
      (Icons.FA_FILTER .. " Group: " .. self.selected_scanlator) or
      Icons.FA_FILTER .. " Filter by Group"

    table.insert(buttons, {
      {
        text = scanlator_text,
        callback = function()
          UIManager:close(dialog)
          self:showScanlatorDialog()
        end
      }
    })
  end

  dialog = ButtonDialog:new {
    buttons = buttons,
  }

  UIManager:show(dialog)
end

-- Scanlator selection dialog with persistence
function ChapterListing:showScanlatorDialog()
  local dialog
  local buttons = {}

  -- Show All option
  table.insert(buttons, {
    {
      text = self.selected_scanlator == nil and Icons.FA_CHECK .. " Show All" or "Show All",
      callback = function()
        UIManager:close(dialog)
        self.selected_scanlator = nil

        Backend.setPreferredScanlator(self.manga.source.id, self.manga.id, nil)

        self:updateItems()
        UIManager:show(InfoMessage:new { text = "Showing all groups", timeout = 1 })
      end
    }
  })

  -- Individual scanlators
  for _, scanlator in ipairs(self.available_scanlators) do
    local is_selected = self.selected_scanlator == scanlator
    local text = is_selected and (Icons.FA_CHECK .. " " .. scanlator) or scanlator

    table.insert(buttons, {
      {
        text = text,
        callback = function()
          UIManager:close(dialog)
          self.selected_scanlator = scanlator

          Backend.setPreferredScanlator(self.manga.source.id, self.manga.id, scanlator)

          self:updateItems()
          UIManager:show(InfoMessage:new { text = "Filtered to: " .. scanlator, timeout = 1 })
        end
      }
    })
  end

  dialog = ButtonDialog:new {
    title = "Filter by Group",
    buttons = buttons,
  }

  UIManager:show(dialog)
end

function ChapterListing:onDownloadUnreadChapters()
  local input_dialog
  input_dialog = InputDialog:new {
    title = "Download unread chapters...",
    input_type = "number",
    input_hint = "Amount of unread chapters (default: all)",
    description = self.selected_scanlator and
      ("Will download from: " .. self.selected_scanlator .. "\n\nSpecify amount or leave empty for all.") or
      "Specify the amount of unread chapters to download, or leave empty to download all of them.",
    buttons = {
      {
        {
          text = "Cancel",
          id = "close",
          callback = function()
            UIManager:close(input_dialog)
          end,
        },
        {
          text = "Download",
          is_enter_default = true,
          callback = function()
            UIManager:close(input_dialog)

            local amount = nil
            if input_dialog:getInputText() ~= '' then
              amount = tonumber(input_dialog:getInputText())

              if amount == nil then
                ErrorDialog:show('Invalid amount of chapters!')

                return
              end
            end

            -- Use scanlator-aware download
            local job = self:createDownloadJob(amount)
            if job then
              local dialog = DownloadUnreadChaptersJobDialog:new({
                show_parent = self,
                job = job,
                dismiss_callback = function()
                  self:updateChapterList()
                end
              })

              dialog:show()
            else
              UIManager:show(InfoMessage:new {
                text = "No unread chapters found for " .. (self.selected_scanlator or "this manga"),
                timeout = 2,
              })
            end
          end,
        },
      }
    }
  }

  UIManager:show(input_dialog)
end

function ChapterListing:createDownloadJob(amount)
  return DownloadUnreadChapters:new({
    source_id = self.manga.source.id,
    manga_id = self.manga.id,
    amount = amount,
    scanlator = self.selected_scanlator
  })
end

function ChapterListing:onDownloadAllChapters()
  local downloadingMessage = InfoMessage:new {
    text = "Downloading all chapters, this will take a while…",
  }

  UIManager:show(downloadingMessage)

  -- FIXME when the backend functions become actually async we can get rid of this probably
  UIManager:nextTick(function()
    local time = require("ui/time")
    local startTime = time.now()
    local response = Backend.downloadAllChapters(self.manga.source.id, self.manga.id)

    if response.type == 'ERROR' then
      ErrorDialog:show(response.message)

      return
    end

    local onDownloadFinished = function()
      -- FIXME I don't think mutating the chapter list here is the way to go, but it's quicker
      -- than making another call to list the chapters from the backend...
      -- this also behaves wrong when the download fails but manages to download some chapters.
      -- some possible alternatives:
      -- - return the chapter list from the backend on the `downloadAllChapters` call
      -- - biting the bullet and making the API call
      for _, chapter in ipairs(self.chapters) do
        chapter.downloaded = true
      end

      logger.info("Downloaded all chapters in ", time.to_ms(time.since(startTime)), "ms")

      self:updateItems()
    end

    local updateProgress = function() end

    local cancellationRequested = false
    local onCancellationRequested = function()
      local response = Backend.cancelDownloadAllChapters(self.manga.source.id, self.manga.id)
      -- FIXME is it ok to assume there are no errors here?
      assert(response.type == 'SUCCESS')

      cancellationRequested = true

      updateProgress()
    end

    local onCancelled = function()
      local cancelledMessage = InfoMessage:new {
        text = "Cancelled.",
      }

      UIManager:show(cancelledMessage)
    end

    updateProgress = function()
      -- Remove any scheduled `updateProgress` calls, because we do not want this to be
      -- called again if not scheduled by ourselves. This may happen when `updateProgress` is called
      -- from another place that's not from the scheduler (eg. the `onCancellationRequested` handler),
      -- which could result in an additional `updateProgress` call that was already scheduled previously,
      -- even if we do not schedule it at the end of the method.
      UIManager:unschedule(updateProgress)
      UIManager:close(downloadingMessage)

      local response = Backend.getDownloadAllChaptersProgress(self.manga.source.id, self.manga.id)
      if response.type == 'ERROR' then
        ErrorDialog:show(response.message)

        return
      end

      local downloadProgress = response.body

      local messageText = nil
      local isCancellable = false
      if downloadProgress.type == "INITIALIZING" then
        messageText = "Downloading all chapters, this will take a while…"
      elseif downloadProgress.type == "FINISHED" then
        onDownloadFinished()

        return
      elseif downloadProgress.type == "CANCELLED" then
        onCancelled()

        return
      elseif cancellationRequested then
        messageText = "Waiting for download to be cancelled…"
      elseif downloadProgress.type == "PROGRESSING" then
        messageText = "Downloading all chapters, this will take a while… (" ..
            downloadProgress.downloaded .. "/" .. downloadProgress.total .. ")." ..
            "\n\n" ..
            "Tap outside this message to cancel."

        isCancellable = true
      else
        logger.err("unexpected download progress message", downloadProgress)

        error("unexpected download progress message")
      end

      downloadingMessage = InfoMessage:new {
        text = messageText,
        dismissable = isCancellable,
      }

      -- Override the default `onTapClose`/`onAnyKeyPressed` actions
      if isCancellable then
        local originalOnTapClose = downloadingMessage.onTapClose
        downloadingMessage.onTapClose = function(messageSelf)
          onCancellationRequested()

          originalOnTapClose(messageSelf)
        end

        local originalOnAnyKeyPressed = downloadingMessage.onAnyKeyPressed
        downloadingMessage.onAnyKeyPressed = function(messageSelf)
          onCancellationRequested()

          originalOnAnyKeyPressed(messageSelf)
        end
      end
      UIManager:show(downloadingMessage)

      UIManager:scheduleIn(1, updateProgress)
    end

    UIManager:scheduleIn(1, updateProgress)
  end)
end

return ChapterListing