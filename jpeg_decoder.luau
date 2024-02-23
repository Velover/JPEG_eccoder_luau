--!native
--!optimize 2

local DrawUtilities = require(game.ReplicatedStorage:WaitForChild("DrawUtilities"))
local Huffman = require(game.ReplicatedStorage.Huffman)
local BinaryCompactor = require(game.ReplicatedStorage.Modules.BinaryCompactor)
local BinaryDecompactor = require(game.ReplicatedStorage.Modules.BinaryDecompactor)
local MatrixUtilities = require(game.ReplicatedStorage:WaitForChild("Modules"):WaitForChild("MatrixUtilities"))
local StringUtilities = require(game.ReplicatedStorage.Modules.StringUtilities)
local LZW = require(game.ReplicatedStorage.LZW)

local LUMINANCE_QUANTISATION_TABLE = { 
	{16, 11, 10, 16, 24, 40, 51, 61},
	{12, 12, 14, 19, 26, 58, 60, 55},
	{14, 13, 16, 24, 40, 57, 69, 56},
	{14, 17, 22, 29, 51, 87, 80, 62},
	{18, 22, 37, 56, 68, 109, 103, 77},
	{24, 35, 55, 64, 81, 104, 113, 92},
	{49, 64, 78, 87, 103, 121, 120, 101},
	{72, 92, 95, 98, 112, 100, 103, 99}
}

local CHROMINANCE_QUANTISATION_TABLE = {
	{17, 18, 24, 47, 99, 99, 99, 99},
	{18, 21, 26, 66, 99, 99, 99, 99},
	{24, 26, 56, 99, 99, 99, 99, 99},
	{47, 66, 99, 99, 99, 99, 99, 99},
	{99, 99, 99, 99, 99, 99, 99, 99},
	{99, 99, 99, 99, 99, 99, 99, 99},
	{99, 99, 99, 99, 99, 99, 99, 99},
	{99, 99, 99, 99, 99, 99, 99, 99}
}

local BLOCK_SIZE = 8
local HEADER_SIZE = 7 * 4
local INT32_SIZE_BYTES = 4
local INT16_SIZE_BYTES = 2
local JPEG_TAG = "JPG_"

local JPEG = {}

local TableToString = function(table: {number})
	local buffer_size = #table
	local text_buffer = buffer.create(buffer_size)
	for i = 0, buffer_size - 1 do
		buffer.writeu8(text_buffer, i , table[i + 1])
	end

	return buffer.tostring(text_buffer)
end

local DecodeHuffman = function(encoded_text: string, second_encoding: boolean?)
	local table = Huffman.DecodeInt(encoded_text)
	if not second_encoding then
		return table
	end
	
	return Huffman.DecodeInt(TableToString(table))
end

local DecodeNew = function(lzw_encoded_text: string)
	local encoded_text = LZW.DecodeFromTextToText(lzw_encoded_text)
	local table = Huffman.DecodeInt(encoded_text)

	return table
end

local DecodeData = function(data: {number}, 
	size_x: number, size_y: number, quantisation_table: {{number}}, luminance: boolean?)

	local original_size_x = size_x
	local original_size_y = size_y

	size_x = luminance and size_x or size_x // 2
	size_y = luminance and size_y or size_y // 2

	local blocks_x = math.ceil(size_x / BLOCK_SIZE)
	local blocks_y = math.ceil(size_y / BLOCK_SIZE)

	local image_size = Vector2.new(size_x, size_y)

	local blocks = {}
	local size_of_huffman = #data
	local start = os.clock()
	for i = 0, size_of_huffman / 64 - 1 do
		local block = {}
		for v = 1, 64 do
			table.insert(block, data[i * 64 + v])
		end

		local dct_matrix = MatrixUtilities.DiagonalArrayToMatrix(block, 8, 8)
		MatrixUtilities.Dequantize(dct_matrix, quantisation_table)
		local color_matrix = DrawUtilities.FromDST(dct_matrix)
		local color_data = DrawUtilities.MatrixToColor(color_matrix)

		table.insert(blocks, color_data)	
	end
	local time_dct = os.clock()
	print(string.format("%.3fs took to convert from DCT", time_dct - start))
	
	local start = os.clock()
	local color_component = {}

	for y = 0, blocks_y - 1 do
		for x = 0, blocks_x - 1 do
			local position = Vector2.new(x * BLOCK_SIZE, y * BLOCK_SIZE)
			local index = y * blocks_x + x
			local block = blocks[index + 1]		
			DrawUtilities.AddColor(color_component, image_size, position, block, Vector2.new(BLOCK_SIZE, BLOCK_SIZE))
		end
	end

	color_component = luminance and color_component or
		DrawUtilities.ScaleComponent(color_component, Vector2.new(size_x, size_y), Vector2.new(original_size_x, original_size_y), "Linear")
	
	local time_scale_and_assemble = os.clock()
	print(string.format("%.3fs took to scale and assemble", time_scale_and_assemble - start))
	return color_component	
