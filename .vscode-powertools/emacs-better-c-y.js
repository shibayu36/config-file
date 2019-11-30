exports.execute = async args => {
  const vscode = args.require("vscode");

  await vscode.commands.executeCommand("editor.action.clipboardPasteAction");
  await vscode.commands.executeCommand("emacs.exitMarkMode");
};
