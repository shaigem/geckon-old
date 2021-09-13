import geckon

defineCodes:
    createCode "Mh/Ch Airplane & Punch Follow Vertical":
        authors "Ronnie"
        description "Airplane and Punch attacks follow the player vertically too"

        patchWrite32Bits "80153970": # mh airplane fly
            lfs f0, 0x14(r1) # set our y pos to target player's y
        
        patchWrite32Bits "8015a090": # ch airplane fly
            lfs f0, 0x14(r1) # set our y pos to target player's y

        patchWrite32Bits "80153C14": # mh bg punch fly in
            lfs f0, 0x14(r1) # set our y pos to target player's y

        patchWrite32Bits "8015998C": # ch bg punch fly in
            lfs f0, 0x14(r1) # set our y pos to target player's y

        patchInsertAsm "80153D14": # mh bg punch fly in reset x and y velocities
            stfs f0, 0x80(r4) # original code line, resets only x velocity
            stfs f0, 0x84(r4) # reset our y velocity
            # load char attributes into r3
            lwz r3, 0x10c(r4)
            lwz r3, 4(r3)
            lfs f0, 0x68(r3) # load y pos for fly in punch
            stfs f0, 0xB4(r4) # set y pos

        patchInsertAsm "80159A8C": # ch bg punch fly in reset x and y velocities
            stfs f0, 0x80(r4) # original code line, resets only x velocity
            stfs f0, 0x84(r4) # reset our y velocity
            # load char attributes into r3
            lwz r3, 0x10c(r4)
            lwz r3, 4(r3)
            lfs f0, 0xec(r3) # load y pos for fly in punch
            stfs f0, 0xB4(r4) # set y pos

        patchInsertAsm "8015bff8":
            
            lwz r3, 0x10(r31) # check if is bg slap down move (mh)
            cmpwi r3, 371
            beq Exit
            cmpwi r3, 373 # bg slap down move (ch)
            beq Exit

            Start:
                lfs f2, 0x0018(sp) # load target current y pos
                lfs f1, 0x00B4(r31) # load hand current pos y
                lfs f0, -0x57E8(rtoc)
                fsubs f1,f2,f1
                fcmpo cr0,f1,f0
                %`bge-` B8
                fneg f0,f1
                b BC
                B8:
                    fmr f0, f1
                    BC:
                        fcmpo cr0,f0,f31
                        %`ble-` EC
                lfs f0, -0x57E8 (rtoc)
                fcmpo cr0,f1,f0
                %`ble-` D8
                fmr f1, f31
                b DC
                D8:
                    fneg f1,f31
                    DC:
                        lfs f0, 0x0084 (r31)
                        fadds f0,f0,f1
                        stfs f0, 0x0084 (r31)
                        b Exit
                EC:
                    lfs f0, 0x0084(r31)
                    fadds f0,f0,f1
                    stfs f0, 0x0084(r31)
                Exit:
                    lwz r0, 0x0034(sp) # original code line
