local utf8 = require("utf8")

-- LÖVE 2D 다마고치 캐릭터 테스트용 main.lua
-- Tab 키로 세로 모드(450x800)와 가로 모드(800x450)를 전환합니다.
-- 방향키로 캐릭터를 움직이고, 오른쪽으로 갈 때는 character_sheet_right.png를 사용합니다.
-- 마우스 드래그, 가속도 없는 등속 낙하 착지, 레터박스 스케일링, 크로마키를 함께 유지합니다.

-- 세로 모드와 가로 모드의 기준 가상 해상도입니다.
local ORIENTATION = {
    portrait = {
        name = "세로 모드",
        width = 450,
        height = 800
    },
    landscape = {
        name = "가로 모드",
        width = 800,
        height = 450
    }
}

-- 현재 켜져 있는 화면 모드입니다. PC 테스트는 가로 모드로 시작하고, Tab 키로 세로 9:16 모드를 확인합니다.
local currentOrientation = "landscape"

-- 현재 모드에서 사용하는 가상 해상도입니다.
local virtualWidth = ORIENTATION[currentOrientation].width
local virtualHeight = ORIENTATION[currentOrientation].height

-- 화면에 보이는 영역과 별개로, 캐릭터가 실제로 돌아다닐 수 있는 방 전체 크기입니다.
-- 가로 모드는 화면과 같은 800x450, 세로 모드는 카메라로 800x800 방을 따라가게 만듭니다.
local roomWorldWidth = virtualWidth
local roomWorldHeight = virtualHeight

-- 실제 창에 가상 화면을 그릴 때 필요한 스케일과 레터박스 위치입니다.
local screen = {
    scale = 1,
    offsetX = 0,
    offsetY = 0
}

-- 세로 모드에서 캐릭터를 더 크게 보여주고 따라가기 위한 2D 카메라입니다.
local camera = {
    x = virtualWidth * 0.5,
    y = virtualHeight * 0.5,
    zoom = 1,
    -- 세로 모드도 동일한 800x450 방을 보여주므로 세로 화면 높이를
    -- 방 높이 안에 채울 수 있는 배율을 사용합니다.
    portraitZoom = 1.80,
    followLerp = 10
}

-- 캐릭터가 차지하는 영역입니다.
-- x, y, width, height는 모두 현재 가상 해상도 기준 좌표입니다.
local character = {
    x = 175,
    y = 250,
    width = 100,
    height = 150,
    isDragging = false,
    isLanded = false,
    dragOffsetX = 0,
    dragOffsetY = 0,
    dragDepthScale = 1.0,
    dragShadowFootX = 0,
    dragShadowFootY = 0,
    dragShadowFadeDistance = 140,
    fallTargetY = nil,
    baseFallSpeed = 900,
    fallSpeed = 900,
    maxFallSpeed = 1800,
    moveSpeed = 175,
    isMovingToTarget = false,
    targetX = 0,
    targetY = 0,
    movePath = nil,
    movePathIndex = 1,
    targetStopDistance = 4,
    minDepthScale = 0.58,
    maxDepthScale = 1.0
}

-- 좌우 스프라이트 애니메이션 정보입니다.
-- 왼쪽 시트는 현재 character_sheet.png, 오른쪽 시트는 character_sheet_right.png를 사용합니다.
local sprite = {
    frameWidth = 200,
    frameHeight = 300,
    frameTime = 0.15,
    timer = 0,
    currentFrame = 1,
    currentAnimation = "left",
    isMovingByKeyboard = false,
    animations = {
        left = {
            label = "left",
            fileName = "character_sheet.png",
            image = nil,
            quads = {},
            frameCount = 8,
            frameTime = 0.10,
            isLoaded = false
        },
        right = {
            label = "right",
            fileName = "character_sheet_right.png",
            image = nil,
            quads = {},
            frameCount = 8,
            frameTime = 0.10,
            isLoaded = false
        },
        front = {
            label = "front",
            fileName = "character_sheet_front.png",
            image = nil,
            quads = {},
            frameCount = 8,
            frameTime = 0.075,
            isLoaded = false
        },
        back = {
            label = "back",
            fileName = "character_sheet_back.png",
            image = nil,
            quads = {},
            frameCount = 8,
            frameTime = 0.075,
            isLoaded = false
        },
        drag = {
            label = "drag",
            fileName = "character_sheet_drag.png",
            image = nil,
            quads = {},
            frameCount = 4,
            frameTime = 0.13,
            isLoaded = false
        }
    }
}

-- 초록색 배경을 투명하게 만들 픽셀 셰이더입니다.
local chromaKeyShader = nil
local chromaKeyShaderReady = false
local roomBackgroundImage = nil

local backgroundLibrary = {
    folder = "room_backgrounds",
    activePath = nil,
    previewPath = nil,
    loadedPath = nil,
    selectedIndex = 1,
    items = {}
}

local ui = {
    isMenuOpen = false,
    isInteriorOpen = false,
    isChatOpen = false,
    activeInteriorTab = "backgrounds",
    backgroundScrollX = 0,
    isBackgroundListDragging = false,
    backgroundDragLastX = 0
}

local chat = {
    input = "",
    messages = {},
    isSending = false,
    threadErrorShown = false,
    thread = nil,
    requestChannel = nil,
    responseChannel = nil
}

local furnitureLibrary = {
    selectedIndex = 1,
    items = {
        {
            id = "bed",
            label = "Bed",
            fileName = "furniture/bed.png",
            image = nil,
            isLoaded = false,
            width = 190,
            height = 130,
            minDepthScale = 0.50,
            maxDepthScale = 0.90,
            visualHeightScale = 1.28,
            collisionInsetX = 0.14,
            collisionTopPadding = 0.24,
            collisionBottomPadding = 0.04
        },
        {
            id = "window",
            label = "Window",
            fileName = "furniture/window.png",
            image = nil,
            isLoaded = false,
            width = 280,
            height = 154,
            minDepthScale = 1.0,
            maxDepthScale = 1.0,
            visualHeightScale = 1.0,
            defaultY = 18,
            wallMounted = true,
            blocksMovement = false,
            renderBehind = true
        }
    }
}

local placedFurniture = {}
local furnitureDrag = {
    item = nil,
    offsetX = 0,
    offsetY = 0
}
local furnitureEdit = {
    selectedItem = nil,
    isSizing = false,
    sizeStep = 10,
    minWidth = 90,
    maxWidth = 320,
    lastCopiedText = ""
}

local floorArea = {
    topRatio = 0.40,
    defaultTopRatio = 0.40,
    spriteFootPadding = 24,
    ratios = {
        ["room_backgrounds/KakaoTalk_20260710_012611856_01.png"] = 0.440,
        ["room_backgrounds/KakaoTalk_20260710_012611856_02.png"] = 0.440,
        ["room_backgrounds/KakaoTalk_20260710_012611856_03.png"] = 0.445,
        ["room_backgrounds/KakaoTalk_20260710_012611856_04.png"] = 0.485,
        ["room_backgrounds/KakaoTalk_20260710_012611856_05.png"] = 0.505
    }
}

local floorDebug = {
    enabled = false,
    step = 0.005,
    lastCopiedText = ""
}

local clampCharacterToVirtualScreen
local updateFallSpeedFromHeight
local buildCharacterPath

-- 숫자 value를 minValue와 maxValue 사이로 제한합니다.
local function clamp(value, minValue, maxValue)
    return math.max(minValue, math.min(value, maxValue))
end

-- 현재 모드의 가상 화면 바닥 y좌표를 계산합니다.
local function getWorldFloorY()
    return roomWorldHeight - character.height
end

local function getFloorTopY()
    return roomWorldHeight * floorArea.topRatio
end

local function getMinCharacterFloorY()
    return getFloorTopY() - character.height + floorArea.spriteFootPadding
end

local function getFloorY()
    return character.fallTargetY or (roomWorldHeight - character.height)
end

local function getCurrentBackgroundPath()
    return backgroundLibrary.previewPath or backgroundLibrary.activePath or "unknown_background"
end

local function applyFloorRatioForBackground(backgroundPath)
    floorArea.topRatio = floorArea.ratios[backgroundPath] or floorArea.defaultTopRatio
end

local function buildFloorClipboardText()
    local path = getCurrentBackgroundPath()
    return string.format("[\"%s\"] = %.3f,", path, floorArea.topRatio)
end

local function adjustFloorRatio(amount)
    floorDebug.enabled = true
    floorArea.topRatio = clamp(floorArea.topRatio + amount, 0.20, 0.80)
    floorArea.ratios[getCurrentBackgroundPath()] = floorArea.topRatio
    character.fallTargetY = nil
    clampCharacterToVirtualScreen()
    updateFallSpeedFromHeight()
end

-- 현재 실제 창 크기에 맞춰 가상 화면의 스케일과 레터박스 위치를 계산합니다.
local function updateScreenScale()
    local windowWidth = love.graphics.getWidth()
    local windowHeight = love.graphics.getHeight()

    local scaleX = windowWidth / virtualWidth
    local scaleY = windowHeight / virtualHeight

    -- 가로와 세로 중 더 작은 배율을 사용해야 현재 가상 해상도 비율이 깨지지 않습니다.
    screen.scale = math.min(scaleX, scaleY)

    -- 남는 공간은 검은색 레터박스로 보이도록 가상 화면을 중앙에 배치합니다.
    screen.offsetX = (windowWidth - virtualWidth * screen.scale) / 2
    screen.offsetY = (windowHeight - virtualHeight * screen.scale) / 2
end

-- 현재 화면 모드에 맞춰 방 전체 월드 크기를 갱신합니다.
local function updateRoomWorldSize()
    -- 가로/세로 모드는 같은 방을 서로 다른 뷰포트로 바라봅니다.
    -- 월드 크기를 방향마다 바꾸면 동일한 가구 Y 좌표의 깊이 비율이
    -- 달라지고, 세로 전환 시 clamp가 실제 좌표까지 변경하게 됩니다.
    roomWorldWidth = ORIENTATION.landscape.width
    roomWorldHeight = ORIENTATION.landscape.height
end

-- 실제 창 좌표를 현재 모드의 가상 화면 좌표로 변환합니다.
local function windowToVirtual(windowX, windowY)
    local virtualX = (windowX - screen.offsetX) / screen.scale
    local virtualY = (windowY - screen.offsetY) / screen.scale

    return virtualX, virtualY
end

-- 현재 화면 모드에 맞는 카메라 줌 값을 가져옵니다.
local function getCameraTargetZoom()
    if currentOrientation == "portrait" then
        return camera.portraitZoom
    end

    return 1
end

-- 카메라 중심이 월드 밖으로 지나치게 나가지 않도록 제한합니다.
local function clampCameraToWorld()
    local halfWidth = virtualWidth / (camera.zoom * 2)
    local halfHeight = virtualHeight / (camera.zoom * 2)

    if halfWidth * 2 >= roomWorldWidth then
        camera.x = roomWorldWidth * 0.5
    else
        camera.x = clamp(camera.x, halfWidth, roomWorldWidth - halfWidth)
    end

    if halfHeight * 2 >= roomWorldHeight then
        camera.y = roomWorldHeight * 0.5
    else
        camera.y = clamp(camera.y, halfHeight, roomWorldHeight - halfHeight)
    end
end

-- 실제 창 좌표를 카메라가 적용된 월드 좌표로 변환합니다.
local function windowToWorld(windowX, windowY)
    local virtualX, virtualY = windowToVirtual(windowX, windowY)

    if currentOrientation ~= "portrait" then
        return virtualX, virtualY
    end

    local worldX = (virtualX - virtualWidth * 0.5) / camera.zoom + camera.x
    local worldY = (virtualY - virtualHeight * 0.5) / camera.zoom + camera.y

    return worldX, worldY
