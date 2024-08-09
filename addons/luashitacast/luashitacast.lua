addon.name      = 'LuAshitacast';
addon.author    = 'Thorny';
addon.version   = '2.04';
addon.desc      = 'A lua-based equipment swapping system for Ashita';
addon.link      = 'https://github.com/ThornyFFXI/LuAshitacast';

require('common');
chat = require('chat');
local jit = require('jit');
jit.off();

gConfigGUI           = require('config');
gData                = require('data');
gFunc                = require('func');
gEquip               = require('equip');
gFileTools           = require('filetools');
gIntegration         = require('integration');
gState               = require('state');
gCommandHandlers     = require('commandhandlers');
gPacketHandlers      = require('packethandlers');
gSetDisplay          = require('setdisplay');
gPreservedGlobalKeys = T{};

ashita.events.register('load', 'load_cb', function ()
    --Create a list of all globals the ashita environment has created.
    --This will be used to clear all leftover globals when loading a new profile.
    for key,_ in pairs(_G) do
        gPreservedGlobalKeys[key] = true;
    end
    gState.Init();
end);

ashita.events.register('d3d_present', 'mobdb_main_render', function()
    gConfigGUI:Render();
    gSetDisplay:Render();
end);

ashita.events.register('packet_in', 'packet_in_cb', function (e)
    gPacketHandlers.HandleIncomingPacket(e);
end);

ashita.events.register('packet_out', 'packet_out_cb', function (e)
    gPacketHandlers.HandleOutgoingPacket(e);
end);

ashita.events.register('command', 'command_cb', function (e)
    gCommandHandlers.HandleCommand(e);
end);