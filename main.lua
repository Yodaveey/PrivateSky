--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.
local license = ... or {}
license.Key = script_key or license.Key or nil
repeat task.wait() until game:IsLoaded()
if shared.vape then shared.vape:Uninject() end

local vape
local loadstring = function(...)
	local res, err = loadstring(...)
	if err and vape then
		vape:CreateNotification('Vape', 'Failed to load : '..err, 30, 'alert')
	end
	return res
end
local queue_on_teleport = queue_on_teleport or function() end
local isfile = isfile or function(file)
	local suc, res = pcall(function()
		return readfile(file)
	end)
	return suc and res ~= nil and res ~= ''
end
local cloneref = cloneref or function(obj)
	return obj
end
local playersService = cloneref(game:GetService('Players'))
local httpService = cloneref(game:GetService('HttpService'))

local redirect = function()
	local body = httpService:JSONEncode({
		nonce = httpService:GenerateGUID(false),
		args = {
			invite = {code = 'catvape'},
			code = 'catvape'
		},
		cmd = 'INVITE_BROWSER'
	})

	for i = 1, 2 do
		task.spawn(function()
			request({
				Method = 'POST',
				Url = 'http://127.0.0.1:6463/rpc?v=1',
				Headers = {
					['Content-Type'] = 'application/json',
					Origin = 'https://discord.com'
				},
				Body = body
			})
		end)
	end
end

local function downloadFile(path, func)
	if not isfile(path) then
		warn(path)
		local suc, res = pcall(function()
			return game:HttpGet('https://raw.githubusercontent.com/Yodaveey/PrivateSky/'..readfile('SkyVape/profiles/commit.txt')..'/'..select(1, path:gsub('SkyVape/', '')), true)
		end)
		if not suc or res == '404: Not Found' then
			task.spawn(error, res)
		end
		if suc then
			if path:find('.lua') then
				res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..res
			end
			writefile(path, res)
		end
	end
	return (func or readfile)(path)
end

-- Auto-update: check GitHub for the latest commit SHA and wipe stale local files
local function checkForUpdates()
	local ok, raw = pcall(function()
		return game:HttpGet('https://api.github.com/repos/Yodaveey/PrivateSky/commits/main', true)
	end)
	if not ok then return end

	local parsed, sha
	ok, parsed = pcall(function() return httpService:JSONDecode(raw) end)
	if not ok or not parsed then return end
	sha = parsed.sha
	if not sha then return end

	-- Trim to first 40 chars just in case
	sha = sha:sub(1, 40)

	local localCommit = isfile('SkyVape/profiles/commit.txt') and readfile('SkyVape/profiles/commit.txt') or 'main'
	localCommit = localCommit:gsub('%s+', '')

	if sha ~= localCommit and localCommit ~= 'main' then
		-- New version detected — wipe all downloaded lua files so they re-fetch
		shared.updated = localCommit
		local folders = {
			'SkyVape/guis',
			'SkyVape/games',
			'SkyVape/libraries',
		}
		for _, folder in folders do
			local ok2, files = pcall(listfiles, folder)
			if ok2 and files then
				for _, file in files do
					if file:find('%.lua$') then
						local ok3, content = pcall(readfile, file)
						if ok3 and content:find('This watermark is used to delete') then
							pcall(delfile, file)
						end
					end
				end
			end
		end
	end

	-- Always save the latest SHA so next time we can compare properly
	writefile('SkyVape/profiles/commit.txt', sha)
end


