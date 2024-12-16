spriteMetaData = require "spritemetadata"
mazeFactory = require "maze"
tilemapFactory = require "tilemap"
spriteFactory = require "spriteFactory"
camera = require "camera"

local GAMESCALE = 2

-- game variables and constants
local MENU, GAME, HISCORE = 1, 2, 3

local NEWGAME, EXIT = 1, 2

local STARTTIME = 300

local OBJECTS = {1000,1007}
local PRESENTS = {2000,2003}
local SNOW = {3000,3001,3002}
local TREE = {8000,8001}

local menuscreen = nil
local menuscreenscale = 1


local menuoptions = {
    {label = "New Game", x=200, y=140},
    {label = "Exit", x=220, y=160}
}

local menucolours = {
    normal = {0,0,0,1},
    highlight = {0.4,0.8,0.5,1}
}

local currentmenuoption = 1

-- player variables
local player = {
    walkspeed = 100,
    x=0, 
    y=0,
    width = 0,
    height = 0,
    flip = 1,
    quad = nil,
    uid = 0,
    spriteangle = math.pi/16,
    angletoggle = 0,
    anglechangetimer = 0,
    anglechangetimermax = 0.2,
    presents = {},
    maxpresents = 4,
    poptimer = 1,
    poptimermax = 1,
}

-- maze and tilemap variables
local layout = nil
local mazeTexture = nil
local tilemap = nil
local tilemapSpritebatch = nil
local objectlist = nil
local nextuid = 0

local minimapsize = 128      -- the map size - largest of the two sides
local minimapscale = 1
local minimaptexture = nil
local minimapcolours = {
    highlight = {0.5,0.5,0.5,1},
    lowlight = {0.5,0.1,0.1,1}
}

local objectRandomness = 0.025    -- chance that a object will be placed
local roomsize = 8      -- a room is one cell from the maze/layout object. the cell is 8x8 in this case
local tilesize = 16     -- size in pixels
local gametime = 0      -- game timer
local presentcount = 0  -- present count

local presentlist = {
    presents = {},
    presenttimer = 5,
    presenttimermax = 5,
    presentmax = 8,
    individualpresenttimer = 10
}


local dropofftree = {
    quad = {},
    frame = 1,
    timer = 0,
    timermax = 1
}

local timertext = nil

local timerposition = {
    x=0,
    y=5,
    bx=12,
    tx=12,
    ty=10
}
local timerbox = nil

local presenttext = nil
local presentui = nil
local presentbox = nil
local presentuiposition = {
    x=1,
    y=1,
    bx=17,
    by=1,
    tx=19,
    ty=2
}

local mazedef = {
    size = {8,8},
    start = {2,2},
    mask = {
        {1,1},
        {2,1},
        {1,2},
        {1,7},
        {1,8},
        {2,8},
        {7,1},
        {8,1},
        {8,2},
        {7,8},
        {8,7},
        {8,8}
    },
    removal = 0.35
}

-- -- maze definitions, move to a data file soon
-- local mazedef = {
--     size = {4,4},
--     start = {2,2},
--     mask = {
--         {1,1},
--         {1,4},
--         {4,1},
--         {4,4}
--     },
--     removal = 0.5
-- }

-- local mazedef = {
--     size = {6,6},
--     start = {1,1},
--     mask = {},
--     removal = 0.5
-- }


-- automata rules
local rules = {
    init = 0.35, 
    generations=8, 
    rules={5,4}
}

local menuaudio = nil
local jingleaudio = nil
local popaudio = nil
local actionaudio = nil
local stepaudio = nil


local function getHash(s)
    local n = 0
    for i=1,#s do
        local c = s:sub(i, i)
        local av = string.byte(c)
        n = n + av
    end
    return n
end

