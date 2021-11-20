local common = require('lsp-adept.common')

local Hover = {
}


Hover.clientCapabilities = function()
    return { contentFormat = common.LspAdept.allow_markdown_docs and { 'markdown', 'plaintext' } or { 'plaintext' } }
end


Hover.showHover = function()
    local srv = common.LspAdept.keepUp()
    if not srv then return end

    local hover_params = common.textDocumentPositionParams()
end


return Hover
