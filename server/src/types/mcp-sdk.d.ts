declare module '@modelcontextprotocol/sdk/client' {
  import type { Transport } from '@modelcontextprotocol/sdk/shared/transport';

  interface Implementation {
    name: string;
    version: string;
  }

  interface ClientOptions {
    capabilities?: Record<string, unknown>;
  }

  interface CallToolParams {
    name: string;
    arguments: Record<string, string>;
  }

  interface CallToolContent {
    type: string;
    text: string;
  }

  interface CallToolResult {
    isError?: boolean;
    content: CallToolContent[];
  }

  export class Client {
    constructor(info: Implementation, options?: ClientOptions);
    connect(transport: Transport): Promise<void>;
    callTool(params: CallToolParams): Promise<CallToolResult>;
    close(): Promise<void>;
  }
}

declare module '@modelcontextprotocol/sdk/client/sse' {
  import type { Transport } from '@modelcontextprotocol/sdk/shared/transport';

  export class SSEClientTransport implements Transport {
    constructor(url: URL, opts?: Record<string, unknown>);
    start(): Promise<void>;
    close(): Promise<void>;
  }
}

declare module '@modelcontextprotocol/sdk/shared/transport' {
  export interface Transport {
    start(): Promise<void>;
    close(): Promise<void>;
  }
}
