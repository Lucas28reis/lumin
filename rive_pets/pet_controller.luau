-- =============================================================================
-- Lumin Pets — Pointer Tracking & Tail Wag Controller (Luau)
-- Drives the native Rive nodes (`HeadRig`, `EyesGazeRig`, `TailRig`) via the
-- `PetAvatar` ViewModel so all shapes remain 100% editable in the Rive Editor.
-- =============================================================================

type PointerTracker = {
    size: Vector,
    elapsed: number,
    x: number,
    y: number,
    targetX: number,
    targetY: number,
    headX: Property<number>?,
    headY: Property<number>?,
    headRot: Property<number>?,
    tailRot: Property<number>?,
    eyeX: Property<number>?,
    eyeY: Property<number>?,
}

function init(self: PointerTracker, context: Context): boolean
    local vm = context:viewModel()
    if vm == nil then
        return true
    end
    self.headX = vm:getNumber('headX')
    self.headY = vm:getNumber('headY')
    self.headRot = vm:getNumber('headRot')
    self.tailRot = vm:getNumber('tailRot')
    self.eyeX = vm:getNumber('eyeX')
    self.eyeY = vm:getNumber('eyeY')
    return true
end

function resize(self: PointerTracker, size: Vector)
    self.size = size
end

function pointerMove(self: PointerTracker, event: PointerEvent)
    self.targetX = event.position.x
    self.targetY = event.position.y
end

function advance(self: PointerTracker, seconds: number): boolean
    self.elapsed += seconds

    local k = 1 - math.exp(-10 * seconds)
    self.x += (self.targetX - self.x) * k
    self.y += (self.targetY - self.y) * k

    local w = if self.size.x > 0 then self.size.x else 500
    local h = if self.size.y > 0 then self.size.y else 500
    local nx = (self.x / w) * 2 - 1
    local ny = (self.y / h) * 2 - 1

    if self.headX ~= nil then
        self.headX.value = 250 + nx * 16
    end
    if self.headY ~= nil then
        self.headY.value = 175 + ny * 10
    end
    if self.headRot ~= nil then
        self.headRot.value = nx * 0.09
    end
    if self.eyeX ~= nil then
        self.eyeX.value = 368 + nx * 6
    end
    if self.eyeY ~= nil then
        self.eyeY.value = 134 + ny * 4
    end
    if self.tailRot ~= nil then
        self.tailRot.value = math.sin(self.elapsed * 6.0) * 0.25
    end

    return true
end

return function(context: Context): Layout<PointerTracker>
    return {
        size = Vector.xy(500, 500),
        elapsed = 0,
        x = 250,
        y = 220,
        targetX = 250,
        targetY = 220,
        headX = nil,
        headY = nil,
        headRot = nil,
        tailRot = nil,
        eyeX = nil,
        eyeY = nil,
        init = init,
        resize = resize,
        advance = advance,
        pointerMove = pointerMove,
    }
end
