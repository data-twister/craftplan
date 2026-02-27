export async function cacheMacro() {
  let manifest = await cache_manifest_or_default();

  let base = [
    "assets/app.css",
    "assets/event-calendar.css"
    "assets/app.js"
    "assets/tailwind_heroicons.js"
  ];

  let cache = base.map((key) => {
    let digested = manifest.latest[key];
    if (!digested)
      return {
        key: key,
        sha512: null,
        path: "/" + key,
      };
    return {
      key: digested,
      sha512: manifest.digests[key]?.sha512,
      path: "/" + digested + "?vsn=d",
    };
  });

  let hash = cache
    .flatMap((entry) => {
      if (!entry.sha512) return [];
      return [entry.sha512];
    })
    .reduce((hasher, sha) => hasher.update(sha), new Bun.CryptoHasher("sha512"))
    .digest("base64");

  return {
    cache: cache.map((entry) => entry.path),
    hash: hash,
  };
}

async function cache_manifest_or_default() {
  return import("./../../../priv/static/cache_manifest.json").catch((_err) => ({
    latest: [],
    digests: [],
  }));
}