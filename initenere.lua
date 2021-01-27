music = require("musicutil")
lattice = require("lattice")
engine.name = 'Passersby'
passersby = include "passersby/lib/passersby_engine"

m = midi.connect(1)

seq_1_pos = 1
seq_2_pos = 1
seq_3_pos = 1
seq_notes = {notes1 = {60,60,60,60}, notes2 = {60,60,60,60}, notes3 = {60,60,60,60}}
octave1 = 0
octave2 = 0
octave3 = 0

edit_note_focus = 1

time_div_names = {}
time_div_options = {}
for i=1,16 do
  table.insert(time_div_names, "/"..i)
  table.insert(time_div_options, 1/i)
end

scale = music.generate_scale(0, "major", 9)
scales = {}

edit_focus = {
  "time1",
  "time2",
  "time3",
  "notes1",
  "notes2",
  "notes3",
}
local edit = "time1"
local dd_1 = 0
local div_dirty = false
local new_div_div = {time1 = 1, time2 = 1, time3 = 1}


function init()

  randomize_notes()

  for i = 1, #music.SCALES do
    table.insert(scales, string.lower(music.SCALES[i].name))
  end

  time_divisions = lattice:new()

  global_div = time_divisions:new_pattern{
    action = function(x)
      if div_dirty then
        sequences[edit]:set_division(time_div_options[new_div_div[edit]])
        sequences["time1"].phase = 0
        sequences["time2"].phase = 0
        sequences["time3"].phase = 0
        div_dirty = false
      end
    end,
    division = 1
  }

  sequences = {
  time1 = time_divisions:new_pattern{
      action = function(x)
        seq_1_pos = seq_1_pos + 1 
        seq_1_pos = util.wrap(seq_1_pos, 1, 4)
        playnote = music.snap_note_to_array(seq_notes["notes1"][seq_1_pos], scale)
        engine.noteOn(1, music.note_num_to_freq(playnote),100)
        m:note_on(playnote,100,1)
        m:note_off(playnote,100,1)
        screen_dirty = true
      end
  },
  time2 = time_divisions:new_pattern{
      action = function(x) 
        seq_2_pos = seq_2_pos + 1 
        seq_2_pos = util.wrap(seq_2_pos, 1, 4)
        playnote = music.snap_note_to_array(seq_notes["notes2"][seq_2_pos], scale)
        engine.noteOn(2, music.note_num_to_freq(playnote),100)
        m:note_on(playnote,100,1)
        m:note_off(playnote,100,1)
        screen_dirty = true
        end
  },
  time3 = time_divisions:new_pattern{
      action = function(x) 
        seq_3_pos = seq_3_pos + 1 
        seq_3_pos = util.wrap(seq_3_pos, 1, 4)
        playnote = music.snap_note_to_array(seq_notes["notes3"][seq_3_pos], scale)
        engine.noteOn(3, music.note_num_to_freq(playnote),100)
        m:note_on(playnote,100,1)
        m:note_off(playnote,100,1)
        screen_dirty = true
        end
  }}
  time_divisions:start()

  for i=1,3 do
    sequences["time"..i]:set_division(time_div_options[4 + (i-1)*4])
  end

  params:add_option("scale","scale",scales,1)
  params:set_action("scale", function(x)
    scale = music.generate_scale(0, scales[x], 9)
  end)

  passersby.add_params()

  for i=1,3 do
    params:add_option("time"..i, "s"..i.." division", time_div_names, 4 + (i-1)*4)
    params:set_action("time"..i, function(x)
      sequences["time"..i]:set_division(time_div_options[x])
    end)
    params:hide("time"..i)
  end
  screen_dirty = true
  main_clock = clock.run(pulse)
end

function pulse()
    while true do
        clock.sleep(1/30)
        if screen_dirty then
            redraw()
            screen_dirty = false
        end
    end
end

function key(n,z)
  if n == 3 then
  end
end

function enc(n,d)
  if n == 1 then
    dd_1 = util.clamp(dd_1+d,1,#edit_focus)
    edit = edit_focus[dd_1]  
  end
  if n == 2 then
    edit_note_focus = util.wrap(edit_note_focus + d, 1, 4)
  end
  if n == 3 then
    if string.find(edit, "time") then
      new_div_div[edit] = util.clamp(params:get(edit) + d, 1, #time_div_options)
      print(time_div_options[new_div_div[edit]])
      params:set(edit, new_div_div[edit])
      div_dirty = true
    end
    if string.find(edit, "notes") then
      seq_notes[edit][edit_note_focus] = util.clamp(seq_notes[edit][edit_note_focus] + d, 0, 127)
    end
  end
  screen_dirty = true
end

function redraw()
    screen.clear()
    screen.level(15)
    screen.aa(0)
    screen.font_size(8)
    screen.font_face(0)

    for i=1,3 do
      screen.move(50,8 + (i-1)*12)
      screen.level(edit == "time"..i and 15 or 2)
      screen.text_center(time_div_names[params:get("time"..i)])
    end

    for i=1,4 do
      for j=1,3 do
          if edit == "notes"..j and edit_note_focus == i then
            screen.level(15)
          else
            screen.level(2)
          end
        screen.move(70 + (i-1)*16,36 + 8+9*(j-1))
        screen.text_center(seq_notes["notes"..j][i])
      end
    end
    
    for i=1,4 do
      screen.level(1)
      screen.rect(64 + (i-1)*16,2,9,9)
      screen.fill()
      if i == seq_1_pos then screen.level(15) else screen.level(5) end
      screen.rect(66 + (i-1)*16,0,9,9)
      screen.fill()
    end
    for i=1,4 do
      screen.level(1)
      screen.rect(64 + (i-1)*16,14,9,9)
      screen.fill()
      if i == seq_2_pos then screen.level(15) else screen.level(5) end
      screen.rect(66 + (i-1)*16,12,9,9)
      screen.fill()
    end
    for i=1,4 do
      screen.level(1)
      screen.rect(64 + (i-1)*16,26,9,9)
      screen.fill()
      if i == seq_3_pos then screen.level(15) else screen.level(5) end
      screen.rect(66 + (i-1)*16,24,9,9)
      screen.fill()
    end

    --screen.move(1, 8)
    --screen.text(params:get("clock_tempo") .. " BPM")
    --screen.move(1,16)
    --screen.text("seq_1_pos: " .. seq_1_pos)
    --screen.move(1,24)
    --screen.text("seq_2_pos: " .. seq_2_pos)
    --screen.move(1,32)
    --screen.text("seq_3_pos: " .. seq_3_pos)
    screen.update()
end

function randomize_notes()
  for i=1,3 do
    for j=1,4 do
      seq_notes["notes"..i][j] = math.random(24+i*12,36+i*12)
    end
  end
end

function cleanup()
    time_divisions:destroy()
end