function love.load()
    love.graphics.setDefaultFilter("nearest")

    -- love.window.setMode(960,540)
    love.window.setMode(1440,810)

    local w, h = love.graphics.getDimensions()

    menuscreen = love.graphics.newImage("assets/menu.png")
    local mw, mh = menuscreen:getDimensions()
    menuscreenscale = w/mw
    
    sprites = spriteFactory.loadSprites("assets/sprites.png", spriteMetaData)

    for _,v in ipairs(sprites.sprites) do
        if v.bitvalue == 9000 then
            player.quad = v.quad

            local x, y, width, height = v.quad:getViewport()
            player.width = width
            player.height = height
        elseif v.bitvalue == 5000 then
            timerbox = v.quad
        elseif v.bitvalue == 5001 then
            presentbox = v.quad
        elseif v.bitvalue == TREE[1] then
            local x, y, width, height = v.quad:getViewport()
            dropofftree.width = width
            dropofftree.height = height
            dropofftree.offsetx = v.xoffset
            dropofftree.offsety = v.yoffset
            dropofftree.quad[1] = v.quad
        elseif v.bitvalue == TREE[2] then
            dropofftree.quad[2] = v.quad
        end
    end

    local qx, qy, qw, qh = timerbox:getViewport()
    timerposition.x = w/2 - qw/2
    timerposition.bx = w/2

    timertext = love.graphics.newText(love.graphics.getFont(),"")
    presenttext = love.graphics.newText(love.graphics.getFont(),"")

    menuaudio = {
        love.audio.newSource("assets/menu1.wav", "static"),
        love.audio.newSource("assets/menu2.wav", "static"),
        love.audio.newSource("assets/menu3.wav", "static"),
        love.audio.newSource("assets/menu4.wav", "static"),
        love.audio.newSource("assets/menu5.wav", "static")
    }

    actionaudio = {
        love.audio.newSource("assets/action1.wav", "static")
    }

    popaudio = {
        love.audio.newSource("assets/pop1.wav", "static")
    }

    jingleaudio = {
        love.audio.newSource("assets/jingle1.ogg", "static"),
        love.audio.newSource("assets/jingle2.ogg", "static")
    }

    stepaudio = {
        love.audio.newSource("assets/step1.flac", "static"),
        love.audio.newSource("assets/step2.flac", "static"),
        love.audio.newSource("assets/step3.flac", "static"),
        love.audio.newSource("assets/step4.flac", "static")
    }

    gamestate = MENU
end

