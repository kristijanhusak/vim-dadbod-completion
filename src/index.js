const { sources, workspace } = require('coc.nvim');
const { nvim } = workspace;
const path = require('path');
const rtpPath = path.resolve(__dirname, '../');


exports.activate = async (context) => {
  await nvim.command(`source ${rtpPath}/plugin/vim_dadbod_completion.vim`);
  await nvim.command(`source ${rtpPath}/autoload/vim_dadbod_completion.vim`);
  await nvim.command(`source ${rtpPath}/autoload/vim_dadbod_completion/schemas.vim`);
  await nvim.command(`source ${rtpPath}/autoload/vim_dadbod_completion/alias_parser.vim`);
  await nvim.command(`source ${rtpPath}/autoload/vim_dadbod_completion/job.vim`);
  await nvim.command(`source ${rtpPath}/autoload/vim_dadbod_completion/utils.vim`);

  const currentDoc = await workspace.document;
  if (currentDoc.filetype === 'sql') {
    nvim.call('vim_dadbod_completion#fetch', [currentDoc.bufnr]);
  }

  workspace.onDidOpenTextDocument(e => {
    const doc = workspace.getDocument(e.uri);
    if (doc.filetype === 'sql') {
      return nvim.call('vim_dadbod_completion#fetch', [doc.bufnr]);
    }
  });

  const source = {
    name: 'db',
    doComplete: async function (opt) {
      const { input, triggerCharacter } = opt;
      const isTriggerCharacter = this.getConfig('triggerCharacters').includes(triggerCharacter);
      let base = isTriggerCharacter ? '' : input;
      const items = await nvim.call('vim_dadbod_completion#omni', [0, base]);

      return { items };
    },
  };

  context.subscriptions.push(sources.createSource(source));
};
