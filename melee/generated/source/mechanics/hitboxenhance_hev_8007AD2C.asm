lwz r0, 0(r31)
cmpwi r0, 0
beq Exit
stw r3, 0x0000001C(sp)
lwz r3, 0(r3)
lis r12, 0x801510ec @h
ori r12, r12, 0x801510ec @l
mtctr r12
bctrl
lwz r3, 0x0000001C(sp)
Exit:
lwz r0, 0(r31)