local Radio = require('yacm/client/Radio')

local YacmClientRecvCommands = {}

YacmClientRecvCommands['ChatMessage'] = function(args)
    ISChat.onMessagePacket(args)
end

YacmClientRecvCommands['RadioMessage'] = function(args)
    ISChat.onRadioPacket(
        args['type'], args['author'], args['message'], args['color'], args['radios'])
end

YacmClientRecvCommands['Typing'] = function(args)
    ISChat.onTypingPacket(args['author'], args['type'])
end

YacmClientRecvCommands['ChatError'] = function(args)
    ISChat.onChatErrorPacket(args['type'], args['message'])
end

YacmClientRecvCommands['ServerPrint'] = function(args)
    print('Server: ' .. args.message)
end

YacmClientRecvCommands['SendSandboxVars'] = function(args)
    ISChat.onRecvSandboxVars(args)
end

YacmClientRecvCommands['RadioSquareState'] = function(args)
    Radio.SyncSquare(
        args.turnedOn, args.mute, args.power, args.volume,
        args.frequency, args.x, args.y, args.z)
end

YacmClientRecvCommands['RadioInHandState'] = function(args)
    Radio.SyncInHand(
        args.id, args.turnedOn, args.mute, args.power, args.volume,
        args.frequency)
end

function OnServerCommand(module, command, args)
    if module == 'YACM' and YacmClientRecvCommands[command] then
        YacmClientRecvCommands[command](args)
    end
end

Events.OnServerCommand.Add(OnServerCommand)

return YacmClientRecvCommands