end

-- 좌표가 현재 가상 화면 안에 있는지 확인합니다.
local function isInsideVirtualScreen(virtualX, virtualY)
    return virtualX >= 0
        and virtualX <= roomWorldWidth
        and virtualY >= 0
        and virtualY <= roomWorldHeight
end

-- 실제로 보이는 9:16/16:9 가상 화면 안쪽인지 확인합니다.
local function isInsideViewport(virtualX, virtualY)
    return virtualX >= 0
        and virtualX <= virtualWidth
        and virtualY >= 0
        and virtualY <= virtualHeight
end

-- 캐릭터가 현재 가상 화면 밖으로 사라지지 않도록 제한합니다.
function clampCharacterToVirtualScreen()
    character.x = clamp(character.x, 0, roomWorldWidth - character.width)
    local minY = getMinCharacterFloorY()

    if character.isDragging then
        minY = 0
    end

    character.y = clamp(character.y, minY, getWorldFloorY())

    -- 바닥에 닿아 있으면 착지 상태로 표시합니다.
    character.isLanded = character.y >= getFloorY()
end

-- 캐릭터를 높은 곳에서 놓을수록 더 빠르게 떨어지도록 낙하 속도를 계산합니다.
function updateFallSpeedFromHeight()
    local floorY = getFloorY()
    local fallDistance = math.max(0, floorY - character.y)
    local heightRatio = 0

    if floorY > 0 then
        heightRatio = fallDistance / floorY
    end

    character.fallSpeed = character.baseFallSpeed
        + (character.maxFallSpeed - character.baseFallSpeed) * heightRatio
end

-- 발 위치가 화면 아래쪽에 가까울수록 앞쪽, 위쪽에 가까울수록 뒤쪽으로 판단합니다.
local function getCharacterDepthRatio()
    local effectiveY = character.y

    -- 드래그 중 위로 들어올린 움직임은 깊이 이동으로 보지 않고,
    -- 앞으로 끌어내린 움직임만 깊이 이동으로 반영합니다.
    if character.isDragging and character.fallTargetY then
        effectiveY = math.max(character.y, character.fallTargetY)
    end

    local footY = effectiveY + character.height
    local farFootY = getFloorTopY()
    local nearFootY = roomWorldHeight

    return clamp((footY - farFootY) / (nearFootY - farFootY), 0, 1)
end

-- 2D 화면에서 z좌표처럼 보이도록 깊이에 따라 캐릭터 크기를 계산합니다.
local function getCharacterDepthScale()
    local depthRatio = getCharacterDepthRatio()
    return character.minDepthScale
        + (character.maxDepthScale - character.minDepthScale) * depthRatio
end

-- 캐릭터는 발바닥 위치를 기준으로 축소/확대됩니다.
local function getCharacterVisualBounds()
    local depthScale = getCharacterDepthScale()
    local visualWidth = character.width * depthScale
    local visualHeight = character.height * depthScale
    local footX = character.x + character.width * 0.5
    local footY = character.y + character.height

    return {
        x = footX - visualWidth * 0.5,
        y = footY - visualHeight,
        width = visualWidth,
        height = visualHeight,
        footX = footX,
        footY = footY,
        scale = depthScale
    }
end

-- 세로 모드에서는 캐릭터 중심을 따라가고, 가로 모드에서는 기본 전체 화면으로 돌아옵니다.
local function updateCamera(dt, snap)
    camera.zoom = getCameraTargetZoom()

    local targetX = roomWorldWidth * 0.5
    local targetY = roomWorldHeight * 0.5

    if currentOrientation == "portrait" then
        local bounds = getCharacterVisualBounds()
        targetX = bounds.footX
        targetY = bounds.y + bounds.height * 0.48
    end

    if snap then
        camera.x = targetX
        camera.y = targetY
    else
        local followAmount = clamp(dt * camera.followLerp, 0, 1)
        camera.x = camera.x + (targetX - camera.x) * followAmount
        camera.y = camera.y + (targetY - camera.y) * followAmount
    end

    clampCameraToWorld()
end

-- 가상 좌표 기준으로 포인터가 캐릭터 영역 안에 있는지 확인합니다.
local function isPointerInsideCharacter(pointerX, pointerY)
    local bounds = getCharacterVisualBounds()

    return pointerX >= bounds.x
        and pointerX <= bounds.x + bounds.width
        and pointerY >= bounds.y
        and pointerY <= bounds.y + bounds.height
end

-- 빈 바닥을 누르면 캐릭터의 발 위치가 그 지점으로 가도록 목표를 설정합니다.
local function setMoveTarget(pointerX, pointerY)
    character.fallTargetY = nil
    local destinationX = clamp(pointerX - character.width * 0.5, 0, roomWorldWidth - character.width)
    local destinationY = clamp(pointerY - character.height, getMinCharacterFloorY(), getFloorY())
    local path = buildCharacterPath(character.x, character.y, destinationX, destinationY)

    character.movePath = path
    character.movePathIndex = 1

    if path and #path > 0 then
        character.targetX = path[1].x
        character.targetY = path[1].y
        character.isMovingToTarget = true
    else
        character.isMovingToTarget = false
    end

    character.isLanded = true
end

local function clampFurnitureToRoom(item)
    item.x = clamp(item.x, 0, roomWorldWidth - item.width)

    if item.wallMounted then
        -- 벽 장식은 이미지 전체가 벽 영역 안에 남도록 제한합니다.
        local maxWallY = math.max(0, getFloorTopY() - item.height)
        item.y = clamp(item.y, 0, maxWallY)
    else
        item.y = clamp(item.y, getFloorTopY() - item.height, roomWorldHeight - item.height)
    end
end

local function getFurnitureDepthRatio(item)
    local footY = item.y + item.height
    local farFootY = getFloorTopY()
    local nearFootY = roomWorldHeight

    return clamp((footY - farFootY) / (nearFootY - farFootY), 0, 1)
end

local function getFurnitureDepthScale(item)
    local minScale = item.minDepthScale or 0.50
    local maxScale = item.maxDepthScale or 0.90
    local depthRatio = getFurnitureDepthRatio(item)

    return minScale + (maxScale - minScale) * depthRatio
end

local function getFurnitureVisualBounds(item)
    local depthScale = getFurnitureDepthScale(item)
    local visualHeightScale = item.visualHeightScale or 1.0
    local visualWidth = item.width * depthScale
    local visualHeight = item.height * depthScale * visualHeightScale
    local footX = item.x + item.width * 0.5
    local footY = item.y + item.height

    return {
        x = footX - visualWidth * 0.5,
        y = footY - visualHeight,
        width = visualWidth,
        height = visualHeight,
        footX = footX,
        footY = footY,
        scale = depthScale
    }
end

local function getFurnitureDeleteButtonRect(item)
    local bounds = getFurnitureVisualBounds(item)
    local size = 24 / math.max(0.5, bounds.scale)

    return {
        x = bounds.x + bounds.width - size * 0.55,
        y = bounds.y - size * 0.45,
        width = size,
        height = size
    }
end

local function getFurnitureSizeButtonRects(item)
    local bounds = getFurnitureVisualBounds(item)
    local buttonSize = 24 / math.max(0.5, bounds.scale)
    local gap = 6 / math.max(0.5, bounds.scale)
    local y = bounds.y + bounds.height + gap
    local minusX = bounds.x + bounds.width * 0.5 - buttonSize - gap * 0.5
    local plusX = bounds.x + bounds.width * 0.5 + gap * 0.5

    return {
        minus = {x = minusX, y = y, width = buttonSize, height = buttonSize},
        plus = {x = plusX, y = y, width = buttonSize, height = buttonSize}
    }
end

local function setFurnitureWidth(item, newWidth)
    if not item then
        return
    end

    local footX = item.x + item.width * 0.5
    local footY = item.y + item.height

    item.width = clamp(newWidth, furnitureEdit.minWidth, furnitureEdit.maxWidth)

    if item.image then
        item.height = item.width * item.image:getHeight() / item.image:getWidth()
    end

    item.x = footX - item.width * 0.5
    item.y = footY - item.height
    clampFurnitureToRoom(item)
end

local function buildFurnitureClipboardText(item)
    if not item then
        return ""
    end

    return string.format(
        "[\"%s\"] = { width = %.1f, height = %.1f, visualHeightScale = %.2f },",
        item.id,
        item.width,
        item.height,
        item.visualHeightScale or 1.0
    )
end

local function clampAllFurnitureToRoom()
    for _, item in ipairs(placedFurniture) do
        clampFurnitureToRoom(item)
    end
end

local function removePlacedFurniture(targetItem)
    for index = #placedFurniture, 1, -1 do
        if placedFurniture[index] == targetItem then
            table.remove(placedFurniture, index)
            break
        end
    end

    if furnitureEdit.selectedItem == targetItem then
        furnitureEdit.selectedItem = nil
        furnitureEdit.isSizing = false
    end

    if furnitureDrag.item == targetItem then
        furnitureDrag.item = nil
    end
end

local function addFurnitureToRoom(libraryItem)
    if not libraryItem or not libraryItem.isLoaded then
        return nil
    end

    for _, item in ipairs(placedFurniture) do
        if item.id == libraryItem.id then
            item.width = libraryItem.width
            item.height = libraryItem.height
            item.minDepthScale = libraryItem.minDepthScale
            item.maxDepthScale = libraryItem.maxDepthScale
            item.visualHeightScale = libraryItem.visualHeightScale
            item.collisionInsetX = libraryItem.collisionInsetX
            item.collisionTopPadding = libraryItem.collisionTopPadding
            item.collisionBottomPadding = libraryItem.collisionBottomPadding
            item.wallMounted = libraryItem.wallMounted
            item.blocksMovement = libraryItem.blocksMovement
            item.renderBehind = libraryItem.renderBehind
            clampFurnitureToRoom(item)
            return item
        end
    end

    local placedItem = {
        id = libraryItem.id,
        label = libraryItem.label,
        image = libraryItem.image,
        x = roomWorldWidth * 0.5 - libraryItem.width * 0.5,
        y = libraryItem.defaultY or (roomWorldHeight - libraryItem.height),
        width = libraryItem.width,
        height = libraryItem.height,
        minDepthScale = libraryItem.minDepthScale,
        maxDepthScale = libraryItem.maxDepthScale,
        visualHeightScale = libraryItem.visualHeightScale,
        collisionInsetX = libraryItem.collisionInsetX,
        collisionTopPadding = libraryItem.collisionTopPadding,
        collisionBottomPadding = libraryItem.collisionBottomPadding,
        wallMounted = libraryItem.wallMounted,
        blocksMovement = libraryItem.blocksMovement,
        renderBehind = libraryItem.renderBehind
    }

    clampFurnitureToRoom(placedItem)
    table.insert(placedFurniture, placedItem)
    return placedItem
end

local function findFurnitureAt(worldX, worldY)
    for index = #placedFurniture, 1, -1 do
        local item = placedFurniture[index]
        local bounds = getFurnitureVisualBounds(item)

        if worldX >= bounds.x
            and worldX <= bounds.x + bounds.width
            and worldY >= bounds.y
            and worldY <= bounds.y + bounds.height then
            return item
        end
    end

    return nil
end

