# WordUI Documentation Website

Built with [Astro](https://astro.build/) + [Starlight](https://starlight.astro.build/).

Content lives in [`../docs/`](../docs/) — this project is a thin Starlight wrapper that reads
those `.mdx` files as its content directory via symlink.

## Setup

```sh
bun install
```

## Develop

```sh
bun run dev        # Start dev server at http://localhost:4321
```

## Build

```sh
bun run build      # Output to dist/
bun run preview    # Preview the production build
```

## How it works

```
docs/               ← canonical .mdx files (the source of truth)
  └── concepts/
  └── api/
  └── guides/
  └── design/

doc-website/
  └── src/content/docs/ → symlink → ../../docs/
  └── astro.config.mjs  → Starlight sidebar + config
  └── src/components/   → Custom MDX components (StackEffect, …)
```

Content files in `docs/` use standard Markdown with Starlight frontmatter
(`title`, `description`). They render fine on GitHub; Starlight adds navigation,
search, dark mode, and syntax highlighting.
