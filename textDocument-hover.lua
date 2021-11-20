local Common = require('lsp-adept.common')

-- language-server-protocol/blob/gh-pages/_specifications/specification-3-16.md#textDocument_hover
local Hover = {
    range_highlight_indic = textadept.editing.INDIC_BRACEMATCH
}


function Hover.clientCapabilities()
    return { contentFormat = Common.LspAdept.allow_markdown_docs and { 'markdown', 'plaintext' } or { 'plaintext' } }
end


function Hover.show(pos, buf, show_pos)
    buf = buf or buffer
    pos = pos or buf.current_pos
    local result, err = Hover.get(pos, bus)
    if err then
        return view:call_tip_show(show_pos or pos, err.message or Common.Json.encode(err))
    elseif result and result.contents then
        if result.range and Hover.range_highlight_indic > 0 then
            local start, stop = Common.rangeLsp2Ta(buf, result.range)
            buf.indicator_current = Hover.range_highlight_indic
            buf:indicator_clear_range(1, buf.length)
            buf:indicator_fill_range(start, stop - start)
        end

        local tip = result.contents
        if type(tip) ~= 'string' then
            if #tip > 0 then -- legacy []MarkedString
                local str = ""
                for i, subtip in ipairs(tip) do
                    str = str .. "\n\n" .. (type(subtip) == 'string' and subtip or subtip.value or '')
                end
                tip = string.sub(str, 3)
            else -- MarkupContent or legacy MarkedString
                tip = tip.value or ''
            end
        end
        if #tip > 0 then
            return view:call_tip_show(show_pos or pos, tip)
        end
    end
end


function Hover.get(pos, buf)
    local srv = Common.LspAdept.keepUp(buf)
    if not (srv and srv.lang_server.caps and srv.lang_server.caps.hoverProvider) then
        return
    end
    local hover_params = Common.textDocumentPositionParams(buf, pos)
    return srv.sendRequest("textDocument/hover", hover_params)
end


function Hover.clearRangeHighlight(buf)
    buf = buf or buffer
    if Hover.range_highlight_indic > 0 then
        local indic = buf.indicator_current
        buf.indicator_current = Hover.range_highlight_indic
        buf:indicator_clear_range(1, buf.length)
        buf.indicator_current = indic
    end
end


events.connect(events.KEYPRESS, function(keycode)
    if keycode == 65307 then -- since when is ESC not 27... =)
        Hover.clearRangeHighlight()
    end
end)


return Hover
