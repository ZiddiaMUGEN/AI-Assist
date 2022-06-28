-- Analyze.lua: probe the partner's states and anims to identify useful information
-- this script gets run once per frame, but the analysis is only done once.
-- results of analysis are stashed in a global variable `AI_ASSIST_ANALYSIS_RESULT_{ID}`

--- lol? https://stackoverflow.com/a/32389020
OR, XOR, AND = 1, 3, 4

function bitoper(a, b, oper)
   local r, m, s = 0, 2^31
   repeat
      s,a,b = a+b+m, a%m, b%m
      r,m = r + m*oper%(s-a-b), m/2
   until m < 1
   return r
end

function dump_animations(animation_data)
	mugen.log("==== COLLECTED ANIMATION DATA ====\n")
	for k,v in pairs(animation_data) do
		mugen.log("Action " .. k .. ":\n")
		mugen.log("  Action index: " .. v.index .. "\n")
		mugen.log("  Total frames: " .. v.length .. "\n")
		if v.active ~= 0 then
			mugen.log("  Startup frames: " .. v.startup .. "\n")
			mugen.log("  Active frames: " .. v.active .. "\n")
			mugen.log("  Recovery frames: " .. v.recovery .. "\n")
		end
		mugen.log("  CLSN1 (hitbox) count: " .. #(v.boxes) + 1 .. "\n")
		if #(v.boxes) > 0 then
			mugen.log("    CLSN1 details:\n")
			for i=1,#(v.boxes) do
				local box = v.boxes[i]
				mugen.log("      CLSN1[" .. i .. "]:\n")
				mugen.log("        Element: " .. box.element .. "\n")
				mugen.log("        Left bound: " .. box.left .. "\n")
				mugen.log("        Right bound: " .. box.right .. "\n")
				mugen.log("        Lower bound: " .. box.bottom .. "\n")
				mugen.log("        Upper bound: " .. box.top .. "\n")
			end
		end
	end
end

function dump_states(state_data)
	local function st_to_c(i)
		if i == 1 then return 'S'
		elseif i == 2 then return 'C'
		elseif i == 3 then return 'A'
		elseif i == 4 then return 'L'
		else return '?' end
	end
	
	local function mt_to_c(i)
		if i == 0 then return 'I'
		elseif i == 1 then return 'A'
		elseif i == 2 then return 'H'
		else return '?' end
	end
	
	local function p_to_c(i)
		if i == 1 then return 'S'
		elseif i == 2 then return 'C'
		elseif i == 3 then return 'A'
		elseif i == 0 then return 'N'
		else return '?' end
	end

	mugen.log("==== COLLECTED STATE DATA ====\n")
	for k,v in pairs(state_data) do
		mugen.log("State " .. k .. ":\n")
		mugen.log("  Statetype: " .. st_to_c(v.statetype) .. "\n")
		mugen.log("  Movetype: " .. mt_to_c(v.movetype) .. "\n")
		mugen.log("  Juggle points: " .. v.juggle .. "\n")
		if v.power < 0 then mugen.log("  Power cost: " .. (v.power * -1) .. "\n") end
		if v.power > 0 then mugen.log("  Power gain: " .. v.power .. "\n") end
		if v.invuln > 0 then mugen.log("  Invuln: " .. v.invuln .. "\n") end
		if v.hitdef ~= nil then
			mugen.log("  Hitdef properties:\n")
			if v.hitdef.type == 4 then mugen.log("    Attack strength: Hyper\n") end
			if v.hitdef.type == 3 then mugen.log("    Attack strength: Super\n") end
			if v.hitdef.type == 2 then mugen.log("    Attack strength: Heavy Normal\n") end
			if v.hitdef.type == 1 then mugen.log("    Attack strength: Medium Normal\n") end
			if v.hitdef.type == 0 then mugen.log("    Attack strength: Light Normal\n") end
			if v.hitdef.inair then mugen.log("    Attack is in the air\n") end
			if v.hitdef.throw then 
				mugen.log("    Attack is a throw\n") 
				if v.hitdef.target_state ~= -1 then mugen.log("    Target goes to state " .. v.hitdef.target_state .. "\n") end
			end
			mugen.log("    Frames to link: " .. v.hitdef.link_frames .. "\n")
		end
		mugen.log("  Player velocities:")
		for k2,v2 in pairs(v.velocities) do
			mugen.log(" (" .. v2.x .. "," .. v2.y .. ")")
		end
		mugen.log("\n")
		mugen.log("  Impact velocities:")
		for k2,v2 in pairs(v.impact_velocities) do
			mugen.log(" (" .. v2.x .. "," .. v2.y .. ")")
		end
		mugen.log("\n")
		if #(v.posadds) > 0 then
			mugen.log("  Position changes:")
			for k2,v2 in pairs(v.posadds) do
				mugen.log(" (" .. v2.x .. "," .. v2.y .. ")")
			end
			mugen.log("\n")
		end
		mugen.log("  Animations:")
		for k2,v2 in pairs(v.anims) do
			if v2 ~= -1 then mugen.log(" " .. v2) end
		end
		mugen.log("\n")
	end
end

function userscript()
	local current = player.current()
	local partner = current:partner()
	if _G['AI_ASSIST_ANALYSIS_RESULT_' .. partner:id()] ~= nil then return end
	
	local result = {}
	mugen.log("Performing AI assist analysis of partner player with ID " .. partner:id() .. "\n")
	
	local enemy1 = partner:enemy(0)
	local enemy2 = partner:enemy(1)
	
	-- detect enemy height based on standing animation
	local enemy1_stand = {top = 0, bottom = 0}
	if enemy1 ~= nil then
		local standing = enemy1:anim(0)
		if standing ~= nil then
			for element in standing:elements() do
				for clsn in element:clsn2() do
					enemy1_stand.top = math.min(enemy1_stand.top, clsn.top)
					enemy1_stand.bottom = math.max(enemy1_stand.bottom, clsn.bottom)
				end
			end
		end
	end
	local enemy2_stand = {top = 0, bottom = 0}
	if enemy2 ~= nil then
		local standing = enemy2:anim(0)
		if standing ~= nil then
			for element in standing:elements() do
				for clsn in element:clsn2() do
					enemy2_stand.top = math.min(enemy2_stand.top, clsn.top)
					enemy2_stand.bottom = math.max(enemy2_stand.bottom, clsn.bottom)
				end
			end
		end
	end
	
	-- extract information about all animations, in particular looking for frame data
	local animation_data = {}
	
	-- iterate all anims
	for animation in partner:animations() do
		local animno = animation:id()
	
		-- relevant details: startup/active/recovery frames, box extents
		-- here we record all clsn1 boxes just so we can get a feel for max extents
		animation_data[animno] = {
			index = animation:index(),
			length = animation:length(),
			startup = 0,
			active = 0,
			recovery = 0,
			boxes = {}
		}
		
		local elementindex = 1
		for element in animation:elements() do
			-- determine whether to increment startup, active, or recovery
			if element:clsn1count() == 0 and animation_data[animno].active == 0 then
				animation_data[animno].startup = animation_data[animno].startup + element:length()
			elseif element:clsn1count() == 0 and animation_data[animno].active ~= 0 then
				animation_data[animno].recovery = animation_data[animno].recovery + element:length()
			elseif element:clsn1count() == 1 then
				animation_data[animno].active = animation_data[animno].active + element:length()
			end
			-- iterate all hitboxes so we can append
			for clsn in element:clsn1() do
				animation_data[animno].boxes[#(animation_data[animno].boxes) + 1] = {
					element = elementindex,
					left = clsn.left,
					right = clsn.right,
					top = clsn.top,
					bottom = clsn.bottom
				}
			end
			elementindex = elementindex + 1
		end
	end
	
	-- parse the -1 to find states which are supposed to be playable
	-- then, parse those states to identify which ones have HitDefs, which ones grant/remove power, which ones grant iframes,
	-- determine startup/hitstun, velocities.
	local state_data = {}
	
	-- find the -1 statedef
	local command_state = partner:state(-1)
	if command_state == nil then
		mugen.log("Failed to parse statedef data for AI analysis: no -1 statedef discovered\n")
		return
	end
	
	-- iterate each controller in statedef -1
	for controller in command_state:controllers() do
		-- only care about ChangeState and SelfState
		if controller:type() == 0x01 then
			-- mark the destination state for processing
			local target = controller:properties().value
			if target:isconstant() then
				if partner:state(target:constant()) ~= nil then
					state_data[target:constant()] = {}
				else
					mugen.log("Command state references nonexistent state " .. target:constant() .. ".\n")
				end
			else
				mugen.log("Command state uses trigger for target state, cannot read.\n")
			end
		end
	end
	
	-- iterate all states and read specifics for states changed to from statedef -1
	for st in partner:states() do
		if state_data[st:stateno()] ~= nil then
			local jugglePoints = st:juggle()
			local animationID = st:animid()
			local xvel = st:xvel()
			local yvel = st:yvel()
			local power = st:poweradd()
			
			state_data[st:stateno()] = {
				statetype = st:statetype(),
				movetype = st:movetype(),
				juggle = -1,
				velocities = {{x = 0.0, y = 0.0}},
				impact_velocities = {{x = 0.0, y = 0.0}},
				posadds = {},
				anims = {},
				power = -1000, -- note: this assumes a power cost for every move. this is so we don't set a default of 0 to moves which define `poweradd` in StateDef as a trigger value. moves with 0 poweradd will naturally fix this value.
				invuln = 0
			}
			
			if jugglePoints:isconstant() then state_data[st:stateno()].juggle = jugglePoints:constant() end
			if animationID:isconstant() then state_data[st:stateno()].anims[animationID:constant()] = animationID:constant() end
			if xvel:isconstant() then state_data[st:stateno()].velocities[1].x = xvel:constant() end
			if yvel:isconstant() then state_data[st:stateno()].velocities[1].y = yvel:constant() end
			if power:isconstant() then state_data[st:stateno()].power = power:constant() end
			
			-- read state controllers to determine functionality
			-- in particular, looking for:
			---- ChangeAnim - ID 0x20 - value at +0x18
			---- HitDef - ID 0x25 - useful values are all in extended props
			---- NotHitBy - ID 0x1E - value at +0x18 (as bitflag), time at +0x24
			---- SuperPause - ID 0xD6 - poweradd at +0x60 -> +0x70 (extended props)
			---- PosAdd - ID 0x16 - x at +0x3C, assume y at +0x48 (floats)
			---- VelSet - ID 0x18 - x at +0x3C, assume y at +0x48 (floats)
			---- PowerAdd/PowerSet
			-- all these together paint a picture of how the state can be used.
			
			for controller in st:controllers() do
				if controller:type() == 0x20 then
					-- ChangeAnim: add to anims list
					local target = controller:properties().value
					if target:isconstant() then
						state_data[st:stateno()].anims[target:constant()] = target:constant()
					end
				elseif controller:type() == 0x18 then
					-- VelSet: add to velocities list
					local x = controller:properties().x
					local y = controller:properties().y
					
					if x:isconstant() then x = x:constant() else x = 0.0 end
					if y:isconstant() then y = y:constant() else y = 0.0 end
					
					state_data[st:stateno()].velocities[#(state_data[st:stateno()].velocities) + 1] = {x = x, y = y}
				elseif controller:type() == 0x16 then
					-- PosAdd: add to posadds list, these will be treated similar to velocities later
					local x = controller:properties().x
					local y = controller:properties().y
					
					if x:isconstant() then x = x:constant() else x = 0.0 end
					if y:isconstant() then y = y:constant() else y = 0.0 end
					
					state_data[st:stateno()].posadds[#(state_data[st:stateno()].posadds) + 1] = {x = x, y = y}
				elseif controller:type() == 0xD6 then
					-- SuperPause: check for additional poweradd value. add it to the existing total
					local poweradd = controller:properties().poweradd
					
					if poweradd:isconstant() then state_data[st:stateno()].power = state_data[st:stateno()].power + poweradd:constant() end
				elseif controller:type() == 0x1E then
					-- NotHitBy
					-- this doesn't take into account the flags or the activation frame for now. just a general indicator of whether a move has some iframes.
					local t = controller:properties().time
					if t:isconstant() then state_data[st:stateno()].invuln = state_data[st:stateno()].invuln + t:constant() end
				elseif controller:type() == 0x0D then
					-- PowerAdd
					local poweradd = controller:properties().value
					if poweradd:isconstant() then state_data[st:stateno()].power = state_data[st:stateno()].power + poweradd:constant() end
				elseif controller:type() == 0x0C then
					-- PowerSet: in general i treat this the same as PowerAdd since we can assume it sets power to something higher
					local poweradd = controller:properties().value
					if poweradd:isconstant() then state_data[st:stateno()].power = state_data[st:stateno()].power + poweradd:constant() end
					-- special case: if the value is 0 we can treat this as negative PowerMax.
					if poweradd:isconstant() and poweradd:constant() == 0 then state_data[st:stateno()].power = -1 * partner:powermax() end
				elseif controller:type() == 0x25 then
					-- HitDef: (most) hitdef properties are not stored directly. we use properties to help classify the kind of move this is.
					-- to do this, we assign a score to each property, and use the overall relative scores (summed from all hitdefs) to determine move style.
					local hitdef = controller:properties()
					if state_data[st:stateno()].hitdef == nil then state_data[st:stateno()].hitdef = {type = 0, inair = false, throw = false, target_state = -1, prio_score = 0, animtype_score = 0, damage_score = 0, link_frames = 0, damage = 0} end
					-- main properties we care about in classifying the move:
					---- affectteam: disqualifies the hitdef
					---- hitdefattr, hitflag: normal/super/hyper, grounded/air, throw/non-throw, hitflags
					---- damage, priority, animtype: indicator of how hard the hit is
					---- p2stateno: throw indicator
					---- timing-related: hitpausetime, hitshaketime, groundhittime, groundslidetime, airhittime
					---- velocity-related: groundvelocityx, groundvelocityy, airvelocityx, airvelocityy
					
					-- confirm affectteam can actually hit the enemy
					if hitdef.affectteam:constant() > 1 then
						-- classifying move as normal,super,hyper (0,1,2)
						local hda = hitdef.hitdefattr:constant()
						if bitoper(hda, 2336, AND) ~= 0 then
							state_data[st:stateno()].hitdef.type = 4
						elseif bitoper(hda, 1168, AND) ~= 0 then
							state_data[st:stateno()].hitdef.type = math.max(state_data[st:stateno()].hitdef.type, 3)
						elseif bitoper(hda, 584, AND) ~= 0 then
							state_data[st:stateno()].hitdef.type = math.max(state_data[st:stateno()].hitdef.type, 0)
						end
						
						-- classifying move as air/ground (idc about stand vs crouch)
						-- note if a move has 1 grounded and 1 air hitdef - we classify the whole move as air. (maybe not the best method.)
						if bitoper(hda, 4, AND) ~= 0 then
							state_data[st:stateno()].hitdef.inair = true
						end
						
						-- classifying move as throw, based either on hitdefattr or p2stateno
						-- (p2stateno is more accurate overall, but checking hitdefattr also helps capture the author's intent)
						-- throws also get assigned hitdef.type of 2.5 (sitting between heavy and super)
						if bitoper(hda, 448, AND) ~= 0 then
							state_data[st:stateno()].hitdef.throw = true
							state_data[st:stateno()].hitdef.type = 2.5
						end
						if hitdef.p2stateno:isconstant() and hitdef.p2stateno:constant() ~= -1 then
							state_data[st:stateno()].hitdef.throw = true
							state_data[st:stateno()].hitdef.type = 2.5
							state_data[st:stateno()].hitdef.target_state = hitdef.p2stateno:constant()
						end
						
						-- just store the move's hitflag as-is
						state_data[st:stateno()].hitdef.hitflag = hitdef.hitflag:constant()
						
						-- assign scores for how hard the hit is - this is used to determine which moves are light, med, and hard
						-- we take scores for priority, animtype, and damage, and average them out.
						-- (this is ofc inaccurate, but since we can't easily parse the command triggers, this is next best thing for determining what moves can link)
						if hitdef.priorityval:isconstant() then
							state_data[st:stateno()].hitdef.prio_score = math.max(state_data[st:stateno()].hitdef.prio_score, hitdef.priorityval:constant())
						end
						
						local animtype = hitdef.animtype:constant()
						if animtype > 2 then animtype = 2 end
						state_data[st:stateno()].hitdef.animtype_score = math.max(state_data[st:stateno()].hitdef.animtype_score, (animtype + 2) * 2)
						
						if hitdef.hitdamage:isconstant() then
							local damage = hitdef.hitdamage:constant()
							local damage_ratio = damage / partner:lifemax()
							if damage_ratio > 0.10 then damage_ratio = 0.10 end
							state_data[st:stateno()].hitdef.damage_score = math.max(state_data[st:stateno()].hitdef.damage_score, 70 * damage_ratio)
							state_data[st:stateno()].hitdef.damage = damage
						end
						
						-- try to assess how long the enemy's recovery will be on successful hit.
						if hitdef.groundhittime:isconstant() then
							local pauseframes = 0
							if hitdef.hitpausetime:isconstant() then pauseframes = hitdef.hitpausetime:constant() end
							state_data[st:stateno()].hitdef.link_frames = hitdef.groundhittime:constant() - pauseframes
						end
						
						-- assess the impact velocities
						if hitdef.groundvelocityx:isconstant() then
							local x = hitdef.groundvelocityx:constant()
							local y = 0.0
							if hitdef.groundvelocityy:isconstant() then y = hitdef.groundvelocityy:constant() end
							state_data[st:stateno()].impact_velocities[#(state_data[st:stateno()].impact_velocities) + 1] = {x = x, y = y}
						end
					else
						mugen.log("Skipping affectteam = F HitDef in state " .. st:stateno() .. "\n")
					end
				end
			end
			
			-- perform score aggregation
			if state_data[st:stateno()].hitdef ~= nil then
				state_data[st:stateno()].hitdef.attack_score = (state_data[st:stateno()].hitdef.prio_score + state_data[st:stateno()].hitdef.animtype_score + state_data[st:stateno()].hitdef.damage_score) / 3.0
			end
		end
	end
	
	-- do some computation on normal attacks to determine our idea of light, med, heavy.
	local avg_attack_score = 0
	local total_normal_attacks = 0
	for k,v in pairs(state_data) do
		if v.hitdef ~= nil and v.hitdef.type == 0 then
			total_normal_attacks = total_normal_attacks + 1
			avg_attack_score = avg_attack_score + v.hitdef.attack_score
		end
	end
	avg_attack_score = avg_attack_score / total_normal_attacks
	
	local light_attack_cutoff = avg_attack_score
	local med_attack_cutoff = avg_attack_score * 8/6
	
	for k,v in pairs(state_data) do
		if v.hitdef ~= nil and v.hitdef.type == 0 then
			if v.hitdef.attack_score > med_attack_cutoff then v.hitdef.type = 2
			elseif v.hitdef.attack_score > light_attack_cutoff then v.hitdef.type = 1
			else v.hitdef.type = 0 end
		end
	end
	
	result.animation_data = animation_data
	result.state_data = state_data
	result.enemy_stand = {first = enemy1_stand, second = enemy2_stand}
	dump_animations(animation_data)
	dump_states(state_data)
	
	_G['AI_ASSIST_ANALYSIS_RESULT_' .. partner:id()] = result
	mugen.log("AI assist analysis completed successfully.\n")
end

local co = coroutine.create(userscript)
local status, err = coroutine.resume(co)
if not status then
	mugen.log("Failed to run AI analysis script: " .. err .. "\n")
	local full_tb = debug.traceback(co)
	mugen.log(full_tb .. "\n")
end