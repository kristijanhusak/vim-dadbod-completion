from .base import Base


class Source(Base):
    def __init__(self, vim):
        Base.__init__(self, vim)
        self.name = 'vim-dadbod-completion'
        self.mark = ''
        self.filetypes = ['sql', 'mysql', 'plsql']
        self.input_pattern = '\w+|\.|"|\[|`'
        self.rank = 500
        self.max_pattern_length = -1
        self.matchers = ['matcher_full_fuzzy']

    def get_complete_position(self, context):
        return self.vim.call('vim_dadbod_completion#omni', 1, '')

    def gather_candidates(self, context):
        items = self.vim.call('vim_dadbod_completion#omni', 0,
                             context['complete_str'])
        context['is_async'] = self.vim.call('vim_dadbod_completion#refresh_deoplete')

        return items
