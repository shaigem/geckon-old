lwz r4, 0x00000008(r29)
cmpwi r28, 0x0000003C
bne OriginalExit
addi r4, r4, 8
stw r4, 0x00000008(r29)
lis r12, 0x80073588 @h
ori r12, r12, 0x80073588 @l
mtctr r12
bctr
OriginalExit: