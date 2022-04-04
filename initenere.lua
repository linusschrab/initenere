-- INITENERE
-- @vicimity (linus schrab)
-- https://llllllll.co/t/initenere
--
--  /// confining spaces 
--  of random seeds ///
--
-- main screen has eight edit 
-- positions, navigate with E1.
--
-- ~horizontal~
-- 1-4 manipulates time
-- E2 - change play directtion 
-- "-" pause,
-- ">" forward, 
-- "<" backward and 
-- "~" random
-- E3 -  slow down/speed up
-- /4 -> 16x
--
-- ~vertical~~
-- 5-8 alters to the note matrix
-- E2 - change play direction
-- "-" pause,
-- ">" forward, 
-- "<" backward and 
-- "~" random
-- E3 -  slow down/speed up
-- /4 -> 16x
-- 
-- alt. edit w. K3
-- hold while 1-4
-- E2: octave offset
-- E3: octave range
--
-- edit -> params
-- 
-- midi & outputs
-- route s1. -> s4.
--
-- time routings
-- interaction of
-- sequencers
-- 
-- scale & notes
-- 
-- molly the poly
-- w/syn

local music = require("musicutil")

--ploysub
local polysub = require 'polysub'
engine.name = "PolySub"

--molly the poly
--local MollyThePoly = require "molly_the_poly/lib/molly_the_poly_engine"
--engine.name = "MollyThePoly"

--uncomment below for the bangs
--thebangs = include('thebangs/lib/thebangs_engine')
--local Thebangs = require "thebangs/lib/thebangs_engine"
--engine.name = 'Thebangs'

--uncomment below for mx.samples
--mxsamples=include("mx.samples/lib/mx.samples")
--engine.name="MxSamples"
--instruments = {}

g = grid.connect()

lattice = include("initenere/lib/lattice")

screen_dirty = true

cycle_modes = {"-", ">", "<", "~"}
time = {
  names = {},
  modes = {}
}
for i=1,3 do
  time["names"][i] = "/"..(5-i)
  time["modes"][i] = 5-i
end
for i=1,16 do
  time["names"][i+3] = "x"..i
  time["modes"][i+3] = 1/i
end

oct_modes = {"x", "1", "2", "4"}

local crow_gate_length = 0.005
local crow_gate_volts = 5

local pset_wsyn_curve = 0
local pset_wsyn_ramp = 0
local pset_wsyn_fm_index = 0
local pset_wsyn_fm_env = 0
local pset_wsyn_fm_ratio_num = 0
local pset_wsyn_fm_ratio_den = 0
local pset_wsyn_lpg_time = 0
local pset_wsyn_lpg_symmetry = 0

local transport_run = true

function clock.transport.start()
  if params:get("midi_transport") == 2 then
    time_handlers:hard_sync()
    transport_run = true
    screen_dirty = true
  end
end

function clock.transport.stop()
  if params:get("midi_transport") == 2 then
    for i=1,4 do
      matrix[i].x_position = 4
    end
    time_handlers:stop()
    transport_run = false
  end
end

