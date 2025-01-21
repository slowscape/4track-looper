-- 4 track looper [unclocked]
-- A simple unclocked 4 track looper.

-- E1 = Select Voice.
-- E2 = Select Level or Rate.
-- E3 = Set selected value.
-- K2 = Overdub / play
-- K3 = Record / Play
--

local cs = require 'controlspec'
local viewport = { width = 128, height = 64, frame = 0 }
local state = {"stop","stop","stop","stop"}
local start_time = {0,0,0,0}
local loop_len = {0,0,0,0}
local s1 = 1
local s2 = 1
local met = false
local modd = false

-- 1=lvl, 2=rate
local v = {
  {1,1,1,1},
  {1,1,1,1},
  {17000,17000,17000,17000}
}

function init()
  audio.level_cut(1)
  audio.level_adc_cut(1)
  audio.level_eng_cut(1)
  for i=1,4 do
    if i<=2 then
        -- Voice 1,2 use the start of buffer 1,2
        softcut.buffer(i,i)
        softcut.position(i, 1)
        softcut.loop_start(i, 1)
        softcut.loop_end(i, 44)
        softcut.level_input_cut(i, i, 1.0) -- I don't understand channels. This may not be r ight.
      else
        -- Voice 3,4 use the end of buffer 1,2
        softcut.buffer(i,i-2)
        softcut.position(i, 45)
        softcut.loop_start(i, 45)
        softcut.loop_end(i, 91)
        softcut.level_input_cut(i-2, i, 1.0) -- I don't understand channels. This may not be r ight.
    end
    softcut.level(i,0)
    softcut.level_slew_time(i,0.1)
    softcut.post_filter_lp(i,1.0)
    softcut.post_filter_dry(i,0.0)
    softcut.post_filter_fc(i,17000)
    softcut.post_filter_rq(i,10)
    softcut.pan(i, 0)
    softcut.play(i, 1)
    softcut.rate(i, 1)
    softcut.rate_slew_time(i,0.1)
    softcut.loop(i, 1)
    softcut.fade_time(i, 0.1)
    softcut.rec(i, 1)
    softcut.rec_level(i, 0)
    softcut.pre_level(i, 0.5)
    softcut.enable(i, 1)
    softcut.filter_dry(i, 1);
  end
end

local function rec(i)
  start_time[i] = util.time()
  if s1 <= 2 then
    -- if voice 1,2 clear correct section of buffers
    softcut.buffer_clear_region_channel(i,0,44) -- I don't understand channels. This may not be r ight.
    softcut.position(i, 1)
    softcut.loop_end(i, 44)
    print("clear "..i)
  else
    -- if voice 3,4 clear correct section of buffers
    softcut.buffer_clear_region_channel(i-2,45,91) -- I don't understand channels. This may not be r ight.
    softcut.position(i, 45)
    softcut.loop_end(i, 91)
     print("clear "..i)
  end
  softcut.level(i,0)
  softcut.rec_level(i, 1)
  softcut.pre_level(i, 0)
  state[i] = "rec"
  print("recording "..i)
end

local function ovrdub(i)
  start_time[i] = util.time()
  if s1 <= 2 then
    -- if voice 1,2 clear correct section of buffers
    softcut.position(i, 1)
    softcut.loop_end(i, 44)
    print("overdub "..i)
  else
    -- if voice 3,4 clear correct section of buffers
    softcut.position(i, 45)
    softcut.loop_end(i, 91)
     print("overdub "..i)
  end
  softcut.level(i,0)
  softcut.rec_level(i, 1)
  softcut.pre_level(i, .5)
  state[i] = "rec"
  print("dubbing "..i)
end



local function play(i)
  loop_len[i] = util.time() - start_time[i]
  print(loop_len[i])
  softcut.level(i,1)
  softcut.rec_level(i, 0)
  softcut.pre_level(i, 1)
  if i <=2 then
    -- Voice 1,2 play correct portion of buffer
    softcut.position(i, 1)
    softcut.loop_end(i, loop_len[i] + 1)
    print("play "..i)
  else
    -- Voice 3,4 play correct portion of buffer
    softcut.position(i, 45)
    softcut.loop_end(i, loop_len[i] + 45)
    print("play "..i.." loop end "..loop_len[i])
  end
  state[i] = "play"
end

function key(n,z)
  
  if n==1 and z==1 then
    modd = true
  else
    modd = false
  end

  if n==2 and z==1 and state[s1]~="rec" then
    ovrdub(s1)
  elseif n==2 and z==1 and state[s1]=="rec" then
    play(s1)
  end
  
  if n==3 and z==1 and not modd and state[s1]~="rec" then
    rec(s1)
  elseif n==3 and z==1 and state[s1]=="rec" then
    play(s1)
  end
  redraw()
end

function enc(n,z)
  if n==1 then 
    -- select track.
    s1 = s1 + z
    s1 = util.clamp(s1,1,4)
    
  elseif n==2 then
    -- select feature on track.
    s2 = s2 + z
    s2 = util.clamp(s2,1,3)
  elseif n==3 and not modd then
    -- change selected feature.
    if s2 == 1 then
      -- change volume for selected voice.
      v[s2][s1] = util.clamp(v[s2][s1]+ (z*.1),0,10)
      softcut.level(s1, v[s2][s1])
      print(v[s2][s1])
    elseif s2 == 2 then
      -- change rate for selected voice
      v[s2][s1] = util.clamp(v[s2][s1]+(z*.1),-2,2)
      softcut.rate(s1, v[s2][s1])
    elseif s2 == 3 then
      if v[s2][s1] >= 500 then 
        v[s2][s1] = v[s2][s1] + (z*150)
      else
        v[s2][s1] = v[s2][s1] + (z*10)
      end
      v[s2][s1] = util.clamp(v[s2][s1],0,25000)
      softcut.post_filter_fc(s1,v[s2][s1])
    end
  end
  redraw()
