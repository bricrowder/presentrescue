local camera = {}

function camera.set(x, y, s)
    love.graphics.push()
    love.graphics.scale(s)
    
    love.graphics.translate(-x,-y)
end

function camera.setCentre(x, y, s, width, height)
    love.graphics.push()
    love.graphics.scale(s)
    
    local w, h = love.graphics.getDimensions()
    local px = x - w / 2 / s
    local py = y - h / 2 / s

    if px < 0 then px = 0 end
    if py < 0 then py = 0 end
    if px > width - w/s then px = width - w/s end
    if py > height - h/s then py = height - h/s end

    love.graphics.translate(-px, -py)

end

function camera.reset()
    love.graphics.pop()
end

return camera