class ProtocolParser {
  constructor() {
    this.buffer = Buffer.alloc(0);
  }

  addChunk(chunk) {
    this.buffer = Buffer.concat([this.buffer, chunk]);
  }

  findSequence(seq) {
    for (let i = 0; i <= this.buffer.length - seq.length; i++) {
      let found = true;
      for (let j = 0; j < seq.length; j++) {
        if (this.buffer[i + j] !== seq[j]) {
          found = false;
          break;
        }
      }
      if (found) return i;
    }
    return -1;
  }

  tryParseRequest() {
    // First find header end without modifying buffer
    const headerEndIndex = this.findSequence([13, 10, 13, 10]);
    if (headerEndIndex === -1) return null;

    // Parse headers from slice
    const headerSection = this.buffer.slice(0, headerEndIndex);
    const headers = new Map();
    const headerLines = headerSection.toString().split('\r\n');

    // First header must be $rq
    const [name, ...valueParts] = headerLines[0].split(':');
    if (name !== '$rq') {
      throw new Error('First header must be $rq');
    }
    headers.set(name, valueParts.join(':').trim());

    // Parse remaining headers
    for (let i = 1; i < headerLines.length; i++) {
      const [name, ...valueParts] = headerLines[i].split(':');
      headers.set(name, valueParts.join(':').trim());
    }

    // Calculate total bytes needed
    const length = headers.get('$length');
    const totalNeeded = headerEndIndex + 4 + (length ? parseInt(length, 10) : 0);

    // Check if we have enough data
    if (length && this.buffer.length < totalNeeded) {
      return null;
    }

    // Only now consume data from buffer
    const body = length ? this.buffer.slice(headerEndIndex + 4, totalNeeded) : null;
    this.buffer = this.buffer.slice(totalNeeded);

    return { headers, body };
  }
}

// Create single global parser that maintains buffer state
const parser = new ProtocolParser();

export async function readRequest() {
  while (true) {
    const request = parser.tryParseRequest();
    if (request) return request;

    const chunk = await new Promise(resolve => 
      process.stdin.once('data', resolve)
    );
    parser.addChunk(chunk);
  }
}

export function sendRequest(rq, hdrs, body) {
    // Start with $rq header
    process.stdout.write(`$rq: ${rq}\r\n`);

    // Write other headers
    for (const [key, value] of Object.entries(hdrs)) {
        process.stdout.write(`${key}: ${value}\r\n`);
    }

    // Convert body to bytes if it's a string
    const bodyBytes = typeof body === 'string' 
        ? Buffer.from(body, 'utf8')
        : body;

    // Write length header and empty line
    process.stdout.write(`$length: ${bodyBytes.length}\r\n\r\n`);

    // Write body
    process.stdout.write(bodyBytes);
}

/*
async function main() {
  try {
    const request = await readRequest();
    console.log('Headers:', Object.fromEntries(request.headers));
    console.log('Body:', request.body ? request.body.toString() : null);
  } catch (err) {
    console.error('Error:', err.message);
    process.exit(1);
  }
}

if (require.main === module) {
  main();
}
*/

