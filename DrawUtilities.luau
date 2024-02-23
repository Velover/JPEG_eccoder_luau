--!optimize 2
--!native
local VectorUtilities = require(script.Parent:WaitForChild("VectorUtilities"))
local ColorUtilities = require(script.Parent:WaitForChild("Modules"):WaitForChild("ColorUtilities"))
local MatrixUtilities = require(game.ReplicatedStorage:WaitForChild("Modules"):WaitForChild("MatrixUtilities"))


local COMPONENT_INDEXES = {
	r = 1,
	g = 2,
	b = 3,
	a = 4
}

local LUMINANCE_QUANTASATION_TABLE = { 
	{16, 11, 10, 16, 24, 40, 51, 61},
	{12, 12, 14, 19, 26, 58, 60, 55},
	{14, 13, 16, 24, 40, 57, 69, 56},
	{14, 17, 22, 29, 51, 87, 80, 62},
	{18, 22, 37, 56, 68, 109, 103, 77},
	{24, 35, 55, 64, 81, 104, 113, 92},
	{49, 64, 78, 87, 103, 121, 120, 101},
	{72, 92, 95, 98, 112, 100, 103, 99}
}

local CHROMINANCE_QUANTASATION_TABLE = {
	{17, 18, 24, 47, 99, 99, 99, 99},
	{18, 21, 26, 66, 99, 99, 99, 99},
	{24, 26, 56, 99, 99, 99, 99, 99},
	{47, 66, 99, 99, 99, 99, 99, 99},
	{99, 99, 99, 99, 99, 99, 99, 99},
	{99, 99, 99, 99, 99, 99, 99, 99},
	{99, 99, 99, 99, 99, 99, 99, 99},
	{99, 99, 99, 99, 99, 99, 99, 99}
}

local INVERSE_255 = 1/255

local function map(value: number, min: number, max: number, output_min: number, output_max: number, keepInRange: boolean?) 
	--the most used and usefull function i've ever created, (JavaScript function) scales value to another range
	-- e.g   .5, 0, 1, 0, 100  -> 50 
	local difference = max - min
	local difference_output = output_max - output_min

	local coefficient = difference_output / difference

	local difference_value = value - min
	local output_value = output_min + difference_value * coefficient

	if keepInRange then
		output_value = math.clamp(output_value, math.min(output_max, output_min), math.max(output_max, output_min))
	end
	return output_value
end

local DrawUtilities = {}

DrawUtilities.CreateImageData = function(width: number, height: number, r: number, g: number, b: number, a: number)
	--creates the image table of one color 
	local image_table = {}
	
	--transparency = 0 - visible
	--alpha = 1 - visible
	for i = 0, width * height - 1 do
		table.insert(image_table, r)
		table.insert(image_table, g)
		table.insert(image_table, b)
		table.insert(image_table, a)
	end

	return image_table
end

DrawUtilities.DrawCircle = function(image_data: {number}, editable_image_size: Vector2, position: Vector2,
	radius: number,	red: number, green: number, blue: number, alpha: number)
	--just a simple recreation of a circle | analog EditableImage:DrawCircle
	--can be improved 
	--area of circle pi*r^2
	--area of sqaure = a^2
	--               a = 2*r
	--               r = a/2
	--as i belive you check a^2 - pi*a^2/4 pixels more -> a^2(1 - pi/4)
	-- ~21% pixels more
	local Size = Vector2.one * radius * 2

	local top_left_corner = position - Size / 2
	local bottom_right_corner = position + Size / 2

	for y = top_left_corner.Y, bottom_right_corner.Y - 1 do
		for x = top_left_corner.X, bottom_right_corner.X - 1 do
			if y < 0 or y >= editable_image_size.Y or 
				x < 0 or x >= editable_image_size.X
			then
				continue
			end

			local index = (y * editable_image_size.X + x) * 4

			local distance_x = x - position.X
			local distance_y = y - position.Y

			if distance_x * distance_x + distance_y * distance_y > radius * radius then
				continue
			end

			image_data[index + 1] = red
			image_data[index + 2] = green
			image_data[index + 3] = blue
			image_data[index + 4] = alpha			
		end
	end
	
	--automatically writes in the table
	--table is not cloned when passed to the function
