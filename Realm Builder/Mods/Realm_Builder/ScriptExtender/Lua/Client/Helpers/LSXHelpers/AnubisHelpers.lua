AnubisHelpers = AnubisHelpers or {}

local anubisValueTypes = {
	["string"] = { id = "String", type = "LSString", },
	["number"] = { id = "double", type = "double", },
	["boolean"] = { id = "bool", type = "bool", },
}

function AnubisHelpers.BuildScriptParamNode(paramName, value)
	local valueType = type(value)
	local anubisValueType = anubisValueTypes[valueType]
	if not anubisValueType then
		error("Unsupported Anubis script parameter value type: " .. tostring(valueType))
	end

	local paramNode = LSXNode.new("node", { id = "ScriptConfigParameter", })
	local attrNode = paramNode:AppendChild(LSXHelpers.AttrNode("Name", "LSString", paramName))

	-- why is this so deeply nested???
	paramNode:AppendChild(LSXHelpers.ChildrenNode())
		:AppendChild(LSXNode.new("node", { id = "Value", }))
		:AppendChild(LSXHelpers.ChildrenNode())
		:AppendChild(LSXNode.new("node", { id = "Scalar", }))
		:AppendChild(LSXHelpers.ChildrenNode())
		:AppendChild(LSXNode.new("node", { id = "Scalar", }))
		:AppendChild(LSXHelpers.ChildrenNode())
		:AppendChild(LSXNode.new("node", { id = anubisValueType.id, }))
		:AppendChild(LSXHelpers.AttrNode(anubisValueType.id, anubisValueType.type, value))

	return paramNode
end

--- @param triggerName any
--- @param wanderMin any
--- @param wanderMax any
--- @param sleepMin number?
--- @param sleepMax number?
function AnubisHelpers.BuildWanderParams(wanderMin, wanderMax, sleepMin, sleepMax, triggerName)

	local scriptConfigParamsNode = LSXNode.new("node",
		{ id = "ScriptConfigGlobalParameters", })

	local allParamsChildren = scriptConfigParamsNode:AppendChild(LSXHelpers.ChildrenNode())

	local wanderParams = {
		AnubisHelpers.BuildScriptParamNode("trigger", triggerName),
		AnubisHelpers.BuildScriptParamNode("wanderMin", wanderMin),
		AnubisHelpers.BuildScriptParamNode("wanderMax", wanderMax),
	}

	if sleepMin then
		table.insert(wanderParams, AnubisHelpers.BuildScriptParamNode("sleepMin", sleepMin))
	end
	if sleepMax then
		table.insert(wanderParams, AnubisHelpers.BuildScriptParamNode("sleepMax", sleepMax))
	end

	allParamsChildren:AppendChildren(wanderParams)
	local attrNode = LSXHelpers.AttrNode("AnubisConfigName", "FixedString", "GEN_Wander")

	return attrNode, scriptConfigParamsNode
end
