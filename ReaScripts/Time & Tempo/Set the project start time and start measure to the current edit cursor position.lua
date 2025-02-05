-- Set the project start time and start measure to the current edit cursor position

-- Get the current project
local currentProject = 0 -- 0 means the current project

-- Get the position of the edit cursor
local cursorTime = reaper.GetCursorPosition()

-- Convert cursor position to measure (not sure what dummy does, but it seems to be needed to get the measure number)
local _, cursorMeasure = reaper.TimeMap2_timeToBeats(currentProject,cursorTime)
local cursorMeasureTime = reaper.TimeMap_GetMeasureInfo(currentProject,cursorMeasure)

-- Change project start time and measure to edit cursor
reaper.SNM_SetDoubleConfigVar("projtimeoffs", -cursorMeasureTime)
reaper.SNM_SetIntConfigVar("projmeasoffs", -cursorMeasure)

-- Base ruler label spacing on start measure
reaper.SNM_SetIntConfigVar("projmeasoffsruler",1)

-- Update the arrangement view
reaper.UpdateTimeline()
reaper.UpdateArrange()
