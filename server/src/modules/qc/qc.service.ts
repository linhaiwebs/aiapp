import { Injectable } from '@nestjs/common';

@Injectable()
export class QcService {
  /**
   * Base quality check - will be extended in Phase 2 (audio), Phase 3 (image), Phase 4 (video)
   */
  async performBasicQc(fileId: string, taskType: string): Promise<{
    passed: boolean;
    score: number;
    report: Record<string, any>;
  }> {
    // Placeholder - will be implemented per task type in subsequent phases
    return {
      passed: true,
      score: 100,
      report: { message: 'Basic QC passed' },
    };
  }
}
