-- ================================================
-- wget https://raw.githubusercontent.com/GeneralMine/CC/main/berryfarm.lua
-- ================================================


-- Berry Farm Turtle
-- Harvests sweet berry bushes
-- Moves once every 2 seconds

local LENGTH = 8
local MOVE_DELAY = 2

local INTERACTION_SLOT = 1
local fuelSlot = 16


-- Direction: bushes are to the right of the turtle
-- Chest is behind the starting position
-- C                  <- Chest at starting position
-- T → → → → → → →    <- Turtle path
-- B B B B B B B B    <- Berry bushes


local function sleepMove()
    sleep(MOVE_DELAY)
end


local function harvest()
    -- Face the berry bush
    turtle.turnRight()

    local success, data = turtle.inspect()

    if success and data.name == "minecraft:sweet_berry_bush" then
        local age = tonumber(data.state.age)

        -- Age 2 and 3 are harvestable
        if age and age >= 2 then
            turtle.select(INTERACTION_SLOT)

            -- Right-click interaction without breaking the bush
            local harvested = turtle.place()

            if harvested then
                sleep(0.3)

                -- Collect dropped berries
                turtle.suck()
            end
        end
    end

    -- Restore original direction
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
    for slot = 2, 16 do
        turtle.select(slot)
        turtle.drop()
    end

    -- Refuel from chest
    if turtle.getFuelLevel() ~= "unlimited" then

        -- Find an empty inventory slot

        for slot = 2, 16 do
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