end



------ dRawiNG stUFF ---------
-- Images
local t1 = {
  {1,1,1,1,1},
  {1,0,0,0,1},
  {1,0,0,0,1},
  {1,0,0,0,1},
  {1,1,1,1,1}
}
local t2 = {
  {1,1,1,1,1},
  {1,0,0,0,1},
  {1,0,0,0,1},
  {1,0,0,1,1},
  {1,1,1,1,0}
}
local t3 = {
  {1,1,1,1,1},
  {1,0,0,0,1},
  {1,0,1,0,1},
  {1,0,0,0,1},
  {1,1,1,1,1}
}
local t4 = {
  {1,1,1,1,1},
  {1,0,0,0,1},
  {1,0,0,0,1},
  {1,0,0,0,1},
  {0,1,1,1,1}
}

-- Track X offsets
local t1x = 30
local t2x = 50
local t3x = 70
local t4x = 90

function redraw()
	screen.clear()
  
  -- the four tracks
  for x in ipairs(t1) do
    for y in ipairs(t1) do 
      screen.level(s1 == 1 and 15 or 2)
      if t1[x][y] == 1 then
        if state[1] == 'rec' then 
          screen.pixel(x+t1x,y+5+math.random(18))
        end
        screen.pixel(x+t1x,y+15)
        screen.fill()
      end
      screen.level(s1 == 2 and 15 or 2)
      if t2[x][y] == 1 then
        if state[2] == 'rec' then 
          screen.pixel(x+t2x,y+5+math.random(18))
        end
        screen.pixel(x+t2x,y+15)
        screen.fill()
      end
      screen.level(s1 == 3 and 15 or 2)
      if t3[x][y] == 1 then
        if state[3] == 'rec' then 
          screen.pixel(x+t3x,y+5+math.random(18))
        end
        screen.pixel(x+t3x,y+15)
        screen.fill()
      end
      screen.level(s1 == 4 and 15 or 2)
      if t4[x][y] == 1 then
        if state[4] == 'rec' then 
          screen.pixel(x+t4x,y+5+math.random(18))
        end
        screen.pixel(x+t4x,y+15)
        screen.fill()
      end
    end
  end
  
  -- level
  screen.level(s2 == 1 and s1 == 1 and 15 or 2)
  lvl = util.linlin(0,10,1,5,v[1][1])
  screen.move(t1x+1,23)
  screen.line(lvl+t1x+1,23)
  screen.stroke()
  
  screen.level(s2 == 1 and s1 == 2 and 15 or 2)
  lvl = util.linlin(0,10,1,5,v[1][2])
  screen.move(t2x+1,23)
  screen.line(lvl+t2x+1,23)
  screen.stroke()
  
  screen.level(s2 == 1 and s1 == 3 and 15 or 2)
  lvl = util.linlin(0,10,1,5,v[1][3])
  screen.move(t3x+1,23)
  screen.line(lvl+t3x+1,23)
  screen.stroke()
  
  screen.level(s2 == 1 and s1 == 4 and 15 or 2)
  lvl = util.linlin(0,10,1,5,v[1][4])
  screen.move(t4x+1,23)
  screen.line(lvl+t4x+1,23)
  screen.stroke()
  
  -- rate
  screen.level(s2 == 2 and s1 == 1 and 15 or 2)
  lvl = util.linlin(-2,2,1,5,v[2][1])
  screen.move(31,25)
  screen.line(lvl+31,25)
  screen.stroke()
  
  screen.level(s2 == 2 and s1 == 2 and 15 or 2)
  lvl = util.linlin(-2,2,1,5,v[2][2])
  screen.move(51,25)
  screen.line(lvl+51,25)
  screen.stroke()
  
  screen.level(s2 == 2 and s1 == 3 and 15 or 2)
  lvl = util.linlin(-2,2,1,5,v[2][3])
  screen.move(71,25)
  screen.line(lvl+71,25)
  screen.stroke()

  screen.level(s2 == 2 and s1 == 4 and 15 or 2)
  lvl = util.linlin(-2,2,1,5,v[2][4])
  screen.move(91,25)
  screen.line(lvl+91,25)
  screen.stroke()
  
  -- Lowpass
  screen.level(s2 == 3 and s1 == 1 and 15 or 2)
  lvl = util.linlin(0,17000,1,5,v[3][1])
  screen.move(31,27)
  screen.line(lvl+31,27)
  screen.stroke()
  
  screen.level(s2 == 3 and s1 == 2 and 15 or 2)
  lvl = util.linlin(0,17000,1,5,v[3][2])
  screen.move(51,27)
  screen.line(lvl+51,27)
  screen.stroke()
  
  screen.level(s2 == 3 and s1 == 3 and 15 or 2)
  lvl = util.linlin(0,17000,1,5,v[3][3])
  screen.move(71,27)
  screen.line(lvl+71,27)
  screen.stroke()

  screen.level(s2 == 3 and s1 == 4 and 15 or 2)
  lvl = util.linlin(0,17000,1,5,v[3][4])
  screen.move(91,27)
  screen.line(lvl+91,27)
  screen.stroke()
  

  -- words
  if s2 == 1 then 
    w1 = "LVL"
  elseif s2 == 2 then
    w1 = "RTE"
  elseif s2 == 3 then
    w1 = "FLT"
  end
  
  
  screen.level(2)
  screen.move(31,50)
  screen.font_size(8)
  screen.font_face(1)
  screen.text(w1.." "..v[s2][s1])
	
	screen.update()
end