end

DrawUtilities.DrawLineWithThicness = function(image_data: {number}, editable_image_size: Vector2, point1: Vector2, point2: Vector2,
	thickness: number, desnsity: number, quality: number, rounding: boolean,
	red: number, green: number, blue: number, alpha: number)	
	--the most efficient way to draw line with thickness
	
	--thickness in pixels
	--density the density of the starting points 0-1
	--quality the used to calculate the step for the vector 0-1
	-- 0 - fast
	-- 1 - slow
	--rounding round edges
	
	local pi_sqr = math.pi * math.pi
	local thickness_sqr = thickness * thickness
	local quater_thickness_sqr = thickness_sqr * .25
	
	local half_sqrt_2 = math.sqrt(2) / 2 --the smallest value that will fill every cell
	--steps over pixels with magnidude of sqrt(2)/2 -- half of the pixel diagonal PixelSize = (1, 1)
	-- can save upto 200 -- 300 ms on the large scale
	-- test with very thicc line
	
	local step_vector = map(desnsity, 0, 1, 5, half_sqrt_2, true) --spawns vectors on the line
	local step_pixel = map(quality, 0, 1, 5, half_sqrt_2, true) --offset applied to the vector to calculate the index
	
	local direction = (point2 - point1).Unit
	local length = (point2 - point1).Magnitude
	
	local left_direction = VectorUtilities.RotateVector2(direction, math.pi/2)
	local right_direction = VectorUtilities.RotateVector2(direction, -math.pi/2)
	local points = {}
	
	--calculates initial vector points that will fill up lines
	for i = -thickness / 2, thickness / 2, step_vector do
		local point = point1 + left_direction * i
		local k = nil
		local offset_distance = nil
		if rounding then
			local k = map(i*i, -quater_thickness_sqr, quater_thickness_sqr, 0, pi_sqr)
			offset_distance = math.sin(math.sqrt(k)) * thickness / 2 --makes round edges needs to be improved
			point -= direction * offset_distance
		end		
		table.insert(points, {{x = point.X, y = point.Y}, offset_distance or 0})
	end
	
	--drawing diagonal lines
	for _, point_turple in points do
		local position = point_turple[1]
		local offset_distance = point_turple[2]
		for i = 0, length + offset_distance * 2, step_pixel do
			--fast indexing using offset
			local pixel_position = {x = position.x + direction.X * i, y = position.y + direction.Y * i}
			--normal vector automatically calculates the sqrt -- we create our own to avoid addicional calculations
			--position + direction * i
			local x = math.floor(pixel_position.x)
			local y = math.floor(pixel_position.y)
			if y < 0 or y >= editable_image_size.Y or
				x < 0 or x >= editable_image_size.X
			then
				continue
			end
			local index = (y * editable_image_size.X + x) * 4
			
			image_data[index + 1] = red
			image_data[index + 2] = green
			image_data[index + 3] = blue
			image_data[index + 4] = alpha	
		end
	end
	
	--automatically writes in the table
	--table is not cloned when passed to the function
end

DrawUtilities.DrawTriangleSlow = function(image_data: {number}, editable_image_size: Vector2,
	vertex1: Vector2, vertex2: Vector2, vertex3: Vector2,
	red: number, green: number, blue: number, alpha: number
)	
	local vertices = {vertex1, vertex2, vertex3}
	table.sort(vertices, function(a0: Vector2, a1: Vector2): boolean 
		return a0.Y < a1.Y	
	end)
	vertex1 = vertices[1]
	vertex2 = vertices[2]
	vertex3 = vertices[3]
	
	local min_y = math.min(vertex1.Y, vertex2.Y, vertex3.Y)
	local min_x = math.min(vertex1.X, vertex2.X, vertex3.X)
	local max_y = math.max(vertex1.Y, vertex2.Y, vertex3.Y)
	local max_x = math.max(vertex1.X, vertex2.X, vertex3.X)

	local vertical_slope_1 = Vector2.new(vertex2.X - vertex1.X, vertex2.Y - vertex1.Y)
	local vertical_slope_2 = Vector2.new(vertex3.X - vertex1.X, vertex3.Y - vertex1.Y)
	
	for y = min_y, max_y do
		for x = min_x, max_x do
			
			if x >= editable_image_size.X or x < 0 or
				y >= editable_image_size.Y or y < 0 then
				continue
			end
			
			local q = {x = x - vertex1.X, y = y - vertex1.Y}
			
			local slope_product = vertical_slope_1.X * vertical_slope_2.Y - vertical_slope_1.Y * vertical_slope_2.X
			local s =  (q.x * vertical_slope_2.Y - q.y * vertical_slope_2.X) / slope_product
			local t = (vertical_slope_1.X * q.y - vertical_slope_1.Y * q.x) / slope_product

			if (s >= 0) and (t >= 0) and (s + t <= 1) then
				local index = (y * editable_image_size.X + x) * 4
				image_data[index + 1] = red
				image_data[index + 2] = green
				image_data[index + 3] = blue
				image_data[index + 4] = alpha
			end			
		end
	end
