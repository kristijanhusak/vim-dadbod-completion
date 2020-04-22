const { sources, workspace } = require('coc.nvim');
const { nvim } = workspace;
const path = require('path');

exports.activate = async (context) => {
  const paths = await nvim.runtimePaths;
  const rtpPath = path.resolve(__dirname, '../');
  if (!paths.includes(rtpPath)) {
    await nvim.command(`set rtp+=${rtpPath}`)
  }

  workspace.onDidOpenTextDocument(e => {
    const doc = workspace.getDocument(e.uri);
    if (doc.filetype === 'sql') {
      return nvim.call('vim_dadbod_completion#fetch', [doc.bufnr])
    }
  });

  const source = {
    name: 'db',
    doComplete: async function (opt) {
      const { input, triggerCharacter } = opt;
      const isTriggerCharacter = this.getConfig('triggerCharacters').includes(triggerCharacter);
      let base = isTriggerCharacter ? '' : input
      const items = await nvim.call('vim_dadbod_completion#omni', [0, base])

      return { items };
    },
  };

  context.subscriptions.push(sources.createSource(source));
};
