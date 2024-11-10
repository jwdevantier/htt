import net from 'net';
import fs from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import { createHighlighter } from 'shiki';

const __dirname = dirname(fileURLToPath(import.meta.url));
const theme = 'one-light';

class MessageFramer {
    constructor() {
        this.buffer = Buffer.alloc(0);
    }

    addChunk(chunk) {
        this.buffer = Buffer.concat([this.buffer, chunk]);
    }

    tryReadMessage() {
        //console.error(`srv>> tryReadMessage`);
        // Check if we have enough bytes for the length prefix
        if (this.buffer.length < 4) {
            return null;
        }

        // Read the length prefix
        const messageLength = this.buffer.readUInt32LE(0);

        // Check if we have the complete message
        const totalLength = messageLength + 4; // length prefix + message
        if (this.buffer.length < totalLength) {
            return null;
        }

        // Extract the complete message
        const message = this.buffer.slice(4, totalLength);

        // Remove the processed message from the buffer
        this.buffer = this.buffer.slice(totalLength);

        return message;
    }
}

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

async function main() {
    // Get port from command line arguments
    console.log("highlighter.js stdout");
    console.error("highlighter.js stderr");
    const port = parseInt(process.argv[2]);

    if (!port || isNaN(port)) {
        console.error('Usage: node server.js <PORT>');
        process.exit(1);
    }

    const highlighter = await initializeHighlighter();

    const server = net.createServer((socket) => {
        console.log('Client connected:', socket.remoteAddress);
        
        const framer = new MessageFramer();
    
        socket.on('data', (chunk) => {
            // Add the new chunk to our buffer
            framer.addChunk(chunk);
    
            // Try to read complete messages
            let message;
            while ((message = framer.tryReadMessage()) !== null) {
                // // Create response with length prefix

                const cmd = message.readUInt16LE(0);
                switch (cmd) {
                    case 0: // exit
                        console.log("server shutting down");
                        process.exit(0);
                        break;
                    case 1: // highlight
                        const str = message.slice(2).toString('utf-8');
                        let lang = null;
                        let code = null;
                        if (str.startsWith("lang:")) {
                            const after = str.substring(5); // 'lang:'
                            const delim = after.indexOf(';');
                            if (delim !== -1) {
                                lang = after.substring(0, delim);
                                code = after.substring(delim+1);
                            }
                        }
                        if (lang === null) {
                            lang = "htt";
                            code = str;
                        }

                        const html = highlighter.codeToHtml(code, {
                            lang: lang,
                            theme: theme,
                            colorReplacements: {
                                "#fafafa": "rgb(245 245 244 / var(--tw-bg-opacity))",
                            },
                        });

                        // respond
                        const responseLength = Buffer.alloc(4);
                        responseLength.writeUInt32LE(html.length);
                        
                        // Send the length prefix followed by the message
                        socket.write(Buffer.concat([responseLength, Buffer.from(html)]));
                        break;
                    default:
                        console.error(`srv got unknown cmd [${cmd}], disconnecting`);
                        socket.destroy();
                };
            }
        });
    
        socket.on('end', () => {
            console.log('Client disconnected:', socket.remoteAddress);
        });
    
        socket.on('error', (err) => {
            console.error('Socket error:', err);
        });
    });

    server.listen(port, '127.0.0.1', () => {
        console.log(`Server listening on port localhost:${port}`);
    });
}

main().catch(err => {
    console.error("failed to start highlighter server: ", err);
    process.exit(1);
})