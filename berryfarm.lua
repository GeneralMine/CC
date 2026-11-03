-- ================================================
-- wget https://raw.githubusercontent.com/GeneralMine/CC/main/berryfarm.lua
-- ================================================


-- Berry Farm Turtle
-- Harvests sweet berry bushes
-- Moves once every 2 seconds

local LENGTH = 8
local MOVE_DELAY = 2

-- Direction: bushes are to the right of the turtle
-- Chest is behind the starting position
-- C                  <- Chest at starting position
-- T → → → → → → →    <- Turtle path
-- B B B B B B B B    <- Berry bushes


local function sleepMove()
    sleep(MOVE_DELAY)
end


local function harvest()
    -- Turn right to face the berry bushes
    turtle.turnRight()

    -- Inspect the block in front
    local success, data = turtle.inspect()

    if success and data.name == "minecraft:sweet_berry_bush" then
        -- Harvest only fully grown bushes
        if data.state and tonumber(data.state.age) == 3 then
            turtle.dig()
        end
    end

    -- Face the original direction again
    turtle.turnLeft()
end


local function moveForward()
    while not turtle.forward() do
        turtle.dig()
        sleep(0.5)
    end
    sleepMove()
end

local function turnAround()
    turtle.turnLeft()
    turtle.turnLeft()
end


local function depositAndRefuel()
    -- Face the chest behind the turtle
    turnAround()

    -- Deposit harvested berries
    for slot = 1, 16 do
        turtle.select(slot)
        turtle.drop()
    end

    -- Refuel from chest
    if turtle.getFuelLevel() ~= "unlimited" then

        -- Find an empty inventory slot
        local fuelSlot = 16

        for slot = 1, 16 do
            if turtle.getItemCount(slot) == 0 then
                fuelSlot = slot
                break
            end
        end

        -- Take fuel from chest
        turtle.select(fuelSlot)

        if turtle.suck() then
            -- Consume fuel until full or stack is empty
            turtle.refuel(0)

            while turtle.getFuelLevel() < turtle.getFuelLimit()
              and turtle.getItemCount(fuelSlot) > 0 do
                turtle.refuel(1)
            end

            -- Return unused fuel to chest
            turtle.drop()
        end
    end

    -- Face original direction again
    turnAround()
end


local function farm()
    for i = 1, LENGTH do
        harvest()

        if i < LENGTH then
            moveForward()
        end
    end

    -- Return to starting position
    turnAround()

    for i = 1, LENGTH - 1 do
        moveForward()
    end

    turnAround()

    -- Store harvested berries
    depositAndRefuel()
end


while true do
    farm()
    sleep(5)
end
