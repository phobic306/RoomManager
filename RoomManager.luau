local roomManager = {}

-- init variables

local serverStorage = game:GetService("ServerStorage")
local serverScriptService = game:GetService("ServerScriptService")

local tweenService = game:GetService("TweenService")

local mapBuilding = serverStorage.mapBuilding

local lightsOffWeight = 100
local numberCriteria = 1

local generatedMap = workspace:WaitForChild("generatedMap")
local numOfRooms = 0

local nextRoomsToGenerate = 2

-- These are the different "pools"
-- A pool in this context is basically a group of different rooms tiered by their rarity and placed into a single folder
-- As you see throughout the code, only startPool and commonPool are used as only those types of rooms were made at the time of this script

local startPool = mapBuilding.startPool
local commonPool = mapBuilding.commonPool
local rarePool = mapBuilding.rarePool
local extremelyRarePool = mapBuilding.extremelyRarePool

-- This is a table that holds all our generated rooms
local listOfRoomsTable = {}

-- This is a function to turn the lights on and off in a room.
local function handleLights(room: Instance, off: boolean)

	 -- Create a table for the lights to store
     local lights = {}

	 -- All lights are always named "light" in a room, so
     -- we can safely add them into the table
     for _, descendant in pairs(room:GetDescendants()) do
          if descendant.Name == "light" then
               table.insert(lights, descendant)
          end
     end

     -- debugging purposes
     print(lights)

     for _, light in pairs(lights) do
          for _, descendant in pairs(light:GetDescendants()) do
               if descendant:IsA("PointLight") then
                    descendant.Enabled = off

                    -- This conditional basically turns the light on and off.
                    if not off then
                         if descendant.Parent.Material == Enum.Material.Neon then
                              descendant.Parent.Material = Enum.Material.Plastic
                              descendant.Parent.Color = Color3.new(0.5, 0.5, 0.5) -- gray color
                         end
                    else
                         if  descendant.Parent.Material == Enum.Material.Plastic then
                              descendant.Parent.Material = Enum.Material.Neon
                              descendant.Parent.Color = Color3.fromRGB(202, 191, 163) -- white color
                         end
                    end
               end
               
               if descendant:IsA("Sound") then
                    descendant.Playing = off
               end
          end
     end
end

-- This function is to allow doors to be opened and closed.
local function handleDoor(door : Instance)
     -- We find the prompt in the door.
     local prompt
     for index, descendant in pairs(door:GetDescendants()) do
          if descendant:IsA("ProximityPrompt") then
               prompt = descendant
          end
     end

     if prompt then
          -- We create a listener
          prompt.Triggered:Connect(function()
               -- This attribute allows us to keep track if a door is being opened or not so doors can't be used while it's in an animation.
               local animationInProgress = door:GetAttribute("animationInProgress")

               if not animationInProgress then
                    door:SetAttribute("animationInProgress", false)
               else
                    if animationInProgress == true then return end
               end

               -- We use a hinge that is welded to the door to rotate the entire door.
               local hinge 
               for index, descendant in pairs(door:GetDescendants()) do
                    if descendant.Name == "Hinge" or descendant.Name == "hinge" then
                         hinge = descendant
                    end
               end

               -- We define our open/closing CFrames for the tween.
               local openGoal = {
                    CFrame = hinge.CFrame * CFrame.Angles(0, math.rad(-90), 0)
               }

               local closedGoal = {
                    CFrame = hinge.CFrame * CFrame.Angles(0, math.rad(90), 0)
               }

               local info = TweenInfo.new(1)

               -- Define the tweens
               local openTween = tweenService:Create(hinge, info, openGoal)
               local closeTween = tweenService:Create(hinge, info, closedGoal)

               -- Check whether or not the door is open.
               local openValue = door:GetAttribute("open")
               if not openValue then
                    door:SetAttribute("open", false)
               end

               -- Scrapped functionality: players have a door opening animation
               --local loadedInteractAnimation = humanoid.Animator:LoadAnimation(interactAnimation)
               --loadedInteractAnimation:Play()

               -- The function to open the door and set its attribute and play animation.
               local function openDoor()
                    openTween:Play()
                    door:SetAttribute("animationInProgress", true)
                    door:SetAttribute("open", true)
                    openTween.Completed:Wait()
                    door:SetAttribute("animationInProgress", false)
               end
               -- Function to close the door.
               local function closeDoor()
                    closeTween:Play()
                    door:SetAttribute("animationInProgress", true)
                    door:SetAttribute("open", false)
                    closeTween.Completed:Wait()
                    door:SetAttribute("animationInProgress", false)
               end

               -- Depending on whether or not the door is open, we call either 'openDoor()' or 'closeDoor()'
               if openValue == false then
                    openDoor()
               else
                    closeDoor()
               end

          end)
     else
          warn("There is no proximity prompt in room: "..numOfRooms.." || True name: "..door.Parent.Name)
     end
end

