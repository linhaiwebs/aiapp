declare module 'ali-oss' {
  interface OSSOptions {
    region: string;
    accessKeyId: string;
    accessKeySecret: string;
    bucket: string;
    endpoint?: string;
    internal?: boolean;
    secure?: boolean;
    timeout?: number;
  }

  interface HeadResult {
    res: { status: number; headers: Record<string, string> };
    meta: Record<string, string>;
    status: number;
  }

  interface PutObjectResult {
    name: string;
    url: string;
    res: { status: number; headers: Record<string, string> };
  }

  export default class OSSClient {
    constructor(options: OSSOptions);
    signatureUrl(name: string, options?: {
      method?: string;
      'Content-Type'?: string;
      expires?: number;
      response?: Record<string, string>;
    }): string;
    put(name: string, file: any, options?: Record<string, any>): Promise<PutObjectResult>;
    head(name: string, options?: Record<string, any>): Promise<HeadResult>;
    get(name: string, options?: Record<string, any>): Promise<{ content: any; res: any }>;
    delete(name: string, options?: Record<string, any>): Promise<any>;
    list(query: Record<string, any>, options?: Record<string, any>): Promise<any>;
  }
}
