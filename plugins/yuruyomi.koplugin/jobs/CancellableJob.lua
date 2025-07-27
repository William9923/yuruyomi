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
--- @param poll_timeout number? Individual poll timeout in seconds (default: 15)
--- @param max_retries number? Maximum retry attempts (default: 3)
--- @return CancellableJob job A new job instance
function CancellableJob:new(poll_interval, poll_timeout, max_retries)
  local instance = {
    job_id = nil,
    is_cancelled = false,
    poll_interval = poll_interval or 1,
    poll_timeout = poll_timeout or 15,
    max_retries = max_retries or 3,
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

  self.current_retries = 0
  if onProgress then
    onProgress("Starting download...")
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

  logger.info("Started download job for:", self.job_id, self.source_id, manga_id, chapter_id, chapter_num)

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
    self.current_retries = self.current_retries + 1
    logger.err("Failed to get job status:", status_response.message)
    if self.current_retries <= self.max_retries then
      logger.warn("Job status check failed, retrying", self.current_retries, "/", self.max_retries)
      if onProgress then onProgress(_("Connection issue, retrying...")) end

      -- SECURITY: Exponential backoff for retries - prevent overwhelming server
      local retry_delay = math.min(self.poll_interval * (2 ^ self.current_retries), 30)
      UIManager:scheduleIn(retry_delay, function()
        self:_pollJobStatus(onProgress, onComplete, onError, onCancel)
      end)
      return
    end

    -- Max retries exceeded - SECURITY: Fail securely
    local safe_error = _("Download failed after multiple attempts")
    logger.err("Max retries exceeded for job", self.job_id and self.job_id:sub(1, 8) .. "..." or "unknown")
    if onError then onError(safe_error) end
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
  self.current_retries = 0
end

--- Checks if download is active
--- @return boolean
function CancellableJob:isActive()
  return self.job_id ~= nil
end

return CancellableJob