-- Since this is a room generation script that behavies similarly to Doors room generation, I added door signs
-- Door signs tell the player the next room number
-- The function below helps assign numbers to these door signs.
local function doorSign(doorSignCurrent : Instance, doorSignPrevious : Instance, room : Instance)
	 -- Each room has a door sign for the next room, and a door sign for the previous room.
     -- Door sign current is the sign telling the number of the next room
     if doorSignCurrent then
          doorSignCurrent.text.SurfaceGui.TextLabel.Text = numOfRooms
     else
          warn("Door Sign Current not found on room: "..numOfRooms.." || True name: "..room.Name)
     end

     -- Door sign previous is the sign telling the number of the previous room
     if doorSignPrevious then
          doorSignPrevious.text.SurfaceGui.TextLabel.Text = numOfRooms  - 1
     else
          warn("Door Sign Previous not found on room: "..numOfRooms.." || True name: "..room.Name)
     end
end

-- Each room has an anchored part that helps with aligning and attaching the rooms
-- This boolean below is just for debugging purposes.
local hideAlignments = true

-- This is the function to help attach the room to the last room.
local function positionRoom(room : Instance)
     local previousRoomNum = numOfRooms - 1
     -- Find the most recent room not including the current room
     local previousRoomInstance = generatedMap:FindFirstChild(previousRoomNum)
     if previousRoomInstance then
          -- Each room has a doorAlignment and door trigger
          -- doorAlignment is where the next room should be attached to
          -- doorTrigger spawns the next rooms when touched by the player.
          local doorAlignment = room:FindFirstChild("doorAlignment")
          local previousDoorTrigger = previousRoomInstance:FindFirstChild("doorTrigger")
          
          if doorAlignment then
               if  previousDoorTrigger then
                    if doorAlignment then
                         -- We set the primary part to the door alignment so that all pivots and rotations are about the doorAlignment
                         room.PrimaryPart = doorAlignment
                         
                         room:PivotTo(previousDoorTrigger.CFrame)
                         local doorTrigger = room:FindFirstChild("doorTrigger")
                         
                         if doorTrigger then
                              
                              
                              
                              setupDoorTrigger(doorTrigger)

                              -- Call the function so it creates the listener for the door to be opened and closed
                              local door = doorTrigger.Parent:FindFirstChild("door")
                              if door then
                                   handleDoor(door)
                              else
                                   warn("Door not present in room: "..numOfRooms.." || True name: "..room.Name)
                              end
                              
                              local doorSignCurrent, doorSignPrevious = room:FindFirstChild("doorSignCurrent"), room:FindFirstChild("doorSignPrevious")
                              -- Call the function to set the dooor sign numbers
                              doorSign(doorSignCurrent, doorSignPrevious, room)
                              
                              if hideAlignments then
                                   doorTrigger.Transparency = 1
                                   doorAlignment.Transparency = 1
                              end
                              

                              -- We insert the room into the table by the instance and its number.
                              table.insert(listOfRoomsTable, {roomInstance = room, roomNumber = numOfRooms})
                              

                              -- We start deleting rooms for performance once the player gets far enough
                              if numOfRooms > 10 then
                                   -- We add a little bit of randomization.
                                   if math.random(1,2) == 2 then
                                        roomManager.destroyOldestRoom()
                                   end
                              end
                              
                         else
                              warn("Please creat door trigger instacne on room: "..numOfRooms.." || True name: "..room.Name)
                         end
                    else
                         warn("Please set primary part as door alignment for proper positioning on room: "..numOfRooms.." || True name: "..room.Name)
                    end
               else
                    warn("Failed to find Door Trigger for alignment in previous room: "..previousRoomNum)
               end
          else
               warn("Failed to find Door Alignment Object in room: "..numOfRooms.." || True name: "..room.Name)
          end
     else
          warn("Failed to find previous room. Current room: "..numOfRooms.." || Previous room: "..numOfRooms)
     end
end

-- Small helper function, although it is redundant
local function positionObject(object : Instance, toPosition : Instance)
     object:PivotTo(toPosition.CFrame)
end


-------------
local misc = mapBuilding.misc
local lockers = misc.lockers



-------------

local smallLocker = lockers.smallLocker


-- Each room sometimes has spawn points for lockers
-- We loop through each spawn, and run a random number to see if we should spawn a locker or not.
local function handleMiscSpawns(room : Instance)

     -- smallLockerSpawns is a folder housing all the spawns
     local smallLockerSpawns = room:FindFirstChild("smallLockerSpawns")
     if smallLockerSpawns then
          
          for _, spawnPlacement in pairs(smallLockerSpawns:GetChildren()) do
               
               if math.random(1, 2) == 2 then
                    local clonedSmallLocker = smallLocker:Clone()
                    clonedSmallLocker.Parent = smallLockerSpawns
                    positionObject(clonedSmallLocker, spawnPlacement)
                    
                    handleDoor(clonedSmallLocker)
               end

               spawnPlacement:Destroy() -- destroy all placements except lockers so we know how many lockers are there
          end
          
     else
          warn("No Small Locker Spawns in room: "..numOfRooms.." || True name: "..room.Name)
     end
     
