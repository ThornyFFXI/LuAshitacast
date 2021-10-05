addon.name      = 'LuAshitacast';
addon.author    = 'Thorny';
addon.version   = '1.09';
addon.desc      = 'A lua-based equipment swapping system for Ashita';
addon.link      = 'https://github.com/ThornyFFXI/LuAshitacast';

require('common');
require('globals');
chat = require('chat');

gBase = {};
gData = require('data');
gDefaultSettings = require('settings');
gFunc = require('func');
gEquip = require('equip');
gFileTools = require('filetools');
gProfile = nil;
gState = require('state');
gCommandHandlers = require('commandhandlers');
gPacketHandlers = require('packethandlers');

ashita.events.register('load', 'load_cb', function ()
    gState.Init();
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