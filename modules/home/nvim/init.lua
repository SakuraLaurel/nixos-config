assert(vim.fn.has('nvim-0.12') == 1, 'This configuration requires Neovim 0.12+')

local is_nixos = vim.fn.filereadable('/etc/NIXOS') == 1

vim.g.mapleader = ' '

for name, value in pairs({
    number = true,
    cursorline = true,
    signcolumn = 'yes',
    scrolloff = 10,
    list = true,
    listchars = 'tab:» ,trail:·,nbsp:␣',
    breakindent = true,
    expandtab = true,
    tabstop = 4,
    shiftwidth = 0,
    ignorecase = true,
    smartcase = true,
    inccommand = 'split',
    splitright = true,
    splitbelow = true,
    undofile = true,
    updatetime = 250,
    confirm = true,
    winborder = 'rounded',
    wrap = true,
    smoothscroll = true,
    background = 'light',
}) do
    vim.o[name] = value
end
vim.schedule(function() vim.o.clipboard = 'unnamedplus' end)

local function build_codediff(path)
    for _, argv in ipairs({
        { 'cmake', '-S',      '.',     '-B',       'build',       '-DCMAKE_BUILD_TYPE=Release' },
        { 'cmake', '--build', 'build', '--target', 'vscode_diff', '--parallel',                '2' },
    }) do
        local result = vim.system(argv, { cwd = path, text = true }):wait()
        assert(result.code == 0, 'CodeDiff build failed:\n' .. (result.stderr or '') .. (result.stdout or ''))
    end
    -- 加载器优先选带版本号的旧库，清掉它才会加载本地编译的版本。
    for _, library in ipairs(vim.fn.glob(path .. '/libvscode_diff_*.so', false, true)) do
        assert(vim.uv.fs_unlink(library))
    end
end

-- 钩子要早于 vim.pack.add 注册，才能处理首次安装。
vim.api.nvim_create_autocmd('PackChanged', {
    callback = function(ev)
        local data = ev.data
        if data.kind ~= 'install' and data.kind ~= 'update' then return end
        if data.spec.name == 'nvim-treesitter' then
            if not data.active then vim.cmd.packadd('nvim-treesitter') end
            vim.cmd('TSUpdate')
        elseif data.spec.name == 'codediff.nvim' and is_nixos then
            build_codediff(data.path)
        end
    end,
})

local gh = function(repo) return 'https://github.com/' .. repo end
local cb = function(repo) return 'https://codeberg.org/' .. repo end

vim.pack.add({
    { src = gh('rose-pine/neovim'),                name = 'rose-pine' },
    { src = gh('nvim-treesitter/nvim-treesitter'), version = 'main' },
    gh('neovim/nvim-lspconfig'),
    -- v1 支持下面使用的 Lua 匹配器。
    { src = gh('saghen/blink.cmp'),      version = vim.version.range('1') },
    gh('ibhagwan/fzf-lua'),
    gh('nvim-mini/mini.icons'),
    gh('stevearc/conform.nvim'),
    gh('stevearc/oil.nvim'),
    gh('lewis6991/gitsigns.nvim'),
    gh('esmuellert/codediff.nvim'),
    gh('MeanderingProgrammer/render-markdown.nvim'),
    gh('gaoDean/autolist.nvim'),
    gh('windwp/nvim-autopairs'),
    -- nvim-dap-view 依赖 nvim-dap 主分支的 listeners.on_session。
    cb('mfussenegger/nvim-dap'),
    cb('mfussenegger/nvim-dap-python'),
    { src = gh('igorlfs/nvim-dap-view'), version = vim.version.range('1') },
})
vim.cmd.packadd('nvim.undotree')

-- 迁移已有插件时不会触发 PackChanged，需补建本地库。
if is_nixos then
    for _, plugin in ipairs(vim.pack.get({ 'codediff.nvim' })) do
        local ready = vim.fn.filereadable(plugin.path .. '/CMakeLists.txt') == 1
        local built = vim.fn.filereadable(plugin.path .. '/libvscode_diff.so') == 1
        if ready and not built then build_codediff(plugin.path) end
    end
end

vim.cmd.colorscheme('rose-pine-dawn')

