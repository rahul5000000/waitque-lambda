import { build } from "esbuild";

await build({
  entryPoints: ["src/index.js"],
  bundle: true,
  platform: "node",
  target: "node20",
  outfile: "dist/index.js",
  minify: false,
});