local function isPointOnPlacedFurniture(worldX, worldY)
    for _, item in ipairs(placedFurniture) do
        if item.blocksMovement ~= false then
            local bounds = getFurnitureVisualBounds(item)
            local marginX = bounds.width * (item.collisionInsetX or 0.02)
            local topPadding = bounds.height * (item.collisionTopPadding or 0.03)
            local bottomPadding = bounds.height * (item.collisionBottomPadding or 0)

            if worldX >= bounds.x + marginX
                and worldX <= bounds.x + bounds.width - marginX
                and worldY >= bounds.y + topPadding
                and worldY <= bounds.y + bounds.height - bottomPadding then
                return true
            end
        end
    end

    return false
end

local function doRectsOverlap(aX, aY, aWidth, aHeight, bX, bY, bWidth, bHeight)
    return aX < bX + bWidth
        and aX + aWidth > bX
        and aY < bY + bHeight
        and aY + aHeight > bY
end

local function isRectOnPlacedFurniture(rectX, rectY, rectWidth, rectHeight)
    for _, item in ipairs(placedFurniture) do
        if item.blocksMovement ~= false then
            local bounds = getFurnitureVisualBounds(item)
            local marginX = bounds.width * (item.collisionInsetX or 0.02)
            local topPadding = bounds.height * (item.collisionTopPadding or 0.03)
            local bottomPadding = bounds.height * (item.collisionBottomPadding or 0)
            local blockX = bounds.x + marginX
            local blockY = bounds.y + topPadding
            local blockWidth = bounds.width - marginX * 2
            local blockHeight = bounds.height - topPadding - bottomPadding

            if doRectsOverlap(rectX, rectY, rectWidth, rectHeight, blockX, blockY, blockWidth, blockHeight) then
                return true
            end
        end
    end

    return false
end

local function isCharacterOnPlacedFurnitureAt(characterX, characterY)
    local footX = characterX + character.width * 0.5
    local footY = characterY + character.height
    local farFootY = getFloorTopY()
    local nearFootY = roomWorldHeight
    local depthRatio = clamp((footY - farFootY) / (nearFootY - farFootY), 0, 1)
    local depthScale = character.minDepthScale + (character.maxDepthScale - character.minDepthScale) * depthRatio
    local footWidth = character.width * depthScale * 0.88
    local footHeight = 34 * depthScale
    local footRectX = footX - footWidth * 0.5
    local footRectY = footY - footHeight

    return isRectOnPlacedFurniture(footRectX, footRectY, footWidth, footHeight)
end

local function isCharacterPathSegmentClear(fromX, fromY, toX, toY)
    local deltaX = toX - fromX
    local deltaY = toY - fromY
    local distance = math.sqrt(deltaX * deltaX + deltaY * deltaY)
    local sampleCount = math.max(1, math.ceil(distance / 8))

    for index = 1, sampleCount do
        local ratio = index / sampleCount
        local sampleX = fromX + deltaX * ratio
        local sampleY = fromY + deltaY * ratio

        if isCharacterOnPlacedFurnitureAt(sampleX, sampleY) then
            return false
        end
    end

    return true
end


buildCharacterPath = function(startX, startY, destinationX, destinationY)
    if isCharacterOnPlacedFurnitureAt(destinationX, destinationY) then
        return nil
    end

    if isCharacterPathSegmentClear(startX, startY, destinationX, destinationY) then
        return {{x = destinationX, y = destinationY}}
    end

    local gridSize = 20
    local minX = 0
    local maxX = roomWorldWidth - character.width
    local minY = getMinCharacterFloorY()
    local maxY = getFloorY()
    local columnCount = math.floor((maxX - minX) / gridSize) + 1
    local rowCount = math.floor((maxY - minY) / gridSize) + 1

    local function gridKey(column, row)
        return row * columnCount + column
    end

    local function gridPosition(column, row)
        return minX + column * gridSize, minY + row * gridSize
    end

    local function nearestGrid(value, minimum, count)
        return clamp(math.floor((value - minimum) / gridSize + 0.5), 0, count - 1)
    end

    local startColumn = nearestGrid(startX, minX, columnCount)
    local startRow = nearestGrid(startY, minY, rowCount)
    local endColumn = nearestGrid(destinationX, minX, columnCount)
    local endRow = nearestGrid(destinationY, minY, rowCount)
    local startKey = gridKey(startColumn, startRow)
    local endKey = gridKey(endColumn, endRow)
    local open = {{column = startColumn, row = startRow, key = startKey, g = 0, f = 0}}
    local openByKey = {[startKey] = open[1]}
    local closed = {}
    local parents = {}
    local costs = {[startKey] = 0}
    local directions = {
        {-1, 0, 1}, {1, 0, 1}, {0, -1, 1}, {0, 1, 1},
        {-1, -1, 1.414}, {1, -1, 1.414}, {-1, 1, 1.414}, {1, 1, 1.414}
    }

    while #open > 0 do
        local bestIndex = 1
        for index = 2, #open do
            if open[index].f < open[bestIndex].f then
                bestIndex = index
            end
        end

        local current = table.remove(open, bestIndex)
        openByKey[current.key] = nil

        if current.key == endKey then
            local reversed = {}
            local cursorKey = endKey

            while cursorKey and cursorKey ~= startKey do
                local column = cursorKey % columnCount
                local row = math.floor(cursorKey / columnCount)
                local pointX, pointY = gridPosition(column, row)
                table.insert(reversed, {x = pointX, y = pointY})
                cursorKey = parents[cursorKey]
            end

            local rawPath = {}
            for index = #reversed, 1, -1 do
                table.insert(rawPath, reversed[index])
            end
            table.insert(rawPath, {x = destinationX, y = destinationY})

            local smoothedPath = {}
            local anchorX = startX
            local anchorY = startY
            local candidateIndex = 1

            while candidateIndex <= #rawPath do
                local farthestIndex = candidateIndex
                for index = #rawPath, candidateIndex, -1 do
                    if isCharacterPathSegmentClear(anchorX, anchorY, rawPath[index].x, rawPath[index].y) then
                        farthestIndex = index
                        break
                    end
                end

                local waypoint = rawPath[farthestIndex]
                table.insert(smoothedPath, waypoint)
                anchorX = waypoint.x
                anchorY = waypoint.y
                candidateIndex = farthestIndex + 1
            end

            return smoothedPath
        end

        closed[current.key] = true

        for _, direction in ipairs(directions) do
            local nextColumn = current.column + direction[1]
            local nextRow = current.row + direction[2]

            if nextColumn >= 0 and nextColumn < columnCount and nextRow >= 0 and nextRow < rowCount then
                local nextKey = gridKey(nextColumn, nextRow)
                local nextX, nextY = gridPosition(nextColumn, nextRow)

                if not closed[nextKey] and not isCharacterOnPlacedFurnitureAt(nextX, nextY) then
                    local diagonal = direction[1] ~= 0 and direction[2] ~= 0
                    local cornerIsClear = true

                    if diagonal then
                        local sideAX, sideAY = gridPosition(current.column + direction[1], current.row)
                        local sideBX, sideBY = gridPosition(current.column, current.row + direction[2])
                        cornerIsClear = not isCharacterOnPlacedFurnitureAt(sideAX, sideAY)
                            and not isCharacterOnPlacedFurnitureAt(sideBX, sideBY)
                    end

                    if cornerIsClear then
                        local newCost = current.g + direction[3]
                        if not costs[nextKey] or newCost < costs[nextKey] then
                            costs[nextKey] = newCost
                            parents[nextKey] = current.key
                            local heuristicX = endColumn - nextColumn
                            local heuristicY = endRow - nextRow
                            local heuristic = math.sqrt(heuristicX * heuristicX + heuristicY * heuristicY)
                            local node = openByKey[nextKey]

                            if node then
                                node.g = newCost
                                node.f = newCost + heuristic
                            else
                                node = {
                                    column = nextColumn,
                                    row = nextRow,
                                    key = nextKey,
                                    g = newCost,
                                    f = newCost + heuristic
                                }
                                table.insert(open, node)
                                openByKey[nextKey] = node
                            end
                        end
                    end
                end
            end
        end
    end

    return nil
end

-- 현재 모드 이름을 사람이 읽기 쉬운 문자열로 가져옵니다.
local function getOrientationName()
    return ORIENTATION[currentOrientation].name
end

-- 현재 선택된 애니메이션 정보를 가져옵니다.
local function getCurrentAnimation()
    return sprite.animations[sprite.currentAnimation]
end

-- 현재 재생할 애니메이션을 바꿉니다.
local function setCurrentAnimation(animationName)
    if not sprite.animations[animationName] then
        return
    end

    if sprite.currentAnimation ~= animationName then
        sprite.currentAnimation = animationName
        sprite.currentFrame = 1
        sprite.timer = 0
    end
end

-- 이동 벡터에서 더 크게 움직이는 축을 기준으로 걷기 애니메이션을 고릅니다.
-- 옆으로 찍은 이동에 y값이 조금 섞여도 좌/우 걷기가 우선 나오도록 합니다.
local function setAnimationFromMoveVector(moveX, moveY)
    if math.abs(moveX) >= math.abs(moveY) then
        if moveX > 0 then
            setCurrentAnimation("right")
        elseif moveX < 0 then
            setCurrentAnimation("left")
        elseif moveY > 0 then
            setCurrentAnimation("front")
        elseif moveY < 0 then
            setCurrentAnimation("back")
        else
            setCurrentAnimation("front")
        end
    else
        if moveY > 0 then
            setCurrentAnimation("front")
        elseif moveY < 0 then
            setCurrentAnimation("back")
        elseif moveX > 0 then
            setCurrentAnimation("right")
        elseif moveX < 0 then
            setCurrentAnimation("left")
        else
            setCurrentAnimation("front")
        end
    end
end

-- 스프라이트 시트 하나를 불러오고 100x150 프레임으로 자릅니다.
local function loadAnimation(animation)
    if not love.filesystem.getInfo(animation.fileName) then
        animation.isLoaded = false
        return
    end

    local success, imageOrError = pcall(love.graphics.newImage, animation.fileName)

    -- 이미지 로딩에 실패해도 게임이 튕기지 않도록 안전하게 처리합니다.
    if not success then
        animation.image = nil
        animation.quads = {}
        animation.isLoaded = false
        return
    end

    animation.image = imageOrError
    animation.image:setFilter("linear", "linear")
    animation.quads = {}

    local sheetWidth = animation.image:getWidth()
    local sheetHeight = animation.image:getHeight()

    -- 프레임 수만큼 가로 방향으로 Quad를 잘라냅니다.
    for frameIndex = 1, animation.frameCount do
        local frameX = (frameIndex - 1) * sprite.frameWidth
        local frameY = 0
        animation.quads[frameIndex] = love.graphics.newQuad(
            frameX,
            frameY,
            sprite.frameWidth,
            sprite.frameHeight,
            sheetWidth,
            sheetHeight
        )
    end

    animation.isLoaded = true
end

-- 좌우 애니메이션 시트를 모두 불러옵니다.
local function loadAllAnimations()
    loadAnimation(sprite.animations.left)
    loadAnimation(sprite.animations.right)
    loadAnimation(sprite.animations.front)
    loadAnimation(sprite.animations.back)
    loadAnimation(sprite.animations.drag)
end

-- 방 배경 이미지를 불러옵니다. 파일이 없어도 게임은 기본 배경으로 계속 실행됩니다.
local function loadFurnitureLibrary()
    for _, item in ipairs(furnitureLibrary.items) do
        item.image = nil
        item.isLoaded = false

        if love.filesystem.getInfo(item.fileName) then
            local success, imageOrError = pcall(love.graphics.newImage, item.fileName)

            if success then
                item.image = imageOrError
                item.image:setFilter("linear", "linear")
                item.height = item.width * item.image:getHeight() / item.image:getWidth()
                item.isLoaded = true
            end
        end
    end
