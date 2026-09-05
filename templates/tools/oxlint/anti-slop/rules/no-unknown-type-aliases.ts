import { defineRule } from "@oxlint/plugins";

import type { ESTree } from "@oxlint/plugins";

import {
	createTypeEnvironment,
	resolveTypeAlias,
	type TypeEnvironment,
} from "../shared/dictionary-types.ts";

function referencedAliasName(type: ESTree.TSType): string | null {
	if (type.type === "TSParenthesizedType") return referencedAliasName(type.typeAnnotation);
	if (type.type !== "TSTypeReference" || type.typeName.type !== "Identifier") return null;
	return type.typeArguments === null ||
		type.typeArguments === undefined ||
		type.typeArguments.params.length === 0
		? type.typeName.name
		: null;
}

/** Ban named aliases that merely conceal TypeScript's unknown top type. */
export const noUnknownTypeAliasesRule = defineRule({
	meta: {
		type: "problem",
		docs: {
			description:
				"Disallow type aliases whose resolved type is unknown; unknown must remain visible at an allowed boundary.",
		},
		messages: {
			unknownAlias:
				"Type alias `{{alias}}` hides `unknown`. Keep `unknown` explicit at the parsing boundary or on an allowed `cause` field; otherwise use the parsed owner type.",
		},
	},
	createOnce(context) {
		let environment: TypeEnvironment | null = null;

		const resolvesToUnknown = (type: ESTree.TSType, visited = new Set<string>()): boolean => {
			if (type.type === "TSUnknownKeyword") return true;
			if (type.type === "TSParenthesizedType")
				return resolvesToUnknown(type.typeAnnotation, visited);
			const name = referencedAliasName(type);
			if (name === null || visited.has(name)) return false;
			if (environment === null) return false;
			const alias = resolveTypeAlias(name, type, environment);
			if (
				alias === null ||
				(alias.typeParameters !== null && alias.typeParameters !== undefined)
			) {
				return false;
			}
			const nextVisited = new Set(visited);
			nextVisited.add(name);
			return resolvesToUnknown(alias.typeAnnotation, nextVisited);
		};

		return {
			Program(node) {
				environment = createTypeEnvironment(node);
				for (const aliases of environment.aliases.values()) {
					for (const binding of aliases) {
						const alias = binding.declaration;
						if (!resolvesToUnknown(alias.typeAnnotation, new Set([alias.id.name]))) continue;
						context.report({
							node: alias.id,
							messageId: "unknownAlias",
							data: { alias: alias.id.name },
						});
					}
				}
			},
		};
	},
});
