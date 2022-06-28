-- Execute.lua: attempt to run AI for the partner.
function will_collide(me, enemy, extents, startup, active, velocities, posadds, enemy_standing)
	if enemy ~= nil then
		local my_extents = {left = extents.left, right = extents.right, bottom = extents.bottom, top = extents.top}
		local gravity = mll.ReadFloat(enemy:getplayeraddress() + 0x12C) * enemy:unitsize()
		local position = enemy:pos()
		local velocity = enemy:vel()
		velocity.x = velocity.x * enemy:facing()
		
		local position_shifted = {x = position.x + (velocity.x * startup), y = position.y + (velocity.y * startup)}
		-- simulated acceleration, stretching grade 9 physics rememberence
		if enemy:statetype() == 'A' then 
			position_shifted.y = position.y + velocity.y * startup + 0.5 * gravity * startup * startup
			if position_shifted.y > 0 then position_shifted.y = 0 end
		end
		-- now loop for the duration of active frames
		for i=0,active do
			-- compute re-shifted position on this frame
			local position_reshifted = {x = position_shifted.x + (velocity.x * i), y = position_shifted.y + (velocity.y * i)}
			if enemy:statetype() == 'A' then
				position_reshifted.y = position_shifted.y + velocity.y * startup + 0.5 * gravity * startup * startup
				if position_reshifted.y > 0 then position_reshifted.y = 0 end
			end
			-- check if our box extents overlaps the enemy's position
			local enemy_extents = {left = position_reshifted.x - math.max(10, mll.ReadInteger(enemy:getplayeraddress() + 0x84) * enemy:unitsize()), right = position_reshifted.x + math.max(10, mll.ReadInteger(enemy:getplayeraddress() + 0x88) * enemy:unitsize()), bottom = position_reshifted.y, top = position_reshifted.y + enemy_standing.top}
			
			-- account for our boxes moving due to attack velocities
			-- each velocity is treated as being applied once, then reduced to 0 gradually by friction
			-- also account for friction if standing
			local friction = mll.ReadFloat(me:getplayeraddress() + 0x130) * me:unitsize()
			for _,velo in pairs(velocities) do
				local v = me:facing() * velo.x
				
				for j=0,(startup+i) do
					my_extents.left = my_extents.left + v
					my_extents.right = my_extents.right + v
					if me:statetype() == 'S' then v = v * friction end
				end
			end
			
			-- account for our boxes moving due to attack posadds
			for _,adds in pairs(posadds) do
				local v = me:facing() * adds.x * 0.5
				my_extents.left = my_extents.left + v
				my_extents.right = my_extents.right + v
			end
			
			-- fixup extents into screen coordinates
			enemy_extents.left = enemy_extents.left + mugen.screenwidth() / 2
			enemy_extents.right = enemy_extents.right + mugen.screenwidth() / 2
			
			if my_extents.left < enemy_extents.right and my_extents.right > enemy_extents.left and my_extents.bottom > enemy_extents.top and my_extents.top < enemy_extents.bottom then
				return true
			end
		end
	end
	return false
end

-- helper for statetype comparison
function st_to_c(i)
	if i == 1 then return 'S'
	elseif i == 2 then return 'C'
	elseif i == 3 then return 'A'
	elseif i == 4 then return 'L'
	else return '?' end
end

