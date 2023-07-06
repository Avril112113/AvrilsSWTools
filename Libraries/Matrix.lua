---@class Matrix
---@section Matrix 1 _Matrix_
Matrix = {
	---@overload fun(self, matrix:Matrix):Matrix
	---@return Matrix
	---@param ... (LBVec|number)
	---@nodiscard
	new = function(self, ...)
		local input = {...}
		local matrix = {}
		if #input > 0 and #input[1] == 16 then
			---@cast input Matrix[]
			matrix = input[1]
		else
			for i=1,4 do
				for j=1,4 do
					matrix[(i-1)*4+j] = input[i] and (input[i][j] or input[i][({"x", "y", "z"})[j]]) or 0
				end
			end
		end
		return LifeBoatAPI.lb_copy(self, matrix)
	end,

	---@nodiscard
	M = function(self, x, y)
		return self[(x-1)*4+y]
	end,
	Ms = function(self, x, y, value)
		self[(x-1)*4+y] = value
	end,

	---@section Matrix_identity 1
	---@return Matrix
	---@nodiscard
	Matrix_identity = function(self)
		local matrix = Matrix:new()
		for i=1,4 do
			matrix:Ms(i, i, 1)
		end
		return matrix
	end,
	---@endsection

	---@section Matrix_projection
	---@return Matrix
	---@nodiscard
	Matrix_projection = function(self, fov, aspect, near, far)
		local yScale = 1.0 / math.tan(math.rad(fov/2))
		local xScale = yScale / aspect
		return Matrix:new({
			yScale, 0, 0, 0,
			0, xScale, 0, 0,
			0, 0, -far / (far - near), -1,
			0, 0, -far * near / (far - near), 0
		})
	end,
	---@endsection

	---@section Matrix_projectionComplex
	---@return Matrix
	---@nodiscard
	Matrix_projectionComplex = function(self, left, right, bottom, top, near, far)
		-- debug.log(("[SW-KR]  %.2f  %.2f  %.2f  %.2f"):format(left, right, bottom, top))
		return Matrix:new({
			2*near/(right-left),       0,                         0,                        0,
			0,                         2*near/(top-bottom),       0,                        0,
			(right+left)/(right-left), (top+bottom)/(top-bottom), -(far+near)/(far-near),  -1,
			0,                         0,                         -2*far*near/(far - near), 0
		})
	end,
	---@endsection

	---@section Matrix_fromEuler
	---@param euler LBVec
	---@return Matrix
	---@nodiscard
	Matrix_fromEuler = function(self, euler)
		local a = euler.x
		local b = euler.y
		local y = euler.z
		return Matrix:new({
			math.cos(b)*math.cos(y), math.cos(b)*math.sin(y), -math.sin(b), 0,
			math.sin(a)*math.sin(b)*math.cos(y)-math.cos(a)*math.sin(y), math.sin(a)*math.sin(b)*math.sin(y)+math.cos(a)*math.cos(y), math.sin(a)*math.cos(b), 0,
			math.cos(a)*math.sin(b)*math.cos(y)+math.sin(a)*math.sin(y), math.cos(a)*math.sin(b)*math.sin(y)-math.sin(a)*math.cos(y), math.cos(a)*math.cos(b), 0,
			0, 0, 0, 1
		})
	end,
	---@endsection

	---@section Matrix_fromOrientation
	---@param yaw number
	---@param pitch number
	---@param roll number
	---@return Matrix
	---@nodiscard
	Matrix_fromOrientation = function(self, yaw, pitch, roll)
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
		return Matrix:new({
			1 - 2 * (yy + zz),	2 * (xy + wz),		2 * (xz - wy),		0,
			2 * (xy - wz),		1 - 2 * (zz + xx),	2 * (yz + wx),		0,
			2 * (xz + wy),		2 * (yz - wx),		1 - 2 * (yy + xx),	0,
			0,					0,					0, 					1
		})
	end,
	---@endsection

	---@section Matrix_mul
	---@param self Matrix
	---@return Matrix
	---@nodiscard
	Matrix_mul = function(self, other)
		local matrix = {}

		local function calc(idx)
			local i = (idx-1)%4+1
			local j = math.floor((idx-1)/4)*4+1
			return (other[i]*self[j]) + (other[i+4]*self[j+1]) + (other[i+8]*self[j+2]) + (other[i+12]*self[j+3])
		end

		for i=1,16 do
			matrix[i] = calc(i)
		end

		return Matrix:new(matrix)
	end,
	---@endsection

	---@section Matrix_inverse
	---@return Matrix
	-- Matrix_inverse = function(self)
	-- 	local a, b, c, d = self:M(1, 1), self:M(1, 2), self:M(1, 3), self:M(1, 4)
	-- 	local e, f, g, h = self:M(2, 1), self:M(2, 2), self:M(2, 3), self:M(2, 4)
	-- 	local i, j, k, l = self:M(3, 1), self:M(3, 2), self:M(3, 3), self:M(3, 4)
	-- 	local m, n, o, p = self:M(4, 1), self:M(4, 2), self:M(4, 3), self:M(4, 4)

	-- 	local kp_lo = k * p - l * o
	-- 	local jp_ln = j * p - l * n
	-- 	local jo_kn = j * o - k * n
	-- 	local ip_lm = i * p - l * m
	-- 	local io_km = i * o - k * m
	-- 	local in_jm = i * n - j * m

	-- 	local a11 =  (f * kp_lo - g * jp_ln + h * jo_kn)
	-- 	local a12 = -(e * kp_lo - g * ip_lm + h * io_km)
	-- 	local a13 =  (e * jp_ln - f * ip_lm + h * in_jm)
	-- 	local a14 = -(e * jo_kn - f * io_km + g * in_jm)

	-- 	local det = a * a11 + b * a12 + c * a13 + d * a14

	-- 	if math.abs(det) < 1E-12 then
	-- 		print(math.abs(det))
	-- 		return nil
	-- 	end

	-- 	local invDet = 1 / det

	-- 	local gp_ho = g * p - h * o
	-- 	local fp_hn = f * p - h * n
	-- 	local fo_gn = f * o - g * n
	-- 	local ep_hm = e * p - h * m
	-- 	local eo_gm = e * o - g * m
	-- 	local en_fm = e * n - f * m
	-- 	local gl_hk = g * l - h * k
	-- 	local fl_hj = f * l - h * j
	-- 	local fk_gj = f * k - g * j
	-- 	local el_hi = e * l - h * i
	-- 	local ek_gi = e * k - g * i
	-- 	local ej_fi = e * j - f * i

	-- 	return Matrix:new({
	-- 		a11 * invDet, -(b * kp_lo - c * jp_ln + d * jo_kn) * invDet,  (b * gp_ho - c * fp_hn + d * fo_gn) * invDet, -(b * gl_hk - c * fl_hj + d * fk_gj) * invDet,
	-- 		a12 * invDet,  (a * kp_lo - c * ip_lm + d * io_km) * invDet, -(a * gp_ho - c * ep_hm + d * eo_gm) * invDet,  (a * gl_hk - c * el_hi + d * ek_gi) * invDet,
	-- 		a13 * invDet, -(a * jp_ln - b * ip_lm + d * in_jm) * invDet,  (a * fp_hn - b * ep_hm + d * en_fm) * invDet, -(a * fl_hj - b * el_hi + d * ej_fi) * invDet,
	-- 		a14 * invDet,  (a * jo_kn - b * io_km + c * in_jm) * invDet, -(a * fo_gn - b * eo_gm + c * en_fm) * invDet,  (a * fk_gj - b * ek_gi + c * ej_fi) * invDet
	-- 	})
	-- end,
	--- https://integratedmlai.com/matrixinverse/
	---@return Matrix
	---@nodiscard
	Matrix_inverse = function(self)
		-- Section 1: Make sure A can be inverted.
		-- check_squareness(A)
		-- check_non_singular(A)

		-- Section 2: Make copies of A & I, AM & IM, to use for row ops
		local AM = LifeBoatAPI.lb_copy(self)
		local IM = Matrix:Matrix_identity()

		-- Section 3: Perform row operations
		for fd=1,4 do  -- fd stands for focus diagonal
			local fdScaler = 1.0 / AM:M(fd, fd)
			-- FIRST: scale fd row with fd inverse. 
			for j=1,4 do  -- Use j to indicate column looping.
				AM:Ms(fd, j, AM:M(fd, j) * fdScaler)
				IM:Ms(fd, j, IM:M(fd, j) * fdScaler)
			end
			-- SECOND: operate on all rows except fd row as follows:
			for i=1,4 do
				-- *** skip row with fd in it.
				if i ~= fd then
					local crScaler = AM:M(i, fd)  -- cr stands for "current row".
					for j=1,4 do
						-- cr - crScaler * fdRow, but one element at a time.
						AM:Ms(i, j, AM:M(i, j) - crScaler * AM:M(fd, j))
						IM:Ms(i, j, IM:M(i, j) - crScaler * IM:M(fd, j))
					end
				end
			end
		end

		-- Section 4: Make sure IM is an inverse of A with specified tolerance
		-- if check_matrix_equality(Matrix:Matrix_identity(), matrix_multiply(A, IM), tol):
		-- 	return IM
		-- else
		-- 	return nil, "Matrix inverse out of tolerance."
		-- end

		return IM
	end,
	---@endsection

	---@section Matrix_transpose
	---@return Matrix
	---@nodiscard
	Matrix_transpose = function(self)
		return Matrix:new({
			self[1], self[5], self[9],  self[13],
			self[2], self[6], self[10], self[14],
			self[3], self[7], self[11], self[15],
			self[4], self[8], self[12], self[16]
		})
	end,
	---@endsection

	---@section Matrix_transform
	---@param vec LBVec
	---@return LBVec, number
	---@nodiscard
	Matrix_transform = function(self, vec)
		return LBVec:new(
			(self[1]*vec.x) + (self[5]*vec.y) + (self[ 9]*vec.z) + (self[13]),
			(self[2]*vec.x) + (self[6]*vec.y) + (self[10]*vec.z) + (self[14]),
			(self[3]*vec.x) + (self[7]*vec.y) + (self[11]*vec.z) + (self[15])
		), (self[4]*vec.x) + (self[8]*vec.y) + (self[12]*vec.z) + (self[16])
	end,
	---@endsection

	---@section Matrix_translate
	---@param self Matrix
	---@param vec LBVec
	---@return Matrix
	---@nodiscard
	Matrix_translate = function(self, vec)
		local matrix = LifeBoatAPI.lb_copy(self)
		matrix[13] = matrix[13] + vec.x
		matrix[14] = matrix[14] + vec.y
		matrix[15] = matrix[15] + vec.z
		return matrix
	end,
	---@endsection

	---@section Matrix_getTranslation
	---@return LBVec
	---@nodiscard
	Matrix_getTranslation = function(self)
		return LBVec:new(self[13], self[14], self[15])
	end,
	---@endsection

	---@section Matrix_scale
	---@param self Matrix
	---@param vec LBVec
	---@return Matrix
	---@nodiscard
	Matrix_scale = function(self, vec)
		local matrix = LifeBoatAPI.lb_copy(self)
		matrix[1] = matrix[1] + vec.x
		matrix[6] = matrix[6] + vec.y
		matrix[11] = matrix[11] + vec.z
		return Matrix:new(matrix)
	end,
	---@endsection

	---@section Matrix_getScale
	---@return LBVec
	---@nodiscard
	Matrix_getScale = function(self)
		return LBVec:new(self[1], self[6], self[11])
	end,
	---@endsection
}
---@endsection _Matrix_
