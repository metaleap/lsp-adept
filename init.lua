local common = require('lsp-adept.common')
local server = require('lsp-adept.server')

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
common.LspAdept = LspAdept -- lets all *.lua use the above infos


events.connect(events.INITIALIZED, function()
    events.connect(events.RESET_BEFORE, LspAdept.shutItDown)
    events.connect(events.QUIT, LspAdept.shutItDown)
    events.connect(events.BUFFER_AFTER_SWITCH, LspAdept.keepUp)
    events.connect(events.FILE_OPENED, LspAdept.keepUp)
    LspAdept.keepUp()
end)


function LspAdept.keepUp(filepath_or_buffer)
    local buf = (type(filepath_or_buffer) == 'string') and common.bufferFromFilePath(filepath_or_buffer)
                    or (filepath_or_buffer or buffer)
    local lang = buf:get_lexer(true)
    if not (lang and LspAdept.lang_servers[lang] and LspAdept.lang_servers[lang].cmd) then
        return nil
    end

    if not LspAdept.lang_servers[lang]._ then
        LspAdept.lang_servers[lang]._ = server.new(lang, LspAdept.lang_servers[lang])
    end
    return LspAdept.lang_servers[lang]._
end


function LspAdept.shutItDown()
    server.shutting_down = true
    for langname, it in pairs(LspAdept.lang_servers) do
        if it._ then
            server.sendRequest(it._, 'shutdown', null, true)
            server.sendNotify(it._, 'exit')
            server.die(it._)
        end
        LspAdept.lang_servers[langname]._ = nil
    end
    server.shutting_down = false
end


return LspAdept
