// base から head への差分を、ファイルごとに行の列にする。
// 行番号付きdiffの表示（numbered-diff.mjs）、範囲の展開（expand-guide.mjs）、描画（render-html.mjs）が同じ行番号を使うよう、ここで1つに作る。
// 対象リポジトリのディレクトリで呼ぶ。
import { execFileSync } from "node:child_process";

const git = (args) => execFileSync("git", args, { encoding: "utf8", maxBuffer: 64 * 1024 * 1024, stdio: ["ignore", "pipe", "ignore"] });

// base から head で変わったファイルを、差分の出る順に返す。binary はテキストの行を持たないファイル。
// 名前の変更は、元のパスの削除と新しいパスの追加として返す。diffRows がパスごとに差分を取るため。
export function changedFiles(base, head, paths = []) {
  const out = git(["diff", "--no-color", "--no-ext-diff", "--no-renames", "--numstat", "-z", base, head, "--", ...paths]);
  return out.split("\0").filter((s) => s !== "").map((entry) => {
    const [added, deleted, file] = entry.split("\t");
    return { file, binary: added === "-" && deleted === "-" };
  });
}

// base から head への file のファイル全体の diff を、行の配列で返す。
// 各行は { type: "ctx" | "add" | "del", code, oldNo?, newNo? }。oldNo は base、newNo は head の行番号で、
// "add" は newNo だけ、"del" は oldNo だけ、"ctx" は両方を持つ。code は行末の空白を除いた中身。
// 差分が無いファイル・バイナリのファイル・git が失敗した時は空の配列を返す。
export function diffRows(base, head, file) {
  let out;
  try {
    out = git(["diff", "--no-color", "--no-ext-diff", "-U1000000", base, head, "--", file]);
  } catch {
    return [];
  }
  const rows = [];
  let inHunk = false;
  let oldNo = 0;
  let newNo = 0;
  for (const line of out.split("\n")) {
    const h = line.match(/^@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@/);
    if (h) {
      inHunk = true;
      oldNo = Number(h[1]);
      newNo = Number(h[2]);
      continue;
    }
    if (!inHunk || line === "" || line[0] === "\\") continue;
    const code = line.slice(1).trimEnd();
    if (line[0] === "+") rows.push({ type: "add", code, newNo: newNo++ });
    else if (line[0] === "-") rows.push({ type: "del", code, oldNo: oldNo++ });
    else rows.push({ type: "ctx", code, oldNo: oldNo++, newNo: newNo++ });
  }
  return rows;
}
