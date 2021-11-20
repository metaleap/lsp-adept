local common = require('lsp-adept.common')

-- language-server-protocol/blob/gh-pages/_specifications/specification-3-16.md#textDocument_hover
local Hover = {
}


Hover.clientCapabilities = function()
    return { contentFormat = common.LspAdept.allow_markdown_docs and { 'markdown', 'plaintext' } or { 'plaintext' } }
end


Hover.show = function(pos, file_path, lang)
    local result, err = Hover.get(pos)
    if result or err then
        return view:call_tip_show(pos or buffer.current_pos, common.json.encode(result or err))
    end
end


Hover.get = function(pos, file_path, lang)
    local srv = common.LspAdept.keepUp(lang, file_path)
    if not (srv and srv.lang_server.caps and srv.lang_server.caps.hoverProvider) then
        return
    end
    local hover_params = common.textDocumentPositionParams(file_path, pos)
    return srv.sendRequest("textDocument/hover", hover_params)
end


return Hover
