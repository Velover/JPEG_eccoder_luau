--!native
--!optimize 2
local BinaryCompactor = require(game.ReplicatedStorage:WaitForChild("Modules"):WaitForChild("BinaryCompactor"))
local BinaryDecompactor = require(game.ReplicatedStorage:WaitForChild("Modules"):WaitForChild("BinaryDecompactor"))
local BIT_31_NUMBER = 2147483648
local BIT_15_NUMBER = 32768

local Huffman = {}

Huffman.ToHuffmanTable = function(data_table: {any})
	local quantities = {}
	
	--save amount of elements
	for _, value in data_table do
		quantities[value] = (quantities[value] or 0) + 1
	end
	
	--each element and amount save in the branch
	local branches = {}
	local data = {}
	for value, quantity in quantities do
		--parent + path to avoid recursing
		local branch = {q = quantity, value = value, path = nil, parent = nil}
		--put branch to other branches
		table.insert(branches, branch)
		--save original to table for path reconstructing
		table.insert(data, branch)
	end
	
	--if only 1 element return premade huffman table
	if #data == 1 then
		return {
			[0] = {
				value = data[1].value,
				path_length = 1
			}
		}
	end
	
	--sort by amount
	table.sort(branches, function(a0: { q: number, value: number, path: nil, parent: nil}, a1: { q: number, value: number, path: nil, parent: nil}): boolean 
		return a0.q < a1.q
	end)
	
	while #branches ~= 1 do
		--joining two braches together to form new
		local branch_1 = table.remove(branches, 1)
		local branch_2 = table.remove(branches, 1)
		
		--saving direction for reconsruction of path
		branch_1.path = 0
		branch_2.path = 1
		
		local branch = {q = branch_1.q + branch_2.q, value = {branch_1, branch_2}}
		--saving the parent to avoid recursing and to reconstruct the path
		branch_1.parent = branch
		branch_2.parent = branch
		
		local branches_size = #branches
		--check amount of branches and insert last branch
		if branches_size == 0 then
			table.insert(branches, branch)
			break
		end
		
		--to avoid sorting branches, searching the index of the bigger branch and inserting before it
		for i = 1, branches_size do --sorting
			local comparison_branch = branches[i]
			if comparison_branch.q <= branch.q and i ~= branches_size then
				continue
			end
			--insert branch in the right place
			table.insert(branches, i, branch)
			break
		end
	end
	

	local huffman_table = {}
	--reconstructing path for each value
	for _, child in data do
		child.string_path = ""
		local current_value = child
		while current_value.parent ~= nil do
			--reconstructing path
			--converting binary bits to string "0", "1"
			child.string_path ..= current_value.path
			--changing current value to parent
			--take path of the parrent and concat with first path
			current_value = current_value.parent
		end
		
		--converting path to number
		local path_number = tonumber(child.string_path, 2):: number
		--saving amount of bits for each path
		local path_length = string.len(child.string_path)
		--creating huffman table
		huffman_table[path_number] = {value = child.value, path_length = path_length}
	end
	
	return huffman_table
end

Huffman.EncodeInt = function(data: {number}, huffman_table: {[number]: {value: number, path_length: number}}?)
	local huffman_table: {[number]: {value: number, path_length: number}}
		= huffman_table or Huffman.ToHuffmanTable(data) 
	
	local compactor = BinaryCompactor.New()
	local path_total_length = 0
	local huffman_table_size = 0
	
	local reconstructed_huffman_table = {}
	for path, value_tuple in huffman_table do
		--counting amount of elements
		huffman_table_size += 1
		
		--reconstructing the table with value as an index
		local value = value_tuple.value
		local path_length = value_tuple.path_length
		local path_tuple = {
			path = path,
			path_length = path_length
		}
		reconstructed_huffman_table[value] = path_tuple 
	end

	for _, value in data do
		--search for the path_tuple using value
		local path_tuple = reconstructed_huffman_table[value]
		--counting the total amount of bits of path
		path_total_length += path_tuple.path_length
	end
	
	--full length of the path as U_INT32 
	BinaryCompactor.Add(compactor, path_total_length, 32)
	--size of huffman table as U_INT16
	BinaryCompactor.Add(compactor, huffman_table_size, 32)
	
	--saving huffman table
	for path, value_tuple in huffman_table do
		local path_length = value_tuple.path_length
		local value = value_tuple.value
		--value INT_16 -> U_INT16
		BinaryCompactor.Add(compactor, value + BIT_15_NUMBER, 16) --sighned short int
		--path_length U_INT32
		BinaryCompactor.Add(compactor, path_length, 32)
		--path INT(path_length)
		--e.g 3, 15 -> 1100 0000 0000 000
		BinaryCompactor.Add(compactor, path, path_length)
	end
	
	--saving binary path
	for index, value in data do
		--extracting path_tuple from reconstructed_huffman_table
		local path_tuple = reconstructed_huffman_table[value]
		local path = path_tuple.path
		local path_length = path_tuple.path_length
		--compacting binary
		BinaryCompactor.Add(compactor, path, path_length)
	end
	
	--converting to the string
	return BinaryCompactor.Finish(compactor)
end

Huffman.DecodeInt = function(encoded_string: string)
	local decompactor = BinaryDecompactor.New(encoded_string)
	
	--path length U_INT32
	local path_total_length = BinaryDecompactor.ReadBits(decompactor, 32)
	--huffman table size U_INT16
	local huffman_table_size = BinaryDecompactor.ReadBits(decompactor, 32)
	
	--recreating huffman table
	local modified_huffman_table = {}
	for i = 1, huffman_table_size do
		--value U_INT16 -> INT16
		local value = BinaryDecompactor.ReadBits(decompactor, 16) - BIT_15_NUMBER
		--path length U_INT32
		local path_length = BinaryDecompactor.ReadBits(decompactor, 32)
		--path INT(path_length)
		local path = BinaryDecompactor.ReadBits(decompactor, path_length)
		--sorting values by path_size and then by value
		--path 0 can have 3bit -> 000
		--for optimized sorting
		--{size = {
		--  	path = value 
		--	}
		--}
		if modified_huffman_table[path_length] == nil then
			modified_huffman_table[path_length] = {}
		end
		local value_tuple = modified_huffman_table[path_length]
		value_tuple[path] = value
	end
	
	

	local data = {}
	local current_path_length = 0
	local current_path = 0
	for i = 1, path_total_length do
		--read bit and saving to the current path
		local bit = BinaryDecompactor.ReadBits(decompactor, 1)
		current_path = bit32.replace(current_path, bit, current_path_length, 1)
		current_path_length += 1
		
		--searching for the size branch
		--modified huffman table structure
		--{size = {
		--  	path = value 
		--	}
		--}
		if modified_huffman_table[current_path_length] == nil then
			continue
		end
		
		--checking for value
		local value = modified_huffman_table[current_path_length][current_path]
		if value == nil then
			continue
		end
		--reseting if found value
		current_path_length = 0
		current_path = 0
		
		--inserting value if found
		table.insert(data, value)
	end

	return data
end

return Huffman
