local Common = require('lsp-adept.common')

local Server = {
    shutting_down = false
}


local msgicons = {"gtk-dialog-error", "gtk-dialog-warning", "gtk-dialog-info", "gtk-dialog-info", "gtk-dialog-question"}

local notifs_ignore, inreqs_ignore, inreqs_todo = {}, {}, {}
notifs_ignore['telemetry/event'] = 1
inreqs_todo['client/registerCapability'] = 1



function Server.new(lang, desc)
    local me = {
        lang = lang, desc = desc,
        lang_server = { caps = nil, name = lang .. " LSP `" .. desc.cmd .. "`" }
    }
    me.sendNotify = function(method, params) return Server.sendNotify(me, method, params) end
    me.sendRequest = function(method, params) return Server.sendRequest(me, method, params) end

    Server.ensureProc(me)
    return me
end

function setStatusBarText(text)
    ui.statusbar_text = string.gsub(string.gsub(text, "\r", ""), "\n", " — ")
end

function Server.showMsgBox(me, text, level)
    setStatusBarText(text)
    ui.dialogs.msgbox({ title = me.lang_server.name, text = text, icon = level and msgicons[level] or nil })
end

function Server.log(me, msg)
    if msg then
        Common.shush('['..me.lang..']\t'..msg)
        setStatusBarText(msg)
    end
end

function Server.chk(me)
    if me.proc and me.proc:status() == 'terminated' then
        me.proc = nil
    end
    return me.proc
end

function Server.ensureProc(me)
    local err
    if (not Server.shutting_down) and not Server.chk(me) then
        me._reqid, me._stdin, me._inbox, me._waiting = 0, "", {}, false
        me.proc, err = os.spawn(me.desc.cmd, me.desc.cwd or lfs.currentdir(),
                                Server.onStdout(me), Server.onStderr(me), Server.onExit(me))
        if err then
            Server.die(me)
            Server.log(me, err)
        end
        if me.proc then
            Server.log(me, me.proc:status())
            local result, err = Server.sendRequest(me, 'initialize', {
                processId = Common.Json.null, rootUri = Common.Json.null,
                initializationOptions = me.desc.init_options or Common.Json.null,
                capabilities = {
                    textDocument = {
                        hover = Common.LspAdept.features.textDocument.hover.clientCapabilities()
                    },
                    window = {
                        showMessage = Common.Json.empty
                    },
                    workspace = Common.Json.empty
                }
            })
            if result then
                me.lang_server.caps = result.capabilities
                if result.serverInfo and result.serverInfo.name and #result.serverInfo.name > 0 then
                    me.lang_server.name = result.serverInfo.name
                end
                Server.sendNotify(me, 'initialized', Common.Json.empty)
            end
        end
    end
    return Server.chk(me)
end

function Server.die(me)
    if me.proc then
        pcall(function() me.proc:close() end)
        pcall(function() me.proc:kill() end)
        me.proc = nil
    end
end

function Server.onExit(me) return function(exitcode)
    Server.log(me, "EXITED: "..exitcode)
    Server.die(me)
end end

function Server.onStderr(me) return function(data)
    Server.log(me, data)
end end

function Server.onStdout(me) return function(data)
    Server.onIncomingData(me, data)
    Server.processInbox(me)
end end

function jRpcErr(msg)
    return {code = -32603, message = msg}
end

function parseContentLength(str)
    local pos = string.find(str, "Content-Length:", 1, 'plain')
    if not pos then
        return
    end
    local numpos = pos + #"Content-Length:"
    local rnpos = string.find(str, "\r", numpos, 'plain')
    if not rnpos then
        return nil, numpos, rnpos
    end
    return tonumber(string.sub(str, numpos, rnpos)), numpos, rnpos
end

