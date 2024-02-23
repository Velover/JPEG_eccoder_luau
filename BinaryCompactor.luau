--!native
--!optimize 2

local INT_SIZE_BYTES = 4
local BYTE_SIZE_BITS = 8
local INT_SIZE_BITS = BYTE_SIZE_BITS * INT_SIZE_BYTES

local BinaryCompactor = {}

BinaryCompactor.Finish = function(self)
	local bit_index = self.CurrentBit % 32
	
	if bit_index ~= 0 then
		table.insert(self.NumberArray, self.CurrentNumber)
	end
	
	local return_buffer_size = #self.NumberArray * INT_SIZE_BYTES
	local return_buffer = buffer.create(return_buffer_size)
	for i = 0, #self.NumberArray - 1 do
		local number = self.NumberArray[i + 1]
		buffer.writeu32(return_buffer, i * INT_SIZE_BYTES, number)
	end
	
	return buffer.readstring(return_buffer, 0, return_buffer_size)
end

BinaryCompactor.Add = function(self, value: number, size: number)	
	local bit_index = self.CurrentBit % 32
	local awaible_bits = INT_SIZE_BITS - bit_index
	
	if awaible_bits - size < 0 then
		local number_2_size = size - awaible_bits
		local number_2 = bit32.extract(value, awaible_bits, size - awaible_bits)
		self.CurrentNumber = bit32.replace(self.CurrentNumber, value, bit_index, awaible_bits)
		self.CurrentBit += awaible_bits
		table.insert(self.NumberArray, self.CurrentNumber)
		self.CurrentNumber = 0
		
		BinaryCompactor.Add(self, number_2, number_2_size)
		return
	end
	
	local snapped_bit = self.CurrentBit - bit_index
	self.CurrentNumber = bit32.replace(self.CurrentNumber, value, bit_index, size)
	self.CurrentBit += size
	if self.CurrentBit - snapped_bit < 32 then
		return
	end
	table.insert(self.NumberArray, self.CurrentNumber)
	self.CurrentNumber = 0
end

function BinaryCompactor.New()
	local self = {}
	self.CurrentNumber = 0
	self.CurrentBit = 0
	self.NumberArray = {}
	return self
end 

return BinaryCompactor
