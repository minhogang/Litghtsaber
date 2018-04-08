pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
--litghtsaber
--by irdumb

function _init()
 t = 0
 sbr = init_saber(8)
 sbrci = 1
 across = true
 -- sbr2 = init_saber(11)
 -- sbr2.t += rnd(128)
 -- sbr2.x=20
 -- sbr2.y=100
 -- sbr2.a=.9
 -- sbr2.toggle(sbr2)
 sbrcs = {8,11,12,9,6}
 cs = {
  c8={2,8,14,7,14,8,1},
  c11={5,3,11,7,11,3,1},
  c12={5,13,12,7,12,1,1},
  c9={5,4,9,7,9,4,2},
  c6={5,15,6,7,6,5,1}
 }
 tns = 7.5

 cols = {
  c8={ 7,7,7,7,7,7,7,14,14,8,8,8,  4,2,2,1,1,1},
  c11={7,7,7,7,7,7,7,11,11,3,3,3,  5,5,5,1,1,1},
  c12={7,7,7,7,7,7,7,12,12,12,13,13,5,5,1,1,1,1},
  c9={ 7,7,7,7,7,7,7,9,9,9,4,4,    5,5,5,1,1,1},
  c6={ 7,7,7,7,7,7,7,6,6,6,10,10,  5,5,5,1,1,1}
 }

 --mouse
 poke(0x5f2d,1)
 mx=64 my=110 mb=0
 --mouse button cooldown
 --like btnp w/ mouse
 mbcd=0
 --for menu option later
 mouse_control = true

 rotating = false
 rott = 0
 rdir = 0
 pdir = ''
 previous_angle=sbr.a
 avg_mvs = {}
 avg_mv = 0
 avg_i = 1
 -- phone button pressed
 lit_pressed = 0
 col_pressed = 0

 moved = false
 moved_t = 0

 cpu_usage = stat(1)

 -- map n stuff
 door_t=1
 door_opened=0
 posts = 5
 wallx = 32
 wally = 40

 enemies = {}
 max_spawn_cooldown = 30
 spawn_cooldown = 0
 bullets = {}

 hurting = 0
 life = 10
 gpio = {}
 has_gpio = false
 points = 0

 _update = game_update
 _draw = game_draw
end

function game_update()
 t += .015

 -- if (btn(0)) sbr.x-=12
 -- if (btn(1)) sbr.x+=12
 -- if (btn(2)) sbr.y-=12
 -- if (btn(3)) sbr.y+=12

 gpio = {}
 for i=0x5f80, 0x5fa0 do 
  add(gpio, peek(i))
 end
 if (gpio[1] != 0) has_gpio = true


 if has_gpio then -- iphone control
  -- yaw
  reverse = (gpio[6] * 2)-1
  sbr.a = gpio[1]/255 * reverse
  -- change color
  -- gpio 6
  if (btnp(5) or col_pressed != gpio[7]) then
   sbrci = sbrci%#sbrcs + 1
   sbr.c = sbrcs[sbrci]
  end
  col_pressed = gpio[7]
  -- gpio accel z, y
  sbr.dx += -((gpio[13]/255) * 12 - 6) * 2
  sbr.dy += ((gpio[12]/255) * 12 - 6) * 2
  sbr.dx *= .95
  sbr.dy *= .95
  sbr.x = mid(0,128, sbr.x+sbr.dx)
  sbr.y = mid(0,128, sbr.y+sbr.dy)
  sbr.x = ((sbr.x - 64) * .925 + 64)
  sbr.y = ((sbr.y - 120) * .85 + 120)
 elseif mouse_control then 
  mx, my, mb = mouse()
  local pressed = false
  if mb==1 and mbcd==0 then
   pressed = true
   mbcd = 10
  end
  mbcd = max(mbcd - 1, 0)

  local ds = distancee(mx,my,sbr.x,sbr.y)
  local dx = mx - sbr.x
  local dy = my - sbr.y
  local a = atan2(dx, dy) + .75

  if (btn(4) or mb==1) then  -- try before commit
   a += .5
  end
  a %= 1
  if abs(a+1 - sbr.a) < abs(a-sbr.a) then
  	a += 1
  elseif abs(a-1 - sbr.a) < abs(a-sbr.a) then
  	a -= 1
  end

  if ds > 10  and moved_t > 10 and sbr.on then
   sfx(flr(3 + rnd(3)))
   moved = true
   moved_t = 0
  else
   moved = false
   moved_t += 1
  end


  if ds > .5 then 
  	sbr.a = lerp(sbr.a, a, .1)
  end
  
  --da = abs()

  sbr.x = lerp(sbr.x, mx, .9)
  sbr.y = lerp(sbr.y, my, .9)

  if (btnp(5)) then
   sbrci = sbrci%#sbrcs + 1
   sbr.c = sbrcs[sbrci]
  end
 else
  if (btn(0)) sbr.x-=12
  if (btn(1)) sbr.x+=12
  if (btn(2)) sbr.y-=12
  if (btn(3)) sbr.y+=12

  if (btn(4)) sbr.a+=.06
  if (btn(5)) sbr.a-=.06
 end


 -- if (pressed) sbr.toggle(sbr)
 -- shift key

 -- gpio 4
 if (btnp(4,1) or lit_pressed != gpio[5]) sbr.toggle(sbr)
 lit_pressed = gpio[5]
 --if (btnp(5,1)) across = not across

 --sbr2.update(sbr2)
 sbr.update(sbr)


 update_door()


 -- enemies
 spawn_cooldown = max(0,spawn_cooldown-1)

 spawn_fast = t%128 > 96  -- 1 - 2 minutes every 3 - 6 minutes
 local st = t/5
 lin_sqrt_spawn = .8 + min(sqrt(st), st/10)
 if rnd(100) < lin_sqrt_spawn and spawn_cooldown==0 then
 	local spawn_door = flr(rnd(3)) -- random door
 	if(spawn_door == 1)open_door()
 	local times = (spawn_fast and rnd(100) < 5) and 1 or max(rnd(sqrt(sqrt(st))),1)
 	for i=1, times do
 		spawn_enemy(spawn_door) 
 	end
 	spawn_cooldown = max_spawn_cooldown
 	max_spawn_cooldown -= 1
 end

 for e in all(enemies) do 
 	e.update(e)
 end

 -- bullets
 for b in all(bullets) do 
 	b.update(b)
 end

 hurting = max(0, hurting-1)
 update_camera()
 update_shake()
