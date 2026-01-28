local instanceTable = {
	Part = {
		Color = Color3.fromRGB(163, 162, 165),
		Material = Enum.Material.Plastic,
		MaterialVariant = "",
		Reflectance = 0,
		Transparency = 0,
		Archivable = true,
		Locked = false,
		Name = "Part",
		Size = Vector3.new(4, 1, 2),
		Position = Vector3.new(),
		Orientation = Vector3.new(),
		CFrame = CFrame.new(),
		CanCollide = true,
		CanTouch = true,
		CanQuery = true,
		Anchored = true,
		Shape = Enum.PartType.Block,
		TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth,
		LeftSurface = Enum.SurfaceType.Smooth,
		RightSurface = Enum.SurfaceType.Smooth,
		FrontSurface = Enum.SurfaceType.Smooth,
		BackSurface = Enum.SurfaceType.Smooth,
		CastShadow = true,
		CollisionGroup = "Default",
		CustomPhysicalProperties = nil,
		Massless = true
	},
	KeyframeSequence = {
		Name = "KeyframeSequence",
		Loop = true,
		Priority = Enum.AnimationPriority.Action,
		Archivable = true
	},
	Keyframe = {
		Archivable = true,
		Time = 0,
		Name = "Keyframe"
	},
	Pose = {
		Archivable = true,
		Name = "Pose",
		CFrame = CFrame.new(),
		EasingDirection = Enum.EasingDirection.In,
		EasingStyle = Enum.EasingStyle.Linear,
		Weight = 1
	},
	Model = {
		Name = "Model",
		Archivable = true,
		LevelOfDetail = Enum.ModelLevelOfDetail.Automatic,
		ModelStreamingMode = Enum.ModelStreamingMode.Default,
		WorldPivot = CFrame.new()
	}
} :: {[string]: {[string]: any}}

-- HELPER FUNCTIONS
local function getSorted(tbl, f)
	local clone = table.clone(tbl)
	table.sort(clone, f)
	return clone
end

local function getKeys(dict)
	local keys = {}
	for k in dict do table.insert(keys, k) end
	return keys
end

-- DEFINITIONS
local numberIdentifiers = getSorted({"nan", "+inf", "-inf", "u8", "u16", "u32", "u64", "i8", "i16", "i32", "i64", "f32", "f64"})
local datatypeList = getSorted({"number", "true", "false", "string", "Color3", "Vector3", "CFrame", "EnumItem", "nil"})

local enumList = getSorted(Enum:GetEnums(), function(a, b) return tostring(a) < tostring(b) end)
local enumIndexMap = {}
for i, enum in ipairs(enumList) do enumIndexMap[enum] = i end

local sortedInstances = getSorted(getKeys(instanceTable))
local sortedKeys = {}
local propertyIndices = {}

for k, v in instanceTable do
	local keys = getSorted(getKeys(v))
	sortedKeys[k] = keys
	local flipped = {}
	for i, propName in ipairs(keys) do flipped[propName] = i end
	propertyIndices[k] = flipped
end

-- NUMBER LOGIC
local function classifyNumber(n: number)
	local function findIdentifier(t) return string.char(table.find(numberIdentifiers, t)) end
	if n ~= n then return findIdentifier("nan")
	elseif n == math.huge then return findIdentifier("+inf")
	elseif n == -math.huge then return findIdentifier("-inf")
	end
	if n % 1 == 0 then
		if n >= 0 then
			if n <= 0xFF then return findIdentifier("u8")
			elseif n <= 0xFFFF then return findIdentifier("u16")
			elseif n <= 0xFFFFFFFF then return findIdentifier("u32")
			else return findIdentifier("u64") end
		else
			if n >= -0x80 then return findIdentifier("i8")
			elseif n >= -0x8000 then return findIdentifier("i16")
			elseif n >= -0x80000000 then return findIdentifier("i32")
			else return findIdentifier("i64") end
		end
	else
		return (string.unpack("f", string.pack("f", n)) == n) and findIdentifier("f32") or findIdentifier("f64")
	end
end

local function packNumber(n, t_index)
	local t = numberIdentifiers[t_index]
	if t == "u8" then return string.pack("<B", n)
	elseif t == "u16" then return string.pack("<I2", n)
	elseif t == "u32" then return string.pack("<I4", n)
	elseif t == "u64" then return string.pack("<I8", n)
	elseif t == "i8" then return string.pack("<b", n)
	elseif t == "i16" then return string.pack("<i2", n)
	elseif t == "i32" then return string.pack("<i4", n)
	elseif t == "i64" then return string.pack("<i8", n)
	elseif t == "f32" then return string.pack("<f", n)
	else return string.pack("<d", n) end
end

