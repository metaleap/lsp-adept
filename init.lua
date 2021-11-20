local Common = require('lsp-adept.common')
local Server = require('lsp-adept.server')

local LspAdept = {
    log_rpc = true,
    allow_markdown_docs = true,
    lang_servers = { -- eg:
        --go = {cmd = 'gopls'}
    },
    features = {
        textDocument = {
            hover = require('lsp-adept.textDocument-hover')
        }
    }
}
Common.LspAdept = LspAdept -- lets all *.lua use the above infos


events.connect(events.INITIALIZED, function()
    events.connect(events.RESET_BEFORE, LspAdept.shutItDown)
    events.connect(events.QUIT, LspAdept.shutItDown)
    events.connect(events.BUFFER_AFTER_SWITCH, LspAdept.keepUp)
    events.connect(events.FILE_OPENED, LspAdept.keepUp)
    LspAdept.keepUp()
end)


function LspAdept.keepUp(filepath_or_buffer, lang)
    local buf = (type(filepath_or_buffer) == 'string') and Common.bufferFrom(filepath_or_buffer)
                    or (filepath_or_buffer or buffer)
    lang = lang or buf:get_lexer(true)
    if not (lang and LspAdept.lang_servers[lang] and LspAdept.lang_servers[lang].cmd) then
        return nil
    end

    if not LspAdept.lang_servers[lang]._ then
        LspAdept.lang_servers[lang]._ = Server.new(lang, LspAdept.lang_servers[lang])
    end
    return LspAdept.lang_servers[lang]._
end


function LspAdept.shutItDown()
    Server.shutting_down = true
    for langname, it in pairs(LspAdept.lang_servers) do
        if it._ then
            Server.sendRequest(it._, 'shutdown')
            Server.sendNotify(it._, 'exit')
            Server.die(it._)
        end
        LspAdept.lang_servers[langname]._ = nil
    end
    Server.shutting_down = false
end


return LspAdept