end

DrawUtilities.ExtractComponents = function(image_data: {number}, components: string)
	local indexes = {}
	for _, character in components:split("") do
		local index = COMPONENT_INDEXES[character]
		if index == nil then
			continue
		end
		table.insert(indexes, index)
	end
	
	local new_data = {}
	for i = 0, #image_data / 4 - 1 do
		local index = i * 4
		for _, component_index in indexes do
			table.insert(new_data, image_data[index + component_index])
		end
	end
	
	return new_data
end

DrawUtilities.ConvertToInt = function(image_data: {number})
	for i = 1, #image_data do
		local color = math.floor(image_data[i] * 255)
		image_data[i] = color
	end
end

DrawUtilities.ConvertToFloat = function(image_data: {number})
	for i = 1, #image_data do
		local color = image_data[i] * INVERSE_255
		image_data[i] = color
	end
end

DrawUtilities.ColorToMatrix = function(color_data: {number}, size: Vector2)
	local matrix = {}
	for y = 0, size.Y - 1 do
		local row = {}
		for x = 0, size.X - 1 do
			local index = y * size.X + x
			local color = color_data[index + 1]
			table.insert(row, color)
		end
		table.insert(matrix, row)
	end
	
	return matrix
end

DrawUtilities.ToDST = function(color_matrix: {{number}})
	local rows = #color_matrix
	local collums = #color_matrix[1]
	MatrixUtilities.OffsetMatrix(color_matrix, -128)
	local DST_matrix = MatrixUtilities.MatrixToDCT(color_matrix, rows, collums)
	return DST_matrix
end

DrawUtilities.FromDST = function(DTS_matrix: {{number}})
	local rows = #DTS_matrix
	local collums = #DTS_matrix[1]
	local color_matrix = MatrixUtilities.DCTToMatrix(DTS_matrix, rows, collums)
	MatrixUtilities.OffsetMatrix(color_matrix, 128)
	
	return color_matrix
end

DrawUtilities.MatrixToColor = function(matrix: {{number}})	
	local color_data = {}
	for _, row in matrix do
		for _, color in row do
			table.insert(color_data, color)
		end
	end
	
	return color_data
end

DrawUtilities.RGBToYCbCrInt = function(image_data: {number}, size: Vector2)	
	local YCbCr_image_data = {}
	
	for y = 0, size.Y - 1 do
		for x = 0, size.X - 1 do
			local index = (y * size.X + x) * 3
			local r = image_data[index + 1]
			local g = image_data[index + 2]
			local b = image_data[index + 3]
			
			local y, cb, cr = ColorUtilities.RGBToYCbCr(r, g, b)
			table.insert(YCbCr_image_data, y)
			table.insert(YCbCr_image_data, cb)
			table.insert(YCbCr_image_data, cr)
		end
	end
	
	return YCbCr_image_data
end

DrawUtilities.YCbCrToRGBInt = function(ycbcr_data: {number}, size: Vector2)
	local image_data = {}
	
	for y = 0, size.Y - 1 do
		for x = 0, size.X - 1 do
			local index = (y * size.X + x) * 3
			local y = ycbcr_data[index + 1]
			local cb = ycbcr_data[index + 2]
			local cr = ycbcr_data[index + 3]

			local r, g, b = ColorUtilities.YCbCrToRGB(y, cb, cr)
			table.insert(image_data, r)
			table.insert(image_data, g)
			table.insert(image_data, b)
		end
	end

	return image_data