-- DATATYPE SERIALIZATION
local function serializeDatatype(datatype: any)
	local function getIdentifier(t) return string.char(table.find(datatypeList, t)) end
	local t = typeof(datatype)

	-- Handle boolean as true or false cuz it saves space
	if t == "boolean" then
		return getIdentifier(tostring(datatype))
	end

	local idIdx = table.find(datatypeList, t)
	if not idIdx then 
		warn("Unhandled type:", t)
		return getIdentifier("nil") 
	end
	local identifier = string.char(idIdx)

	if t == "nil" then return identifier
	elseif t == "number" then
		local numId = classifyNumber(datatype)
		return identifier .. numId .. packNumber(datatype, string.byte(numId))
	elseif t == "string" then
		return identifier .. string.pack("<I2", #datatype) .. datatype
	elseif t == "Color3" then
		return identifier .. string.pack("BBB", math.floor(datatype.R*255), math.floor(datatype.G*255), math.floor(datatype.B*255))
	elseif t == "Vector3" then
		return identifier .. string.pack("<fff", datatype.X, datatype.Y, datatype.Z)
	elseif t == "CFrame" then
		return identifier .. string.pack("<ffffffffffff", datatype:GetComponents())
	elseif t == "EnumItem" then
		local enumId = enumIndexMap[datatype.EnumType]
		return identifier .. string.pack("<I2I2", enumId or 0, datatype.Value)
	end
	return getIdentifier("nil")
end

-- INSTANCE SERIALIZATION
local function serializeProperties(target: Instance)
	local class = target.ClassName
	local classId = table.find(sortedInstances, class)
	if not classId or not instanceTable[class] then return "" end

	local data = string.char(classId)
	for i, propName in ipairs(sortedKeys[class]) do
		local success, val = pcall(function() return target[propName] end)
		if success and val ~= instanceTable[class][propName] then
			local serializedVal = serializeDatatype(val)
			
			-- PropID .. DataLength .. Data
			data = data .. string.char(i) .. string.pack("<I2", #serializedVal) .. serializedVal
		end
	end
	return data .. string.char(0) 
end

local function serialize(target: Instance)
	local instanceData = serializeProperties(target)
	if #instanceData == 0 then return "" end

	local children = target:GetChildren()
	instanceData = instanceData .. string.pack("<I2", #children)
	for _, child in children do
		instanceData = instanceData .. serialize(child)
	end
	return instanceData
end

-- DESERIALIZATION
local function deserializeDatatype(data: string, offset: number)
	local typeId = string.byte(data, offset)
	local typeName = datatypeList[typeId]
	offset += 1

	if typeName == "nil" then return nil, offset
	elseif typeName == "true" then return true, offset
	elseif typeName == "false" then return false, offset
	elseif typeName == "string" then
		local len = string.unpack("<I2", data, offset)
		return string.sub(data, offset + 2, offset + 1 + len), offset + 2 + len
	elseif typeName == "number" then
		local nIdx = string.byte(data, offset)
		local nType = numberIdentifiers[nIdx]
		local formatMap = {u8="B", u16="I2", u32="I4", u64="I8", i8="b", i16="i2", i32="i4", i64="i8", f32="f", f64="d", nan="d", ["+inf"]="d", ["-inf"]="d"}
		local sizeMap = {B=1, I2=2, I4=4, I8=8, b=1, i2=2, i4=4, i8=8, f=4, d=8}
		local fmt = formatMap[nType]
		local val = string.unpack("<" .. fmt, data, offset + 1)
		return val, offset + 1 + sizeMap[fmt]
	elseif typeName == "Color3" then
		local r, g, b = string.unpack("BBB", data, offset)
		return Color3.fromRGB(r, g, b), offset + 3
	elseif typeName == "Vector3" then
		local x, y, z = string.unpack("<fff", data, offset)
		return Vector3.new(x, y, z), offset + 12
	elseif typeName == "CFrame" then
		local c = {string.unpack("<ffffffffffff", data, offset)}
		return CFrame.new(unpack(c, 1, 12)), offset + 48
	elseif typeName == "EnumItem" then
		local eId, eVal = string.unpack("<I2I2", data, offset)
		local enum = enumList[eId]
		if enum then
			for _, item in enum:GetEnumItems() do
				if item.Value == eVal then return item, offset + 4 end
			end
		end
		return nil, offset + 4
	end
	return nil, offset
end

local function deserialize(data: string, offset: number)
	local classId = string.byte(data, offset)
	local className = sortedInstances[classId]
	if not className then return nil, offset + 1 end
	offset += 1

	local inst = Instance.new(className)
	local propKeys = sortedKeys[className]

	-- Properties
	while true do
		local propId = string.byte(data, offset)
		offset += 1
		if propId == 0 then break end

		local len = string.unpack("<I2", data, offset)
		local val = deserializeDatatype(data, offset + 2)
		local propName = propKeys[propId]
		if propName then
			pcall(function() inst[propName] = val end)
		end
		offset += 2 + len
	end

	-- Children
	local childCount = string.unpack("<I2", data, offset)
	offset += 2
	for i = 1, childCount do
		local child, nextOffset = deserialize(data, offset)
		if child then child.Parent = inst end
		offset = nextOffset
	end

	return inst, offset
end

return {
	serialize = serialize,
	deserialize = function(data, offset) return deserialize(data, offset or 1) end
}
