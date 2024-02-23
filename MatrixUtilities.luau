--!native
--!optimize 2
local MatrixUtilities = {}
local inverse_sqrt_2 = 1/math.sqrt(2)
local quater = 1/4 --[[2 / math.sqrt(N * P)]]

local c = function(x: number)
	return x== 0 and inverse_sqrt_2 or 1
end

local CosineProduct = function(m: number, n: number, x: number, y: number, M: number, N: number)
	return math.cos((2*x + 1) * m * math.pi / (2 * M)) * math.cos((2*y + 1) * n * math.pi / (2 * N))		
end

local ToDCT = function(matrix: {{number}}, N: number, P: number, u: number, v: number)
	--[[N - collums, P - rows]]
	--[[v - y, u - x]]
	--[[2 / math.sqrt(N * P)]]
	local g = quater * c(u) * c(v) --[[Magic ***]]
	local summ = 0
	for n = 0, N - 1 do --[[y]]
		for p = 0, P - 1 do --[[x]]		
			local cosine_product = math.cos((2*n + 1) * u * math.pi / (2 * N)) * math.cos((2*p + 1) * v * math.pi / (2 * P))
			summ += matrix[p+1][n+1] * cosine_product
		end
	end

	return g * summ
end

local FromDCT = function(matrix: {{number}}, M: number, N: number, x: number, y: number)
	--[[N - collums, P - rows]]
	--[[v - y, u - x]]
	local summ = 0
	for m = 0, M - 1 do --[[y]]
		for n = 0, N - 1 do --[[x]]
			local cosine_product = math.cos((2*x + 1) * m * math.pi / (2 * M)) * math.cos((2*y + 1) * n * math.pi / (2 * N))		
			summ +=  matrix[m+1][n+1] * c(m) * c(n) * cosine_product
		end
	end

	return quater * summ
end 

MatrixUtilities.MatrixToDCT = function(matrix: {{number}}, rows: number, collums: number)
	local N = collums
	local P = rows

	local new_matrix = {}
	for i = 1, rows do
		table.insert(new_matrix, table.create(collums, 0))
	end

	for v = 0, rows - 1 do
		for u = 0, collums - 1 do
			new_matrix[v+1][u+1] = ToDCT(matrix, N, P, u, v)
		end
	end

	return new_matrix
end

MatrixUtilities.DCTToMatrix = function(dct_matrix: {{number}}, rows: number, collums: number)
	local N = collums
	local P = rows

	local new_matrix = {}
	for i = 1, rows do
		table.insert(new_matrix, table.create(collums, 0))
	end

	for v = 0, rows - 1 do
		for u = 0, collums - 1 do
			new_matrix[u+1][v+1] = FromDCT(dct_matrix, N, P, u, v)
		end
	end

	return new_matrix
end

local Quantize = function(value: number, dividor: number)
	return value // dividor
end

MatrixUtilities.Quantize = function(martix: {{number}}, quantisation_table: {{number}})
	for y, row in martix do
		for x, value in row do
			local divisor = quantisation_table[y][x]
			martix[y][x] = math.round(value / divisor)
		end
	end
end

MatrixUtilities.Dequantize = function(martix: {{number}}, quantisation_table: {{number}})
	for y, row in martix do
		for x, value in row do
			local divisor = quantisation_table[y][x]
			martix[y][x] = value * divisor
		end
	end
end


MatrixUtilities.OffsetMatrix = function(matrix: {{number}}, offset: number)
	for y, row in matrix do
		for x, color in row do
			matrix[y][x] = color + offset
		end
	end
end

MatrixUtilities.RoundMatrix = function(matrix: {{number}})
	for y, row in matrix do
		for x, color in row do
			matrix[y][x] = math.round(color)
		end
	end
end

MatrixUtilities.MultiplyMatrix = function(matrix: {{number}}, multiplier: number)
	for y, row in matrix do
		for x, color in row do
			matrix[y][x] = color * multiplier
		end
	end
end

MatrixUtilities.MatrixToDiagonalArray = function(matrix: {{number}})
	local rows = #matrix
	local collums = #matrix[1]
	local diagonal_data = {}

	for line = 1, rows + collums - 1 do
		local start_collumn = math.max(0, line - rows)
		local count = math.min(line, (collums - start_collumn), rows)
		for j = 0, count - 1 do
			local value = matrix[math.min(rows, line) - j - 1 + 1][start_collumn + j + 1]
			table.insert(diagonal_data, value)
		end
	end

	return diagonal_data
end

MatrixUtilities.DiagonalArrayToMatrix = function(diagonal_array: {number}, rows: number, collums: number)
	local matrix = {}
	for i = 1, rows do
		table.insert(matrix, {})
	end

	for line = 1, rows + collums - 1 do
		local start_collumn = math.max(0, line - rows)
		local count = math.min(line, (collums - start_collumn), rows)
		for j = 0, count - 1 do
			local y = math.min(rows, line) - j - 1 + 1
			local x = start_collumn + j + 1
			local value = table.remove(diagonal_array, 1)

			matrix[y][x] = value
		end
	end

	return matrix
end

MatrixUtilities.Print2DMatrix = function(matrix: {{number}})
	local text = "\n"
	for _, row in matrix do
		for _, value in row do
			text ..= value.. ", "
		end
		text ..= "\n"
	end

	print(text)
end

--local Matrix = {
--	{-66, -73, -73, -74, -79, -80, -81, -73},
--	{-66, -71, -74, -76, -80, -81, -80, -75},
--	{-67, -68, -76, -79, -80, -81, -79, -74},
--	{-65, -67, -68, -68, -65, -63, -60, -63},
--	{-61, -61, -58, -54, -49, -43, -37, -36},
--	{-46, -33, -27, -22, -14, -13, -16, -11},
--	{-32, -17, -13, - 9,   0,   0,   2, - 1},
--	{-19, - 7, - 1,   5,  11,  13,  12,   5}
--}

--local Test_Matrix = {
--	{-368, -24,  0, 0, 0, 0, 0, 0},
--	{-231, 48, 26, 0, 0, 0, 0, 0},
--	{  60,  14,  0, 0, 0, 0, 0, 0},
--	{  16, -19,  0, 0, 0, 0, 0, 0},
--	{   0,   0,  0, 0, 0, 0, 0, 0},
--	{   0,   0,  0, 0, 0, 0, 0, 0},
--	{   0,   0,  0, 0, 0, 0, 0, 0},
--	{   0,   0,  0, 0, 0, 0, 0, 0},
--}

--Print2DMatrix(MatrixToDCT(Matrix, 8, 8))

return MatrixUtilities
