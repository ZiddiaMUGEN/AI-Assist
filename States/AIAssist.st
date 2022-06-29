[Statedef -2]

;; initial analysis, we run this every frame but it only ever does work once
[State -2, Execute Lua]
type = DisplayToClipboard
trigger1 = !IsHelper
text = "!lua Functions/Analyze.lua"
ignorehitpause = 1
persistent = 256

;; execute on the AI steps
[State -2, Execute Lua]
type = DisplayToClipboard
trigger1 = !IsHelper
text = "!lua Functions/Execute.lua"
ignorehitpause = 1
persistent = 256

[State -2]
type = LifeSet
trigger1 = !NumPartner
trigger1 = RoundState >= 2
value = 0
ignorehitpause = 1
persistent = 256

[State -2]
type = SelfState
trigger1 = !NumPartner
trigger1 = RoundState >= 2
value = 5150
ignorehitpause = 1
persistent = 256

[State -2, Invisible]
type = AssertSpecial
trigger1 = 1
flag = Invisible
flag2 = NoShadow
ignorehitpause = 1
persistent = 256

[State -2, NotHitBy]
type = NotHitBy
trigger1 = 1
value = SCA
ignorehitpause = 1
persistent = 256

[State -2, PlayerPush]
type = PlayerPush
trigger1 = 1
value = 0
ignorehitpause = 1
persistent = 256

[State -2, PosSet]
type = PosSet
trigger1 = NumPartner
x = partner,Pos x
y = partner,Pos y
ignorehitpause = 1
persistent = 256

[State -2, LifeSet]
type = LifeSet
trigger1 = NumPartner
value = partner,Life
kill = 1
ignorehitpause = 1
persistent = 256

;---------------------------------------------------------------------------
; Jump Fwd Start
[Statedef 40]
type    = S
physics = S
anim = 40
ctrl = 0
sprpriority = 1
facep2 = 1

[State 40, 4]
type = VelSet
trigger1 = AnimTime = 0
x = const(velocity.jump.fwd.x)
y = const(velocity.jump.y)

[State 40, 6]
type = SelfState
trigger1 = AnimTime = 0
value = 50
ctrl = 1

;---------------------------------------------------------------------------
; Jump Back Start
[Statedef 41]
type    = S
physics = S
anim = 40
ctrl = 0
sprpriority = 1
facep2 = 1

[State 40, 4]
type = VelSet
trigger1 = AnimTime = 0
x = const(velocity.jump.back.x)
y = const(velocity.jump.y)

[State 40, 6]
type = SelfState
trigger1 = AnimTime = 0
value = 50
ctrl = 1

;---------------------------------------------------------------------------
; Runjump Fwd Start
[Statedef 42]
type    = S
physics = S
anim = 40
ctrl = 0
sprpriority = 1
facep2 = 1

[State 40, 4]
type = VelSet
trigger1 = AnimTime = 0
x = const(velocity.runjump.fwd.x)
y = const(velocity.jump.y)

[State 40, 6]
type = SelfState
trigger1 = AnimTime = 0
value = 50
ctrl = 1