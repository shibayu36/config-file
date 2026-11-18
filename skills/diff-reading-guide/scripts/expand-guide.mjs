#!/usr/bin/env node
// guide.json のうち range を持つブロックを、range が指す行を写した lines のブロックに書き換える。
// lines のブロックには触れないので、何度走らせてもよい。
// 範囲に誤りがあれば、ファイルを書き換えずにエラーで止まる。
// 使い方: 対象リポジトリのディレクトリで `node expand-guide.mjs <guide.json>`
//
// range の要素は、出したい順に並べた次のどれか。
//   "@@ <文>"           区切りの行。そのまま行になる（diff だけ）
//   "<端>-<端>"          端は b<baseの行番号> か h<headの行番号>。両端の間の行をすべて含む
//   { "note": "<注釈>" } 独立した注釈の行。次の行（無ければ前の行）の字下げに揃える
// lineNotes は { "<端>": "<注釈>" } で、その行の末尾に空白1つを挟んで注釈を付ける。
//
// diff の端は numbered-diff.mjs の出す行番号で、範囲は diff の行の並びで数える。
// code と beforeAfter の端は base / head のファイルの行番号。code は b と h のどちらかにそろえ、そこから ref を付ける。
// beforeAfter は before を b、after を h で書く。
import { readFileSync, writeFileSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { diffRows } from "./diff-rows.mjs";

const RANGE = /^([bh])(\d+)-([bh])(\d+)$/;
const END = /^([bh])(\d+)$/;
const SIGN = { ctx: " ", add: "+", del: "-" };
const REF_OF = { b: "base", h: "head" };

const indentOf = (code) => code.match(/^\s*/)[0];
const isNote = (item) => item && typeof item === "object" && typeof item.note === "string" && item.note !== "" && Object.keys(item).length === 1;

// commit の file を、行末の空白を除いた行の配列で返す。ファイルが無ければ null。
function fileLines(commit, file) {
  let content;
  try {
    content = execFileSync("git", ["show", `${commit}:${file}`], { encoding: "utf8", maxBuffer: 64 * 1024 * 1024, stdio: ["ignore", "pipe", "ignore"] });
  } catch {
    return null;
  }
  const lines = content.split("\n");
  if (lines[lines.length - 1] === "") lines.pop();
  return lines.map((l) => l.trimEnd());
}

// diff の行の列を、展開に使う形にする。変更の無い行は b と h のどちらでも引ける。
function diffSource(rows, file) {
  const byB = new Map();
  const byH = new Map();
  rows.forEach((r, i) => {
    if (r.oldNo !== undefined) byB.set(r.oldNo, i);
    if (r.newNo !== undefined) byH.set(r.newNo, i);
  });
  return {
    rows: rows.map((r) => ({ sign: SIGN[r.type], code: r.code })),
    find: (letter, no) => (letter === "b" ? byB : byH).get(no),
    where: `${file} の diff`,
    allowHunk: true,
    notePrefix: " ",
  };
}

// ファイルの行を、展開に使う形にする。letter の端だけを引ける。
function fileSource(lines, letter, commit, file) {
  return {
    rows: lines.map((code) => ({ sign: "", code })),
    find: (l, no) => (l === letter && no >= 1 && no <= lines.length ? no - 1 : undefined),
    where: `${REF_OF[letter]}（${commit}）の ${file}`,
    allowHunk: false,
    notePrefix: "",
  };
}

// range と lineNotes に出てくる端の b / h を集める。
function lettersOf(f) {
  const letters = new Set();
  for (const item of Array.isArray(f.range) ? f.range : []) {
    const m = typeof item === "string" && item.match(RANGE);
    if (m) letters.add(m[1]).add(m[3]);
  }
  for (const key of Object.keys(f.lineNotes ?? {})) {
    const m = key.match(END);
    if (m) letters.add(m[1]);
  }
  return letters;
}

// f の range と lineNotes を lines にする。誤りがあれば errors に足して null を返す。
function expandRange(f, at, src, errors) {
  const err = (where, msg) => errors.push(`${at}${where}: ${msg}`);
  const errorsBefore = errors.length;
  const items = [];
  f.range.forEach((item, i) => {
    if (src.allowHunk && typeof item === "string" && item.startsWith("@@")) return items.push({ hunk: item });
    if (isNote(item)) return items.push({ note: item.note });
    const m = typeof item === "string" && item.match(RANGE);
    if (!m) {
      const forms = src.allowHunk ? `"@@ <文>"・"<端>-<端>"（例: "h40-b52"）・{ "note": "…" }` : `"<端>-<端>"（例: "h40-h52"）・{ "note": "…" }`;
      return err(`.range[${i}]`, `${forms} のどれか: ${JSON.stringify(item)}`);
    }
    const from = src.find(m[1], Number(m[2]));
    const to = src.find(m[3], Number(m[4]));
    const missing = new Set();
    if (from === undefined) missing.add(`${m[1]}${m[2]}`);
    if (to === undefined) missing.add(`${m[3]}${m[4]}`);
    if (missing.size > 0) return err(`.range[${i}]`, `${[...missing].join("・")} は ${src.where} に無い`);
    if (from > to) return err(`.range[${i}]`, `${item} は逆向き（後ろの行が先に来ている）`);
    for (let k = from; k <= to; k++) items.push({ row: k });
  });

  const notes = new Map();
  const included = new Set(items.filter((x) => x.row !== undefined).map((x) => x.row));
  for (const [key, note] of Object.entries(f.lineNotes ?? {})) {
    const m = key.match(END);
    if (!m) { err(".lineNotes", `キーは b<行番号> か h<行番号>: ${JSON.stringify(key)}`); continue; }
    if (typeof note !== "string" || note === "") { err(`.lineNotes.${key}`, "注釈の文字列が必要"); continue; }
    const k = src.find(m[1], Number(m[2]));
    if (k === undefined || !included.has(k)) { err(`.lineNotes.${key}`, "range に含まれない行を指している"); continue; }
    notes.set(k, note);
  }
  if (errors.length > errorsBefore) return null;

  const rowItems = items.map((x, i) => (x.row !== undefined ? i : -1)).filter((i) => i >= 0);
  const nearRow = (i) => {
    const j = rowItems.find((k) => k > i) ?? rowItems.findLast((k) => k < i);
    return j === undefined ? null : src.rows[items[j].row];
  };
  return items.map((x, i) => {
    if (x.hunk !== undefined) return x.hunk;
    if (x.note !== undefined) {
      const near = nearRow(i);
      return `${src.notePrefix}${near ? indentOf(near.code) : ""}${x.note}`;
    }
    const r = src.rows[x.row];
    const note = notes.get(x.row);
    return `${r.sign}${r.code}${note ? ` ${note}` : ""}`;
  });
}

// range を lines に置き換えた新しいオブジェクトを返す。キーの並びは保ち、range の位置に lines を置く。
// extra（code の ref）は、元に無ければ lines の前に置く。
function replaceRange(f, lines, extra = {}) {
  const out = {};
  for (const [k, v] of Object.entries(f)) {
    if (k === "range") {
      for (const [ek, ev] of Object.entries(extra)) if (!(ek in f)) out[ek] = ev;
      out.lines = lines;
    } else if (k !== "lineNotes") out[k] = k in extra ? extra[k] : v;
  }
  return out;
}

function expandGuide(guide, rowsOf, linesOf) {
  const errors = [];
  let expanded = 0;

  // range を書いたオブジェクトの共通の形を確かめる。問題が無ければ true。
  const checkShape = (f, at) => {
    if (f.lines !== undefined) { errors.push(`${at}: lines と range は一緒に書けない`); return false; }
    if (typeof f.file !== "string" || f.file === "") { errors.push(`${at}.file: リポジトリからのパスが必要`); return false; }
    if (!Array.isArray(f.range) || f.range.length === 0) { errors.push(`${at}.range: 1つ以上の要素の配列が必要`); return false; }
    return true;
  };

  // code と beforeAfter の片側を展開する。letter は使う端（b / h）。
  const expandFile = (f, at, letter) => {
    const commit = letter === "b" ? guide.base : guide.head;
    const lines = linesOf(commit, f.file);
    if (lines === null) { errors.push(`${at}.file: ${REF_OF[letter]}（${commit}）に ${f.file} が無い`); return null; }
    return expandRange(f, at, fileSource(lines, letter, commit, f.file), errors);
  };

  const expandBlock = (block, at) => {
    if (block.kind === "beforeAfter") {
      let changed = false;
      const sides = {};
      for (const [side, letter] of [["before", "b"], ["after", "h"]]) {
        if (!Array.isArray(block[side])) continue;
        sides[side] = block[side].map((f, i) => {
          const fat = `${at}.${side}[${i}]`;
          if (!f || typeof f !== "object" || f.range === undefined) {
            if (f?.lineNotes !== undefined) errors.push(`${fat}.lineNotes: range と一緒に書く`);
            return f;
          }
          if (!checkShape(f, fat)) return f;
          const wrong = [...lettersOf(f)].filter((l) => l !== letter);
          if (wrong.length > 0) { errors.push(`${fat}: ${side} の端は ${letter} で書く`); return f; }
          const lines = expandFile(f, fat, letter);
          if (lines === null) return f;
          changed = true;
          return replaceRange(f, lines);
        });
      }
      return changed ? { ...block, ...sides } : block;
    }
    if (block.range === undefined) {
      if (block.lineNotes !== undefined) errors.push(`${at}.lineNotes: range と一緒に書く`);
      return block;
    }
    if (!checkShape(block, at)) return block;
    if (block.kind === "diff") {
      const lines = expandRange(block, at, diffSource(rowsOf(block.file), block.file), errors);
      return lines === null ? block : replaceRange(block, lines);
    }
    if (block.kind === "code") {
      const letters = [...lettersOf(block)];
      if (letters.length > 1) { errors.push(`${at}: code の端は b か h のどちらかにそろえる`); return block; }
      const letter = letters[0] ?? (block.ref === "base" ? "b" : "h");
      if (block.ref !== undefined && block.ref !== REF_OF[letter]) {
        errors.push(`${at}.ref: "${block.ref}" と range の端 ${letter} が合わない`);
        return block;
      }
      const lines = expandFile(block, at, letter);
      return lines === null ? block : replaceRange(block, lines, { ref: REF_OF[letter] });
    }
    errors.push(`${at}: range を書けるのは diff・code・beforeAfter`);
    return block;
  };

  const expandBlocks = (blocks, at) => {
    if (!Array.isArray(blocks)) return blocks;
    return blocks.map((block, b) => {
      if (!block || typeof block !== "object") return block;
      const out = expandBlock(block, `${at}[${b}]`);
      if (out !== block) expanded++;
      return out;
    });
  };
  const units = (guide.units ?? []).map((unit, u) => {
    const at = `units[${u}]`;
    const out = { ...unit, blocks: expandBlocks(unit.blocks, `${at}.blocks`) };
    if (unit.tests?.blocks !== undefined) out.tests = { ...unit.tests, blocks: expandBlocks(unit.tests.blocks, `${at}.tests.blocks`) };
    return out;
  });
  return { guide: { ...guide, units }, errors, expanded };
}

const [guidePath] = process.argv.slice(2);
if (!guidePath) {
  console.error("usage: node expand-guide.mjs <guide.json>");
  process.exit(2);
}
const guide = JSON.parse(readFileSync(guidePath, "utf8"));
if (typeof guide.base !== "string" || typeof guide.head !== "string") {
  console.error("guide.json に base と head の commit が必要");
  process.exit(1);
}
const memo = (fn) => {
  const cache = new Map();
  return (...args) => {
    const key = args.join("\0");
    if (!cache.has(key)) cache.set(key, fn(...args));
    return cache.get(key);
  };
};
const result = expandGuide(guide, memo((file) => diffRows(guide.base, guide.head, file)), memo(fileLines));
if (result.errors.length > 0) {
  console.error(`range に誤りがあるので書き換えなかった:\n- ${result.errors.join("\n- ")}`);
  process.exit(1);
}
if (result.expanded === 0) {
  console.log("range を持つブロックが無いので書き換えなかった");
  process.exit(0);
}
writeFileSync(guidePath, `${JSON.stringify(result.guide, null, 2)}\n`);
console.log(`${result.expanded} 個のブロックを展開して ${guidePath} を書き換えた`);
