--[[ ReaScript (Lua): Compare notes in active take of selected midi item to specified grid

Author: Stefan Behrens (Streck0)
Date: 2025-02-05
Version: 0.4

DESCRIPTION:
- compares the note-on messages in active take of the selected MIDI item to a specified grid
- the distance to the nearest grid line is measured in milliseconds
- the evaluation (displayed in the console) includes a graph 
- "15 ms | >>>>>" means that ~5% of the notes are off grid within the 5 ms window centered around 15 ms
- the window size is set by user input

CHANGELOG:

0.4a.2:
- cleaned up output ("Diagnosis" section commented out)
- improved "Note quality evaluation"
- Rephrased the evaluation
- renamed from "How did I do? Evaluated recorded MIDI performance" to "Compare notes in active take of selected midi item to grid"
- updated description

0.4a.1:
- added quality evaluation (BUGGY!)

0.4a:
- (almost) complete rewrite
- test grid is now obtained from user input and is independent of project grid
- evaluation is still incomplete

previous:
- 0.3.3: code cleaned up from 0.3.2
- 0.3.3: added mean and standard deviation to performance statistics
- 0.3.4: added accuracy window statistics

--]]



--== PREPARATION ==--

-- Get user input: grid and window size

local grid_size = 1/16
local triplet_feel = false
local window size = 0.005

--- Get user input as csv string
local _, input_str = reaper.GetUserInputs("How did I do?",2,"Grid size (e.g. 1/8, 1/8T, etc):,Window size (in ms):","1/16,5")

--- Split csv string and comma
grid_str, window_str = input_str:match("([^,]+),([^,]+)")

--- Convert grid string to number
if grid_str:sub(-1) == "T" then
  triplet_feel = true
  grid_str = grid_str:sub(1,-2)
end
grid_denominator = tonumber(grid_str:sub(3))

--- Check input
function grid_check(number)
  for i=0,5 do
  if number == 2^i then return true end
  end
  return false
end

if grid_check(grid_denominator) == false then
  reaper.MB("Please enter one of the following grid sizes:\n\nstraight:\t1, 1/2, 1/4, 1/8, 1/16, 1/32\ntriplet:\t1/4T, 1/8T, 1/16T, 1/32T", "Error", 0)
    return
end

if tonumber(window_str) == nil then
  reaper.MB("Please a number as window size", "Error", 0)
    return
end

-- Set grid size
if triplet_feel == true 
  then grid_size = 2 / (3*grid_denominator)
  else grid_size = 1 / grid_denominator
end

--- Set windows size
window_size = tonumber(window_str)/1000


-- Variable to indicate current (active) project
local current_project = 0

-- Store current project grid state
local original_grid = {}
_, original_grid.div, original_grid.swgmode, original_grid.swgamt = reaper.GetSetProjectGrid(current_project, false)



--== GATHER NOTE DATA ==--

-- Get selected media item
local selected_item = reaper.GetSelectedMediaItem(current_project, 0) -- 0 = first selected item

-- Return error if no item is selected
if not selected_item then
  reaper.MB("No MIDI item selected.", "Error", 0)
    return
end

-- Get active take
local active_take = reaper.GetActiveTake(selected_item)

-- Return error if active take is not MIDI
if not active_take or not reaper.TakeIsMIDI(active_take) then
    reaper.MB("Selected item does not contain MIDI data.", "Error", 0)
    return
end

-- Count notes in active take
local note_count = 0
while reaper.MIDI_GetNote(active_take, note_count) == true do
  note_count = note_count + 1
end

-- Return error if active take contains no notes
if note_count == 0 then
    reaper.MB("Active take does not contain MIDI notes.", "Error", 0)
    return
end

-- Set project grid according to user input
reaper.GetSetProjectGrid(current_project, true, grid_size)


-- Store note information in table
local notes = {}
for note = 1,note_count do
  local _, _, _, startppq = reaper.MIDI_GetNote(active_take, note-1)
  local time = reaper.MIDI_GetProjTimeFromPPQPos(active_take, startppq)
  notes[note] = {}
  notes[note].time = time
  notes[note].offset = time - reaper.BR_GetClosestGridDivision(time)
end



--== ELEMENTARY STATISTICS TOOLKIT ==--

-- Median of a table of numbers
function median(table)
  local sum = 0
  local N = 0
  for _,entry in pairs(table) do
    if type(entry) == "number" then 
    sum = sum + entry
    N = N + 1
    else error("invalid input") end
  end
  return sum/N
end

-- Standard deviation of a table of numbers
function variance(table)
  local avg = median(table)
  local sum = 0
  local N = 0
  for _,entry in pairs(table) do
    if type(entry) == "number" then 
    sum = sum + (entry-avg)^2
    N = N + 1
    else error("invalid input") end
  end
  return math.sqrt(sum/N)
end

-- Count numbers in interval [min, max]
function countInInterval(numbers, min, max)
  if type(numbers) ~= "table" then error("invalid input") end
  if type(min) ~= "number" then error("invalid input") end
  if type(max) ~= "number" then error("invalid input") end
  local count = 0
  for _, number in pairs(numbers) do
    if type(number) ~= "number" then error("invalid input") end
    if not (number < min or number > max) then count = count + 1 end
  end
  return count
