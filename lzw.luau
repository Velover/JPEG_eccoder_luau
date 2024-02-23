--!native
--!optimize 2
local CHARACTER_ARRAY = {}
for i = 0, 255 do
	CHARACTER_ARRAY[string.char(i)] = i
end

local NUMBER_ARRAY = {}
for i = 0, 255 do
	NUMBER_ARRAY[i] = string.char(i)
end

local NUMBER_ARRAY_2 = {}
for i = 0, 255 do
	NUMBER_ARRAY_2[i] = {i}
end

local MAX_BIT_16_NUMBER = 0b1111_1111_1111_1111
local MAX_AMOUNT_OF_ENTRIES = MAX_BIT_16_NUMBER
local BIT16_NUMBER_SIZE_BYTES = 2


local LZW = {}

LZW.EncodeTextToText = function(text: string)
	local character_array = table.clone(CHARACTER_ARRAY)

	local encoded_array = {}

	local max_value = 255
	local text_buffer = ""

	local TakeNextAndCompare = function(character: string)
		local expected_buffer = text_buffer .. character
		if character_array[expected_buffer] then
			text_buffer = expected_buffer
			return
		end
		local number = character_array[text_buffer]
		table.insert(encoded_array, number)

		text_buffer = character

		max_value += 1
		if max_value > MAX_AMOUNT_OF_ENTRIES then
			character_array = table.clone(CHARACTER_ARRAY)
			max_value = 255
			return
		end

		character_array[expected_buffer] = max_value		
	end

	for i = 1, string.len(text) do
		TakeNextAndCompare(text:sub(i, i))
	end

	if string.len(text_buffer) ~= 0 then
		table.insert(encoded_array, character_array[text_buffer])
	end
	
	print(#encoded_array)
	
	local text_buffer = buffer.create(#encoded_array * BIT16_NUMBER_SIZE_BYTES)
	for i = 0, #encoded_array - 1 do
		local number = encoded_array[i + 1]
		buffer.writeu16(text_buffer, i * BIT16_NUMBER_SIZE_BYTES, number)
	end
	
	return buffer.tostring(text_buffer)
end

LZW.DecodeFromTextToInt = function(encoded_text: string)
	local encoded_array = {}
	local text_buffer = buffer.fromstring(encoded_text)
	for i = 0, buffer.len(text_buffer) / BIT16_NUMBER_SIZE_BYTES - 1 do
		local number = buffer.readu16(text_buffer, i * BIT16_NUMBER_SIZE_BYTES)
		table.insert(encoded_array, number)
	end	
	
	local number_array = table.clone(NUMBER_ARRAY_2)

	local last_combination = number_array[encoded_array[1]]
	local return_array = table.clone(last_combination)
	local max_value = 255

	local InsertCombination = function(combination: {number})
		for i = 1, #combination do
			table.insert(return_array, combination[i])
		end
	end

	local TakeNextNumber = function(number: number)
		local combination = number_array[number]
		if combination == nil then
			combination = table.clone(last_combination)
			table.insert(combination, last_combination[1])
		end

		InsertCombination(combination)
		max_value += 1
		if max_value > MAX_AMOUNT_OF_ENTRIES then
			number_array = table.clone(NUMBER_ARRAY_2)
			last_combination = {combination[#combination]}
			max_value = 255
			return
		end
		local first_number = combination[1]
		number_array[max_value] = table.clone(last_combination)
		table.insert(number_array[max_value], first_number)
		last_combination = combination
	end
	

	for i = 2, #encoded_array do
		local value = encoded_array[i]
		TakeNextNumber(value)
	end
	return return_array
end

LZW.DecodeFromTextToText = function(encoded_text: string)
	local encoded_array = {}
	local text_buffer = buffer.fromstring(encoded_text)
	for i = 0, buffer.len(text_buffer) / BIT16_NUMBER_SIZE_BYTES - 1 do
		local number = buffer.readu16(text_buffer, i * BIT16_NUMBER_SIZE_BYTES)
		table.insert(encoded_array, number)
	end	

	local number_array = table.clone(NUMBER_ARRAY_2)

	local last_combination = number_array[encoded_array[1]]
	local return_array = table.clone(last_combination)
	local max_value = 255

	local InsertCombination = function(combination: {number})
		for i = 1, #combination do
			table.insert(return_array, combination[i])
		end
	end

	local TakeNextNumber = function(number: number)
		local combination = number_array[number]
		if combination == nil then
			combination = table.clone(last_combination)
			table.insert(combination, last_combination[1])
		end

		InsertCombination(combination)
		max_value += 1
		if max_value > MAX_AMOUNT_OF_ENTRIES then
			number_array = table.clone(NUMBER_ARRAY_2)
			last_combination = {combination[#combination]}
			max_value = 255
			return
		end
		local first_number = combination[1]
		number_array[max_value] = table.clone(last_combination)
		table.insert(number_array[max_value], first_number)
		last_combination = combination
	end

	for i = 2, #encoded_array do
		local value = encoded_array[i]
		TakeNextNumber(value)
	end
	
	local text_buffer = buffer.create(#return_array)
	for i = 0, #return_array - 1 do
		local number = return_array[i + 1]
		buffer.writeu8(text_buffer, i, number)
	end
	return buffer.tostring(text_buffer)
end

return LZW
