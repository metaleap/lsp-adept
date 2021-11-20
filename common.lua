
local Common = {
    json = require('lsp-adept.deps.dkjson'),
    LspAdept = nil, -- ./init.lua sets this, all ./*.lua get to use it
}
Common.json.empty = Common.json.decode('{}') -- plain lua {}s would mal-encode into json []s


function Common.bufferFrom(file_path)
    if buffer.filename == file_path then return buffer end
    for i, buf in ipairs(_BUFFERS) do
        if buf.filename == file_path then
            return buf
        end
    end
end


-- language-server-protocol/blob/gh-pages/_specifications/specification-3-16.md#-position-
function Common.posTa2posLsp(buf, pos)
    buf = buf or buffer
    pos = pos or buf.current_pos
    local line = buf.line_from_position(pos)
    local linestr = string.sub(buf:get_line(line), 1, pos - buf.position_from_line(line))
    return { line = line - 1, character = #linestr }
end


-- language-server-protocol/blob/gh-pages/_specifications/specification-3-16.md#-position-
function Common.posLsp2posTa(buf, pos)

end


-- language-server-protocol/blob/gh-pages/_specifications/specification-3-16.md#-range-
function Common.rangeLspToTa(range)

end


-- language-server-protocol/blob/gh-pages/_specifications/specification-3-16.md#textDocumentPositionParams
function Common.textDocumentPositionParams(buf, pos)
    return {
        textDocument = { uri = (buf or buffer).filename },
        position = Common.posTa2posLsp(buf, pos)
    }
end


return Common
