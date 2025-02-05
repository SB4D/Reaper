--[[ ReaScript written in Lua for Reaper 7.28

Title:    Create tempo map from project markers
Version:  0.2
Author:   Stefan Behrens
Date:     2025-01-12

DESCRIPTION / INSTRUCTIONS:
coming coon...

CHANGELOG:
0.2: 
- added undo block
- time signature from user input
- fixed a bug in quater notes per bar computation

0.1: 
- core functions working, tested IRL

--]]

--== TEST AREA
--reaper.ClearConsole()


--[ KILL SWITCH

--== PREPARATION ==--

-- Start undo block
reaper.Undo_BeginBlock()

-- Store current project timebase
local error_value_int = 909
local original_timebase = reaper.SNM_GetIntConfigVar("itemtimelock",error_value_int)

-- Temporarily set project timebase to time
local timebase_time = 0 
reaper.SNM_SetIntConfigVar("itemtimelock",timebase_time)


-- Get time signature from user input

--- Get time signature as string in the format 4/4, 6/8, etc
_, timesig_str = reaper.GetUserInputs("Create tempo map from project markers", 1, "Time signature of the song:", "4/4")

--- TO DO: Check if format is correct

--- Split time signature string at "/"
local timesig_split_str = {}
for part in string.gmatch(timesig_str, "([^/]+)") do
    table.insert(timesig_split_str, part)
end

--- Get time signature numerator and denominator as numbers
local timesig_num = tonumber(timesig_split_str[1])
local timesig_denom = tonumber(timesig_split_str[2])


--== TEMPO COMPUTATION FOR SECTIONS ==--

-- Get number of project markers
local marker_count = reaper.CountProjectMarkers(0)

-- Get section marker times and section length
local section_start_times = {}
local bars_in_sections = {}

for i = 0,marker_count-1 do
  local _, _, marker_time, _, marker_name = reaper.EnumProjectMarkers(i)
  local _, _, _, _, marker_name = reaper.EnumProjectMarkers(i+1)
  section_start_times[i] = marker_time
  bars_in_sections[i] = tonumber(marker_name)
end

-- Compute quarter notes per bar
local qn_per_bar = timesig_num / timesig_denom * 4

-- Compute bpm per section
local section_bpms = {}

for i = 0,marker_count-2 do
  section_bpms[i] = 60*bars_in_sections[i] * qn_per_bar / (section_start_times[i+1] - section_start_times[i])
end

--== MARKER CONVERSION ==--

-- Delete project markers
for marker_index = 1,marker_count do
reaper.DeleteProjectMarker(0, marker_index, false)
end

-- Insert section regions and tempo change markers
for i = 0,marker_count-2 do
  -- Insert section region
  region_start = section_start_times[i]
  region_end = section_start_times[i+1]
  region_name = bars_in_sections[i].." bar section"
  is_region = true
  region_id = i+1
  reaper.AddProjectMarker(0, is_region, region_start, region_end, region_name, region_id)
  -- Add tempo markers
  if i==0 or (i > 0 and section_bpms[i] ~= section_bpms[i-1]) 
    then reaper.AddTempoTimeSigMarker(0, section_start_times[i], section_bpms[i], timesig_num, timesig_denom, 0)
  end
end


--== CLEAN UP ==--

-- Reset project timebase
reaper.SNM_SetIntConfigVar("itemtimelock",original_timebase)

-- Update view
reaper.UpdateArrange()
reaper.UpdateTimeline()

-- End undo block
reaper.Undo_EndBlock("Create tempo map from project markers",-1)


--[[ TEST
reaper.ClearConsole()

for i = 0,marker_count-2 do
  reaper.ShowConsoleMsg(section_bpms[i].."\t"..section_start_times[i].."\n")
end

--]]