for _, plugin in ipairs({
    'mini.icons', 'oil', 'gitsigns', 'nvim-autopairs', 'autolist',
}) do
    require(plugin).setup()
end

-- 这三种嵌入格式需要额外解析器，LaTeX 还需要转换工具。
require('render-markdown').setup({
    html = { enabled = false },
    latex = { enabled = false },
    yaml = { enabled = false },
})

vim.api.nvim_create_autocmd('FileType', {
    pattern = { 'markdown', 'text', 'tex', 'plaintex', 'norg' },
    callback = function(ev)
        vim.keymap.set('i', '<CR>', '<CR><cmd>AutolistNewBullet<cr>', { buffer = ev.buf, desc = 'Continue list' })
    end,
})
require('blink.cmp').setup({
    fuzzy = { implementation = 'lua' },
    enabled = function()
        return vim.bo.filetype ~= 'markdown'
    end,
    signature = { enabled = true },
})
require('fzf-lua').register_ui_select()
require('dap-view').setup({ auto_toggle = true, virtual_text = { enabled = true } })
require('conform').setup({
    default_format_opts = { lsp_format = 'fallback' },
    -- C++ 保留手动格式化。
    format_on_save = function(buf)
        if vim.bo[buf].filetype ~= 'cpp' then return {} end
    end,
    formatters_by_ft = {
        c = { 'clang_format' },
        cpp = { 'clang_format' },
        python = { 'ruff_organize_imports', 'ruff_format' },
        json = { 'biome' },
        jsonc = { 'biome' },
        toml = { 'tombi' },
        markdown = { 'rumdl' },
    },
})

require('nvim-treesitter').install({
    'python', 'c', 'cpp', 'lua', 'luadoc', 'vim', 'vimdoc', 'query',
    'json', 'json5', 'toml', 'markdown', 'markdown_inline',
})
vim.treesitter.language.register('json5', { 'jsonc', 'json5' })
vim.api.nvim_create_autocmd('FileType', {
    callback = function(ev)
        local lang = vim.treesitter.language.get_lang(ev.match)
        -- 首次安装解析器是异步的，加载成功后才能启动高亮。
        if lang and vim.treesitter.language.add(lang) then vim.treesitter.start(ev.buf, lang) end
    end,
})

vim.lsp.config('*', { capabilities = require('blink.cmp').get_lsp_capabilities() })
vim.lsp.config('lua_ls', {
    settings = {
        Lua = {
            runtime = { version = 'LuaJIT' },
            workspace = { library = { vim.env.VIMRUNTIME } },
        },
    },
})
vim.lsp.enable({ 'ty', 'ruff', 'clangd', 'lua_ls', 'jsonls', 'tombi', 'rumdl' })
vim.diagnostic.config({ severity_sort = true, virtual_text = true, float = { source = 'if_many' } })

local dap = require('dap')
require('dap-python').setup(vim.fn.executable('debugpy-adapter') == 1 and 'debugpy-adapter' or 'uv')
if vim.fn.has('mac') == 1 then
    dap.adapters.native = vim.fn.executable('lldb-dap') == 1
        and { type = 'executable', command = 'lldb-dap' }
        or { type = 'executable', command = 'xcrun', args = { 'lldb-dap' } }
else
    dap.adapters.native = {
        type = 'executable',
        command = 'gdb',
        args = { '--interpreter=dap', '--eval-command', 'set print pretty on' },
    }
end
dap.configurations.cpp = {
    {
        name = 'Launch',
        type = 'native',
        request = 'launch',
        cwd = '${workspaceFolder}',
        program = function() return vim.fn.input('Executable: ', vim.fn.getcwd() .. '/', 'file') end,
    },
}
dap.configurations.c = dap.configurations.cpp

vim.api.nvim_create_autocmd('TextYankPost', { callback = function() vim.hl.on_yank() end })

local fzf, gs = require('fzf-lua'), require('gitsigns')
local function map(mode, lhs, rhs, description)
    vim.keymap.set(mode, lhs, rhs, { desc = description })
end

