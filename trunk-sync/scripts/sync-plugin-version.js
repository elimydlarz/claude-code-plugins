import { readFileSync, writeFileSync } from "fs";

const pkg = JSON.parse(readFileSync("package.json", "utf8"));

for (const path of [".claude-plugin/plugin.json"]) {
  const plugin = JSON.parse(readFileSync(path, "utf8"));
  plugin.version = pkg.version;
  writeFileSync(path, JSON.stringify(plugin, null, 2) + "\n");
}
