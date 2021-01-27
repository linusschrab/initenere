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

local crow_gate_length = 0.005 --5 ms for 'standard' trig behavior  --clock.get_beat_sec() / 2
local crow_gate_volts = 5 --5 v (beacuse we don't want to blow any fuses)


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
        sequences[edit].phase = time_div_options[new_div_div[edit]] * time_divisions.ppqn * time_divisions.meter
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
        prev_playnote = playnote
        --if prev_playnote ~= nil then
        --  if params:get("seq_1_midi_A") == 2 then
        --    all_notes_off(prev_playnote, params:get("midi_A"))
        --  elseif params:get("seq_1_midi_B") == 2 then
        --    all_notes_off(prev_playnote, params:get("midi_B"))
        --  end
        --end
        playnote = music.snap_note_to_array(seq_notes["notes1"][seq_1_pos], scale)
        play(1,playnote)
        screen_dirty = true
      end
  },
  time2 = time_divisions:new_pattern{
      action = function(x) 
        seq_2_pos = seq_2_pos + 1 
        seq_2_pos = util.wrap(seq_2_pos, 1, 4)
        playnote = music.snap_note_to_array(seq_notes["notes2"][seq_2_pos], scale)
        play(2,playnote)
        screen_dirty = true
        end
  },
  time3 = time_divisions:new_pattern{
      action = function(x) 
        seq_3_pos = seq_3_pos + 1 
        seq_3_pos = util.wrap(seq_3_pos, 1, 4)
        playnote = music.snap_note_to_array(seq_notes["notes3"][seq_3_pos], scale)
        play(3,playnote)
        screen_dirty = true
        end
  }}
  time_divisions:start()

  for i=1,3 do
    sequences["time"..i]:set_division(time_div_options[4 + (i-1)*4])
  end

  

  params:add_group("scale & outputs", 31)

  params:add_separator("scale")
  params:add_option("scale","scale",scales,1)
  params:add_option("root_note", "root note", music.note_nums_to_names({0,1,2,3,4,5,6,7,8,9,10,11}),1)
  params:set_action("root_note", function(x)
    scale = music.generate_scale(x, scales[params:get("scale")], 9)
  end)
  params:set_action("scale", function(x)
    scale = music.generate_scale(params:get("root_note"), scales[x], 9)
  end)

  params:add_separator("midi")
  params:add_number("midi_device", "midi device", 1,4,1)
  params:set_action("midi_device", function (x) m = midi.connect(x) end)
  params:add_number("midi_A", "midi ch A", 1,16,1)
  params:add_number("midi_B", "midi ch B", 1,16,1)

  params:add_separator("seq 1 outputs")
  params:add_option("seq_1_engine", "seq 1 -> engine", {"no", "yes"}, 2)
  params:add_option("seq_1_midi_A", "seq 1 -> midi ch A", {"no", "yes"}, 2)
  params:add_option("seq_1_midi_B", "seq 1 -> midi ch B", {"no", "yes"}, 1)
  params:add_option("seq_1_crow_1", "seq 1 -> crow 1/2", {"no", "yes"}, 1)
  params:set_action("seq_1_crow_1", function (x)
    crow.output[2].action = "{to(".. crow_gate_volts ..",0),to(0,".. crow_gate_length .. ")}" 
  end)
  params:add_option("seq_1_crow_2", "seq 1 -> crow 3/4", {"no", "yes"}, 1)
  params:set_action("seq_1_crow_2", function (x)
    crow.output[4].action = "{to(".. crow_gate_volts ..",0),to(0,".. crow_gate_length .. ")}" 
  end)
  params:add_option("seq_1_JF", "seq 1 -> JF", {"no", "yes"}, 1)
  params:set_action("seq_1_JF", function(x)
    if params:get("seq_2_JF") == 1 or params:get("seq_3_JF") == 1 then
      if x == 2 then
        crow.ii.jf.mode(1)
      else
        crow.ii.jf.mode(0)
      end
    end
  end)
  params:add_option("seq_1_w", "seq 1 -> w/syn", {"no", "yes"}, 1)

  params:add_separator("seq 2 outputs")
  params:add_option("seq_2_engine", "seq 2 -> engine", {"no", "yes"}, 2)
  params:add_option("seq_2_midi_A", "seq 2 -> midi ch A", {"no", "yes"}, 2)
  params:add_option("seq_2_midi_B", "seq 2 -> midi ch B", {"no", "yes"}, 1)
  params:add_option("seq_2_crow_1", "seq 2 -> crow 1/2", {"no", "yes"}, 1)
  params:set_action("seq_2_crow_1", function (x)
    crow.output[2].action = "{to(".. crow_gate_volts ..",0),to(0,".. crow_gate_length .. ")}" 
  end)
  params:add_option("seq_2_crow_2", "seq 2 -> crow 3/4", {"no", "yes"}, 1)
  params:set_action("seq_2_crow_2", function (x)
    crow.output[4].action = "{to(".. crow_gate_volts ..",0),to(0,".. crow_gate_length .. ")}" 
  end)
  params:add_option("seq_2_JF", "seq 2 -> JF", {"no", "yes"}, 1)
  params:set_action("seq_2_JF", function(x)
    if params:get("seq_1_JF") == 1 or params:get("seq_3_JF") == 1 then
      if x == 2 then
        crow.ii.jf.mode(1)
      else
        crow.ii.jf.mode(0)
      end
    end
  end)
  params:add_option("seq_2_w", "seq 2 -> w/syn", {"no", "yes"}, 1)

  params:add_separator("seq 3 outputs")
  params:add_option("seq_3_engine", "seq 3 -> engine", {"no", "yes"}, 2)
  params:add_option("seq_3_midi_A", "seq 3 -> midi ch A", {"no", "yes"}, 2)
  params:add_option("seq_3_midi_B", "seq 3 -> midi ch B", {"no", "yes"}, 1)
  params:add_option("seq_3_crow_1", "seq 3 -> crow 1/2", {"no", "yes"}, 1)
  params:set_action("seq_3_crow_1", function (x)
    crow.output[2].action = "{to(".. crow_gate_volts ..",0),to(0,".. crow_gate_length .. ")}" 
  end)
  params:add_option("seq_3_crow_2", "seq 3 -> crow 3/4", {"no", "yes"}, 1)
  params:set_action("seq_3_crow_2", function (x)
    crow.output[4].action = "{to(".. crow_gate_volts ..",0),to(0,".. crow_gate_length .. ")}" 
  end)
  params:add_option("seq_3_JF", "seq 3 -> JF", {"no", "yes"}, 1)
  params:set_action("seq_3_JF", function(x)
    if params:get("seq_1_JF") == 1 or params:get("seq_2_JF") == 1 then
      if x == 2 then
        crow.ii.jf.mode(1)
      else
        crow.ii.jf.mode(0)
      end
    end
  end)
  params:add_option("seq_3_w", "seq 3 -> w/syn", {"no", "yes"}, 1)

  params:add_group("passersby", 31)
  passersby.add_params()
  wsyn_add_params()

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

