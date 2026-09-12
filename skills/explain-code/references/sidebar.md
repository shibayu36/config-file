# サイドバーの実装例

配置・開閉・コード表示を示す最小例。下のコードブロックをHTMLとして保存すると、外部リソースなしで動作する。本文の構成や図は解説に合わせて作り、コード領域はVS CodeのDark+に合わせる。

実コードに適用するときは、表示確認用サンプルを実ファイルから取得したメソッド本体に置き換える。色分けは生成時に済ませ、この例のように色分け済みの要素とCSSをHTML内に含める。特定のライブラリには固定しない。

注釈は対象言語のコメント記法でコード内に加え、既存コメントと同じ色・文字サイズで表示する。元の処理・既存コメント・改行・インデントは保ち、文字列の途中など行末コメントが処理を変えてしまう箇所では、安全な位置に独立したコメント行を加える。色分け用の要素で囲むときに、注釈以外の文字や改行を `<code>` 内に加えない。

```html
<!doctype html>
<html lang="ja">
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>サイドバーの表示確認</title>
<style>
  * { box-sizing: border-box; }
  body {
    margin: 0;
    padding: 24px;
    color: #24292f;
    background: #fff;
    font: 16px/1.7 system-ui, sans-serif;
  }
  button { font: inherit; cursor: pointer; }
  button:focus-visible { outline: 2px solid #0969da; outline-offset: 3px; }
  code { font: 15px/1.6 ui-monospace, SFMono-Regular, Menlo, monospace; }
  .layout { display: grid; grid-template-columns: minmax(0, 1fr); gap: 24px; }
  .layout[data-sidebar-open="true"] {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
  main, .sidebar, .code-lines, .code-lines code { min-width: 0; }
  main { overflow-wrap: anywhere; }
  h1 { margin-top: 0; font-size: 28px; }
  .code-link {
    padding: 0;
    border: 0;
    color: #0969da;
    background: transparent;
    text-decoration: underline;
    text-align: left;
  }
  .sidebar {
    position: sticky;
    top: 24px;
    align-self: start;
    display: flex;
    flex-direction: column;
    max-height: calc(100vh - 48px);
    border: 1px solid #454545;
    border-radius: 8px;
    color: #d4d4d4;
    background: #1e1e1e;
    color-scheme: dark;
  }
  .sidebar[hidden] { display: none; }
  .sidebar-header {
    display: flex;
    align-items: start;
    justify-content: space-between;
    gap: 16px;
    padding: 16px;
    border-bottom: 1px solid #454545;
  }
  .sidebar-header h2 {
    min-width: 0;
    margin: 0;
    font-size: 16px;
    overflow-wrap: anywhere;
  }
  .close-sidebar { flex-shrink: 0; }
  .code-lines { min-height: 0; margin: 0; padding: 16px; overflow-y: auto; }
  .code-lines code {
    display: block;
    white-space: pre-wrap;
    overflow-wrap: anywhere;
    tab-size: 4;
  }
  .token-keyword { color: #569cd6; }
  .token-control { color: #c586c0; }
  .token-string { color: #ce9178; }
  .token-number { color: #b5cea8; }
  .token-function { color: #dcdcaa; }
  .token-variable { color: #9cdcfe; }
  .token-constant { color: #4fc1ff; }
  .token-comment { color: #6a9955; }
</style>

<div class="layout" data-sidebar-open="false">
  <main>
    <h1>本文とコードを並べて読む</h1>
    <p>以下は表示確認用のサンプルです。リポジトリの実コードではありません。</p>
    <p>通常は本文を広く表示し、コードを開いたときだけ左右に半分ずつ分けます。</p>
    <p><button class="code-link" data-code="sample-highlighted" aria-controls="code-sidebar" aria-expanded="false">色分けありのサンプル</button>を開くと、長い文字列と注釈の折り返しを確認できます。</p>
    <p><button class="code-link" data-code="sample-plain" aria-controls="code-sidebar" aria-expanded="false">色分けなしのサンプル</button>も全文を表示します。</p>
  </main>
  <aside class="sidebar" id="code-sidebar" aria-labelledby="code-title" hidden>
    <header class="sidebar-header">
      <h2 id="code-title">コード</h2>
      <button class="close-sidebar" type="button">閉じる</button>
    </header>
    <pre class="code-lines"></pre>
  </aside>
</div>

<template id="sample-highlighted">
<code><span class="token-keyword">function</span> <span class="token-function">formatMessage</span>(<span class="token-variable">name</span>) {
  <span class="token-keyword">const</span> <span class="token-constant">limit</span> = <span class="token-number">3</span>; <span class="token-comment">// 受信側が扱える要素数に合わせる</span>
  <span class="token-keyword">const</span> <span class="token-constant">marker</span> = <span class="token-string">"&lt;sample&gt; &amp; 日本語"</span>;
  <span class="token-keyword">const</span> <span class="token-constant">longLabel</span> = <span class="token-string">"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"</span>; <span class="token-comment">// 連携先が発行するラベルをそのまま保持する</span>

  <span class="token-control">return</span> [<span class="token-variable">name</span>, <span class="token-constant">marker</span>, <span class="token-constant">longLabel</span>].<span class="token-function">slice</span>(<span class="token-number">0</span>, <span class="token-constant">limit</span>).<span class="token-function">join</span>(<span class="token-string">" / "</span>); <span class="token-comment">// 受信側に合わせて区切り文字を固定する</span>
}</code>
</template>
<template id="sample-plain">
<code>形式不明のコード &lt;raw&gt; &amp; "text"
    abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789</code>
</template>

<script>
  const layout = document.querySelector('.layout');
  const sidebar = document.querySelector('.sidebar');
  const codeTitle = document.querySelector('#code-title');
  const codeLines = document.querySelector('.code-lines');
  const closeButton = document.querySelector('.close-sidebar');
  const codeLinks = document.querySelectorAll('.code-link');
  let opener;

  for (const link of codeLinks) {
    link.addEventListener('click', () => {
      const template = document.getElementById(link.dataset.code);
      codeLines.replaceChildren(template.content.querySelector('code').cloneNode(true));
      codeTitle.textContent = link.textContent;
      layout.dataset.sidebarOpen = 'true';
      sidebar.hidden = false;
      codeLines.scrollTop = 0;
      for (const item of codeLinks) {
        item.setAttribute('aria-expanded', String(item === link));
      }
      opener = link;
      closeButton.focus({ preventScroll: true });
    });
  }

  closeButton.addEventListener('click', () => {
    layout.dataset.sidebarOpen = 'false';
    sidebar.hidden = true;
    for (const link of codeLinks) {
      link.setAttribute('aria-expanded', 'false');
    }
    opener.focus({ preventScroll: true });
  });
</script>
</html>
```
