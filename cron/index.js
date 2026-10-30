// Starts the mirror workflow on GitHub, on the schedule in wrangler.jsonc.
export default {
	async scheduled(controller, env) {
		const res = await fetch(
			`https://api.github.com/repos/${env.GITHUB_REPO}/actions/workflows/mirror.yml/dispatches`,
			{
				method: "POST",
				headers: {
					Accept: "application/vnd.github+json",
					Authorization: `Bearer ${env.GITHUB_TOKEN}`,
					"User-Agent": "stagit-cron",
					"X-GitHub-Api-Version": "2022-11-28",
				},
				body: JSON.stringify({ ref: "main", inputs: { trigger: "scheduled" } }),
			},
		);
		if (!res.ok)
			throw new Error(`workflow dispatch: ${res.status} ${await res.text()}`);
	},
};