end

local function loadRoomBackground(backgroundPath)
    local imagePath = backgroundPath or backgroundLibrary.activePath

    if not imagePath then
        roomBackgroundImage = nil
        backgroundLibrary.loadedPath = nil
        return false
    end

    if not love.filesystem.getInfo(imagePath) then
        roomBackgroundImage = nil
        backgroundLibrary.loadedPath = nil
        return false
    end

    local success, imageOrError = pcall(love.graphics.newImage, imagePath)

    if success then
        roomBackgroundImage = imageOrError
        roomBackgroundImage:setFilter("linear", "linear")
        backgroundLibrary.loadedPath = imagePath
        return true
    else
        roomBackgroundImage = nil
        backgroundLibrary.loadedPath = nil
        return false
    end
end

local function refreshWorldAfterBackgroundChange()
    updateRoomWorldSize()
    clampCharacterToVirtualScreen()
    clampAllFurnitureToRoom()
    updateCamera(0, true)
end

local function previewRoomBackground(backgroundPath)
    if loadRoomBackground(backgroundPath) then
        backgroundLibrary.previewPath = backgroundPath
        applyFloorRatioForBackground(backgroundPath)
        refreshWorldAfterBackgroundChange()
    end
end

local function syncRoomBackground()
    local targetPath = backgroundLibrary.previewPath or backgroundLibrary.activePath

    if backgroundLibrary.loadedPath ~= targetPath then
        loadRoomBackground(targetPath)
    end

    applyFloorRatioForBackground(targetPath)
    refreshWorldAfterBackgroundChange()
end

local function applyPreviewRoomBackground()
    backgroundLibrary.activePath = backgroundLibrary.previewPath
    previewRoomBackground(backgroundLibrary.activePath)
end

local function cancelPreviewRoomBackground()
    backgroundLibrary.previewPath = backgroundLibrary.activePath
    previewRoomBackground(backgroundLibrary.activePath)
end

local function loadBackgroundLibrary()
    backgroundLibrary.items = {}

    local function addBackgroundItem(path, label)
        if not love.filesystem.getInfo(path) then
            return
        end

        local item = {
            path = path,
            label = label,
            image = nil
        }

        local success, imageOrError = pcall(love.graphics.newImage, path)

        if success then
            item.image = imageOrError
            item.image:setFilter("linear", "linear")
        end

        table.insert(backgroundLibrary.items, item)
    end

    if love.filesystem.getInfo(backgroundLibrary.folder) then
        local files = love.filesystem.getDirectoryItems(backgroundLibrary.folder)
        table.sort(files)

        for _, fileName in ipairs(files) do
            local lowerName = string.lower(fileName)

            if lowerName:match("%.png$") or lowerName:match("%.jpg$") or lowerName:match("%.jpeg$") or lowerName:match("%.webp$") then
                addBackgroundItem(backgroundLibrary.folder .. "/" .. fileName, fileName)
            end
        end
    end

    backgroundLibrary.selectedIndex = 1

    if #backgroundLibrary.items > 0 then
        backgroundLibrary.activePath = backgroundLibrary.items[1].path
        backgroundLibrary.previewPath = backgroundLibrary.activePath
    else
        backgroundLibrary.activePath = nil
        backgroundLibrary.previewPath = nil
    end
end

-- 초록색(RGB 0, 255, 0) 배경을 투명하게 날리는 픽셀 셰이더를 준비합니다.
local function loadChromaKeyShader()
    local shaderCode = [[
        extern vec3 keyColor;
        extern number tolerance;

        vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
        {
            vec4 pixel = Texel(texture, texture_coords) * color;
            float colorDistance = distance(pixel.rgb, keyColor);
            float greenDominance = pixel.g - max(pixel.r, pixel.b);

            if (colorDistance <= tolerance || (pixel.g > 0.35 && greenDominance > 0.08)) {
                pixel.a = 0.0;
            }

            return pixel;
        }
    ]]

    local success, shaderOrError = pcall(love.graphics.newShader, shaderCode)

    -- 셰이더 생성에 실패하면 크로마키 없이 이미지를 그리되 게임은 계속 실행합니다.
    if not success then
        chromaKeyShader = nil
        chromaKeyShaderReady = false
        return
    end

    chromaKeyShader = shaderOrError
    chromaKeyShader:send("keyColor", {0, 1, 0})
    chromaKeyShader:send("tolerance", 0.18)
    chromaKeyShaderReady = true
end

-- 세로 모드와 가로 모드를 서로 전환합니다.
local function toggleOrientation()
    if currentOrientation == "portrait" then
        currentOrientation = "landscape"
    else
        currentOrientation = "portrait"
    end

    -- 현재 모드에 맞춰 가상 해상도를 즉시 변경합니다.
    virtualWidth = ORIENTATION[currentOrientation].width
    virtualHeight = ORIENTATION[currentOrientation].height

    -- PC 창 크기를 실제 스마트폰 회전처럼 즉시 바꿉니다.
    love.window.setMode(virtualWidth, virtualHeight, {
        resizable = true,
        minwidth = 320,
        minheight = 320
    })

    -- 창 크기 변경 후 레터박스와 좌표 변환 기준을 다시 계산합니다.
    updateScreenScale()
    syncRoomBackground()

    -- 회전 직후 캐릭터가 새 가상 화면 밖으로 밀려나지 않도록 안전하게 제한합니다.
    clampCharacterToVirtualScreen()
    updateCamera(0, true)

    -- 회전하는 순간에도 드래그 중이었다면 새 좌표계 기준으로 드래그 오프셋을 다시 맞춥니다.
    if character.isDragging then
        local mouseX, mouseY = love.mouse.getPosition()
        local viewX, viewY = windowToVirtual(mouseX, mouseY)
        local pointerX, pointerY = windowToWorld(mouseX, mouseY)

        if isInsideViewport(viewX, viewY) and isInsideVirtualScreen(pointerX, pointerY) then
            character.dragOffsetX = pointerX - character.x
            character.dragOffsetY = pointerY - character.y
        else
            -- 마우스가 레터박스 영역 밖으로 벗어난 상태라면 드래그를 안전하게 종료합니다.
            character.isDragging = false
            character.isLanded = character.y >= getFloorY()
            updateFallSpeedFromHeight()
        end
    end

end

-- 방향키 입력을 읽어 캐릭터 이동 방향을 계산합니다.
local function getKeyboardMoveVector()
    local moveX = 0
    local moveY = 0

    if love.keyboard.isDown("left") then
        moveX = moveX - 1
    end

    if love.keyboard.isDown("right") then
        moveX = moveX + 1
    end

    if love.keyboard.isDown("up") then
        moveY = moveY - 1
    end

    if love.keyboard.isDown("down") then
        moveY = moveY + 1
    end

    -- 대각선 이동이 너무 빨라지지 않도록 방향 벡터를 정규화합니다.
    if moveX ~= 0 and moveY ~= 0 then
        local length = math.sqrt(moveX * moveX + moveY * moveY)
        moveX = moveX / length
        moveY = moveY / length
    end

    return moveX, moveY
end

local function isPointInsideRect(x, y, rect)
    return x >= rect.x
        and x <= rect.x + rect.width
        and y >= rect.y
        and y <= rect.y + rect.height
end

local function getMenuButtonRect()
    return {
        x = virtualWidth - 58,
        y = 18,
        width = 42,
        height = 42
    }
end

local function getInteriorButtonRect()
    return {
        x = virtualWidth - 150,
        y = 66,
        width = 132,
        height = 42
    }
end

local function getChatButtonRect()
    return {
        x = virtualWidth - 150,
        y = 114,
        width = 132,
        height = 42
    }
end

local function getChatWindowRect()
    local width = math.min(520, virtualWidth - 40)
    local height = math.min(350, virtualHeight - 80)

    return {
        x = (virtualWidth - width) * 0.5,
        y = (virtualHeight - height) * 0.5,
        width = width,
        height = height
    }
end

local function getChatCloseRect()
    local rect = getChatWindowRect()
    return {x = rect.x + rect.width - 42, y = rect.y + 10, width = 30, height = 30}
end

local function getChatInputRect()
    local rect = getChatWindowRect()
    return {x = rect.x + 16, y = rect.y + rect.height - 54, width = rect.width - 112, height = 38}
end

local function getChatSendRect()
    local rect = getChatWindowRect()
    return {x = rect.x + rect.width - 88, y = rect.y + rect.height - 54, width = 72, height = 38}
end

local function getInteriorWindowRect()
    return {
        x = 28,
        y = 54,
        width = virtualWidth - 56,
        height = virtualHeight - 108
    }
end

local function getInteriorSidebarRect()
    local windowRect = getInteriorWindowRect()

    return {
        x = windowRect.x - 12,
        y = windowRect.y + 96,
        width = 77,
        height = windowRect.height - 120
    }
end

local function getInteriorCategoryButtonRect(index)
    local sidebarRect = getInteriorSidebarRect()
    local buttonHeight = 43
    local buttonGap = 11

    return {
        x = sidebarRect.x,
        y = sidebarRect.y + (index - 1) * (buttonHeight + buttonGap),
        width = sidebarRect.width,
        height = buttonHeight
    }
end

local function getBackgroundListRect()
    local windowRect = getInteriorWindowRect()
    local sidebarRect = getInteriorSidebarRect()
    local contentX = sidebarRect.x + sidebarRect.width + 12

    return {
        x = contentX,
        y = windowRect.y + 80,
        width = windowRect.x + windowRect.width - 24 - contentX,
        height = windowRect.height - 140
    }
end

local function getBackgroundItemLayout()
    return {
        width = 220,
        height = 146,
        gap = 16
    }
end

local function getFurnitureItemLayout()
    return {
        width = 180,
        height = 132,
        gap = 16
    }
end

