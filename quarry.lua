
-- ================================================
-- CC:Tweaked - Optimised 3D Quarry
-- ================================================
-- Start position: (0, 0, 0)
-- First block:    (0, 0, 1)
-- Chest:          Directly behind starting position
--
-- X+ = Right
-- Y+ = Up
-- Z+ = Forward
--
-- Fuel items are kept in the turtle.
-- All other items are deposited into the chest.
-- ================================================

local START_X = 0
local START_Y = 0
local START_Z = 1

local HOME_X = 0
local HOME_Y = 0
local HOME_Z = 0

local FUEL_TARGET = 1000
local FUEL_MARGIN = 32
local INVENTORY_RESERVE = 3

local MAX_DIG_ATTEMPTS = 30

-- ================================================
-- PROTECTED BLOCKS
-- ================================================

local BLACKLIST_NAMESPACES = {
    
}

-- Optional additional protected blocks.
local BLACKLIST_BLOCKS = {
    -- "minecraft:chest",
    -- "minecraft:barrel",
}

local function isBlacklisted(blockName)
    if not blockName then
        return false
    end

    for _, namespace in ipairs(BLACKLIST_NAMESPACES) do
        if string.sub(blockName, 1, #namespace) == namespace then
            return true
        end
    end

    for _, block in ipairs(BLACKLIST_BLOCKS) do
        if blockName == block then
            return true
        end
    end

    return false
end

local function checkProtected(inspectFunction, position)
    local detected, block = inspectFunction()

    if detected and isBlacklisted(block.name) then
        error(
            "PROTECTED BLOCK DETECTED at "
            .. position .. ": " .. block.name
            .. "\nQuarry stopped to protect MineColonies."
        )
    end

    return detected
end

-- ================================================
-- POSITION TRACKING
-- ================================================

local x, y, z = HOME_X, HOME_Y, HOME_Z

-- 0 = Forward
-- 1 = Right
-- 2 = Backward
-- 3 = Left

local direction = 0
local servicing = false

-- ================================================
-- USER INPUT
-- ================================================

local function askNumber(prompt)
    while true do
        write(prompt)
        local value = tonumber(read())

        if value and value == math.floor(value) then
            return value
        end

        print("Please enter a whole number.")
    end
end

print("================================")
print("       AUTOMATIC QUARRY")
print("================================")
print("")
print("Start block: (0, 0, 1)")
print("Enter the last block coordinates.")
print("")

local endX = askNumber("Last X: ")
local endY = askNumber("Last Y: ")
local endZ = askNumber("Last Z: ")

local minX = math.min(START_X, endX)
local maxX = math.max(START_X, endX)

local minY = math.min(START_Y, endY)
local maxY = math.max(START_Y, endY)

local minZ = math.min(START_Z, endZ)
local maxZ = math.max(START_Z, endZ)

local sizeX = maxX - minX + 1
local sizeY = maxY - minY + 1
local sizeZ = maxZ - minZ + 1

local totalBlocks = sizeX * sizeY * sizeZ

print("")
print("Quarry dimensions:")
print("X: " .. sizeX)
print("Y: " .. sizeY)
print("Z: " .. sizeZ)
print("Total blocks: " .. totalBlocks)
print("")

-- ================================================
-- TURNING
-- ================================================

local function turnRight()
    if not turtle.turnRight() then
        error("Unable to turn right.")
    end

    direction = (direction + 1) % 4
end

local function turnLeft()
    if not turtle.turnLeft() then
        error("Unable to turn left.")
    end

    direction = (direction + 3) % 4
end

local function face(target)
    while direction ~= target do
        turnRight()
    end
end

-- ================================================
-- FUEL MANAGEMENT
-- ================================================

local function getFuel()
    return turtle.getFuelLevel()
end

local function refuelTo(target)
    local fuel = getFuel()

    if fuel == "unlimited" then
        return true
    end

    for slot = 1, 16 do
        if fuel >= target then
            break
        end

        turtle.select(slot)

        while turtle.getItemCount(slot) > 0 do
            if getFuel() >= target then
                break
            end

            if not turtle.refuel(1) then
                break
            end
        end

        fuel = getFuel()
    end

    turtle.select(1)

    return getFuel() == "unlimited"
        or getFuel() >= target
end

local function distanceHome()
    return math.abs(x - HOME_X)
        + math.abs(y - HOME_Y)
        + math.abs(z - HOME_Z)
end

-- ================================================
-- INVENTORY MANAGEMENT
-- ================================================

local function isFuelSlot(slot)
    if turtle.getItemCount(slot) == 0 then
        return false
    end

    local previous = turtle.getSelectedSlot()

    turtle.select(slot)
    local result = turtle.refuel(0)

    turtle.select(previous)

    return result
end

local function inventoryStats()
    local empty = 0
    local nonFuel = 0

    for slot = 1, 16 do
        local count = turtle.getItemCount(slot)

        if count == 0 then
            empty = empty + 1
        elseif not isFuelSlot(slot) then
            nonFuel = nonFuel + count
        end
    end

    return empty, nonFuel
end

local function checkChest()
    local found, data = turtle.inspect()

    if not found then
        error("No chest detected behind turtle!")
    end

    local name = data.name or ""

    if not string.find(name, "chest", 1, true)
        and not string.find(name, "barrel", 1, true) 
        and not string.find(name, "backpack", 1, true) then
        error("Block behind turtle is not a chest or barrel!")
    end
end

local function unload()
    -- Original starting direction is forward.
    face(0)

    -- Turn around to face the chest.
    turnRight()
    turnRight()

    checkChest()

    print("Depositing inventory...")

    for slot = 1, 16 do
        if turtle.getItemCount(slot) > 0
            and not isFuelSlot(slot) then

            turtle.select(slot)

            local success, reason = turtle.drop()

            if not success and turtle.getItemCount(slot) > 0 then
                error("Chest full or unable to deposit: "
                    .. tostring(reason))
            end
        end
    end

    turtle.select(1)

    -- Restore original direction.
    turnRight()
    turnRight()

    print("Inventory deposited.")
end

-- ================================================
-- MOVEMENT
-- ================================================

local function moveForwardRaw()
    local attempts = 0

    while not turtle.forward() do
        attempts = attempts + 1

        if turtle.detect() then

            checkProtected(
                turtle.inspect,
                x .. "," .. y .. "," .. z
            )

            turtle.dig()

        else
            turtle.attack()
            sleep(0.2)
        end

        if attempts >= MAX_DIG_ATTEMPTS then
            error("Cannot move forward. Obstruction.")
        end
    end

    if direction == 0 then z = z + 1
    elseif direction == 1 then x = x + 1
    elseif direction == 2 then z = z - 1
    elseif direction == 3 then x = x - 1
    end
end

local function moveUpRaw()
    local attempts = 0

    while not turtle.up() do
        attempts = attempts + 1

        if turtle.detectUp() then

            checkProtected(
                turtle.inspectUp,
                x .. "," .. (y + 1) .. "," .. z
            )

            turtle.digUp()

        else
            turtle.attackUp()
            sleep(0.2)
        end

        if attempts >= MAX_DIG_ATTEMPTS then
            error("Cannot move up. Obstruction.")
        end
    end

    y = y + 1
end

local function moveDownRaw()
    local attempts = 0

    while not turtle.down() do
        attempts = attempts + 1

        if turtle.detectDown() then

            checkProtected(
                turtle.inspectDown,
                x .. "," .. (y - 1) .. "," .. z
            )

            turtle.digDown()

        else
            turtle.attackDown()
            sleep(0.2)
        end

        if attempts >= MAX_DIG_ATTEMPTS then
            error("Cannot move down. Obstruction.")
        end
    end

    y = y - 1
end

-- ================================================
-- SINGLE STEP NAVIGATION
-- ================================================

local function stepRaw(axis, amount)
    if axis == "x" then
        face(amount > 0 and 1 or 3)
        moveForwardRaw()

    elseif axis == "z" then
        face(amount > 0 and 0 or 2)
        moveForwardRaw()

    elseif axis == "y" then
        if amount > 0 then
            moveUpRaw()
        else
            moveDownRaw()
        end
    end
end

-- ================================================
-- SERVICE / UNLOADING
-- ================================================

local function service()
    if servicing then
        return
    end

    servicing = true

    local savedX = x
    local savedY = y
    local savedZ = z

    print("")
    print("=== SERVICE REQUIRED ===")
    print("Returning to chest...")

    -- Ensure enough fuel to reach home.
    local returnFuel = distanceHome() + FUEL_MARGIN

    if not refuelTo(returnFuel) then
        error("Insufficient fuel to return home! "
            .. "Insert more fuel.")
    end

    -- Route to home uses X, then Z, then Y.
    -- The exact reverse route is used to resume.
    local function moveHomeRaw()
        while x ~= HOME_X do
            stepRaw("x", HOME_X > x and 1 or -1)
        end

        while z ~= HOME_Z do
            stepRaw("z", HOME_Z > z and 1 or -1)
        end

        while y ~= HOME_Y do
            stepRaw("y", HOME_Y > y and 1 or -1)
        end
    end

    local function returnToSavedPosition()
        -- Reverse of the home route: Y, Z, X.
        while y ~= savedY do
            stepRaw("y", savedY > y and 1 or -1)
        end

        while z ~= savedZ do
            stepRaw("z", savedZ > z and 1 or -1)
        end

        while x ~= savedX do
            stepRaw("x", savedX > x and 1 or -1)
        end
    end

    moveHomeRaw()

    unload()

    -- Refuel at home.
    local targetFuel = math.max(
        FUEL_TARGET,
        math.abs(savedX) + math.abs(savedY)
            + math.abs(savedZ) + FUEL_MARGIN
    )

    refuelTo(targetFuel)

    -- Verify enough fuel to resume.
    local resumeDistance = math.abs(savedX)
        + math.abs(savedY)
        + math.abs(savedZ)

    if getFuel() ~= "unlimited"
        and getFuel() < resumeDistance + FUEL_MARGIN then
        error("Not enough fuel to resume mining!")
    end

    print("Resuming quarry...")

    returnToSavedPosition()

    servicing = false

    print("Back at mining position.")
    print("")
end

-- ================================================
-- INVENTORY AND FUEL CHECK
-- ================================================

local function ensureCapacity()
    if servicing then
        return
    end

    local fuel = getFuel()

    -- Return before fuel gets dangerously low.
    if fuel ~= "unlimited"
        and fuel <= distanceHome() + FUEL_MARGIN then
        service()
    end

    local empty, nonFuel = inventoryStats()

    -- Keep a few empty slots for unexpected drops.
    if empty <= INVENTORY_RESERVE and nonFuel > 0 then
        service()
    elseif empty <= 1 and nonFuel == 0 then
        error("Inventory occupied by fuel items. "
            .. "Remove some fuel stacks.")
    end
end

-- ================================================
-- SAFE MOVEMENT WITH AUTOMATIC SERVICE
-- ================================================

local function step(axis, amount)
    ensureCapacity()
    stepRaw(axis, amount)
end

local function moveTo(targetX, targetY, targetZ)
    -- X movement
    while x ~= targetX do
        step("x", targetX > x and 1 or -1)
    end

    -- Z movement
    while z ~= targetZ do
        step("z", targetZ > z and 1 or -1)
    end

    -- Y movement
    while y ~= targetY do
        step("y", targetY > y and 1 or -1)
    end
end

-- ================================================
-- QUARRY INFORMATION
-- ================================================

print("Checking fuel...")

if not refuelTo(100) then
    error("Insufficient starting fuel. Add fuel to turtle.")
end

print("Starting quarry...")
print("")

-- ================================================
-- MAIN QUARRY LOOP
-- ================================================

local mined = 0

for currentY = minY, maxY do

    print("Mining layer Y = " .. currentY)

    for xi = 0, sizeX - 1 do

        local currentX = minX + xi

        -- Serpentine Z movement.
        if xi % 2 == 0 then

            for currentZ = minZ, maxZ do

                moveTo(currentX, currentY, currentZ)

                mined = mined + 1

            end

        else

            for currentZ = maxZ, minZ, -1 do

                moveTo(currentX, currentY, currentZ)

                mined = mined + 1

            end

        end

    end

    print("Layer complete.")
    print("Blocks visited: " .. mined .. "/" .. totalBlocks)

end

-- ================================================
-- FINAL RETURN
-- ================================================

print("")
print("================================")
print("       QUARRY COMPLETE")
print("================================")

print("Returning to chest...")

-- Ensure enough fuel for final return.
if not refuelTo(distanceHome() + FUEL_MARGIN) then
    error("Not enough fuel for final return!")
end

-- Return to original starting position.
while x ~= HOME_X do
    stepRaw("x", HOME_X > x and 1 or -1)
end

while z ~= HOME_Z do
    stepRaw("z", HOME_Z > z and 1 or -1)
end

while y ~= HOME_Y do
    stepRaw("y", HOME_Y > y and 1 or -1)
end

unload()

print("")
print("ALL DONE!")
print("Blocks visited: " .. mined)
print("Turtle returned to starting position.")
