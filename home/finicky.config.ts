export default {
  defaultBrowser: "Safari",
  handlers: [
    {
      // Open these urls in Chrome
      match: ["docs.google.com/*"],
      browser: "Google Chrome",
      profile: "Work"
    },

    // Notion 
    {
      match: ["notion.so/*"],
      browser: "Notion"
    },

    // Spotify
    {
      match: finicky.matchDomains("open.spotify.com"),
      browser: "Spotify"
    },

    // Zoom
    {
      match: /zoom\.us\/join/,
      browser: "us.zoom.xos"
    },

    // Teams
    {
      match: finicky.matchHostnames(['teams.microsoft.com']),
      browser: 'com.microsoft.teams',
      url: ({ url }) =>
        ({ ...url, protocol: 'msteams' }),
    },

    // Slack
        // Teams
    {
      match: ['*.slack.com/*'],
      browser: 'Google Chrome',
      profile: "Work"
    }
  ],

  rewrite: [

    // Zoom
    {
      match: (url) => url.host.includes("zoom.us") && url.pathname.includes("/j/"),
      url: (url) => {
        try {
          const match = url.search.match(/pwd=(\w*)/);
          var pass = match ? '&pwd=' + match[1] : '';
        } catch {
          var pass = "";
        }
        const pathMatch = url.pathname.match(/\/j\/(\d+)/);
        var conf = 'confno=' + (pathMatch ? pathMatch[1] : '');
        url.search = conf + pass;
        url.pathname = '/join';
        url.protocol = "zoommtg";
        return url;
      }
    }
  ]
}