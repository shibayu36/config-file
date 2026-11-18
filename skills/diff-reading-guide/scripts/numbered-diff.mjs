#!/usr/bin/env node
// base から head への diff を、各行に base の行番号 b… と head の行番号 h… を付けて出す。
// guide.json の range に書く行番号は、この出力から読む。
// 使い方: 対象リポジトリのディレクトリで `node numbered-diff.mjs <base> <head>`
//
// 出力の例:
//   === src/paths.ts
//   ...
//   b12 h12   attachmentId: string;
//   b15     -   key: old,
//       h15 +   key: new,
//   b16 h16 }
// "-" の行は b だけ、"+" の行は h だけ、変更の無い行は両方を持つ。変更の前後 CONTEXT 行だけを出し、省いた所に "..." を置く。
import { changedFiles, diffRows } from "./diff-rows.mjs";

const CONTEXT = 3;
const SIGN = { ctx: " ", add: "+", del: "-" };

// 変更の行から前後 CONTEXT 行以内にある行の位置を、昇順で返す。
function shownIndexes(rows) {
  const shown = new Set();
  rows.forEach((r, i) => {
    if (r.type === "ctx") return;
    for (let k = Math.max(0, i - CONTEXT); k <= Math.min(rows.length - 1, i + CONTEXT); k++) shown.add(k);
  });
  return [...shown].sort((a, b) => a - b);
}

function formatFile(rows) {
  const b = (r) => (r.oldNo === undefined ? "" : `b${r.oldNo}`);
  const h = (r) => (r.newNo === undefined ? "" : `h${r.newNo}`);
  const shown = shownIndexes(rows);
  const wb = shown.reduce((w, i) => Math.max(w, b(rows[i]).length), 0);
  const wh = shown.reduce((w, i) => Math.max(w, h(rows[i]).length), 0);
  const out = [];
  let prev = -1;
  for (const i of shown) {
    if (i !== prev + 1) out.push("...");
    const r = rows[i];
    out.push(`${b(r).padEnd(wb)} ${h(r).padEnd(wh)} ${SIGN[r.type]}${r.code}`);
    prev = i;
  }
  if (prev !== rows.length - 1) out.push("...");
  return out;
}

const [base, head] = process.argv.slice(2);
if (!base || !head) {
  console.error("usage: node numbered-diff.mjs <base> <head>");
  process.exit(2);
}
let files;
try {
  files = changedFiles(base, head);
} catch {
  console.error(`git diff ${base} ${head} に失敗した。commit がリポジトリにあるか確かめる`);
  process.exit(1);
}
const out = [];
for (const { file, binary } of files) {
  if (binary) {
    out.push(`=== ${file}（バイナリのため行を出さない）`);
    continue;
  }
  const rows = diffRows(base, head, file);
  if (rows.length === 0) {
    out.push(`=== ${file}（行の変更なし）`);
    continue;
  }
  out.push(`=== ${file}`, ...formatFile(rows));
}
console.log(out.join("\n"));