end

-- Percantage of numbers in interval [min, max]
function percInInterval(numbers, min, max)
  if type(numbers) ~= "table" then error("invalid input") end
  if type(min) ~= "number" then error("invalid input") end
  if type(max) ~= "number" then error("invalid input") end
  local count_all = 0
  local count_in = 0
  for _, number in pairs(numbers) do
    if type(number) ~= "number" then error("invalid input") end
    count_all = count_all + 1
    if not (number < min or number > max) then count_in = count_in + 1 end
  end
  return 100 * count_in / count_all
end

-- Round number x to d decimal places

function roundNum (x,d) -- rounds to decimal place 10^(-d)
  local rounded = math.floor(x*10^d+0.5)*10^(-d)
  if d<=0 then rounded = math.floor(rounded) end
  return rounded
  end



--== EVALUATION ==--

-- Record offsets in milliseconds
offsets = {}
for i = 1,note_count do
  offsets[i] = 1000*notes[i].offset 
end

-- Compute average offset and standard deviation
average = median(offsets)
std_dev = variance(offsets)

--- Note quality

-- Note quality table
local quality_labels = {"perfect", "good", "okay", "passable", "mediocre", "sloppy", "horrible"}
local quality_bounds = {0.0025,    0.005,   0.0125,   0.025,      0.05,       0.1,      0.2}

-- Rating funtion for note objects. Assigns a string label according to the offset value
function note_quality(note)
  local dev = math.abs(note.offset)
  if      dev <= quality_bounds[1] then return quality_labels[1]
  elseif  dev <= quality_bounds[2] then return quality_labels[2]
  elseif  dev <= quality_bounds[3] then return quality_labels[3]
  elseif  dev <= quality_bounds[4] then return quality_labels[4]
  elseif  dev <= quality_bounds[5] then return quality_labels[5]
  elseif  dev <= quality_bounds[6] then return quality_labels[6]
  else                                 return quality_labels[7]
  end
end

-- Add quality rating to note object attributes
for i, note in ipairs(notes) do
  note.quality = note_quality(note)
end

-- Quality counts
local quality_counts = {0,0,0,0,0,0,0}

for _, note in ipairs(notes) do
  for i, label in ipairs(quality_labels) do
    if note.quality == label then quality_counts[i] = quality_counts[i] + 1 end
  end
end


-- Quality percentage
local quality_percentages = {}
for i, _ in ipairs(quality_labels) do
  quality_percentages[i] = quality_counts[i] / note_count * 100
end


--== GRAPHIAL ILLUSTRATION ==--

reaper.ClearConsole()
reaper.ShowConsoleMsg("--== EVALUATION ==--\n\n")


-- Basic Performance statistics
reaper.ShowConsoleMsg("Basic statistics:\n\n")
reaper.ShowConsoleMsg(string.format("- %d notes are played.\n",note_count))
if average > 0 then
  reaper.ShowConsoleMsg(string.format("- On average the notes are %.0f ms behind.\n",average))
  elseif average < 0 then
  reaper.ShowConsoleMsg(string.format("- On average the notes are %.0f ms ahead.\n",-average))
  else
  reaper.ShowConsoleMsg("- On average all notes are on the grid.\n")
  end
reaper.ShowConsoleMsg(string.format("- The standard deviation is %.0f ms.\n",std_dev))


-- Playing accurary graph relative to set window

reaper.ShowConsoleMsg("\n")
reaper.ShowConsoleMsg("The playing accuracy is distributed as follows:")
reaper.ShowConsoleMsg("\n\n")

local steps = 10

for i = 0,2 * steps do
  local x = (i - steps) * window_size * 1000
  local a = x - 0.5 * window_size * 1000
  local b = a + window_size * 1000
  local perc = percInInterval(offsets,a,b)
  local y = string.rep(">",roundNum(perc,0))
  reaper.ShowConsoleMsg(string.format("%5.0f ms | %s\n",x,y))
  end


-- Quality counts and percentages

reaper.ShowConsoleMsg("\n")
reaper.ShowConsoleMsg("Note quality evaluation:\n\n")

for i, label in ipairs(quality_labels) do
  if i==1 then 
  reaper.ShowConsoleMsg(string.format("- %3d notes (%2.f%%) are %8s (at most %.1f ms off grid). \n",quality_counts[i], quality_percentages[i], label, 1000*quality_bounds[i]))  
  elseif i==7 then
  reaper.ShowConsoleMsg(string.format("- %3d notes (%2.f%%) are %8s (over %.1f ms off grid). \n",quality_counts[i], quality_percentages[i], label, 1000*quality_bounds[i-1]))
  else
  reaper.ShowConsoleMsg(string.format("- %3d notes (%2.f%%) are %8s (%.1f to %.1f ms off grid). \n",quality_counts[i], quality_percentages[i], label, 1000*quality_bounds[i-1], 1000*quality_bounds[i]))
  end
end



--== CLEAN UP ==--

-- Reset project grid to original state
reaper.GetSetProjectGrid(current_project, true, original_grid.div, original_grid.swgmode, original_grid.swgamt)
