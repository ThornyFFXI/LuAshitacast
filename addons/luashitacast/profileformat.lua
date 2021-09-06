local profile = {};
profile.sets = {};

--Table members are coded N(number), S(string), or T(table)

--Called when profile is loaded.
profile.OnLoad = function()
  print('Hello from profile load!');
end

--Called when profile is unloaded.
profile.OnUnload = function()

end

--Called constantly whenever player is not currently in the middle of using an ability.
--Should be used to handle idle sets, engaged sets, DT sets, any set you want to be in while not performing an ability.
--Should also be used for pet abilities and spells.
profile.HandleDefault = function()

end

--Called whenever player performs an ability.  Equipment is placed on before the ability executes.
--ability is a table with members: Name[S], Id[N], Resource[Table]
--target is a table with members: Distance[N], HPP[N], Id[N], Index[N], Name[S], Status[S], Type[S]
profile.HandleAbility = function(ability, target)
  print(('%s : %s'):fmt(ability.Name, target.Name));
end

--Called whenever player uses an item.  Equipment is placed on before the item begins to execute and kept until item completes.
--item is a table with members: Name[S], ID[N], Resource[Table]
--target is a table with members: Distance[N], HPP[N], Id[N], Index[N], Name[S], Status[S], Type[S]
--Using an item via packet before the item loads into inventory in client memory will result in the item name 'Unknown'.
--This is probably not a concern, but was noted in case of future addon that allows using items out of other bags.
profile.HandleItem = function(item, target)
  print(('%s : %s'):fmt(item.Name, target.Name));
end

--Called whenever player starts casting a spell.  Equipment is placed on before the spell begins.
--This should be used for any equipment that changes the casttime of the spell.
--If midcast gear is specified, it will immediately overwrite precast gear and you cannot be hit in precast.
--spell is a table with members: Name[S], ID[N], Casttime[N, milliseconds], Element[S], MpAftercast[N], MpCost[N], Recast[N, milliseconds], Skill[S], Type[S], Resource[Table]
--target is a table with members: Distance[N], HPP[N], Id[N], Index[N], Name[S], Status[S], Type[S]
profile.HandlePrecast = function(spell, target)
  print(('%s : %s'):fmt(spell.Name, target.Name));
end

--Called whenever player starts casting a spell.  Equipment is placed on after the spell begins.
--This should be used for any equipment that changes the effects of the spell.
--spell is a table with members: Name[S], ID[N], Casttime[N, milliseconds], Element[S], MpAftercast[N], MpCost[N], Recast[N, milliseconds], Skill[S], Type[S], Resource[Table]
--target is a table with members: Distance[N], HPP[N], Id[N], Index[N], Name[S], Status[S], Type[S]
profile.HandleMidcast = function(spell, target)
  print(('%s : %s'):fmt(spell.Name, target.Name));
end

--Called whenever player starts a ranged attack.  Equipment is placed on before the ranged attack begins.
--This should be used for any equipment that changes the length of the ranged attack.
--If midshot gear is specified, it will immediately overwrite preshot gear and you cannot be hit in preshot.
--target is a table with members: Distance[N], HPP[N], Id[N], Index[N], Name[S], Status[S], Type[S]
profile.HandlePreshot = function(target)
  print(('Ranged: %s'):fmt(target.Name));
end

--Called whenever player starts a ranged attack.  Equipment is placed on after the ranged attack begins.
--This should be used for any equipment that changes the effects of the ranged attack.
--target is a table with members: Distance[N], HPP[N], Id[N], Index[N], Name[S], Status[S], Type[S]
profile.HandleMidshot = function(target)
  print(('Ranged: %s'):fmt(target.Name));
end

--Called whenever player performs a weaponskill.  Equipment is placed on before the weaponskill executes.
--skill is a table with members: Name[S], Id[N], Resource[Table]
--target is a table with members: Distance[N], HPP[N], Id[N], Index[N], Name[S], Status[S], Type[S]
profile.HandleWeaponskill = function(skill, target)
  print(('%s : %s'):fmt(skill.Name, target.Name));
end

return profile;