end

DrawUtilities.YCbCrToRGBAInt = function(ycbcr_data: {number}, alpha_data: {number}, size: Vector2)
	local image_data = {}

	for y = 0, size.Y - 1 do
		for x = 0, size.X - 1 do
			local index = (y * size.X + x) * 3
			local alpha = alpha_data[y * size.X + x + 1]
			
			local y = ycbcr_data[index + 1]
			local cb = ycbcr_data[index + 2]
			local cr = ycbcr_data[index + 3]

			local r, g, b = ColorUtilities.YCbCrToRGB(y, cb, cr)
			table.insert(image_data, r)
			table.insert(image_data, g)
			table.insert(image_data, b)
			table.insert(image_data, alpha)
		end
	end

	return image_data
end

DrawUtilities.Decompose = function(image_data: {number}, amount_of_components: number)
	local components = {}
	for v = 1, amount_of_components do
		table.insert(components, {})
	end
	
	for i = 0, #image_data / amount_of_components - 1 do
		local index = i * amount_of_components
		for component_index = 1, amount_of_components do
			local component = components[component_index]
			local color = image_data[index + component_index]
			table.insert(component, color)
		end
	end
	
	return components
end

DrawUtilities.Compose = function(...: {number})
	local components = {...}
	local image_data = {}
	
	local size = #components[1]
	for i = 1, size do
		for _, component in components do
			table.insert(image_data, component[i])
		end
	end 
	
	return image_data
end

DrawUtilities.WriteImage = function(EditableImage: EditableImage, image_data: {number})
	EditableImage:WritePixels(Vector2.zero, EditableImage.Size, image_data)
end

DrawUtilities.AddImage = function(image_data: {number}, editable_image_size: Vector2, position: Vector2, image_data_2: {number}, size: Vector2)
	for y = 0, size.Y - 1 do
		for x = 0, size.X - 1 do
			local local_index = (y * size.X + x) * 4
			local global_y = y + position.Y
			local global_x = x + position.X
			local _r = image_data_2[local_index + 1]
			local _g = image_data_2[local_index + 2]
			local _b = image_data_2[local_index + 3]
			local _a = image_data_2[local_index + 4]
			
			if global_y >= editable_image_size.Y or global_y < 0 or
				global_x >= editable_image_size.X or global_x < 0 then
				continue
			end
			
			local global_index = (global_y * editable_image_size.X + global_x) * 4
			image_data[global_index + 1] = _r
			image_data[global_index + 2] = _g
			image_data[global_index + 3] = _b
			image_data[global_index + 4] = _a
		end
	end
end

DrawUtilities.AddColor = function(color_data: {number}, editable_image_size: Vector2, position: Vector2, color_data_2: {number}, size: Vector2)
	for y = 0, size.Y - 1 do
		for x = 0, size.X - 1 do
			local local_index = (y * size.X + x)
			local global_y = y + position.Y
			local global_x = x + position.X
			local color = color_data_2[local_index + 1]

			if global_y >= editable_image_size.Y or global_y < 0 or
				global_x >= editable_image_size.X or global_x < 0 then
				continue
			end

			local global_index = (global_y * editable_image_size.X + global_x)
			color_data[global_index + 1] = color
		end
	end
end

DrawUtilities.SplitComponentWithFill = function(color_data: {number}, original_size: Vector2, width: number, height: number, default_value: number?)
	--splits image into tiles of the size
	--can be used for animation sheets

	local blocks = {}
	local awaible_height = original_size.Y
	for y = 0, original_size.Y - 1, height do
		local awaible_width = original_size.X
		for x = 0, original_size.X - 1, width do
			local block = {}
			for v = 0, height - 1 do
				for u = 0, width - 1 do
					local index = ((y + v) * original_size.X + (x + u))
					local color = color_data[index + 1]
					table.insert(block, color or default_value or 0)
				end
			end
			table.insert(blocks, block)
			awaible_width -= width
		end
		awaible_height -= height
	end
	return blocks
