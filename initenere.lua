local music = require("musicutil")
local MollyThePoly = require "molly_the_poly/lib/molly_the_poly_engine"
engine.name = "MollyThePoly"

lattice = require("lattice")

screen_dirty = true
grid_dirty = true


cycle_modes = {"-", ">", "<", "~"}
time = {
  names = {},
  modes = {}
}
for i=1,16 do
  time["names"][i] = i.."x"
  time["modes"][i] = 1/i
end

oct_modes = {1, 3, 5}

local crow_gate_length = 0.005 --5 ms for 'standard' trig behavior  --clock.get_beat_sec() / 2
local crow_gate_volts = 5 --5 v (beacuse we don't want to blow any fuses)


--matrix to hold all note values
matrix = {}
for y=1,4 do
    matrix[y] = {
      x_position = 1,
      row = y,
      cycle_dir = 2,
      octave_range = 2,
      x_cycle_dir = 1,
      screen_time = 4,
      screen_y_time = 4
    }
    for x=1,4 do
        matrix[y][x] = {
          note = 0
        }
    end
end

edit = "y_1"
edit_foci = {"y_1", "y_2", "y_3", "y_4", "x_1", "x_2", "x_3", "x_4"}
edit = 1

time_dirty = false
time_dirty_stack = {}

k3_is_held = false

scales = {}

function init()

  for i = 1, #music.SCALES do
    table.insert(scales, string.lower(music.SCALES[i].name))
  end

  randomize_notes()
  add_params()
  m = midi.connect(params:get("midi_device"))

  time_handlers = lattice:new()
  --might need this later to keep new divisions in time
  global_time = time_handlers:new_pattern{
    action = function(x)  
      if time_dirty and #time_dirty_stack > 0 then
        for i=1,#time_dirty_stack do
          --print(time_dirty_stack[i]["seq"])
          i_seq = "seq"..time_dirty_stack[i]["seq"]
          --sequencers[i_seq]:set_division(time.modes[time_dirty_stack[i]["time"]])
          params:set("time"..time_dirty_stack[i]["seq"], time_dirty_stack[i]["time"])
          --print(time.modes[time_dirty_stack[i]["time"]])
          --matrix[i_seq].division = 
        end
        div_dirty = false
        time_dirty_stack = {}
        screen_dirty = true
      end
    end,
    division = 1
  }
  sequencers = {
    seq1 = time_handlers:new_pattern{
      action = function(x)
        advance_seq(1)
        screen_dirty = true
      end,
      division = time["modes"][matrix[1].time]
    },
    seq2 = time_handlers:new_pattern{
      action = function(x)
        advance_seq(2)
        screen_dirty = true
      end,
      division = time["modes"][matrix[2].time]
    },
    seq3 = time_handlers:new_pattern{
      action = function(x)
        advance_seq(3)
        screen_dirty = true
      end,
      division = time["modes"][matrix[3].time]
    },
    seq4 = time_handlers:new_pattern{
      action = function(x)
        advance_seq(4)
        screen_dirty = true
      end,
      division = time["modes"][matrix[4].time]
    },
    
    seq_y1 = time_handlers:new_pattern{
      action = function(x)
        rotate(1)
        screen_dirty = true
      end,
      division = time["modes"][matrix[1].y_time]
    },
    seq_y2 = time_handlers:new_pattern{
      action = function(x)
        rotate(2)
        screen_dirty = true
      end,
      division = time["modes"][matrix[2].y_time]
    },
    seq_y3 = time_handlers:new_pattern{
      action = function(x)
        rotate(3)
        screen_dirty = true
      end,
      division = time["modes"][matrix[3].y_time]
    },
    seq_y4 = time_handlers:new_pattern{
      action = function(x)
        rotate(4)
        screen_dirty = true
      end,
      division = time["modes"][matrix[4].y_time]
    }
  }

  for i=1,4 do
    params:add_number("time"..i, "s"..i.." division", 1,16,4)
    params:set_action("time"..i, function(x)
      sequencers["seq"..i]:set_division(time.modes[x])
      matrix[i].screen_time = x
    end)
    params:hide("time"..i)
  end

  for i=5,8 do
    params:add_number("time"..i, "s"..i.." division", 1,16,4)
    params:set_action("time"..i, function(x)
      sequencers["seq_y"..(i-4)]:set_division(time.modes[x])
      matrix[i-4].screen_y_time = x
    end)
    params:hide("time"..i)
  end

  time_handlers:start()
  clock.run(go)
end

function go()
    while true do
        clock.sleep(1/15)
        if screen_dirty then 
            redraw()
            screen_dirty = false 
        end
        if grid_dirty then 
            grid_redraw()
            grid_dirty = false 
        end
    end
end

function add_params()
  params:add_group("midi & outputs",46)
  params:add_separator("midi")
  params:add_number("midi_device", "midi device", 1, #midi.vports, 1)
  params:add_number("midi_channel_A", "midi channel A", 1, 16, 1)
  params:add_number("midi_channel_B", "midi channel B", 1, 16, 2)
  params:add_number("midi_channel_C", "midi channel C", 1, 16, 3)
  params:add_number("midi_channel_D", "midi channel D", 1, 16, 4)
  for i=1,4 do
    params:add_separator("seq "..i.." outputs")
    params:add_option("seq_"..i.."_engine", "seq "..i.." -> engine", {"no", "yes"}, 2)
    params:add_option("seq_"..i.."_midi_A", "seq "..i.." -> midi ch A", {"no", "yes"}, 2)
    params:add_option("seq_"..i.."_midi_B", "seq "..i.." -> midi ch B", {"no", "yes"}, 1)
    params:add_option("seq_"..i.."_midi_C", "seq "..i.." -> midi ch C", {"no", "yes"}, 1)
    params:add_option("seq_"..i.."_midi_D", "seq "..i.." -> midi ch D", {"no", "yes"}, 1)
    params:add_option("seq_"..i.."_crow_1", "seq "..i.." -> crow 1/2", {"no", "yes"}, 1)
    params:set_action("seq_"..i.."_crow_1", function (x)
      crow.output[2].action = "{to(".. crow_gate_volts ..",0),to(0,".. crow_gate_length .. ")}" 
    end)
    params:add_option("seq_"..i.."_crow_2", "seq 1 -> crow 3/4", {"no", "yes"}, 1)
    params:set_action("seq_"..i.."_crow_2", function (x)
      crow.output[4].action = "{to(".. crow_gate_volts ..",0),to(0,".. crow_gate_length .. ")}" 
    end)
    params:add_option("seq_"..i.."_JF", "seq "..i.." -> JF", {"no", "yes"}, 1)
    params:set_action("seq_"..i.."_JF", function(x)
      if params:get("seq_".. util.wrap(i+1,1,4) .."_JF") == 1 or params:get("seq_".. util.wrap(i+2,1,4) .."_JF") == 1 or params:get("seq_".. util.wrap(i+3,1,4) .."_JF") == 1 then
        if x == 2 then
          crow.ii.jf.mode(1)
        else
          crow.ii.jf.mode(0)
        end
      end
    end)
    params:add_option("seq_"..i.."_w", "seq "..i.." -> w/syn", {"no", "yes"}, 1)
  end

  params:add_group("scale & notes",14)
  params:add_separator("scale")
  params:add_option("scale","scale",scales,1)
  params:add_option("root_note", "root note", music.note_nums_to_names({0,1,2,3,4,5,6,7,8,9,10,11}),1)
  params:add_trigger("randomize_notes", "randomize note matrix")
  params:set_action("randomize_notes", function(x) randomize_notes() end)
  params:add_separator("octave offset")
  for i=1,4 do
    params:add_number("seq_"..i.."_off", "s"..i..". octave offset", -3,3,0)
  end
  params:add_separator("octave range")
  params:add_option("seq_1_oct", "s1. oct range +/-", oct_modes, 2)
  params:add_option("seq_2_oct", "s2. oct range +/-", oct_modes, 2)
  params:add_option("seq_3_oct", "s3. oct range +/-", oct_modes, 2)
  params:add_option("seq_4_oct", "s4. oct range +/-", oct_modes, 2)


  
  params:add_group("molly the poly", 46)
  MollyThePoly.add_params()
  wsyn_add_params()

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

--fill the matrix with random notes
function randomize_notes()
    for y=1,4 do
        for x=1,4 do
            matrix[y][x].note = math.random(120) -- +/- 5 octave range
        end
    end
end

function enc(e,d)
  if e == 1 then
    edit = util.clamp(edit + d, 1, #edit_foci)
  elseif e == 2 then
    if k3_is_held ~= true then
      if edit <= 4 then
        matrix[edit].cycle_dir = util.clamp(matrix[edit].cycle_dir + d, 1, #cycle_modes)
      else
        matrix[edit-4].x_cycle_dir = util.clamp(matrix[edit-4].x_cycle_dir + d, 1, #cycle_modes)
      end
    elseif edit <= 4 then
      params:set("seq_"..edit.."_off", util.clamp(params:get("seq_"..edit.."_off") + d, -3, 3))
    end
  elseif e == 3 then
    if k3_is_held ~= true then
      if edit <= 4 then
        matrix[edit].screen_time = util.clamp(matrix[edit].screen_time + d, 1, #time.modes)
        table.insert(time_dirty_stack, {seq=edit, time=matrix[edit].screen_time}) -- HERE
        time_dirty = true
      elseif matrix[edit-4].x_cycle_dir ~= 1 then
        matrix[edit-4].screen_y_time = util.clamp(matrix[edit-4].screen_y_time + d, 1, #time.modes)
        table.insert(time_dirty_stack, {seq=edit, time = util.clamp(matrix[edit-4].screen_y_time, 1, #time.modes)})
        time_dirty = true
      end
    else
      if edit <= 4 then
        params:set("seq_"..edit.."_oct", util.clamp(params:get("seq_"..edit.."_oct")+d,1,#oct_modes))
      end
    end
  end
  screen_dirty = true
end

function key(k,z)
  if z == 1 then
    if k == 3 then
      k3_is_held = true
    elseif k == 2 then
      
    end
  else
    k3_is_held = false
  end
  screen_dirty = true
end

function redraw()
    screen.clear()
    screen.font_face(0)
    screen.font_size(8)
    local y_off = -2
    local x_off = 0
    
    for y=1,4 do
        for x=1,4 do
            screen.level(1)
            screen.rect(34+x*10,2+y*10+y_off,8,8)
            screen.fill()
            if x == matrix[y].x_position then screen.level(15) else screen.level(5) end
            screen.rect(33+x*10,1+ matrix[y].row*10+y_off,8,8)
            screen.fill()
        end
    end
    
    --[[ for testing purposes
    for y=1,4 do
      for x=1,4 do
        screen.move(x*10,y*10)
        screen.text(matrix[y][x].note)
      end
    end
    ]]

    for i=1,4 do
      screen.level(1)
      screen.move(5,9+i*10+y_off)
      screen.text("o "..params:get("seq_"..i.."_off"))
      screen.move(22,9+i*10+y_off)
      screen.text(" |")
      screen.move(35,9+i*10+y_off)
      screen.text(cycle_modes[matrix[i].cycle_dir])
      screen.move(89,8+i*10+y_off)
      if matrix[i].cycle_dir ~= 1 then
        screen.text(time["names"][matrix[i].screen_time])
        screen.move(100,8+i*10+y_off)
        screen.text(" | "..oct_modes[params:get("seq_"..i.."_oct")])
        screen.move(114,8+i*10+y_off)
        screen.text(" o")
      else
        screen.text("-")
        screen.move(100,8+i*10+y_off)
        screen.text(" | "..oct_modes[params:get("seq_"..i.."_oct")])
        screen.move(114,8+i*10+y_off)
        screen.text(" o")
      end
      screen.text_rotate(35+i*10, 4+y_off,cycle_modes[matrix[i].x_cycle_dir],90)
      if matrix[i].x_cycle_dir ~= 1 then
        screen.text_rotate(35+i*10, 55+y_off, time["names"][matrix[i].screen_y_time], 90)
      else
        screen.text_rotate(35+i*10, 55+y_off, "-", 90)
      end
      screen.level(edit_foci[edit] == "y_"..i and 15 or 5)
      screen.move(4,8+i*10+y_off)
      screen.text("o "..params:get("seq_"..i.."_off"))
      screen.move(21,8+i*10+y_off)
      screen.text(" |")
      screen.move(34,8+i*10+y_off)
      screen.text(cycle_modes[matrix[i].cycle_dir])
      screen.move(88,7+i*10+y_off)
      if matrix[i].cycle_dir ~= 1 then
        screen.text(time["names"][matrix[i].screen_time])
        screen.move(99,7+i*10+y_off)
        screen.text(" | "..oct_modes[params:get("seq_"..i.."_oct")])
        screen.move(113,7+i*10+y_off)
        screen.text(" o")
      else
        screen.text("-")
        screen.move(99,7+i*10+y_off)
        screen.text(" | "..oct_modes[params:get("seq_"..i.."_oct")])
        screen.move(113,7+i*10+y_off)
        screen.text(" o")
      end
      screen.level(edit_foci[edit] == "x_"..i and 15 or 5)
      screen.text_rotate(34+i*10, 3+y_off,cycle_modes[matrix[i].x_cycle_dir],90)
      if matrix[i].x_cycle_dir ~= 1 then
        screen.text_rotate(34+i*10, 54+y_off, time["names"][matrix[i].screen_y_time], 90)
      else
        screen.text_rotate(34+i*10, 54+y_off, "-", 90)
      end
    end
    screen.update()
    screen_dirty = false
end

function grid_redraw()

end

function advance_seq(i)
  if matrix[i].cycle_dir == 1 then
    return
  elseif cycle_modes[matrix[i].cycle_dir] == ">" then
    matrix[i].x_position = util.wrap(matrix[i].x_position + 1, 1, 4)
  elseif cycle_modes[matrix[i].cycle_dir] == "<" then
    matrix[i].x_position = util.wrap(matrix[i].x_position - 1, 1, 4)
  elseif  cycle_modes[matrix[i].cycle_dir] == "~" then
    matrix[i].x_position = math.random(1, 4)
  end

  --prev_playnote = playnote
  --scaled_note = 60 - (params:get("seq_1_oct")*12) + math.floor((seq_notes["notes1"][seq_1_pos] / 120) * 2*(params:get("seq_1_oct")*12))
  --playnote = music.snap_note_to_array(scaled_note, scale[1])
  playnote = music.snap_note_to_array(matrix[i][matrix[i].x_position].note, music.generate_scale(params:get("root_note"), scales[params:get("scale")], 2*oct_modes[params:get("seq_"..i.."_oct")]))
  playnote = playnote + params:get("seq_"..i.."_off") * 12
  --print(playnote)
  play(i,playnote)
end

function rotate(x)
  for y=1,4 do
    tmp_note = matrix[y][x]
    if matrix[y].x_cycle_dir == 1 then
      --
    elseif cycle_modes[matrix[y].x_cycle_dir] == ">" then
      matrix[y][x] = matrix[util.wrap(y+1,1,4)][x]
      matrix[util.wrap(y+1,1,4)][x] = tmp_note
    elseif cycle_modes[matrix[y].x_cycle_dir] == "<" then
      matrix[y][x] = matrix[util.wrap(y-1,1,4)][x]
      matrix[util.wrap(y-1,1,4)][x] = tmp_note
    elseif cycle_modes[matrix[y].x_cycle_dir] == "~" then
      tmp_rnd = math.random(1,4)
      matrix[y][x] = matrix[tmp_rnd][x]
      matrix[tmp_rnd][x] = tmp_note
    end
  end
end

function play(i, playnote)
  
    if params:get("seq_"..i.."_engine") == 2 then
      engine.noteOn(playnote, music.note_num_to_freq(playnote),100)
      clock.run(mollyhang, playnote,i)
    end
    if params:get("seq_"..i.."_midi_A") == 2 then
      m:note_on(playnote,100,params:get("midi_channel_A"))
      clock.run(midihang, i, playnote, params:get("midi_channel_A"))
    end
    if params:get("seq_"..i.."_midi_B") == 2 then
      m:note_on(playnote,100,params:get("midi_channel_B"))
      clock.run(midihang, i, playnote, params:get("midi_channel_B"))
    end
    if params:get("seq_"..i.."_midi_C") == 2 then
      m:note_on(playnote,100,params:get("midi_channel_C"))
      clock.run(midihang, i, playnote, params:get("midi_channel_C"))
    end
    if params:get("seq_"..i.."_midi_D") == 2 then
      m:note_on(playnote,100,params:get("midi_channel_D"))
      clock.run(midihang, i, playnote, params:get("midi_channel_D"))
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
  
  function mollyhang(note,i)
    --print(time.modes[params:get("time"..i)]/2)
    clock.sleep(time.modes[params:get("time"..i)]/2)
    engine.noteOff(note)
  end
  
  function midihang(i, playnote, midi_ch)
    clock.sleep(time.modes[params:get("time"..i)]/2)
    m:note_off(playnote,100,midi_ch)
  end