function userscript()
	local current = player.current()
	local partner = current:partner()
	current:lifemaxset(partner:lifemax())
	
	local enemy1 = partner:enemy(0)
	local enemy2 = partner:enemy(1)
	
	-- absolute distance from enemy
	local distance = mugen.screenwidth() * 1000
	if enemy1 ~= nil then distance = math.min(distance, math.sqrt(((enemy1:pos().x - partner:pos().x) * (enemy1:pos().x - partner:pos().x)) + ((enemy1:pos().y - partner:pos().y) * (enemy1:pos().y - partner:pos().y)))) end
	if enemy2 ~= nil then distance = math.min(distance, math.sqrt(((enemy2:pos().x - partner:pos().x) * (enemy2:pos().x - partner:pos().x)) + ((enemy2:pos().y - partner:pos().y) * (enemy2:pos().y - partner:pos().y)))) end
	
	if _G['AI_ASSIST_ANALYSIS_RESULT_' .. partner:name()] == nil then return end
	
	local ai_data = _G['AI_ASSIST_ANALYSIS_RESULT_' .. partner:name()]
	
	-- disable default AI, don't need inputs interrupting!
	partner:aienableset(false)
	-- grant 999999 juggle points
	partner:juggleset(999999)
	
	-- only apply during RoundState = 2 and when alive
	if mugen.roundstate() ~= 2 or not partner:alive() then return end
	
	-- recovery from air, close to ground
	if partner:stateno() == 5050 and partner:vel().y > 0 and partner:pos().y >= mll.ReadFloat(partner:getplayeraddress() + 0x188) then
		mugen.log("AI Assist selected state 5200 by recovery method.\n")
		partner:selfstate({value = 5200})
		return
	end
	
	-- recovery from air, in the air
	if partner:stateno() == 5050 and partner:vel().y > mll.ReadFloat(partner:getplayeraddress() + 0x190) then
		mugen.log("AI Assist selected state 5210 by recovery method.\n")
		partner:selfstate({value = 5210})
		return
	end
	
	if partner:stateno() == 52 and partner:prevstateno() == 5210 then
		partner:selfstate({value = 120, ctrl = true})
		return
	end
	
	-- only apply if we have control, OR if movecontact is met
	if not partner:ctrl() and partner:movecontact() == 0 then 
		return 
	end
	
	-- if the enemy is in range + attacking, and we have ctrl, we may want to guard instead of attack.
	-- once enemy makes contact, we can take a chance to try to counter with a different attack.
	if partner:ctrl() and (enemy1 ~= nil and enemy1:movetype() == 'A') or (enemy2 ~= nil and enemy2:movetype() == 'A') then
		partner:selfstate({value = 120, ctrl = true})
		return
	end
	
	-- if enemy moves towards us, consider guarding as well
	if partner:ctrl() and (enemy1 ~= nil and enemy1:vel().x > 3.0) or (enemy2 ~= nil and enemy2:vel().x > 3.0) then
		partner:selfstate({value = 120, ctrl = true})
		return
	end
	
	-- filter the list of attacks to figure out which ones we can currently use
	local valid_state_selections = {}
	local curr_state_data = ai_data.state_data[partner:stateno()]
	for stateno,statedef in pairs(ai_data.state_data) do
		-- ignore attacks which we don't have enough power to use, or which cannot be linked to from the current attack.
		-- also confirm the partner's statetype for safety.
		-- this also checks against the current state data to identify link potential, so multi-state attacks may get a bit messed up here (i.e. will not be linkable).
		if statedef.hitdef ~= nil and partner:power() >= (-1 * statedef.power) and partner:statetype() == st_to_c(statedef.statetype) and (partner:ctrl() or (curr_state_data ~= nil and curr_state_data.hitdef ~= nil and curr_state_data.hitdef.type < statedef.hitdef.type)) then
			-- flag for validity
			local valid = false
			-- check if the attack can connect. if yes, add to the list and continue.
			-- it checks each anim in the list individually for connection, which is also a bit off but most skills use 1 anim anyway
			for _,animno in pairs(statedef.anims) do
				local animdata = ai_data.animation_data[animno]
				if animdata ~= nil and #(animdata.boxes) > 0 then
					for i=1,#(animdata.boxes) do
						local extents = {left = animdata.boxes[i].left, right = animdata.boxes[i].right, bottom = animdata.boxes[i].bottom, top = animdata.boxes[i].top}
						-- add position and fixup with facing to screen coords
						local facing = partner:facing()
						if facing ~= -1 then
							extents.left = extents.left + partner:pos().x + (mugen.screenwidth() / 2)
							extents.right = extents.right + partner:pos().x + (mugen.screenwidth() / 2)
						else
							local tmpleft = extents.left
							extents.left = facing * extents.right + partner:pos().x + (mugen.screenwidth() / 2)
							extents.right = facing * tmpleft + partner:pos().x + (mugen.screenwidth() / 2)
						end
						extents.bottom = extents.bottom + partner:pos().y
						extents.top = extents.top + partner:pos().y
						
						-- add impact velocities from hitdef into consideration
						local velocities = {}
						for _,velo in pairs(statedef.velocities) do
							velocities[#velocities + 1] = {x = velo.x, y = velo.y}
						end
						if curr_state_data ~= nil then
							for _,velo in pairs(curr_state_data.impact_velocities) do
								velocities[#velocities + 1] = {x = velo.x, y = velo.y}
							end
						end
						
						if will_collide(partner, enemy1, extents, animdata.startup, animdata.active, velocities, statedef.posadds, ai_data.enemy_stand.first) then 
							valid = true
							break
						elseif will_collide(partner, enemy2, extents, animdata.startup, animdata.active, velocities, statedef.posadds, ai_data.enemy_stand.second) then 
							valid = true
							break
						end
					end
				end
				-- don't need to check rest of anims if this one is valid
				if valid then break end
			end
			-- save stateno if valid
			if valid then valid_state_selections[#valid_state_selections + 1] = stateno end
		end
	end
	
	-- eliminate super/hyper unless linking or randomly activating
	local filtered_state_selections = {}
	for _,stateno in pairs(valid_state_selections) do
		local statedef = ai_data.state_data[stateno]
		
		if partner:power() >= (-1 * statedef.power) and statedef.hitdef.type >= 3 and not partner:ctrl() and curr_state_data ~= nil and curr_state_data.hitdef ~= nil and curr_state_data.hitdef.type < statedef.hitdef.type then
			-- retain supers if linking
			filtered_state_selections[#filtered_state_selections + 1] = stateno
		elseif partner:power() >= (-1 * statedef.power) and statedef.hitdef.type >= 3 and partner:ctrl() and mugen.random(1000) < 30 then
			-- retain supers if standby and random
			filtered_state_selections[#filtered_state_selections + 1] = stateno
		elseif statedef.hitdef.type < 3 then
			-- retain non-supers always
			filtered_state_selections[#filtered_state_selections + 1] = stateno
		end
	end
	
	-- if enemy gets knocked down, jump out of range
	if partner:ctrl() and (enemy1 == nil or enemy1:statetype() == 'L') and (enemy2 == nil or enemy2:statetype() == 'L') and distance <= (0.2*mugen.screenwidth()) then
		if partner:statetype() ~= 'S' or not partner:ctrl() then return end
		partner:forcecustomstate(current, 41, 0)
		mugen.log("AI Assist selected state 41 by jump-out movement method.\n")
		return
	end
	
	-- if enemy is still getting up, just guard
	if partner:ctrl() and (enemy1 == nil or (enemy1:stateno() >= 5100 and enemy1:stateno() < 5200)) and (enemy2 == nil or (enemy2:stateno() >= 5100 and enemy2:stateno() < 5200)) and partner:stateno() ~= 41 and partner:stateno() ~= 42 and partner:stateno() ~= 50 then
		partner:selfstate({value = 120, ctrl = true})
		return
	end
	
	-- if there are no moves to use, we should try to either move in or jump in
	-- jump moves on the partner may be unreliable, so we can use forced custom states with well-defined movement states
	if #filtered_state_selections == 0 then
		-- if not standing, we can just drop out early
		if partner:statetype() ~= 'S' or not partner:ctrl() then return end
		
		partner:forcecustomstate(current, 42, 0)
		mugen.log("AI Assist selected state 42 by jump-in movement method.\n")
		return
	end
	
	-- select an attack, prioritizing attacks which link nicely
	if #filtered_state_selections > 0 then
		if mugen.random(1000) < 120 then
			local rand = math.random(#filtered_state_selections)
			partner:selfstate({value = filtered_state_selections[rand]})
			mugen.log("AI Assist selected state " .. filtered_state_selections[rand] .. " by random chance method.\n")
		else
			-- 1. identify lowest type
			local lowest_type = 10
			for k,v in pairs(filtered_state_selections) do
				lowest_type = math.min(ai_data.state_data[v].hitdef.type, lowest_type)
			end
			-- 2. filter for this specifically
			local states_filtered = {}
			for k,v in pairs(filtered_state_selections) do
				if ai_data.state_data[v].hitdef.type == lowest_type then
					states_filtered[#states_filtered + 1] = v
				end
			end
			-- 3. select at random
			if #states_filtered > 0 then
				local rand = math.random(#states_filtered)
				partner:selfstate({value = states_filtered[rand]})
				mugen.log("AI Assist selected state " .. states_filtered[rand] .. " by chain elimination method.\n")
			end
		end
	end
end

-- force garbage collector params correctly before executing script proper
collectgarbage("setpause", 100)
collectgarbage("setstepmul", 200)
collectgarbage("restart")

local co = coroutine.create(userscript)
local status, err = coroutine.resume(co)
if not status then
	mugen.log("Failed to run AI execution script: " .. err .. "\n")
	local full_tb = debug.traceback(co)
	mugen.log(full_tb .. "\n")
end