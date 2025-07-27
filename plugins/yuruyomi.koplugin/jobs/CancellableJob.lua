local logger = require("logger")
local UIManager = require("ui/uimanager")
local Backend = require("Backend")

--- @class CancellableJob
--- @field job_id string|nil
--- @field is_cancelled boolean
--- @field poll_interval number
local CancellableJob = {}

function CancellableJob:extend()
  local o = {}
  setmetatable(o, self)
  self.__index = self

  return o
end

--- Creates a new cancellable download instance
--- @param poll_interval number? Polling interval in seconds (default: 2)
--- @return CancellableJob job A new job instance
function CancellableJob:new(poll_interval)
  local instance = {
    job_id = nil,
    is_cancelled = false,
    poll_interval = poll_interval or 2, -- Poll every 2 seconds instead of continuous
  }
  setmetatable(instance, self)
  return instance
end

--- Starts a download chapter job with cancellation support
--- @param source_id string
--- @param manga_id string
--- @param chapter_id string
--- @param chapter_num number?
--- @param onProgress function? Callback for progress updates
--- @param onComplete function? Callback for completion
--- @param onError function? Callback for errors
--- @param onCancel function? Callback for cancellation
function CancellableJob:startDownload(source_id, manga_id, chapter_id, chapter_num, onProgress, onComplete, onError,
                                      onCancel)
  if self.job_id then
    logger.warn("Download already in progress")
    return
  end

  -- Create the download job
  local job_response = Backend.createDownloadChapterJob(source_id, manga_id, chapter_id, chapter_num)

  if job_response.type == 'ERROR' then
    logger.err("Failed to create download job:", job_response.message)
    if onError then onError(job_response.message) end
    return
  end

  self.job_id = job_response.body
  self.is_cancelled = false

  logger.info("Started download job:", self.job_id)
  if onProgress then onProgress("Starting download...") end

  -- Start polling for job completion
  self:_pollJobStatus(onProgress, onComplete, onError, onCancel)
end

--- Cancels the current download
function CancellableJob:cancel()
  if not self.job_id then
    logger.warn("No active download to cancel")
    return
  end

  self.is_cancelled = true

  -- Request backend cancellation
  local cancel_response = Backend.requestJobCancellation(self.job_id)
  if cancel_response.type == 'ERROR' then
    logger.err("Failed to cancel job:", cancel_response.message)
  else
    logger.info("Requested cancellation for job:", self.job_id)
  end
end

--- Internal method to poll job status
--- @private
function CancellableJob:_pollJobStatus(onProgress, onComplete, onError, onCancel)
  if self.is_cancelled then
    if onCancel then onCancel() end
    self:_cleanup()
    return
  end

  -- Check job status with timeout
  local status_response = Backend.getJobDetails(self.job_id)

  if status_response.type == 'ERROR' then
    logger.err("Failed to get job status:", status_response.message)
    if onError then onError(status_response.message) end
    self:_cleanup()
    return
  end

  local job_details = status_response.body

  if job_details.type == 'PENDING' then
    -- Still in progress, schedule next poll
    if onProgress then onProgress("Downloading...") end

    UIManager:scheduleIn(self.poll_interval, function()
      self:_pollJobStatus(onProgress, onComplete, onError, onCancel)
    end)
  elseif job_details.type == 'COMPLETED' then
    -- Download completed successfully
    logger.info("Download completed:", self.job_id)
    if onComplete then onComplete(job_details.data) end
    self:_cleanup()
  elseif job_details.type == 'ERROR' then
    -- Download failed
    logger.err("Download failed:", job_details.data.message)
    if onError then onError(job_details.data.message) end
    self:_cleanup()
  end
end

--- Cleanup internal state
--- @private
function CancellableJob:_cleanup()
  self.job_id = nil
  self.is_cancelled = false
end

--- Checks if download is active
--- @return boolean
function CancellableJob:isActive()
  return self.job_id ~= nil
end

return CancellableJob
