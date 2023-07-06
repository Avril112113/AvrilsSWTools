do
	local x, y = 0, 0

	function Debug_set(nx, ny)
		x, y = nx or 0, ny or 0
	end

	function Debug_lf()
		y = y + 8
	end

	function Debug_text(text)
		screen.drawText(x, y, text)
		Debug_lf()
	end

	---@section Debug_fmt
	function Debug_fmt(fmt, ...)
		Debug_text(fmt:format(...))
	end
	---@endsection

	---@section Debug_vec
	function Debug_vec(name, v, p)
		p=p or 2
		Debug_text(name .. (": %."..p.."f, %."..p.."f, %."..p.."f"):format(v.x, v.y, v.z))
	end
	---@endsection

	---@section Debug_matrix
	function Debug_matrix(name, m, p)
		p=p or 2
		for i=1,16,4 do
			Debug_text((i==1 and (name..": ") or string.rep(" ", #name+2)) .. ("%."..p.."f %."..p.."f %."..p.."f %."..p.."f"):format(m[i], m[i+1], m[i+2], m[i+3]))
		end
	end
	---@endsection
end