end

-- This is the function that helps creates new rooms upon touching the doorTrigger.
function setupDoorTrigger(doorTrigger : Instance)

     local touchedOnce = false
     if doorTrigger then
          doorTrigger.Touched:Connect(function(hit)
               -- Quick debounce check to prevent .Touched running multiple times
               if not touchedOnce then
                    touchedOnce = true

                    -- Create however many rooms based on nextRoomsToGenerate
                    for i = 1, nextRoomsToGenerate do
                         roomManager.createRandomRoom()
                    end
                    -- We alternate numbers to ensure randomization and that too many rooms aren't created constantly.
                    if nextRoomsToGenerate == 2 then
                         nextRoomsToGenerate = 1
                    elseif nextRoomsToGenerate == 1 then
                         -- A bit of math.random to ensure randomization.
                         nextRoomsToGenerate = math.random(1,2)
                    end
               end
          end)


     else
          warn("Please provide a valid doorTrigger")
     end

end

-- init module functions

-- This function destroys the oldest room
-- Utilizes destroyRoom function as a secondary function
roomManager.destroyOldestRoom = function()
     local oldestRoomData = listOfRoomsTable[1]  -- get the oldest room
     -- We run this conditional to make sure we aren't destroying a room too early when the player is not far enough
     -- Basically, there needs to be 6 rooms or more between the oldest room and the current room
     if oldestRoomData and (numOfRooms - oldestRoomData.roomNumber) >= 6 then
          table.remove(listOfRoomsTable, 1)
          roomManager.destroyRoom(oldestRoomData.roomNumber)
     end
end


-- This function just destroys a specified room
roomManager.destroyRoom = function(roomNum)
     local foundRoom = generatedMap:FindFirstChild(roomNum)
     if foundRoom then
          foundRoom:Destroy()
          print("Destroyed room: "..roomNum)
     else
          warn("Unable to find room: "..roomNum)
     end
end


local defaultPool = commonPool
local shouldDefaultToPool = true -- for testing purposes.. -- set to false after testing

-- This function creates a room
roomManager.createRoom = function(pool : StringValue, returnRoom : boolean)
     
     local poolFolder = pool or commonPool
     if poolFolder then
          
          
          local poolContents = poolFolder:GetChildren()

          -- Conditional to verify that a pool (folder) has rooms parented under it
          if #poolContents == 0 then
               warn("Pool is empty. Please add more rooms to the pool: "..pool)
               if shouldDefaultToPool then
                    poolContents = defaultPool:GetChildren()
               else
                    return
               end
          end

          -- We get a random room from the pool
          local randomRoom = poolContents[math.random(1, #poolContents)]
          if randomRoom then
               
               local clonedRandomRoom = randomRoom:Clone()
               clonedRandomRoom.Parent = generatedMap 

               -- Just a quick conditional to verify that there is actually a room to attach it to
               if numOfRooms > 0 then
                    positionRoom(clonedRandomRoom)
               end

               -- This conditional allows for some lights in some rooms to be off to create eerieness
               if (math.random(1, lightsOffWeight) <= numberCriteria) then
                    handleLights(clonedRandomRoom, false)
                    print("Turning off lights!")
               end
               -- As more rooms generate, the chances of encountering a dark room is greater
               lightsOffWeight -= 1
			
               -- this is to add more rooms without lights as the rooms progress more
               -- We set the numberCriteria to 12 so theres a higher chance of a dark room
               if numOfRooms >= 32 then
                    numberCriteria = 12
               end

               -- Call the locker spawning function
               handleMiscSpawns(clonedRandomRoom)

               -- We name each room by the number
               clonedRandomRoom.Name = numOfRooms
               print("Successfully generated Room: "..numOfRooms)
               numOfRooms += 1
               
               return clonedRandomRoom
          else
               warn("Unable to find a room. Please verify the inputs you are passing through.")
               return
          end
          
          
          
          
     else
          warn("Pool does not exist. Please enter a valid pool name. Pool options:  "..poolFolder.Name)
          return 
     end
     
     
     
end

-- This is the function to create a random room.
roomManager.createRandomRoom = function()
	print("Creating room from: "..commonPool.Name)
	roomManager.createRoom(commonPool, false)
end


-- Tihs creates the start room
-- Uses the createRoom function, but always uses startPool
roomManager.createStartRoom = function()
     local firstRoom = roomManager.createRoom(startPool, true)
     
     local doorTrigger = firstRoom:FindFirstChild("doorTrigger")
     -- Setup door trigger listener event
     if doorTrigger then
          setupDoorTrigger(doorTrigger)
          table.insert(listOfRoomsTable, {roomInstance = firstRoom, roomNumber = 0})
     else
          warn("please setup door trigger in first room")
     end
     
     return firstRoom
end

return roomManager

