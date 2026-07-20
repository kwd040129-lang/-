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
    stairLift = 0,
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
local windowViews = {
    day = {fileName = "furniture/window_views/day.png", image = nil},
    sunset = {fileName = "furniture/window_views/sunset.png", image = nil},
    night = {fileName = "furniture/window_views/night.png", image = nil}
}

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
    isRefrigeratorOpen = false,
    activeInteriorTab = "backgrounds",
    backgroundScrollX = 0,
    isBackgroundListDragging = false,
    backgroundDragLastX = 0
}

local refrigeratorStorage = {
    columns = 5,
    rows = 4,
    slots = {}
}

local chat = {
    input = "",
    composition = "",
    messages = {},
    scrollY = 0,
    contentHeight = 0,
    viewportHeight = 0,
    isBackspaceHeld = false,
    backspaceRepeatTimer = 0,
    backspaceRepeatStarted = false,
    portraitShowHistory = false,
    orientationBeforeOpen = nil,
    characterStateBeforeOpen = nil,
    isSending = false,
    threadErrorShown = false,
    thread = nil,
    requestChannel = nil,
    responseChannel = nil
}

local koreanUiFont = nil

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
        },
        {
            id = "refrigerator",
            label = "Refrigerator",
            fileName = "furniture/refrigerator.png",
            image = nil,
            isLoaded = false,
            width = 125,
            height = 198,
            minDepthScale = 0.65,
            maxDepthScale = 0.92,
            visualHeightScale = 1.0,
            -- 캐릭터 충돌은 발 중심 기준이므로 냉장고 본체보다 좌우로
            -- 조금 넓혀야 몸통이 이미지 안에 반쯤 들어간 뒤 막히지 않습니다.
            collisionInsetX = -0.16,
            collisionTopPadding = 0.62,
            collisionBottomPadding = 0.02,
            blocksMovement = true,
            renderBehind = false
        },
        {
            id = "stairs",
            label = "2-Step Stairs",
            fileName = "furniture/stairs.png",
            image = nil,
            isLoaded = false,
            width = 220,
            height = 168,
            minDepthScale = 0.62,
            maxDepthScale = 0.92,
            visualHeightScale = 1.28,
            collisionInsetX = 0.04,
            blocksMovement = true,
            renderBehind = false
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

local stairAction = {
    active = false,
    phase = nil,
    item = nil,
    stepIndex = 0,
    waypoints = nil,
    startX = 0,
    startY = 0,
    startLift = 0,
    elapsed = 0,
    duration = 0.42,
    landingDuration = 0.20,
    landingElapsed = 0,
    jumpHeight = 34,
    onTop = false,
    awaitRelease = false
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
local updateSpriteAnimation
local setCurrentAnimation
local setAnimationFromMoveVector

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
    -- 방 안의 깊이 위치(character.y)와 계단 위의 수직 높이를 분리합니다.
    -- 깊이 배율은 바닥 위치로 계산하되 그림만 발판 높이만큼 위로 올립니다.
    local groundFootY = character.y + character.height
    local footY = groundFootY - (character.stairLift or 0)

    return {
        x = footX - visualWidth * 0.5,
        y = footY - visualHeight,
        width = visualWidth,
        height = visualHeight,
        footX = footX,
        footY = footY,
        groundFootY = groundFootY,
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
    stairAction.onTop = false
    stairAction.awaitRelease = false
    character.stairLift = 0
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

-- 계단의 그림, 충돌, 오르기 동작이 모두 같은 측면형 2단 구조를 사용합니다.
local function getStairGeometry(item)
    local bounds = getFurnitureVisualBounds(item)
    -- stairs.png에는 큰 투명 여백이 있으므로 이미지 전체가 아닌 실제
    -- 불투명 픽셀 영역(원본 1436x1095에서 측정)을 계단으로 사용합니다.
    local bodyLeftX = bounds.x + bounds.width * (185 / 1436)
    local bodyRightX = bounds.x + bounds.width * (1251 / 1436)
    local splitRatio = 680 / 1436
    if item.flipX then
        splitRatio = 1 - splitRatio
    end
    local splitX = bounds.x + bounds.width * splitRatio
    local lowTopY = bounds.y + bounds.height * (475 / 1095)
    local highTopY = bounds.y + bounds.height * (249 / 1095)
    -- 캐릭터 발은 발판의 맨 위 윤곽선이 아니라 노란 상판 안쪽,
    -- 분홍색 테두리 바로 위까지 내려와야 자연스럽게 겹쳐 보입니다.
    local lowStandY = bounds.y + bounds.height * (600 / 1095)
    local highStandY = bounds.y + bounds.height * (385 / 1095)
    local baseY = bounds.y + bounds.height * (854 / 1095)
    -- 계단 뒤에는 캐릭터 한 명의 발 깊이보다 넉넉한 충돌 구역을 둡니다.
    -- 이 구역이 캐릭터가 계단 몸체 안까지 내려오는 것을 막아, 뒤로
    -- 지나갈 때 다리가 계단 아래로 튀어나오는 현상을 방지합니다.
    local depthBand = math.max(30, bounds.height * 0.22)
    -- 화면 아래쪽이 앞쪽이므로 앞 경계도 계단 바닥선보다 위에 둡니다.
    local collisionFrontY = baseY - bounds.height * 0.025
    local collisionBackY = collisionFrontY - depthBand

    return {
        bounds = bounds,
        bodyLeftX = bodyLeftX,
        bodyRightX = bodyRightX,
        splitX = splitX,
        ascendingDirection = item.flipX and -1 or 1,
        lowTopY = lowTopY,
        highTopY = highTopY,
        lowStandY = lowStandY,
        highStandY = highStandY,
        baseY = baseY,
        backY = collisionBackY,
        frontY = collisionFrontY,
        depthBand = depthBand
    }
end

local function getFurnitureCollisionRect(item)
    local bounds = getFurnitureVisualBounds(item)
    local marginX = bounds.width * (item.collisionInsetX or 0.02)

    if item.id == "stairs" then
        local geometry = getStairGeometry(item)
        return geometry.bodyLeftX,
            geometry.backY,
            geometry.bodyRightX - geometry.bodyLeftX,
            geometry.frontY - geometry.backY
    end

    local topPadding = bounds.height * (item.collisionTopPadding or 0.03)
    local bottomPadding = bounds.height * (item.collisionBottomPadding or 0)
    return bounds.x + marginX,
        bounds.y + topPadding,
        bounds.width - marginX * 2,
        bounds.height - topPadding - bottomPadding
end

local function getNearbyRefrigerator()
    if character.isDragging
        or character.isMovingToTarget
        or sprite.isMovingByKeyboard
        or stairAction.active
        or stairAction.onTop then
        return nil
    end

    local characterBounds = getCharacterVisualBounds()

    for _, item in ipairs(placedFurniture) do
        if item.id == "refrigerator" then
            local bounds = getFurnitureVisualBounds(item)
            local horizontalDistance = math.abs(characterBounds.footX - bounds.footX)
            local frontDistance = characterBounds.groundFootY - bounds.footY
            local horizontalLimit = math.max(30, bounds.width * 0.46)
            local isInFront = frontDistance >= -4 and frontDistance <= 34
            local isCloseEnough = horizontalDistance <= horizontalLimit

            if isInFront and isCloseEnough then
                return item
            end
        end
    end

    return nil
end

local function getRefrigeratorOpenButtonRect(item)
    local bounds = getFurnitureVisualBounds(item)
    local centerX = (bounds.footX - camera.x) * camera.zoom + virtualWidth * 0.5
    local bottomY = (bounds.footY - camera.y) * camera.zoom + virtualHeight * 0.5
    local width = 116
    local height = 34

    return {
        x = clamp(centerX - width * 0.5, 10, virtualWidth - width - 10),
        y = clamp(bottomY + 12, 10, virtualHeight - height - 10),
        width = width,
        height = height
    }
end

local function getRefrigeratorWindowRect()
    local width = math.min(390, virtualWidth - 28)
    local height = math.min(330, virtualHeight - 36)
    return {
        x = (virtualWidth - width) * 0.5,
        y = (virtualHeight - height) * 0.5,
        width = width,
        height = height
    }
end

local function getRefrigeratorCloseRect()
    local rect = getRefrigeratorWindowRect()
    return {
        x = rect.x + rect.width - 42,
        y = rect.y + 14,
        width = 28,
        height = 28
    }
end

local function openRefrigeratorWindow()
    ui.isRefrigeratorOpen = true
    ui.isMenuOpen = false
    character.isMovingToTarget = false
    character.movePath = nil
    sprite.isMovingByKeyboard = false
    furnitureEdit.selectedItem = nil
    furnitureEdit.isSizing = false
    furnitureDrag.item = nil
end

local function closeRefrigeratorWindow()
    ui.isRefrigeratorOpen = false
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

local function getFurnitureFlipButtonRect(item)
    local bounds = getFurnitureVisualBounds(item)
    local scale = math.max(0.5, bounds.scale)
    local width = 58 / scale
    local height = 24 / scale
    return {
        x = bounds.x,
        y = bounds.y - height - 6 / scale,
        width = width,
        height = height
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
        renderBehind = libraryItem.renderBehind,
        flipX = false
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

local function beginStairHop(stepIndex)
    local waypoint = stairAction.waypoints and stairAction.waypoints[stepIndex]
    if not waypoint then
        stairAction.active = false
        stairAction.phase = nil
        stairAction.onTop = true
        stairAction.awaitRelease = true
        character.isLanded = true
        character.fallTargetY = character.y
        sprite.isMovingByKeyboard = false
        setCurrentAnimation("front")
        return
    end

    stairAction.phase = "hop"
    stairAction.onTop = false
    stairAction.stepIndex = stepIndex
    stairAction.startX = character.x
    stairAction.startY = character.y
    stairAction.startLift = character.stairLift or 0
    stairAction.elapsed = 0
    stairAction.landingElapsed = 0
    character.isLanded = false
    character.fallTargetY = nil
    sprite.currentFrame = 1
end

local function startStairClimb(item)
    local geometry = getStairGeometry(item)
    local floorFootY = geometry.baseY + 3
    local approachFootX = item.flipX and geometry.bodyRightX or geometry.bodyLeftX
    local lowCenterX = item.flipX
        and (geometry.splitX + geometry.bodyRightX) * 0.5
        or (geometry.bodyLeftX + geometry.splitX) * 0.5
    local highCenterX = item.flipX
        and (geometry.bodyLeftX + geometry.splitX) * 0.5
        or (geometry.splitX + geometry.bodyRightX) * 0.5
    local approachX = approachFootX - character.width * 0.5
    local firstStepX = lowCenterX - character.width * 0.5
    local secondStepX = highCenterX - character.width * 0.5

    stairAction.active = true
    stairAction.onTop = false
    stairAction.awaitRelease = false
    stairAction.phase = "approach"
    stairAction.item = item
    stairAction.stepIndex = 0
    stairAction.elapsed = 0
    stairAction.landingElapsed = 0
    stairAction.waypoints = {
        {
            x = firstStepX,
            lift = math.max(0, floorFootY - geometry.lowStandY),
            surfaceY = geometry.lowStandY
        },
        {
            x = secondStepX,
            lift = math.max(0, floorFootY - geometry.highStandY),
            surfaceY = geometry.highStandY
        }
    }
    stairAction.approachX = clamp(approachX, 0, roomWorldWidth - character.width)
    stairAction.approachY = clamp(floorFootY - character.height, getMinCharacterFloorY(), getWorldFloorY())

    character.isMovingToTarget = false
    character.movePath = nil
    character.isLanded = true
    character.fallTargetY = nil
    character.stairLift = 0
end

local function tryStartAutomaticStairClimb(moveX, moveY)
    if stairAction.active
        or character.isDragging
        or math.abs(moveY) > 0.70 then
        return false
    end

    -- 첫 번째 발판에 서 있다면 새 접근 동작 없이 두 번째 단만 오릅니다.
    -- 첫 착지 때 설정된 awaitRelease가 해제된 뒤의 새 이동 입력만 받습니다.
    if stairAction.onTop then
        local climbDirection = stairAction.item and getStairGeometry(stairAction.item).ascendingDirection or 1
        if stairAction.stepIndex == 1
            and stairAction.item
            and not stairAction.awaitRelease
            and moveX * climbDirection > 0.35 then
            stairAction.active = true
            beginStairHop(2)
            return true
        end

        return false
    end

    local characterBounds = getCharacterVisualBounds()

    for _, item in ipairs(placedFurniture) do
        if item.id == "stairs" then
            local geometry = getStairGeometry(item)
            local bounds = geometry.bounds
            local climbDirection = geometry.ascendingDirection
            local lowOuterEdgeX = item.flipX and geometry.bodyRightX or geometry.bodyLeftX
            local footDistanceToFirstStep = (lowOuterEdgeX - characterBounds.footX) * climbDirection
            local laneTolerance = math.max(24, bounds.height * 0.15)
            local approachDistance = math.max(56, characterBounds.width * 0.78)
            local edgeAllowance = math.max(8, bounds.width * 0.035)
            local isMovingUpStairs = moveX * climbDirection > 0.35
            local isBesideFirstStep = characterBounds.footX * climbDirection
                    <= lowOuterEdgeX * climbDirection + edgeAllowance
                and footDistanceToFirstStep >= -edgeAllowance
                and footDistanceToFirstStep <= approachDistance
            local isAtFloorLane = math.abs(characterBounds.footY - geometry.baseY) <= laneTolerance

            if isMovingUpStairs and isBesideFirstStep and isAtFloorLane then
                startStairClimb(item)
                return true
            end
        end
    end

    return false
end

local function updateStairAction(dt)
    if not stairAction.active then
        return false
    end

    if not stairAction.item then
        stairAction.active = false
        return false
    end

    if stairAction.phase == "approach" then
        local deltaX = stairAction.approachX - character.x
        local deltaY = stairAction.approachY - character.y
        local distance = math.sqrt(deltaX * deltaX + deltaY * deltaY)

        if distance <= 4 then
            character.x = stairAction.approachX
            character.y = stairAction.approachY
            beginStairHop(1)
        else
            local moveAmount = math.min(distance, character.moveSpeed * dt)
            character.x = character.x + deltaX / distance * moveAmount
            character.y = character.y + deltaY / distance * moveAmount
            sprite.isMovingByKeyboard = true
            setAnimationFromMoveVector(deltaX, deltaY)
            updateSpriteAnimation(dt)
        end
    elseif stairAction.phase == "hop" then
        local waypoint = stairAction.waypoints[stairAction.stepIndex]
        stairAction.elapsed = stairAction.elapsed + dt
        local ratio = clamp(stairAction.elapsed / stairAction.duration, 0, 1)
        local smoothRatio = ratio * ratio * (3 - 2 * ratio)
        local arcHeight = math.sin(ratio * math.pi) * stairAction.jumpHeight
        character.x = stairAction.startX + (waypoint.x - stairAction.startX) * smoothRatio
        character.y = stairAction.startY
        character.stairLift = stairAction.startLift
            + (waypoint.lift - stairAction.startLift) * smoothRatio
            + arcHeight
        sprite.isMovingByKeyboard = false
        setCurrentAnimation("front")
        sprite.currentFrame = 1

        if ratio >= 1 then
            character.x = waypoint.x
            character.y = stairAction.startY
            character.stairLift = waypoint.lift
            -- 발바닥을 현재 발판 윗면에 정확히 고정하고 잠시 착지한 뒤
            -- 다음 단으로 이동합니다. 이 동안 방 바닥 낙하는 적용되지 않습니다.
            stairAction.phase = "land"
            stairAction.onTop = true
            stairAction.landingElapsed = 0
            character.isLanded = true
            character.fallTargetY = character.y
            sprite.isMovingByKeyboard = false
            setCurrentAnimation("front")
        end
    elseif stairAction.phase == "land" then
        local waypoint = stairAction.waypoints[stairAction.stepIndex]
        character.x = waypoint.x
        character.stairLift = waypoint.lift
        character.isLanded = true
        character.fallTargetY = character.y
        sprite.isMovingByKeyboard = false
        setCurrentAnimation("front")

        stairAction.landingElapsed = stairAction.landingElapsed + dt
        if stairAction.landingElapsed >= stairAction.landingDuration then
            if stairAction.stepIndex == 1 then
                -- 첫 단에서는 자동으로 다음 단을 오르지 않습니다. 이동키를
                -- 놓았다가 계단 방향으로 다시 눌러야 두 번째 점프를 시작합니다.
                stairAction.active = false
                stairAction.phase = nil
                stairAction.onTop = true
                stairAction.awaitRelease = true
            else
                beginStairHop(stairAction.stepIndex + 1)
            end
        end
    end

    updateCamera(dt, false)
    return true
end

local function isPointOnPlacedFurniture(worldX, worldY)
    for _, item in ipairs(placedFurniture) do
        if item.blocksMovement ~= false then
            local blockX, blockY, blockWidth, blockHeight = getFurnitureCollisionRect(item)

            if worldX >= blockX
                and worldX <= blockX + blockWidth
                and worldY >= blockY
                and worldY <= blockY + blockHeight then
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
            local blockX, blockY, blockWidth, blockHeight = getFurnitureCollisionRect(item)

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
    local footWidth = character.width * depthScale * 0.34
    local footHeight = 18 * depthScale
    local footRectX = footX - footWidth * 0.5
    local footRectY = footY - footHeight

    return isRectOnPlacedFurniture(footRectX, footRectY, footWidth, footHeight)
end

local function getCharacterFurnitureOverlapAreaAt(characterX, characterY)
    local footX = characterX + character.width * 0.5
    local footY = characterY + character.height
    local farFootY = getFloorTopY()
    local nearFootY = roomWorldHeight
    local depthRatio = clamp((footY - farFootY) / (nearFootY - farFootY), 0, 1)
    local depthScale = character.minDepthScale + (character.maxDepthScale - character.minDepthScale) * depthRatio
    local footWidth = character.width * depthScale * 0.34
    local footHeight = 18 * depthScale
    local footLeft = footX - footWidth * 0.5
    local footTop = footY - footHeight
    local totalArea = 0

    for _, item in ipairs(placedFurniture) do
        if item.blocksMovement ~= false then
            local blockLeft, blockTop, blockWidth, blockHeight = getFurnitureCollisionRect(item)
            local blockRight = blockLeft + blockWidth
            local blockBottom = blockTop + blockHeight
            local overlapWidth = math.max(0, math.min(footLeft + footWidth, blockRight) - math.max(footLeft, blockLeft))
            local overlapHeight = math.max(0, math.min(footTop + footHeight, blockBottom) - math.max(footTop, blockTop))
            totalArea = totalArea + overlapWidth * overlapHeight
        end
    end

    return totalArea
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
setCurrentAnimation = function(animationName)
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
setAnimationFromMoveVector = function(moveX, moveY)
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

local function loadWindowViews()
    for _, view in pairs(windowViews) do
        view.image = nil
        if love.filesystem.getInfo(view.fileName) then
            local success, imageOrError = pcall(love.graphics.newImage, view.fileName)
            if success then
                view.image = imageOrError
                view.image:setFilter("linear", "linear")
            end
        end
    end
end

local function getCurrentWindowView()
    local hour = tonumber(os.date("%H")) or 12
    if hour >= 6 and hour < 17 then
        return windowViews.day.image
    elseif hour >= 17 and hour < 20 then
        return windowViews.sunset.image
    end
    return windowViews.night.image
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
    if currentOrientation == "portrait" then
        return {x = 0, y = 0, width = virtualWidth, height = virtualHeight}
    end

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

    if currentOrientation == "portrait" then
        return {x = rect.width - 56, y = 10, width = 42, height = 42}
    end

    return {x = rect.x + rect.width - 42, y = rect.y + 10, width = 30, height = 30}
end

local function getChatCloseHitRect()
    local rect = getChatCloseRect()
    local padding = currentOrientation == "portrait" and 12 or 6
    return {
        x = rect.x - padding,
        y = rect.y - padding,
        width = rect.width + padding * 2,
        height = rect.height + padding * 2
    }
end

local function getChatInputRect()
    local rect = getChatWindowRect()

    if currentOrientation == "portrait" then
        local keyboardTop = math.floor(virtualHeight * 0.625)
        return {x = 16, y = keyboardTop - 58, width = rect.width - 112, height = 44}
    end

    return {x = rect.x + 16, y = rect.y + rect.height - 54, width = rect.width - 112, height = 38}
end

local function getChatSendRect()
    local rect = getChatWindowRect()

    if currentOrientation == "portrait" then
        local keyboardTop = math.floor(virtualHeight * 0.625)
        return {x = rect.width - 94, y = keyboardTop - 58, width = 78, height = 44}
    end

    return {x = rect.x + rect.width - 88, y = rect.y + rect.height - 54, width = 72, height = 38}
end

local function getChatHistoryToggleRect()
    return {x = 16, y = 14, width = 112, height = 36}
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
        width = 130,
        height = 132,
        gap = 12
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
    chat.scrollY = 0
    while #chat.messages > 20 do
        table.remove(chat.messages, 1)
    end
end

local function openChatWindow()
    chat.orientationBeforeOpen = currentOrientation
    chat.characterStateBeforeOpen = {
        x = character.x,
        y = character.y,
        isLanded = character.isLanded,
        fallTargetY = character.fallTargetY,
        fallSpeed = character.fallSpeed,
        isMovingToTarget = false,
        targetX = character.targetX,
        targetY = character.targetY,
        movePath = nil,
        movePathIndex = 1
    }

    -- 채팅을 여는 순간 진행 중인 이동을 취소하고 현재 위치에 멈춥니다.
    character.isMovingToTarget = false
    character.movePath = nil
    character.movePathIndex = 1
    sprite.isMovingByKeyboard = false
    sprite.currentAnimation = "front"
    sprite.currentFrame = 1
    sprite.timer = 0

    if currentOrientation == "landscape" then
        toggleOrientation()
    end

    ui.isChatOpen = true
    ui.isMenuOpen = false
    ui.isInteriorOpen = false
    chat.composition = ""
    chat.isBackspaceHeld = false
    chat.backspaceRepeatTimer = 0
    chat.backspaceRepeatStarted = false
    chat.portraitShowHistory = false
    love.keyboard.setTextInput(true)
end

local function closeChatWindow()
    ui.isChatOpen = false
    chat.composition = ""
    chat.isBackspaceHeld = false
    chat.backspaceRepeatTimer = 0
    chat.backspaceRepeatStarted = false
    chat.portraitShowHistory = false
    love.keyboard.setTextInput(false)

    if chat.orientationBeforeOpen and currentOrientation ~= chat.orientationBeforeOpen then
        toggleOrientation()
    end

    local savedState = chat.characterStateBeforeOpen
    if savedState then
        character.x = savedState.x
        character.y = savedState.y
        character.isLanded = savedState.isLanded
        character.fallTargetY = savedState.fallTargetY
        character.fallSpeed = savedState.fallSpeed
        character.isMovingToTarget = savedState.isMovingToTarget
        character.targetX = savedState.targetX
        character.targetY = savedState.targetY
        character.movePath = savedState.movePath
        character.movePathIndex = savedState.movePathIndex
        updateCamera(0, true)
    end

    chat.orientationBeforeOpen = nil
    chat.characterStateBeforeOpen = nil
end

local function deleteLastChatCharacter()
    local byteOffset = utf8.offset(chat.input, -1)

    if byteOffset then
        chat.input = chat.input:sub(1, byteOffset - 1)
    end
end

local function sendChatMessage()
    local message = chat.input:match("^%s*(.-)%s*$")
    if message == "" or chat.isSending or not chat.requestChannel then
        return
    end

    addChatMessage("user", message)
    chat.input = ""
    chat.composition = ""
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
    if ui.isRefrigeratorOpen then
        if isPointInsideRect(virtualX, virtualY, getRefrigeratorCloseRect()) then
            closeRefrigeratorWindow()
        end
        return true
    end

    if ui.isChatOpen then
        if isPointInsideRect(virtualX, virtualY, getChatCloseHitRect()) then
            closeChatWindow()
        elseif currentOrientation == "portrait" and isPointInsideRect(virtualX, virtualY, getChatHistoryToggleRect()) then
            chat.portraitShowHistory = not chat.portraitShowHistory
            chat.scrollY = 0
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

    if not ui.isInteriorOpen and not ui.isChatOpen then
        local refrigerator = getNearbyRefrigerator()
        if refrigerator and isPointInsideRect(virtualX, virtualY, getRefrigeratorOpenButtonRect(refrigerator)) then
            openRefrigeratorWindow()
            return true
        end
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
local function loadKoreanUiFont()
    local fontPaths = {
        "C:/Windows/Fonts/malgun.ttf",
        "C:/Windows/Fonts/malgunsl.ttf"
    }

    for _, fontPath in ipairs(fontPaths) do
        local file = io.open(fontPath, "rb")
        if file then
            local contents = file:read("*a")
            file:close()
            local fileData = love.filesystem.newFileData(contents, "korean_ui_font.ttf")
            local success, font = pcall(love.graphics.newFont, fileData, 15)
            if success then
                koreanUiFont = font
                love.graphics.setFont(koreanUiFont)
                return
            end
        end
    end
end

function love.load()
    chat.requestChannel = love.thread.getChannel("chat_requests")
    chat.responseChannel = love.thread.getChannel("chat_responses")
    chat.requestChannel:clear()
    chat.responseChannel:clear()
    chat.thread = love.thread.newThread("chat_worker.lua")
    chat.thread:start()
    loadKoreanUiFont()

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
    loadWindowViews()
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
    if ui.isRefrigeratorOpen then
        if key == "escape" then
            closeRefrigeratorWindow()
        end
        return
    end

    if ui.isChatOpen then
        if key == "escape" then
            closeChatWindow()
        elseif key == "return" or key == "kpenter" then
            sendChatMessage()
        elseif key == "backspace" then
            if chat.composition ~= "" then
                return
            end
            deleteLastChatCharacter()
            chat.isBackspaceHeld = true
            chat.backspaceRepeatTimer = 0
            chat.backspaceRepeatStarted = false
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

function love.keyreleased(key)
    if key == "backspace" then
        chat.isBackspaceHeld = false
        chat.backspaceRepeatTimer = 0
        chat.backspaceRepeatStarted = false
    end
end

-- 마우스 버튼을 눌렀을 때 실행됩니다.
function love.textinput(text)
    if ui.isChatOpen and not chat.isSending and #chat.input < 1000 then
        chat.input = chat.input .. text
        chat.composition = ""
    end
end

function love.textedited(text, start, length)
    if ui.isChatOpen and not chat.isSending then
        chat.composition = text or ""
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
            local flipRect = furnitureEdit.selectedItem.id == "stairs"
                and getFurnitureFlipButtonRect(furnitureEdit.selectedItem)
                or nil

            if flipRect and isPointInsideRect(pointerX, pointerY, flipRect) then
                furnitureEdit.selectedItem.flipX = not furnitureEdit.selectedItem.flipX
                stairAction.active = false
                stairAction.onTop = false
                stairAction.awaitRelease = false
                character.stairLift = 0
                return
            end

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
            stairAction.onTop = false
            stairAction.awaitRelease = false
            character.stairLift = 0
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
    if ui.isChatOpen then
        local maxScroll = math.max(0, chat.contentHeight - chat.viewportHeight)
        chat.scrollY = clamp(chat.scrollY + y * 42, 0, maxScroll)
    elseif ui.isInteriorOpen and ui.activeInteriorTab == "backgrounds" then
        ui.backgroundScrollX = ui.backgroundScrollX - y * 48 - x * 48
        clampBackgroundScroll()
    end
end

-- 매 프레임마다 스프라이트 애니메이션을 갱신합니다.
updateSpriteAnimation = function(dt)
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

    if chat.isBackspaceHeld then
        if not ui.isChatOpen or not love.keyboard.isDown("backspace") or chat.composition ~= "" then
            chat.isBackspaceHeld = false
            chat.backspaceRepeatTimer = 0
            chat.backspaceRepeatStarted = false
        else
            chat.backspaceRepeatTimer = chat.backspaceRepeatTimer + dt
            local repeatDelay = chat.backspaceRepeatStarted and 0.045 or 0.38

            while chat.backspaceRepeatTimer >= repeatDelay do
                chat.backspaceRepeatTimer = chat.backspaceRepeatTimer - repeatDelay
                chat.backspaceRepeatStarted = true
                deleteLastChatCharacter()
                repeatDelay = 0.045
            end
        end
    end

    -- 채팅 화면은 별도의 전체 화면 장면입니다. 대화 중에는 뒤쪽 방의
    -- 이동과 낙하를 멈춰 열기 전 캐릭터 위치가 바뀌지 않게 합니다.
    if ui.isChatOpen then
        return
    end

    if ui.isRefrigeratorOpen then
        return
    end

    if updateStairAction(dt) then
        return
    end

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

    -- 오르기 키를 계속 누르고 있어도 정상에 도착하자마자 바닥으로
    -- 이탈하지 않게, 한 번 키를 놓을 때까지 계단 위 착지를 유지합니다.
    if stairAction.awaitRelease then
        if moveX == 0 and moveY == 0 then
            stairAction.awaitRelease = false
        else
            moveX = 0
            moveY = 0
        end
    end

    if moveX ~= 0 or moveY ~= 0 then
        character.isMovingToTarget = false
        if not stairAction.onTop then
            character.fallTargetY = nil
        end
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

    local intendedMoveX = moveX ~= 0 and moveX or targetMoveX
    local intendedMoveY = moveY ~= 0 and moveY or targetMoveY
    if tryStartAutomaticStairClimb(intendedMoveX, intendedMoveY) then
        updateCamera(dt, false)
        return
    end

    -- 계단 오르기 입력이 아니라고 확인된 뒤에만 발판 상태를 해제합니다.
    if (moveX ~= 0 or moveY ~= 0) and stairAction.onTop then
        character.stairLift = 0
        stairAction.onTop = false
        character.fallTargetY = nil
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
        local previousOverlapArea = getCharacterFurnitureOverlapAreaAt(previousX, previousY)

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

        local nextOverlapArea = getCharacterFurnitureOverlapAreaAt(character.x, character.y)
        -- 계단에서 내려온 직후처럼 이미 충돌 영역과 조금 겹친 상태에서는
        -- 겹침을 더 키우는 이동만 막습니다. 같은 깊이의 좌우 이동이나
        -- 충돌 영역 밖으로 빠져나가는 이동까지 막으면 투명벽에 갇힙니다.
        local enteredNewCollision = previousOverlapArea <= 0.01 and nextOverlapArea > 0.01
        local movedDeeperIntoCollision = previousOverlapArea > 0.01
            and nextOverlapArea > previousOverlapArea + 0.01
        if enteredNewCollision or movedDeeperIntoCollision then
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

    if item.id == "window" then
        local viewImage = getCurrentWindowView()
        if viewImage then
            -- The green panes occupy this normalized rectangle in window.png.
            -- Draw the outdoor scene behind it; the frame drawn below covers the divider.
            local paneX = bounds.x + bounds.width * 0.234
            local paneY = bounds.y + bounds.height * 0.217
            local paneWidth = bounds.width * 0.533
            local paneHeight = bounds.height * 0.645
            local coverScale = math.max(paneWidth / viewImage:getWidth(), paneHeight / viewImage:getHeight())
            local viewWidth = viewImage:getWidth() * coverScale
            local viewHeight = viewImage:getHeight() * coverScale
            local viewX = paneX + (paneWidth - viewWidth) * 0.5
            local viewY = paneY + (paneHeight - viewHeight) * 0.5

            love.graphics.setShader()
            love.graphics.stencil(function()
                love.graphics.rectangle("fill", paneX, paneY, paneWidth, paneHeight)
            end, "replace", 1)
            love.graphics.setStencilTest("greater", 0)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(viewImage, viewX, viewY, 0, coverScale, coverScale)
            love.graphics.setStencilTest()
        end
    end

    -- 침대와 계단은 알파 채널이 있는 투명 PNG이므로 크로마키를 사용하지 않습니다.
    -- 초록색 유리 영역을 가진 기존 창문 이미지에만 셰이더를 적용합니다.
    local useChromaKey = item.id == "window" and chromaKeyShaderReady
    if useChromaKey then
        love.graphics.setShader(chromaKeyShader)
    end
    love.graphics.setColor(1, 1, 1, 1)
    if item.flipX then
        love.graphics.draw(item.image, bounds.x + bounds.width, bounds.y, 0, -scaleX, scaleY)
    else
        love.graphics.draw(item.image, bounds.x, bounds.y, 0, scaleX, scaleY)
    end
    if useChromaKey then
        love.graphics.setShader()
    end
end

local function drawPlacedFurniture()
    for _, item in ipairs(placedFurniture) do
        drawFurnitureItem(item)
    end
end

local function drawCharacterShadow()
    -- 계단을 오르기 시작한 뒤에는 발판 자체가 캐릭터를 받치므로
    -- 방 바닥용 타원 그림자를 표시하지 않습니다.
    if (stairAction.active and stairAction.phase ~= "approach") or stairAction.onTop then
        return
    end

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
    local characterDepthY = (stairAction.active or stairAction.onTop) and math.huge or characterBounds.footY

    if character.isDragging then
        table.insert(drawItems, {
            kind = "character_shadow",
            depthY = character.dragShadowFootY
        })
    else
        table.insert(drawItems, {
            kind = "character",
            depthY = characterDepthY
        })
    end

    for _, item in ipairs(placedFurniture) do
        local bounds = getFurnitureVisualBounds(item)
        local furnitureDepthY = item.renderBehind and -math.huge or bounds.footY

        -- 계단 바로 앞의 캐릭터가 뒤로 잘못 분류되지 않도록 계단 뒤쪽
        -- 경계선을 깊이 정렬 기준으로 사용합니다.
        if item.id == "stairs" and not item.renderBehind then
            furnitureDepthY = getStairGeometry(item).backY
        end

        table.insert(drawItems, {
            kind = "furniture",
            depthY = furnitureDepthY,
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
            drawFurnitureItem(entry.item)
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

local function getSingleLineTextTail(text, maxWidth)
    local font = love.graphics.getFont()
    local visibleText = text:gsub("[\r\n]", " ")

    while visibleText ~= "" and font:getWidth(visibleText) > maxWidth do
        local nextCharacter = utf8.offset(visibleText, 2)
        visibleText = nextCharacter and visibleText:sub(nextCharacter) or ""
    end

    return visibleText
end

local function drawStandardChatWindow()
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

    if currentOrientation == "portrait" then
        local keyboardTop = math.floor(virtualHeight * 0.625)
        love.graphics.setColor(0.91, 0.87, 0.82, 1)
        love.graphics.rectangle("fill", 0, keyboardTop, virtualWidth, virtualHeight - keyboardTop)
    end

    love.graphics.setColor(0.18, 0.12, 0.09, 1)
    if currentOrientation == "portrait" then
        love.graphics.printf("대화 기록", 0, rect.y + 22, rect.width, "center")
        local toggleRect = getChatHistoryToggleRect()
        drawRoundedPanel(toggleRect.x, toggleRect.y, toggleRect.width, toggleRect.height, 8, {0.95, 0.53, 0.50, 0.96}, {0.46, 0.16, 0.14, 0.34})
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf("캐릭터", toggleRect.x, toggleRect.y + 8, toggleRect.width, "center")
    else
        love.graphics.print("Chat", rect.x + 18, rect.y + 18)
    end
    drawRoundedPanel(closeRect.x, closeRect.y, closeRect.width, closeRect.height, 7, {0.28, 0.22, 0.20, 0.16}, {0.30, 0.20, 0.16, 0.30})
    love.graphics.setColor(0.18, 0.12, 0.09, 1)
    love.graphics.printf("X", closeRect.x, closeRect.y + 7, closeRect.width, "center")

    local viewportX = rect.x + 12
    local viewportY = rect.y + 50
    local viewportWidth = rect.width - 24
    local viewportBottom = inputRect.y - 28
    local viewportHeight = viewportBottom - viewportY
    local textWidth = rect.width - 110
    local font = love.graphics.getFont()
    local messageLayouts = {}
    local totalHeight = 0

    for index, message in ipairs(chat.messages) do
        local _, wrappedLines = font:getWrap(message.text, textWidth)
        local bubbleHeight = math.max(46, #wrappedLines * font:getHeight() + 16)
        messageLayouts[index] = bubbleHeight
        totalHeight = totalHeight + bubbleHeight + 6
    end

    chat.contentHeight = totalHeight
    chat.viewportHeight = viewportHeight
    chat.scrollY = clamp(chat.scrollY, 0, math.max(0, totalHeight - viewportHeight))
    local messageY = viewportBottom - totalHeight + chat.scrollY
    local oldScissorX, oldScissorY, oldScissorWidth, oldScissorHeight = love.graphics.getScissor()
    love.graphics.setScissor(
        screen.offsetX + viewportX * screen.scale,
        screen.offsetY + viewportY * screen.scale,
        viewportWidth * screen.scale,
        viewportHeight * screen.scale
    )

    for index, message in ipairs(chat.messages) do
        local message = chat.messages[index]
        local label = message.role == "user" and "You" or (message.role == "assistant" and "Gemini" or "System")
        local bubbleColor = message.role == "user" and {0.95, 0.70, 0.66, 0.34} or {1, 1, 1, 0.58}
        local bubbleHeight = messageLayouts[index]
        drawRoundedPanel(rect.x + 16, messageY, rect.width - 32, bubbleHeight, 7, bubbleColor, nil)
        love.graphics.setColor(0.34, 0.19, 0.14, 1)
        love.graphics.print(label .. ":", rect.x + 24, messageY + 6)
        love.graphics.setColor(0.16, 0.12, 0.10, 1)
        love.graphics.printf(message.text, rect.x + 78, messageY + 6, textWidth, "left")
        messageY = messageY + bubbleHeight + 6
    end

    if oldScissorX then
        love.graphics.setScissor(oldScissorX, oldScissorY, oldScissorWidth, oldScissorHeight)
    else
        love.graphics.setScissor()
    end

    if chat.isSending then
        love.graphics.setColor(0.38, 0.28, 0.22, 0.8)
        love.graphics.print("Gemini is typing...", rect.x + 18, inputRect.y - 22)
    end

    drawRoundedPanel(inputRect.x, inputRect.y, inputRect.width, inputRect.height, 7, {1, 1, 1, 0.90}, {0.35, 0.22, 0.14, 0.45})
    love.graphics.setColor(0.16, 0.12, 0.10, 1)
    local visibleInput = chat.input .. chat.composition
    local inputText = visibleInput ~= "" and visibleInput or "Type a message..."
    inputText = getSingleLineTextTail(inputText, inputRect.width - 20)
    love.graphics.print(inputText, inputRect.x + 10, inputRect.y + 10)

    local sendColor = chat.isSending and {0.55, 0.52, 0.50, 0.75} or {0.95, 0.53, 0.50, 0.96}
    drawRoundedPanel(sendRect.x, sendRect.y, sendRect.width, sendRect.height, 7, sendColor, {0.46, 0.16, 0.14, 0.34})
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Send", sendRect.x, sendRect.y + 10, sendRect.width, "center")
end

local function getLatestCharacterReply()
    if chat.isSending then
        return "생각하고 있어..."
    end

    for index = #chat.messages, 1, -1 do
        local message = chat.messages[index]
        if message.role == "assistant" or message.role == "system" then
            return message.text
        end
    end

    return "무슨 이야기를 해볼까?"
end

local function drawChatCharacterAt(centerX, bottomY, drawHeight)
    local animation = getCurrentAnimation()
    local drawWidth = drawHeight * sprite.frameWidth / sprite.frameHeight
    local drawX = centerX - drawWidth * 0.5
    local drawY = bottomY - drawHeight

    love.graphics.setColor(0, 0, 0, 0.16)
    love.graphics.ellipse("fill", centerX, bottomY - 3, drawWidth * 0.42, 10)

    if not animation or not animation.isLoaded or not animation.quads[sprite.currentFrame] then
        love.graphics.setColor(0.96, 0.72, 0.76, 1)
        love.graphics.circle("fill", centerX, drawY + drawHeight * 0.30, drawWidth * 0.28)
        love.graphics.rectangle("fill", drawX + drawWidth * 0.25, drawY + drawHeight * 0.48, drawWidth * 0.50, drawHeight * 0.46, 12, 12)
        return
    end

    if chromaKeyShaderReady then
        love.graphics.setShader(chromaKeyShader)
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(
        animation.image,
        animation.quads[sprite.currentFrame],
        drawX,
        drawY,
        0,
        drawWidth / sprite.frameWidth,
        drawHeight / sprite.frameHeight
    )

    if chromaKeyShaderReady then
        love.graphics.setShader()
    end
end

local function drawPortraitCharacterChat()
    local closeRect = getChatCloseRect()
    local toggleRect = getChatHistoryToggleRect()
    local inputRect = getChatInputRect()
    local sendRect = getChatSendRect()
    local keyboardTop = math.floor(virtualHeight * 0.625)

    love.graphics.setColor(0.98, 0.95, 0.90, 1)
    love.graphics.rectangle("fill", 0, 0, virtualWidth, virtualHeight)
    love.graphics.setColor(0.91, 0.87, 0.82, 1)
    love.graphics.rectangle("fill", 0, keyboardTop, virtualWidth, virtualHeight - keyboardTop)

    drawRoundedPanel(toggleRect.x, toggleRect.y, toggleRect.width, toggleRect.height, 8, {0.95, 0.53, 0.50, 0.96}, {0.46, 0.16, 0.14, 0.34})
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("대화 기록", toggleRect.x, toggleRect.y + 8, toggleRect.width, "center")

    drawRoundedPanel(closeRect.x, closeRect.y, closeRect.width, closeRect.height, 8, {0.28, 0.22, 0.20, 0.16}, {0.30, 0.20, 0.16, 0.30})
    love.graphics.setColor(0.18, 0.12, 0.09, 1)
    love.graphics.printf("X", closeRect.x, closeRect.y + 8, closeRect.width, "center")

    local reply = getLatestCharacterReply()
    local font = love.graphics.getFont()
    local characterHeight = 174
    local characterBottom = inputRect.y - 16
    local characterTop = characterBottom - characterHeight
    local bubbleTailHeight = 14
    local bubbleBottom = characterTop - bubbleTailHeight - 6
    local maxBubbleWidth = virtualWidth - 56
    local bubbleWidth = clamp(font:getWidth(reply) + 28, 120, maxBubbleWidth)
    local bubbleTextWidth = bubbleWidth - 28
    local _, wrappedLines = font:getWrap(reply, bubbleTextWidth)
    local maxBubbleHeight = math.max(48, bubbleBottom - 62)
    local bubbleHeight = clamp(#wrappedLines * font:getHeight() + 24, 48, maxBubbleHeight)
    local bubbleX = (virtualWidth - bubbleWidth) * 0.5
    local bubbleY = bubbleBottom - bubbleHeight

    drawRoundedPanel(bubbleX, bubbleY, bubbleWidth, bubbleHeight, 14, {1, 1, 1, 0.98}, {0.42, 0.29, 0.22, 0.32})
    love.graphics.setColor(1, 1, 1, 0.98)
    love.graphics.polygon("fill", virtualWidth * 0.5 - 12, bubbleBottom - 1, virtualWidth * 0.5 + 12, bubbleBottom - 1, virtualWidth * 0.5, bubbleBottom + bubbleTailHeight)

    local oldScissorX, oldScissorY, oldScissorWidth, oldScissorHeight = love.graphics.getScissor()
    love.graphics.setScissor(
        screen.offsetX + (bubbleX + 14) * screen.scale,
        screen.offsetY + (bubbleY + 12) * screen.scale,
        bubbleTextWidth * screen.scale,
        (bubbleHeight - 24) * screen.scale
    )
    love.graphics.setColor(0.16, 0.12, 0.10, 1)
    love.graphics.printf(reply, bubbleX + 14, bubbleY + 12, bubbleTextWidth, "left")
    if oldScissorX then
        love.graphics.setScissor(oldScissorX, oldScissorY, oldScissorWidth, oldScissorHeight)
    else
        love.graphics.setScissor()
    end

    drawChatCharacterAt(virtualWidth * 0.5, characterBottom, characterHeight)

    drawRoundedPanel(inputRect.x, inputRect.y, inputRect.width, inputRect.height, 8, {1, 1, 1, 0.96}, {0.35, 0.22, 0.14, 0.45})
    love.graphics.setColor(0.16, 0.12, 0.10, 1)
    local visibleInput = chat.input .. chat.composition
    local inputText = visibleInput ~= "" and visibleInput or "메시지를 입력하세요..."
    inputText = getSingleLineTextTail(inputText, inputRect.width - 20)
    love.graphics.print(inputText, inputRect.x + 10, inputRect.y + 12)

    local sendColor = chat.isSending and {0.55, 0.52, 0.50, 0.75} or {0.95, 0.53, 0.50, 0.96}
    drawRoundedPanel(sendRect.x, sendRect.y, sendRect.width, sendRect.height, 8, sendColor, {0.46, 0.16, 0.14, 0.34})
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("전송", sendRect.x, sendRect.y + 12, sendRect.width, "center")
end

local function drawChatWindow()
    if not ui.isChatOpen then
        return
    end

    if currentOrientation == "portrait" and not chat.portraitShowHistory then
        drawPortraitCharacterChat()
    else
        drawStandardChatWindow()
    end
end

local function drawFurnitureEditControls()
    local item = furnitureEdit.selectedItem

    if not item then
        return
    end

    local bounds = getFurnitureVisualBounds(item)
    local deleteRect = getFurnitureDeleteButtonRect(item)
    local sizeRects = getFurnitureSizeButtonRects(item)
    local flipRect = item.id == "stairs" and getFurnitureFlipButtonRect(item) or nil

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

    if flipRect then
        drawRoundedPanel(flipRect.x, flipRect.y, flipRect.width, flipRect.height, 6, {0.95, 0.53, 0.50, 0.96}, {1, 1, 1, 0.50})
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf("Flip", flipRect.x, flipRect.y + flipRect.height * 0.16, flipRect.width, "center")
    end

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

        local useChromaKey = item.id == "window" and chromaKeyShaderReady
        if useChromaKey then
            love.graphics.setShader(chromaKeyShader)
        end

        drawImageContained(item.image, itemX + 8, itemY + 8, layout.width - 16, layout.height - 40)

        if useChromaKey then
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

local function drawRefrigeratorOpenPrompt()
    if ui.isRefrigeratorOpen or ui.isInteriorOpen or ui.isChatOpen then
        return
    end

    local refrigerator = getNearbyRefrigerator()
    if not refrigerator then
        return
    end

    local rect = getRefrigeratorOpenButtonRect(refrigerator)
    drawRoundedPanel(rect.x, rect.y, rect.width, rect.height, 8, {0.91, 0.96, 0.98, 0.97}, {0.28, 0.48, 0.56, 0.52})
    love.graphics.setColor(0.18, 0.31, 0.36, 1)
    love.graphics.printf("냉장고 열기", rect.x, rect.y + 8, rect.width, "center")
end

local function drawRefrigeratorWindow()
    if not ui.isRefrigeratorOpen then
        return
    end

    local rect = getRefrigeratorWindowRect()
    local closeRect = getRefrigeratorCloseRect()
    local gap = 8
    local horizontalPadding = 24
    local topY = rect.y + 66
    local availableWidth = rect.width - horizontalPadding * 2
    local availableHeight = rect.height - 88
    local cellSize = math.floor(math.min(
        (availableWidth - gap * (refrigeratorStorage.columns - 1)) / refrigeratorStorage.columns,
        (availableHeight - gap * (refrigeratorStorage.rows - 1)) / refrigeratorStorage.rows
    ))
    local gridWidth = cellSize * refrigeratorStorage.columns + gap * (refrigeratorStorage.columns - 1)
    local gridHeight = cellSize * refrigeratorStorage.rows + gap * (refrigeratorStorage.rows - 1)
    local gridX = rect.x + (rect.width - gridWidth) * 0.5
    local gridY = topY + math.max(0, (availableHeight - gridHeight) * 0.5)

    love.graphics.setColor(0, 0, 0, 0.48)
    love.graphics.rectangle("fill", 0, 0, virtualWidth, virtualHeight)
    drawRoundedPanel(rect.x, rect.y, rect.width, rect.height, 12, {0.94, 0.97, 0.98, 0.99}, {0.25, 0.42, 0.48, 0.60})

    love.graphics.setColor(0.16, 0.28, 0.33, 1)
    love.graphics.print("냉장고 보관함", rect.x + 22, rect.y + 20)
    love.graphics.setColor(0.34, 0.48, 0.53, 0.82)
    love.graphics.printf("20칸", rect.x + 22, rect.y + 39, rect.width - 86, "left")

    drawRoundedPanel(closeRect.x, closeRect.y, closeRect.width, closeRect.height, 7, {0.84, 0.91, 0.94, 0.96}, {0.25, 0.42, 0.48, 0.42})
    love.graphics.setColor(0.18, 0.30, 0.35, 1)
    love.graphics.printf("X", closeRect.x, closeRect.y + 6, closeRect.width, "center")

    for row = 1, refrigeratorStorage.rows do
        for column = 1, refrigeratorStorage.columns do
            local slotX = gridX + (column - 1) * (cellSize + gap)
            local slotY = gridY + (row - 1) * (cellSize + gap)
            drawRoundedPanel(slotX, slotY, cellSize, cellSize, 6, {0.78, 0.87, 0.90, 0.96}, {0.28, 0.43, 0.49, 0.58})
            love.graphics.setColor(1, 1, 1, 0.42)
            love.graphics.rectangle("line", slotX + 3, slotY + 3, cellSize - 6, cellSize - 6, 4, 4)
        end
    end
end

local function drawUiLayer()
    drawRefrigeratorOpenPrompt()
    drawMenuButton()
    drawDropdownMenu()
    drawInteriorWindow()
    drawChatWindow()
    drawRefrigeratorWindow()
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
