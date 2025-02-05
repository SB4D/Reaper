--[[
ReaScript: Change project tempo by number of semi-tones...
Author: Stefan Behrens (Streck0)
Date: 2024-12-08
Reaper Version: 7.27

Description: 
Changes the tempo at the edit cursor according to a specified number of semi-tones.

--]]

-- Create an undo point 
reaper.Undo_BeginBlock()

-- Get number of semi-tones to adjust tempo
local _, semiTones = reaper.GetUserInputs("Semi Tone to BPM",1,"Semi tones:","1")
semiTones = tonumber(semiTones)

-- Get current tempo
--local _,_,_,_,currentBPM,_,_,_ = reaper.GetTempoTimeSigMarker(0,currentTempoMarkerID)
local currentBPM = reaper.TimeMap2_GetDividedBpmAtTime(0,reaper.GetCursorPosition())

-- Compute new tempo
local newBPM = currentBPM*2^(semiTones/12)

-- Get ID of tempo/time signature marker before or at edit cursor
local currentTempoMarkerID = reaper.FindTempoTimeSigMarker(0,reaper.GetCursorPosition())

-- Read out information (see info below)
local a,b,c,d,e,f,g,h = reaper.GetTempoTimeSigMarker(0,currentTempoMarkerID)
-- a -> false if there is no tempo/time signature change marker in the project yet, true otherwise
-- e -> bpm at marker

-- Set the new bpm
if a==true 
  then reaper.SetTempoTimeSigMarker(0,currentTempoMarkerID,b,c,d,newBPM,f,g,h) -- either updartes bpm at existing marker
  else reaper.AddTempoTimeSigMarker(0, 0, newBPM, -1, -1, false) -- or creates a new one at 0*
  --else reaper.ShowConsoleMsg("Dang!")
  end
-- (*) this is a crutch, because I don't know how to access the project tempo

-- Update Interface
reaper.UpdateArrange()
reaper.UpdateTimeline()

-- End undo block
reaper.Undo_EndBlock("Change project tempo "..semiTones.." semi-tones",-1)

-- THE END --]]
