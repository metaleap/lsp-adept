
local Common = {
    json = require('lsp-adept.deps.dkjson'),
    LspAdept = nil, -- ./init.lua sets this, all ./*.lua get to use it
}
Common.json.empty = Common.json.decode('{}') -- plain lua {}s would mal-encode into json []s


-- language-server-protocol/blob/gh-pages/_specifications/specification-3-16.md#-position-
function Common.posTa2posLsp(pos)
    pos = pos or buffer.current_pos
    local line = buffer.line_from_position(pos)
    local linestr = string.sub(buffer:get_line(line), 1, pos - buffer.position_from_line(line))
    return { line = line - 1, character = #linestr }
end


-- language-server-protocol/blob/gh-pages/_specifications/specification-3-16.md#textDocumentPositionParams
function Common.textDocumentPositionParams(file_path, pos)
    return {
        textDocument = { uri = file_path or buffer.filename },
        position = Common.posTa2posLsp(pos)
    }
end


return Common
