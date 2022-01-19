import geckon
#[- code: 0xF1
  name: Hitbox Extension
  parameters:
  - name: Hitbox ID
    bitCount: 3
  - name: Apply to Hitbox IDs 0-3
    bitCount: 1
    enums:
    - false
    - true
  - name: Hitlag Multiplier %
    bitCount: 12
  - name: SDI Multiplier %
    bitCount: 12
  - name: Shieldstun Multiplier %
    bitCount: 12
  - name: Hitstun Modifier
    bitCount: 8
    signed: true
  - name: Set Weight
    bitCount: 1
    enums:
      - false
      - true
  - name: Angle Flipper
    bitCount: 2
    enums:
      - Regular
      - Current Facing Direction
      - Opposite Current Facing Direction
  - name: Stretch
    bitCount: 1
    enums:
      - false
      - true
  - name: Flinchless
    bitCount: 1
    enums:
      - false
      - true
  - name: Disable Meteor Cancel
    bitCount: 1
    enums:
      - false
      - true
  - name: Padding
    bitCount: 2]#

type GameDataType* = enum
        Vanilla, A20XX, Mex

type
    GameData = object
        dataType: GameDataType
        fighterDataSize: int
        itemDataSize: int

const
    FighterDataOrigSize = 0x23EC
    ItemDataOrigSize = 0xFCC

const 
    VanillaGameData = GameData(dataType: GameDataType.Vanilla,
    fighterDataSize: FighterDataOrigSize,
    itemDataSize: ItemDataOrigSize)
    
    A20XXGameData = GameData(dataType: GameDataType.A20XX,
    fighterDataSize: FighterDataOrigSize,
    itemDataSize: ItemDataOrigSize)

    # as of commit #f779005 Nov-29-2021 @ 1:28 AM EST
    MexGameData = GameData(dataType: GameDataType.Mex,
    fighterDataSize: FighterDataOrigSize + 52,
    itemDataSize: ItemDataOrigSize + 0x4)

# The current game data to compile the code for
const CurrentGameData = MexGameData

const
    CodeVersion = "v1.6.3"
    CodeName = "Hitbox Extension " & CodeVersion &  " (" & $CurrentGameData.dataType & ")"
    CodeAuthors = ["sushie"]
    CodeDescription = "Allows you to modify hitlag, SDI, hitstun and more!"
    ExtFighterDataOffset = CurrentGameData.fighterDataSize
    ExtItemDataOffset = CurrentGameData.itemDataSize

proc patchItemDataAllocation(extraDataSize: int): seq[CodeSectionNode] =
    let newDataSize = CurrentGameData.itemDataSize + extraDataSize
    let
        SizeAdjust =
                patchWrite32Bits "80266fd8":
                    li r4, {newDataSize}

        # Initialize Extended Item Data
        InitItemData = 
            patchInsertAsm "80268754":
                addi r29, r3, 0 # backup r3

                li r4, {newDataSize} # was 4044
                %branchLink("0x8000c160")

                Exit:
                    mr r3, r29 # restore r3
                    %`mr.`(r6, r3)

    case CurrentGameData.dataType
    of Vanilla:
        discard
    of A20XX:
        discard
    of Mex:
        discard
    # for all game types
    result.add SizeAdjust
    result.add InitItemData

proc patchFighterDataAllocation(extraDataSize: int): seq[CodeSectionNode] =
    let 
        InitPlayerBlockValues = 
            patchInsertAsm "80068eec":
        # credits to https://github.com/UnclePunch/Training-Mode/blob/master/ASM/m-ex/Custom%20Playerdata%20Variables/Initialize%20Extended%20Playerblock%20Values.asm

            block:
                if CurrentGameData.dataType == A20XX:
                    ppc:
                        li r4, 0
                        stw r4, 0x20(r31)
                        stw r4, 0x24(r31)
                        stb r4, 0x0D(r3)
                        sth r4, 0x0E(r3)
                        stb r4, 0x21FD(r3)
                        sth r4, 0x21FE(r3)
                else:
                    ppc:
                        %emptyBlock

            # Backup Data Pointer After Creation
            addi r30, r3, 0

            # Get Player Data Length
            %load("0x80458fd0", r4)
            lwz r4, 0x20(r4)
            # Zero Entire Data Block
            %branchLink("0x8000c160")

            Exit:
                mr r3, r30
                lis r4, 0x8046

        SizeAdjust = 
            patchWrite32Bits "800679bc":
                li r4, {CurrentGameData.fighterDataSize + extraDataSize}

        # # Initialize Extended Playerblock Values (Result screen)
        # patchInsertAsm "800BE830":
        #     # Backup Data Pointer After Creation
        #     addi r30, r3, 0

        #     # Get Player Data Length
        #     %load("0x80458fd0", r4)
        #     lwz r4,0x20(r4)
        #     # Zero Entire Data Block
        #     %branchLink("0x8000c160")

        #     Exit:
        #         mr r3, r30
        #         lis r4, 0x8046

    case CurrentGameData.dataType
    of Vanilla:
        discard
    of A20XX:
        # Fix 20XX Crash when Allocating New PlayerBlock Size
        let SwingFileColorsFix = 
            patchWrite32Bits "8013651c":
                blr # this breaks 'Marth and Roy Sword Swing File Colors'!!!

        result.add SwingFileColorsFix

    of Mex:
        discard

    # for all game types
    result.add SizeAdjust
    result.add InitPlayerBlockValues

# Variable offsets in our new ExtHit struct
const
    ExtHitHitlagOffset = 0x0 # float
    ExtHitSDIMultiplierOffset = ExtHitHitlagOffset + 0x4 # float
    ExtHitShieldstunMultiplierOffset = ExtHitSDIMultiplierOffset + 0x4 # float
    ExtHitHitstunModifierOffset = ExtHitShieldstunMultiplierOffset + 0x4 # float
    ExtHitFlags1Offset = ExtHitHitstunModifierOffset + 0x4 # char

    ExtHitFlags1SetWeight = 0x80
    ExtHitFlags1AngleFlipOpposite= 0x40
    ExtHitFlags1AngleFlipCurrent= 0x20
    ExtHitFlags1Stretch = 0x10
    ExtHitFlags1Flinchless = 0x8
    ExtHitFlags1DisableMeteorCancel = 0x4


# Size of new hitbox data = last var offset + last var offset.size
const ExtHitSize = ExtHitFlags1Offset + 0x4

# New variable pointer offsets for both ITEMS & FIGHTERS
const
    ExtHit0Offset = 0x0
    ExtHit1Offset = ExtHit0Offset + ExtHitSize
    ExtHit2Offset = ExtHit1Offset + ExtHitSize
    ExtHit3Offset = ExtHit2Offset + ExtHitSize

# New variable pointer offsets for FIGHTERS only
const
    SDIMultiplierOffset = ExtHit3Offset + ExtHitSize # float
    HitstunModifierOffset = SDIMultiplierOffset + 0x4 # float
    ShieldstunMultiplierOffset = HitstunModifierOffset + 0x4 # float

    Flags1Offset = ShieldstunMultiplierOffset + 0x4 # byte
    FlinchlessFlag = 0x1
    TempGravityFallSpeedFlag = 0x2
    DisableMeteorCancelFlag = 0x4
# New variable pointer offsets for ITEMS only
const
    ExtItHitlagMultiplierOffset = ExtHit3Offset + ExtHitSize # float

const 
    ExtFighterDataSize = (Flags1Offset + 0x4)
    ExtItemDataSize = (ExtItHitlagMultiplierOffset + 0x4)

const
    CustomFunctionReadEvent = "0x801510e0"
    CustomFunctionInitDefaultEventVars = "0x801510e4"
    CustomFuncResetGravityAndFallSpeed = "0x801510e8"

