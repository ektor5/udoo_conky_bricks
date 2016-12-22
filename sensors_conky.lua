-- #!/usr/bin/lua
do
	local interval = 5 
	-- local variables protected from the evil outside world
	local next_update
	local buf 
	local int = 0
	local colour = 0
	local function update_buf()
		buf = os.time()
	end

	local sens_path="/sys/module/hwmon/holders/si70xx/drivers/i2c\:si70xx/"

	function scandir(directory)
		local i, t, popen = 0, {}, io.popen
		local pfile = popen('find "'..directory..'" -maxdepth 1 -name [0-9]*')
		for filename in pfile:lines() do
			i = i + 1
			t[i] = filename
		end
		pfile:close()
		return t
	end
	

	function conky_gen_widget(xmax,ymax)
		-- generate all widgets
		local xglobaloff = 20
		local table = ""
		local yoff = 58
		local xoff = -6
		local col = 3
		local row = 6
		local wheight = 73

		local head = "${color grey}"

		local e = scandir(sens_path)

		for index,dir in ipairs(e) do
			-- column index
			local i = index - 1
			local sensor = string.match(dir,"[0-9]*-%d*")
			local sens_col = math.floor( i / row )
			local sens_row = ( i % row )
			-- widget width
			local wwidth = math.floor( xmax / col )

			local xgoto = wwidth * sens_col + xglobaloff
			local ygoto = math.floor( row * wheight )

			local bg_xoff = xgoto + xoff
			local bg_yoff = math.floor( yoff + wheight * sens_row )
			local bg_width = wwidth + xoff
			local bg_height = wheight + 4

			local img_xoff = bg_xoff + 15
			local img_yoff = bg_yoff + 35
			local img_width = 13
			local img_height = 13

			local function tabr(width)
				return "${alignr "..xmax-xgoto -wwidth*(sens_col+1).." }"
			end
			local function tab(width)
				return "${goto "..width+xgoto.." }"
			end
 
			-- set vertical offset
			if ( sens_row == 0 and i ~= 0 )  then
				table = table .. "${voffset -"..ygoto.."}"
			end

			local nhead = head .."${goto "..xgoto.."}"
			table = table ..nhead.. tab(15) .. "${color orange}Brick " .. index .. " ( " .. sensor .. " )${voffset 5} \n"
			table = table ..nhead.. tab(35) .. "Temp:"..tab(wwidth*0.7).."${i2c " .. sensor .. " temp 1}°C \n"
			table = table ..nhead.. tab(35) .. "Hum:" ..tab(wwidth*0.7).."${i2c " .. sensor .. " humidity 1 0.001 0.0 } % \n"
			table = table .. "${image ~/.config/conky/base.png -p ".. bg_xoff ..","..bg_yoff.." -s "..bg_width.."x"..bg_height.."}"
			table = table .. "${image ~/.config/conky/temp.png -p ".. img_xoff ..",".. img_yoff.." -s "..img_width.."x"..img_height.."}"
			table = table .. "${image ~/.config/conky/hum.png -p  ".. img_xoff ..",".. img_yoff+17 .." -s "..img_width.."x"..img_height.."} \n"

		end
		return table 
	end

	function conky_string_func()
		local now = os.time()

		if next_update == nil or now >= next_update then
			update_buf();
			next_update = now + interval
		end
		colour = colour + 11100
		
		return string.format("${color #%06x}The time is now ", colour%0xffffff) .. tostring(buf) .. "${color}"
	end	

	-- this function changes Conky's top colour based on a threshold
	function conky_top_colour(value, default_colour, upper_thresh, lower_thresh)
		local r, g, b = default_colour, default_colour, default_colour
		local colour = 0
		-- in my case, there are 4 CPUs so a typical high value starts at around ~20%, and 25% is one thread/process maxed out
		local thresh_diff = upper_thresh - lower_thresh
		if (value - lower_thresh) > 0 then
			if value > upper_thresh then value = upper_thresh end
			-- add some redness, depending on the 'strength'
			r = math.ceil(default_colour + ((value - lower_thresh) / thresh_diff) * (0xff - default_colour))
			b = math.floor(default_colour - ((value - lower_thresh) / thresh_diff) * default_colour)
			g = b
		end
		colour = (r * 0x10000) + (g * 0x100) + b -- no bit shifting operator in Lua afaik

		return string.format("${color #%06x}", colour%0xffffff)
	end
	-- parses the output from top and calls the colour function
	function conky_top_cpu_colour(arg)
		-- input is ' ${top name 1} ${top pid 1} ${top cpu 1} ${top mem 1}'
		local cpu = tonumber(string.match(arg, '(%d+%.%d+)'))
		-- tweak the last 3 parameters to your liking
		-- my machine has 4 CPUs, so an upper thresh of 25% is appropriate
		return conky_top_colour(cpu, 0xd3, 25, 15) .. arg
	end
	function conky_top_mem_colour(arg)
		-- input is '${top_mem name 1} ${top_mem pid 1} ${top_mem cpu 1} ${top_mem mem 1}'
		local mem = tonumber(string.match(arg, '%d+%.%d+%s+(%d+%.%d+)'))
		-- tweak the last 3 parameters to your liking
		-- my machine has 8GiB of ram, so an upper thresh of 15% is appropriate
		return conky_top_colour(mem, 0xd3, 15, 5) .. arg
	end

	-- returns a percentage value that loops around
	function conky_int_func()
		int = int + 1
		return int % 100
	end
	function conky_floor(arg)
		return math.floor(arg)
	end
end
