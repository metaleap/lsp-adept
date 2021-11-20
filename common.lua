local json = require('lsp-adept.deps.dkjson')

local Common = {
    LspAdept = nil, -- ./init.lua sets this
    json_empty = json.decode('{}') -- plain lua {}s would mal-encode into json []s
}


function Common.posTa2posLsp(pos)
    -- github.com/microsoft/language-server-protocol/blob/gh-pages/_specifications/specification-3-16.md#-position-
    pos = pos or buffer.current_pos
    local line = buffer.line_from_position(pos)
    local linestr = string.sub(buffer:get_line(line), 1, pos - buffer.position_from_line(line))
    return { line = line - 1, character = string.len(linestr) }
end


function Common.posLsp2posTa(pos)
end


function Common.textDocumentPositionParams(file_path, pos)
    return {
        textDocument = { uri = file_path or buffer.filename },
        position = Common.posTa2posLsp(pos)
    }
end


return Common
