import { readRequest, sendRequest } from './proto.js';
import fs from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import { createHighlighter } from 'shiki';

const __dirname = dirname(fileURLToPath(import.meta.url));
//const theme = 'catppuccin-latte';
const theme = 'one-light';

async function initializeHighlighter() {
    const httGrammar = JSON.parse(
        fs.readFileSync(join(__dirname, 'htt.tmLanguage.json'), 'utf8')
    );
    httGrammar.aliases = ['htt'];

    return await createHighlighter({
        langs: [httGrammar, 'lua'],
        themes: [theme]
    });
}

async function processRequest(highlighter, rq) {
    const hdrs = rq.headers;
    if (!hdrs.has("$rq")) {
        console.error("ERROR, RQ has NO $rq");
        return;
    }

    if (!hdrs.has("$length")) {
        console.error("RQ has no body (no $length hdr)");
        return;
    }

    const length = parseInt(hdrs.get("$length"), 10);
    if (length === NaN) {
        console.error("$length cannot be interpreted as a number");
        return;
    }

    const lang = (hdrs.get("lang") ?? "htt").toLowerCase();

    // TODO: later, look at an encoding header
    const body = rq.body.toString("utf8");

    const html = highlighter.codeToHtml(body, {
        lang: lang,
        theme: theme,
        colorReplacements: {
            "#fafafa": "rgb(245 245 244 / var(--tw-bg-opacity))",
        },
    });

    const rsp_hdrs = {
        rid: hdrs.get("rid"),
    };
    sendRequest("/highlight/rsp", rsp_hdrs, html);
}

async function main() {
    console.error("initializing highlighter...");
    const highlighter = await initializeHighlighter();
    console.log("Ready for requests");


    while (true) {
        try {
            const rq = await readRequest();
            //console.error("headers:", Object.fromEntries(rq.headers));
            processRequest(highlighter, rq);
        } catch (err) {
            console.error("error parsing rq:", error);
        }

    }
}

main().catch(error => {
    console.error("Fatal error:", error);
    process.exit(1);
})
