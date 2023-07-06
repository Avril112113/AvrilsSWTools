---@class Matrix33
---@section Matrix33 1 _Matrix33_
Matrix33 = {
	---@overload fun(self, matrix:Matrix33):Matrix33
	---@return Matrix33
	---@param ... (LBVec|number)
	---@nodiscard
	new = function(self, ...)
		local input = {...}
		local matrix = {}
		if #input > 0 and #input[1] == 9 then
			---@cast input Matrix33[]
			matrix = input[1]
		else
			for i=1,3 do
				for j=1,3 do
					matrix[(i-1)*3+j] = input[i] and (input[i][j] or input[i][({"x", "y", "z"})[j]]) or 0
				end
			end
		end
		return LifeBoatAPI.lb_copy(self, matrix)
	end,

	---@nodiscard
	M = function(self, x, y)
		return self[(x-1)*3+y]
	end,
	Ms = function(self, x, y, value)
		self[(x-1)*3+y] = value
	end,

	---@section Matrix33_identity 1
	---@return Matrix33
	---@nodiscard
	Matrix33_identity = function(self)
		local matrix = Matrix33:new()
		for i=1,3 do
			matrix:Ms(i, i, 1)
		end
		return matrix
	end,
	---@endsection

	---@section Matrix33_fromEuler
	---@param euler LBVec
	---@return Matrix33
	---@nodiscard
	Matrix33_fromEuler = function(self, euler)
		local a = euler.x
		local b = euler.y
		local y = euler.z
		return Matrix33:new({
			math.cos(b)*math.cos(y), math.cos(b)*math.sin(y), -math.sin(b),
			math.sin(a)*math.sin(b)*math.cos(y)-math.cos(a)*math.sin(y), math.sin(a)*math.sin(b)*math.sin(y)+math.cos(a)*math.cos(y), math.sin(a)*math.cos(b),
			math.cos(a)*math.sin(b)*math.cos(y)+math.sin(a)*math.sin(y), math.cos(a)*math.sin(b)*math.sin(y)-math.sin(a)*math.cos(y), math.cos(a)*math.cos(b)
		})
	end,
	---@endsection

	---@section Matrix33_fromOrientation
	---@param yaw number
	---@param pitch number
	---@param roll number
	---@return Matrix33
	---@nodiscard
	Matrix33_fromOrientation = function(self, yaw, pitch, roll)
		-- yaw, pitch, roll -> Quaternion
		local sr, cr, sp, cp, sy, cy =
		math.sin(roll * 0.5),
		math.cos(roll * 0.5),
		math.sin(pitch * 0.5),
		math.cos(pitch * 0.5),
		math.sin(yaw * 0.5),
		math.cos(yaw * 0.5)
		local q = {
			X = cy * sp * cr + sy * cp * sr,
			Y = sy * cp * cr - cy * sp * sr,
			Z = cy * cp * sr - sy * sp * cr,
			W = cy * cp * cr + sy * sp * sr
		}

		-- Quaternion -> Matrix
		local xx = q.X ^ 2
		local yy = q.Y ^ 2
		local zz = q.Z ^ 2
		local xy = q.X * q.Y
		local wz = q.Z * q.W
		local xz = q.Z * q.X
		local wy = q.Y * q.W
		local yz = q.Y * q.Z
		local wx = q.X * q.W
		return Matrix33:new({
			1 - 2 * (yy + zz),	2 * (xy + wz),		2 * (xz - wy),
			2 * (xy - wz),		1 - 2 * (zz + xx),	2 * (yz + wx),
			2 * (xz + wy),		2 * (yz - wx),		1 - 2 * (yy + xx)
		})
	end,
	---@endsection

	---@section Matrix33_mul
	---@param self Matrix33
	---@return Matrix33
	---@nodiscard
	Matrix33_mul = function(self, other)
		local matrix = {}

		local function calc(idx)
			local i = (idx-1)%3+1
			local j = math.floor((idx-1)/3)*3+1
			return (other[i]*self[j]) + (other[i+3]*self[j+1]) + (other[i+6]*self[j+2]) + (other[i+9]*self[j+3])
		end

		for i=1,9 do
			matrix[i] = calc(i)
		end

		return Matrix33:new(matrix)
	end,
	---@endsection

	---@section Matrix33_transpose
	---@return Matrix33
	---@nodiscard
	Matrix33_transpose = function(self)
		return Matrix33:new({
			self[1], self[4], self[7],
			self[2], self[5], self[8],
			self[3], self[6], self[9]
		})
	end,
	---@endsection

	---@section Matrix33_transform
	---@param vec LBVec
	---@return LBVec
	---@nodiscard
	Matrix33_transform = function(self, vec)
		return LBVec:new(
			(self[1]*vec.x) + (self[4]*vec.y) + (self[7]*vec.z),
			(self[2]*vec.x) + (self[5]*vec.y) + (self[8]*vec.z),
			(self[3]*vec.x) + (self[6]*vec.y) + (self[9]*vec.z)
		)
	end,
	---@endsection
}
---@endsection _Matrix33_