--matrix to hold all note values
matrix = {}
for y=1,4 do
    matrix[y] = {
      x_position = 1,
      row = y,
      cycle_dir = 2,
      octave_range = 2,
      x_cycle_dir = 1,
      screen_time = 7,
      screen_y_time = 7
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

momentary = {}
for x = 1,16 do
  momentary[x] = {}
  for y = 1,8 do
    momentary[x][y] = false
  end
end

press_counter = {}
for x = 1,16 do
  press_counter[x] = {}
  for y = 1,8 do
    press_counter[x][y] = false
  end
end

function process_change(v)
  randomize_notes()
end

function init()

  for i = 1, #music.SCALES do
    table.insert(scales, string.lower(music.SCALES[i].name))
  end

  randomize_notes()
  add_params()
  m = midi.connect(params:get("midi_device"))

  time_handlers = lattice:new()
  global_time = time_handlers:new_pattern{
    action = function(x)  
      if time_dirty and #time_dirty_stack > 0 then
        for i=1,#time_dirty_stack do
          params:set("time"..time_dirty_stack[i]["seq"], time_dirty_stack[i]["time"])
          if time_dirty_stack[i]["seq"] > 4 then
            sequencers["seq_y"..(time_dirty_stack[i]["seq"] - 4)].phase = 0
          else
            sequencers["seq"..time_dirty_stack[i]["seq"]].phase = 0
          end
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
        if matrix[1].cycle_dir ~= 1 then
          advance_seq(1)
          if params:get("time_1_2") == 2 then advance_seq(2) end
          if params:get("time_1_3") == 2 then advance_seq(3) end
          if params:get("time_1_4") == 2 then advance_seq(4) end
        end
        screen_dirty = true
      end,
      division = time["modes"][matrix[1].screen_time]
    },
    seq2 = time_handlers:new_pattern{
      action = function(x)
        if matrix[2].cycle_dir ~= 1 then
          advance_seq(2)
          if params:get("time_2_1") == 2 then advance_seq(1) end
          if params:get("time_2_3") == 2 then advance_seq(3) end
          if params:get("time_2_4") == 2 then advance_seq(4) end
        end
        screen_dirty = true
      end,
      division = time["modes"][matrix[2].screen_time]
    },
    seq3 = time_handlers:new_pattern{
      action = function(x)
        if matrix[3].cycle_dir ~= 1 then
          advance_seq(3)
          if params:get("time_3_1") == 2 then advance_seq(1) end
          if params:get("time_3_2") == 2 then advance_seq(2) end
          if params:get("time_3_4") == 2 then advance_seq(4) end
        end   
        screen_dirty = true
      end,
      division = time["modes"][matrix[3].screen_time]
    },
    seq4 = time_handlers:new_pattern{
      action = function(x)
        if matrix[4].cycle_dir ~= 1 then
          advance_seq(4)
          if params:get("time_4_1") == 2 then advance_seq(1) end
          if params:get("time_4_2") == 2 then advance_seq(2) end
          if params:get("time_4_3") == 2 then advance_seq(3) end
        end  
        screen_dirty = true
      end,
      division = time["modes"][matrix[4].screen_time]
    },
    
    seq_y1 = time_handlers:new_pattern{
      action = function(x)
        rotate(1)
        screen_dirty = true
      end,
      division = time["modes"][matrix[1].screen_y_time]
    },
    seq_y2 = time_handlers:new_pattern{
      action = function(x)
        rotate(2)
        screen_dirty = true
      end,
      division = time["modes"][matrix[2].screen_y_time]
    },
    seq_y3 = time_handlers:new_pattern{
      action = function(x)
        rotate(3)
        screen_dirty = true
      end,
      division = time["modes"][matrix[3].screen_y_time]
    },
    seq_y4 = time_handlers:new_pattern{
      action = function(x)
        rotate(4)
        screen_dirty = true
      end,
      division = time["modes"][matrix[4].screen_y_time]
    }
  }

  for i=1,4 do
    params:add_number("time"..i, "s"..i.." division", 1,19,7)
    params:set_action("time"..i, function(x)
      sequencers["seq"..i]:set_division(time.modes[x])
      matrix[i].screen_time = x
    end)
    params:hide("time"..i)
  end

  for i=5,8 do
    params:add_number("time"..i, "s"..i.." division", 1,19,7)
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
            grid_redraw()
            screen_dirty = false
        end
    end
end

