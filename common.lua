local json = require('lsp-adept.deps.dkjson')

local Common = {
    LspAdept = nil, -- ./init.lua sets this
    json_empty = json.decode('{}') -- plain lua {}s would mal-encode into json []s
}


function Common.taPos2lspPos(pos)
    pos = pos or buffer.current_pos
    local line = buffer.line_from_position(pos)
    return {
        line = line - 1
    }
end


function Common.textDocumentPositionParams(file_path, pos)
    return {
        textDocument = { uri = file_path or buffer.filename },
        position = Common.taPos2lspPos(pos)
    }
end


return Common
