Config = {}

Config.Npc = { -- Ped start de la mission
    model = 'IG_Money',
    coords = vector4(-563.0, -921.0, 23.9, 270.0)
}

Config.Hours = { -- heures de début et de fin de la mission
    start = 22,
    finish = 4
}

Config.SaveMetadata = true    -- save de la progression en metadata

Config.CooldownType = 'daily' -- 'daily' or 'unique'

Config.Screamer = {           -- activer ou non le screamer
    enabled = true,
    chance = 100
}

Config.Ghosts = { -- positions et models de fantômes
    {
        id = 'ghost_skidrow',
        model = 'm23_1_prop_m31_ghostskidrow_01a',
        coords = vector4(-456.0, -938.0, 24.0, 358.0)
    },

}

Config.Rewards = { -- récompenses à la fin de la mission
    money = 5000,
    items = {
        { name = 'bread', count = 2 }
    }
}
