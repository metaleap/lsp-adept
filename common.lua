
local Common = {
    Json = require('lsp-adept.deps.dkjson'),
    LspAdept = nil, -- ./init.lua sets this, all ./*.lua get to use it
}
Common.Json.empty = Common.Json.decode('{}') -- plain lua {}s would mal-encode into json []s


function Common.bufferFrom(file_path)
    if buffer.filename == file_path then return buffer end
    for i, buf in ipairs(_BUFFERS) do
        if buf.filename == file_path then
            return buf
        end
    end
end


-- language-server-protocol/blob/gh-pages/_specifications/specification-3-16.md#-position-
function Common.posTa2posLsp(buf, ta_pos)
    buf = buf or buffer
    ta_pos = ta_pos or buf.current_pos
    local line = buf.line_from_position(ta_pos)
    local linestr = string.sub(buf:get_line(line), 1, ta_pos - buf.position_from_line(line))
    return { line = line - 1, character = #linestr }
end


-- language-server-protocol/blob/gh-pages/_specifications/specification-3-16.md#-position-
function Common.posLsp2posTa(buf, lsp_pos, use_utf8len)
    buf = buf or buffer
    local line = lsp_pos.line + 1
    local linepos = buf:position_from_line(line)
    if lsp_pos.character == 0 then return linepos end
    local linestr = string.sub(buf:get_line(line), 1, lsp_pos.character)
    return linepos + (use_utf8len and utf8.len(linestr) or string.len(linestr))
end


-- language-server-protocol/blob/gh-pages/_specifications/specification-3-16.md#-range-
function Common.rangeLsp2Ta(buf, range, use_utf8len, never_swap)
    local start, stop = Common.posLsp2posTa(buf, range.start, use_utf8len), Common.posLsp2posTa(buf, range['end'], use_utf8len)
    if stop < start and not never_swap then
        start, stop = stop, start
    end
    return start, stop
end


function Common.shush(str)
    local silent_print = ui.silent_print
    ui.silent_print = true
    ui._print('[LSP]', str)
    ui.silent_print = silent_print
end


-- language-server-protocol/blob/gh-pages/_specifications/specification-3-16.md#textDocumentPositionParams
function Common.textDocumentPositionParams(buf, pos)
    return {
        textDocument = { uri = (buf or buffer).filename },
        position = Common.posTa2posLsp(buf, pos)
    }
end


return Common
