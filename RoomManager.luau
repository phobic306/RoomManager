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

-- pools

local startPool = mapBuilding.startPool
local commonPool = mapBuilding.commonPool
local rarePool = mapBuilding.rarePool
local extremelyRarePool = mapBuilding.extremelyRarePool


local listOfRoomsTable = {}


local function handleLights(room: Instance, off: boolean)

     local lights = {}

     for _, descendant in pairs(room:GetDescendants()) do
          if descendant.Name == "light" then
               table.insert(lights, descendant)
          end
     end
     
     print(lights)

     for _, light in pairs(lights) do
          for _, descendant in pairs(light:GetDescendants()) do
               if descendant:IsA("PointLight") then
                    descendant.Enabled = off

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


local function handleDoor(door : Instance)
     local prompt
     for index, descendant in pairs(door:GetDescendants()) do
          if descendant:IsA("ProximityPrompt") then
               prompt = descendant
          end
     end
     if prompt then
          prompt.Triggered:Connect(function()
               local animationInProgress = door:GetAttribute("animationInProgress")

               if not animationInProgress then
                    door:SetAttribute("animationInProgress", false)
               else
                    if animationInProgress == true then return end
               end

               local hinge 
               for index, descendant in pairs(door:GetDescendants()) do
                    if descendant.Name == "Hinge" or descendant.Name == "hinge" then
                         hinge = descendant
                    end
               end

               local openGoal = {
                    CFrame = hinge.CFrame * CFrame.Angles(0, math.rad(-90), 0)
               }

               local closedGoal = {
                    CFrame = hinge.CFrame * CFrame.Angles(0, math.rad(90), 0)
               }

               local info = TweenInfo.new(1)

               local openTween = tweenService:Create(hinge, info, openGoal)
               local closeTween = tweenService:Create(hinge, info, closedGoal)

               local openValue = door:GetAttribute("open")
               if not openValue then
                    door:SetAttribute("open", false)
               end

               --local loadedInteractAnimation = humanoid.Animator:LoadAnimation(interactAnimation)
               --loadedInteractAnimation:Play()

               local function openDoor()
                    openTween:Play()
                    door:SetAttribute("animationInProgress", true)
                    door:SetAttribute("open", true)
                    openTween.Completed:Wait()
                    door:SetAttribute("animationInProgress", false)
               end

               local function closeDoor()
                    closeTween:Play()
                    door:SetAttribute("animationInProgress", true)
                    door:SetAttribute("open", false)
                    closeTween.Completed:Wait()
                    door:SetAttribute("animationInProgress", false)
               end

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


local function doorSign(doorSignCurrent : Instance, doorSignPrevious : Instance, room : Instance)
     if doorSignCurrent then
          doorSignCurrent.text.SurfaceGui.TextLabel.Text = numOfRooms
     else
          warn("Door Sign Current not found on room: "..numOfRooms.." || True name: "..room.Name)
     end


     if doorSignPrevious then
          doorSignPrevious.text.SurfaceGui.TextLabel.Text = numOfRooms  - 1
     else
          warn("Door Sign Previous not found on room: "..numOfRooms.." || True name: "..room.Name)
     end
end

local hideAlignments = true -- for testing purposes, set false after testing

local function positionRoom(room : Instance)
     local previousRoomNum = numOfRooms - 1
     local previousRoomInstance = generatedMap:FindFirstChild(previousRoomNum)
     if previousRoomInstance then
          local doorAlignment = room:FindFirstChild("doorAlignment")
          local previousDoorTrigger = previousRoomInstance:FindFirstChild("doorTrigger")
          
          if doorAlignment then
               if  previousDoorTrigger then
                    if doorAlignment then
                         room.PrimaryPart = doorAlignment
                         
                         room:PivotTo(previousDoorTrigger.CFrame)
                         local doorTrigger = room:FindFirstChild("doorTrigger")
                         
                         if doorTrigger then
                              
                              
                              
                              setupDoorTrigger(doorTrigger)
                              
                              local door = doorTrigger.Parent:FindFirstChild("door")
                              if door then
                                   handleDoor(door)
                              else
                                   warn("Door not present in room: "..numOfRooms.." || True name: "..room.Name)
                              end
                              
                              local doorSignCurrent, doorSignPrevious = room:FindFirstChild("doorSignCurrent"), room:FindFirstChild("doorSignPrevious")
                              doorSign(doorSignCurrent, doorSignPrevious, room)
                              
                              if hideAlignments then
                                   doorTrigger.Transparency = 1
                                   doorAlignment.Transparency = 1
                              end
                              
                              
                              table.insert(listOfRoomsTable, {roomInstance = room, roomNumber = numOfRooms})
                              
                              
                              if numOfRooms > 10 then
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

local function positionObject(object : Instance, toPosition : Instance)
     object:PivotTo(toPosition.CFrame)
end


-------------
local misc = mapBuilding.misc
local lockers = misc.lockers



-------------

local smallLocker = lockers.smallLocker


local function handleMiscSpawns(room : Instance)
     
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

function setupDoorTrigger(doorTrigger : Instance)

     local touchedOnce = false
     if doorTrigger then
          doorTrigger.Touched:Connect(function(hit)
               if not touchedOnce then
                    touchedOnce = true
                    
                    for i = 1, nextRoomsToGenerate do
                         roomManager.createRandomRoom()
                    end
                    if nextRoomsToGenerate == 2 then
                         nextRoomsToGenerate = 1
                    elseif nextRoomsToGenerate == 1 then
                         nextRoomsToGenerate = math.random(1,2)
                    end
               end
          end)


     else
          warn("Please provide a valid doorTrigger")
     end

end

-- init module functions

roomManager.destroyOldestRoom = function()
     local oldestRoomData = listOfRoomsTable[1]  -- get the oldest room
     if oldestRoomData and (numOfRooms - oldestRoomData.roomNumber) >= 6 then
          table.remove(listOfRoomsTable, 1)
          roomManager.destroyRoom(oldestRoomData.roomNumber)
     end
end



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

roomManager.createRoom = function(pool : StringValue, returnRoom : boolean)
     
     local poolFolder = pool or commonPool
     if poolFolder then
          
          
          local poolContents = poolFolder:GetChildren()
          
          if #poolContents == 0 then
               warn("Pool is empty. Please add more rooms to the pool: "..pool)
               if shouldDefaultToPool then
                    poolContents = defaultPool:GetChildren()
               else
                    return
               end
          end
          
          local randomRoom = poolContents[math.random(1, #poolContents)]
          if randomRoom then
               
               local clonedRandomRoom = randomRoom:Clone()
               clonedRandomRoom.Parent = generatedMap               
               if numOfRooms > 0 then
                    positionRoom(clonedRandomRoom)
               end
               
               if (math.random(1, lightsOffWeight) <= numberCriteria) then
                    handleLights(clonedRandomRoom, false)
                    print("Turning off lights!")
               end
               
               lightsOffWeight -= 1
			
				-- this is to add more rooms without lights as the rooms progress more
               if numOfRooms >= 32 then
                    numberCriteria = 12
               end
               
               handleMiscSpawns(clonedRandomRoom)
               
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

roomManager.createRandomRoom = function()
	print("Creating room from: "..commonPool.Name)
	roomManager.createRoom(commonPool, false)
end


roomManager.createStartRoom = function()
     local firstRoom = roomManager.createRoom(startPool, true)
     
     local doorTrigger = firstRoom:FindFirstChild("doorTrigger")
     if doorTrigger then
          setupDoorTrigger(doorTrigger)
          table.insert(listOfRoomsTable, {roomInstance = firstRoom, roomNumber = 0})
     else
          warn("please setup door trigger in first room")
     end
     
     return firstRoom
end

return roomManager
