local tilemap = {}

local function getAliveNeighborCount(tilemap, cell)
    local row, col = cell[1], cell[2]

    local neighbors = 0

    local startrow = row - 1
    local startcol = col - 1
    local endrow = row + 1
    local endcol = col + 1

    if startrow < 1 then startrow = 1 end
    if startcol < 1 then startcol = 1 end
    if endrow > #tilemap then endrow = #tilemap end
    if endcol > #tilemap[1] then endcol = #tilemap[1] end


    for r=startrow, endrow do
        for c=startcol, endcol do
            if tilemap[r][c].alive then
                neighbors = neighbors + 1
            end                
        end
    end

    return neighbors
end

local function getBitwiseNeighborCount(tilemap, cell)
    local row, col = cell[1], cell[2]

    local neighbors = 0

    if row > 1 and tilemap[row-1][col].alive then
        neighbors = neighbors + 1
    end
    if row < #tilemap and tilemap[row+1][col].alive then
        neighbors = neighbors + 4
    end
    if col > 1 and tilemap[row][col-1].alive then
        neighbors = neighbors + 8
    end
    if col < #tilemap[1] and tilemap[row][col+1].alive then
        neighbors = neighbors + 2
    end

    return neighbors
end

function tilemap.createTilemap(maze, roomsize, automata, objrand, OBJECTS)
    local rows = #maze
    local cols = #maze[1]

    local width = cols * roomsize
    local height = rows * roomsize

    local tilemap = {}

    -- print("creating tilemap: " .. width .. "," .. height)

    for r=1, height do
        tilemap[r] = {}
        local mazeRow = math.floor((r-1) / roomsize) + 1
        for c=1, width do
            tilemap[r][c] = {
                alive = false,
                tile = 0,
                object = 0
            }

            local mazeCol = math.floor((c-1) / roomsize) + 1

            if maze[mazeRow][mazeCol].masked then
                tilemap[r][c].alive = true

            elseif (maze[mazeRow][mazeCol].N_wall and (r-1) % roomsize + 1 == 1) or
                    (maze[mazeRow][mazeCol].S_wall and (r-1) % roomsize + 1 == roomsize) or
                    (maze[mazeRow][mazeCol].W_wall and (c-1) % roomsize + 1 == 1) or
                    (maze[mazeRow][mazeCol].E_wall and (c-1) % roomsize + 1 == roomsize) then
                tilemap[r][c].alive = true
            else
                if automata then
                    if math.random() <= automata.init then
                        tilemap[r][c].alive = true
                    end
                end
            end
        end
    end

    if automata then
        for i=1, automata.generations do
            for r=2, height-1 do
                for c=2, width-1 do
                    local neighbors = getAliveNeighborCount(tilemap,{r,c})

                    if tilemap[r][c].alive then
                        if 8-neighbors >= automata.rules[2] then
                            tilemap[r][c].alive = false
                        end
                    else
                        if neighbors >= automata.rules[1] then
                            tilemap[r][c].alive = true
                        end
                    end 
                end
            end
        end
    end

    -- bitwise auto-tiling and object placement
    for r=1, height do
        for c=1, width do
            local neighbors = getBitwiseNeighborCount(tilemap, {r,c})
            if tilemap[r][c].alive then
                tilemap[r][c].tile = neighbors

                -- edge case
                if neighbors == 10 and (r == height or r == 1) then tilemap[r][c].tile = 11 end
            end

            -- only place on floor or top tiles
            if tilemap[r][c].tile == 0 then
                if math.random() < objrand then
                    tilemap[r][c].object = math.random(OBJECTS[1],OBJECTS[2])
                end
            end
            
        end
    end

    -- spritebatch for tilemap

    return tilemap
end

function tilemap.bakeSpriteBatch(tilemap, tilesize, spriteFactory)
    local sb = love.graphics.newSpriteBatch(spriteFactory.texture, 1000, "static")

    for r=1, #tilemap do
        for c=1, #tilemap[1] do
            for i=1, #spriteFactory.sprites do
                if spriteFactory.sprites[i].bitvalue == tilemap[r][c].tile then
                    sb:add(spriteFactory.sprites[i].quad, (c-1) * tilesize, (r-1) * tilesize)
                end
            end
        end
    end

    return sb
end

function tilemap.createObjectList(tilemap, tilesize, sf)
    local sprites = {}

    for r=1, #tilemap do
        for c=1, #tilemap[1] do
            if tilemap[r][c].object > 0 then
                for i=1, #sf.sprites do
                    if sf.sprites[i].bitvalue == tilemap[r][c].object then
                        table.insert(sprites, {
                            uid = i,
                            quad = sf.sprites[i].quad,
                            x = (c-1) * tilesize,
                            y = (r-1) * tilesize,
                            angle = 0,
                            scalex = 1,
                            scaley = 1,
                            offsetx = sf.sprites[i].xoffset,
                            offsety = sf.sprites[i].yoffset
                        })
                    end
                end    
            end
        end
    end

    return sprites
