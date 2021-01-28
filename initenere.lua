-- INITENERE
-- @vicimity
--
-- main screen has six edit 
-- positions, navigate with E1.
-- 1-3 manipulates time
-- E2 - changes play order 
-- ">" forward, 
-- "<" backward and 
-- "~" random
-- E3 - divides time from 
-- 1/1 to 1/16
-- 4-6 changes pitch
-- E2 - navigates left -> right
-- E3 - dials in notes
-- edit -> params
-- time routing
-- divisions are merged, 
-- pushing time
-- scale & outputs
-- scale
-- scale - scale
-- root note - root note
-- 1. to 3. octave range 
-- scale note 
-- values to an octave 
-- range +/- x octaves 
-- (C3 is middle)
-- midi
-- midi device - 1 to 4
-- midi ch A/B - 1 to 16
-- seq 1-3
-- route sequence 1-3 to 
-- various outputs 
-- passersby - params for 
-- passersby (engine) 
-- w/syn - params for w/syn 
-- (via crow)

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

scale = {
  1,
  2,
  3
}
scale[1] = music.generate_scale(0, "major", 10)
scale[2] = music.generate_scale(0, "major", 10)
scale[3] = music.generate_scale(0, "major", 10)

scales = {}

edit_focus = {
  "time1",
  "time2",
  "time3",
  "notes1",
  "notes2",
  "notes3",
  "route1",
  "route2",
  "route3",
  "oct1",
  "oct2",
  "oct3"
}

local edit = "time1"
local dd_1 = 1
local dd_2 = 1
local div_dirty = false
local new_div_div = {time1 = 1, time2 = 1, time3 = 1}

local octave_range = {3,3,3}

local crow_gate_length = 0.005 --5 ms for 'standard' trig behavior  --clock.get_beat_sec() / 2
local crow_gate_volts = 5 --5 v (beacuse we don't want to blow any fuses)

direction = {">", ">", ">"}
dir_options = {">", "<", "~"}
current_direction = {1, 1, 1}

function init()

  randomize_notes()

  for i = 1, #music.SCALES do
    table.insert(scales, string.lower(music.SCALES[i].name))
  end

  params:add_group("time routing", 6)
  params:add_option("time_1_2", "1 -> 2", {"no", "yes"}, 1)
  params:add_option("time_1_3", "1 -> 3", {"no", "yes"}, 1)
  params:add_option("time_2_1", "2 -> 1", {"no", "yes"}, 1)
  params:add_option("time_2_3", "2 -> 3", {"no", "yes"}, 1)
  params:add_option("time_3_1", "3 -> 1", {"no", "yes"}, 1)
  params:add_option("time_3_2", "3 -> 2", {"no", "yes"}, 1)


  params:add_group("scale & outputs", 34)

  params:add_separator("scale")
  params:add_option("scale","scale",scales,1)
  params:add_option("root_note", "root note", music.note_nums_to_names({0,1,2,3,4,5,6,7,8,9,10,11}),1)
  params:set_action("root_note", function(x)
    scale["1"] = music.generate_scale(60-x-params:get("seq_1_oct")*12, scales[params:get("scale")], 2*params:get("seq_1_oct"))
    scale["2"] = music.generate_scale(60-x-params:get("seq_2_oct")*12, scales[params:get("scale")], 2*params:get("seq_2_oct"))
    scale["3"] = music.generate_scale(60-x-params:get("seq_3_oct")*12, scales[params:get("scale")], 2*params:get("seq_3_oct"))
  end)
  params:set_action("scale", function(x)
    scale["1"] = music.generate_scale(params:get("root_note")+60-params:get("seq_1_oct")*12, scales[params:get("scale")], 2*params:get("seq_1_oct"))
    scale["2"] = music.generate_scale(params:get("root_note")+60-params:get("seq_2_oct")*12, scales[params:get("scale")], 2*params:get("seq_2_oct"))
    scale["3"] = music.generate_scale(params:get("root_note")+60-params:get("seq_3_oct")*12, scales[params:get("scale")], 2*params:get("seq_3_oct"))
  end)
  params:add_option("seq_1_oct", "1. octave range", {"+/- 1","+/- 3","+/- 5"}, 2)
  params:set_action("seq_1_oct", function(x)
    scale["1"] = music.generate_scale(params:get("root_note")+60-x*12, scales[params:get("scale")], 2*x) end)
  params:add_option("seq_2_oct", "2. octave range", {"+/- 1","+/- 3","+/- 5"}, 2)
  params:set_action("seq_2_oct", function(x)
    scale["2"] = music.generate_scale(params:get("root_note")+60-x*12, scales[params:get("scale")], 2*x)  end)
  params:add_option("seq_3_oct", "3. octave range", {"+/- 1","+/- 3","+/- 5"}, 2)
  params:set_action("seq_3_oct", function(x)
    scale["3"] = music.generate_scale(params:get("root_note")+60-x*12, scales[params:get("scale")], 2*x)  end)


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
        if params:get("time_1_2") == 2 then
          advance_seq_2()
        end
        if params:get("time_1_3") == 2 then
          advance_seq_3()
        end
        advance_seq_1()
        prev_playnote = playnote
        scaled_note = 60 - (params:get("seq_1_oct")*12) + math.floor((seq_notes["notes1"][seq_1_pos] / 127) * 2*(params:get("seq_1_oct")*12))
        playnote = music.snap_note_to_array(scaled_note, scale["1"])
        play(1,playnote)
        screen_dirty = true
      end
  },
  time2 = time_divisions:new_pattern{
      action = function(x) 
        if params:get("time_2_1") == 2 then
          advance_seq_1()
        end
        if params:get("time_2_3") == 2 then
          advance_seq_3()
        end
        advance_seq_2()
        scaled_note = 60 - (params:get("seq_2_oct")*12) + math.floor((seq_notes["notes2"][seq_2_pos] / 127) * 2*(params:get("seq_2_oct")*12))
        playnote = music.snap_note_to_array(scaled_note, scale["2"])        
        play(2,playnote)
        screen_dirty = true
        end
  },
  time3 = time_divisions:new_pattern{
      action = function(x) 
        if params:get("time_3_1") == 2 then
          advance_seq_1()
        end
        if params:get("time_3_2") == 2 then
          advance_seq_2()
        end
        advance_seq_3()
        scaled_note = 60 - (params:get("seq_3_oct")*12) + math.floor((seq_notes["notes3"][seq_2_pos] / 127) * 2*(params:get("seq_3_oct")*12))
        playnote = music.snap_note_to_array(scaled_note, scale["3"])
        play(3,playnote)
        screen_dirty = true
        end
  }}
  time_divisions:start()

  for i=1,3 do
    sequences["time"..i]:set_division(time_div_options[4 + (i-1)*4])
  end

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

