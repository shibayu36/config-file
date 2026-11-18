#!/usr/bin/env node
// guide.json を読み、diffをGitHub風に描いた1つのHTMLを書き出す。
// HTMLは外部を何も読み込まずに表示できる。色分けは生成時に済ませて style に書き込み、CSSとJSも埋め込む。
// 使い方: 対象リポジトリのディレクトリで `node render-html.mjs <guide.json> <out.html>`
// データの形が外れていればエラーで止まる。コードの行が base / head の実ファイルに見つからなければ警告を出す。
import { readFileSync, writeFileSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { dirname, extname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { diffRows } from "./diff-rows.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const { createHighlighter, THEME } = await import(join(here, "../vendor/highlight.mjs"));

const AI_NOTE = "[AI注]";
const LANG_BY_EXT = {
  ".go": "go",
  ".ts": "typescript", ".mts": "typescript", ".cts": "typescript",
  ".tsx": "tsx", ".jsx": "tsx",
  ".js": "javascript", ".mjs": "javascript", ".cjs": "javascript",
  ".json": "json",
  ".sql": "sql",
  ".py": "python",
  ".yaml": "yaml", ".yml": "yaml",
  ".proto": "proto",
};
// 図のHTMLが外部を読み込んでいないかを見る。1ファイルで完結させるため。
const EXTERNAL_REF = /\b(src|href)\s*=|@import|url\(\s*['"]?\s*(https?:|\/\/)/i;

// ---- データの検査 ----

function validate(guide) {
  const errors = [];
  const err = (at, msg) => errors.push(`${at}: ${msg}`);
  const isStr = (v) => typeof v === "string" && v.length > 0;
  const optStr = (v, at) => { if (v !== undefined && !isStr(v)) err(at, "文字列が必要"); };
  const strArray = (v, at) => {
    if (!Array.isArray(v)) return err(at, "文字列の配列が必要");
    v.forEach((s, i) => { if (typeof s !== "string") err(`${at}[${i}]`, "文字列が必要"); });
  };
  const items = (v, at) => {
    if (!Array.isArray(v)) return err(at, "配列が必要");
    v.forEach((item, i) => {
      if (typeof item === "string") return;
      if (item && isStr(item.text) && (item.items === undefined || Array.isArray(item.items))) {
        if (item.items) items(item.items, `${at}[${i}].items`);
        return;
      }
      err(`${at}[${i}]`, "文字列か { text, items } が必要");
    });
  };
  const figure = (v, at) => {
    if (v === undefined) return;
    strArray(v, at);
    if (Array.isArray(v) && EXTERNAL_REF.test(v.join("\n"))) err(at, "外部を読み込む記述（src= / href= / @import / url(http…)）は使えない");
  };
  const codeFile = (f, at, prefixed) => {
    if (!f || typeof f !== "object") return err(at, "{ file, lines } が必要");
    if (f.range !== undefined || f.lineNotes !== undefined) return err(at, "展開していない range / lineNotes がある。先に expand-guide.mjs で展開する");
    if (!isStr(f.file)) err(`${at}.file`, "リポジトリからのパスが必要");
    optStr(f.caption, `${at}.caption`);
    if (!Array.isArray(f.lines) || f.lines.length === 0) return err(`${at}.lines`, "1行以上の配列が必要");
    f.lines.forEach((line, l) => {
      if (typeof line !== "string") return err(`${at}.lines[${l}]`, "文字列が必要");
      if (prefixed && line !== "" && !" +-".includes(line[0]) && !line.startsWith("@@")) {
        err(`${at}.lines[${l}]`, `先頭は " "・"+"・"-"・"@@" のどれか: ${JSON.stringify(line)}`);
      }
    });
  };
  const blocks = (v, at) => {
    if (!Array.isArray(v)) return err(at, "配列が必要");
    v.forEach((block, b) => {
      const bat = `${at}[${b}]`;
      switch (block?.kind) {
        case "diff": return codeFile(block, bat, true);
        case "code":
          if (block.ref !== undefined && !["base", "head"].includes(block.ref)) err(`${bat}.ref`, `"base" か "head"`);
          return codeFile(block, bat, false);
        case "beforeAfter":
          for (const sideName of ["before", "after"]) {
            const side = block[sideName];
            if (!Array.isArray(side) || side.length === 0) err(`${bat}.${sideName}`, "1つ以上の { file, lines } が必要");
            else side.forEach((f, i) => codeFile(f, `${bat}.${sideName}[${i}]`, false));
          }
          return;
        case "text": if (!isStr(block.text)) err(`${bat}.text`, "文字列が必要"); return;
        case "list": items(block.items, `${bat}.items`); return;
        default: err(`${bat}.kind`, `"diff"・"code"・"beforeAfter"・"text"・"list" のどれか`);
      }
    });
  };

  if (!isStr(guide.title)) err("title", "文字列が必要");
  if (!isStr(guide.base)) err("base", "commitが必要");
  if (!isStr(guide.head)) err("head", "commitが必要");
  figure(guide.map?.figure, "map.figure");
  strArray(guide.omittedFiles ?? [], "omittedFiles");
  items(guide.checks ?? [], "checks");
  optStr(guide.checksSource, "checksSource");
  if (!Array.isArray(guide.units) || guide.units.length === 0) err("units", "1つ以上の単位が必要");
  (guide.units ?? []).forEach((unit, u) => {
    const at = `units[${u}]`;
    if (!isStr(unit.title)) err(`${at}.title`, "文字列が必要");
    if (!isStr(unit.nature)) err(`${at}.nature`, "変更の性質の文字列が必要");
    optStr(unit.why, `${at}.why`);
    optStr(unit.points, `${at}.points`);
    figure(unit.figure, `${at}.figure`);
    blocks(unit.blocks, `${at}.blocks`);
    if (unit.tests !== undefined) {
      if (!Array.isArray(unit.tests.groups)) err(`${at}.tests.groups`, "配列が必要");
      else unit.tests.groups.forEach((g, i) => { optStr(g.title, `${at}.tests.groups[${i}].title`); items(g.items, `${at}.tests.groups[${i}].items`); });
      if (unit.tests.blocks !== undefined) blocks(unit.tests.blocks, `${at}.tests.blocks`);
    }
    if (unit.notes !== undefined) items(unit.notes, `${at}.notes`);
  });
  return errors;
}

// ---- 行の解析 ----

// "[AI注]" の直前のコメント記号から行末までを注釈として切り離す。
// 行全体が注釈なら code を null にし、字下げを保ったまま note に入れる。
function splitNote(text) {
  const i = text.indexOf(AI_NOTE);
  if (i < 0) return { code: text, note: null };
  const m = text.slice(0, i).match(/\s*(\/\/|#|--|\/\*)\s*$/);
  const start = m ? m.index : i;
  const code = text.slice(0, start);
  if (code.trim() === "") return { code: null, note: text };
  return { code, note: text.slice(start).trim() };
}

function parseDiffLines(lines) {
  return lines.map((raw) => {
    if (raw.startsWith("@@")) return { type: "hunk", text: raw };
    const sign = raw === "" ? " " : raw[0];
    const { code, note } = splitNote(raw.slice(1));
    if (code === null) return { type: "note", note };
    return { type: sign === "+" ? "add" : sign === "-" ? "del" : "ctx", code, note };
  });
}

function parseCodeLines(lines) {
  return lines.map((raw) => {
    const { code, note } = splitNote(raw);
    return code === null ? { type: "note", note } : { type: "ctx", code, note };
  });
}

// ---- 実ファイルとの照合と色分け ----

function gitShow(ref, file) {
  try {
    return execFileSync("git", ["show", `${ref}:${file}`], { encoding: "utf8", maxBuffer: 64 * 1024 * 1024, stdio: ["ignore", "pipe", "ignore"] });
  } catch {
    return null;
  }
}

// 前に見つけた位置より後ろを先に探し、無ければ先頭から探す。
function locate(source, code, from) {
  const target = code.trimEnd();
  let i = source.lines.indexOf(target, from);
  if (i < 0) i = source.lines.indexOf(target);
  return i;
}

// rows の各行を base / head の実ファイルで探し、行番号と色分けを付ける。
// side が "diff" なら行の種類で探す先を変え、"base" / "head" ならその片方だけで探す。
// 見つからない行は警告し、その行だけで色分けする。
function matchRows(rows, sources, side, file, warnings, tokenizeLine) {
  const ptr = { base: 0, head: 0 };
  const find = (which, row) => {
    const src = sources[which];
    const i = locate(src, row.code, ptr[which]);
    if (i < 0) return false;
    ptr[which] = i + 1;
    row[which === "base" ? "oldNo" : "newNo"] = i + 1;
    row.tokens ??= src.tokens[i];
    return true;
  };
  for (const row of rows) {
    if (row.type === "note" || row.type === "hunk") continue;
    let found;
    if (side === "diff") {
      const inHead = row.type !== "del" && find("head", row);
      const inBase = row.type !== "add" && find("base", row);
      found = row.type === "add" ? inHead : row.type === "del" ? inBase : inHead || inBase;
    } else {
      found = find(side, row);
    }
    if (!found) {
      const where = side === "diff" ? (row.type === "del" ? "base" : "head") : side;
      warnings.push(`${file}: ${where} に無い行: ${JSON.stringify(row.code)}`);
      row.tokens = tokenizeLine(row.code);
    }
  }
}

// "@@" の行から次の "@@" の行（無ければブロックの終わり）までを1つの区間とし、
// 区間の中で表示した行どうしの間にある、載せなかった実際の diff の行を、その位置に "omitted" の行として差し込む。
// ブロックが "@@" の行で終わる時は、最後に表示した行より後ろのファイルの終わりまでを、その "@@" の区間に含める。
// 差し込むのは、省いた行に変更を含む区間だけ。行番号の分からない行や、順序が実際の diff と食い違う行がある区間は、
// 省いた範囲を決められないので差し込まない。差し込んだ区間の "@@" の行には gapId を付ける。
function insertOmitted(rows, full, newId) {
  const idxByOld = new Map();
  const idxByNew = new Map();
  full.forEach((r, i) => {
    if (r.type !== "add") idxByOld.set(r.oldNo, i);
    if (r.type !== "del") idxByNew.set(r.newNo, i);
  });
  const position = (r) => {
    if (r.type === "add") return idxByNew.get(r.newNo);
    if (r.type === "del") return idxByOld.get(r.oldNo);
    return r.newNo !== undefined ? idxByNew.get(r.newNo) : idxByOld.get(r.oldNo);
  };

  const out = [];
  const sections = [];
  let section = null;
  let last = -1;
  for (const r of rows) {
    if (r.type === "hunk") {
      section = { hunk: r, pieces: [], valid: last !== null, hasRows: false };
      sections.push(section);
    } else if (r.type !== "note") {
      const pos = position(r);
      if (section) {
        section.hasRows = true;
        if (pos === undefined || last === null || pos <= last) section.valid = false;
        else if (pos > last + 1) section.pieces.push({ at: out.length, rows: full.slice(last + 1, pos) });
      }
      last = pos ?? null;
    }
    out.push(r);
  }
  if (section && !section.hasRows && last !== null && last + 1 < full.length) {
    section.pieces.push({ at: out.length, rows: full.slice(last + 1) });
  }

  const inserts = [];
  for (const s of sections) {
    if (!s.valid || !s.pieces.some((p) => p.rows.some((r) => r.type !== "ctx"))) continue;
    s.hunk.gapId = newId();
    for (const p of s.pieces) inserts.push({ at: p.at, row: { type: "omitted", id: s.hunk.gapId, rows: p.rows.map((r) => ({ ...r })) } });
  }
  for (const { at, row } of inserts.sort((a, b) => b.at - a.at)) out.splice(at, 0, row);
  return out;
}

// ---- 行内の単語の差分 ----

function wordTokens(s) {
  return s.match(/[\p{Script=Han}\p{Script=Hiragana}\p{Script=Katakana}ー]|[A-Za-z0-9_$]+|\s+|./gu) ?? [];
}

// 2つの行の、変わった文字の範囲 [start, end) を返す。似ていない行どうしは塗らない。
function wordDiff(a, b) {
  const x = wordTokens(a);
  const y = wordTokens(b);
  const dp = Array.from({ length: x.length + 1 }, () => new Uint16Array(y.length + 1));
  for (let i = x.length - 1; i >= 0; i--) {
    for (let j = y.length - 1; j >= 0; j--) {
      dp[i][j] = x[i] === y[j] ? dp[i + 1][j + 1] + 1 : Math.max(dp[i + 1][j], dp[i][j + 1]);
    }
  }
  const keepA = new Array(x.length).fill(false);
  const keepB = new Array(y.length).fill(false);
  let common = 0;
  for (let i = 0, j = 0; i < x.length && j < y.length;) {
    if (x[i] === y[j]) {
      if (x[i].trim()) common += x[i].length;
      keepA[i++] = true;
      keepB[j++] = true;
    } else if (dp[i + 1][j] >= dp[i][j + 1]) i++;
    else j++;
  }
  const visible = (s) => s.replace(/\s/g, "").length;
  if (common / Math.max(visible(a), visible(b), 1) < 0.4) return [[], []];
  const ranges = (toks, keep) => {
    const out = [];
    let pos = 0;
    toks.forEach((t, k) => {
      if (!keep[k]) {
        const last = out[out.length - 1];
        if (last && last[1] === pos) last[1] = pos + t.length;
        else out.push([pos, pos + t.length]);
      }
      pos += t.length;
    });
    return out;
  };
  return [ranges(x, keepA), ranges(y, keepB)];
}

// 連続する削除の行と、その直後の追加の行を、上から順に組にする。
function changeGroups(rows, onGroup) {
  let i = 0;
  while (i < rows.length) {
    if (rows[i].type !== "del" && rows[i].type !== "add") { onGroup(null, rows[i]); i++; continue; }
    const dels = [];
    while (i < rows.length && rows[i].type === "del") dels.push(rows[i++]);
    const adds = [];
    while (i < rows.length && rows[i].type === "add") adds.push(rows[i++]);
    onGroup({ dels, adds });
  }
}

// 字下げの違いは塗らず、字下げより後ろだけを比べる。
function wordDiffIgnoringIndent(a, b) {
  const ia = a.length - a.trimStart().length;
  const ib = b.length - b.trimStart().length;
  const [ra, rb] = wordDiff(a.slice(ia), b.slice(ib));
  const shift = (ranges, n) => ranges.map(([s, e]) => [s + n, e + n]);
  return [shift(ra, ia), shift(rb, ib)];
}

// before/after の行どうしを字下げを無視して比べ、片側にしか無い行に tone（"del" / "add"）を付ける。
// 責務の移動では、コードがそのまま移って字下げだけ変わることが多いため、字下げは比べない。
function markBeforeAfter(before, after) {
  const key = (r) => r.code.trim();
  const dp = Array.from({ length: before.length + 1 }, () => new Uint16Array(after.length + 1));
  for (let i = before.length - 1; i >= 0; i--) {
    for (let j = after.length - 1; j >= 0; j--) {
      dp[i][j] = key(before[i]) === key(after[j]) ? dp[i + 1][j + 1] + 1 : Math.max(dp[i + 1][j], dp[i][j + 1]);
    }
  }
  let gapA = [];
  let gapB = [];
  const flush = () => {
    for (const r of gapA) r.tone = "del";
    for (const r of gapB) r.tone = "add";
    for (let k = 0; k < Math.min(gapA.length, gapB.length); k++) {
      [gapA[k].ranges, gapB[k].ranges] = wordDiffIgnoringIndent(gapA[k].code, gapB[k].code);
    }
    gapA = [];
    gapB = [];
  };
  let i = 0;
  let j = 0;
  while (i < before.length && j < after.length) {
    if (key(before[i]) === key(after[j])) { flush(); i++; j++; }
    else if (dp[i + 1][j] >= dp[i][j + 1]) gapA.push(before[i++]);
    else gapB.push(after[j++]);
  }
  gapA.push(...before.slice(i));
  gapB.push(...after.slice(j));
  flush();
}

function applyWordDiff(rows, diff = wordDiff) {
  changeGroups(rows, (g) => {
    if (!g) return;
    for (let k = 0; k < Math.min(g.dels.length, g.adds.length); k++) {
      [g.dels[k].ranges, g.adds[k].ranges] = diff(g.dels[k].code, g.adds[k].code);
    }
  });
}

// GitHub の w=1（git diff -w）のように、空白を除くと同じになる削除と追加の行を、変更の無い行にした rows を返す。
// 組にするのは、連続する削除の行とその直後の追加の行の中だけ。組にできる行が無ければ null を返す。
// 残った削除と追加の行の単語の差分も、字下げの違いは塗らない。
// 変更の無い行にした行は、split の左側に変更前の行（left）を出せるよう両方を持つ。
function hideWhitespaceChanges(rows) {
  const key = (r) => r.code.replace(/\s+/g, "");
  const fresh = (r) => ({ ...r, ranges: undefined });
  const out = [];
  let collapsed = false;
  changeGroups(rows, (g, r) => {
    if (!g) { out.push(r); return; }
    const { dels, adds } = g;
    const dp = Array.from({ length: dels.length + 1 }, () => new Uint16Array(adds.length + 1));
    for (let i = dels.length - 1; i >= 0; i--) {
      for (let j = adds.length - 1; j >= 0; j--) {
        dp[i][j] = key(dels[i]) === key(adds[j]) ? dp[i + 1][j + 1] + 1 : Math.max(dp[i + 1][j], dp[i][j + 1]);
      }
    }
    let pendingDels = [];
    let pendingAdds = [];
    const flush = () => {
      out.push(...pendingDels.map(fresh), ...pendingAdds.map(fresh));
      pendingDels = [];
      pendingAdds = [];
    };
    let i = 0;
    let j = 0;
    while (i < dels.length && j < adds.length) {
      if (key(dels[i]) === key(adds[j])) {
        flush();
        const d = dels[i++];
        const a = adds[j++];
        out.push({ type: "ctx", code: a.code, tokens: a.tokens, note: a.note ?? d.note, oldNo: d.oldNo, newNo: a.newNo, left: fresh(d) });
        collapsed = true;
      } else if (dp[i + 1][j] >= dp[i][j + 1]) pendingDels.push(dels[i++]);
      else pendingAdds.push(adds[j++]);
    }
    pendingDels.push(...dels.slice(i));
    pendingAdds.push(...adds.slice(j));
    flush();
  });
  if (!collapsed) return null;
  applyWordDiff(out, wordDiffIgnoringIndent);
  return out;
}

// ---- HTML の部品 ----

const esc = (s) => s.replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]);
const inline = (s) => esc(s).replace(/`([^`]+)`/g, "<code>$1</code>");

function itemsHtml(list) {
  const li = (item) => typeof item === "string"
    ? `<li>${inline(item)}</li>`
    : `<li>${inline(item.text)}${item.items ? itemsHtml(item.items) : ""}</li>`;
  return `<ul>${list.map(li).join("")}</ul>`;
}

function codeHtml(row) {
  const tokens = row.tokens ?? [{ content: row.code }];
  const ranges = row.ranges ?? [];
  let out = "";
  let pos = 0;
  for (const t of tokens) {
    const cuts = new Set([0, t.content.length]);
    for (const [s, e] of ranges) {
      if (s > pos && s < pos + t.content.length) cuts.add(s - pos);
      if (e > pos && e < pos + t.content.length) cuts.add(e - pos);
    }
    const sorted = [...cuts].sort((a, b) => a - b);
    for (let k = 0; k < sorted.length - 1; k++) {
      const piece = t.content.slice(sorted[k], sorted[k + 1]);
      const at = pos + sorted[k];
      const changed = ranges.some(([s, e]) => at >= s && at < e);
      const style = t.color ? ` style="color:${t.color}${t.fontStyle & 1 ? ";font-style:italic" : ""}"` : "";
      const span = `<span${style}>${esc(piece)}</span>`;
      out += changed ? `<span class="wd">${span}</span>` : span;
    }
    pos += t.content.length;
  }
  if (row.note) out += ` <span class="ai-note">${esc(row.note)}</span>`;
  return out;
}

const noteHtml = (row) => `<span class="ai-note">${esc(row.note)}</span>`;
const SIGN = { add: "+", del: "-", ctx: " " };

function fileBox(file, caption, body, label) {
  const head = `${label ? `<span class="file-label ${label.tone}">${esc(label.text)}</span>` : ""}<span class="file-path">${esc(file)}</span>${caption ? `<span class="file-caption">${inline(caption)}</span>` : ""}`;
  return `<div class="file"><div class="file-header">${head}</div>${body}</div>`;
}

// 省いた行のある "@@" の行は、押すとその区間の省いた行を開閉できるようにする。
// 省いた行は、ws が true なら空白の変更を隠した版を出す。
const hunkAttrs = (r) => (r.gapId ? `class="hunk gap-toggle" data-gap="${r.gapId}" aria-expanded="false" title="省いた行を開く"` : `class="hunk"`);
const omittedRows = (r, ws) => (ws ? r.wsRows : r.rows);
const hideRow = (tr, id) => tr.replace(/^<tr/, `<tr hidden data-gap-row="${id}"`);

function inlineDiffTrs(rows, ws) {
  return rows.flatMap((r) => {
    if (r.type === "omitted") return inlineDiffTrs(omittedRows(r, ws), ws).map((tr) => hideRow(tr, r.id));
    if (r.type === "hunk") return `<tr ${hunkAttrs(r)}><td class="ln"></td><td class="ln"></td><td class="sign"></td><td class="code">${esc(r.text)}</td></tr>`;
    if (r.type === "note") return `<tr class="note"><td class="ln"></td><td class="ln"></td><td class="sign"></td><td class="code">${noteHtml(r)}</td></tr>`;
    return `<tr class="${r.type}"><td class="ln">${r.type === "add" ? "" : r.oldNo ?? ""}</td><td class="ln">${r.type === "del" ? "" : r.newNo ?? ""}</td><td class="sign">${SIGN[r.type]}</td><td class="code">${codeHtml(r)}</td></tr>`;
  });
}

function inlineDiffTable(rows, ws) {
  return `<table class="diff inline-view"><colgroup><col class="c-ln"><col class="c-ln"><col class="c-sign"><col></colgroup>${inlineDiffTrs(rows, ws).join("")}</table>`;
}

function splitDiffTrs(rows, ws) {
  const cell = (r, kind) => {
    if (!r) return `<td class="ln empty"></td><td class="code empty"></td>`;
    const no = kind === "old" || kind === "del" ? r.oldNo : r.newNo;
    return `<td class="ln ${kind}">${no ?? ""}</td><td class="code ${kind}">${codeHtml(r)}</td>`;
  };
  const trs = [];
  changeGroups(rows, (g, r) => {
    if (g) {
      for (let k = 0; k < Math.max(g.dels.length, g.adds.length); k++) trs.push(`<tr>${cell(g.dels[k], "del")}${cell(g.adds[k], "add")}</tr>`);
    } else if (r.type === "omitted") trs.push(...splitDiffTrs(omittedRows(r, ws), ws).map((tr) => hideRow(tr, r.id)));
    else if (r.type === "hunk") trs.push(`<tr ${hunkAttrs(r)}><td class="ln"></td><td class="code" colspan="3">${esc(r.text)}</td></tr>`);
    else if (r.type === "note") trs.push(`<tr class="note"><td class="ln"></td><td class="code" colspan="3">${noteHtml(r)}</td></tr>`);
    else trs.push(`<tr class="ctx">${cell(r.left ?? r, "old")}${cell(r, "new")}</tr>`);
  });
  return trs;
}

function splitDiffTable(rows, ws) {
  return `<table class="diff split-view"><colgroup><col class="c-ln"><col><col class="c-ln"><col></colgroup>${splitDiffTrs(rows, ws).join("")}</table>`;
}

// 行に tone（"del" / "add"）が付いていれば、diffの削除・追加と同じ色で塗る。
function codeTable(rows, side) {
  const trs = rows.map((r) => r.type === "note"
    ? `<tr class="note"><td class="ln"></td><td class="code">${noteHtml(r)}</td></tr>`
    : `<tr class="${r.tone ?? "ctx"}"><td class="ln">${(side === "base" ? r.oldNo : r.newNo) ?? ""}</td><td class="code">${codeHtml(r)}</td></tr>`);
  return `<table class="diff"><colgroup><col class="c-ln"><col></colgroup>${trs.join("")}</table>`;
}

const figureHtml = (lines) => (lines ? `<figure class="fig">${lines.join("\n")}</figure>` : "");

// ---- ブロック ----

function makeRenderer(guide, highlighter, warnings) {
  const loaded = new Set(highlighter.getLoadedLanguages());
  const cache = new Map();
  const langOf = (file) => {
    const lang = LANG_BY_EXT[extname(file).toLowerCase()];
    return loaded.has(lang) ? lang : "text";
  };
  const source = (ref, file) => {
    const key = `${ref}:${file}`;
    if (!cache.has(key)) {
      const lang = langOf(file);
      const content = gitShow(ref, file);
      cache.set(key, content === null
        ? { lines: [], tokens: [] }
        : { lines: content.split("\n").map((l) => l.trimEnd()), tokens: highlighter.codeToTokens(content, { lang, theme: THEME }).tokens });
    }
    return cache.get(key);
  };
  const sources = (file) => ({ base: source(guide.base, file), head: source(guide.head, file) });
  const tokenizer = (file) => (code) => highlighter.codeToTokens(code, { lang: langOf(file), theme: THEME }).tokens[0] ?? [];
  const fullCache = new Map();
  const fullDiff = (file) => {
    if (!fullCache.has(file)) {
      const src = sources(file);
      fullCache.set(file, diffRows(guide.base, guide.head, file).map((r) => ({
        ...r,
        tokens: r.type === "del" ? src.base.tokens[r.oldNo - 1] : src.head.tokens[r.newNo - 1],
      })));
    }
    return fullCache.get(file);
  };
  let gapCount = 0;

  const codeRows = (f, side) => {
    const rows = parseCodeLines(f.lines);
    matchRows(rows, sources(f.file), side, f.file, warnings, tokenizer(f.file));
    return rows;
  };

  return (block) => {
    switch (block.kind) {
      case "diff": {
        const shown = parseDiffLines(block.lines);
        matchRows(shown, sources(block.file), "diff", block.file, warnings, tokenizer(block.file));
        const rows = shown.some((r) => r.type === "hunk")
          ? insertOmitted(shown, fullDiff(block.file), () => `gap-${++gapCount}`)
          : shown;
        applyWordDiff(rows);
        const omitted = rows.filter((r) => r.type === "omitted");
        for (const r of omitted) {
          applyWordDiff(r.rows);
          r.wsRows = hideWhitespaceChanges(r.rows) ?? r.rows;
        }
        const tables = (rs, ws) => inlineDiffTable(rs, ws) + splitDiffTable(rs, ws);
        const wsHidden = hideWhitespaceChanges(rows);
        const body = wsHidden || omitted.some((r) => r.wsRows !== r.rows)
          ? `<div class="ws-show">${tables(rows, false)}</div><div class="ws-hide">${tables(wsHidden ?? rows, true)}</div>`
          : tables(rows, false);
        return fileBox(block.file, block.caption, body);
      }
      case "code": {
        const side = block.ref ?? "head";
        return fileBox(block.file, block.caption, codeTable(codeRows(block, side), side));
      }
      case "beforeAfter": {
        const before = block.before.map((f) => ({ f, rows: codeRows(f, "base") }));
        const after = block.after.map((f) => ({ f, rows: codeRows(f, "head") }));
        const codeOnly = (files) => files.flatMap((x) => x.rows).filter((r) => r.type !== "note");
        markBeforeAfter(codeOnly(before), codeOnly(after));
        const html = (files, side, label) => files.map(({ f, rows }) => fileBox(f.file, f.caption, codeTable(rows, side), label)).join("");
        return `<div class="before-after"><div>${html(before, "base", { text: "変更前", tone: "del" })}</div><div>${html(after, "head", { text: "変更後", tone: "add" })}</div></div>`;
      }
      case "text":
        return `<p>${inline(block.text)}</p>`;
      case "list":
        return itemsHtml(block.items);
    }
  };
}

// ---- ページ ----

const CSS = `
* { box-sizing: border-box; }
body { margin: 0; padding: 0 32px 64px; color: #1f2328; background: #fff; font: 15px/1.7 -apple-system, BlinkMacSystemFont, "Segoe UI", "Hiragino Sans", sans-serif; }
.layout { display: grid; grid-template-columns: 240px minmax(0, 1fr); gap: 32px; max-width: 1680px; margin: 0 auto; }
nav.toc { position: sticky; top: 0; align-self: start; max-height: 100vh; overflow-y: auto; padding: 24px 0; font-size: 13px; line-height: 1.5; }
nav.toc ol { list-style: none; margin: 0; padding: 0; }
nav.toc a { display: block; padding: 4px 8px; border-left: 2px solid #d1d9e0; color: #59636e; text-decoration: none; }
nav.toc a:hover { color: #1f2328; background: #f6f8fa; }
nav.toc a.current { border-left-color: #fd8c73; color: #1f2328; font-weight: 600; background: #f6f8fa; }
nav.toc code { font: 12px ui-monospace, SFMono-Regular, Menlo, monospace; }
@media (max-width: 1100px) { .layout { display: block; } nav.toc, #toc-open { display: none; } }
section[id] { scroll-margin-top: 56px; }
h1 { font-size: 24px; margin: 24px 0 4px; }
h2 { font-size: 20px; margin: 48px 0 8px; padding-bottom: 6px; border-bottom: 1px solid #d1d9e0; }
h3 { font-size: 15px; margin: 24px 0 4px; }
.meta { color: #59636e; font-size: 13px; margin: 0; }
p, ul { margin: 8px 0; }
ul { padding-left: 1.5em; }
p code, li code, td code, .file-caption code { padding: 1px 5px; border-radius: 4px; background: #eff1f3; font: 13px ui-monospace, SFMono-Regular, Menlo, monospace; }
.label { font-weight: 600; }
.toolbar { position: sticky; top: 0; z-index: 2; display: flex; justify-content: flex-end; align-items: center; gap: 16px; padding: 8px 0; background: #fff; }
.toolbar label { display: flex; align-items: center; gap: 4px; font-size: 13px; cursor: pointer; }
.toolbar .view-switch { display: flex; }
.toolbar button { padding: 4px 14px; border: 1px solid #d1d9e0; background: #f6f8fa; color: #1f2328; font: 13px/1.5 inherit; cursor: pointer; }
.toolbar .view-switch button:first-child { border-radius: 6px 0 0 6px; }
.toolbar .view-switch button:last-child { border-radius: 0 6px 6px 0; border-left: 0; }
.toolbar .view-switch button[aria-pressed="true"] { background: #fff; font-weight: 600; box-shadow: inset 0 -2px 0 #fd8c73; }
.toc-button { padding: 0 6px; border: 0; border-radius: 4px; background: none; color: #8c959f; font: 16px/1.5 inherit; cursor: pointer; }
.toc-button:hover { color: #1f2328; background: #f6f8fa; }
#toc-close { display: block; margin: 0 0 4px auto; }
#toc-open { position: fixed; top: 20px; left: 4px; z-index: 3; }
body[data-toc="open"] #toc-open { display: none; }
body[data-toc="closed"] .layout { display: block; }
body[data-toc="closed"] nav.toc { display: none; }
table.map { border-collapse: collapse; margin: 8px 0; }
table.map th, table.map td { padding: 4px 12px; border: 1px solid #d1d9e0; text-align: left; }
table.map th { background: #f6f8fa; }
.file { margin: 12px 0; border: 1px solid #d1d9e0; border-radius: 6px; overflow: hidden; }
.file-header { display: flex; flex-wrap: wrap; align-items: baseline; gap: 8px; padding: 6px 12px; background: #f6f8fa; border-bottom: 1px solid #d1d9e0; font-size: 13px; }
.file-path { font: 600 13px/1.5 ui-monospace, SFMono-Regular, Menlo, monospace; overflow-wrap: anywhere; }
.file-label { padding: 0 8px; border-radius: 10px; font-size: 12px; font-weight: 600; }
.file-label.del { color: #82071e; background: #ffcecb; }
.file-label.add { color: #116329; background: #aceebb; }
.file-caption { color: #59636e; }
table.diff { width: 100%; border-collapse: collapse; table-layout: fixed; font: 13px/20px ui-monospace, SFMono-Regular, Menlo, monospace; }
body[data-view="split"] .inline-view, body[data-view="inline"] .split-view { display: none; }
body[data-ws="hide"] .ws-show, body[data-ws="show"] .ws-hide { display: none; }
.before-after { display: grid; gap: 0 16px; }
body[data-view="split"] .before-after { grid-template-columns: minmax(0, 1fr) minmax(0, 1fr); align-items: start; }
col.c-ln { width: 52px; }
col.c-sign { width: 20px; }
table.diff td { padding: 0 8px; vertical-align: top; }
td.ln { color: #59636e; text-align: right; user-select: none; font-size: 12px; }
td.sign { padding: 0; text-align: center; user-select: none; }
td.code { white-space: pre-wrap; overflow-wrap: anywhere; tab-size: 4; }
.split-view td.code.old, .split-view td.code.del, .split-view td.code.empty:nth-child(2) { border-right: 1px solid #d1d9e0; }
tr.add td, td.add { background: #e6ffec; }
tr.add td.ln, td.ln.add { background: #ccffd8; }
tr.del td, td.del { background: #ffebe9; }
tr.del td.ln, td.ln.del { background: #ffd7d5; }
td.empty { background: #f6f8fa; }
td.add .wd, tr.add .wd { background: #abf2bc; border-radius: 2px; }
td.del .wd, tr.del .wd { background: rgba(255, 129, 130, 0.4); border-radius: 2px; }
tr.hunk td { background: #ddf4ff; color: #59636e; }
tr.gap-toggle td { cursor: pointer; }
tr.gap-toggle:hover td { background: #b6e3ff; }
tr.gap-toggle td.code::before { content: "▸ "; }
tr.gap-toggle[aria-expanded="true"] td.code::before { content: "▾ "; }
tr.note td { background: #fff8c5; }
tr.note td.code { box-shadow: inset 3px 0 0 #d4a72c; }
.ai-note { color: #1f2328; background: #ffe58a; border-radius: 3px; padding: 0 3px; box-decoration-break: clone; -webkit-box-decoration-break: clone; }
tr.note .ai-note { background: transparent; padding: 0; }
/* 図で使ってよい部品 */
figure.fig { margin: 16px 0; padding: 16px; border: 1px solid #d1d9e0; border-radius: 6px; overflow-x: auto; }
figure.fig svg { display: block; max-width: 100%; height: auto; margin: 0 auto; font: 13px/1.4 -apple-system, BlinkMacSystemFont, "Hiragino Sans", sans-serif; }
.fig-box { fill: #f6f8fa; stroke: #59636e; stroke-width: 1; }
.fig-box-new { fill: #e6ffec; stroke: #1a7f37; stroke-width: 1; }
.fig-box-old { fill: #ffebe9; stroke: #cf222e; stroke-width: 1; }
.fig-box-alt { fill: none; stroke: #8c959f; stroke-width: 1; stroke-dasharray: 4 3; }
.fig-line { stroke: #59636e; stroke-width: 1.2; fill: none; marker-end: url(#fig-arrow); }
.fig-line-return { stroke: #59636e; stroke-width: 1.2; fill: none; stroke-dasharray: 5 3; marker-end: url(#fig-arrow); }
.fig-lifeline { stroke: #8c959f; stroke-width: 1; stroke-dasharray: 3 3; }
.fig-note { fill: #fff8c5; stroke: #d4a72c; stroke-width: 1; }
.fig-text { fill: #1f2328; }
.fig-label { fill: #59636e; font-size: 12px; }
.fig-title { fill: #1f2328; font-weight: 600; }
`;

const SVG_DEFS = `<svg width="0" height="0" style="position:absolute" aria-hidden="true"><defs><marker id="fig-arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" fill="#59636e"/></marker></defs></svg>`;

const SCRIPT = `
const KEY = "diff-reading-guide:view";
const setView = (v) => {
  document.body.dataset.view = v;
  for (const b of document.querySelectorAll(".view-switch button")) b.setAttribute("aria-pressed", String(b.dataset.view === v));
  localStorage.setItem(KEY, v);
};
for (const b of document.querySelectorAll(".view-switch button")) b.addEventListener("click", () => setView(b.dataset.view));
setView(localStorage.getItem(KEY) || "inline");

const WS_KEY = "diff-reading-guide:ws";
const wsToggle = document.getElementById("ws-toggle");
const setWs = (v) => {
  document.body.dataset.ws = v;
  wsToggle.checked = v === "hide";
  localStorage.setItem(WS_KEY, v);
};
wsToggle.addEventListener("change", () => setWs(wsToggle.checked ? "hide" : "show"));
setWs(localStorage.getItem(WS_KEY) || "hide");

const TOC_KEY = "diff-reading-guide:toc";
const setToc = (v) => {
  document.body.dataset.toc = v;
  localStorage.setItem(TOC_KEY, v);
};
document.getElementById("toc-close").addEventListener("click", () => setToc("closed"));
document.getElementById("toc-open").addEventListener("click", () => setToc("open"));
setToc(localStorage.getItem(TOC_KEY) || "open");

// 同じ区間の表は inline/split と空白の切り替えで複数あるので、すべての開閉を揃える。
document.addEventListener("click", (e) => {
  const toggle = e.target.closest("tr.gap-toggle");
  if (!toggle) return;
  const id = toggle.dataset.gap;
  const open = toggle.getAttribute("aria-expanded") !== "true";
  for (const t of document.querySelectorAll('tr.gap-toggle[data-gap="' + id + '"]')) t.setAttribute("aria-expanded", String(open));
  for (const r of document.querySelectorAll('tr[data-gap-row="' + id + '"]')) r.hidden = !open;
});

// 見出しが画面の上端近くまで来た最後の節を、今読んでいる節として目次で強調する。
// 最後の節が短いと見出しが上端まで届かないので、末尾まで来たら最後の節にする。
const tocLinks = [...document.querySelectorAll("nav.toc a")];
const tocTargets = tocLinks.map((a) => document.getElementById(a.hash.slice(1)));
let tocQueued = false;
const markCurrent = () => {
  tocQueued = false;
  let current = 0;
  tocTargets.forEach((t, i) => { if (t.getBoundingClientRect().top <= 80) current = i; });
  if (innerHeight + scrollY >= document.documentElement.scrollHeight - 2) current = tocTargets.length - 1;
  tocLinks.forEach((a, i) => a.classList.toggle("current", i === current));
};
addEventListener("scroll", () => { if (!tocQueued) { tocQueued = true; requestAnimationFrame(markCurrent); } }, { passive: true });
markCurrent();
`;

function render(guide, renderBlock) {
  const mapRows = guide.units.map((u, i) => `<tr><td>${i + 1}</td><td><a href="#unit-${i + 1}">${inline(u.title)}</a></td><td>${inline(u.nature)}</td></tr>`).join("");
  const omitted = guide.omittedFiles?.length ? guide.omittedFiles.map((f) => `<code>${esc(f)}</code>`).join("、") : "なし";
  const checks = guide.checks?.length ? itemsHtml(guide.checks) : "<p>記載なし</p>";
  const tocItems = [
    `<li><a href="#map">地図</a></li>`,
    `<li><a href="#checks">動作確認したこと</a></li>`,
    ...guide.units.map((u, i) => `<li><a href="#unit-${i + 1}">${i + 1}. ${inline(u.title)}</a></li>`),
  ].join("");
  const units = guide.units.map((unit, i) => {
    const tests = unit.tests ? `<h3>テストが確かめていること</h3>${unit.tests.groups.map((g) => `${g.title ? `<p>${inline(g.title)}</p>` : ""}${itemsHtml(g.items)}`).join("")}${(unit.tests.blocks ?? []).map(renderBlock).join("")}` : "";
    const notes = unit.notes?.length ? `<h3>特記</h3>${itemsHtml(unit.notes)}` : "";
    return `
<section id="unit-${i + 1}">
<h2>${i + 1}. ${inline(unit.title)}</h2>
${unit.why ? `<p><span class="label">なぜ:</span> ${inline(unit.why)}</p>` : ""}
${unit.points ? `<p><span class="label">見るポイント:</span> ${inline(unit.points)}</p>` : ""}
${figureHtml(unit.figure)}
${unit.blocks.map(renderBlock).join("\n")}
${tests}
${notes}
</section>`;
  });
  return `<!doctype html>
<html lang="ja">
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${esc(guide.title)}</title>
<style>${CSS}</style>
<body data-view="inline" data-ws="hide" data-toc="open">
${SVG_DEFS}
<div class="layout">
<button id="toc-open" class="toc-button" title="目次を開く" aria-label="目次を開く">»</button>
<nav class="toc"><button id="toc-close" class="toc-button" title="目次を閉じる" aria-label="目次を閉じる">«</button><ol>${tocItems}</ol></nav>
<main>
<h1>${inline(guide.title)}</h1>
<p class="meta">base <code>${esc(guide.base)}</code> → head <code>${esc(guide.head)}</code></p>
<div class="toolbar"><label><input type="checkbox" id="ws-toggle" checked>空白の変更を隠す</label><div class="view-switch"><button data-view="inline">Inline</button><button data-view="split">Split</button></div></div>
<section id="map">
<h2>地図</h2>
<table class="map"><tr><th>#</th><th>読む単位</th><th>性質</th></tr>${mapRows}</table>
${figureHtml(guide.map?.figure)}
<p>載せなかったファイル: ${omitted}</p>
</section>
<section id="checks">
<h2>動作確認したこと</h2>
${guide.checksSource ? `<p>${inline(guide.checksSource)}</p>` : ""}
${checks}
</section>
${units.join("\n")}
</main>
</div>
<script>${SCRIPT}</script>
</body>
</html>
`;
}

// ---- main ----

const [guidePath, outPath] = process.argv.slice(2);
if (!guidePath || !outPath) {
  console.error("usage: node render-html.mjs <guide.json> <out.html>");
  process.exit(2);
}
const guide = JSON.parse(readFileSync(guidePath, "utf8"));
const errors = validate(guide);
if (errors.length > 0) {
  console.error(`guide.json の形が外れている:\n- ${errors.join("\n- ")}`);
  process.exit(1);
}

const warnings = [];
const renderBlock = makeRenderer(guide, await createHighlighter(), warnings);
writeFileSync(outPath, render(guide, renderBlock));
if (warnings.length > 0) console.error(`実ファイルと合わない行がある:\n- ${warnings.join("\n- ")}`);
console.log(`wrote ${outPath}`);
