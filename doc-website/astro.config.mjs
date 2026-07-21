// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

// https://astro.build/config
export default defineConfig({
	site: 'https://vendinois.github.io/PFUI/',
	integrations: [
		starlight({
			title: 'PFUI',
			description: 'An experimental concatenative UI framework for Beef',
			social: [{ icon: 'github', label: 'GitHub', href: 'https://github.com/vendinois/PFUI' }],
			expressiveCode: {
				languages: ['beef'],
			},
			sidebar: [
				{
					label: 'Start Here',
					items: [
						{ label: 'Overview', slug: '' },
						{ label: 'Getting Started', slug: 'getting-started' },
					],
				},
				{
					label: 'Concepts',
					items: [
						{ label: 'Concatenative Model', slug: 'concepts/concatenative-model' },
						{ label: 'Widget Model', slug: 'concepts/widget-model' },
						{ label: 'Modifiers & Pens', slug: 'concepts/modifiers' },
						{ label: 'Rebuild Model', slug: 'concepts/rebuild-model' },
					],
				},
				{
					label: 'API Reference',
					collapsed: true,
					items: [
						{ label: 'Core Ops', slug: 'api/core-ops' },
						{ label: 'Widgets', slug: 'api/widgets' },
						{ label: 'Modifiers', slug: 'api/modifiers' },
						{ label: 'Styling', slug: 'api/styling' },
						{ label: 'Handlers', slug: 'api/handlers' },
						{ label: 'Diagnostics', slug: 'api/diagnostics' },
					],
				},
				{
					label: 'Guides',
					collapsed: true,
					items: [
						{ label: 'Factoring Words', slug: 'guides/factoring-words' },
						{ label: 'Custom Components', slug: 'guides/custom-components' },
						{ label: 'Drawable Primitives', slug: 'guides/drawable-primitives' },
						{ label: 'State Management', slug: 'guides/state-management' },
					],
				},
				{
					label: 'Design',
					items: [
						{ label: 'Decisions', slug: 'design/decisions' },
						{ label: 'Roadmap', slug: 'roadmap' },
					],
				},
			],
		}),
	],
});
