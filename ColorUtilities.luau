--!native


function map(value, min, max, output_min, output_max, keepInRange)
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

local ColorUtilities = {}

ColorUtilities.UnpackPixel = function(color_number: number)
	local r = bit32.rshift(bit32.band(0x000000ff, color_number), 0)
	local g = bit32.rshift(bit32.band(0x0000ff00, color_number), 8)
	local b = bit32.rshift(bit32.band(0x00ff0000, color_number), 16)
	local a = bit32.rshift(bit32.band(0xff000000, color_number), 24)

	return r, g, b, a 
end

ColorUtilities.PackPixel = function(r: number, g: number, b: number, a: number)
	local r = bit32.band(0x000000ff, bit32.lshift(r, 0))
	local g = bit32.band(0x0000ff00, bit32.lshift(g, 8))
	local b = bit32.band(0x00ff0000, bit32.lshift(b, 16))
	local a = bit32.band(0xff000000, bit32.lshift(a, 24))

	return bit32.bor(r, g, b, a)
end

ColorUtilities.PackPixelWithHeight = function(R: number, G: number, B: number, H: number, max_depth: number)
	local r = bit32.band(0x000000ff, bit32.lshift(R, 0))
	local g = bit32.band(0x0000ff00, bit32.lshift(G, 8))
	local b = bit32.band(0x00ff0000, bit32.lshift(B, 16))

	local Height = map(H, 0, max_depth, 254, 0, true) // 1
	local h = bit32.band(0xff000000, bit32.lshift(Height, 24))

	return bit32.bor(r, g, b, h)
end

ColorUtilities.RGBToYCbCr = function(r: number, g: number, b: number)
	local Y = .299 * r + 0.587 * g + 0.114 * b
	local Cb = -.169 * r - .331 * g +.5 * b + 128
	local Cr = .5 * r - .419 * g - .081 * b + 128

	return Y // 1, Cb // 1, Cr // 1
end

ColorUtilities.YCbCrToRGB = function(y: number, cb: number, cr: number)
	cr -= 128
	cb -= 128

	local R = y + 45 * cr / 32
	local G = y - (11 * cb + 23 * cr) / 32
	local B = y + 113 * cb /64

	return R // 1, G // 1, B // 1
end

return ColorUtilities