local function getBackgroundContentWidth()
    local layout = getBackgroundItemLayout()
    local itemCount = math.max(1, #backgroundLibrary.items)

    return itemCount * layout.width + math.max(0, itemCount - 1) * layout.gap
end

local function clampBackgroundScroll()
    local listRect = getBackgroundListRect()
    local maxScroll = math.max(0, getBackgroundContentWidth() - listRect.width)
    ui.backgroundScrollX = clamp(ui.backgroundScrollX, 0, maxScroll)
end

local function selectBackgroundItem(index)
    local item = backgroundLibrary.items[index]

    if not item then
        return
    end

    backgroundLibrary.selectedIndex = index
    previewRoomBackground(item.path)
end

local function decodeJsonStringField(json, fieldName)
    local _, valueStart = json:find('"' .. fieldName .. '"%s*:%s*"')
    if not valueStart then
        return nil
    end

    local result = {}
    local index = valueStart + 1

    while index <= #json do
        local characterByte = json:sub(index, index)
        if characterByte == '"' then
            return table.concat(result)
        elseif characterByte == "\\" then
            local escaped = json:sub(index + 1, index + 1)
            local replacements = {n = "\n", r = "\r", t = "\t", b = "\b", f = "\f"}
            table.insert(result, replacements[escaped] or escaped)
            index = index + 2
        else
            table.insert(result, characterByte)
            index = index + 1
        end
    end

    return nil
end

local function addChatMessage(role, text)
    table.insert(chat.messages, {role = role, text = text})
    while #chat.messages > 20 do
        table.remove(chat.messages, 1)
    end
end

local function openChatWindow()
    ui.isChatOpen = true
    ui.isMenuOpen = false
    ui.isInteriorOpen = false
    love.keyboard.setTextInput(true)
end

local function closeChatWindow()
    ui.isChatOpen = false
    love.keyboard.setTextInput(false)
end

local function sendChatMessage()
    local message = chat.input:match("^%s*(.-)%s*$")
    if message == "" or chat.isSending or not chat.requestChannel then
        return
    end

    addChatMessage("user", message)
    chat.input = ""
    chat.isSending = true
    chat.requestChannel:push(message)
end

local function pollChatResponse()
    if chat.thread and not chat.threadErrorShown then
        local threadError = chat.thread:getError()
        if threadError then
            chat.threadErrorShown = true
            chat.isSending = false
            addChatMessage("system", "채팅 스레드 오류: " .. threadError)
        end
    end

    if not chat.responseChannel then
        return
    end

    local result = chat.responseChannel:pop()
    if not result then
        return
    end

    chat.isSending = false
    local statusCode, body = result:match("^(%d+)%s*\n(.*)$")
    local reply = body and decodeJsonStringField(body, "reply")

    if statusCode == "200" and reply then
        addChatMessage("assistant", reply)
    else
        local serverError = body and decodeJsonStringField(body, "error")
        addChatMessage("system", serverError or "서버에 연결하지 못했습니다. 잠시 후 다시 시도해 주세요.")
    end
end

local function openInteriorWindow()
    closeChatWindow()
    ui.isMenuOpen = false
    ui.isInteriorOpen = true
    ui.activeInteriorTab = "backgrounds"
    ui.backgroundScrollX = 0
    backgroundLibrary.previewPath = backgroundLibrary.activePath

    for index, item in ipairs(backgroundLibrary.items) do
        if item.path == backgroundLibrary.activePath then
            backgroundLibrary.selectedIndex = index
            break
        end
    end
end

local function closeInteriorWindow(shouldApply)
    if shouldApply then
        applyPreviewRoomBackground()
    else
        cancelPreviewRoomBackground()
    end

    clampAllFurnitureToRoom()
    ui.isInteriorOpen = false
end

local function handleUiMousePressed(virtualX, virtualY)
    if ui.isChatOpen then
        if isPointInsideRect(virtualX, virtualY, getChatCloseRect()) then
            closeChatWindow()
        elseif isPointInsideRect(virtualX, virtualY, getChatSendRect()) then
            sendChatMessage()
        end
        return true
    end

    if ui.isInteriorOpen then
        local windowRect = getInteriorWindowRect()
        local confirmRect = {
            x = windowRect.x + windowRect.width - 116,
            y = windowRect.y + windowRect.height - 54,
            width = 92,
            height = 34
        }
        local cancelRect = {
            x = confirmRect.x - 104,
            y = confirmRect.y,
            width = 92,
            height = 34
        }
        local closeRect = {
            x = windowRect.x + windowRect.width - 40,
            y = windowRect.y + 16,
            width = 24,
            height = 24
        }
        local backgroundButtonRect = getInteriorCategoryButtonRect(1)
        local furnitureButtonRect = getInteriorCategoryButtonRect(2)
        local listRect = getBackgroundListRect()

        if isPointInsideRect(virtualX, virtualY, confirmRect) then
            closeInteriorWindow(true)
            return true
        end

        if isPointInsideRect(virtualX, virtualY, cancelRect) or isPointInsideRect(virtualX, virtualY, closeRect) then
            closeInteriorWindow(false)
            return true
        end

        if isPointInsideRect(virtualX, virtualY, backgroundButtonRect) then
            ui.activeInteriorTab = "backgrounds"
            return true
        end

        if isPointInsideRect(virtualX, virtualY, furnitureButtonRect) then
            ui.activeInteriorTab = "furniture"
            ui.isBackgroundListDragging = false
            return true
        end

        if ui.activeInteriorTab == "backgrounds" and isPointInsideRect(virtualX, virtualY, listRect) then
            ui.isBackgroundListDragging = true
            ui.backgroundDragLastX = virtualX

            local layout = getBackgroundItemLayout()
            local localX = virtualX - listRect.x + ui.backgroundScrollX
            local itemStep = layout.width + layout.gap
            local index = math.floor(localX / itemStep) + 1
            local itemStartX = (index - 1) * itemStep

            if localX >= itemStartX and localX <= itemStartX + layout.width then
                selectBackgroundItem(index)
            end

            return true
        end

        if ui.activeInteriorTab == "furniture" and isPointInsideRect(virtualX, virtualY, listRect) then
            local layout = getFurnitureItemLayout()
            local localX = virtualX - listRect.x
            local localY = virtualY - listRect.y
            local itemStep = layout.width + layout.gap
            local index = math.floor((localX - 14) / itemStep) + 1
            local itemX = 14 + (index - 1) * itemStep
            local itemY = 14

            if furnitureLibrary.items[index]
                and localX >= itemX
                and localX <= itemX + layout.width
                and localY >= itemY
                and localY <= itemY + layout.height then
                furnitureLibrary.selectedIndex = index
                furnitureEdit.selectedItem = addFurnitureToRoom(furnitureLibrary.items[index])
                furnitureEdit.isSizing = furnitureEdit.selectedItem ~= nil
            end

            return true
        end

        return true
    end

    if isPointInsideRect(virtualX, virtualY, getMenuButtonRect()) then
        ui.isMenuOpen = not ui.isMenuOpen
        return true
    end

    if ui.isMenuOpen then
        if isPointInsideRect(virtualX, virtualY, getInteriorButtonRect()) then
            openInteriorWindow()
            return true
        elseif isPointInsideRect(virtualX, virtualY, getChatButtonRect()) then
            openChatWindow()
            return true
        end

        ui.isMenuOpen = false
    end

    return false
end

-- 게임이 처음 시작될 때 한 번 실행됩니다.
function love.load()
    chat.requestChannel = love.thread.getChannel("chat_requests")
    chat.responseChannel = love.thread.getChannel("chat_responses")
    chat.requestChannel:clear()
    chat.responseChannel:clear()
    chat.thread = love.thread.newThread("chat_worker.lua")
    chat.thread:start()

    -- PC 테스트용 가로 모드 기준 창 크기로 시작합니다.
    love.window.setMode(virtualWidth, virtualHeight, {
        resizable = true,
        minwidth = 320,
        minheight = 320
    })

    love.window.setTitle("LÖVE Tamagotchi Sprite Test")

    -- 좌우 스프라이트 이미지와 셰이더를 먼저 준비합니다.
    loadAllAnimations()
    loadFurnitureLibrary()
    loadBackgroundLibrary()
    loadRoomBackground()
    loadChromaKeyShader()

    -- 현재 창 크기에 맞게 레터박스 스케일을 계산합니다.
    updateScreenScale()
    updateRoomWorldSize()

    -- 시작할 때 캐릭터가 가상 화면 안에 있도록 정리합니다.
    clampCharacterToVirtualScreen()
    updateCamera(0, true)
end

-- 실제 창 크기가 바뀔 때마다 실행됩니다.
function love.resize(width, height)
    -- 현재 켜진 세로/가로 모드의 가상 해상도 기준으로 스케일을 다시 계산합니다.
    updateScreenScale()
    syncRoomBackground()

    -- 사용자가 창을 직접 줄이거나 늘려도 캐릭터가 가상 화면 밖으로 사라지지 않게 합니다.
    clampCharacterToVirtualScreen()
    updateCamera(0, true)
end

-- 키보드를 눌렀을 때 실행됩니다.
function love.keypressed(key)
    if ui.isChatOpen then
        if key == "escape" then
            closeChatWindow()
        elseif key == "return" or key == "kpenter" then
            sendChatMessage()
        elseif key == "backspace" then
            local byteOffset = utf8.offset(chat.input, -1)
            if byteOffset then
                chat.input = chat.input:sub(1, byteOffset - 1)
            end
        end
        return
    end

    if love.keyboard.isDown("lctrl", "rctrl") and key == "c" then
        if furnitureEdit.isSizing and furnitureEdit.selectedItem then
            furnitureEdit.lastCopiedText = buildFurnitureClipboardText(furnitureEdit.selectedItem)
            love.system.setClipboardText(furnitureEdit.lastCopiedText)
        elseif floorDebug.enabled then
            floorDebug.lastCopiedText = buildFloorClipboardText()
            love.system.setClipboardText(floorDebug.lastCopiedText)
        end

        return
    end

    if key == "[" or key == "leftbracket" then
        adjustFloorRatio(-floorDebug.step)
        return
    elseif key == "]" or key == "rightbracket" then
        adjustFloorRatio(floorDebug.step)
        return
    end

    -- Tab 키를 누를 때마다 스마트폰 회전처럼 세로 모드와 가로 모드를 전환합니다.
    if key == "tab" then
        toggleOrientation()
    end
end

-- 마우스 버튼을 눌렀을 때 실행됩니다.
function love.textinput(text)
    if ui.isChatOpen and not chat.isSending and #chat.input < 1000 then
        chat.input = chat.input .. text
    end
end

function love.mousepressed(windowX, windowY, button)
    if button == 1 then
        -- 실제 마우스 좌표를 현재 카메라가 적용된 월드 좌표로 변환합니다.
        local viewX, viewY = windowToVirtual(windowX, windowY)
        local pointerX, pointerY = windowToWorld(windowX, windowY)

        if handleUiMousePressed(viewX, viewY) then
            return
        end

        if furnitureEdit.selectedItem then
            local deleteRect = getFurnitureDeleteButtonRect(furnitureEdit.selectedItem)
            local sizeRects = getFurnitureSizeButtonRects(furnitureEdit.selectedItem)

            if isPointInsideRect(pointerX, pointerY, deleteRect) then
                removePlacedFurniture(furnitureEdit.selectedItem)
                return
            end

            if isPointInsideRect(pointerX, pointerY, sizeRects.minus) then
                setFurnitureWidth(furnitureEdit.selectedItem, furnitureEdit.selectedItem.width - furnitureEdit.sizeStep)
                furnitureEdit.isSizing = true
                return
            end

            if isPointInsideRect(pointerX, pointerY, sizeRects.plus) then
                setFurnitureWidth(furnitureEdit.selectedItem, furnitureEdit.selectedItem.width + furnitureEdit.sizeStep)
                furnitureEdit.isSizing = true
                return
            end
        end

        local clickedFurniture = nil

        if isInsideViewport(viewX, viewY) and isInsideVirtualScreen(pointerX, pointerY) then
            clickedFurniture = findFurnitureAt(pointerX, pointerY)
        end

        if clickedFurniture then
            furnitureEdit.selectedItem = clickedFurniture
            furnitureEdit.isSizing = true
            furnitureDrag.item = clickedFurniture
            furnitureDrag.offsetX = pointerX - clickedFurniture.x
            furnitureDrag.offsetY = pointerY - clickedFurniture.y
            character.isMovingToTarget = false
            return
        end

        furnitureEdit.selectedItem = nil
        furnitureEdit.isSizing = false

        -- 검은 레터박스가 아니라 실제 가상 화면 안쪽의 캐릭터를 눌렀을 때만 드래그합니다.
        if isInsideViewport(viewX, viewY) and isInsideVirtualScreen(pointerX, pointerY) and isPointerInsideCharacter(pointerX, pointerY) then
            local bounds = getCharacterVisualBounds()
            character.dragDepthScale = getCharacterDepthScale()
            character.dragShadowFootX = bounds.footX
            character.dragShadowFootY = bounds.footY
            character.fallTargetY = character.y
            character.isDragging = true
            character.isMovingToTarget = false
            character.isLanded = false
            character.fallSpeed = character.baseFallSpeed

            -- 캐릭터의 어느 부위를 잡아도 잡은 지점 그대로 따라오도록 오프셋을 저장합니다.
            character.dragOffsetX = pointerX - character.x
            character.dragOffsetY = pointerY - character.y
        elseif isInsideViewport(viewX, viewY) and isInsideVirtualScreen(pointerX, pointerY) then
            if isCharacterOnPlacedFurnitureAt(pointerX - character.width * 0.5, pointerY - character.height) then
                return
            end

            setMoveTarget(pointerX, pointerY)
        end
    end
end

-- 마우스 버튼에서 손을 뗐을 때 실행됩니다.
function love.mousereleased(windowX, windowY, button)
    if button == 1 and ui.isBackgroundListDragging then
        ui.isBackgroundListDragging = false
        return
    end

    if button == 1 and character.isDragging then
        -- 드래그를 끝내고, 현재 위치가 바닥이 아니면 다시 등속 낙하합니다.
        character.isDragging = false
        character.isLanded = character.y >= getFloorY()
        updateFallSpeedFromHeight()
    end
end

-- 모바일 터치에서도 빈 곳을 누르면 해당 위치로 이동하게 합니다.
function love.touchpressed(id, windowX, windowY, dx, dy, pressure)
    love.mousepressed(windowX, windowY, 1)
end

function love.mousemoved(windowX, windowY, dx, dy)
    if ui.isInteriorOpen and ui.isBackgroundListDragging then
        local viewX = windowToVirtual(windowX, windowY)
        local dragDelta = viewX - ui.backgroundDragLastX

        ui.backgroundScrollX = ui.backgroundScrollX - dragDelta
        ui.backgroundDragLastX = viewX
        clampBackgroundScroll()
    end
end

function love.touchmoved(id, windowX, windowY, dx, dy, pressure)
    love.mousemoved(windowX, windowY, dx, dy)
end

function love.touchreleased(id, windowX, windowY, dx, dy, pressure)
    love.mousereleased(windowX, windowY, 1)
end

function love.wheelmoved(x, y)
    if ui.isInteriorOpen and ui.activeInteriorTab == "backgrounds" then
        ui.backgroundScrollX = ui.backgroundScrollX - y * 48 - x * 48
        clampBackgroundScroll()
    end
end

-- 매 프레임마다 스프라이트 애니메이션을 갱신합니다.
local function updateSpriteAnimation(dt)
    local animation = getCurrentAnimation()

    if not animation or not animation.isLoaded then
        return
    end

    -- 방향키로 이동 중일 때만 걷기 프레임을 진행하고, 멈추면 첫 프레임에 둡니다.
    if not sprite.isMovingByKeyboard and not character.isDragging then
        sprite.currentFrame = 1
        sprite.timer = 0
        return
    end

    sprite.timer = sprite.timer + dt

    local frameTime = animation.frameTime or sprite.frameTime

    while sprite.timer >= frameTime do
        sprite.timer = sprite.timer - frameTime
        sprite.currentFrame = sprite.currentFrame + 1

        if sprite.currentFrame > animation.frameCount then
            sprite.currentFrame = 1
        end
    end
end

-- 매 프레임마다 게임 상태를 갱신합니다.
function love.update(dt)
    pollChatResponse()

    if furnitureDrag.item then
        if love.mouse.isDown(1) then
            local windowX, windowY = love.mouse.getPosition()
            local viewX, viewY = windowToVirtual(windowX, windowY)
            local pointerX, pointerY = windowToWorld(windowX, windowY)

            if isInsideViewport(viewX, viewY) then
                furnitureDrag.item.x = pointerX - furnitureDrag.offsetX
                furnitureDrag.item.y = pointerY - furnitureDrag.offsetY
                clampFurnitureToRoom(furnitureDrag.item)
            end
        else
            furnitureDrag.item = nil
        end
    elseif love.mouse.isDown(1) and not ui.isInteriorOpen and not character.isDragging then
        local windowX, windowY = love.mouse.getPosition()
        local viewX, viewY = windowToVirtual(windowX, windowY)
        local pointerX, pointerY = windowToWorld(windowX, windowY)

        if isInsideViewport(viewX, viewY) and isInsideVirtualScreen(pointerX, pointerY) then
            local hoveredFurniture = findFurnitureAt(pointerX, pointerY)

            if hoveredFurniture then
                furnitureEdit.selectedItem = hoveredFurniture
                furnitureEdit.isSizing = true
                furnitureDrag.item = hoveredFurniture
                furnitureDrag.offsetX = pointerX - hoveredFurniture.x
                furnitureDrag.offsetY = pointerY - hoveredFurniture.y
                character.isMovingToTarget = false
            end
        end
    end

    local moveX, moveY = getKeyboardMoveVector()
    local targetMoveX = 0
    local targetMoveY = 0

    if moveX ~= 0 or moveY ~= 0 then
        character.isMovingToTarget = false
        character.fallTargetY = nil
    elseif character.isMovingToTarget then
        local deltaX = character.targetX - character.x
        local deltaY = character.targetY - character.y
        local distance = math.sqrt(deltaX * deltaX + deltaY * deltaY)

        if distance <= character.targetStopDistance then
            character.x = character.targetX
            character.y = character.targetY
            if character.movePath and character.movePathIndex < #character.movePath then
                character.movePathIndex = character.movePathIndex + 1
                local nextWaypoint = character.movePath[character.movePathIndex]
                character.targetX = nextWaypoint.x
                character.targetY = nextWaypoint.y
            else
                character.isMovingToTarget = false
                character.movePath = nil
            end
        else
            targetMoveX = deltaX / distance
            targetMoveY = deltaY / distance
        end
    end

    sprite.isMovingByKeyboard = moveX ~= 0 or moveY ~= 0 or targetMoveX ~= 0 or targetMoveY ~= 0

    -- 마우스로 캐릭터를 들어올리는 동안에는 드래그 전용 스프라이트를 가장 먼저 표시합니다.
    if character.isDragging then
        setCurrentAnimation("drag")
    elseif sprite.isMovingByKeyboard then
        local animationMoveX = moveX
        local animationMoveY = moveY

        if animationMoveX == 0 and animationMoveY == 0 then
            animationMoveX = targetMoveX
            animationMoveY = targetMoveY
        end

        setAnimationFromMoveVector(animationMoveX, animationMoveY)
    else
        -- 이동을 멈추면 어느 방향에서 멈췄든 기본 대기 자세는 전면으로 고정합니다.
        setCurrentAnimation("front")
    end

    updateSpriteAnimation(dt)

    if character.isDragging then
        -- 드래그 중에는 실제 마우스 좌표를 계속 현재 카메라가 적용된 월드 좌표로 변환해서 사용합니다.
        local windowX, windowY = love.mouse.getPosition()
        local viewX, viewY = windowToVirtual(windowX, windowY)
        local pointerX, pointerY = windowToWorld(windowX, windowY)

        if isInsideViewport(viewX, viewY) then
            character.x = pointerX - character.dragOffsetX
            character.y = pointerY - character.dragOffsetY

            -- 앞으로 끌어내린 경우에는 현재 깊이 위치를 새 착지 지점으로 갱신합니다.
            -- 위로 들어올린 경우에는 기존 착지 깊이를 유지합니다.
            if character.fallTargetY then
                character.fallTargetY = clamp(math.max(character.fallTargetY, character.y), getMinCharacterFloorY(), getWorldFloorY())
                character.dragShadowFootY = character.fallTargetY + character.height
            end
        end

        -- 드래그 중에도 캐릭터가 현재 가상 화면 밖으로 사라지지 않게 합니다.
        clampCharacterToVirtualScreen()

    elseif sprite.isMovingByKeyboard then
        -- 방향키를 누르는 동안에는 그 방향으로 캐릭터를 이동합니다.
        local depthMoveScale = 0.65 + 0.35 * getCharacterDepthRatio()
        local currentMoveSpeed = character.moveSpeed * depthMoveScale
        local actualMoveX = moveX
        local actualMoveY = moveY
        local previousX = character.x
        local previousY = character.y

        if actualMoveX == 0 and actualMoveY == 0 then
            actualMoveX = targetMoveX
            actualMoveY = targetMoveY
        end

        local nextX = character.x + actualMoveX * currentMoveSpeed * dt
        local nextY = character.y + actualMoveY * currentMoveSpeed * dt

        if character.isMovingToTarget then
            local beforeX = character.targetX - character.x
            local beforeY = character.targetY - character.y
            local afterX = character.targetX - nextX
            local afterY = character.targetY - nextY

            if beforeX * afterX + beforeY * afterY <= 0 then
                nextX = character.targetX
                nextY = character.targetY
                if character.movePath and character.movePathIndex < #character.movePath then
                    character.movePathIndex = character.movePathIndex + 1
                    local nextWaypoint = character.movePath[character.movePathIndex]
                    character.targetX = nextWaypoint.x
                    character.targetY = nextWaypoint.y
                else
                    character.isMovingToTarget = false
                    character.movePath = nil
                end
            end
        end

        character.x = nextX
        character.y = nextY

        if isCharacterOnPlacedFurnitureAt(character.x, character.y) then
            character.x = previousX
            character.y = previousY
            character.isMovingToTarget = false
            character.movePath = nil
        end

        -- 방향키 이동 중에도 가상 화면 밖으로 나가지 않도록 제한합니다.
        clampCharacterToVirtualScreen()

        -- 방향키 위/아래 이동은 공중 낙하가 아니라 방 안 깊이 이동입니다.
        -- 키를 놓아도 현재 깊이 위치에 그대로 서 있도록 착지 상태로 고정합니다.
        character.isLanded = true
        character.fallSpeed = character.baseFallSpeed
    elseif not character.isLanded then
        -- 가속도 없이 일정한 속도로 현재 가상 화면의 바닥을 향해 떨어집니다.
        character.y = character.y + character.fallSpeed * dt

        -- 현재 모드의 가상 화면 바닥에 닿으면 튕기지 않고 정확히 착지합니다.
        if character.y >= getFloorY() then
            character.y = getFloorY()
            character.isLanded = true
            character.fallTargetY = nil
            character.fallSpeed = character.baseFallSpeed
        end
    end

    updateCamera(dt, false)
end

-- 스프라이트 파일이 없을 때 표시할 안전용 파란색 임시 박스입니다.
local function drawPlaceholderCharacter()
    local bounds = getCharacterVisualBounds()

    love.graphics.setColor(0.25, 0.65, 1.0)
    love.graphics.rectangle("fill", bounds.x, bounds.y, bounds.width, bounds.height)

    love.graphics.setColor(1, 1, 1)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", bounds.x, bounds.y, bounds.width, bounds.height)

    love.graphics.setColor(0, 0, 0)
    love.graphics.printf("VIDEO\nPLACEHOLDER", bounds.x, bounds.y + bounds.height * 0.36, bounds.width, "center")
end

-- 방 배경을 현재 가상 해상도에 맞게 꽉 채워 그립니다.
local function drawRoomBackground()
    if not roomBackgroundImage then
        love.graphics.setColor(0.12, 0.12, 0.14)
        love.graphics.rectangle("fill", 0, 0, roomWorldWidth, roomWorldHeight)
        return
    end

    love.graphics.setColor(1, 1, 1, 1)

    local imageWidth = roomBackgroundImage:getWidth()
    local imageHeight = roomBackgroundImage:getHeight()
    local backgroundScale = math.max(roomWorldWidth / imageWidth, roomWorldHeight / imageHeight)
    local drawWidth = imageWidth * backgroundScale
    local drawHeight = imageHeight * backgroundScale
    local drawX = (roomWorldWidth - drawWidth) * 0.5
    local drawY = (roomWorldHeight - drawHeight) * 0.5

    love.graphics.draw(roomBackgroundImage, drawX, drawY, 0, backgroundScale, backgroundScale)
end

-- 캐릭터가 바닥에 붙어 있다는 느낌을 주는 그림자입니다. 멀어질수록 작고 연해집니다.
local function drawFurnitureItem(item)
    if not item.image then
        return
    end

    local bounds = getFurnitureVisualBounds(item)
    local scaleX = bounds.width / item.image:getWidth()
    local scaleY = bounds.height / item.image:getHeight()

    love.graphics.draw(item.image, bounds.x, bounds.y, 0, scaleX, scaleY)
end

local function drawPlacedFurniture()
    if chromaKeyShaderReady then
        love.graphics.setShader(chromaKeyShader)
    end

    love.graphics.setColor(1, 1, 1, 1)

    for _, item in ipairs(placedFurniture) do
        drawFurnitureItem(item)
    end

    if chromaKeyShaderReady then
        love.graphics.setShader()
    end
end

local function drawCharacterShadow()
    local bounds = getCharacterVisualBounds()
    local shadowX = bounds.footX
    local shadowY = bounds.footY - 3 * bounds.scale
    local shadowScale = 1.0
    local shadowAlphaScale = 1.0

    if character.isDragging then
        local shadowFootY = math.max(bounds.footY, character.dragShadowFootY)
        local liftDistance = math.max(0, shadowFootY - bounds.footY)
        shadowX = bounds.footX
        shadowY = shadowFootY - 3 * bounds.scale
        shadowScale = 0.88
        shadowAlphaScale = clamp(1 - liftDistance / character.dragShadowFadeDistance, 0, 1)
    end

    local shadowWidth = bounds.width * 0.68 * shadowScale
    local shadowHeight = 13 * bounds.scale * shadowScale
    local shadowAlpha = 0.24 * bounds.scale * shadowAlphaScale

    if isRectOnPlacedFurniture(
        shadowX - shadowWidth,
        shadowY - shadowHeight,
        shadowWidth * 2,
        shadowHeight * 2
    ) then
        return
    end

    love.graphics.setColor(0, 0, 0, shadowAlpha)
    love.graphics.ellipse("fill", shadowX, shadowY, shadowWidth, shadowHeight)
end

-- 현재 방향의 스프라이트 시트 캐릭터를 현재 프레임으로 그립니다.
local function drawSpriteCharacter()
    local animation = getCurrentAnimation()

    if not animation or not animation.isLoaded then
        drawPlaceholderCharacter()
        return
    end

    local currentQuad = animation.quads[sprite.currentFrame]

    if not currentQuad then
        drawPlaceholderCharacter()
        return
    end

    -- 초록색 크로마키 셰이더가 준비되어 있으면 캐릭터 이미지에만 적용합니다.
    if chromaKeyShaderReady then
        love.graphics.setShader(chromaKeyShader)
    end

    love.graphics.setColor(1, 1, 1, 1)
    local bounds = getCharacterVisualBounds()
    local drawScaleX = bounds.width / sprite.frameWidth
    local drawScaleY = bounds.height / sprite.frameHeight
    love.graphics.draw(animation.image, currentQuad, bounds.x, bounds.y, 0, drawScaleX, drawScaleY)

    -- 셰이더가 다른 UI나 배경에 영향을 주지 않도록 바로 해제합니다.
    if chromaKeyShaderReady then
        love.graphics.setShader()
    end
end

-- 현재 가상 화면 안에 들어갈 게임 장면을 그립니다.
local function drawSortedWorldObjects()
    local drawItems = {}
    local characterBounds = getCharacterVisualBounds()

    if character.isDragging then
        table.insert(drawItems, {
            kind = "character_shadow",
            depthY = character.dragShadowFootY
        })
    else
        table.insert(drawItems, {
            kind = "character",
            depthY = characterBounds.footY
        })
    end

    for _, item in ipairs(placedFurniture) do
        local bounds = getFurnitureVisualBounds(item)

        table.insert(drawItems, {
            kind = "furniture",
            depthY = item.renderBehind and -math.huge or bounds.footY,
            item = item
        })
    end

    table.sort(drawItems, function(a, b)
        return a.depthY < b.depthY
    end)

    for _, entry in ipairs(drawItems) do
        if entry.kind == "character" then
            drawCharacterShadow()
            drawSpriteCharacter()
        elseif entry.kind == "character_shadow" then
            drawCharacterShadow()
        elseif entry.kind == "furniture" then
            if chromaKeyShaderReady then
                love.graphics.setShader(chromaKeyShader)
            end

            love.graphics.setColor(1, 1, 1, 1)
            drawFurnitureItem(entry.item)

            if chromaKeyShaderReady then
                love.graphics.setShader()
            end
        end
    end

    -- 들어 올린 캐릭터는 공중에 있으므로 모든 바닥 가구보다 앞에 그립니다.
    -- 그림자는 위의 깊이 정렬에 남겨 두어 원래 바닥 위치를 표현합니다.
    if character.isDragging then
        drawSpriteCharacter()
    end
end

local function setUiColor(color)
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
end

local function drawRoundedPanel(x, y, width, height, r, fillColor, lineColor)
    setUiColor(fillColor)
    love.graphics.rectangle("fill", x, y, width, height, r, r)

    if lineColor then
        setUiColor(lineColor)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x, y, width, height, r, r)
    end
