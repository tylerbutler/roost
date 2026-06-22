import assert from "node:assert/strict";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";

import { generateReference } from "./generate-reference.mjs";

test("generates an index and module pages from package-interface.json", async () => {
	const tempDir = await tempFixtureDir();
	const docsJsonPath = path.join(tempDir, "package-interface.json");
	const outputDir = path.join(tempDir, "reference");

	await writeFile(docsJsonPath, JSON.stringify(packageInterfaceFixture()));
	const result = await generateReference({ docsJsonPath, outputDir });

	assert.deepEqual(result, { pageCount: 3, moduleCount: 2 });

	const index = await readFile(path.join(outputDir, "index.md"), "utf8");
	assert.match(index, /title: "Reference"/);
	assert.match(index, /\| \[`roost\/extra`\]\(\/reference\/roost-extra\/\) \| Extra helpers\. \|/);

	const modulePage = await readFile(path.join(outputDir, "roost-extra.md"), "utf8");
	assert.match(modulePage, /title: "roost\/extra"/);
	assert.match(modulePage, /## Types\n\n### `Box`/);
	assert.match(modulePage, /pub type Box\(a\) \{\n  Box\(value: a\)\n\}/);
	assert.match(modulePage, /#### Constructors\n\n##### `Box\(value: a\)`\n\nWraps a value\./);
	assert.match(modulePage, /## Type aliases\n\n### `Pair`/);
	assert.match(modulePage, /pub type Pair\(a\) = #\(a, String\)/);
	assert.match(modulePage, /## Constants\n\n### `default_handler`/);
	assert.match(modulePage, /pub const default_handler: fn\(String, #\(Int, String\)\) -> Bool/);
	assert.match(modulePage, /## Functions\n\n### `old_use_box`/);
	assert.match(modulePage, /pub fn use_box\(box: Box\(Int\)\) -> frame\.Incoming/);
	assert.match(modulePage, /<strong>Deprecated\.<\/strong> Use `use_box` instead\./);
});

test("missing package-interface.json mentions gleam docs build", async () => {
	const tempDir = await tempFixtureDir();
	const docsJsonPath = path.join(tempDir, "missing.json");
	const outputDir = path.join(tempDir, "reference");

	await assert.rejects(
		() => generateReference({ docsJsonPath, outputDir }),
		/error.*gleam docs build/i,
	);
});

async function tempFixtureDir() {
	return mkdir(path.join(os.tmpdir(), `roost-reference-${process.pid}-${Date.now()}`), {
		recursive: true,
	});
}

function named(name, module = "gleam", parameters = []) {
	return { kind: "named", name, package: "", module, parameters };
}

function variable(id) {
	return { kind: "variable", id };
}

function packageInterfaceFixture() {
	return {
		name: "roost",
		version: "0.1.0",
		modules: {
			roost: {
				documentation: ["Root module."],
				"type-aliases": {},
				types: {},
				constants: {},
				functions: {},
			},
			"roost/extra": {
				documentation: "Extra helpers.",
				"type-aliases": {
					Pair: {
						documentation: "A tuple alias.",
						deprecation: null,
						parameters: 1,
						alias: {
							kind: "tuple",
							elements: [variable(0), named("String")],
						},
					},
				},
				types: {
					Box: {
						documentation: "A generic box.",
						deprecation: null,
						parameters: 1,
						constructors: [
							{
								name: "Box",
								documentation: "Wraps a value.",
								parameters: [{ label: "value", type: variable(0) }],
							},
						],
					},
				},
				constants: {
					default_handler: {
						documentation: "Default handler.",
						deprecation: null,
						type: {
							kind: "fn",
							parameters: [
								named("String"),
								{ kind: "tuple", elements: [named("Int"), named("String")] },
							],
							return: named("Bool"),
						},
					},
				},
				functions: {
					old_use_box: {
						documentation: "Deprecated helper.",
						deprecation: { message: "Use `use_box` instead." },
						parameters: [],
						return: named("Nil"),
					},
					use_box: {
						documentation: "Use a box.",
						deprecation: null,
						parameters: [
							{
								label: "box",
								type: named("Box", "roost/extra", [named("Int")]),
							},
						],
						return: named("Incoming", "roost/frame"),
					},
				},
			},
		},
	};
}
