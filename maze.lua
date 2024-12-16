local maze = {}

-- local function to initialize the maze cells and apply any masking
local function initializeGrid(rows, cols, mask)
    local grid = {}
    for r = 1, rows do
        grid[r] = {}
        for c = 1, cols do
            grid[r][c] = {
                N_wall = true, 
                E_wall = true, 
                S_wall = true, 
                W_wall = true, 
                visited = false,
                masked = false
            }
        end
    end

    if mask then
        for _,v in ipairs(mask) do
            grid[v[1]][v[2]].visited = true
            grid[v[1]][v[2]].masked = true
        end
    end

    return grid
end

-- Function to get neighbors of a cell
local function getNeighbors(grid, cell)
    local neighbors = {}
    local row, col = cell[1], cell[2]

    if row > 1 and not grid[row - 1][col].visited then
        table.insert(neighbors, { row - 1, col, row, col })
    end
    if row < #grid and not grid[row + 1][col].visited then
        table.insert(neighbors, { row + 1, col, row, col })
    end
    if col > 1 and not grid[row][col - 1].visited then
        table.insert(neighbors, { row, col - 1, row, col })
    end
    if col < #grid[1] and not grid[row][col + 1].visited then
        table.insert(neighbors, { row, col + 1, row, col })
    end

    return neighbors
end

local function getInternalWalls(grid)
    local rows = #grid
    local cols = #grid[1]

    local walls = {}

    for r=1, rows do
        for c=1, cols do
            if not grid[r][c].masked then
                -- north
                if r > 1 and grid[r][c].N_wall and not grid[r - 1][c].masked then
                    table.insert(walls, {r, c, "n"})
                end
                -- south
                if r < rows and grid[r][c].S_wall and not grid[r + 1][c].masked then
                    table.insert(walls, {r, c, "s"})
                end
                -- west
                if c > 1 and grid[r][c].W_wall and not grid[r][c - 1].masked then
                    table.insert(walls, {r, c, "w"})
                end
                -- east
                if c < cols and grid[r][c].E_wall and not grid[r][c + 1].masked then
                    table.insert(walls, {r, c, "e"})
                end
            end
        end
    end

    return walls
end

-- Function to perform Prim's algorithm
function maze.generateMaze(mazedef)
    local grid = initializeGrid(mazedef.size[1], mazedef.size[2], mazedef.mask)

    grid[mazedef.start[1]][mazedef.start[2]].visited = true

    local nodes = getNeighbors(grid, {mazedef.start[1], mazedef.start[2]})

    while #nodes > 0 do
        local randomIndex = math.random(#nodes)
        local neighbor = nodes[randomIndex]
        local neighborRow, neighborCol = neighbor[1], neighbor[2]
        local parentRow, parentCol = neighbor[3], neighbor[4]

        -- print("Nodes: " .. #nodes .. "  Processing: " .. parentRow .. "," .. parentCol .. " -> " .. neighborRow .. "," .. neighborCol)

        if not(grid[parentRow][parentCol].visited) or not(grid[neighborRow][neighborCol].visited) then
            if parentRow < neighborRow then
                grid[parentRow][parentCol].S_wall = false
                grid[neighborRow][neighborCol].N_wall = false
            elseif parentRow > neighborRow then
                grid[parentRow][parentCol].N_wall = false
                grid[neighborRow][neighborCol].S_wall = false
            elseif parentCol < neighborCol then
                grid[parentRow][parentCol].E_wall = false
                grid[neighborRow][neighborCol].W_wall = false
            elseif parentCol > neighborCol then
                grid[parentRow][parentCol].W_wall = false
                grid[neighborRow][neighborCol].E_wall = false
            end
        end

        grid[neighborRow][neighborCol].visited = true

        table.remove(nodes, randomIndex)
        
        local newNeighbors = getNeighbors(grid, neighbor)
        for _, newNeighbor in ipairs(newNeighbors) do
            table.insert(nodes, newNeighbor)
        end
    end

    if mazedef.removal > 0 then
        local walls = getInternalWalls(grid)
        local remove = math.floor(#walls / 2 * mazedef.removal)
        -- print("walls: " .. #walls/2 .. "  removing: " .. remove)
        
        for i=1, remove do
            local randomIndex = math.random(#walls)
            local r, c, w = walls[randomIndex][1], walls[randomIndex][2], walls[randomIndex][3]

            if w == "n" then
                grid[r][c].N_wall = false
                grid[r-1][c].S_wall = false
            elseif w == "s" then
                grid[r+1][c].N_wall = false
                grid[r][c].S_wall = false
            elseif w == "e" then
                grid[r][c].E_wall = false
                grid[r][c+1].W_wall = false
            elseif w == "w" then
                grid[r][c-1].E_wall = false
                grid[r][c].W_wall = false
            end
        end
    end

    -- are we going to remove any for additional randomness?
    return grid
end



-- render maze to a texture
function maze.createMazeTexture(maze, cellsize)
    local height = #maze * cellsize
    local width = #maze[1] * cellsize

    local texture = love.graphics.newCanvas(width, height)
    love.graphics.setCanvas(texture)

    for row=1, #maze do
        for col=1, #maze[row] do
            if maze[row][col].masked then
                love.graphics.setColor(0,0,0,1)
                love.graphics.rectangle(
                    "fill", 
                    (col-1) * cellsize,
                    (row-1) * cellsize,
                    cellsize,
                    cellsize
                )
                love.graphics.setColor(1,1,1,1)
            else
                if maze[row][col].N_wall then
                    love.graphics.line(
                        (col-1) * cellsize,
                        (row-1) * cellsize,
                        (col-1) * cellsize + cellsize,
                        (row-1) * cellsize                    
                    )
                end
                if maze[row][col].E_wall then
                    love.graphics.line(
                        (col-1) * cellsize + cellsize,
                        (row-1) * cellsize,
                        (col-1) * cellsize + cellsize,
                        (row-1) * cellsize + cellsize
                    )
                end
                if maze[row][col].S_wall then
                    love.graphics.line(
                        (col-1) * cellsize,
                        (row-1) * cellsize + cellsize,
                        (col-1) * cellsize + cellsize,
                        (row-1) * cellsize + cellsize
                    )                    
                end
                if maze[row][col].W_wall then
                    love.graphics.line(
                        (col-1) * cellsize,
                        (row-1) * cellsize,
                        (col-1) * cellsize,
                        (row-1) * cellsize + cellsize
                    )                    
                end
            end
        end
    end

    love.graphics.setCanvas()

    return texture
end

return maze