function play(i, playnote)
  if params:get("seq_"..i.."_engine") == 2 then
    engine.noteOn(1, music.note_num_to_freq(playnote),100)
  end
  if params:get("seq_"..i.."_midi_A") == 2 then
    m:note_on(playnote,100,params:get("midi_A"))
    clock.run(midihang, i, playnote, params:get("midi_A"))
  end
  if params:get("seq_"..i.."_midi_B") == 2 then
    m:note_on(playnote,100,params:get("midi_B"))
    clock.run(midihang, i, playnote, params:get("midi_B"))
  end
  if params:get("seq_"..i.."_crow_1") == 2 then
    crow.output[1].volts = (((playnote)-60)/12)
    crow.output[2].execute()
  end
  if params:get("seq_"..i.."_crow_2") == 2 then
    crow.output[3].volts = (((playnote)-60)/12)
    crow.output[4].execute()
  end
  if params:get("seq_"..i.."_JF") == 2 then
    crow.ii.jf.play_note(((playnote)-60)/12,5)
  end
  if params:get("seq_"..i.."_w") == 2 then
    crow.send("ii.wsyn.play_note(".. ((playnote)-60)/12 ..", " .. 5 .. ")")
  end
end

function midihang(i, playnote, midi_ch)
  clock.sleep(time_div_options[params:get("time"..i)]/2)
  m:note_off(playnote,100,midi_ch)