end

JPEG.Decode = function(encoded_string: string)
	local start = os.clock()
	local text = StringUtilities.FromBase64(encoded_string)
	local time_base_64 = os.clock()
	print(string.format("%.3fs base64", time_base_64 - start))
	
	local start = os.clock()
	local header = text:sub(1, HEADER_SIZE)
	local tag = header:sub(1, 4)
	assert(tag == JPEG_TAG, "Wrong format")
	header = header:sub(5)
	local header_buffer = buffer.fromstring(header)	
	
	local second_encoding = buffer.readu32(header_buffer, 0) == 1 and true or false
	local size_x = buffer.readu16(header_buffer, 1 * INT32_SIZE_BYTES)
	local size_y = buffer.readu16(header_buffer, 1 * INT32_SIZE_BYTES + INT16_SIZE_BYTES)
	local multiplicator = buffer.readf32(header_buffer, 2 * INT32_SIZE_BYTES)
	local y_size = buffer.readu32(header_buffer, 3 * INT32_SIZE_BYTES)
	local cb_size = buffer.readu32(header_buffer, 4 * INT32_SIZE_BYTES)
	local cr_size = buffer.readu32(header_buffer, 5 * INT32_SIZE_BYTES)
	
	local luminance_quantization_table = table.clone(LUMINANCE_QUANTISATION_TABLE)
	local chrominance_quantization_table = table.clone(CHROMINANCE_QUANTISATION_TABLE)
	
	MatrixUtilities.MultiplyMatrix(luminance_quantization_table, multiplicator)
	MatrixUtilities.MultiplyMatrix(chrominance_quantization_table, multiplicator)
	text = text:sub(HEADER_SIZE + 1)
	
	print("-----------")
	print(tag)
	print(second_encoding)
	print(size_x)
	print(size_y)
	print(multiplicator)
	print(y_size)
	print(cb_size)
	print(cr_size)
	print(string.len(text))
	print("-----------")
	
	local time_header = os.clock()
	print(string.format("%.3fs header", time_header - start))
	
	local start = os.clock()
	local BLOCK_SIZE = 8
	local y_text = text:sub(1, y_size)
	local cb_text = text:sub(y_size + 1, y_size + cb_size)
	local cr_text = text:sub(y_size + cb_size + 1, y_size + cb_size + cr_size)
	local time_isolating_data = os.clock()
	print(string.format("%.3fs isolating data", time_isolating_data - start))
	
	local start = os.clock()
	local y_data = DecodeNew(y_text, second_encoding)
	local cb_data = DecodeNew(cb_text, second_encoding)
	local cr_data = DecodeNew(cr_text, second_encoding)
	local time_decode_huffman = os.clock()
	print(string.format("%.3fs huffman", time_decode_huffman - start))
	
	local start = os.clock()
	local y_color = DecodeData(y_data, size_x, size_y, luminance_quantization_table, true)
	local cb_color = DecodeData(cb_data, size_x, size_y, chrominance_quantization_table, false)
	local cr_color = DecodeData(cr_data, size_x, size_y, chrominance_quantization_table, false)
	local time_decode_data = os.clock()
	print(string.format("%.3fs decode_blocks", time_decode_data - start))
	
	local start = os.clock()
	local ycbcr_image = DrawUtilities.Compose(y_color, cb_color, cr_color)
	local alpha_data = table.create(size_x * size_y, 255)
	local rgba_image = DrawUtilities.YCbCrToRGBAInt(ycbcr_image, alpha_data, Vector2.new(size_x, size_y))
	DrawUtilities.ConvertToFloat(rgba_image)
	local time_color_decode = os.clock()
	print(string.format("%.3fs color_decode", time_color_decode - start))
	
	
	
	print(#rgba_image)
	return rgba_image, size_x, size_y
end

return JPEG
