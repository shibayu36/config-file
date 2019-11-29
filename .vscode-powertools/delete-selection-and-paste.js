exports.execute = async args => {
  const vscode = args.require("vscode");

  const activeEditor = vscode.window.activeTextEditor;
  if (!activeEditor) {
    return;
  }

  if (!activeEditor.selection.active) {
    return;
  }

  await vscode.commands.executeCommand("deleteLeft");
  await vscode.commands.executeCommand("emacs.C-y");
};