end

function tilemap.presentGenerator(pl, tilemap, tilesize, sf, PRESENTS, SNOW, dt)
    if #pl.presents < pl.presentmax then
        pl.presenttimer = pl.presenttimer + dt
        if pl.presenttimer >= pl.presenttimermax then
            pl.presenttimer = pl.presenttimer - pl.presenttimermax

            local togen = pl.presentmax - #pl.presents

            while togen > 0 do
                local r = math.random(#tilemap)
                local c = math.random(#tilemap[1])

                if tilemap[r][c].tile < 1 and tilemap[r][c].object < 1 then
                    local s = math.random(PRESENTS[1],PRESENTS[2])
                    local q = nil
                    local x, y, w, h = 0,0,0,0
                    for i=1,#sf.sprites do
                        if sf.sprites[i].bitvalue == s then
                            q = sf.sprites[i].quad
                            x,y,w,h = q:getViewport()
                        end
                    end
                    if q then
                        table.insert(pl.presents,
                            {
                                quad = q,
                                x = (c-1) * tilesize,
                                y = (r-1) * tilesize,
                                w = w,
                                h = h,
                                t = 0,
                                sq = nil
                            }
                        )

                        -- print("made a present: " .. s .. " @ " .. (c-1) * tilesize .. "," .. (r-1) * tilesize)
                    end

                    togen = togen - 1
                end
            end


        end
    end

    local toremove = {}
    for i,v in ipairs(pl.presents) do
        v.t = v.t + dt

        local s = math.floor(v.t / pl.snowtick)
        
        if s > 0 then
            local x, y, w, h = 0,0,0,0
            for j=1,#sf.sprites do
                if sf.sprites[j].bitvalue == SNOW[s] then
                    v.sq = sf.sprites[j].quad
                    -- x,y,w,h = sq:getViewport()
                end
            end

        end

        if v.t >= pl.individualpresenttimer then
            -- print("removing " .. i)
            table.insert(toremove, i)
        end
    end

    if #toremove > 0 then
        for i=#toremove, 1, -1 do
            table.remove(pl.presents, toremove[i])
        end
    end

    return pl
end

function tilemap.drawBasicLayout(tilemap, tilesize, highlight, lowlight)
    for r=1, #tilemap do
        for c=1, #tilemap[1] do
            if tilemap[r][c].tile > 0 then
                love.graphics.setColor(lowlight)
            else
                love.graphics.setColor(highlight)
            end
            love.graphics.rectangle("fill", (c-1) * tilesize, (r-1) * tilesize, tilesize, tilesize)
        end
    end
end

function tilemap.drawTilemap(tilemap, tilesize, sf)

    for r=1, #tilemap do
        for c=1, #tilemap[1] do
            local y = (r-1) * tilesize
            local x = (c-1) * tilesize
            
            -- local q = sf.sprites[14].quad

            -- -- print("checking for: " .. tilemap[r][c].tile)
            -- for i=1, #sf.sprites do
            --     if sf.sprites[i].bitvalue == tilemap[r][c].tile then
            --         q = sf.sprites[i].quad
            --     end
            -- end
            
            -- love.graphics.draw(sf.texture, q, x, y)

            -- if tilemap[r][c].alive then
            --     love.graphics.rectangle("fill", x, y, tilesize, tilesize)
            -- end
            love.graphics.setColor(1,0,0,1)
            love.graphics.print(tilemap[r][c].object, x+1, y+1)
            love.graphics.setColor(1,1,1,1)
        end
    end
end

function tilemap.findRandomOpenCell(tilemap)
    local coords = {}

    for r=1, #tilemap do
        for c=1, #tilemap[1] do
            if tilemap[r][c].tile == 0 then
                table.insert(coords, {r,c})
            end
        end
    end

    local randomIndex = math.random(#coords)

    return coords[randomIndex][1], coords[randomIndex][2]
end

function tilemap.getGridPosition(x, y, tilesize)
    local r = math.floor(y / tilesize) + 1
    local c = math.floor(x / tilesize) + 1
    return r, c
end

function tilemap.isCellOpen(x, y, tilemap, tilesize)
    local r, c = tilemap.getGridPosition(x, y, tilesize)
    local open = false
    if tilemap[r][c].tile == 0 then
        open = true
    end
    return open
end

return tilemap