end

function wsyn_add_params()
  params:add_group("w/syn",10)
  params:add {
    type = "option",
    id = "wsyn_ar_mode",
    name = "AR mode",
    options = {"off", "on"},
    default = 2,
    action = function(val) crow.send("ii.wsyn.ar_mode(" .. (val - 1) .. ")") end
  }
  params:add {
    type = "control",
    id = "wsyn_curve",
    name = "Curve",
    controlspec = controlspec.new(-5, 5, "lin", 0, 0, "v"),
    action = function(val) crow.send("ii.wsyn.curve(" .. val .. ")") end
  }
  params:add {
    type = "control",
    id = "wsyn_ramp",
    name = "Ramp",
    controlspec = controlspec.new(-5, 5, "lin", 0, 0, "v"),
    action = function(val) crow.send("ii.wsyn.ramp(" .. val .. ")") end
  }
  params:add {
    type = "control",
    id = "wsyn_fm_index",
    name = "FM index",
    controlspec = controlspec.new(0, 5, "lin", 0, 0, "v"),
    action = function(val) crow.send("ii.wsyn.fm_index(" .. val .. ")") end
  }
  params:add {
    type = "control",
    id = "wsyn_fm_env",
    name = "FM env",
    controlspec = controlspec.new(-5, 5, "lin", 0, 0, "v"),
    action = function(val) crow.send("ii.wsyn.fm_env(" .. val .. ")") end
  }
  params:add {
    type = "control",
    id = "wsyn_fm_ratio_num",
    name = "FM ratio numerator",
    controlspec = controlspec.new(1, 20, "lin", 1, 2),
    action = function(val) crow.send("ii.wsyn.fm_ratio(" .. val .. "," .. params:get("wsyn_fm_ratio_den") .. ")") end
  }
  params:add {
    type = "control",
    id = "wsyn_fm_ratio_den",
    name = "FM ratio denominator",
    controlspec = controlspec.new(1, 20, "lin", 1, 1),
    action = function(val) crow.send("ii.wsyn.fm_ratio(" .. params:get("wsyn_fm_ratio_num") .. "," .. val .. ")") end
  }
  params:add {
    type = "control",
    id = "wsyn_lpg_time",
    name = "LPG time",
    controlspec = controlspec.new(-5, 5, "lin", 0, 0, "v"),
    action = function(val) crow.send("ii.wsyn.lpg_time(" .. val .. ")") end
  }
  params:add {
    type = "control",
    id = "wsyn_lpg_symmetry",
    name = "LPG symmetry",
    controlspec = controlspec.new(-5, 5, "lin", 0, 0, "v"),
    action = function(val) crow.send("ii.wsyn.lpg_symmetry(" .. val .. ")") end
  }
  params:add{
    type = "binary",
    id = "wsyn_randomize",
    name = "Randomize",
    action = function()
      params:set("wsyn_curve", math.random(-50, 50)/10)
      params:set("wsyn_ramp", math.random(-50, 50)/10)
      params:set("wsyn_fm_index", math.random(0, 50)/10)
      params:set("wsyn_fm_env", math.random(-50, 50)/10)
      params:set("wsyn_fm_ratio_num", math.random(1, 20))
      params:set("wsyn_fm_ratio_den", math.random(1, 20))
      params:set("wsyn_lpg_time", math.random(-50, 50)/10)
      params:set("wsyn_lpg_symmetry", math.random(-50, 50)/10)
    end
  }
end

function cleanup()
    time_divisions:destroy()
end