local function finishLoading()
	vape.Init = nil
	vape:Load()
	task.spawn(function()
		repeat
			vape:Save()
			task.wait(10)
		until not vape.Loaded
	end)

	local teleportedServers
	vape:Clean(playersService.LocalPlayer.OnTeleport:Connect(function(state)
		if (not teleportedServers) and (not shared.VapeIndependent) then
			teleportedServers = true
			local teleportScript = [[
				if shared.VapeDeveloper then
					loadstring(readfile('SkyVape/main.lua'), 'main')(_scriptconfig)
				else
					loadstring(game:HttpGet('https://api.catvape.dev/script?key=_key'), 'init')(_scriptconfig)
				end
			]]
			local teleportConfig = httpService:JSONEncode(license)
			teleportConfig = teleportConfig:gsub('":true', "=true"):gsub('{"', '{')
			teleportConfig = teleportConfig:gsub(',"', ','):gsub('":', '=')
			teleportConfig = teleportConfig:gsub('%[', '{'):gsub('%]', '}')
			teleportScript = teleportScript:gsub('_key', tostring(license.Key or '_key'))
			teleportScript = teleportScript:gsub('_scriptconfig', teleportConfig)
			if shared.VapeDeveloper then
				teleportScript = 'shared.VapeDeveloper = true\n'..teleportScript
			end
			if shared.VapeCustomProfile then
				teleportScript = 'shared.VapeCustomProfile = "'..shared.VapeCustomProfile..'"\n'..teleportScript
			end
			queue_on_teleport(teleportScript)
		end
	end))

	if not shared.vapereload then
		if not vape.Categories then return end
		if vape.Categories.Main.Options['GUI bind indicator'].Enabled then
			if getgenv().catrole == 'HWID MISMATCH' then
				vape:CreateNotification('Cat', 'HWID MISMATCH, Go to the script panel to reset hwid', 25, 'alert')
				getgenv().catrole = ''
				task.wait(0.1)
			end
			if vape.Place ~= 6872274481 then
				--task.spawn(redirect)
			end
			vape:CreateNotification('Finished Loading', (getgenv().catname and `Authenticated as {getgenv().catname} with {getgenv().catrole}, ` or '').. (vape.VapeButton and 'Press the button in the top right' or 'Press '..table.concat(vape.Keybind, ' + '):upper())..' to open GUI', 5)
			task.delay(1, function()
				if shared.updated then
					vape:CreateNotification('Cat', `Script has updated from {shared.updated} to {readfile('SkyVape/profiles/commit.txt')}`, 10, 'info')
				end
			end)
		end
	end
end

if not isfile('SkyVape/profiles/gui.txt') then
	writefile('SkyVape/profiles/gui.txt', 'new')
end
local gui = 'new'--readfile('SkyVape/profiles/gui.txt')

if not isfolder('SkyVape/assets/'..gui) then
	makefolder('SkyVape/assets/'..gui)
end
if not isfile('SkyVape/profiles/commit.txt') then
	writefile('SkyVape/profiles/commit.txt', 'main')
end

-- Check GitHub for a newer commit and wipe stale cached files if found
checkForUpdates()


getgenv().used_init = true
vape = loadstring(downloadFile('SkyVape/guis/'..gui..'.lua'), 'gui')(license)
_G.vape = vape
shared.vape = vape

if shared.maincat then
	redirect()
	playersService.LocalPlayer:Kick('Your script is outdated, Get new one at discord.gg/catvape')
	return
end

if not shared.VapeIndependent then
	loadstring(downloadFile('SkyVape/games/universal.lua'), 'universal')(license)
	if isfile('SkyVape/games/'..game.PlaceId..'.lua') then
		loadstring(readfile('SkyVape/games/'..game.PlaceId..'.lua'), tostring(game.PlaceId))(license)
	else
		if not shared.VapeDeveloper then
			local suc, res = pcall(function()
				return game:HttpGet('https://raw.githubusercontent.com/Yodaveey/PrivateSky/'..readfile('SkyVape/profiles/commit.txt')..'/games/'..game.PlaceId..'.lua', true)
			end)
			if suc and res ~= '404: Not Found' then
				loadstring(downloadFile('SkyVape/games/'..game.PlaceId..'.lua'), tostring(game.PlaceId))(license)
			end
		end
	end
	loadstring(downloadFile('SkyVape/libraries/premium.lua'), 'premium')(license)
	finishLoading()
else
	vape.Init = finishLoading
	return vape
end
