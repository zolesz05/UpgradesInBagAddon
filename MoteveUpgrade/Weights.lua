-- Moteve Upgrade - default stat weights
-- Values are relative points per 1 unit of the stat. hit / crit / dodge / parry / block are per 1%.
-- dps / rangedDps are per 1 weapon damage-per-second. These are starting values, not simulations:
-- tune them in game with  /mup weight <stat> <value>.
--
-- Stat keys: str agi sta int spi armor ap rap feralap sp heal hit crit haste mp5 hp5
--            def dodge parry block blockvalue dps rangedDps

local _, ns = ...

ns.PROFILES = {
    WARRIOR = {
        { key = "dps",  label = "Arms / Fury (DPS)",
          w = { str = 1.0, agi = 0.65, ap = 0.5, hit = 14, crit = 13, sta = 0.05, dps = 6 } },
        { key = "tank", label = "Protection (Tank)",
          w = { sta = 1.0, armor = 0.06, def = 1.5, dodge = 12, parry = 10, block = 6, blockvalue = 0.3,
                str = 0.4, agi = 0.5, hit = 6, dps = 1.5 } },
    },
    PALADIN = {
        { key = "holy", label = "Holy (Healer)",
          w = { int = 1.0, heal = 0.9, sp = 0.9, mp5 = 2.0, crit = 9, spi = 0.2, sta = 0.1 } },
        { key = "ret",  label = "Retribution (DPS)",
          w = { str = 1.0, agi = 0.6, ap = 0.5, hit = 12, crit = 12, int = 0.2, sp = 0.3, sta = 0.05, dps = 5 } },
        { key = "prot", label = "Protection (Tank)",
          w = { sta = 1.0, armor = 0.05, def = 1.2, dodge = 10, parry = 8, block = 5, blockvalue = 0.4,
                sp = 0.6, int = 0.3, hit = 5 } },
    },
    HUNTER = {
        { key = "dps", label = "Ranged (DPS)",
          w = { agi = 1.0, rap = 0.45, ap = 0.45, hit = 14, crit = 13, int = 0.3, sta = 0.1, rangedDps = 4, dps = 0.5 } },
    },
    ROGUE = {
        { key = "dps", label = "Melee (DPS)",
          w = { agi = 1.0, str = 0.5, ap = 0.5, hit = 15, crit = 12, sta = 0.1, dps = 5 } },
    },
    PRIEST = {
        { key = "heal",   label = "Holy / Discipline (Healer)",
          w = { int = 1.0, heal = 0.9, sp = 0.9, mp5 = 2.0, spi = 0.6, crit = 9, sta = 0.1 } },
        { key = "shadow", label = "Shadow (DPS)",
          w = { sp = 1.0, heal = 0.33, hit = 12, crit = 9, int = 0.4, spi = 0.25, sta = 0.15 } },
    },
    SHAMAN = {
        { key = "ele",   label = "Elemental (DPS)",
          w = { sp = 1.0, heal = 0.33, hit = 12, crit = 10, int = 0.45, mp5 = 1.0, sta = 0.1 } },
        { key = "enh",   label = "Enhancement (DPS)",
          w = { str = 1.0, agi = 0.6, ap = 0.5, hit = 12, crit = 12, int = 0.2, sta = 0.05, dps = 5 } },
        { key = "resto", label = "Restoration (Healer)",
          w = { int = 1.0, heal = 0.9, sp = 0.9, mp5 = 2.2, crit = 9, spi = 0.2, sta = 0.1 } },
    },
    MAGE = {
        { key = "dps", label = "Caster (DPS)",
          w = { sp = 1.0, heal = 0.33, hit = 13, crit = 10, int = 0.45, spi = 0.1, mp5 = 0.5, sta = 0.1 } },
    },
    WARLOCK = {
        { key = "dps", label = "Caster (DPS)",
          w = { sp = 1.0, heal = 0.33, hit = 13, crit = 7, sta = 0.3, int = 0.3, spi = 0.1 } },
    },
    DRUID = {
        { key = "balance", label = "Balance (DPS)",
          w = { sp = 1.0, heal = 0.33, hit = 12, crit = 9, int = 0.4, spi = 0.15, mp5 = 0.8, sta = 0.1 } },
        { key = "cat",     label = "Feral Cat (DPS)",
          w = { agi = 1.1, str = 1.0, ap = 0.5, feralap = 0.5, hit = 13, crit = 13, sta = 0.1 } },
        { key = "bear",    label = "Feral Bear (Tank)",
          w = { sta = 1.0, armor = 0.1, agi = 0.7, def = 1.2, dodge = 12, str = 0.3, ap = 0.1, feralap = 0.1, hit = 5 } },
        { key = "resto",   label = "Restoration (Healer)",
          w = { int = 1.0, heal = 0.9, sp = 0.9, mp5 = 2.0, spi = 0.6, crit = 8, sta = 0.1 } },
    },
}

ns.STAT_NAMES = {
    str = "Strength", agi = "Agility", sta = "Stamina", int = "Intellect", spi = "Spirit",
    armor = "Armor", ap = "Attack Power", rap = "Ranged Attack Power", feralap = "Feral Attack Power",
    sp = "Spell Damage & Healing", heal = "Healing", hit = "Hit %", crit = "Crit %", haste = "Haste",
    mp5 = "Mana per 5", hp5 = "Health per 5", def = "Defense", dodge = "Dodge %", parry = "Parry %",
    block = "Block %", blockvalue = "Block Value", dps = "Weapon DPS", rangedDps = "Ranged Weapon DPS",
}
