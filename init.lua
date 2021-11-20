local Common = require('lsp-adept.common')
local Server = require('lsp-adept.server')

local LspAdept = {
    log_rpc = true,
    log_time = true,
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
    events.connect(events.BUFFER_AFTER_SWITCH, LspAdept.keepItUp)
    events.connect(events.FILE_OPENED, LspAdept.keepItUp)
    LspAdept.keepItUp()
end)


function LspAdept.pertinent(filepath_or_buf, lang)
    local _, file_path, lang = LspAdept.fitFor(filepath_or_buf, lang)
    return lang
end


function LspAdept.fitFor(filepath_or_buf, lang)
    local buf, file_path = Common.bufAndFilePath(filepath_or_buf)
    lang = lang or (buf and buf:get_lexer(true))
    if lang and LspAdept.lang_servers[lang] and LspAdept.lang_servers[lang].cmd then
        return buf, file_path, lang
    end
end


function LspAdept.keepItUp(filepath_or_buf, lang)
    local _, file_path, lang = LspAdept.fitFor(filepath_or_buf, lang)
    if lang then
        if not LspAdept.lang_servers[lang]._ then
            LspAdept.lang_servers[lang]._ = Server.new(lang, LspAdept.lang_servers[lang], file_path)
        end
        return LspAdept.lang_servers[lang]._
    end
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
