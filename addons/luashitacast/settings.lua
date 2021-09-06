local settings = {
    AddSetEquipScreenOrder = true,
    AllowSyncEquip = true,
    AllowAddSet = false,
    Debug = true,
    EquipBags = {
        [1] = 8,
        [2] = 10,
        [3] = 11,
        [4] = 12,
        [5] = 0
    },
    EnableNomadStorage = false,
    ForceEnableBags = { },
    ForceDisableBags = { },
    PetskillDelay = 4000,
    WeaponskillDelay = 3000,
    AbilityDelay = 2500,
    SpellOffset = 500,
    RangedBase = 10000,
    RangedOffset = 500,
    ItemBase = 4000;
    ItemOffset = 500,
    FastCast = 0,
    Snapshot = 0
};

settings.Reset = function()
    gSettings.AddSetEquipScreenOrder = true;
    gSettings.AllowSyncEquip = true;
    gSettings.AllowAddSet = false;
    gSettings.Debug = true;
    gSettings.EquipBags = {
        [1] = 8,
        [2] = 10,
        [3] = 11,
        [4] = 12,
        [5] = 0
    };
    gSettings.ForceEnableBags = { 0, 8, 10, 11, 12 };
    gSettings.ForceDisableBags = { 0, 8, 10, 11, 12 };
    gSettings.PetskillDelay = 4000;
    gSettings.WeaponskillDelay = 3000;
    gSettings.AbilityDelay = 2500;
    gSettings.SpellOffset = 500;
    gSettings.RangedBase = 10000;
    gSettings.RangedOffset = 500;
    gSettings.ItemBase = 4000;
    gSettings.ItemOffset = 500;
    gSettings.FastCast = 0;
    gSettings.Snapshot = 0;
end

return settings;