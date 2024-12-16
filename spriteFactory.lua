local spriteFactory = {}

function spriteFactory.loadSprites(spritesheet, metadata)
    local s = {}

    s.texture = love.graphics.newImage(spritesheet)
    s.sprites = {}
    

    for i=1, #metadata do
        local xoffset, yoffset = 0, 0
        local md = metadata[i]
        if md.xoffset then
            xoffset = md.offset
        end
        if md.yoffset then
            yoffset = md.yoffset
        end
        s.sprites[i] = {
            quad = love.graphics.newQuad(md.x, md.y, md.width, md.height, s.texture:getWidth(), s.texture:getHeight()),
            type = md.type,
            style = md.style,
            bitvalue = md.bitvalue,
            xoffset = xoffset,
            yoffset = yoffset
        }
    end

    return s
end

return spriteFactory