local Common = require('lsp-adept.common')

-- language-server-protocol/blob/gh-pages/_specifications/specification-3-16.md#textDocument_hover
local Hover = {
    range_highlight_indic = textadept.editing.INDIC_BRACEMATCH
}


Hover.clientCapabilities = function()
    return { contentFormat = Common.LspAdept.allow_markdown_docs and { 'markdown', 'plaintext' } or { 'plaintext' } }
end


Hover.show = function(pos, buf, show_pos)
    buf = buf or buffer
    pos = pos or buf.current_pos
    local result, err = Hover.get(pos, bus)
    if result or err then
        if result.range and Hover.range_highlight_indic > 0 then
            local start, stop = Common.rangeLsp2Ta(buf, result.range)
            buf.indicator_current = Hover.range_highlight_indic
            buf:indicator_clear_range(1, buf.length)
            buf:indicator_fill_range(start, stop - start)
        end
        return view:call_tip_show(show_pos or pos, Common.Json.encode(result or err))
    end
end


Hover.get = function(pos, buf)
    local srv = Common.LspAdept.keepUp(buf)
    if not (srv and srv.lang_server.caps and srv.lang_server.caps.hoverProvider) then
        return
    end
    local hover_params = Common.textDocumentPositionParams(buf, pos)
    local result, err = srv.sendRequest("textDocument/hover", hover_params)
    return result, err
end


return Hover