proc calcOffsetFighterExtData(varOff: int): int = ExtFighterDataOffset + varOff
proc calcOffsetItemExtData(varOff: int): int = ExtItemDataOffset + varOff

defineCodes:
    createCode CodeName:
        description CodeDescription
        authors CodeAuthors

        # Patch Disable Meteor Cancel
        patchInsertAsm "8007ac68":
            # r31 = fighter data
            lbz r0, {calcOffsetFighterExtData(Flags1Offset)}(r31)
            %`rlwinm.`(r0, r0, 0, DisableMeteorCancelFlag)
            beq NormalCheck
            li r3, 0 # cannot meteor cancel
            blr
            NormalCheck:
                cmplwi r3, 361 # original code line

        # Damage_BranchToDamageHandler - Patch Custom Windbox Function
        patchInsertAsm "8008edb0":
            # r31 = ft/it gobj
            # r29 = ft/it data

            lbz r3, {calcOffsetFighterExtData(Flags1Offset)}(r29)
            %`rlwinm.`(r3, r3, 0, FlinchlessFlag)
            beq UnhandledExit

            lbz r0, 0x2222(r29)
            %`rlwinm.`(r0, r0, 27, 31, 31) # 0x20 grab?
            beq lbl_800C355C
            b HandledExit

            lbl_800C355C:
                lbz r0, 0x2071(r29) # ???
                rlwinm r0, r0, 28, 28, 31
                cmpwi r0, 12
                bge HandleWindbox
                cmpwi r0, 10 # grab?
                beq HandleWindbox 
                cmpwi r0, 9 # hanging off ledge??
                bge HandledExit
                b HandleWindbox

            HandleWindbox:
                mr r3, r31
                bl Damage_Windbox

            HandledExit:
                # branches to the end of the Damage_BranchToDamageHandler, meaning that we handled the damage
                %branch("0x8008f71c")

            Damage_Windbox:
                mflr r0
                stw r0, 0x0004 (sp)
                lis r0, 0x4330
                stwu sp, -0x0040 (sp)
                stfd f31, 0x0038 (sp)
                stfd f30, 0x0030 (sp)
                stfd f29, 0x0028 (sp)
                stw r31, 0x0024 (sp)
                lwz r5, 0x002C (r3)
                mr r31, r5
#                BranchToUnk:
#                    %branchLink("0x8006D044") # Hitlag related functions for grab victims and EnterHitlag callbacks?
                lbl_800C3634:
                    lwz r3, -0x514C(r13)
                    lfs f0, 0x100(r3) # 0.03
                    lfs f1, 0x1850(r31) # forced applied
                    fmuls f31, f1, f0 # forced applied * 0.03
                    CheckAttackAngle:
                        mr r3, r31
                        lfs f1, 0x1850(r31) # forced applied
                        %branchLink("0x8008D7F0") # CheckAttackAngle
                fmr f30, f1 # save AttackRadians into f30
                %branchLink("0x80326240") # cos
                fmuls f29, f31, f1 # f29 = (forced Applied * 0.03) * result of cos
                fmr f1, f30 # put AttackRadians back into f1
                %branchLink("0x803263D4") # sin
                lwz r0, 0x00E0 (r31) # check air state
                fmuls f2,f31,f1 # (force_applied * 0.03) * result of sin
                cmpwi r0, 1 # if in the air
                bne StoreVelocityGrounded
                lfs f0, 0x1844(r31) # dmg_direction
                mr r3, r31
                fneg f1, f29 # -((forced Applied * 0.03) * result of cos)
                fmuls f1, f1, f0 # -((forced Applied * 0.03) * result of cos) * direction
                %branchLink("0x8008DC0C") # StoreVelocity/CheckForKBStack
                lfs f0, -0x6D08(rtoc)
                stfs f0, 0x00F0(r31)
                b StoreSlotLastDamaged
                StoreVelocityGrounded:
                    # called when hit on the GROUND
                    fneg f1, f29 # -((forced Applied * 0.03) * result of cos)
                    lfs f0, 0x1844(r31) # dmg_direction
                    fmuls f0, f1, f0
                    fmr f1, f0
                    stfs f1, 0xF0(r31)
                    mr r3, r31
                    lfs f0, 0x0844(r31) # -0?
                    fneg f0,f0
                    fmuls f2, f0, f1
                    %branchLink("0x8008DC0C") # StoreVelocity/CheckForKBStack
                StoreSlotLastDamaged:
                    li r3, 0
                    stw r3, 0x18AC(r31) # store time_last_hit = 0
#                    mr r3, r31
#                    %branchLink("0x800804FC") # SlotLastDamaged Make Self If On Ground
                    lwz r0, 0x0044 (sp)
                    lfd f31, 0x0038 (sp)
                    lfd f30, 0x0030 (sp)
                    lfd f29, 0x0028 (sp)
                    lwz r31, 0x0024 (sp)
                    addi sp, sp, 64
                    mtlr r0
                    blr

            UnhandledExit:
                mr r3, r31

        #[Notes on hitlag on invincibility
            80077438 - this is where it spawns the gfx when you hit an invincible opponent
            - good spot for adding hitlag multipliers if I decided to do it for invincible hits ]#

        patchInsertAsm "801510d4":

            cmpwi r4, 343
            %`beq-`(OriginalExit)
            
            # inputs
            # r3 = attacker gobj
            # r4 = attacker hit ft/it hit struct ptr
            # returns
            # r3 = ptr to ExtHit of attacker
            cmplwi r3, 0
            beq Invalid
            cmplwi r4, 0
            beq Invalid

            li r0, 4 # set loop 4 times
            mtctr r0

            # check attacker type
            lhz r0, 0(r3)
            lwz r3, 0x2C(r3) # fighter data
            cmplwi r0, 4 # fighter type
            beq GetExtHitForFighter
            cmplwi r0, 6 # item type
            beq GetExtHitForItem
            b Invalid

            GetExtHitForItem:
                addi r5, r3, 1492 # attacker data ptr + hit struct offset
                addi r3, r3, {ExtItemDataOffset} # attacker data ptr + Exthit struct offset
                li r0, 316
            b GetExtHit

            GetExtHitForFighter:
                addi r5, r3, 2324 # attacker data ptr + hit struct offset
                addi r3, r3, {ExtFighterDataOffset} # attacker data ptr + Exthit struct offset
                li r0, 312

            GetExtHit:
                # uses
                # r3 = points to ExtHit struct offset
                # r4 = target hit struct ptr
                # r5 = temp var holding our current hit struct ptr
                # r0 = sizeof hit struct ptr
                b Comparison
                Loop:
                    add r5, r5, r0 # point to next hit struct
                    addi r3, r3, {ExtHitSize} # point to next ExtHit struct
                    Comparison:
                        cmplw r5, r4 # hit struct ptr != given hit struct ptr
                        bdnzf eq, Loop

            beq Exit
        
            Invalid:
                li r3, 0

            Exit:
                blr

            OriginalExit:
                lwz r31, 0x002C(r3)
        
        # Standalone function for handling stretched hitboxes for both fighters & items
        patchInsertAsm "801510ec":
            cmpwi r4, 343
            %`beq-`(OriginalExit)

            # inputs
            # r3 = ft/it gobj
            # r4 = ft/it hit struct

            %backup

            mr r31, r4 # hit struct
            mr r30, r3 # gobj

            # get ext hit struct
            %branchLink("0x801510d4") # getExtHit
            cmplwi r3, 0
            beq Exit
            # check stretch property
            lbz r3, {ExtHitFlags1Offset}(r3) # get flags
            %`rlwinm.`(r3, r3, 0, 27, 27) # check if Stretch property is set to true (0x10)
            beq Exit

            lhz r0, 0(r30)
            cmpwi r0,0x4
            beq SetForFighter
            cmpwi r0,0x6
            bne GetInitialPos

            # setup for item
            mr r3, r30
            %branchLink("0x80275788")
            b GetInitialPos

            SetForFighter:
                li r0, 2 # TODO should this be 4?
                stw r0, 0(r31)
        
            GetInitialPos:
                # first, get initial position with offset of 0
                lwz r3, 0x48(r31) # bone jobj
                li r4, 0 # offset ptr
                addi r5, sp, {BackupFreeSpaceOffset} # result
                %branchLink("0x8000B1CC") # JObj_GetWorldPos
            # next, get position WITH offset
            lwz r3, 0x10(r31)
            lwz r4, 0x14(r31)
            stw r3, {BackupFreeSpaceOffset + 0xC}(sp)
            stw r4, {BackupFreeSpaceOffset + 0xC + 0x4}(sp)
            lwz r4, 0x18(r31)
            stw r4, {BackupFreeSpaceOffset + 0xC + 0x8}(sp)
            lwz r3, 0x48(r31) # bone jobj
            addi r4, sp, {BackupFreeSpaceOffset + 0xC} # offset ptr
            addi r5, sp, {BackupFreeSpaceOffset + 0xC}
            %branchLink("0x8000B1CC") # JObj_GetWorldPos

            # now finally call the interop func
            addi r4, sp, {BackupFreeSpaceOffset}
            addi r5, sp, {BackupFreeSpaceOffset + 0xC}
            mr r6, r31
            %branchLink("0x80275830")

            Exit:
                %restore
                blr

            OriginalExit:
                li r5, 0
            
        # Hitbox_UpdateHitboxPositions Stretch Patch 0x802f05a8
        patchInsertAsm "8007ad2c":
            # r3 = ft data
            # r4 = ft hit struct
            # r31 = ft hit struct
            lwz r0, 0(r31) # orig code line (changed from r4 to r31)
            cmpwi r0, 0 # hitbox to update is inactive, don't bother getting ExtHit
            beq Exit

            stw r3, 0x1C(sp) # backup ft/it data
            lwz r3, 0(r3) # gobj
            %branchLink("0x801510ec")
            lwz r3, 0x1C(sp) # restore ft/it data

            Exit:
                lwz r0, 0(r31)

        # Item_UpdateHitboxPositions Stretch Patch 0x802f05a8
        patchInsertAsm "802713a4":
            # r27 = itgobj
            # r30 = it data?
            # r29 = it hit struct
            lwz r0, 0(r29)
            cmpwi r0, 0 # hitbox to update is inactive, don't bother getting ExtHit
            beq Exit

            mr r3, r27 # gobj
            mr r4, r29 # ithit
            %branchLink("0x801510ec")

            Exit:
                lwz r0, 0(r29)

