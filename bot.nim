import irc, asyncnet, asyncdispatch, parsecfg, tables, strutils, asyncfile, os

type
    IrcConfig = tuple[host: string, user: string, password: string, channels: seq[string]]
    CommandCallable = proc (c: AsyncIrc, ev: IrcEvent, a: seq[string]): Future[void]

var commands = initTable[string, CommandCallable](16)
let pipe = openAsync("wurm_comms", fmReadWrite)

commands["ping"] = proc (client: AsyncIrc, ev: IrcEvent, args: seq[string]) {.async.} =
    await client.privmsg(ev.origin, "Pong!")

commands["pong"] = proc (client: AsyncIrc, ev: IrcEvent, args: seq[string]) {.async.} =
    await client.privmsg(ev.origin, ev.nick & " likes cute asian boys.")

commands["vote"] = proc (client: AsyncIrc, ev: IrcEvent, args: seq[string]) {.async.} =
    if args.len < 1:
        await client.privmsg(ev.origin, ev.nick & ": You need to specify a number to vote!")
        return

    let parts = ["vote", ev.nick, ev.origin, args[0]]
    await pipe.write(parts.join(":") & "\n")

proc handleMessage(client: AsyncIrc, ev: IrcEvent, msg: string) {.async.} =
    if msg.startsWith('?'):
        var args = msg.splitWhitespace()
        let cmd = args[0].strip(chars = {'?'})
        args.delete(0)

        if commands.hasKey(cmd):
            await commands[cmd](client, ev, args)

proc handleEvent(client: AsyncIrc, ev: IrcEvent) {.async.} =
    if ev.typ == EvMsg and ev.cmd == MPrivMsg:
        var msg = ev.params[ev.params.high]
        await handleMessage(client, ev, msg)

proc connect(config: IrcConfig) =
    let client = newAsyncIrc(config.host, nick = config.user, user = config.user, serverPass = config.password, joinChans = config.channels, callback = handleEvent)
    echo "Twitch Plays starting..."
    asyncCheck client.run()
    runForever()
    pipe.close()

let config = loadConfig("config.ini")

let ircHost = config.getSectionValue("IRC", "host")
let ircUser = config.getSectionValue("IRC", "user")
let ircPass = config.getSectionValue("IRC", "password")
let ircChannels = @[config.getSectionValue("IRC", "primaryChannel")]
let ircOpts: IrcConfig = (host: ircHost, user: ircUser, password: ircPass, channels: ircChannels)

connect(ircOpts)
