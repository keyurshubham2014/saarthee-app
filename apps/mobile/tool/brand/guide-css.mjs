// Styles for brand-guide.html (Neem tokens, DS §2–§4).
export const CSS = `
:root{--primary:#14674A;--pc:#E1F0E7;--sun:#C24A1F;--bg:#F3F6F1;--surface:#fff;--border:#DCE5DE;--ink:#17251E;--ink2:#4E5E55}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);font:400 16px/24px Mukta,'Noto Sans Gujarati',sans-serif}
h1,h2,h3{font-family:Baloo,sans-serif;font-weight:700;margin:0}
h2{font-size:24px;line-height:32px;margin:0 0 12px}h3{font-size:19px;line-height:26px;font-weight:600;margin:16px 0 8px;display:flex;gap:8px;align-items:center}
code{font:13px ui-monospace,Menlo,monospace;color:var(--ink2)}
p{max-width:70ch;margin:0 0 12px}.note{color:var(--ink2);font-size:14px}
.hero{background:var(--primary);color:#fff;padding:32px 16px;display:flex;flex-wrap:wrap;gap:24px;align-items:center;justify-content:center}
.hero>svg{height:64px;width:auto}.hero h1{font-size:28px;line-height:36px}.hero p{color:#BFE0CD;margin:0}
main{max-width:960px;margin:0 auto;padding:8px 16px 48px}
section{background:var(--surface);border:1px solid var(--border);border-radius:18px;padding:20px;margin-top:14px;box-shadow:0 1px 2px #17251E0D}
.row{display:flex;flex-wrap:wrap;gap:24px;align-items:flex-end;margin:12px 0}
figure{margin:0;display:grid;gap:8px;justify-items:center}figcaption{font-size:12px;line-height:17px;color:var(--ink2);text-align:center;max-width:220px}
.cs{width:160px;height:160px;padding:40px;outline:1px dashed #C24A1F;background:repeating-linear-gradient(45deg,#FDEDE4 0 6px,#fff 6px 12px);box-sizing:content-box}
.cs svg{width:160px;height:160px;display:block;background:transparent}
.sizes{display:flex;gap:16px;align-items:flex-end}.sizes svg{width:100%;height:auto;display:block}
.g{padding:16px;border-radius:14px;border:1px solid var(--border)}.g svg{width:72px;height:72px;display:block}
.light{background:#fff}.darkg{background:#131C18}.prim{background:var(--primary)}
.darkg figcaption,.prim figcaption{color:#BFE0CD}
.lockups{display:flex;flex-wrap:wrap;gap:40px;margin:16px 0 8px}.lockups svg{height:56px;width:auto}
.two{align-items:stretch}.two>.card{flex:1 1 280px}
.card{border-radius:14px;padding:4px 16px 12px}.card ul{margin:0;padding-left:20px}
.ok{background:#E6F4EC}.ok h3{color:#1A7340}.no{background:#FCEBEA}.no h3{color:#B3261E}
.sws{display:grid;grid-template-columns:repeat(auto-fill,minmax(150px,1fr));gap:12px}
.sw{display:grid;gap:2px;font-size:14px;line-height:20px}.sw i{height:56px;border-radius:14px;border:1px solid var(--border)}.sw small{color:var(--ink2);font-size:12px;line-height:16px}
table.type{border-collapse:collapse;width:100%}.type td{padding:10px 8px;border-top:1px solid var(--border);vertical-align:middle}
.type td:first-child{width:190px}.type small{display:block;font-size:12px;color:var(--ink2)}
.ms{font-family:'Material Symbols Rounded';font-weight:400;font-size:24px;line-height:1;font-variation-settings:'FILL' 0,'wght' 400,'opsz' 24;display:inline-block}
.ms.f{font-variation-settings:'FILL' 1,'wght' 400,'opsz' 24}
.nav{display:flex;justify-content:space-around;max-width:420px;border:1px solid var(--border);border-radius:18px;padding:10px 6px}
.tab{display:grid;justify-items:center;gap:4px;font:600 12px/16px Mukta;color:var(--ink2)}
.tab .ms{padding:4px 18px;border-radius:999px}.tab.sel{color:var(--primary)}.tab.sel .ms{background:var(--pc)}
.tab.rep .ms{background:var(--sun);color:#fff;border-radius:14px;padding:6px 14px}
.cats{display:grid;grid-template-columns:repeat(auto-fill,minmax(120px,1fr));gap:12px}
.cat{display:flex;gap:10px;align-items:center;font:600 14px/20px Mukta;text-transform:capitalize}
.cat i{width:40px;height:40px;border-radius:14px;display:grid;place-items:center;flex:none}
.chips{display:flex;flex-wrap:wrap;gap:10px}
.chip{display:inline-flex;gap:6px;align-items:center;padding:4px 12px 4px 8px;border-radius:999px;font:600 12px/16px Mukta}
.chip .ms{font-size:18px}.chip.solid{color:#fff}
.indep{display:flex;gap:12px;align-items:flex-start;margin-top:14px;padding:16px;border-radius:18px;background:#E5EEFA;color:#1F5FAE}
.indep div{display:grid;gap:4px}.indep span{color:var(--ink)}
`;
