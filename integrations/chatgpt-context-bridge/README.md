# ChatGPT receiving-plugin template

This is the **receiving side**, separate from the Claude Code marketplace plugin in `plugins/context-bridge`. It follows OpenAI's portable plugin packaging shape, with a root `plugin.json`, `mcp.json` and a skill. It is not registered, hosted, connected or subscribed by this PR.

The `https://bridge.example.invalid/mcp` URL is deliberately unusable. In a private working copy, replace it with the HTTPS `/mcp` endpoint of your reviewed deployment of [the reference service](../../services/context-bridge/README.md). Supply its separate MCP bearer credential only through a supported secure connection flow. Never put a token in this manifest, Git, a PR or a conversation. Do not distribute one owner's credentials to other users.

The manifest declares API-key bearer authentication, not OAuth. Official packaging documentation describes this declaration but also warns that API-key declarations are unsupported by the public submission portal's connection form. Therefore this template is **not a ready-to-submit directory integration**. Verify an eligible private/local connection path in the actual account before investing in deployment; a broadly distributed product needs a supported authentication/onboarding design (typically per-user OAuth).

Consult the current official setup documentation rather than assuming every account has the same import controls:

- [Package a plugin and authentication declarations](https://developers.openai.com/plugins/build/plugins)
- [Connect and test](https://developers.openai.com/plugins/deploy/connect-chatgpt)
- [MCP Events](https://developers.openai.com/plugins/build/mcp-events)

Once the connection works, explicitly ask the target chat to monitor one permitted project and explain what to do with incoming handoffs. The platform creates the callback subscription; neither this template nor the sender chooses a chat ID. Test with generic data and verify: sender acceptance, callback acceptance, event arriving in the intended chat and the assistant interpreting it. None of those account-level stages has been verified by the local mock tests.

Do not use a normal OpenAI API conversation ID, browser session cookie or undocumented endpoint to bypass setup. No reply channel to Claude Code is included in this first version.
