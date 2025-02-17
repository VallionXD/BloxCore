function valueToString(value, indentation, parentTable, varName, isFromTovar, path, tables, tableIndex)
	indentation = indentation or 0
	parentTable = parentTable or {}
	varName = varName or ""
	isFromTovar = isFromTovar or false
	path = path or ""
	tables = tables or {}
	tableIndex = tableIndex or {0}

	local function formatString(s, indent)
		indent = indent or 0
		local handled, reachedMax = handleSpecials(s, indent)
		return '"' .. handled .. '"' .. (reachedMax and " --[[ MAXIMUM STRING SIZE REACHED, CHANGE '_G.SimpleSpyMaxStringSize' TO ADJUST MAXIMUM SIZE ]]" or "")
	end

	local function handleSpecials(value, indent)
		local buildStr = {}
		local i = 1
		local char = string.sub(value, i, i)
		local indentStr
		while char ~= "" do
			if char == '"' then
				buildStr[i] = '\\"'
			elseif char == "\\" then
				buildStr[i] = "\\\\"
			elseif char == "\n" then
				buildStr[i] = "\\n"
			elseif char == "\t" then
				buildStr[i] = "\\t"
			elseif string.byte(char) > 126 or string.byte(char) < 32 then
				buildStr[i] = string.format("\\%d", string.byte(char))
			else
				buildStr[i] = char
			end
			i = i + 1
			char = string.sub(value, i, i)
			if i % 200 == 0 then
				indentStr = indentStr or string.rep(" ", indent + 4)
				table.move({ '"\n', indentStr, '... "' }, 1, 3, i, buildStr)
				i += 3
			end
		end
		return table.concat(buildStr)
	end

	local function valueToPath(x, t, path, prev)
		path = path or ""
		prev = prev or {}
		if rawequal(x, t) then
			return true, ""
		end
		for i, v in pairs(t) do
			if rawequal(v, x) then
				if type(i) == "string" and i:match("^[%a_]+[%w_]*$") then
					return true, (path .. "." .. i)
				else
					return true, (path .. "[" .. valueToString(i) .. "]")
				end
			end
			if type(v) == "table" then
				local duplicate = false
				for _, y in pairs(prev) do
					if rawequal(y, v) then
						duplicate = true
					end
				end
				if not duplicate then
					table.insert(prev, t)
					local found
					found, path = valueToPath(x, v, path, prev)
					if found then
						if type(i) == "string" and i:match("^[%a_]+[%w_]*$") then
							return true, "." .. i .. path
						else
							return true, "[" .. valueToString(i) .. "]" .. path
						end
					end
				end
			end
		end
		return false, ""
	end

	local function functionToString(f)
		for k, x in pairs(getgenv()) do
			local isFound, gpath
			if rawequal(x, f) then
				isFound, gpath = true, ""
			elseif type(x) == "table" then
				isFound, gpath = valueToPath(f, x)
			end
			if isFound and type(k) ~= "function" then
				if type(k) == "string" and k:match("^[%a_]+[%w_]*$") then
					return k .. gpath
				else
					return "getgenv()[" .. valueToString(k) .. "]" .. gpath
				end
			end
		end
		if debug.getinfo(f).name:match("^[%a_]+[%w_]*$") then
			return "function()end --[[" .. debug.getinfo(f).name .. "]]"
		end
		return "function()end --[[" .. tostring(f) .. "]]"
	end

	local function instanceToPath(i)
		local player = getPlayer(i)
		local parent = i
		local out = ""
		if parent == nil then
			return "nil"
		elseif player then
			while true do
				if parent and parent == player.Character then
					if player == Players.LocalPlayer then
						return 'game:GetService("Players").LocalPlayer.Character' .. out
					else
						return instanceToPath(player) .. ".Character" .. out
					end
				else
					if parent.Name:match("[%a_]+[%w+]*") ~= parent.Name then
						out = ":FindFirstChild(" .. formatString(parent.Name) .. ")" .. out
					else
						out = "." .. parent.Name .. out
					end
				end
				parent = parent.Parent
			end
		elseif parent ~= game then
			while true do
				if parent and parent.Parent == game then
					local service = game:FindService(parent.ClassName)
					if service then
						if parent.ClassName == "Workspace" then
							return "workspace" .. out
						else
							return 'game:GetService("' .. service.ClassName .. '")' .. out
						end
					else
						if parent.Name:match("[%a_]+[%w_]*") then
							return "game." .. parent.Name .. out
						else
							return "game:FindFirstChild(" .. formatString(parent.Name) .. ")" .. out
						end
					end
				elseif parent.Parent == nil then
					getnilrequired = true
					return "getNil(" .. formatString(parent.Name) .. ', "' .. parent.ClassName .. '")' .. out
				elseif parent == Players.LocalPlayer then
					out = ".LocalPlayer" .. out
				else
					if parent.Name:match("[%a_]+[%w_]*") ~= parent.Name then
						out = ":FindFirstChild(" .. formatString(parent.Name) .. ")" .. out
					else
						out = "." .. parent.Name .. out
					end
				end
				parent = parent.Parent
			end
		else
			return "game"
		end
	end

	local function userdataToString(u)
		if typeof(u) == "TweenInfo" then
			return "TweenInfo.new(" .. tostring(u.Time) .. ", Enum.EasingStyle." .. tostring(u.EasingStyle) .. ", Enum.EasingDirection." .. tostring(u.EasingDirection) .. ", " .. tostring(u.RepeatCount) .. ", " .. tostring(u.Reverses) .. ", " .. tostring(u.DelayTime) .. ")"
		elseif typeof(u) == "Ray" then
			return "Ray.new(" .. userdataToString(u.Origin) .. ", " .. userdataToString(u.Direction) .. ")"
		elseif typeof(u) == "NumberSequence" then
			local ret = "NumberSequence.new("
			for i, v in pairs(u.KeyPoints) do
				ret = ret .. tostring(v)
				if i < #u.Keypoints then
					ret = ret .. ", "
				end
			end
			return ret .. ")"
		elseif typeof(u) == "DockWidgetPluginGuiInfo" then
			return "DockWidgetPluginGuiInfo.new(Enum.InitialDockState" .. tostring(u) .. ")"
		elseif typeof(u) == "ColorSequence" then
			local ret = "ColorSequence.new("
			for i, v in pairs(u.KeyPoints) do
				ret = ret .. "Color3.new(" .. tostring(v) .. ")"
				if i < #u.Keypoints then
					ret = ret .. ", "
				end
			end
			return ret .. ")"
		elseif typeof(u) == "BrickColor" then
			return "BrickColor.new(" .. tostring(u.Number) .. ")"
		elseif typeof(u) == "NumberRange" then
			return "NumberRange.new(" .. tostring(u.Min) .. ", " .. tostring(u.Max) .. ")"
		elseif typeof(u) == "Region3" then
			local center = u.CFrame.Position
			local size = u.CFrame.Size
			local vector1 = center - size / 2
			local vector2 = center + size / 2
			return "Region3.new(" .. userdataToString(vector1) .. ", " .. userdataToString(vector2) .. ")"
		elseif typeof(u) == "Faces" then
			local faces = {}
			if u.Top then table.insert(faces, "Enum.NormalId.Top") end
			if u.Bottom then table.insert(faces, "Enum.NormalId.Bottom") end
			if u.Left then table.insert(faces, "Enum.NormalId.Left") end
			if u.Right then table.insert(faces, "Enum.NormalId.Right") end
			if u.Back then table.insert(faces, "Enum.NormalId.Back") end
			if u.Front then table.insert(faces, "Enum.NormalId.Front") end
			return "Faces.new(" .. table.concat(faces, ", ") .. ")"
		elseif typeof(u) == "EnumItem" then
			return tostring(u)
		elseif typeof(u) == "Enums" then
			return "Enum"
		elseif typeof(u) == "Enum" then
			return "Enum." .. tostring(u)
		elseif typeof(u) == "RBXScriptSignal" then
			return "nil --[[RBXScriptSignal]]"
		elseif typeof(u) == "Vector3" then
			return string.format("Vector3.new(%s, %s, %s)", valueToString(u.X), valueToString(u.Y), valueToString(u.Z))
		elseif typeof(u) == "CFrame" then
			local xAngle, yAngle, zAngle = u:ToEulerAnglesXYZ()
			return string.format("CFrame.new(%s, %s, %s) * CFrame.Angles(%s, %s, %s)", valueToString(u.X), valueToString(u.Y), valueToString(u.Z), valueToString(xAngle), valueToString(yAngle), valueToString(zAngle))
		elseif typeof(u) == "DockWidgetPluginGuiInfo" then
			return string.format("DockWidgetPluginGuiInfo(%s, %s, %s, %s, %s, %s, %s)", "Enum.InitialDockState.Right", valueToString(u.InitialEnabled), valueToString(u.InitialEnabledShouldOverrideRestore), valueToString(u.FloatingXSize), valueToString(u.FloatingYSize), valueToString(u.MinWidth), valueToString(u.MinHeight))
		elseif typeof(u) == "PathWaypoint" then
			return string.format("PathWaypoint.new(%s, %s)", valueToString(u.Position), valueToString(u.Action))
		elseif typeof(u) == "UDim" then
			return string.format("UDim.new(%s, %s)", valueToString(u.Scale), valueToString(u.Offset))
		elseif typeof(u) == "UDim2" then
			return string.format("UDim2.new(%s, %s, %s, %s)", valueToString(u.X.Scale), valueToString(u.X.Offset), valueToString(u.Y.Scale), valueToString(u.Y.Offset))
		elseif typeof(u) == "Rect" then
			return string.format("Rect.new(%s, %s)", valueToString(u.Min), valueToString(u.Max))
		else
			return string.format("nil --[[%s]]", typeof(u))
		end
	end

	local function getPlayer(instance)
		for _, v in pairs(Players:GetPlayers()) do
			if v.Character and (instance:IsDescendantOf(v.Character) or instance == v.Character) then
				return v
			end
		end
	end

	local function tableToString(t, l, p, n, vtv, i, pt, path, tables, tI)
		local globalIndex = table.find(getgenv(), t)
		if type(globalIndex) == "string" then
			return globalIndex
		end
		if not tI then
			tI = {0}
		end
		if not path then
			path = ""
		end
		if not l then
			l = 0
			tables = {}
		end
		if not p then
			p = t
		end
		for _, v in pairs(tables) do
			if n and rawequal(v, t) then
				return "{} --[[DUPLICATE]]"
			end
		end
		table.insert(tables, t)
		local s = "{"
		local size = 0
		l = l + indentation
		for k, v in pairs(t) do
			size = size + 1
			if size > (_G.SimpleSpyMaxTableSize or 1000) then
				s = s .. "\n" .. string.rep(" ", l) .. "-- MAXIMUM TABLE SIZE REACHED, CHANGE '_G.SimpleSpyMaxTableSize' TO ADJUST MAXIMUM SIZE "
				break
			end
			if rawequal(k, t) then
				s = s .. "\n" .. string.rep(" ", l) .. "[" .. tostring(n) .. tostring(path) .. "]" .. " = " .. (rawequal(v, k) and tostring(n) .. tostring(path) or valueToString(v, l, p, n, vtv, k, t, path .. "[" .. tostring(n) .. tostring(path) .. "]", tables))
				size -= 1
				continue
			end
			local currentPath = ""
			if type(k) == "string" and k:match("^[%a_]+[%w_]*$") then
				currentPath = "." .. k
			else
				currentPath = "[" .. valueToString(k, l, p, n, vtv, k, t, path .. currentPath, tables, tI) .. "]"
			end
			if size % 100 == 0 then
				scheduleWait()
			end
			s = s .. "\n" .. string.rep(" ", l) .. "[" .. valueToString(k, l, p, n, vtv, k, t, path .. currentPath, tables, tI) .. "] = " .. valueToString(v, l, p, n, vtv, k, t, path .. currentPath, tables, tI) .. ","
		end
		if #s > 1 then
			s = s:sub(1, #s - 1)
		end
		if size > 0 then
			s = s .. "\n" .. string.rep(" ", l - indentation)
		end
		return s .. "}"
	end

	local function keyToString(v, ...)
		if typeof(v) == "userdata" and getrawmetatable(v) then
			return string.format('"<void> (%s)" --[[Potentially hidden data (tostring in SimpleSpy:HookRemote/GetRemoteFiredSignal at your own risk)]]', safetostring(v))
		elseif typeof(v) == "userdata" then
			return string.format('"<void> (%s)"', safetostring(v))
		elseif type(v) == "userdata" and typeof(v) ~= "Instance" then
			return string.format('"<%s> (%s)"', typeof(v), tostring(v))
		elseif type(v) == "function" then
			return string.format('"<Function> (%s)"', tostring(v))
		end
		return valueToString(v, ...)
	end

	if not tableIndex then
		tableIndex = {0}
	else
		tableIndex[1] += 1
	end
	if typeof(value) == "number" then
		if value == math.huge then
			return "math.huge"
		elseif tostring(value):match("nan") then
			return "0/0 --[[NaN]]"
		end
		return tostring(value)
	elseif typeof(value) == "boolean" then
		return tostring(value)
	elseif typeof(value) == "string" then
		return formatString(value, indentation)
	elseif typeof(value) == "function" then
		return functionToString(value)
	elseif typeof(value) == "table" then
		return tableToString(value, indentation, parentTable, varName, isFromTovar, value, parentTable, path, tables, tableIndex)
	elseif typeof(value) == "Instance" then
		return instanceToPath(value)
	elseif typeof(value) == "userdata" then
		return "newproxy(true)"
	elseif type(value) == "userdata" then
		return userdataToString(value)
	elseif type(value) == "vector" then
		return string.format("Vector3.new(%s, %s, %s)", valueToString(value.X), valueToString(value.Y), valueToString(value.Z))
	else
		return "nil --[[" .. typeof(value) .. "]]"
	end
end

return { ValueToString = valueToString }
