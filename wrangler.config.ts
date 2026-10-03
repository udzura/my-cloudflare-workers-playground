import { defineWranglerConfig } from "wrangler/experimental-config";

export default defineWranglerConfig({
	rules: [
		{
			type: "Data",
			globs: [
				"**/*.bin",
			],
			fallthrough: true,
		},
	],
	build: {
		command: "bundle exec rake build",
		watchDir: [
			"app.rb",
			"build_config.rb",
		],
	},
	types: {
		generate: false,
	},
	assetsDirectory: "./assets",
});
