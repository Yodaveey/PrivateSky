--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.
local StringUtil = {}

function StringUtil:GenerateString(Length: number)
	local String = ""
	for i = 1, Length do
		String = String .. string.char(math.random(33, 126))
	end
	return String
end

function StringUtil:GenerateBytes(Length: number)
	local bytecode = "0x"
	for i = 1, Length do
		bytecode = bytecode .. string.format("%x", math.random(0, 15))
	end
	return bytecode
end

return StringUtil