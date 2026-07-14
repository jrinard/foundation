const path = require("path");
const rails = require("esbuild-rails");

const buildOptions = {
  entryPoints: ["application.js"],
  bundle: true,
  outdir: path.join(process.cwd(), "app/assets/builds"),
  absWorkingDir: path.join(process.cwd(), "app/javascript"),
  plugins: [rails()],
};

const isWatch = process.argv.includes("--watch");

if (isWatch) {
  require("esbuild")
    .context(buildOptions)
    .then((ctx) => ctx.watch())
    .catch(() => process.exit(1));
} else {
  require("esbuild")
    .build(buildOptions)
    .catch(() => process.exit(1));
}
