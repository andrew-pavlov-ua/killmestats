const repositoryUrl =
  "https://api.github.com/repos/andrew-pavlov-ua/killmestats";

export function load_stars(callback) {
  fetch(repositoryUrl, {
    headers: { Accept: "application/vnd.github+json" },
  })
    .then((response) => {
      if (!response.ok) throw new Error("GitHub request failed");
      return response.json();
    })
    .then((repository) => {
      const count = repository.stargazers_count;
      callback(Number.isInteger(count) ? count : -1);
    })
    .catch(() => callback(-1));
}