end

function game_draw()
 camera(camx+shkx, camy+shky)
 if hurting > 11 then
 	clear_color = 14
 	if (hurting==15) clear_color = 7
 	if (hurting==14) clear_color = 8
 	if (hurting==13) clear_color = 0
  return cls(clear_color)
 end

 cls(7)
 --draw map
 local sx = wallx
 local sy = wally
 local sxr = 64+sx-16
 local syr = 64+sx-16
 for y=127-sy,140 do -- floor
  rectfill(sx-(y-(127-sy))*.9+15,y-1,
            127-(sx-(y-(127-sy))*.9+15),y-1,0)
 end
 local corx1 = 24
 local corx2 = 38
 rectfill(corx1,100,corx2,96,0) -- left corridoor
 rectfill(127-corx1,100,127-corx2,96,0) -- right corridoor
 pal(3,0)
 for z=0, 1.5, 1/(posts*3) do 
  local px = (sx-64)/z + 64
  local py = (sy-64)/z + 64
  local pxr = (sxr-64)/z + 64
  local pyr = (syr-64)/z + 64
  local pxw = (sx+16)/z - sx/z
  local pyw = (sy+16)/z - sy/z
  local pxwr = (sxr+16)/z - sxr/z
  local pywr = (syr+16)/z - syr/z

  if z%(1/posts) == 0 then
   sspr(24,0, --left
         16,16,
         px,py,
         pxw,pyw)

   sspr(24,0, --right
         16,16,
         pxr,py,
         pxwr,pyw,
         true)

   sspr(24,16, --left
         16,16,
         px,pyr,
         pxw,pywr)

   sspr(24,16, --right
         16,16,
         pxr,pyr,
         pxwr,pywr,
         true)
  else
   if px < corx1 or px > 28 then
    sspr(43,0, --left
          3,16,
          px,-8/z + 64,
          (px+3)/z - px/z,8/z - -8/z)
    sspr(43,0, --left
          3,16,
          (127-px)-1,-8/z + 64,
          ((127-px)+3)/z - (127-px)/z,8/z - -8/z,
          true)
    if z%(1/posts)>.5/posts then
     sspr(43,0, --left
       3,16,
       px,10/z + 64,
       (px+2.5)/z - px/z,18/z - 10/z)
     local fr = z%(2/posts)>1/posts and 3 or 0
     sspr(40+fr,0, --left
       3,16,
       (127-px)+1,10/z + 64,
       ((127-px)-2)/z - (127-px)/z,18/z - 10/z)
    end 
   end
  end
 end
 pal(3,3)


 doorw = 17
 doorh = 31
 if door_opened != 0 then
  rectfill(64-doorw/2, syr+4-doorh,
            64+doorw/2, syr+4, 0)
 end


 -- sort by z
 for i=1, #enemies do
 	local j=i
 	while j > 1 and enemies[j-1].z < enemies[j].z do
 		enemies[j],enemies[j-1] = enemies[j-1],enemies[j]
 		j=j-1
 	end
 end

 -- enemies in behind door
 for e in all(enemies) do 
 	if(e.behind_door)e.draw(e)
 end


 if door_t != 1 then
  rectfill(64-doorw/2, syr+4-doorh+doorh*(1-door_opened),
            64+doorw/2, syr+4-doorh, 7)
 end
 -- door edges
 rectfill(64-doorw/2, syr+4, -- left
           64-doorw/2, syr+4-doorh,5)
 rectfill(64+doorw/2, syr+4, -- right
           64+doorw/2, syr+4-doorh,5)
 -- rectfill(64-doorw/2, syr+4, -- bottom
 --           64+doorw/2, syr+4,5)
 rectfill(64-doorw/2, syr+4-doorh, -- top
           64+doorw/2, syr+4-doorh,5)

 -- enemies
 for e in all(enemies) do 
 	if(not e.behind_door)e.draw(e)
 end

 -- bullets
 for b in all(bullets) do 
 	b.draw(b)
 end

 sbr.draw(sbr)
 if across then
  --print('-',0,0)
 else
  --print('|',0,0)
 end

 --[[print(#enemies, 64,64,3)
 print(t, 64,69)
 print(lin_sqrt_spawn, t%128+2,64-lin_sqrt_spawn+2,8)--]]
 --pset(t%128,64-lin_sqrt_spawn,8)
 cpu_usage = stat(1)
 --sbr2.draw(sbr2)
 -- print('x: '..mx..' y: '..my..' b: '..mb,0,0,7)
 -- print('a: '..sbr.a..' da: '..sbr.da,0,8,7)

 -- score
 -- print(points,3,2,8)
end

-- door
function update_door()
	door_t = min(door_t + .015, 1)
	door_opened = -min(sin(door_t), 0)
end

function open_door()
	door_t = 0
end

function hurt()
	if hurting == 0 then 
		hurting = 15
		life -= 1
		if life == 0 then 
			game_over()
		end
	end
end

-- enemies
function spawn_enemy(door)
	local w=19
	local h=34
	local x=64
	local dx = 0
	local dz = 0
	local behind_door = false
	if door == 0 then 
		x=24 -- - w/2
		z=.96
		dx = .3 + rnd(1.3)
	elseif door == 1 then
		x=62+rnd(4)
		z=1.58
		dz = -.015 - rnd(.0035)
		behind_door = true
	elseif door == 2 then 
		x=127-24 -- + w/2)
		z=.96
		dx = -(.3 + rnd(1.3))
	end

	local e = {
		t=0,
		w=w, h=h,
		x=x, z=z,
		dx=dx, dz=dz,
		shead=.5,
		storso=.6,
		slegs=.6,
		fire_cooldown=80 + rnd(40) - rnd(t/2),
		fcd=80 + rnd(40) - rnd(t/2) + 20,
		stopt=15+flr(rnd(10)),
		behind_door=behind_door,
		hurting=0,
		update=function(e)
			e.t+=1
			e.x += e.dx
			e.z += e.dz
			if e.hurting==1 then
				e.dz += .005
			end
			if e.hurting>0 then
				e.hurting += 1
				if e.hurting > 5 then
					del(enemies, e)
      points += 1
				end
			end
			if e.t==e.stopt then 
				if e.dz == 0 then
					e.dz = rnd(.08) - .05
				else 
					e.dx = rnd(4)-2
					e.dz -= rnd(.008)
				end
			end
			if(e.behind_door and door_opened > .9)e.behind_door=false
			if e.t>e.stopt then 
				e.dx *= .9
				e.dz *= .9
				if(abs(e.dx)<.005)e.dx=0
				if(abs(e.dz)<.001)e.dz=0
				e.z = min(1.4,e.z)
			end
			e.fcd-=1
			if e.fcd <= 0 then 
				e.fcd = e.fire_cooldown
				e.shoot(e)
    sfx(0)
			end
		end,
		draw=function(e)
			local hw = 19 * e.shead
			local hh = 20 * e.shead
			local sy = ((127-wally-e.h)-64)/e.z + 64
			local sx = (e.x-64-hw/2)/e.z + 64
--[[			circfill(sx,sy,(e.x+hw/2-64)/e.z + 64 - sx,e.behind_door and 1 or 5)
			circ(sx,sy,(e.x+hw/2-64)/e.z + 64 - sx,e.behind_door and 2 or 8)--]]
			if(e.behind_door)pal(7,6)
			if e.hurting > 0 then
				if e.hurting%2==0 then
					all_to_color(7)
				else 
					all_to_color(0)
				end
			end
			pal(3,0)

			local tw = 31 * e.storso
			local th = 29 * e.storso
			local tsy = ((127-wally-e.h + hh*.855)-64)/e.z + 64
			local tsx = (e.x-64-tw/2)/e.z + 64

			-- legs
			local lw = 9 * e.slegs
			local lh = 39 * e.slegs
			local lsy = ((127-wally-e.h + hh*.855 + th*.82)-64)/e.z + 64
			local lsx = (e.x-64 - lw -1)/e.z + 64
			sspr(98,0,
								9, 39,
								lsx, lsy,
								lw/e.z,
								((127-wally-e.h+hh*.855 + th*.8+lh)-64)/e.z + 64 - lsy)
			lsx = (e.x-64 + 2)/e.z + 64
			sspr(98,0,
								9, 39,
								lsx, lsy,
								lw/e.z,
								((127-wally-e.h+hh*.855 + th*.8+lh)-64)/e.z + 64 - lsy,
								true)
			-- torso
			sspr(66,0,
								31, 29,
								tsx, tsy,
								(e.x+tw/2-64)/e.z + 64 - tsx,
								((127-wally-e.h+hh+th)-64)/e.z + 64 - tsy)
			-- head
			sspr(46,0,
								19,20,
								sx, sy,
								(e.x+hw/2-64)/e.z + 64 - sx,
								((127-wally-e.h+hh)-64)/e.z + 64 - sy)
			-- arms
			local aw = 27
			local ah = 11
			local asy = ((127-wally-e.h + hh*.855 + th*.15)-64)/e.z + 64
			local asx = (e.x-64-(tw*.9)/2)/e.z + 64
			sspr(24,32,
								27,11,
								asx, asy,
								(tw*.9)/e.z,
								(ah*.9)/e.z)

			--[[pal(3,3)
			pal(7,7)--]]
			all_to_color()

		end,
		shoot=function(e)
			local b = {
					t=0,
					source=e,
					x=e.x - 27*.05,
					y=(127-wally-e.h+ 20*e.shead*.855 + 11*.9 * .6),
					z=e.z-.0005,
					r=1.4,spd=1,
					deflected=false,
					hit_enemy=false,
					update=function(b)
						b.t += 1
						b.x += b.dx
						b.y += b.dy
						b.z += b.dz
						local sx = (b.x-64)/b.z + 64
      local sy = (b.y-64)/b.z + 64
      local chw = b.r/b.z -- bullet hw
      if b.deflected then
      	if b.hit_enemy and b.z > b.hit_enemy.z then
      		b.hit_enemy.hurt(b.hit_enemy)
        sfx(9)
      		del(bullets,b)
      	end
      	if sx < -chw or sx > 127+chw or 
      				sy < -chw or sy > 127+chw then
      		del(bullets,b)
      	end
      	return -- no need to hit check
      end

      -- hit checks
      if b.z < .35 then -- hit distance
      	-- transform to saber space
      	-- translate
      	local osbx = sx-(sbr.x+sbr.sx)
      	local osby = sy-(sbr.y+sbr.sy)
      	-- unrotate
       local c = cos(-sbr.a+.25)
       local s = sin(-sbr.a+.25)
      	sby = c*osbx - osby*s
      	sbx = s*osbx + osby*c
        --printh(sbx..'|'..sby)
        --while not btnp(z) do flip() end
      	-- box-box collision
      	local sbrlen = sbr.out*sbr.lh
      	local by = -(sbr.loh - sbr.lw/4) -- hilt obscures blade slightly
      	local ty = -(sbr.loh + sbrlen + sbr.lw/3) -- rounded, so smaller hitbox
      	local lx = -sbr.lw/2
      	local rx = sbr.lw/2

      	if sby+chw < by and sby-chw > ty and -- collide!
      				sbx+chw > lx and sbx-chw < rx then
        local shamt = max(1,distance(mx,my,sbr.x,sbr.y))
        add_shake(shamt)
        sfx(1)
      		b.deflected = true
      		b.t = 0
      		if rnd(100) < 80 then -- most of the time hit enemy
      			b.hit_enemy = b.source
      			if rnd(100)<50 then -- sometimes hit his buddy
      				local which = 0 -- most of these times, hit the closest
      				if rnd(100)<20 and #enemies > 1 then
      					which = 1
      				end
      				b.hit_enemy = enemies[#enemies - which]
      			end
      			-- go toward enemy
      			local destx = b.hit_enemy.x + rnd(19*b.hit_enemy.shead/4) - 19*b.hit_enemy.shead/8 + b.hit_enemy.dx*2
      			local desty = 127-wally-b.hit_enemy.h*.5 + rnd(b.hit_enemy.h*.4)
      			local destz = b.hit_enemy.z + b.hit_enemy.dz*2
      			destz = (destz-.25)*64
      			local dist = distance3de(b.x,b.y,(b.z-.25)*64,destx,desty,destz)
									b.dx = (destx - b.x)/dist * b.spd*4
									b.dy = (desty - b.y)/dist * b.spd*4
									b.dz = ((destz - b.z)/dist * b.spd*4)/64
         --printh(b.dz)
      		else
      			-- deflect outward (cause not hitting enemy)
      			local a = rnd(1)
      			b.dx = sin(a) * b.spd*1.9
      			b.dy = cos(a) * b.spd*1.9
      			b.dz = sgn(rnd(1)-.5)*b.dz*rnd(.6)
      		end
      	end
						end
      if b.z < .15 then -- missed
       if sx > 0 and sx < 127 and 
          sy > 0 and sy < 127 then
       add_shake(5)
       camx += rnd(10)-5
       camy += rnd(10)-5
						 hurt()
       sfx(8)
       end
							del(bullets, b)
						end
					end,
					draw=function(b)
      local px = (b.x-64)/b.z + 64
      local py = (b.y-64)/b.z + 64
						local oz = b.z-b.dz
      local ox = ((b.x-b.dx)-64)/oz + 64
      local oy = ((b.y-b.dy)-64)/oz + 64
      -- muzzle flash
      if b.t == 1 or b.t == 3 then 
      	circfill(px, py, b.r/b.z*1.8, 7+b.t-1)
      	rectfill(px-(b.r*2)/b.z, py+b.r/4,
      										px+(b.r*2)/b.z, py-b.r/4, 7)
      end
      if (b.t == 1) circfill(ox, oy, b.r/b.z*1.6, 8)
      if (b.t == 2) circfill(ox, oy, b.r/b.z*1.7, 5)
						circfill(ox, oy, b.r/oz, 8)
						circfill(px, py, b.r/b.z, 8)
       ----print(b.z, ox, oy, 3)
					end
				}
				-- speed/dir
				-- destination (somewhere on player's screen) at depth ~~.25~~ .15
				local x = 30 + rnd(68)
				local y = 30 + rnd(68)
				-- don't forget to normalize z
				-- .25 is the stopping point
				local z = (.25-.25)*64
				local dist = distance3de(b.x,b.y,(b.z-.25)*64,x,y,z)
				-- normalize and speed
				b.dx = (x - b.x)/dist * b.spd
				b.dy = (y - b.y)/dist * b.spd
				b.dz = ((z - b.z)/dist * b.spd)



				add(bullets, b)
		end,
		hurt=function(e)
			e.hurting += 1
		end
	}add(enemies, e)
	return e
end

-- x, y, button
function mouse()
 return stat(32) - 1, stat(33) - 1, stat(34)
end

function init_saber(c)
 local s = {
  x=64,y=64,
  -- should add dx/dy for non-mouse mvmt
  sx=0,sy=0, -- idle offsets
  it=0,t=0,  -- idle time and timer
  a=0,da=0,  -- angle, dangle
  w=1*8 + 4,
  h=5*8 + 5,
  lh=90,lw=7,-- laser w/h
  loh=20,     -- laser offset h
  c=c or 12,
  on=false,
  out=0,
  sparks={},
  pa=0,
  px=0,
  py=0,
  dx=0, -- added for iphone control
  dy=0
 }

 s.update=function(s)
  s.t+=.015
  s.a %= 1
  -- up
  if s.a < .25 and s.a > .75 then
   
  else 

  end

  s.pa = s.a+s.da*.9
  s.a += s.da 
  s.da *= .8

  if s.a > .1 and s.a < .9 and s.it>=-.5 then
   if s.a > .5 then
    s.a = lerp(s.a, .9, .01*(s.it+.5))
   else 
    s.a = lerp(s.a, .1, .01*(s.it+.5))
   end
  end

  if s.on then
   s.out = lerp(s.out, 1, .5)
  else
   s.out = lerp(s.out, 0, .5)
  end
  if abs(sbr.x-mx) < .1 and abs(sbr.y-my) < .1 then
   s.it = min(s.it+.005, 1)
  else
   s.it = lerp(s.it, -1, .4)
  end
  if s.it >= 0 then
   s.sx = cos(s.t/5)*s.it*2
   s.sy = sin(s.t/2)*s.it*3
  else 
   s.sx = 0
   s.sy = 0
  end

  if s.on and rnd(100)<80 and #s.sparks < 35 
  			and cpu_usage < .85 then -- don't add more sparks if maxed cpu
   add(s.sparks, s.spark(s))
  end
  for p in all(s.sparks) do 
   p.update(p)
  end
 end

 s.draw=function(s)

   -- draw behind sparks
  local after = s.draw_back_sparks(s)


  -- draw saber
  local x = s.x+s.sx 
  local y = s.y+s.sy
  local len = s.out*s.lh
  if s.out > .02 then
   for hr=s.loh,s.loh+len do
    circfill(cos(s.a+.25)*hr+x-rnd(), 
             sin(s.a+.25)*hr+y, s.lw/2, s.c)
    circfill(cos(s.pa+.25)*hr+s.px-rnd(), 
             sin(s.pa+.25)*hr+s.py, s.lw/2.1, s.c)
   end  
   for hr=s.loh,s.loh+len do
    circfill(cos(s.a+.25)*hr+x-rnd(), 
              sin(s.a+.25)*hr+y, s.lw/3, 7)
   end
  end
  draw_rotated(
   8,0,
   s.on and s.w-3 or s.w
   ,s.h,
   s.on and x-1.5 or x
   ,y,
   s.a,1)

  -- draw in front sparks
  for i, p in pairs(s.sparks) do 
   if p.ax <= .25 or p.ax > .75 then 
    p.draw(p)
   end
  end
  for i, l in pairs(after) do 
   line(l[1],l[2],l[3],l[4],l[5])
  end

  s.px = x
  s.py = y
  --print(stat(1),0,12)
 end

 s.draw_back_sparks=function(s)
  local lines = {}
  local after = {}
  for pi, p in pairs(s.sparks) do 
   if not p.calcd then
    if p.ax > .25 and p.ax <= .75 then 
     p.draw(p)
    else
     p.point(p)
    end
   end
   for oi, o in pairs(s.sparks) do 
    if not o.calcd then
     if o.ax > .25 and o.ax <= .75 then 
      o.draw(o)
     else
      o.point(o)
     end
    end
    if p != o and not lines[pi..'|'..oi] then
     if p.vy+tns > o.vy and p.vy-tns < o.vy and
        p.vx+tns > o.vx and p.vx-tns < o.vx and
        p.z+tns > o.z and p.z-tns < o.z then
      local ds = distance3de(p.vx, p.vy, p.z/2,
                                o.vx, o.vy, o.z/2)
      --ds /= tns*1000
      -- have d.ax factor into calc
      -- for more spinny effect
      local ad = min(abs(p.ax-o.ax), 
                     abs((min(p.ax,o.ax)+1)-max(p.ax,o.ax)))
      if across then
       ds -= (ad-.25)*(tns/4)
      else
       ds -= (.25-ad)*(tns/4)
      end
      if ds < tns then
--[[       color(8)
       print(ds)
       flip()--]]
       local fds = -(ds - tns)
       p.r += fds*s.lw/14
       o.r += fds*s.lw/14
       --p.ax += rnd(.006)-.003
       --o.ax += rnd(.006)-.003
       --opdir = sgn(p.y - o.y)
       --p.dy += rnd()*opdir/2
       --o.dy += -rnd()*opdir/2

       -- average z / r ratio (-1 to 1/furthest to closest)
       local avgr = (p.r+o.r)/2
       local depth = ((p.z+o.z)/2)/(avgr)
       local clist = cols['c'..sbr.c]
       local ci = #clist / 4
       ci = flr(ci + ((ds)/tns)*(#clist/2) - (depth * ci) + 1 - 
             (avgr - sbr.lw)/sbr.lw
            )
       --local tc = flr(((ds/2)/tns)*(#cols['c'..sbr.c]-3)+1+((p.z+o.z)-1)) or 0
       local c = cols['c'..sbr.c][ci]
--[[       color(c==0 and 12 or c)
       print(ci)
       flip()--]]
       lines[pi..'|'..oi] = true
       if (p.ax <= .25 or p.ax > .75) and 
          (o.ax <= .25 or o.ax > .75) then
        add(after, {p.vx,p.vy,o.vx,o.vy,c})
       else
        line(p.vx,p.vy,o.vx,o.vy,c)
       end
      end
     end
    end
   end
  end
  return after
 end -- end draw_back_sparks

 s.toggle = function(s)
  s.on = not s.on
  if(s.on)sfx(6)
 end

 s.spark=function(s)
  local p = {
   sbr=s,
   ba=s.a,
   by=s.y,
   bx=s.x,
   ax=rnd(),
   dax=rnd(.01),
   y=rnd(s.h),
   dy=-rnd(2)-1,
   t=0,
   deadt=rnd(90)+15,
   mr=rnd(s.lw/4)+s.lw/4, -- try /3
   r=s.lw,                  -- try /2

   vx=0,
   vy=0,
   calcd=false
  }
  p.update=function(d)
   d.calcd=false
   -- any movement makes sparks die sooner
   -- so sparks die as the are further away
   local adiff = min(abs(d.ba-d.sbr.a),
                     abs((min(d.ba,d.sbr.a)+1)-max(d.ba,d.sbr.a)))
   d.t += 1 + abs(adiff*d.y) 
            + abs(sbr.y-d.by)/10 
            + abs(sbr.x-d.bx)/10
            + (1-d.sbr.out)*4
   if d.t > d.deadt then 
    del(d.sbr.sparks, d)
   end
   d.y += d.dy
   if d.y > d.sbr.lh+20 then
    del(d.sbr.sparks, d)
   end
   d.ax += d.dax
   d.ax %= 1

   local pdead = d.t/d.deadt
   local plife = 1-pdead
   d.dy += rnd(plife/2) - plife/3
   d.dy += rnd(.1) - .07
   d.dax += rnd(plife*.01) - plife/200
   d.dax += rnd(.001) - .0005

   d.dy = lerp(d.dy, 0, .125)


   d.r = lerp(d.r, d.mr+d.mr*pdead*2, .35)

   d.ci = flr(((d.ax+.5)%1)*(#cs['c'..d.sbr.c])+1)
   d.z = cos(d.ax)*d.r
   d.c = cs['c'..d.sbr.c][d.ci]

  end
  p.draw=function(d)
   if (not d.calcd) p.point(p)
   local w = (#cs['c'..d.sbr.c]/2-(-d.z/(d.r) + 1)*3)*(d.r/d.sbr.lw)
   circfill(d.vx,d.vy, w/8,d.c)
   --pset(x2,y2,d.c)
  end
  p.point= function(d)
   local b = d.sbr
   local x = sin(d.ax)*d.r/2
   local cy = d.y - b.lh/2 - b.loh
   local x2 = x*cos(d.ba) - cy*sin(d.ba)
   local y2 = cy*cos(d.ba) + x*sin(d.ba)
   x2 = flr(x2+d.bx)
   y2 = flr(y2+d.by)
   d.vx, d.vy = x2, y2
   d.calcd = true
   return x2,y2
  end
  p.point(p)
  return p
 end

 return s
end

function game_over()
 _update = over_update
 _draw   = over_draw
 over_points = points
 t = 0
end

function over_update()
 mx, my, mb = mouse()
 gpio = {}
 for i=0x5f80, 0x5fa0 do 
  add(gpio, peek(i))
 end
 t += .015

 -- gpio 1
 if t > .015*40 and (mb == 1 or btnp(4) or gpio[2] == 1) then
  _init()
 end
 if t < 1 then
  game_update()
 end
 sbr.update(sbr)
 points = over_points -- in case we kill after game over somehow
end

function over_draw()
 game_draw()
 s = 'game over'
 print(s, 64 - #s*2,62 - sin(t)*2+1, 0)
 print(s, 64 - #s*2,62 - sin(t)*2, 8)
 if has_gpio then
  s = 'press 1 to restart'
 else
  s = 'click mouse to restart'
 end
 print(s, 64 - #s*2,91, 1)
 print(s, 64 - #s*2,90, 12)

 s = 'score:'..points
 rectfill(64-#s*2-3, 75,
           64+#s*2+2, 83,0)
 print('score:'..points,64-#s*2,77,7)

end



-- from trasevoldog
function all_to_color(c)
 for i=0,15 do
  if c then
   pal(i,c)
  else
   pal(i)
  end
 end
end

--[[
sprite rotation without holes: 
creamdog
https://www.lexaloffle.com/bbs/?tid=3936
 // quick and dirty way of rotating a sprite
 sx = spritecheet x-coord
 sy = spritecheet y-coord
 sw = pixel width of source sprite
 sh = pixel height of source sprite
 px = x-coord of where to draw rotated sprite on screen
 py = x-coord of where to draw rotated sprite on screen
 r = amount to rotate (radians)
 s = 1.0 for normal scale, 0.5 for half, etc
]]
function draw_rotated(sx,sy,sw,sh,px,py,r,s)
 -- loop through all the pixels
 for y=sy,sy+sh,1 do
  for x=sx,sx+sw,1 do
   -- get source pixel color
   col = sget(x,y)
   -- skip transparent pixel (zero in this case)
   if (col != 0) then
    -- rotate pixel around center
    local xx = (x-sx)-sw/2
    local yy = (y-sy)-sh/2
    local x2 = (xx*cos(r) - yy*sin(r))*s
    local y2 = (yy*cos(r) + xx*sin(r))*s
    -- translate rotated pixel to where we want to draw it on screen
    local x3 = flr(x2+px)
    local y3 = flr(y2+py)
    -- use rectfill if scale is > 1, otherwise just pixel it
    if (s >= 1) then
     local w = flr(x2+px+s)
     local h = flr(y2+py+s)
     rectfill(x3,y3,w,h,col)
    else
     pset(x3,y3,col)
    end
   end
  end
 end
end

function distance3d(x1,y1,z1,x2,y2,z2)
 local dx = abs(x2-x1)
 local dy = abs(y2-y1)
 local dz = abs(z2-z1)
 if dx > dy then
  d = max(dx, dz)
  n = min(dy, dz)/d
  m = max(dy, dz)/d
 else
  d = max(dy, dz)
  n = min(dx, dz)/d
  m = max(dx, dz)/d
 end
 return sqrt(n*n+m*m+1) * d
end

function distance3de(x1,y1,z1,x2,y2,z2)
  local dx = abs(x2-x1)
  local dy = abs(y2-y1)
  local dz = abs(z2-z1)
  local dxy = dx+dy-0.585786*min(dx,dy)
  return dxy+dz-0.585786*min(dxy,dz)
end

function distancee(x1,y1,x2,y2)
  local dx = abs(x2-x1)
  local dy = abs(y2-y1)
  return dx+dy-0.585786*min(dx,dy)
end

function distance(x1,y1,x2,y2)
 local dx = abs(x2-x1)
 local dy = abs(y2-y1)
 local d = max(dx,dy)
 local n = min(dx,dy)/d
 return sqrt(n*n+1) * d
end

function lerp(from,to,t)
 return from+t*(to-from)
end

-- from trasevol_dog
camx=0 camy=0
shkx=0 shky=0
camrx=0 camry=0
function update_camera()
 local ocamx,ocamy=camx,camy
 
 camx=lerp(0,camx,0.1)
 camy=lerp(0,camy,0.1)
 
 camrx=camx-ocamx
 camry=camy-ocamy

 update_shake()
end


function add_shake(p)
 local a=rnd(1)
 shkx+=p*cos(a)
 shky+=p*sin(a)
end

function update_shake()
 if abs(shkx)<0.5 and abs(shky)<0.5 then
  shkx=0
  shky=0
 else
  shkx*=-0.6-rnd(0.2)
  shky*=-0.6-rnd(0.2)
 end
end

__gfx__
00000000060000000000000077775555555555506606600000077777777770000000077773555555555555555557777000000033333333000000000000000000
00000000066000000000000077555555555555606676670000777777777777000000777773355555555555555357777600000033333333000000000000000000
00700700066600000000000075555555555566006676670007767777777777700000777763776555555555567757777600000663333333000000000000000000
00077000067677000000000075566000000000006676670007666677777777700007777763777666666666677757777760000667533333000000000000000000
00077000977677560000000055660000000000006676670076667733337777770007777663777777777777777757777760006677753333000000000000000000
00700700f77677566000000055700000000000006676670073333333333333370006676663777777777777777757777760006677753333000000000000000000
00000000076677566000000055700000000000006676670037777777777777730066666633677777777777777753777776006677773333000000000000000000
00000000076677566000000056000000000000006676670077333337736333770066666637677777766777777773777776006677775330000000000000000000
00000000766775666600000056000000000000006676630077333377773333770066666636667777776677777775777776006677775500000000000000000000
00000000766775666600000056000000000000006676630077733767777337770077600006666666676666666770000776006677777500000000000000000000
00000000767555566000000060000000000000006676670075677667777776570000000006666666777666667770000000006777777000000000000000000000
00000000765571666000000060000000000000006676670775366667777673577000000006667777777777777670000000066777777000000000000000000000
00000000056778666000000060000000000000006676677777577663377775777700000006677777777777777670000000066777776000000000000000000000
000000000d6771666000000060000000000000006666667757777737737777757700000006677777777777777770000000066777770000000000000000000000
00000000016773666000000060000000000000006606606775777377773777577700000006777777777777777770000000066777760000000000000000000000
00000000006771666000000060000000000000000000006677577667777775777600000006677777777777777770000000066777700000000000000000000000
00000000006771666000000060000000000000000000000677766765577667776000000006667775555557777770000000066777700000000000000000000000
00000000006771666000000060000000000000000000000067777733337777770000000006665555666655557770000000767777600000000000000000000000
00000000006771666000000060000000000000000000000006767753357767700000000000555666757566655500000000765577000000000000000000000000
000000000155d1155500000060000000000000000000000000673773367376000000000000666677777777766600000000035765600000000000000000000000
00000000055571515165000060000000000000000000000000066700007660000000000000066777757577577000000000003357600000000000000000000000
00000000055571155161000066000000000000000000000000000000000000000000000007656575765657657760000000055533000000000000000000000000
00000000055571515165000066000000000000000000000000000000000000000000000007656575765657657750000000065555000000000000000000000000
000000000555d1155161000066000000000000000000000000000000000000000000000000555555555555555500000000065667000000000000000000000000
000000000155d1515500000066600000000000000000000000000000000000000000000000006666666666660000000000665677000000000000000000000000
00000000006775166000000056600000000000000000000000000000000000000000000000000066666777000000000000666777000000000000000000000000
00000000006775666000000056600000000000000000000000000000000000000000000000000007777770000000000000666777000000000000000000000000
00000000006775666000000056670000000000000000000000000000000000000000000000000000777700000000000000666677000000000000000000000000
00000000006776666000000075767000000000000000000000000000000000000000000000000000677700000000000000066677000000000000000000000000
00000000006776666000000075577770000000000000000000000000000000000000000000000000667700000000000000066677000000000000000000000000
00000000056575565100000077557666660000000000000000000000000000000000000000000000000000000000000000066670000000000000000000000000
00000000056575565100000077775556666660000000000000000000000000000000000000000000000000000000000000066670000000000000000000000000
00000000056575565100000000000000003300000000000000000000000000000000000000000000000000000000000000076670000000000000000000000000
00000000056575565100000000000000003300000000000000000000000000000000000000000000000000000000000000076667000000000000000000000000
00000000056575565100000000000000000500000000000000000000000000000000000000000000000000000000000000066677000000000000000000000000
00000000056575565100000000776600053330000000005555500000000000000000000000000000000000000000000000076777000000000000000000000000
00000000056565565100000000777766533333330000006655600000000000000000000000000000000000000000000000777775000000000000000000000000
00000000056565565100000003377777533535000000006666700000000000000000000000000000000000000000000000777770000000000000000000000000
00000000056565565100000007777777753333377777006667700000000000000000000000000000000000000000000000777770000000000000000000000000
00000000056565565100000077777766755533666677777773700000000000000000000000000000000000000000000000555500000000000000000000000000
00000000056565565100000077776656676666366666677773300000000000000000000000000000000000000000000000000000000000000000000000000000
00000000056565565100000077665660000666066677777663300000000000000000000000000000000000000000000000000000000000000000000000000000
00000000056575565100000007566000000000000666777666300000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000665550000000000000000000000000000666666660000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000666550000000000000000000000000000000666600000000000000000000000000000000000000000000000000000000000000000000000000000
__label__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000ccc0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000777cc000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000077777cc00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000777777c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000007777777c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000c7777777c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000c7777777c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000c77777777c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000c77777777c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000c77777777c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000c77777777c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000c77777777c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000c7777777c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000077777777c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000077777777c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000c7777777c000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000c7777777c000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000c7777777c00000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000c7777777c0000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000c77777770000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000cc7777777c00000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000cc7777777c0000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000cc7777777c000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000c7777777c000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000c7777777c00000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000c7777777c0000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000c7777777c000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000c7777777c00000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000077777777c0000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000c777777770000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000c7777777c000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000c7777777c00000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000c77777777c0000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000c7777777cc000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000cc777777cc00000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000c7777777c00000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000c7777777c0000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000c7777777c000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000c7777777c00000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000c7777777c0000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000c7777777c000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000007777777cc00000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000c7777777cc0000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000c7777777c0000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000c7777777c000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000c7777777c00000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000c7777777c0000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000c7777777c000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000c777777cc00000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000c7777777c00000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000c7777777c0000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000c7777777c000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000c777777cc00000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000cc777777cc0000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000c7777777cc000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000c7777777c000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000c7777777700000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000c777777770000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000c7777777c000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000c7777777c00000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000c7777777c0000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000cc77777770000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000c7777777c000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000c7777777c00000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000c7777777c0000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000cc7777777c000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000cc7777777c00000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000c77777777c0000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000c77777777c000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000c77777777c00000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000c7777777c00000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000c777756660000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000066667755666600000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000066766775666666000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000006776777566666000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000777677566666000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000f76677565666600000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000ff7677751666660000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000007667571666660000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000007767577166666000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000766677736666600000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000776667771666655000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000077d16771166551100000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000d16677161151110000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000677d11155111000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000065d71155555000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000015557115166000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000015557d15166600000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005555d15666660000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005555777666661100000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000015777566661110000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000011677766565511000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000667775566511100000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000066777556551110000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005657755665110000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005565755565511000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000566575556511100000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000556556555651110000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000055666655565111000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005565565566511000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000566566555550000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000055656555555000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000055665765555000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000565666550000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000556666600000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000055066000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

__sfx__
000100001a6103d620396303543036730324302813426120284202972025220212201f7101a420197101422013210117100d010121001d6001e70020600257002c6002e70033600397003f600000000000000000
000200000a450030501b4500d0601103027430100501a4300c4300805008430064200342002410016100540002000020000200003000030000300002000010000110001100011000110001100011000110001100
010300060111404111021110511305115081150000000000000000000000000000000000000000000001d00000000000000000000000000000000000000000000000000000000000000000000000000000000000
0117000000154001210011500105011002c5002b5002130024500205001d60018500145000f6000e5000d5000a5000a6000750005500025000150004300043000120001200030000000000000000000000000000
010900000316403171021510212502112021120000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010800000216403171031510312500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010100000111401121011210312103121031310413104131041310413104131041310412104125041250412504125041150411504115041150411504115041150411504115041150411504115041150411504115
01040000001141a112001110001100021000210012200122001220003100031000320002200022000220002100131001340013200122001120011200012000220002200022000250001500015000050000500005
00030000333503425031250036100363008050060500405000000000001d200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00020000131501215009150081500e150051500515009230052300623000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
