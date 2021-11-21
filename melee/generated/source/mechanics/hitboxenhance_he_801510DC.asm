cmpwi r4, 343
beq- OriginalExit
mflr r0
stw r0, 0x00000004(r1)
stwu r1, -(56 + 120)(r1)
stmw r20, 0x00000008(r1)
lwz r31, 0x0000002C(r3)
lwz r30, 0x0000002C(r4)
mr r29, r5
mr r27, r3
mr r26, r4
mr r3, r27
bl IsItemOrFighter
mr r25, r3
cmpwi r3, 1
beq SetupFighterVars
cmpwi r3, 2
bne Epilog
SetupItemVars:
li r5, 1492
li r6, 316
li r7, 4044
b CalculateExtHitOffset
SetupFighterVars:
li r5, 2324
li r6, 312
li r7, 9196
CalculateExtHitOffset:
mr r3, r31
mr r4, r29
lis r12, 0x801510d8 @h
ori r12, r12, 0x801510d8 @l
mtctr r12
bctrl
cmpwi r3, 0
beq Epilog
mr r28, r3
StoreHitlag:
lfs f0, 0(r28)
mr r3, r25
bl CalculateHitlagMultiOffset
add r4, r31, r3
mr r3, r26
bl IsItemOrFighter
mr r24, r3
bl CalculateHitlagMultiOffset
add r5, r30, r3
Hitlag:
lwz r0, 0x00000030(r29)
cmplwi r0, 2
bne+ NotElectric
lwz r3, 0xFFFFAEB4(r13)
lfs f1, 0x000001A4(r3)
fmuls f1, f1, f0
stfs f1, 0(r5)
b UpdateHitlagForAttacker
NotElectric:
stfs f0, 0(r5)
UpdateHitlagForAttacker:
stfs f0, 0(r4)
cmpwi r24, 1
bne Epilog
StoreHitstunModifier:
lfs f0, 12(r28)
stfs f0, 9296(r30)
StoreSDIMultiplier:
lfs f0, 4(r28)
stfs f0, 9292(r30)
CalculateFlippyDirection:
lwz r0, 20(r28)
cmpwi r0, 0
beq Epilog
lfs f0, 0x0000002C(r31)
cmpwi r0, 2
bne StoreCalculatedDirection
FlippyForward:
fneg f0, f0
StoreCalculatedDirection:
stfs f0, 0x00001844(r30)
Epilog:
lmw r20, 0x00000008(r1)
lwz r0, (56 + 0x00000004 + 120)(r1)
addi r1, r1, 56 + 120
mtlr r0
blr
CalculateHitlagMultiOffset:
cmpwi r3, 1
beq Return1960
cmpwi r3, 2
bne Exit
li r3, 4140
b Exit
Return1960:
li r3, 0x00001960
Exit:
blr
IsItemOrFighter:
lhz r0, 0(r3)
cmpwi r0, 0x00000004
li r3, 1
beq Result
li r3, 2
cmpwi r0, 0x00000006
beq Result
li r3, 0
Result:
blr
OriginalExit:
lwz r5, 0x0000010C(r31)