end

local function drawImageContained(image, x, y, width, height)
    if not image then
        love.graphics.setColor(0.16, 0.16, 0.18)
        love.graphics.rectangle("fill", x, y, width, height, 6, 6)
        return
    end

    local imageWidth = image:getWidth()
    local imageHeight = image:getHeight()
    local imageScale = math.min(width / imageWidth, height / imageHeight)
    local drawWidth = imageWidth * imageScale
    local drawHeight = imageHeight * imageScale
    local drawX = x + (width - drawWidth) * 0.5
    local drawY = y + (height - drawHeight) * 0.5

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(image, drawX, drawY, 0, imageScale, imageScale)
end

local function drawMenuButton()
    local rect = getMenuButtonRect()

    drawRoundedPanel(rect.x, rect.y, rect.width, rect.height, 8, {0.06, 0.06, 0.07, 0.72}, {1, 1, 1, 0.36})

    love.graphics.setColor(1, 1, 1, 0.92)
    love.graphics.setLineWidth(3)
    love.graphics.line(rect.x + 11, rect.y + 13, rect.x + rect.width - 11, rect.y + 13)
    love.graphics.line(rect.x + 11, rect.y + 21, rect.x + rect.width - 11, rect.y + 21)
    love.graphics.line(rect.x + 11, rect.y + 29, rect.x + rect.width - 11, rect.y + 29)