function Server.sendMsg(me, msg, addreqid)
    if Server.ensureProc(me) then
        if addreqid then
            me._reqid = me._reqid + 1
            msg.id = me._reqid
        end
        local data = Common.Json.encode(msg)
        if Common.LspAdept.log_rpc then
            Server.log(me, ">>>>" .. data)
        end
        local ok, err = me.proc:write("Content-Length: "..(#data+2).."\r\n\r\n"..data.."\r\n")
        if (not ok) and err and #err > 0 then
            Server.die(me)
            Server.log(me, err)
            -- the below, via ensureProc, will restart server, which sends init stuff before ours. (they do crash sometimes, or pipes break..)
            return Server.sendMsg(me, data)
        end
    end
    return msg.id
end

function Server.sendNotify(me, method, params)
    Server.sendMsg(me, {jsonrpc = '2.0', method = method, params = params})
end

function Server.sendResponse(me, reqid, result, error)
    Server.sendMsg(me, {jsonrpc = '2.0', id = reqid, result = result, error = error})
end

function Server.sendRequest(me, method, params)
    local reqid = Server.sendMsg(me, {jsonrpc = '2.0', method = method, params = params}, true)
    if method == 'shutdown' then return end
    me._waiting = true
    while true do
        local accum, posrn = "", nil
        while (not posrn) and Server.ensureProc(me) do
            local chunk = me.proc:read("L")
            if (not chunk) then
                break
            else
                accum = accum .. chunk
                posrn = string.find(accum, "\r\n\r\n", 1, 'plain')
            end
        end
        if posrn then
            local posdata = posrn + 4
            local numbytesgot = #accum - (posdata - 1)
            local clen = parseContentLength(string.sub(accum, 1, posn1))
            if clen then
                local tail = me.proc:read(clen - numbytesgot)
                if tail then
                    local data = string.sub(accum, posdata) .. tail
                    Server.pushToInbox(me, data)
                    local resp, err = Server.takeFromInbox(me, reqid)
                    if resp or err then
                        me._waiting = false
                        return resp, err
                    end
                end
            end
        end
    end
end

function Server.onIncomingData(me, incoming_data)
    if not (incoming_data and #incoming_data > 0) then
        return
    end
    me._stdin = me._stdin .. incoming_data
    while true do
        local clen, numpos, rnpos = parseContentLength(me._stdin)
        if not rnpos then
            break
        elseif (not clen) or clen < 2 then
            me._stdin = string.sub(me._stdin, rnpos)
            break
        end
        local datapos = string.find(me._stdin, "\r\n\r\n", numpos, 'plain')
        if not datapos then
            break
        end
        datapos = datapos + #"\r\n\r\n"
        local data = string.sub(me._stdin, datapos, (datapos + clen) - 1)
        if (not data) or #data < clen then
            break
        end
        me._stdin = string.sub(me._stdin, datapos + clen)
        Server.pushToInbox(me, data)
    end
end

function Server.pushToInbox(me, data)
    if Common.LspAdept.log_rpc then
        Server.log(me, "<<<<" .. data)
    end
    local msg, errpos, errmsg = Common.Json.decode(data)
    if msg then
        me._inbox[1 + #me._inbox] = msg
    end
    if errmsg and #errmsg > 0 then
        Server.log(me, "UNJSON: '" .. errmsg .. "' at pos " .. errpos .. 'in: ' .. data)
        Server.showMsgBox(me, 'Bad JSON, check LSP log', 2)
    end
end

function Server.takeFromInbox(me, waitreqid)
    for i, msg in ipairs(me._inbox) do
        if msg.id and msg.id == waitreqid then
            table.remove(me._inbox, i)
            return msg.result, msg.error
        end
    end
end

function Server.processInbox(me)
    if me._waiting then
        return
    end
    local keeps = {}
    for i, msg in ipairs(me._inbox) do
        if msg.id and msg.method then
            Server.onIncomingRequest(me, msg)
        elseif msg.method then
            Server.onIncomingNotification(me, msg)
        else
            keeps[#keeps + 1] = msg
        end
    end
    me._inbox = keeps
end

function Server.onIncomingNotification(me, msg)
    if msg.params and msg.method == "window/showMessage" and msg.params.message then
        Server.showMsgBox(me, msg.params.message, msg.params.type or 5)
    elseif msg.params and msg.method == "window/logMessage" and msg.params.message then
        Server.log(me, "LOGIT:\t" .. msg.params.message)
    elseif not notifs_ignore[msg.method] then
        Server.log(me, "NOTIF:\t"..Common.Json.encode(msg))
        Server.showMsgBox(me, msg.method, 5)
    end
end

function Server.onIncomingRequest(me, msg)
    local known = inreqs_ignore[msg.method] or inreqs_todo[msg.method]
    Server.sendResponse(me, msg.id, nil, jRpcErr("That's not on."))
    if not known then
        Server.log(me, "INREQ:\t" .. Common.Json.encode(msg))
        Server.showMsgBox(me, msg.method, 5)
    end
end



return Server
