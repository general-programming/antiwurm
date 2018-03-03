import irc, asyncnet, asyncdispatch, parsecfg, tables, strutils

type
    IrcConfig = tuple[host: string, user: string, password: string, channels: seq[string]]
    CommandCallable = proc (c: AsyncIrc, ev: IrcEvent, m: string): Future[void]

var commands = initTable[string, CommandCallable](16)

commands["ping"] = proc (client: AsyncIrc, ev: IrcEvent, msg: string) {.async.} =
    await client.privmsg(ev.origin, "Pong!")

commands["pong"] = proc (client: AsyncIrc, ev: IrcEvent, msg: string) {.async.} =
    await client.privmsg(ev.origin, ev.nick & " likes cute asian boys.")

proc handleMessage(client: AsyncIrc, ev: IrcEvent, msg: string) {.async.} =
    if msg.startsWith('?'):
        var args = msg.splitWhitespace()
        let cmd = args[0].strip(chars = {'?'})
        args.delete(0)

        if commands.hasKey(cmd):
            await commands[cmd](client, ev, msg)

proc handleEvent(client: AsyncIrc, ev: IrcEvent) {.async.} =
    if ev.typ == EvMsg and ev.cmd == MPrivMsg:
        var msg = ev.params[ev.params.high]
        await handleMessage(client, ev, msg)

proc connect(config: IrcConfig) =
    let client = newAsyncIrc(config.host, nick = config.user, user = config.user, serverPass = config.password, joinChans = config.channels, callback = handleEvent)
    echo "Twitch Plays starting..."
    asyncCheck client.run()
    runForever()

let config = loadConfig("config.ini")

let ircHost = config.getSectionValue("IRC", "host")
let ircUser = config.getSectionValue("IRC", "user")
let ircPass = config.getSectionValue("IRC", "password")
let ircChannels = @[config.getSectionValue("IRC", "primaryChannel")]
let ircOpts: IrcConfig = (host: ircHost, user: ircUser, password: ircPass, channels: ircChannels)

connect(ircOpts)
