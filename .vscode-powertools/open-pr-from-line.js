/**
 * A script to open an associated PullRequest from line for vscode powertools.
 * This requires
 *   - Install GitLens
 *   - Place open-pr-from-commit script to your PATH.  See also https://github.com/shibayu36/config-file/blob/master/bin/open-pr-from-commit
 */
exports.execute = async args => {
  const vscode = args.require("vscode");

  await vscode.commands.executeCommand("gitlens.copyShaToClipboard");
  const sha1 = await vscode.env.clipboard.readText();

  const cp = require('child_process')
  cp.execFileSync('open-pr-from-commit', [sha1], { cwd: vscode.workspace.workspaceFolders[0].uri.path });
};