end

local function drawDropdownMenu()
    if not ui.isMenuOpen then
        return
    end

    local rect = getInteriorButtonRect()
    local chatRect = getChatButtonRect()

    drawRoundedPanel(rect.x, rect.y, rect.width, rect.height, 8, {0.97, 0.93, 0.86, 0.94}, {0.35, 0.22, 0.14, 0.35})

    love.graphics.setColor(0.18, 0.12, 0.09, 1)
    love.graphics.printf("Interior", rect.x, rect.y + 12, rect.width, "center")

    drawRoundedPanel(chatRect.x, chatRect.y, chatRect.width, chatRect.height, 8, {0.97, 0.93, 0.86, 0.94}, {0.35, 0.22, 0.14, 0.35})
    love.graphics.setColor(0.18, 0.12, 0.09, 1)
    love.graphics.printf("Chat", chatRect.x, chatRect.y + 12, chatRect.width, "center")
end

local function drawChatWindow()
    if not ui.isChatOpen then
        return
    end

    local rect = getChatWindowRect()
    local closeRect = getChatCloseRect()
    local inputRect = getChatInputRect()
    local sendRect = getChatSendRect()

    love.graphics.setColor(0, 0, 0, 0.48)
    love.graphics.rectangle("fill", 0, 0, virtualWidth, virtualHeight)
    drawRoundedPanel(rect.x, rect.y, rect.width, rect.height, 12, {0.98, 0.95, 0.90, 0.98}, {0.35, 0.22, 0.14, 0.55})

    love.graphics.setColor(0.18, 0.12, 0.09, 1)
    love.graphics.print("Chat", rect.x + 18, rect.y + 18)
    drawRoundedPanel(closeRect.x, closeRect.y, closeRect.width, closeRect.height, 7, {0.28, 0.22, 0.20, 0.16}, {0.30, 0.20, 0.16, 0.30})
    love.graphics.setColor(0.18, 0.12, 0.09, 1)
    love.graphics.printf("X", closeRect.x, closeRect.y + 7, closeRect.width, "center")

    local firstMessage = math.max(1, #chat.messages - 3)
    local messageY = rect.y + 54
    for index = firstMessage, #chat.messages do
        local message = chat.messages[index]
        local label = message.role == "user" and "You" or (message.role == "assistant" and "Gemini" or "System")
        local bubbleColor = message.role == "user" and {0.95, 0.70, 0.66, 0.34} or {1, 1, 1, 0.58}
        drawRoundedPanel(rect.x + 16, messageY, rect.width - 32, 46, 7, bubbleColor, nil)
        love.graphics.setColor(0.34, 0.19, 0.14, 1)
        love.graphics.print(label .. ":", rect.x + 24, messageY + 6)
        love.graphics.setColor(0.16, 0.12, 0.10, 1)
        love.graphics.printf(message.text, rect.x + 78, messageY + 6, rect.width - 110, "left")
        messageY = messageY + 50
    end

    if chat.isSending then
        love.graphics.setColor(0.38, 0.28, 0.22, 0.8)
        love.graphics.print("Gemini is typing...", rect.x + 18, inputRect.y - 22)
    end

    drawRoundedPanel(inputRect.x, inputRect.y, inputRect.width, inputRect.height, 7, {1, 1, 1, 0.90}, {0.35, 0.22, 0.14, 0.45})
    love.graphics.setColor(0.16, 0.12, 0.10, 1)
    local inputText = chat.input ~= "" and chat.input or "Type a message..."
    love.graphics.printf(inputText, inputRect.x + 10, inputRect.y + 10, inputRect.width - 20, "left")

    local sendColor = chat.isSending and {0.55, 0.52, 0.50, 0.75} or {0.95, 0.53, 0.50, 0.96}
    drawRoundedPanel(sendRect.x, sendRect.y, sendRect.width, sendRect.height, 7, sendColor, {0.46, 0.16, 0.14, 0.34})
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Send", sendRect.x, sendRect.y + 10, sendRect.width, "center")
end

local function drawFurnitureEditControls()
    local item = furnitureEdit.selectedItem

    if not item then
        return
    end

    local bounds = getFurnitureVisualBounds(item)
    local deleteRect = getFurnitureDeleteButtonRect(item)
    local sizeRects = getFurnitureSizeButtonRects(item)

    love.graphics.setLineWidth(2)
    love.graphics.setColor(1, 0.12, 0.10, 0.85)
    love.graphics.rectangle("line", bounds.x, bounds.y, bounds.width, bounds.height, 4, 4)

    drawRoundedPanel(deleteRect.x, deleteRect.y, deleteRect.width, deleteRect.height, deleteRect.width * 0.5, {0.92, 0.08, 0.08, 0.96}, {1, 1, 1, 0.92})
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("X", deleteRect.x, deleteRect.y + deleteRect.height * 0.18, deleteRect.width, "center")

    drawRoundedPanel(sizeRects.minus.x, sizeRects.minus.y, sizeRects.minus.width, sizeRects.minus.height, 6, {0.18, 0.16, 0.15, 0.86}, {1, 1, 1, 0.50})
    drawRoundedPanel(sizeRects.plus.x, sizeRects.plus.y, sizeRects.plus.width, sizeRects.plus.height, 6, {0.18, 0.16, 0.15, 0.86}, {1, 1, 1, 0.50})
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("-", sizeRects.minus.x, sizeRects.minus.y + sizeRects.minus.height * 0.16, sizeRects.minus.width, "center")
    love.graphics.printf("+", sizeRects.plus.x, sizeRects.plus.y + sizeRects.plus.height * 0.16, sizeRects.plus.width, "center")

    local textWidth = 96 / math.max(0.5, bounds.scale)
    local textHeight = 20 / math.max(0.5, bounds.scale)
    local textX = bounds.x + bounds.width * 0.5 - textWidth * 0.5
    local textY = sizeRects.plus.y + sizeRects.plus.height + 4 / math.max(0.5, bounds.scale)

    drawRoundedPanel(textX, textY, textWidth, textHeight, 5, {0, 0, 0, 0.50}, nil)
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.printf(string.format("W %.0f", item.width), textX, textY + textHeight * 0.18, textWidth, "center")
end

local function drawBackgroundItems()
    local listRect = getBackgroundListRect()
    local layout = getBackgroundItemLayout()

    drawRoundedPanel(listRect.x, listRect.y, listRect.width, listRect.height, 8, {0.10, 0.09, 0.09, 0.18}, {0.35, 0.22, 0.14, 0.18})

    love.graphics.stencil(function()
        love.graphics.rectangle("fill", listRect.x, listRect.y, listRect.width, listRect.height, 8, 8)
    end, "replace", 1)
    love.graphics.setStencilTest("greater", 0)

    local itemStep = layout.width + layout.gap

    for index, item in ipairs(backgroundLibrary.items) do
        local itemX = listRect.x + (index - 1) * itemStep - ui.backgroundScrollX
        local itemY = listRect.y + 14

        if itemX + layout.width >= listRect.x and itemX <= listRect.x + listRect.width then
            local isSelected = index == backgroundLibrary.selectedIndex
            local borderColor = isSelected and {0.98, 0.55, 0.52, 0.95} or {1, 1, 1, 0.25}

            drawRoundedPanel(itemX, itemY, layout.width, layout.height, 8, {1, 1, 1, 0.72}, borderColor)
            drawImageContained(item.image, itemX + 8, itemY + 8, layout.width - 16, layout.height - 42)

            love.graphics.setColor(0.14, 0.10, 0.08, 1)
            love.graphics.printf("Room " .. index, itemX + 8, itemY + layout.height - 28, layout.width - 16, "center")
        end
    end

    love.graphics.setStencilTest()
    clampBackgroundScroll()

    local maxScroll = math.max(0, getBackgroundContentWidth() - listRect.width)

    if maxScroll > 0 then
        local barWidth = math.max(44, listRect.width * (listRect.width / getBackgroundContentWidth()))
        local barX = listRect.x + (listRect.width - barWidth) * (ui.backgroundScrollX / maxScroll)
        local barY = listRect.y + listRect.height - 12

        love.graphics.setColor(0, 0, 0, 0.18)
        love.graphics.rectangle("fill", listRect.x + 8, barY, listRect.width - 16, 4, 2, 2)
        love.graphics.setColor(0.95, 0.53, 0.50, 0.92)
        love.graphics.rectangle("fill", barX + 8, barY - 1, barWidth - 16, 6, 3, 3)
    end
end

local function drawInteriorCategoryButton(index, label, tabName)
    local rect = getInteriorCategoryButtonRect(index)
    local isActive = ui.activeInteriorTab == tabName
    local fillColor = isActive and {0.95, 0.54, 0.52, 0.96} or {1.0, 0.96, 0.90, 0.82}
    local lineColor = isActive and {0.56, 0.20, 0.18, 0.42} or {0.38, 0.25, 0.16, 0.20}
    local textColor = isActive and {1, 1, 1, 1} or {0.25, 0.16, 0.11, 0.82}

    drawRoundedPanel(rect.x, rect.y, rect.width, rect.height, 9, fillColor, lineColor)

    setUiColor(textColor)
    love.graphics.printf(label, rect.x + 4, rect.y + 15, rect.width - 8, "center")
end

local function drawInteriorSidebar()
    local sidebarRect = getInteriorSidebarRect()

    love.graphics.setColor(0.34, 0.24, 0.17, 0.08)
    love.graphics.rectangle("fill", sidebarRect.x - 8, sidebarRect.y - 12, sidebarRect.width + 16, sidebarRect.height + 24, 10, 10)

    drawInteriorCategoryButton(1, "BG", "backgrounds")
    drawInteriorCategoryButton(2, "Furniture", "furniture")

    -- 나중에 카테고리 버튼을 더 넣을 수 있도록 빈 슬롯 느낌만 살짝 남깁니다.
    for slotIndex = 3, 4 do
        local rect = getInteriorCategoryButtonRect(slotIndex)
        love.graphics.setColor(1, 1, 1, 0.22)
        love.graphics.rectangle("fill", rect.x, rect.y, rect.width, rect.height, 9, 9)
        love.graphics.setColor(0.38, 0.25, 0.16, 0.10)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", rect.x, rect.y, rect.width, rect.height, 9, 9)
    end
end

local function drawFurniturePanel()
    local listRect = getBackgroundListRect()
    local layout = getFurnitureItemLayout()

    drawRoundedPanel(listRect.x, listRect.y, listRect.width, listRect.height, 8, {0.10, 0.09, 0.09, 0.10}, {0.35, 0.22, 0.14, 0.14})

    for index, item in ipairs(furnitureLibrary.items) do
        local itemX = listRect.x + 14 + (index - 1) * (layout.width + layout.gap)
        local itemY = listRect.y + 14
        local isSelected = index == furnitureLibrary.selectedIndex
        local borderColor = isSelected and {0.98, 0.55, 0.52, 0.95} or {1, 1, 1, 0.25}

        drawRoundedPanel(itemX, itemY, layout.width, layout.height, 8, {1, 1, 1, 0.72}, borderColor)

        if chromaKeyShaderReady then
            love.graphics.setShader(chromaKeyShader)
        end

        drawImageContained(item.image, itemX + 8, itemY + 8, layout.width - 16, layout.height - 40)

        if chromaKeyShaderReady then
            love.graphics.setShader()
        end

        love.graphics.setColor(0.14, 0.10, 0.08, 1)
        love.graphics.printf(item.label, itemX + 8, itemY + layout.height - 26, layout.width - 16, "center")
    end
end

local function drawInteriorWindow()
    if not ui.isInteriorOpen then
        return
    end

    local rect = getInteriorWindowRect()
    local confirmRect = {
        x = rect.x + rect.width - 116,
        y = rect.y + rect.height - 54,
        width = 92,
        height = 34
    }
    local cancelRect = {
        x = confirmRect.x - 104,
        y = confirmRect.y,
        width = 92,
        height = 34
    }
    local closeRect = {
        x = rect.x + rect.width - 40,
        y = rect.y + 16,
        width = 24,
        height = 24
    }
    love.graphics.setColor(0, 0, 0, 0.38)
    love.graphics.rectangle("fill", 0, 0, virtualWidth, virtualHeight)

    drawRoundedPanel(rect.x, rect.y, rect.width, rect.height, 10, {0.98, 0.94, 0.88, 0.97}, {0.38, 0.23, 0.13, 0.35})

    love.graphics.setColor(0.17, 0.10, 0.08, 1)
    love.graphics.print("Interior", rect.x + 24, rect.y + 20)

    drawRoundedPanel(closeRect.x, closeRect.y, closeRect.width, closeRect.height, 6, {0.18, 0.13, 0.11, 0.12}, {0.18, 0.13, 0.11, 0.18})
    love.graphics.setColor(0.18, 0.10, 0.08, 1)
    love.graphics.printf("X", closeRect.x, closeRect.y + 4, closeRect.width, "center")

    drawInteriorSidebar()

    if ui.activeInteriorTab == "backgrounds" then
        drawBackgroundItems()
    elseif ui.activeInteriorTab == "furniture" then
        drawFurniturePanel()
    end

    drawRoundedPanel(cancelRect.x, cancelRect.y, cancelRect.width, cancelRect.height, 7, {0.26, 0.22, 0.20, 0.14}, {0.20, 0.14, 0.12, 0.22})
    love.graphics.setColor(0.18, 0.12, 0.09, 1)
    love.graphics.printf("Cancel", cancelRect.x, cancelRect.y + 9, cancelRect.width, "center")

    drawRoundedPanel(confirmRect.x, confirmRect.y, confirmRect.width, confirmRect.height, 7, {0.95, 0.53, 0.50, 0.95}, {0.46, 0.16, 0.14, 0.34})
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("OK", confirmRect.x, confirmRect.y + 9, confirmRect.width, "center")
end

local function drawUiLayer()
    drawMenuButton()
    drawDropdownMenu()
    drawInteriorWindow()
    drawChatWindow()
end

local function drawFloorDebugLine()
    if not floorDebug.enabled then
        return
    end

    love.graphics.setColor(1, 0.08, 0.06, 0.9)
    love.graphics.setLineWidth(3)
    love.graphics.line(0, getFloorTopY(), roomWorldWidth, getFloorTopY())
end

local function drawFloorDebugText()
    if not floorDebug.enabled then
        return
    end

    local copiedText = floorDebug.lastCopiedText

    if copiedText == "" then
        copiedText = buildFloorClipboardText()
    end

    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", 16, 106, 420, 76, 8, 8)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Floor tune: [ up / ] down / Ctrl+C copy", 24, 114)
    love.graphics.print(string.format("Current: %.3f", floorArea.topRatio), 24, 136)
    love.graphics.print(copiedText, 24, 158)