function add_params()
  params:add_group("load & save", 3)
  params:add_number("selected_set", "set", 1,100,1)
  params:add{type = "trigger", id = "load", name = "load", action = loadstate}
  params:add{type = "trigger", id = "save", name = "save", action = savestate}

  params:add_group("midi, crow & outputs",49)
  params:add_separator("midi")
  params:add_number("midi_device", "midi device", 1, #midi.vports, 1)
  params:add_number("midi_channel_A", "midi channel A", 1, 16, 1)
  params:add_number("midi_channel_B", "midi channel B", 1, 16, 2)
  params:add_number("midi_channel_C", "midi channel C", 1, 16, 3)
  params:add_number("midi_channel_D", "midi channel D", 1, 16, 4)
  params:add_option("midi_transport", "midi/link transport", {"off", "on"}, 2)
  params:set_action("midi_transport", function (x) 
    if x == 1 then transport_run = true end
  end)

  params:add_separator("crow")
  params:add_option("crow_in", "in 2 -> randomize notes", {"no", "yes"}, 1)
  params:set_action("crow_in", function(x)
    if x == 2 then
      crow.input[2].change = process_change
      crow.input[2].mode("change", 2.0, 0.25, "rise")
    else
      crow.input[2].mode("none")
    end
  end)

  for i=1,4 do
    params:add_separator("s"..i..". outputs")
    params:add_option("seq_"..i.."_engine", "s"..i..". -> engine", {"no", "yes"}, 2)
    params:add_option("seq_"..i.."_midi_A", "s"..i..". -> midi ch A", {"no", "yes"}, 2)
    params:add_option("seq_"..i.."_midi_B", "s"..i..". -> midi ch B", {"no", "yes"}, 1)
    params:add_option("seq_"..i.."_midi_C", "s"..i..". -> midi ch C", {"no", "yes"}, 1)
    params:add_option("seq_"..i.."_midi_D", "s"..i..". -> midi ch D", {"no", "yes"}, 1)
    params:add_option("seq_"..i.."_crow_1", "s"..i..". -> crow 1/2", {"no", "yes"}, 1)
    params:set_action("seq_"..i.."_crow_1", function (x)
      crow.output[2].action = "{to(".. crow_gate_volts ..",0),to(0,".. crow_gate_length .. ")}" 
    end)
    params:add_option("seq_"..i.."_crow_2", "s"..i..". -> crow 3/4", {"no", "yes"}, 1)
    params:set_action("seq_"..i.."_crow_2", function (x)
      crow.output[4].action = "{to(".. crow_gate_volts ..",0),to(0,".. crow_gate_length .. ")}" 
    end)
    params:add_option("seq_"..i.."_JF", "s"..i..". -> JF", {"no", "yes"}, 1)
    params:set_action("seq_"..i.."_JF", function(x)
      if params:get("seq_".. util.wrap(i+1,1,4) .."_JF") == 1 or params:get("seq_".. util.wrap(i+2,1,4) .."_JF") == 1 or params:get("seq_".. util.wrap(i+3,1,4) .."_JF") == 1 then
        if x == 2 then
          crow.ii.jf.mode(1)
        else
          crow.ii.jf.mode(0)
        end
      end
    end)
    params:add_option("seq_"..i.."_w", "s"..i..". -> w/syn", {"no", "yes"}, 1)
  end

  params:add_group("note prob. & time routings", 22)
  params:add_separator("note probability")
  for i = 1,4 do
    params:add_control("prob_"..i, "s"..i..".", controlspec.new(0,100,'lin',1,100,'%'))
  end

  params:add_separator("time routings")
  params:add_separator(" - s1. - ")

  params:add_option("time_1_2", "-> s2.", {"no", "yes"}, 1)
  params:add_option("time_1_3", "-> s3.", {"no", "yes"}, 1)
  params:add_option("time_1_4", "-> s4.", {"no", "yes"}, 1)
  
  params:add_separator(" - s2. - ")
  params:add_option("time_2_1", "-> s1.", {"no", "yes"}, 1)
  params:add_option("time_2_3", "-> s3.", {"no", "yes"}, 1)
  params:add_option("time_2_4", "-> s4.", {"no", "yes"}, 1)
  
  params:add_separator(" - s3. - ")
  params:add_option("time_3_1", "-> s1.", {"no", "yes"}, 1)
  params:add_option("time_3_2", "-> s2.", {"no", "yes"}, 1)
  params:add_option("time_3_4", "-> s4.", {"no", "yes"}, 1)

  params:add_separator(" - s4. - ")
  params:add_option("time_4_1", "-> s1.", {"no", "yes"}, 1)
  params:add_option("time_4_2", "-> s2.", {"no", "yes"}, 1)
  params:add_option("time_4_3", "-> s3.", {"no", "yes"}, 1)
    

  params:add_group("scale, notes and octaves",15)
  params:add_separator("scale")
  params:add_option("scale","scale",scales,1)
  params:add_option("root_note", "root note", music.note_nums_to_names({0,1,2,3,4,5,6,7,8,9,10,11}),1)
  params:add_separator("notes")
  params:add_trigger("randomize_notes", "randomize note matrix")
  params:set_action("randomize_notes", function(x) randomize_notes() end)
  params:add_separator("octave offset")
  for i=1,4 do
    params:add_number("seq_"..i.."_off", "s"..i..". octave offset", -3,3,0)
  end
  params:add_separator("octave range")
  params:add_option("seq_1_oct", "s1. oct range +/-", oct_modes, 3)
  params:add_option("seq_2_oct", "s2. oct range +/-", oct_modes, 3)
  params:add_option("seq_3_oct", "s3. oct range +/-", oct_modes, 3)
  params:add_option("seq_4_oct", "s4. oct range +/-", oct_modes, 3)

  --molly  the poly
  --params:add_group("molly the poly", 46)
  --MollyThePoly.add_params()
  --uncomment below for the bangs
  --params:add_group("the bangs", 6)
  --Thebangs.add_additional_synth_params()
  --Thebangs.add_voicer_params()
  --uncomment below for the mx.samples
  --skeys=mxsamples:new()
  --instruments = skeys:list_instruments()
  --params:add_option("mx_ins", "MX.INSTRUMENT", instruments, 1)
  params:add_group("polysub", 19)
  polysub.params()
  wsyn_add_params()
  params:bang()
  params:set("wsyn_init",1)
end

function wsyn_add_params()
  params:add_group("w/syn",11)
  params:add {
    type = "option",
    id = "wsyn_ar_mode",
    name = "AR mode",
    options = {"off", "on"},
    default = 2,
    action = function(val) 
      crow.send("ii.wsyn.ar_mode(".. (val-1) ..")")
    end
  }
  params:add {
    type = "control",
    id = "wsyn_vel",
    name = "Velocity",
    controlspec = controlspec.new(0, 5, "lin", 0, 2.5, "v"),
    action = function(val) 
      pset_wsyn_vel = val
    end
  }
  params:add {
    type = "control",
    id = "wsyn_curve",
    name = "Curve",
    controlspec = controlspec.new(-5, 5, "lin", 0, 0, "v"),
    action = function(val) 
      crow.send("ii.wsyn.curve(" .. val .. ")") 
      pset_wsyn_curve = val
    end
  }
  params:add {
    type = "control",
    id = "wsyn_ramp",
    name = "Ramp",
    controlspec = controlspec.new(-5, 5, "lin", 0, 0, "v"),
    action = function(val) 
      crow.send("ii.wsyn.ramp(" .. val .. ")") 
      pset_wsyn_ramp = val
    end
  }
  params:add {
    type = "control",
    id = "wsyn_fm_index",
    name = "FM index",
    controlspec = controlspec.new(0, 5, "lin", 0, 0, "v"),
    action = function(val) 
      crow.send("ii.wsyn.fm_index(" .. val .. ")") 
      pset_wsyn_fm_index = val
    end
  }
  params:add {
    type = "control",
    id = "wsyn_fm_env",
    name = "FM env",
    controlspec = controlspec.new(-5, 5, "lin", 0, 0, "v"),
    action = function(val) 
      crow.send("ii.wsyn.fm_env(" .. val .. ")") 
      pset_wsyn_fm_env = val
    end
  }
  params:add {
    type = "control",
    id = "wsyn_fm_ratio_num",
    name = "FM ratio numerator",
    controlspec = controlspec.new(1, 20, "lin", 1, 2),
    action = function(val) 
      crow.send("ii.wsyn.fm_ratio(" .. val .. "," .. params:get("wsyn_fm_ratio_den") .. ")") 
      pset_wsyn_fm_ratio_num = val
    end
  }
  params:add {
    type = "control",
    id = "wsyn_fm_ratio_den",
    name = "FM ratio denominator",
    controlspec = controlspec.new(1, 20, "lin", 1, 1),
    action = function(val) 
      crow.send("ii.wsyn.fm_ratio(" .. params:get("wsyn_fm_ratio_num") .. "," .. val .. ")") 
      pset_wsyn_fm_ratio_den = val
    end
  }
  params:add {
    type = "control",
    id = "wsyn_lpg_time",
    name = "LPG time",
    controlspec = controlspec.new(-5, 5, "lin", 0, 0, "v"),
    action = function(val) 
      crow.send("ii.wsyn.lpg_time(" .. val .. ")") 
      pset_wsyn_lpg_time = val
    end
  }
  params:add {
    type = "control",
    id = "wsyn_lpg_symmetry",
    name = "LPG symmetry",
    controlspec = controlspec.new(-5, 5, "lin", 0, 0, "v"),
    action = function(val) 
      crow.send("ii.wsyn.lpg_symmetry(" .. val .. ")") 
      pset_wsyn_lpg_symmetry = val
    end
  }
  params:add{
    type = "trigger",
    id = "wsyn_randomize",
    name = "Randomize",
    allow_pmap = false,
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
  params:add{
    type = "trigger",
    id = "wsyn_init",
    name = "Init",
    action = function()
      params:set("wsyn_curve", pset_wsyn_curve)
      params:set("wsyn_ramp", pset_wsyn_ramp)
      params:set("wsyn_fm_index", pset_wsyn_fm_index)
      params:set("wsyn_fm_env", pset_wsyn_fm_env)
      params:set("wsyn_fm_ratio_num", pset_wsyn_fm_ratio_num)
      params:set("wsyn_fm_ratio_den", pset_wsyn_fm_ratio_den)
      params:set("wsyn_lpg_time", pset_wsyn_lpg_time)
      params:set("wsyn_lpg_symmetry", pset_wsyn_lpg_symmetry)
    end
  }
  params:hide("wsyn_init")
end

--fill the matrix with random notes
function randomize_notes()
    for y=1,4 do
        for x=1,4 do
            matrix[y][x].note = math.random(36,84)
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
      else --if matrix[edit-4].x_cycle_dir ~= 1 then
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

function long_press(x,y)
  if x == 5 and y < 7 and y > 2 then
    if momentary[x+1][y] then
      matrix[y-2].cycle_dir = 4
      dont_sleep = true
      return
    end
  end
  if x == 6 and y < 7 and y > 2 then
    if momentary[x-1][y] then
      matrix[y-2].cycle_dir = 4
      dont_sleep = true
      return
    end
  end
  if y == 1 and x < 11 and x > 6 then
    if momentary[x][y+1] then
      matrix[x-6].x_cycle_dir = 4
      dont_sleep = true
      return
    end
  end
  if y == 2 and x < 11 and x > 6 then
    if momentary[x][y-1] then
      matrix[x-6].x_cycle_dir = 4
      dont_sleep = true
      return
    end
  end
  clock.sleep(.5)
  if x == 5 and y < 15 and y > 2 then
      matrix[y-2].cycle_dir = 1
  elseif x == 6 and y < 15 and y > 2 then
      matrix[y-2].cycle_dir = 1
  end
  if y == 1 and x < 11 and x > 6 then
      matrix[x-6].x_cycle_dir = 1
  elseif y == 2 and x < 11 and x > 6 then
      matrix[x-6].x_cycle_dir = 1
  end
  
  press_counter[x][y] = nil
end

function short_press(x,y)
  if x == 5 and y < 7 and y > 2 then
      matrix[y-2].cycle_dir = 3
  elseif x == 6 and y < 7 and y > 2 then
      matrix[y-2].cycle_dir = 2
  end
  if y == 1 and x < 11 and x > 6 then
      matrix[x-6].x_cycle_dir = 3
  elseif y == 2 and x < 11 and x > 6 then
      matrix[x-6].x_cycle_dir = 2
  end
end

g.key = function(x,y,z)
  if z == 1 then
    momentary[x][y] = true
    dont_sleep = false
    press_counter[x][y] = clock.run(long_press,x,y)

    if x == 16 and y > 2 and y < 7 then
      for i=1,4 do
        if momentary[1][i+2] then
          for j=1,4 do
            if j ~= y-2 then
              params:set("time_"..i.."_"..y-2, params:get("time_"..i.."_"..y-2) == 2 and 1 or 2)
            end
          end
        end
      end
    end

    if x > 6 and x < 11 and y > 2 and y < 7 then
      for i=1,4 do
        if momentary[1][i+2] then
          for j=1,4 do
            if j == y-2 then
              params:set("prob_"..i, (x-6)*25)
            end
          end
        end
      end
    end
    

    if x > 6 and x < 11 and y > 2 and y < 7 then
      if momentary[1][y] ~= true then
        matrix[y - 2].x_position = x - 6
        play(y - 2)
      end
    end
    
    if x == 11 and y < 7 and y > 2 then
      matrix[y-2].screen_time = util.clamp(matrix[y-2].screen_time - 1, 1, #time.modes)
      table.insert(time_dirty_stack, {seq=y-2, time = util.clamp(matrix[y-2].screen_time, 1, #time.modes)})
      time_dirty = true
    elseif x == 12 and y < 7 and y > 2 then
      matrix[y-2].screen_time = util.clamp(matrix[y-2].screen_time + 1, 1, #time.modes)
      table.insert(time_dirty_stack, {seq=y-2, time = util.clamp(matrix[y-2].screen_time, 1, #time.modes)})
      time_dirty = true
    end
    if y == 7 and x < 11 and x > 6 then
      matrix[x-6].screen_y_time = util.clamp(matrix[x-6].screen_y_time - 1, 1, #time.modes)
      table.insert(time_dirty_stack, {seq=x-2, time = util.clamp(matrix[x-6].screen_y_time, 1, #time.modes)})
      time_dirty = true
    elseif y == 8 and x < 11 and x > 6 then
      matrix[x-6].screen_y_time = util.clamp(matrix[x-6].screen_y_time + 1, 1, #time.modes)
      table.insert(time_dirty_stack, {seq=x-2, time = util.clamp(matrix[x-6].screen_y_time, 1, #time.modes)})
      time_dirty = true
    end
    if x == 2 and y < 7 and y > 2 then
      params:set("seq_"..(y-2).."_off", util.clamp(params:get("seq_"..(y-2).."_off")-1,-3,3))
    elseif x == 3 and y < 7 and y > 2 then
      params:set("seq_"..(y-2).."_off", util.clamp(params:get("seq_"..(y-2).."_off")+1,-3,3))
    end
    if x == 14 and y < 7 and y > 2 then
      params:set("seq_"..(y-2).."_oct", util.clamp(params:get("seq_"..(y-2).."_oct")-1,1,#oct_modes))
    elseif x == 15 and y < 7 and y > 2 then
      params:set("seq_"..(y-2).."_oct", util.clamp(params:get("seq_"..(y-2).."_oct")+1,1,#oct_modes))
    end
  else 
    if press_counter[x][y] then
      clock.cancel(press_counter[x][y])
      if dont_sleep ~= true then short_press(x,y) end
    end
    momentary[x][y] = false
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

function grid_redraw()
  g:all(0)

  for i=1,4 do
    if momentary[1][i+2] == true then
      prob_led = math.floor(util.round((params:get("prob_"..i) / 100) * 4, 0))
      for j=1,prob_led do
        g:led(6+j,i+2,8)
      end
    else
      for x=1,4 do
        if x == matrix[i].x_position then hl = 15 else hl = 3 end
        g:led(6+x,i+2,hl)
      end
    end
  end
  
  
  --direction leds
  for y=1,4 do
    if matrix[y].cycle_dir == 4 then
      g:led(5,2+y,15)
      g:led(6,2+y,15)
    else
      g:led(5,2+y,matrix[y].cycle_dir == 3 and 15 or 5)
      g:led(6,2+y,matrix[y].cycle_dir == 2 and 15 or 5)
    end
  end
  --octave offset leds
  for y=1,4 do
    hl = (params:get("seq_"..y.."_off") + 4) * 2 
    g:led(2,2+y,14-hl)
    g:led(3,2+y,hl)
  end
  --speed leds
  for y=1,4 do
    hl = math.floor( 15 * matrix[y].screen_time / #time.modes )
    g:led(11,2+y,15-hl)
    g:led(12,2+y,hl)
  end
  --octave range leds
  for y=1,4 do
    hl = params:get("seq_"..y.."_oct") * 4 - 1
    g:led(14,2+y,15-hl)
    g:led(15,2+y,hl)
  end

  --direction vertical
  for x=1,4 do
    --edit == "seed/rule" and 15 or 2
    if matrix[x].x_cycle_dir == 4 then
      g:led(6+x,1,15)
      g:led(6+x,2,15)
    else
      g:led(x+6,1,matrix[x].x_cycle_dir == 3 and 15 or 5)
      g:led(x+6,2,matrix[x].x_cycle_dir == 2 and 15 or 5)
    end
  end

  --speed vertical
  for x=1,4 do
    hl = math.floor( 15 * matrix[x].screen_y_time / #time.modes )    
    g:led(6+x,7,15-hl)
    g:led(6+x,8,hl)
  end

  for i=3,6 do
    if momentary[13][i] == true then
      g:led(13,i,8)
    end
  end

  for i=3,6 do
    if momentary[4][i] == true then
      g:led(4,i,8)
    end
  end

  for i=1,4 do
    if momentary[1][i+2] == true then
      g:led(1,i+2,8)
      for j=1,4 do
        if i ~= j then
          if params:get("time_"..i.."_"..j) == 2 then g:led(16,j+2,8) end
        end
      end
    end
  end

  screen_dirty = true
  g:refresh()
end

function test_draw()
  for y=1,4 do
    for x=1,4 do
      screen.move(x*10,y*10)
      screen.text(matrix[y][x].note)
    end
  end
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
    
    --test_draw()

    for i=1,4 do
      screen.level(1)
      screen.move(5,9+i*10+y_off)
      screen.text("o "..params:get("seq_"..i.."_off"))
      screen.move(22,9+i*10+y_off)
      screen.text(" |")
      screen.move(35,9+i*10+y_off)
      screen.text(cycle_modes[matrix[i].cycle_dir])
      screen.move(89,8+i*10+y_off)
      screen.text(time["names"][matrix[i].screen_time])
      screen.move(100,8+i*10+y_off)
      screen.text(" | "..oct_modes[params:get("seq_"..i.."_oct")])
      screen.move(114,8+i*10+y_off)
      screen.text(" o")
      screen.text_rotate(35+i*10, 4+y_off,cycle_modes[matrix[i].x_cycle_dir],90)
      screen.text_rotate(35+i*10, 55+y_off, time["names"][matrix[i].screen_y_time], 90)
      screen.level(edit_foci[edit] == "y_"..i and 15 or 5)
      screen.move(4,8+i*10+y_off)
      screen.text("o "..params:get("seq_"..i.."_off"))
      screen.move(21,8+i*10+y_off)
      screen.text(" |")
      screen.move(34,8+i*10+y_off)
      screen.text(cycle_modes[matrix[i].cycle_dir])
      screen.move(88,7+i*10+y_off)
      screen.text(time["names"][matrix[i].screen_time])
      screen.move(99,7+i*10+y_off)
      screen.text(" | "..oct_modes[params:get("seq_"..i.."_oct")])
      screen.move(113,7+i*10+y_off)
      screen.text(" o")
      screen.level(edit_foci[edit] == "x_"..i and 15 or 5)
      screen.text_rotate(34+i*10, 3+y_off,cycle_modes[matrix[i].x_cycle_dir],90)
      screen.text_rotate(34+i*10, 54+y_off, time["names"][matrix[i].screen_y_time], 90)
    end
    screen.update()
    screen_dirty = false
end

function advance_seq(i)
  if momentary[4][2+i] ~= true then
    if cycle_modes[matrix[i].cycle_dir] == ">" then
      matrix[i].x_position = util.wrap(matrix[i].x_position + 1, 1, 4)
    elseif cycle_modes[matrix[i].cycle_dir] == "<" then
      matrix[i].x_position = util.wrap(matrix[i].x_position - 1, 1, 4)
    elseif  cycle_modes[matrix[i].cycle_dir] == "~" then
      matrix[i].x_position = math.random(1, 4)
    end
  end
  if math.random(0,100) <= params:get("prob_"..i) and cycle_modes[matrix[i].cycle_dir] ~= "-" then
    play(i)
  end
end

function rotate(x)
      if cycle_modes[matrix[x].x_cycle_dir] == ">" then
        tmp_note = matrix[1][x].note
        for i=1,4 do
          lcl_tmp = matrix[util.wrap(i+1,1,4)][x].note
          matrix[util.wrap(i+1,1,4)][x].note = tmp_note
          tmp_note = lcl_tmp
        end
      elseif cycle_modes[matrix[x].x_cycle_dir] == "<" then
        tmp_note = matrix[1][x].note
        for i=1,4 do
          lcl_tmp = matrix[util.wrap(1-i,1,4)][x].note
          matrix[util.wrap(1-i,1,4)][x].note = tmp_note
          tmp_note = lcl_tmp
        end
      elseif cycle_modes[matrix[x].x_cycle_dir] == "~" then
        tmp_notes = {}
        for i=1, 4 do
          table.insert(tmp_notes, matrix[i][x].note)
        end
        tmp_notes = shuffle(tmp_notes)
        for i=1, 4 do
          matrix[i][x].note = tmp_notes[i]
        end
      end
      screen_dirty = true
end

function shuffle(tbl)
  for i = #tbl, 2, -1 do
    local j = math.random(i)
    tbl[i], tbl[j] = tbl[j], tbl[i]
  end
  return tbl
end

function play(i)
  i_note = matrix[i][matrix[i].x_position].note

  if params:get("seq_"..i.."_oct") == 4 then -- +/- 2 octaves
    tmp_off = 60
    if i_note > tmp_off + 24 then
      i_note = tmp_off + 12 + i_note % 12
    elseif i_note < tmp_off - 24 then
      i_note = tmp_off - 24 + i_note % 12
    end
  elseif params:get("seq_"..i.."_oct") == 3 then -- +/- 1 octaves
    tmp_off = 60
    if i_note > tmp_off + 12 then
      i_note = tmp_off + i_note % 12
    elseif i_note < tmp_off - 12 then
      i_note = tmp_off - 12 + i_note % 12
    end
  elseif params:get("seq_"..i.."_oct") == 2 then -- + 1 octave
    tmp_off = 60
    if i_note > tmp_off + 12 or i_note < tmp_off - 12 then
      i_note = 60 + i_note % 12
    end
  elseif params:get("seq_"..i.."_oct") == 1 then 
    tmp_off = 60
    i_note = 60 + params:get("root_note") - 1
  end
  playnote = i_note + (12 * params:get("seq_"..i.."_off"))

  scale = music.generate_scale(params:get("root_note")-1, scales[params:get("scale")], 10)
  playnote = music.snap_note_to_array(playnote,scale)
  
  if momentary[13][2+i] ~= true then
    if params:get("seq_"..i.."_engine") == 2 then
      --molly the poly
      --engine.noteOn(playnote, music.note_num_to_freq(playnote),100)
      --clock.run(eng_hang, playnote,i)
      --uncomment below for the bangs
      --engine.hz(music.note_num_to_freq(playnote))
      --uncomment below for mx.samples
      --skeys:on({name=instruments[params:get("mx_ins")],midi=playnote,velocity=120})
      --polysub
      engine.start(i,music.note_num_to_freq(playnote))
      clock.run(eng_hang, playnote, i)
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
      crow.output[2]()
    end
    if params:get("seq_"..i.."_crow_2") == 2 then
      crow.output[3].volts = (((playnote)-60)/12)
      crow.output[4]()
    end
    if params:get("seq_"..i.."_JF") == 2 then
      crow.ii.jf.play_note(((playnote)-60)/12,5)
    end
    if params:get("seq_"..i.."_w") == 2 then
      crow.send("ii.wsyn.play_note(".. ((playnote)-60)/12 ..", " .. params:get("wsyn_vel") .. ")")
    end
  end
end
  
function eng_hang(note,i)
  clock.sleep(time.modes[params:get("time"..i)]/2)
  --molly & the bangs
  --engine.noteOff(note)
  --uncomment below for mx.samples
  --skeys:off({name=instruments[params:get("mx_ins")],midi=note})
  --polysub
  engine.stop(i)
end

function midihang(i, playnote, midi_ch)
  clock.sleep(time.modes[params:get("time"..i)]/2)
  m:note_off(playnote,100,midi_ch)
end

function savestate()
  local file = io.open(_path.data .. "initenere/initenere-pattern"..params:get("selected_set")..".data", "w+")
  io.output(file)
  io.write("initenere".."\n")
  for y=1,4 do
    io.write(matrix[y].x_position .. "\n")
    io.write(matrix[y].row  .. "\n")
    io.write(matrix[y].cycle_dir .. "\n")
    io.write(matrix[y].octave_range .. "\n")
    io.write(matrix[y].x_cycle_dir  .. "\n")
    io.write(matrix[y].screen_time  .. "\n")
    io.write(matrix[y].screen_y_time  .. "\n")
    for x=1,4 do
      io.write(matrix[y][x].note .. "\n")
    end
  end
  
  io.write(pset_wsyn_curve .. "\n")
  io.write(pset_wsyn_ramp .. "\n")
  io.write(pset_wsyn_fm_index .. "\n")
  io.write(pset_wsyn_fm_env .. "\n")
  io.write(pset_wsyn_fm_ratio_num .. "\n")
  io.write(pset_wsyn_fm_ratio_den .. "\n")
  io.write(pset_wsyn_lpg_time .. "\n")
  io.write(pset_wsyn_lpg_symmetry .. "\n")

  io.close(file)
  params:write(_path.data .. "initenere/initenere-0"..params:get("selected_set"))
end

function loadstate()
  local file = io.open(_path.data .. "initenere/initenere-pattern"..params:get("selected_set")..".data", "r")
  if file then
    io.input(file)
    filetype = io.read()
    if filetype == "initenere" then

      for y=1,4 do
        matrix[y].x_position = tonumber(io.read())
        matrix[y].row = tonumber(io.read())
        matrix[y].cycle_dir = tonumber(io.read())
        matrix[y].octave_range = tonumber(io.read())
        matrix[y].x_cycle_dir = tonumber(io.read())
        matrix[y].screen_time = tonumber(io.read())
        matrix[y].screen_y_time = tonumber(io.read())
        for x=1,4 do
            matrix[y][x].note = tonumber(io.read())
        end
    end
    params:read(_path.data .. "initenere/initenere-0"..params:get("selected_set"))
    params:bang()
    pset_wsyn_curve = tonumber(io.read())
    pset_wsyn_ramp = tonumber(io.read())
    pset_wsyn_fm_index = tonumber(io.read())
    pset_wsyn_fm_env = tonumber(io.read())
    pset_wsyn_fm_ratio_num = tonumber(io.read())
    pset_wsyn_fm_ratio_den  = tonumber(io.read())
    pset_wsyn_lpg_time = tonumber(io.read())
    pset_wsyn_lpg_symmetry = tonumber(io.read())
    params:set("wsyn_init",1)
    else
      print("invalid data file")
    end
    io.close(file)
    screen_dirty = true
  end
end

function rerun()
  norns.script.load(norns.state.script)
end

function bang()
  params:bang()
end
