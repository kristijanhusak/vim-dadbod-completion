import {
  BaseSource,
  Candidate,
} from "https://deno.land/x/ddc_vim@v0.16.0/types.ts#^";

import {
  GatherCandidatesArguments,
  GetCompletePositionArguments,
} from "https://deno.land/x/ddc_vim@v0.16.0/base/source.ts#^";

type Params = Record<never, never>;

export class Source extends BaseSource<Params> {
  async gatherCandidates(
    args: GatherCandidatesArguments<Params>,
  ): Promise<Candidate[]> {
    const items = await args.denops.call(
      "vim_dadbod_completion#omni",
      0,
      args.completeStr,
    ) as Candidate[];
    return items;
  }
  async getCompletePosition(
    args: GetCompletePositionArguments<Params>,
  ): Promise<number> {
    const pos = await args.denops.call(
      "vim_dadbod_completion#omni",
      1,
      "",
    ) as number;
    return pos;
  }
  params(): Params {
    return {};
  }
}
