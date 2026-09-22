import prettier from "eslint-config-prettier";
import js from "@eslint/js";
import svelte from "eslint-plugin-svelte";
import globals from "globals";
import ts from "typescript-eslint";

export default ts.config(
	js.configs.recommended,
	...ts.configs.recommended,
	...svelte.configs["flat/recommended"],
	prettier,
	...svelte.configs["flat/prettier"],
	{
		languageOptions: {
			globals: {
				...globals.browser,
				...globals.node,
			},
		},
	},
	{
		files: ["**/*.svelte"],
		languageOptions: {
			parserOptions: {
				parser: ts.parser,
			},
		},
		rules: {
			"svelte/no-navigation-without-resolve": "off",
			"svelte/prefer-writable-derived": "off",
			"svelte/require-each-key": "off",
		},
	},
	{
		files: ["**/*.svelte.ts"],
		languageOptions: {
			parser: ts.parser,
		},
	},
	{
		rules: {
			"no-empty": ["error", { allowEmptyCatch: true }],
			"@typescript-eslint/no-explicit-any": "warn",
			"@typescript-eslint/no-unused-vars": [
				"warn",
				{ argsIgnorePattern: "^_", varsIgnorePattern: "^_" },
			],
		},
	},
	{
		ignores: [
			"build/",
			".svelte-kit/",
			"dist/",
			"node_modules/",
			"*.db*",
			".gitnexus/",
			".claude/",
			"coverage/",
			"data/",
			"logs/",
			"backups/",
			"*.config.cjs",
		],
	},
);
