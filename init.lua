--[[
   Copyright (C) 2022  Jude Melton-Houghton

   This file implements mapblock_highlight, a Minetest client-side mod for
   visually highlighting individual mapblocks using chat commands.

   mapblock_highlight is free software: you can redistribute it and/or modify
   it under the terms of the GNU Lesser General Public License as published
   by the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   mapblock_highlight is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public License
   along with mapblock_highlight. If not, see <https://www.gnu.org/licenses/>.
]]


mapblock_highlight = {}


--[[ Settings ]]

-- Interval in seconds at which the set of highlighted mapblocks is updated.
mapblock_highlight.update_interval = 3

-- Texture used for the particles used for highlighting.
mapblock_highlight.particle_texture = "ignore.png"


--[[ Highlight drawing ]]

-- Internal function that draws a line of particles along the given axis with
-- the given length. It starts at the least corner of the node at min_pos and
-- extends in the positive direction.
local function draw_line(axis, min_pos, length, duration)
	local pos = min_pos:subtract(0.5)
	for i = 0, length do
		pos[axis] = min_pos[axis] + i - 0.5
		minetest.add_particle({
			pos = pos,
			expirationtime = duration,
			texture = mapblock_highlight.particle_texture,
			size = 2,
			glow = 14,
		})
	end
end

-- Draws a highlight out of particles for the mapblock with the given position.
-- The highlight will remain visible for the given duration (in seconds.)
-- This highlight is distinct from the persistent highlights described below.
function mapblock_highlight.draw_highlight(blockpos, duration)
	local pos = blockpos * 16

	draw_line("x", pos, 16, duration)
	draw_line("x", pos:offset(0, 16, 0), 16, duration)
	draw_line("x", pos:offset(0, 0, 16), 16, duration)
	draw_line("x", pos:offset(0, 16, 16), 16, duration)

	draw_line("z", pos:offset(0, 0, 1), 14, duration)
	draw_line("z", pos:offset(0, 16, 1), 14, duration)
	draw_line("z", pos:offset(16, 0, 1), 14, duration)
	draw_line("z", pos:offset(16, 16, 1), 14, duration)

	draw_line("y", pos:offset(0, 1, 0), 14, duration)
	draw_line("y", pos:offset(0, 1, 16), 14, duration)
	draw_line("y", pos:offset(16, 1, 0), 14, duration)
	draw_line("y", pos:offset(16, 1, 16), 14, duration)
end


--[[ Persistent highlight management ]]

-- Internal function for converting a (mapblock) position to a string key.
local function pos_key(pos)
	return ("%d@%d@%d"):format(pos.x, pos.y, pos.z)
end

-- Internal map from mapblock keys to update jobs.
local jobs = {}

-- Returns whether the given mapblock is persistently highlighted.
function mapblock_highlight.has_highlight(blockpos)
	return jobs[pos_key(blockpos)] ~= nil
end

-- Sets the given mapblock to be persistently highlighted.
function mapblock_highlight.add_highlight(blockpos)
	mapblock_highlight.draw_highlight(blockpos,
		mapblock_highlight.update_interval)
	local key = pos_key(blockpos)
	if jobs[key] then jobs[key]:cancel() end
	jobs[key] = minetest.after(
		mapblock_highlight.update_interval,
		mapblock_highlight.add_highlight, blockpos)
end

-- Removes persistent highlighting on the given mapblock.
function mapblock_highlight.remove_highlight(blockpos)
	local key = pos_key(blockpos)
	local job = jobs[key]
	if job then
		job:cancel()
		jobs[key] = nil
	end
end

-- Removes all persistent highlights.
function mapblock_highlight.clear_highlights()
	for _, job in pairs(jobs) do
		job:cancel()
	end
	jobs = {}
end


--[[ Chat commands ]]

minetest.register_chatcommand("mapblock_highlight", {
	params = "[<pos>]",
	description = "Toggle the mapblock highlight at the given position " ..
		"or your own",
	func = function(param)
		param = param:trim()

		local pos
		if param == "" then
			pos = minetest.localplayer:get_pos()
			if not pos then
				return false, "Could not get player position"
			end
		else
			pos = minetest.string_to_pos(param)
			if not pos then
				return false, "Invalid argument"
			end
		end

		local blockpos = (pos / 16):floor()
		if mapblock_highlight.has_highlight(blockpos) then
			mapblock_highlight.remove_highlight(blockpos)
			return true, "Mapblock highlight will be removed soon"
		else
			mapblock_highlight.add_highlight(blockpos)
			return true, "Set mapblock highlight"
		end
	end,
})

minetest.register_chatcommand("mapblock_highlight_clear", {
	params = "",
	description = "Clear all mapblock highlights",
	func = function()
		mapblock_highlight.clear_highlights()
		return true, "All mapblock highlights will be removed soon"
	end
})
