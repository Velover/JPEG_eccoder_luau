--!native
--!optimize 2

local INT_SIZE_BYTES = 4
local BYTE_SIZE_BITS = 8
local INT_SIZE_BITS = BYTE_SIZE_BITS * INT_SIZE_BYTES
local INVERSE_32 = 1 / 32

local BinaryDeompactor = {}

BinaryDeompactor.ReadBits = function(self, width: number)
	local bit_index = math.floor(self.CurrentBit * INVERSE_32)	+ 1
	local bit_local_index = self.CurrentBit % 32
	local awaible_bits = INT_SIZE_BITS - bit_local_index
	
	local current_number = self.NumberArray[bit_index]	
	if awaible_bits - width < 0 then
		local number_1 = bit32.extract(current_number, bit_local_index, awaible_bits)
		self.CurrentBit += awaible_bits
		local bit_local_index = self.CurrentBit % 32
		current_number = self.NumberArray[bit_index + 1]
		local number_2_width = width - awaible_bits
		local number_2 = bit32.extract(current_number, bit_local_index, number_2_width)
		self.CurrentBit += number_2_width
		
		local number = bit32.replace(number_1, number_2, awaible_bits, number_2_width)
		return number
	end
	local number = bit32.extract(current_number, bit_local_index, width)
	self.CurrentBit += width
	return number
end

BinaryDeompactor.Debug = function(self)
	local bits = ""
	for _, value in self.NumberArray:: {number} do
		local bit_string = ''
		for i = 0, 32-1 do
			if i % 4 == 0 then
				bit_string = " " .. bit_string
			end
			local bit = bit32.extract(value, i, 1)
			bit_string = bit .. bit_string
		end
		bits ..= bit_string .. " | "
	end
	print(bits)
end

function BinaryDeompactor.New(encoded_string: string)
	local self = {}
	self.CurrentBit = 0
	self.NumberArray = {}
	
	local string_buffer = buffer.fromstring(encoded_string)
	local buffer_length = buffer.len(string_buffer)
	local buffer_32bit_length = buffer_length / INT_SIZE_BYTES
	
	for i = 0, buffer_32bit_length - 1 do
		local value = buffer.readu32(string_buffer, i * INT_SIZE_BYTES)
		table.insert(self.NumberArray, value)
	end
	return self
end 

return BinaryDeompactor
