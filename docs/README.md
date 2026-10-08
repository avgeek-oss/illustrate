# Illustrate website and documentation

This is the Mintlify site root. `index.mdx` is the homepage and `docs/`
contains the guides. Run from the repository root with Node.js 24 or newer:

```sh
npm ci
npm run docs:dev
npm run docs:check
```

Preview at http://localhost:4188. Local search requires `mint login`;
page navigation works without it.

Edit `site.json` for navigation, branding, and footer links. Run
`npm run docs:sync` and commit the generated `docs.json`, `oss-docs.css`,
`oss-docs.js`, `snippets/oss/`, and `.oss-docs.json`. Do not edit generated
files directly. `style.css` only sizes the product logo.

The shared layout is pinned to a public source archive. No registry token
is required. Keep screenshots free of private prompts, media, and credentials.
Documentation reports go to GitHub Issues; do not add email or direct-contact links.

For hosting, connect `avgeek-oss/illustrate`, branch `main`, directory `/docs`
in Mintlify. The canonical origin is `https://illustrate.so`. Repository
publication does not configure hosting or DNS. Add an App Store purchase link
only when a verified listing is available.