#[         # Item_UpdateHitboxPositions Begin Patch
        patchInsertAsm "802713a4":
            # store ExtHit onto 0xC(sp) for use later on in the function
            # r3 = it gobj
            # r27 = it gobj
            # r30 = item data
            # r29 = it hit struct
            lwz r0, 0(r29) # orig code line
            cmpwi r0, 0 # hitbox to update is inactive, don't bother getting ExtHit
            beq Exit

            mr r4, r3
            mr r5, r29
            %branchLink("0x801510d4") # getExtHit
            cmplwi r3, 0
            beq Exit
            stw r3, 0xC(sp) # store Ext Hit on stack
            Exit:
                lwz r0, 0(r29) # orig code line

        # Hitbox_UpdateHitboxPositions Initial Hitbox Position Patch for Stretch
        patchInsertAsm "8007adb0":
            # on create hitbox position
            # calculate initial hitbox position with offset of 0 if hitbox has the Stretch property
            lwz r3, 0x20(sp) # getExtHit
            cmplwi r3, 0
            beq Exit
            lbz r3, {ExtHitFlags1Offset}(r3) # get flags
            %`rlwinm.`(r3, r3, 0, 27, 27) # check if Stretch property is set to true (0x10)
            beq Exit 

            li r0, 0
            stw r0, 0x10(sp)
            stw r0, 0x14(sp)
            stw r0, 0x18(sp)

            Exit:
                lwz r3, 0x48(r31) # bone jobj

        # Item_UpdateHitboxPositions Initial Hitbox Position Patch for Stretch
        patchInsertAsm "802713d8":
            # on create hitbox position
            # calculate initial hitbox position with offset of 0 if hitbox has the Stretch property
            lwz r3, 0xC(sp) # getExtHit
            cmplwi r3, 0
            beq OriginalExit
            lbz r3, {ExtHitFlags1Offset}(r3) # get flags
            %`rlwinm.`(r3, r3, 0, 27, 27) # check if Stretch property is set to true (0x10)
            beq OriginalExit 

            li r0, 0
            stw r0, -0x4(sp)
            stw r0, -0x8(sp)
            stw r0, -0xC(sp)
            addi r4, sp, -0x4
            b Restore

            OriginalExit:
                addi r4, r29, 16
                Restore:
                    lwz r3, 0x48(r29) # bone jobj

        # Hitbox_UpdateHitboxPositions Moving Hitbox Position Patch for Stretch
        patchInsertAsm "8007ae5c":
            # on update hitbox position
            # calculate moving hitbox position with offset of 0 if hitbox has the Stretch property
            lwz r3, 0x20(sp) # getExtHit
            cmplwi r3, 0
            beq Exit
            lbz r3, {ExtHitFlags1Offset}(r3) # get flags
            %`rlwinm.`(r3, r3, 0, 27, 27) # check if Stretch property is set to true (0x10)
            beq Exit

            li r0, 0
            stw r0, 0x10(sp)
            stw r0, 0x14(sp)
            stw r0, 0x18(sp)
            Exit:
                lwz r3, 0x48(r31) # bone jobj

        # Item_UpdateHitboxPositions Moving Hitbox Position Patch for Stretch
        patchInsertAsm "80271440":
            # on update hitbox position
            # calculate moving hitbox position with offset of 0 if hitbox has the Stretch property
            lwz r3, 0x20(sp) # getExtHit
            cmplwi r3, 0
            beq Exit
            lbz r3, {ExtHitFlags1Offset}(r3) # get flags
            %`rlwinm.`(r3, r3, 0, 27, 27) # check if Stretch property is set to true (0x10)
            beq Exit

            li r0, 0
            stw r0, -0x4(sp)
            stw r0, -0x8(sp)
            stw r0, -0xC(sp)
            Exit:
                lwz r3, 0x48(r29) # bone jobj

        # Hitbox_UpdateHitboxPositions Update Last Hitbox Position
        patchInsertAsm "8007addc":
            # if Stretch property is true, set the previous hitbox position as the current pos + offset
            lwz r3, 0x20(sp) # getExtHit
            cmplwi r3, 0
            beq OriginalExit
            lbz r3, {ExtHitFlags1Offset}(r3) # get flags
            %`rlwinm.`(r3, r3, 0, 27, 27) # check if Stretch property is set to true (0x10)
            beq OriginalExit
            lwz r3, 0x10(r31)
            lwz r4, 0x14(r31)
            stw r3, 0x10(sp)
            stw r4, 0x14(sp)
            lwz r4, 0x18(r31)
            stw r4, 0x18(sp)
            lwz r3, 0x48(r31) # bone jobj
            addi r4, sp, 16 # offset ptr
            addi r5, r31, 0x58
            %branchLink("0x8000B1CC")
            %branch("0x8007ae6c")

            OriginalExit:
                stw r0, 0(r31)

        # Hitbox_UpdateHitboxPositions Update Last Hitbox Position
        patchInsertAsm "8007ae00":
            # if Stretch property is true, set the previous hitbox position as the current pos + offset
            lwz r4, 0x20(sp) # getExtHit
            cmplwi r4, 0
            beq OriginalExit
            lbz r4, {ExtHitFlags1Offset}(r4) # get flags
            %`rlwinm.`(r4, r4, 0, 27, 27) # check if Stretch property is set to true (0x10)
            beq OriginalExit
            mr r6, r3 # backup r3
            lwz r3, 0x10(r31)
            lwz r4, 0x14(r31)
            stw r3, 0x10(sp)
            stw r4, 0x14(sp)
            lwz r4, 0x18(r31)
            stw r4, 0x18(sp)
            lwz r3, 0x48(r31) # bone jobj
            addi r4, sp, 16 # offset ptr
            addi r5, r31, 0x58
            %branchLink("0x8000B1CC")
            mr r3, r6
            %branch("0x8007ae04")

            OriginalExit:
                stw r0, 0x60(r31) ]#
        
        # Function for Resetting Gravity and Fall Speed
        patchInsertAsm "801510e8":
            cmpwi r4, 343
            %`beq-`(OriginalExit)
            # inputs
            # r3 = fighter data

            stwu sp, -0x20(sp)
            stw r31, 0x1C(sp)
            # r31 = fighter data
            mr r31, r3
            # reset gravity and fall speed
            lwz r3, 0x10C(r3) # FtData
            lwz r3, 0(r3) # ptr to common attributes
            # reset gravity
            lfs f0, 0x5C(r3)
            stfs f0, 0x16C(r31)
            # reset fall speed
            lfs f0, 0x60(r3)
            stfs f0, 0x170(r31)

            # now restore other modifiers to gravity + fall speed

            # item-related modifiers like bunny hood
            lwz r0, 0x197C(r31)
            cmplwi r0, 0
            beq Idk1
            lwz r3, -0x5180(r13)
            
            lfs f1, 0x016C(r31)
            lfs f0, 0x0020(r3)
            fmuls f0, f1, f0
            stfs f0, 0x016C(r31)

            lfs f1, 0x0170(r31)
            lfs f0, 0x0024(r3)
            fmuls f0, f1, f0
            stfs f0, 0x0170(r31)

            Idk1:
                lbz r0, 0x2223(r31)
                %`rlwinm.`(r0, r0, 0, 31, 31) # 0x1
                beq Idk2
                lwz r3, -0x5184(r13)

                lfs f1, 0x016C(r31)
                lfs f0, 0xC(r3)
                fmuls f0, f1, f0
                stfs f0, 0x016C(r31)

                lfs f1, 0x0170(r31)
                lfs f0, 0x10(r3)
                fmuls f0, f1, f0
                stfs f0, 0x0170(r31)

            Idk2:
                lbz r0, 0x2229(r31)
                %`rlwinm.`(r0, r0, 26, 31, 31) # 0x40
                beq Epilog
                lwz r3, -0x5188(r13)

                lfs f1, 0x016C(r31)
                lfs f0, 0(r3)
                fmuls f0, f1, f0
                stfs f0, 0x016C(r31)

            Epilog:
                lwz r31, 0x1C(sp)
                addi sp, sp, 0x20
                blr

            OriginalExit:
                lwz r30, 0x4(r5)

        # Player_ReapplyAttributes Reset Variables
        patchInsertAsm "800d108c":
            # r30 = fighter data
            li r3, 0
            lbz r0, {calcOffsetFighterExtData(Flags1Offset)}(r30)
            rlwimi r0, r3, 1, {TempGravityFallSpeedFlag}
            stb r0, {calcOffsetFighterExtData(Flags1Offset)}(r30)
            lwz r3, 0x10C(r30) # original code line

        # Reset Temp Gravity & Fall Speed At 10 Frames After Launch
        patchInsertAsm "8006ab10":
            # r31 = fighter data
            lwz r3, 0x18AC(r31) # time_since_hit in frames
            cmpwi r3, 10
            blt Exit

            lbz r0, {calcOffsetFighterExtData(Flags1Offset)}(r31)
            %`rlwinm.`(r0, r0, 0, TempGravityFallSpeedFlag)
            beq Exit

            mr r3, r31
            %branchLink(CustomFuncResetGravityAndFallSpeed)
            # reset flag to 0
            li r3, 0
            lbz r0, {calcOffsetFighterExtData(Flags1Offset)}(r31)
            rlwimi r0, r3, 1, {TempGravityFallSpeedFlag}
            stb r0, {calcOffsetFighterExtData(Flags1Offset)}(r31)
            lwz r3, 0x18AC(r31)
            Exit:
                %emptyBlock

        # CalculateKnockback Patch Use Weight of 100 for Knockback Calculation (ExtHit Flag)
        patchInsertAsm "8007a14c":
            # r25 = defender data
            # r17 = hit struct?
            # r15 = attacker data
            # r27 = current char attr
            lwz r3, 0(r15)
            mr r4, r17 # hit struct
            %branchLink("0x801510d4")
            %`mr.`(r18, r3) # save ExtHit in r18 for other patches to use. NOTE: 8007a784 r18 gets replaced!
            lfs f4, 0x88(r27) # weight of defender
            beq Exit
            # r3 contains ExtHit offset

            lbz r4, {ExtHitFlags1Offset}(r3)
            %`rlwinm.`(r4, r4, 0, ExtHitFlags1SetWeight) # check 0x80
            beq Exit

            UseSetWeight:
                # if the 'Set Weight' flag is set, use a weight of 100 for the defender
                lwz r3, -0x514C(r13)
                lfs f4, 0x10C(r3) # uses same weight value from throws (100)

            Exit:
                %emptyBlock

        # CalculateKnockback Patch Set Weight to 100 for Knockback Calculation (ExtHit Flag)
        # Called when defender is attacked by an item
        patchInsertAsm "8007a270":
            # r25 = def data, is fighter
            # r15 = fighter attacker gobj
            lwz r3, 0x8(r19) # get item gobj attacker
            lwz r4, 0xC(r19) # get last hit
            %branchLink("0x801510d4")
            %`mr.`(r18, r3) # save ExtHit in r18 for other patches to use. NOTE: 8007a784 r18 gets replaced!
            lfs f22, 0x88(r27) # weight of defender
            beq Exit
            # r3 contains ExtHit offset

            lbz r4, {ExtHitFlags1Offset}(r3)
            %`rlwinm.`(r4, r4, 0, ExtHitFlags1SetWeight) # check 0x80
            beq Exit

            UseSetWeight:
                # if the 'Set Weight' flag is set, use a weight of 100 for the defender
                lwz r3, -0x514C(r13)
                lfs f22, 0x10C(r3) # uses same weight value from throws (100)

            Exit:
                %emptyBlock

        # CalculateKnockback Patch for Skipping On Hit GFX for Windboxes
        # Called when defender is attacked by another fighter
        patchInsertAsm "8007a1e4":
            cmplwi r18, 0
            beq Exit

            lbz r0, {ExtHitFlags1Offset}(r18)
            %`rlwinm.`(r0, r0, 0, ExtHitFlags1Flinchless)
            beq Exit

            %branch("0x8007a6a8") # skip gfx on hit
            Exit:
                stw r3, 0x22C(sp) # orig code line

        # CalculateKnockback Patch for Skipping On Hit GFX for Windboxes
        # Called when defender is attacked by an item
        patchInsertAsm "8007a498":
            cmplwi r18, 0
            beq Exit

            lbz r0, {ExtHitFlags1Offset}(r18)
            %`rlwinm.`(r0, r0, 0, ExtHitFlags1Flinchless)
            beq Exit

            %branch("0x8007a6a8") # skip gfx on hit
            Exit:
                stw r3, 0x214(sp) # orig code line

        # patchInsertAsm "801510d8":
        #     cmpwi r4, 343
        #     %`beq-`(OriginalExit)

        #     Exit:
        #         blr

        #     OriginalExit:
        #         lfs f1, -0x5B40(rtoc)

        # ASDI multiplier mechanics patch
        patchInsertAsm "8008e7a4":
            # ASDI distance is increased or decreased based on multiplier
            # r31 = fighter data
            # f2 = 3.0 multiplier
            # f0 = free to use
            lfs f0, {calcOffsetFighterExtData(SDIMultiplierOffset)}(r31)
            fmuls f2, f2, f0 # 3.0 * our custom sdi multiplier
            lfs f0, 0x63C(r31) # original code line

        # ASDI multiplier mechanics patch 2
        patchInsertAsm "8008e7c0":
            # ASDI distance is increased or decreased based on multiplier
            # r31 = fighter data
            # f2 = 3.0 multiplier
            # f0 = free to use
            lfs f0, {calcOffsetFighterExtData(SDIMultiplierOffset)}(r31)
            fmuls f2, f2, f0 # 3.0 * our custom sdi multiplier
            lfs f0, 0x624(r31) # original code line

        # SDI multiplier mechanics patch
        patchInsertAsm "8008e558":
            # SDI distance is increased or decreased based on multiplier
            # r3 = fighter data
            # f4 = 6.0 multiplier
            lfs f0, {calcOffsetFighterExtData(SDIMultiplierOffset)}(r3)
            fmuls f4, f4, f0 # 6.0 * our custom sdi multiplier
            li r0, 254 # original code line

        # Hitstun mechanics patch
        patchInsertAsm "8008dd70":
            # Adds or removes frames of hitstun
            # 8008dd68: loads global hitstun multiplier of 0.4 from plco
            # f30 = calculated hitstun after multipling by 0.4
            # r29 = fighter data
            # f0 = free
            lfs f0, {calcOffsetFighterExtData(HitstunModifierOffset)}(r29) # load modifier
            fadds f30, f30, f0 # hitstun + modifier
            fctiwz f0, f30 # original code line

        # Shieldstun multiplier mechanics patch
        patchInsertAsm "8009304c":
            # note: yoshi's shield isn't affected... let's keep his shield unique
            # Shieldstun for defender is increased or decreased based on multiplier
            # f4 = 1.5
            # f0 is free here
            # r31 = fighter data
            lfs f0, {calcOffsetFighterExtData(ShieldstunMultiplierOffset)}(r31) # load modifier
            fmuls f4, f4, f0 # 1.5 * our multiplier
            fsubs f2, f2, f3 # orig code line

        # Custom Non-Standalone Function For Handling Setting the Appropriate Hitlag & Hitstun & SDI Multipliers
        patchInsertAsm "801510dc":
            cmpwi r4, 343
            %`beq-`(OriginalExit)

            # both items and fighters can experience hitlag
            # only defender fighter experience SDI & Hitstun mods

            # inputs
            # r3 = source gobj
            # r4 = defender gobj
            # r5 = source hit ft/it hit struct ptr
            %backup
            # backup regs
            # r31 = source data
            # r30 = defender data
            # r29 = r5 ft/it hit
            # r27 = r3 source gobj
            # r26 = r4 defender gobj

            lwz r31, 0x2C(r3)
            lwz r30, 0x2C(r4)
            mr r29, r5
            mr r27, r3
            mr r26, r4

            # calculate ExtHit offset for given ft/it hit ptr
            bl IsItemOrFighter
            mr r25, r3 # backup source type

            CalculateExtHitOffset:
                mr r3, r27
                mr r4, r29
                %branchLink("0x801510d4")
            # r3 now has offset
            cmplwi r3, 0
            beq Epilog

            mr r28, r3 # ExtHit off

            # r25 = source type
            # r24 = defender type
            # r28 = ExtHit offset

            StoreHitlag:
                lfs f0, {ExtHitHitlagOffset}(r28) # load hitlag mutliplier
                # calculate hitlag multiplier offsets depending if it's a item or fighter
                # for src
                mr r3, r25
                bl CalculateHitlagMultiOffset
                add r4, r31, r3

                # for def
                mr r3, r26
                bl IsItemOrFighter
                mr r24, r3 # backup def type
                bl CalculateHitlagMultiOffset
                add r5, r30, r3
               
                Hitlag:
                    # check if hit was electric
                    lwz r0, 0x30(r29) # dmg hit attribute
                    cmplwi r0, 2 # electric
                    %`bne+`(NotElectric)
                    # Electric
                    lwz r3, -0x514C(r13) # PlCo values
                    lfs f1, 0x1A4(r3) # 1.5 electric hitlag multiplier
                    fmuls f1, f1, f0 # 1.5 * multiplier
                    # store extra hitlag for DEFENDER ONLY in Melee
                    # TODO idk if i should check if src & defender data is valid before setting...
                    stfs f1, 0(r5) # store extra hitlag for defender
                    b UpdateHitlagForAttacker

                    NotElectric:
                            stfs f0, 0(r5) # store hitlag multi for defender

                            UpdateHitlagForAttacker:
                                stfs f0, 0(r4) # store hitlag multi for source
                                
            # now we store other variables for defenders who are fighters ONLY
            cmpwi r24, 1 # fighter
            bne Epilog # not fighter, skip this section      

            StoreHitstunModifier:
                lfs f0, {ExtHitHitstunModifierOffset}(r28)
                stfs f0, {calcOffsetFighterExtData(HitstunModifierOffset)}(r30)
                
            StoreSDIMultiplier:
                lfs f0, {ExtHitSDIMultiplierOffset}(r28)
                stfs f0, {calcOffsetFighterExtData(SDIMultiplierOffset)}(r30)
            
            CalculateFlippyDirection:
                # TODO flippy for items such as goombas??
                lbz r3, {ExtHitFlags1Offset}(r28)
                lfs f0, 0x2C(r31) # facing direction of attacker
                %`rlwinm.`(r0, r3, 0, 26, 26) # check FlippyTypeForward
                bne FlippyForward
                %`rlwinm.`(r0, r3, 0, 25, 25) # check opposite flippy
                bne StoreCalculatedDirection
                b StoreWindboxFlag
                FlippyForward:
                    fneg f0, f0
                StoreCalculatedDirection:
                    stfs f0, 0x1844(r30)
            
            StoreWindboxFlag:
                lbz r3, {ExtHitFlags1Offset}(r28)
                %`rlwinm.`(r0, r3, 0, 28, 28) # 0x8 for windbox flag
                li r3, 0
                beq WindboxSet
                li r3, 1
                WindboxSet:
                    lbz r0, {calcOffsetFighterExtData(Flags1Offset)}(r30)
                    rlwimi r0, r3, 0, {FlinchlessFlag}
                    stb r0, {calcOffsetFighterExtData(Flags1Offset)}(r30)

            SetWeight:
                # handles the setting and reseting of temp gravity & fall speed
                lbz r3, {ExtHitFlags1Offset}(r28)
                %`rlwinm.`(r3, r3, 0, ExtHitFlags1SetWeight)
                beq ResetTempGravityFallSpeed # hit isn't set weight, check to reset vars

                SetTempGravityFallSpeed:
                    # hit is set weight, set temp vars
                    bl Constants
                    mflr r3
                    addi r4, r30, 0x110 # ptr attributes of defender
                    # set gravity
                    lfs f0, 0(r3)
                    stfs f0, 0x5C(r4)
                    # set fall speed
                    lfs f0, 4(r3)
                    stfs f0, 0x60(r4)
                    # set our temp gravity and fall speed flag to true
                    li r3, 1
                    lbz r0, {calcOffsetFighterExtData(Flags1Offset)}(r30)
                    rlwimi r0, r3, 1, {TempGravityFallSpeedFlag}
                    stb r0, {calcOffsetFighterExtData(Flags1Offset)}(r30)
                    b StoreDisableMeteorCancel

                ResetTempGravityFallSpeed:
                    # reset gravity and fall speed only if the temp flag is true
                    lbz r3, {calcOffsetFighterExtData(Flags1Offset)}(r30)
                    %`rlwinm.`(r3, r3, 0, TempGravityFallSpeedFlag)
                    beq StoreDisableMeteorCancel
                    li r3, 0
                    lbz r0, {calcOffsetFighterExtData(Flags1Offset)}(r30)
                    rlwimi r0, r3, 1, {TempGravityFallSpeedFlag}
                    stb r0, {calcOffsetFighterExtData(Flags1Offset)}(r30)
                    # call custom reset func
                    mr r3, r30
                    %branchLink(CustomFuncResetGravityAndFallSpeed)
    
            StoreDisableMeteorCancel:
                lbz r3, {ExtHitFlags1Offset}(r28)
                %`rlwinm.`(r0, r3, 0, ExtHitFlags1DisableMeteorCancel)
                li r3, 0
                beq MeteorCancelSet
                li r3, 1
                MeteorCancelSet:
                    lbz r0, {calcOffsetFighterExtData(Flags1Offset)}(r30)
                    rlwimi r0, r3, 2, {DisableMeteorCancelFlag}
                    stb r0, {calcOffsetFighterExtData(Flags1Offset)}(r30)

            Epilog:
                %restore
                blr

            CalculateHitlagMultiOffset:
                cmpwi r3, 1
                beq Return1960
                cmpwi r3, 2
                bne Exit
                li r3, {calcOffsetItemExtData(ExtItHitlagMultiplierOffset)}
                b Exit
                Return1960:
                    li r3, 0x1960
                Exit:
                    blr

            IsItemOrFighter:
                # input = gobj in r3
                # returns 0 = ?, 1 = fighter, 2 = item, in r3
                lhz r0, 0(r3)
                cmpwi r0,0x4
                li r3, 1
                beq Result
                li r3, 2
                cmpwi r0,0x6
                beq Result
                li r3, 0
                Result:
                    blr

            Constants:
                blrl
                %`.float`(0.095) # mario's gravity
                %`.float`(1.7) # mario's fall speed

            OriginalExit:
                lwz r5, 0x010C(r31)

        # Patch PlayerThink_Shield/Damage Calculate Hitlag
        # If calculated hitlag is < 1.0, skip going into hitlag which disables A/S/DI
        patchInsertAsm "8006d708":
            lfs f0, -0x7790(rtoc) # 1.0
            fcmpo cr0, f1, f0
            %`bge+`(OriginalExit)
            # TODO add checks if callbacks are for SDI & ASDI functions?
            # we set the callback ptrs to 0 because it's possible for an attacker who is stuck in hitlag from attacking something
            # to be able to A/S/DI. In vBrawl, attackers hit by a move that does 0 hitlag does not reset their initial freeze frames but allows for only DI
            li r3, 0
            stw r3, 0x21D0(r30) # hitlag frame-per-frame cb
            stw r3, 0x21D8(r30) # hitlag exit cb
            %branch("0x8006d7e0") # skip set hitlag functions
            OriginalExit:
                stfs f1, 0x195C(r30)

        # Patch Damage_BranchToDamageHandler Calculate Hitlag for Pummels/Throw Related
        # If calculated hitlag is < 1.0, skip going into hitlag
        patchInsertAsm "8008f030":
            lfs f0, -0x7790(rtoc) # 1.0
            fcmpo cr0, f1, f0
            %`bge+`(OriginalExit)
            %branch("0x8008f078") # skip set hitlag functions
            OriginalExit:
                stfs f1, 0x195C(r27)            

        # Hitbox_MeleeLogicOnShield - Set Hit Vars
        patchInsertAsm "80076dec":
            # r31 = defender data
            # r30 = hit struct
            # r29 = src data
            # free regs to use: r0, f1, f0
            # get ExtHit
            lwz r3, 0(r29) # src gobj
            mr r4, r30 # hit struct
            %branchLink("0x801510d4")
            cmplwi r3, 0
            beq Exit

            # r3 = exthit
            lfs f0, {ExtHitShieldstunMultiplierOffset}(r3)
            stfs f0, {calcOffsetFighterExtData(ShieldstunMultiplierOffset)}(r31)

            Exit:
                # restore r3
                lwz r3, 0x24(sp)
                lwz r0, 0x30(r30) # original code line

        # Hitbox_ProjectileLogicOnShield - Set Hit Vars
        patchInsertAsm "80077914":
            # r29 = defender data
            # r28 = hit struct
            # r27 = src data
            # free regs to use f1, f0
            lwz r3, 0x4(r27) # src gobj
            mr r4, r28 # hit struct
            %branchLink("0x801510d4")
            cmplwi r3, 0
            beq Exit

            # r3 = exthit
            lfs f0, {ExtHitShieldstunMultiplierOffset}(r3)
            stfs f0, {calcOffsetFighterExtData(ShieldstunMultiplierOffset)}(r29)

            Exit:
                lwz r0, 0x30(r28) # original code line
        
        # COMMENTED OUT BELOW ARE CODES RELATING TO 0% HITLAG AGAINST SHIELDING OPPONENTS
        # # SHIELD HIT - Character Hitbox - Attacker+Victim
        # patchInsertAsm "80076d58":
        #     # patch for completely skipping hitlag functions (ASDI, DI & SDI) if hitlag multiplier is 0%
        #     # r31 = defender data
        #     # r30 = hit struct
        #     # r29 = src data
        #     # r3 has to be 0 to skip hitlag functions
        #     mr r0, r3 # backup r3

        #     # get ExtHit
        #     mr r3, r29 # src data
        #     mr r4, r30 # hit struct
        #     li r5, 2324
        #     li r6, 312
        #     li r7, {ExtFighterDataOffset}
        #     %branchLink("0x801510d8")
        #     cmplwi r3, 0
        #     beq Exit
        #     # r3 = ExtHit
        #     stw r3, 0x10(sp) # save ExtHit to stack for later use in other functions

        #     lwz r3, {ExtHitHitlagOffset}(r3) # load hitlag mutliplier
        #     cmpwi r3, 0
        #     mr r3, r0 # restore r3 here
        #     bne Exit
        #     li r3, 0

        #     Exit:
        #         lwz r0, 0x1924(r29) # orig line

        # # SHIELD HIT - Article Hitbox - Attacker+Victim Hitbox_ProjectileLogicOnShield
        # patchInsertAsm "80077718":
        #     # r29 = defender data
        #     # r28 = hit struct
        #     # r27 = src data
        #     # free regs to use f1, f0
        #     # patch for completely skipping hitlag functions (ASDI, DI & SDI) if hitlag multiplier is 0%
        #     # r31 has to be 0 to skip hitlag functions
        #     mr r3, r27 # src data
        #     mr r4, r28 # hit struct
        #     li r5, 1492
        #     li r6, 316
        #     li r7, {ExtItemDataOffset}
        #     %branchLink("0x801510d8")
        #     cmplwi r3, 0
        #     beq Exit
        #     # r3 = ExtHit
        #     stw r3, 0x20(sp) # save ExtHit to stack for later use in other functions

        #     lwz r0, {ExtHitHitlagOffset}(r3) # load hitlag mutliplier
        #     cmpwi r0, 0
        #     bne Exit
        #     li r31, 0

        #     Exit:
        #         lwz r0, 0x0C34(r27) # orig line

        # # Hitbox_MeleeLogicOnShield - Set Hit Vars
        # patchInsertAsm "80076dec":
        #     # r31 = defender data
        #     # r30 = hit struct
        #     # r29 = src data
        #     # free regs to use: r0, f1, f0
        #     mr r0, r3 # backup r3

        #     lwz r3, 0x10(sp) # load ExtHit from patch 80076d58
        #     cmplwi r3, 0
        #     beq Exit

        #     # r3 = exthit
        #     lfs f0, {ExtHitShieldstunMultiplierOffset}(r3)
        #     stfs f0, {calcOffsetFighterExtData(ShieldstunMultiplierOffset)}(r31)

        #     Exit:
        #         # restore r3
        #         mr r3, r0
        #         lwz r0, 0x30(r30) # original code line

        # # Hitbox_ProjectileLogicOnShield - Set Hit Vars
        # patchInsertAsm "80077918":
        #     # r29 = defender data
        #     # r28 = hit struct
        #     # r27 = src data
        #     # free regs to use f1, f0
        #     lwz r3, 0x20(sp) # load ExtHit from stack (patch 80077718)
        #     %branchLink("0x801510d8")
        #     cmpwi r3, 0
        #     beq Exit

        #     # r3 = exthit
        #     lfs f0, {ExtHitShieldstunMultiplierOffset}(r3)
        #     stfs f0, {calcOffsetFighterExtData(ShieldstunMultiplierOffset)}(r29)

        #     Exit:
        #         # restore r6
        #         mr r6, r30
        #         stw r0, 0x19B0(r29) # original code line

        # Hitbox Entity Vs Melee - Set Variables
        patchInsertAsm "802705ac":
            # eg. when a player hits an item with melee
            # r30 = itdata
            # r26 = fthit
            # r28 = attacker data ptr
            # r24 = gobj of itdata
            # r29 = gobj of attacker
            mr r3, r29 # src
            mr r4, r24 # def
            mr r5, r26 # ithit
            %branchLink("0x801510dc")
            Exit:
                lwz r0, 0xCA0(r30) # original code line

        # 8026fe68 - proj vs proj 
        # Hitbox Entity Vs Projectiles - Set Variables
        patchInsertAsm "80270bb8":
            # eg. when a player hits an item (eg. goomba) with projectile
            # r31 = itdata
            # r19 = hit struct
            # r26 = gobj of defender
            # r30 = gobj of attacker
            mr r3, r30 # atk
            mr r4, r26 # def
            mr r5, r19 # ithit
            %branchLink("0x801510dc")
            Exit:
                lwz r0, 0xCA0(r31) # original code line

        # CalculateKnockback patch for setting hit variables that affect the defender and attacker
        patchInsertAsm "8007aaf4":
            # r12 = source ftdata
            # r25 = defender ftdata
            # r31 = ptr ft hit
            # r30 = gobj of defender
            # r4 = gobj of src
            lwz r3, 0x8(r19)
            mr r4, r30
            lwz r5, 0xC(r19) # ptr fthit of source
            %branchLink("0x801510dc") # TODO const...
            %branch("0x8007ab0c")

        # ItemThink_Shield/Damage Hitlag Function For Other Entities
        # Patch Hitlag Multiplier
        patchInsertAsm "8026b454":
            # patch hitlag function used by other entities
            # r31 = itdata
            # f0 = floored hitlag frames
            lfs f1, {calcOffsetItemExtData(ExtItHitlagMultiplierOffset)}(r31)
            fmuls f0, f0, f1 # calculated hitlag frames * multiplier
            fctiwz f0, f0

        # ItemThink_Shield/Damage After Hitlag Calculation
        # If calculated hitlag is < 1.0, skip going into hitlag
        patchInsertAsm "8026a5f8":
            lfs f0, -0x7790(rtoc) # 1.0
            fcmpo cr0, f1, f0
            %`bge+`(OriginalExit)
            %branchLink("0x8026a68c") # skip hitlag
            OriginalExit:
                lfs f0, 0xCBC(r31)

        # Reset Custom Variables for Items
        patchInsertAsm "80269cdc":
            # r5 = itdata

            # reset custom vars to 1.0
            lfs f0, -0x7790(rtoc) # 1.0            
            stfs f0, {calcOffsetItemExtData(ExtItHitlagMultiplierOffset)}(r5)

            # reset custom vars to 0.0
            lfs f0, -0x33A8(rtoc) # 0.0, original code line

        # Init Default Values for ExtHit - Projectiles
        patchInsertAsm "802790f0":
            # r4 = hitbox id
            # r30 = item data??

            mulli r3, r4, {ExtHitSize}
            addi r3, r3, {ExtItemDataOffset}
            add r3, r30, r3
            # save r4 to r28
            mr r28, r4
            %branchLink(CustomFunctionInitDefaultEventVars)
            # restore r4
            mr r4, r28
            Exit:
                mulli r3, r4, 316 # orig code line

        # Init Default Values for ExtHit - Melee
        patchInsertAsm "8007127c":
            # r0 = hitbox ID
            # r31 = fighter data

            mulli r3, r0, {ExtHitSize}
            addi r3, r3, {ExtFighterDataOffset}
            add r3, r31, r3

            # backup r4 to r5
            mr r5, r4
            %branchLink(CustomFunctionInitDefaultEventVars)

            # restore r4
            mr r4, r5
            
            Exit:
                mulli r3, r0, 312 # orig code line

        # Reset Custom ExtFighterData vars that are involved at the end of Hitlag for Fighters
        patchInsertAsm "8006d1d8":
            # reset vars that need to be 1
            # r31 = fighter data
            lfs f0, -0x7790(rtoc) # 1
            stfs f0, {calcOffsetFighterExtData(SDIMultiplierOffset)}(r31)
            Exit:
                lwz r0, 0x24(sp)

        # Fix for Hitlag multipliers not affecting hits within grabs
        # TODO what about for item related hitlag?
        patchInsertAsm "8006d95c":
            # reset multiplier ONLY when there isn't a grabbed_attacker ptr
            # r30 = fighter data
            lwz r3, 0x1A58(r30) # grab_attacker ptr
            cmplwi r3, 0
            bne Exit # if someone is grabbing us, don't reset the multiplier
            stfs f0, 0x1960(r30) # else reset it to 1.0
            Exit:
                li r3, 0 # restore r3

        # Reset Custom ExtFighterData vars that are involved with PlayerThink_Shield/Damage
        patchInsertAsm "8006d8fc":
            # reset custom ExtData vars for fighter
            # f1 = 0.0
            # r3 = 0
            # r30 = fighter data
            # reset vars to 0

            # reset the following vars only if there isn't a grabbed_attacker ptr
            lwz r0, 0x1A58(r30) # grab_attacker ptr
            cmplwi r0, 0
            bne Exit # if someone is grabbing us, don't reset the custom vars

            # reset flinchless flag to 0
            lbz r0, {calcOffsetFighterExtData(Flags1Offset)}(r30)
            rlwimi r0, r3, 0, {FlinchlessFlag}
            stb r0, {calcOffsetFighterExtData(Flags1Offset)}(r30)

            # reset disable meteor cancel flag to 0
            lbz r0, {calcOffsetFighterExtData(Flags1Offset)}(r30)
            rlwimi r0, r3, 2, {DisableMeteorCancelFlag}
            stb r0, {calcOffsetFighterExtData(Flags1Offset)}(r30)

            stfs f1, {calcOffsetFighterExtData(HitstunModifierOffset)}(r30)
            # reset vars to 1.0
            lfs f0, -0x7790(rtoc) # 1.0
            stfs f0, {calcOffsetFighterExtData(ShieldstunMultiplierOffset)}(r30)

            Exit:
                stfs f1, 0x1838(r30) # original code line

        # Custom Non-Standalone Function For Initing Default Values in ExtHit
        patchInsertAsm "801510e4":
            # TODO samus create hitbox?
            cmpwi r4, 343
            %`beq-`(OriginalExit)

            # reset vars that need to be 1
            lfs f0, -0x7790(rtoc) # 1
            stfs f0, {ExtHitHitlagOffset}(r3)
            stfs f0, {ExtHitSDIMultiplierOffset}(r3)
            stfs f0, {ExtHitShieldstunMultiplierOffset}(r3)

            # reset vars that need to be 0
            lfs f0, -0x778C(rtoc) # 0.0
            stfs f0, {ExtHitHitstunModifierOffset}(r3)
            li r4, 0
            stw r4, {ExtHitFlags1Offset}(r3)
            blr

            OriginalExit:
                lfs f2, -0x5B3C(rtoc) # orig code line

        # Custom Non-Standalone Function For Reading Subaction Event Data
        patchInsertAsm "801510e0":
            cmpwi r4, 343
            %`beq-`(OriginalExit)

            # r5 = ExtItem/FighterDataOffset
            # r30 = item/fighter data
            stwu sp, -0x50(sp)
            lwz r3, 0x8(r29) # load current subaction ptr
            lbz r4, 0x1(r3)
            %`rlwinm.`(r0, r4, 0, 27, 27) # 0x10, apply to all previous hitboxes
            bne ApplyToAllPreviousHitboxes
            # otherwise, apply the properties to the given hitbox id
            li r0, 1 # loop once
            rlwinm r4, r4, 27, 29, 31 # 0xE0 hitbox id
            b SetLoopCount
            ApplyToAllPreviousHitboxes:
                li r0, 4 # loop 4 times
                li r4, 0

            SetLoopCount:
                mtctr r0
            # calculate ExtHit ptr offset in Ft/It data
            mulli r4, r4, {ExtHitSize}
            add r4, r4, r5
            add r4, r30, r4

            b BeginReadData

            CopyToAllHitboxes:
                # r6 = ptr to next ExtHit
                # r4 = ptr to old ExtHit
                addi r6, r4, {ExtHitSize}
                Loop:
                    lwz r0, {ExtHitHitlagOffset}(r4)
                    stw r0, {ExtHitHitlagOffset}(r6)

                    lwz r0, {ExtHitSDIMultiplierOffset}(r4)
                    stw r0, {ExtHitSDIMultiplierOffset}(r6)

                    lwz r0, {ExtHitShieldstunMultiplierOffset}(r4)
                    stw r0, {ExtHitShieldstunMultiplierOffset}(r6)

                    lwz r0, {ExtHitHitstunModifierOffset}(r4)
                    stw r0, {ExtHitHitstunModifierOffset}(r6)

                    lwz r0, {ExtHitFlags1Offset}(r4)
                    stw r0, {ExtHitFlags1Offset}(r6)
                    addi r6, r6, {ExtHitSize}
                    bdnz Loop
                b Exit

            BeginReadData:
                # load 0.01 to use for multipliying our multipliers
                lwz r6, -0x514C(r13) # static vars??
                lfs f1, 0xF4(r6) # load 0.01 into f1
                # hitlag & SDI multipliers
                lhz r6, 0x1(r3)
                rlwinm r6, r6, 0, 0xFFF # 0xFFF, load hitlag multiplier
                sth r6, 0x44(sp)
                lhz r6, 0x3(r3)
                rlwinm r6, r6, 28, 0xFFF # load SDI multiplier
                sth r6, 0x46(sp)
                psq_l f0, 0x44(sp), 0, 5 # load both hitlag & sdi multipliers into f0 (ps0 = hitlag multi, ps1 = sdi multi)
                ps_mul f0, f1, f0 # multiply both hitlag & sdi multipliers by f1 = 0.01
                psq_st f0, {ExtHitHitlagOffset}(r4), 0, 7 # store calculated hitlag & sdi multipliers next to each other

                # read shieldstun multiplier & hitstun modifier
                lwz r6, -0x514C(r13)
                psq_l f1, 0xF4(r6), 1, 7 # load 0.01 in f1(ps0), 1.0 in f1(ps1)
                lhz r6, 0x4(r3)
                rlwinm r6, r6, 0, 0xFFF # load shieldstun multiplier
                sth r6, 0x40(sp)
                lbz r6, 0x6(r3) # read hitstun modifier byte
                slwi r6, r6, 24
                srawi r6, r6, 24
                sth r6, 0x42(sp)
                psq_l f0, 0x40(sp), 0, 5 # load shieldstun multi in f0(ps0), hitstun mod in f0(ps1) ]#
                ps_mul f0, f1, f0 # shieldstun multi * 0.01, hitstun mod * 1.00
                psq_st f0, {ExtHitShieldstunMultiplierOffset}(r4), 0, 7 # store results next to each other
                # read isSetWeight & Flippy bits & store it
                lbz r6, 0x7(r3)
                stb r6, {ExtHitFlags1Offset}(r4)

            bdnz CopyToAllHitboxes

            Exit:
                # advance script
                addi r3, r3, 8 # TODO create a function to calculate this
                stw r3, 0x8(r29) # store current pointing ptr
                addi sp, sp, 80
                blr

            OriginalExit:
                fmr f3, f1

        # Patch for Subaction_FastForward
        patchInsertAsm "80073430":
            subi r0, r28, 10 # orig code line
            cmpwi r28, 0x3C # Hitbox Extension Custom ID
            bne OriginalExit
            lwz r4, 0x8(r29) # current action ptr
            addi r4, r4, 8
            stw r4, 0x8(r29)
            %branch("0x80073450")
            OriginalExit:
                %emptyBlock

        # Patch for FastForwardSubactionPointer2
        patchInsertAsm "80073574":
           # fixes a crash with Kirby when using inhale with a custom subaction event
            lwz r4, 0x8(r29) # orig code line, current action ptr
            cmpwi r28, 0x3C # Hitbox Extension Custom ID
            bne OriginalExit
            addi r4, r4, 8
            stw r4, 0x8(r29)
            %branch("0x80073588")
            OriginalExit:
                %emptyBlock

        # Custom Fighter Subaction Event
        patchInsertAsm "80073318":
            # use 0xF1 as code, make sure r28 == 0x3c
            # r27 = item/fighter gobj
            # r29 = script struct ptr
            # r30 = item/fighter data
            cmpwi r28, 0x3C
            %`bne+`(OriginalExit)
            li r5, {ExtFighterDataOffset}
            %branchLink(CustomFunctionReadEvent)
            %branch("0x8007332c")
            OriginalExit:
                lwz r12, 0(r3)

        # Custom Item Subaction Event
        patchInsertAsm "80279abc":
            # use 0xF1 as code, make sure r28 == 0x3c
            # r27 = item/fighter gobj
            # r29 = script struct ptr
            # r30 = item/fighter data
            cmpwi r28, 0x3C
            %`bne+`(OriginalExit)
            li r5, {ExtItemDataOffset}
            %branchLink(CustomFunctionReadEvent)
            %branch("0x80279ad0")
            OriginalExit:
                lwz r12, 0(r3)

        patchItemDataAllocation(ExtItemDataSize)
        patchFighterDataAllocation(ExtFighterDataSize)