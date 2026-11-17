import { createHighlighterCore } from "shiki/core";
import { createJavaScriptRegexEngine } from "shiki/engine/javascript";
import go from "shiki/langs/go.mjs";
import typescript from "shiki/langs/typescript.mjs";
import tsx from "shiki/langs/tsx.mjs";
import javascript from "shiki/langs/javascript.mjs";
import json from "shiki/langs/json.mjs";
import sql from "shiki/langs/sql.mjs";
import python from "shiki/langs/python.mjs";
import yaml from "shiki/langs/yaml.mjs";
import proto from "shiki/langs/proto.mjs";
import githubLight from "shiki/themes/github-light.mjs";

export const THEME = "github-light";

export async function createHighlighter() {
  return createHighlighterCore({
    themes: [githubLight],
    langs: [go, typescript, tsx, javascript, json, sql, python, yaml, proto],
    engine: createJavaScriptRegexEngine(),
  });
}