map('n', '<Esc>', '<Cmd>nohlsearch<CR>', 'Clear search highlight')
map('t', '<Esc><Esc>', '<C-\\><C-n>', 'Exit terminal mode')
map('n', '<C-h>', '<C-w><C-h>', 'Focus left window')
map('n', '<C-l>', '<C-w><C-l>', 'Focus right window')
map('n', '<C-j>', '<C-w><C-j>', 'Focus lower window')
map('n', '<C-k>', '<C-w><C-k>', 'Focus upper window')
map('n', '-', '<Cmd>Oil<CR>', 'Open parent directory')
map('n', '<leader>u', '<Cmd>Undotree<CR>', 'Undotree')
map('n', '<leader>q', vim.diagnostic.setloclist, 'Diagnostic list')
map('', '<leader>f', function() require('conform').format({ async = true }) end, 'Format buffer')
map('n', '<leader>th', function()
    local hints = vim.lsp.inlay_hint
    hints.enable(not hints.is_enabled())
end, 'Toggle inlay hints')
map('n', '<leader>tb', gs.toggle_current_line_blame, 'Toggle line blame')

map('n', '<leader>sh', fzf.helptags, 'Search help')
map('n', '<leader>sk', fzf.keymaps, 'Search keymaps')
map('n', '<leader>sf', fzf.files, 'Search files')
map('n', '<leader>ss', fzf.builtin, 'Search pickers')
map('n', '<leader>sw', fzf.grep_cword, 'Search word')
map('x', '<leader>sw', fzf.grep_visual, 'Search selection')
map('n', '<leader>sg', fzf.live_grep, 'Search by grep')
map('n', '<leader>sd', fzf.diagnostics_workspace, 'Search diagnostics')
map('n', '<leader>sr', fzf.resume, 'Search resume')
map('n', '<leader>s.', fzf.oldfiles, 'Search recent files')
map('n', '<leader>s/', fzf.lines, 'Search open buffers')
map('n', '<leader>sn', function() fzf.files({ cwd = vim.fn.stdpath('config') }) end, 'Search Neovim config')
map('n', '<leader>/', fzf.blines, 'Search current buffer')
map('n', '<leader><leader>', fzf.buffers, 'Find buffers')

map('n', 'grr', fzf.lsp_references, 'References')
map('n', 'gri', fzf.lsp_implementations, 'Implementations')
map('n', 'grd', fzf.lsp_definitions, 'Definitions')
map('n', 'grD', fzf.lsp_declarations, 'Declarations')
map('n', 'grt', fzf.lsp_typedefs, 'Type definitions')
map('n', 'gO', fzf.lsp_document_symbols, 'Document symbols')
map('n', 'gW', fzf.lsp_live_workspace_symbols, 'Workspace symbols')

map('n', ']c', function() gs.nav_hunk('next') end, 'Next hunk')
map('n', '[c', function() gs.nav_hunk('prev') end, 'Prev hunk')
map('n', '<leader>gb', function() gs.blame_line({ full = true }) end, 'Git blame line')
map('n', '<leader>gd', '<Cmd>CodeDiff<CR>', 'Git changes')
map('n', '<leader>gf', '<Cmd>CodeDiff file HEAD<CR>', 'Git diff file vs HEAD')
map('n', '<leader>gh', '<Cmd>CodeDiff history<CR>', 'Git history')
map('x', '<leader>gh', ':CodeDiff history<cr>', 'Git history of selection')

map('n', '<leader>dc', dap.continue, 'Debug: start/continue')
map('n', '<leader>db', dap.toggle_breakpoint, 'Debug: toggle breakpoint')
map('n', '<leader>dB', function()
    dap.set_breakpoint(vim.fn.input('Condition: '))
end, 'Debug: conditional breakpoint')
map('n', '<leader>di', dap.step_into, 'Debug: step into')
map('n', '<leader>do', dap.step_over, 'Debug: step over')
map('n', '<leader>dO', dap.step_out, 'Debug: step out')
map('n', '<leader>dr', dap.run_last, 'Debug: run last')
map('n', '<leader>dq', dap.terminate, 'Debug: terminate')
map('n', '<leader>dv', '<Cmd>DapViewToggle<CR>', 'Debug: toggle view')
map('n', '<leader>dw', '<Cmd>DapViewWatch<CR>', 'Debug: watch expression')