end

DrawUtilities.SplitWithFill = function(image_data: {number}, image_size: Vector2, width: number, height: number)
	--splits image into tiles of the size
	--can be used for animation sheets

	local images = {}
	local awaible_height = image_size.Y
	for y = 0, image_size.Y - 1, height do
		local awaible_width = image_size.X
		for x = 0, image_size.X - 1, width do
			local image = {}
			for v = 0, height - 1 do
				for u = 0, width - 1 do
					local index = ((y + v) * image_size.X + (x + u)) * 4
					local red = image_data[index + 1]
					local green, blue, alpha
					if red ~= nil then
						green = image_data[index + 2]
						blue = image_data[index + 3]
						alpha = image_data[index + 4]
					else
						red, green, blue, alpha = 0, 0, 0, 1
					end
					
					table.insert(image, red)
					table.insert(image, green)
					table.insert(image, blue)
					table.insert(image, alpha)
				end
			end
			table.insert(images, image)
			awaible_width -= width
		end
		awaible_height -= height
	end
	return images
end

DrawUtilities.Split = function(image_data: {number}, image_size: Vector2, width: number, height: number)
	--splits image into tiles of the size
	--can be used for animation sheets
	
	local images = {}
	local awaible_height = image_size.Y
	for y = 0, image_size.Y - 1, height do
		local awaible_width = image_size.X
		for x = 0, image_size.X - 1, width do
			local image = {}
			for v = 0, math.min(height, awaible_height) - 1 do
				for u = 0, math.min(width, awaible_width) - 1 do
					local index = ((y + v) * image_size.X + (x + u)) * 4
					local red = image_data[index + 1]
					local green = image_data[index + 2]
					local blue = image_data[index + 3]
					local alpha = image_data[index + 4]
					table.insert(image, red)
					table.insert(image, green)
					table.insert(image, blue)
					table.insert(image, alpha)
				end
			end
			table.insert(images, image)
			awaible_width -= width
		end
		awaible_height -= height
	end
	return images
end

DrawUtilities.ScaleComponent = function(_color_data: {number}, _image_size: Vector2,
	desired_size: Vector2, mode: "Linear" | "Bilinear")
	desired_size = VectorUtilities.ClampVector2(desired_size, 1 --[[cannot / 0]], 1024)
	local width = desired_size.X
	local height = desired_size.Y
	local coefizient = _image_size / desired_size -- Vector2

	local image_data = {}

	if mode == "Bilinear" then
		mode = "Linear"
		warn("Biliniear is not awaible yes")
	end

	if mode == "Linear" then
		for y = 0, height - 1 do
			for x = 0, width - 1 do
				local _y = math.floor(y * coefizient.Y)
				local _x = math.floor(x * coefizient.X)
				local _index = (_y * _image_size.X + _x)

				local color = _color_data[_index + 1]
				table.insert(image_data, color)
			end
		end
		----------------
	end

	return image_data
end


DrawUtilities.ScaleImage = function(_image_data: {number}, _image_size: Vector2,
	desired_size: Vector2, mode: "Linear" | "Bilinear")
	desired_size = VectorUtilities.ClampVector2(desired_size, 1 --[[cannot / 0]], 1024)
	local width = desired_size.X
	local height = desired_size.Y
	local coefizient = _image_size / desired_size -- Vector2
	
	local image_data = {}
	
	if mode == "Bilinear" then
		mode = "Linear"
		warn("Biliniear is not awaible yes")
	end
	
	if mode == "Linear" then
		for y = 0, height - 1 do
			for x = 0, width - 1 do
				local _y = math.floor(y * coefizient.Y) --point on editable image
				local _x = math.floor(x * coefizient.X) --point on editable image
				local _index = (_y * _image_size.X + _x) * 4
				
				local _r = _image_data[_index + 1] --colors on editable image
				local _g = _image_data[_index + 2]
				local _b = _image_data[_index + 3]
				local _a = _image_data[_index + 4]
				
				table.insert(image_data, _r)
				table.insert(image_data, _g)
				table.insert(image_data, _b)
				table.insert(image_data, _a)
			end
		end
		----------------
	end
	
	return image_data
end



return DrawUtilities
