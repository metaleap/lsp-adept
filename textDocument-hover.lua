local common = require('lsp-adept.common')

-- language-server-protocol/blob/gh-pages/_specifications/specification-3-16.md#textDocument_hover
local Hover = {
}


Hover.clientCapabilities = function()
    return { contentFormat = common.LspAdept.allow_markdown_docs and { 'markdown', 'plaintext' } or { 'plaintext' } }
end


Hover.show = function(pos, buf, show_pos)
    buf = buf or buffer
    pos = pos or buf.current_pos
    local result, err = Hover.get(pos, bus)
    if result or err then
        return view:call_tip_show(show_pos or pos, common.json.encode(result or err))
    end
end


Hover.get = function(pos, buf)
    local srv = common.LspAdept.keepUp(buf)
    if not (srv and srv.lang_server.caps and srv.lang_server.caps.hoverProvider) then
        return
    end
    local hover_params = common.textDocumentPositionParams(buf, pos)
    local result, err = srv.sendRequest("textDocument/hover", hover_params)
    if result and result.range then

    end
    return result, err
end


return Hover