function love.keypressed(key)
    if gamestate == MENU then
        if key == "up" or key == "w" then
            currentmenuoption = currentmenuoption - 1
            if currentmenuoption < 1 then
                currentmenuoption = #menuoptions
            end
            local s = math.random(#menuaudio)
            menuaudio[s]:stop()
            menuaudio[s]:play()
        elseif key == "down" or key == "s" then
            currentmenuoption = currentmenuoption + 1
            if currentmenuoption > #menuoptions then
                currentmenuoption = 1
            end
            local s = math.random(#menuaudio)
            menuaudio[s]:stop()
            menuaudio[s]:play()
        elseif key == "return" and currentmenuoption == NEWGAME then
            gamestate = GAME
    
            local seed = os.time()
            math.randomseed(seed)
            print(seed)
            math.random()
            math.random()
            math.random()

            layout = mazeFactory.generateMaze(mazedef)
            -- mazeTexture = mazeFactory.createMazeTexture(layout, 32)    
            tilemap = tilemapFactory.createTilemap(layout, roomsize, rules, objectRandomness, OBJECTS)
            tilemapSpritebatch = tilemapFactory.bakeSpriteBatch(tilemap, tilesize, sprites)
            objectlist = tilemapFactory.createObjectList(tilemap, tilesize, sprites)

            local r, c = tilemapFactory.findRandomOpenCell(tilemap)
            player.y = (r-1) * tilesize
            player.x = (c-1) * tilesize
            player.presents = {}

            local r2, c2 = tilemapFactory.findRandomOpenCell(tilemap)
            while not(r==r2) and not (c==c2) do
                r2, c2 = tilemapFactory.findRandomOpenCell(tilemap)
            end

            table.insert(objectlist, {
                uid = #objectlist+1,
                quad = player.quad,
                x = player.x,
                y = player.y,
                rotation = 0,
                scalex = player.flip,
                scaley = 1,
                offsetx = player.width/2,
                offsety = player.height/2
            })

            player.uid = #objectlist
            nextuid = #objectlist + 1
            
            r, c = tilemapFactory.findRandomOpenCell(tilemap)
            dropofftree.x = (c-1) * tilesize
            dropofftree.y = (r-1) * tilesize
            dropofftree.timer = 0


            gametime = STARTTIME
            presentcount = 0
            presentlist.presents = {}
            presentlist.snowtick = presentlist.individualpresenttimer / (#SNOW+1)

            local p = math.random(PRESENTS[1],PRESENTS[2])
            for _,v in ipairs(sprites.sprites) do
                if v.bitvalue == p then
                    presentui = v.quad
                end
            end

            local width = #tilemap[1] * tilesize
            local height = #tilemap * tilesize

            if width > height then
                minimapscale = minimapsize / width
            else
                minimapscale = minimapsize / height
            end

            minimaptexture = love.graphics.newCanvas(width*minimapscale, height*minimapscale)
            love.graphics.setCanvas(minimaptexture)
            love.graphics.push()
            love.graphics.scale(minimapscale)
            tilemapFactory.drawBasicLayout(tilemap, tilesize, minimapcolours.highlight, minimapcolours.lowlight)
            love.graphics.pop()
            love.graphics.setCanvas()

            local s = math.random(#actionaudio)
            actionaudio[s]:stop()
            actionaudio[s]:play()

        elseif key == "return" and currentmenuoption == EXIT then
            love.event.quit()
        end
    elseif gamestate == GAME then
        if key == "escape" then
            local s = math.random(#menuaudio)
            menuaudio[s]:stop()
            menuaudio[s]:play()

            gamestate = MENU
        end
    elseif gamestate == HISCORE then
    
    end
end

function love.update(dt)
    if gamestate == MENU then

    elseif gamestate == GAME then
        -- get player input
        local oldx = player.x
        local oldy = player.y
        local moving = false

        if love.keyboard.isDown("up", "w") then
            player.y = player.y - player.walkspeed * dt
            moving = true

            local drow, dcol = tilemapFactory.getGridPosition(player.x, player.y, tilesize)
            if tilemap[drow][dcol].tile > 0 or tilemap[drow][dcol].object > 0 then
                player.y = oldy
            end
        elseif love.keyboard.isDown("down", "s") then
            player.y = player.y + player.walkspeed * dt
            moving = true

            local drow, dcol = tilemapFactory.getGridPosition(player.x, player.y, tilesize)
            if tilemap[drow][dcol].tile > 0 or tilemap[drow][dcol].object > 0  then
                player.y = oldy
            end
        end

        if love.keyboard.isDown("left", "a") then
            player.x = player.x - player.walkspeed * dt
            moving = true
                        
            player.flip = -1

            local drow, dcol = tilemapFactory.getGridPosition(player.x, player.y, tilesize)
            if tilemap[drow][dcol].tile > 0 or tilemap[drow][dcol].object > 0  then
                player.x = oldx
            end

        elseif love.keyboard.isDown("right", "d") then
            player.x = player.x + player.walkspeed * dt
            moving = true

            player.flip = 1

            local drow, dcol = tilemapFactory.getGridPosition(player.x, player.y, tilesize)
            if tilemap[drow][dcol].tile > 0 or tilemap[drow][dcol].object > 0  then
                player.x = oldx
            end
        end

        if moving then
            player.anglechangetimer = player.anglechangetimer + dt
            if player.anglechangetimer >= player.anglechangetimermax then
                player.anglechangetimer = player.anglechangetimer - player.anglechangetimermax
                if player.angletoggle == 0 then
                    player.angletoggle = 1
                else
                    player.angletoggle = player.angletoggle * -1
                end
                local s = math.random(#stepaudio)
                stepaudio[s]:stop()
                stepaudio[s]:play()    
            end
        else
            player.angletoggle = 0
        end

        local toremove = {}
        if #player.presents < player.maxpresents then
            for i, v in ipairs(presentlist.presents) do
                if player.x > v.x and
                player.x < v.x + v.w and
                player.y > v.y and
                player.y < v.y + v.h then
                    
                    table.insert(toremove, i)
                    local presentheight = 0
                    if #player.presents > 0 then
                        presentheight = presentheight + player.presents[#player.presents].h
                    end
                    table.insert(player.presents, {quad = v.quad, h = presentheight+v.h})
                    local s = math.random(#jingleaudio)
                    jingleaudio[s]:stop()
                    jingleaudio[s]:play()        
                end
            end
        end

        if #toremove > 0 then
            for i=#toremove, 1, -1 do
                table.remove(presentlist.presents, toremove[i])
            end
        end

        presentlist = tilemapFactory.presentGenerator(presentlist, tilemap, tilesize, sprites, PRESENTS, SNOW, dt)


        for _,v in ipairs(objectlist) do
            if v.uid == player.uid then
                v.x = player.x
                v.y = player.y
                v.angle = player.spriteangle * player.angletoggle
                v.flip = player.flip
            end
        end

        table.sort(objectlist, 
            function (s1, s2)
                return s1.y < s2.y
            end
        )
    
        dropofftree.timer = dropofftree.timer + dt
        if dropofftree.timer >= dropofftree.timermax then
            dropofftree.timer = dropofftree.timer - dropofftree.timermax
            dropofftree.frame = dropofftree.frame + 1
            if dropofftree.frame > #TREE then
                dropofftree.frame = 1
            end
        end

        if player.x >= dropofftree.x and player.x <= dropofftree.x + dropofftree.width and 
           player.y >= dropofftree.y and player.y <= dropofftree.y + dropofftree.height then

            if #player.presents > 0 then
                player.poptimer = player.poptimer + dt
                if player.poptimer >= player.poptimermax then
                    player.poptimer = player.poptimer - player.poptimermax
                    table.remove(player.presents, #player.presents)
                    presentcount = presentcount + 1
                    local s = math.random(#popaudio)
                    popaudio[s]:stop()
                    popaudio[s]:play()        

                end
            else
                player.poptimer = player.poptimermax
            end
        end

        -- gametimer
        gametime = gametime - dt

        if gametime < 0 then
            gamestate = HISCORE
        end

    elseif gamestate == HISCORE then
        gamestate = MENU
    end
end

function love.draw()
    if gamestate == MENU then
        camera.set(0,0,menuscreenscale)
        love.graphics.draw(menuscreen)
        for i, v in ipairs(menuoptions) do
            if currentmenuoption == i then
                love.graphics.setColor(menucolours.highlight)
            else
                love.graphics.setColor(menucolours.normal)
            end
            love.graphics.print(v.label, v.x, v.y)
        end
        love.graphics.setColor(1,1,1,1)
        camera.reset()
    elseif gamestate == GAME then
        local h = #tilemap * tilesize
        local w = #tilemap[1] * tilesize

        camera.setCentre(player.x, player.y, GAMESCALE, w, h)

        love.graphics.draw(tilemapSpritebatch, 0, 0)

        for _,v in ipairs(presentlist.presents) do
            love.graphics.draw(sprites.texture, v.quad, v.x, v.y)
            if v.sq then
                love.graphics.draw(sprites.texture, v.sq, v.x, v.y, 0, 1, 1, 1, 0)
            end
        end

        love.graphics.draw(sprites.texture, dropofftree.quad[dropofftree.frame], dropofftree.x, dropofftree.y, 0, 1, 1, dropofftree.xoffset, dropofftree.yoffset)
        
        for _,v in ipairs(objectlist) do
            love.graphics.draw(sprites.texture, v.quad, v.x, v.y, v.angle, v.flip, 1, v.offsetx, v.offsety)
        end

        if #player.presents > 0 then
            for _,v in ipairs(player.presents) do
                love.graphics.draw(sprites.texture, v.quad, player.x - player.width/2, player.y - player.height/2 - v.h)
            end
        end

        -- love.graphics.draw("fill",player.x, player.y, player.size, player.size)

        -- tilemapFactory.drawTilemap(tilemap, tilesize, sprites)

        camera.reset()

        camera.set(0,0,GAMESCALE)
        love.graphics.draw(sprites.texture, timerbox, timerposition.x/GAMESCALE, timerposition.y/GAMESCALE)
        -- love.graphics.setColor(0.2,1,0.2,1)
        local m = math.floor(gametime / 60)
        local s = math.floor(gametime % 60)
        if m < 10 then
            m = "0" .. tostring(m)
        end
        if s < 10 then
            s = "0" .. tostring(s)
        end

        

        timertext:clear()
        timertext:set({{0.2,1,0.2,1},m .. ":" .. s})
        timerposition.tx = timerposition.bx - timertext:getWidth()/2/GAMESCALE
        love.graphics.draw(timertext, timerposition.tx/GAMESCALE, timerposition.ty/GAMESCALE)
        -- love.graphics.draw(timertext, timerposition.tx, timerposition.ty)

        love.graphics.draw(sprites.texture, presentui, presentuiposition.x, presentuiposition.y)
        love.graphics.draw(sprites.texture, presentbox, presentuiposition.bx, presentuiposition.by)
        local t = tostring(presentcount)
        local zerocount = 3 - #t
        local z = ""
        for i=1,zerocount do
            z = "0" .. z
        end
        presenttext:clear()
        presenttext:set({{0.3,0.3,0.3,1},z,{0.2,1,0.2,1},t})
        love.graphics.draw(presenttext, presentuiposition.tx, presentuiposition.ty)


        camera.reset()

        local width, height = love.graphics.getDimensions()
        love.graphics.draw(minimaptexture, width - minimaptexture:getWidth(), 0)
        love.graphics.setColor(0,1,0,1)
        love.graphics.circle("fill", player.x * minimapscale + width - minimaptexture:getWidth(), player.y * minimapscale, 2)
        love.graphics.setColor(1,0,0,1)
        love.graphics.circle("fill", dropofftree.x * minimapscale + width - minimaptexture:getWidth(), dropofftree.y * minimapscale, 2)
        love.graphics.setColor(0,0,1,1)
        love.graphics.rectangle("line", width - minimaptexture:getWidth(), 0, minimaptexture:getWidth(), minimaptexture:getHeight())
        love.graphics.setColor(1,1,1,1)


        -- local w, h = love.graphics.getDimensions()
        -- local px = player.x - w/2
        -- local py = player.y - h/2
        -- love.graphics.setColor(1,0,0,1)
        -- love.graphics.print("camera: " .. math.floor(px) .. "," .. math.floor(py), 10, 10)
        -- love.graphics.print("player: " .. math.floor(player.x) .. "," .. math.floor(player.y), 10, 25)
        -- local drow, dcol = tilemapFactory.getGridPosition(player.x, player.y, tilesize)

        -- love.graphics.print(drow .. "," .. dcol .. " : " .. tilemap[drow][dcol].tile, 10, 40)
        -- love.graphics.setColor(1,1,1,1)
    

    elseif gamestate == HISCORE then
    end
end