end

local function drawVirtualGame()
    -- 방 배경과 캐릭터는 세로 모드 카메라의 확대/이동을 적용해서 그립니다.
    love.graphics.push()
    love.graphics.translate(virtualWidth * 0.5, virtualHeight * 0.5)
    love.graphics.scale(camera.zoom, camera.zoom)
    love.graphics.translate(-camera.x, -camera.y)

    drawRoomBackground()
    drawFloorDebugLine()
    drawSortedWorldObjects()

    -- 캐릭터 그림자를 먼저 그리고, 그 위에 스프라이트 캐릭터를 그립니다.
    drawFurnitureEditControls()

    love.graphics.pop()

    -- 현재 모드와 조작 방법을 표시합니다.
    local animation = getCurrentAnimation()
    local spriteName = "placeholder"

    if animation and animation.isLoaded then
        spriteName = animation.fileName
    end

    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Tab: rotate test mode", 20, 20)
    love.graphics.print("Arrow keys: move character", 20, 42)
    love.graphics.print("Mode: " .. getOrientationName() .. " / " .. virtualWidth .. " x " .. virtualHeight, 20, 64)
    love.graphics.print("Sprite: " .. spriteName, 20, 86)

    drawUiLayer()
end

-- 매 프레임마다 실제 화면을 그립니다.
function love.draw()
    -- 전체 실제 창을 검은색으로 채워 레터박스 영역을 만듭니다.
    love.graphics.clear(0, 0, 0)

    -- 이후 그려지는 게임 장면을 현재 가상 해상도 기준에서 실제 창으로 스케일링합니다.
    love.graphics.push()
    love.graphics.translate(screen.offsetX, screen.offsetY)
    love.graphics.scale(screen.scale, screen.scale)

    drawVirtualGame()

    love.graphics.pop()
end