function key(k,z)
  if z == 1 then
    --if k == 2 then
      --edit = edit_focus[dd_1]
      --dd_1 = 0
    --elseif k == 3 then
      --dd_2 = 4
      --edit = edit_focus[dd_2 + #edit_focus/2]
    --end
  end
end

function enc(n,d)
  if string.find(edit, "time") or string.find(edit, "notes") then
    if n == 1 then
      dd_1 = util.clamp(dd_1+d,1,#edit_focus/2)
      edit = edit_focus[dd_1]  
    end
    if n == 2 then
      if string.find(edit, "notes") then
        edit_note_focus = util.wrap(edit_note_focus + d, 1, 4)
      elseif string.find(edit, "time") then
        i = tonumber(string.sub(edit, string.len(edit)))
        current_direction[i] = util.clamp(current_direction[i] + d, 1, #dir_options)
        direction[i] = dir_options[current_direction[i]]
      end
    end
    if n == 3 then
      if string.find(edit, "time") then
        new_div_div[edit] = util.clamp(params:get(edit) + d, 1, #time_div_options)
        params:set(edit, new_div_div[edit])
        div_dirty = true
        
      end
      if string.find(edit, "notes") then
        seq_notes[edit][edit_note_focus] = util.clamp(seq_notes[edit][edit_note_focus] + d, 0, 127)
      end
    end
  end
  if string.find(edit, "route") or string.find(edit, "oct") then
    if n == 1 then
      dd_2 = util.clamp(dd_2+d,4, 6)
      edit = edit_focus[dd_2 + #edit_focus/2]
    end
  end
  screen_dirty = true
end

function redraw()
    screen.clear()
    screen.level(2)
    screen.aa(0)
    screen.font_size(8)
    screen.font_face(0)

    screen.level(edit == "route1" and 15 or 2)
    screen.move(95,8)
    screen.text(gen_route_string(1))
    screen.level(edit == "route2" and 15 or 2)
    screen.move(95,20)
    screen.text(gen_route_string(2))
    screen.level(edit == "route3" and 15 or 2)
    screen.move(95,32)
    screen.text(gen_route_string(3))
    for i=1,3 do
      screen.level(edit == "time"..i and 15 or 2)
      screen.move(85, 8 + (i-1)*12)
      screen.text_center(time_div_names[params:get("time"..i)])
      screen.move(7,8 + (i-1)*12)
      screen.text_center(direction[i])
    end

    for i=1,4 do
      for j=1,3 do
          if edit == "notes"..j and edit_note_focus == i then
            screen.level(15)
          else
            screen.level(2)
          end
        screen.move(20 + (i-1)*16,36 + 8+9*(j-1))
        screen.text_center(seq_notes["notes"..j][i])
      end
    end
    
    for i=1,4 do
      screen.level(1)
      screen.rect(15 + (i-1)*16,2,9,9)
      screen.fill()
      if i == seq_1_pos then screen.level(15) else screen.level(5) end
      screen.rect(17 + (i-1)*16,0,9,9)
      screen.fill()
    end
    for i=1,4 do
      screen.level(1)
      screen.rect(15 + (i-1)*16,14,9,9)
      screen.fill()
      if i == seq_2_pos then screen.level(15) else screen.level(5) end
      screen.rect(17 + (i-1)*16,12,9,9)
      screen.fill()
    end
    for i=1,4 do
      screen.level(1)
      screen.rect(15 + (i-1)*16,26,9,9)
      screen.fill()
      if i == seq_3_pos then screen.level(15) else screen.level(5) end
      screen.rect(17 + (i-1)*16,24,9,9)
      screen.fill()
    end

    --[[screen.level(edit == "oct1" and 15 or 2)
    screen.move(90, 44)
    screen.text_center("+/- "..octave_range[1])
    screen.move(105, 44)
    screen.text("oct.")
    screen.level(edit == "oct2" and 15 or 2)
    screen.move(90, 53)
    screen.text_center("+/- "..octave_range[2])
    screen.move(105, 53)
    screen.text("oct.")
    screen.level(edit == "oct3" and 15 or 2)
    screen.move(90, 62)
    screen.text_center("+/- "..octave_range[3])
    screen.move(105, 62)
    screen.text("oct.")
    ]]

    screen.update()
end

function randomize_notes()
  for i=1,3 do
    for j=1,4 do
      --seq_notes["notes"..i][j] = math.random(24+i*12,36+i*12)
      seq_notes["notes"..i][j] = math.random(0,127)
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

function advance_seq_1()
  if direction[1] == ">" then
    seq_1_pos = seq_1_pos + 1 
    seq_1_pos = util.wrap(seq_1_pos, 1, 4)
  elseif direction[1] == "<" then
    seq_1_pos = seq_1_pos - 1
    seq_1_pos = util.wrap(seq_1_pos, 1, 4)
  elseif  direction[1] == "~" then
    seq_1_pos = math.random(1, 4)
  end
end

function advance_seq_2()
  if direction[2] == ">" then
    seq_2_pos = seq_2_pos + 1 
    seq_2_pos = util.wrap(seq_2_pos, 1, 4)
  elseif direction[2] == "<" then
    seq_2_pos = seq_2_pos - 1
    seq_2_pos = util.wrap(seq_2_pos, 1, 4)
  elseif  direction[2] == "~" then
    seq_2_pos = math.random(1, 4)
  end
end

function advance_seq_3()
  if direction[3] == ">" then
    seq_3_pos = seq_3_pos + 1 
    seq_3_pos = util.wrap(seq_3_pos, 1, 4)
  elseif direction[3] == "<" then
    seq_3_pos = seq_3_pos - 1
    seq_3_pos = util.wrap(seq_3_pos, 1, 4)
  elseif  direction[3] == "~" then
    seq_3_pos = math.random(1, 4)
  end
end

function gen_route_string(x)
  to1 = false
  to2 = false
  to3 = false
  to_string = "-> "
  for i=1,2 do
    if params:get("time_"..x.."_"..util.wrap(x+i,1,3)) == 2 then
      to_string = to_string .. util.wrap(x+i,1,3) .. "+"
    end
  end
  return string.sub(to_string, 1, string.len(to_string)-1)
end

function cleanup()
    time_divisions:destroy()
end

function rerun()
  norns.script.load(norns.state.script)
end